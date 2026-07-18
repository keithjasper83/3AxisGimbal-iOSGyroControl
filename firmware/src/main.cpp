#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include "config.h"

// Global state
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Commanded angles from phone (degrees)
float roll_cmd_deg = 0.0f;
float pitch_cmd_deg = 0.0f;
float yaw_cmd_deg = 0.0f;

// Stabilization blend factor (0.0 to 1.0)
float stabBlend = DEFAULT_STAB_BLEND;

// Output servo pulse widths (microseconds)
int yaw_pulse_us = 1500;
int pitch_pulse_us = 1500;
int roll_pulse_us = 1500;

// BLE Server and characteristics
BLEServer* pServer = nullptr;
BLECharacteristic* pTxCharacteristic = nullptr;
BLECharacteristic* pRxCharacteristic = nullptr;

// Helper clamp function
float clampAngle(float val, float minVal, float maxVal) {
    if (val < minVal) return minVal;
    if (val > maxVal) return maxVal;
    return val;
}

// Map degrees [-180..180] linearly to servo pulse [500..2500] us
int mapAngleToServoPulse(float angle) {
    // Linear interpolation: y = y1 + (x - x1) * (y2 - y1) / (x2 - x1)
    float pulse = SERVO_MIN_PULSE_US + (angle - AXIS_MIN) * (SERVO_MAX_PULSE_US - SERVO_MIN_PULSE_US) / (AXIS_MAX - AXIS_MIN);
    return (int)round(pulse);
}

// BLE Server Connection Callback
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("BLE Client Connected.");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("BLE Client Disconnected.");
    }
};

// BLE Rx Characteristic Callback
class MyRxCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string rxValue = pCharacteristic->getValue();
        if (rxValue.length() > 0) {
            StaticJsonDocument<256> doc;
            DeserializationError error = deserializeJson(doc, rxValue.c_str());
            
            if (error) {
                Serial.print("Invalid JSON received and ignored: ");
                Serial.println(error.c_str());
                return;
            }
            
            const char* cmd = doc["cmd"];
            if (cmd == nullptr) {
                Serial.println("Missing 'cmd' field in JSON. Ignored.");
                return;
            }
            
            if (strcmp(cmd, "setPhoneGyro") == 0) {
                // Read optional gx, gy, gz, defaulting to 0.0 if missing
                float gx = doc.containsKey("gx") ? doc["gx"].as<float>() : 0.0f;
                float gy = doc.containsKey("gy") ? doc["gy"].as<float>() : 0.0f;
                float gz = doc.containsKey("gz") ? doc["gz"].as<float>() : 0.0f;
                
                // Axis Mapping Logic with fixed gain (20.0) and clamping
                roll_cmd_deg  = clampAngle(gx * GYRO_GAIN, AXIS_MIN, AXIS_MAX);
                pitch_cmd_deg = clampAngle(gy * GYRO_GAIN, AXIS_MIN, AXIS_MAX);
                yaw_cmd_deg   = clampAngle(gz * GYRO_GAIN, AXIS_MIN, AXIS_MAX);
            } else {
                Serial.printf("Unknown 'cmd' '%s' ignored.\n", cmd);
            }
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("\n=== Gimbal BLE Gyro Streamer Firmware ===");

    // Initialize BLE Device
    BLEDevice::init(BLE_DEVICE_NAME);

    // Create BLE Server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create BLE Service
    BLEService *pService = pServer->createService(BLE_SERVICE_UUID);

    // Create RX Characteristic (Write / Write Without Response)
    pRxCharacteristic = pService->createCharacteristic(
        BLE_RX_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_WRITE_NR
    );
    pRxCharacteristic->setCallbacks(new MyRxCallbacks());

    // Create TX Characteristic (Read / Notify)
    pTxCharacteristic = pService->createCharacteristic(
        BLE_TX_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTxCharacteristic->addDescriptor(new BLE2902());
    pTxCharacteristic->setValue("ready");

    // Start Service
    pService->start();

    // Start Advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issues
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("BLE advertising started. Waiting for connections...");
}

void loop() {
    // Handle connection state changes for auto-restart advertising
    if (!deviceConnected && oldDeviceConnected) {
        delay(500); // Give the BLE stack time to get ready
        pServer->startAdvertising(); // Restart advertising
        Serial.println("Restarted BLE advertising.");
        oldDeviceConnected = deviceConnected;
    }
    
    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }

    if (deviceConnected) {
        // Stabilization logic
        // Yaw output: follows commanded yaw
        float final_yaw = yaw_cmd_deg;

        // Pitch & Roll output: commanded value + stabBlend * MPU6050 leveling correction
        float final_pitch = pitch_cmd_deg + (stabBlend * MOCK_MPU_CORRECTION_PITCH);
        float final_roll  = roll_cmd_deg  + (stabBlend * MOCK_MPU_CORRECTION_ROLL);

        // Clamp final stabilized angles to prevent servo over-travel
        final_yaw   = clampAngle(final_yaw, AXIS_MIN, AXIS_MAX);
        final_pitch = clampAngle(final_pitch, AXIS_MIN, AXIS_MAX);
        final_roll  = clampAngle(final_roll, AXIS_MIN, AXIS_MAX);

        // Map stabilized angles to servo pulse widths (500us - 2500us)
        yaw_pulse_us   = mapAngleToServoPulse(final_yaw);
        pitch_pulse_us = mapAngleToServoPulse(final_pitch);
        roll_pulse_us  = mapAngleToServoPulse(final_roll);

        // Send telemetry / status update notification
        static unsigned long lastNotifyTime = 0;
        unsigned long currentMillis = millis();
        if (currentMillis - lastNotifyTime >= 1000) {
            char statusPayload[64];
            snprintf(statusPayload, sizeof(statusPayload), "Y:%d P:%d R:%d", yaw_pulse_us, pitch_pulse_us, roll_pulse_us);
            
            pTxCharacteristic->setValue(statusPayload);
            pTxCharacteristic->notify();
            
            Serial.printf("Sent BLE Status Notify: %s (Blend: %.2f)\n", statusPayload, stabBlend);
            lastNotifyTime = currentMillis;
        }
    }

    delay(10);
}
