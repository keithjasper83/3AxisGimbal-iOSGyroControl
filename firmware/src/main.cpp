#include <Arduino.h>
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include "config.h"

// Control mode enum
enum ControlMode {
    MODE_AUTO = 1,      // Automatic gimbal control
    MODE_MANUAL = 0     // Manual control via phone gyro
};

// Global state
AsyncWebServer server(WS_PORT);
AsyncWebSocket ws(WS_PATH);
ControlMode currentMode = MODE_AUTO;
unsigned long lastPhoneGyroTime = 0;

// Current phone gyro rates (rad/s)
float phoneGyroX = 0.0f;
float phoneGyroY = 0.0f;
float phoneGyroZ = 0.0f;

// Function prototypes
void setupWiFi();
void setupWebSocket();
void handleWebSocketMessage(void *arg, uint8_t *data, size_t len);
void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type,
               void *arg, uint8_t *data, size_t len);
void processPhoneGyro();
void checkGyroTimeout();
void setMode(ControlMode mode);
void applyDeadband(float &value);

void setup() {
    Serial.begin(115200);
    Serial.println("\n=== Gimbal Gyro Streamer Firmware ===");
    
    setupWiFi();
    setupWebSocket();
    
    Serial.println("Setup complete. Ready for connections.");
    Serial.printf("Connect to WiFi: %s\n", WIFI_SSID);
    Serial.printf("WebSocket URL: ws://%s%s\n", WiFi.softAPIP().toString().c_str(), WS_PATH);
}

void loop() {
    ws.cleanupClients();
    
    if (currentMode == MODE_MANUAL) {
        processPhoneGyro();
        checkGyroTimeout();
    }
    
    delay(10);
}

void setupWiFi() {
    Serial.println("Setting up WiFi Access Point...");
    
    WiFi.mode(WIFI_AP);
    WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);
    
    IPAddress IP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(IP);
}

void setupWebSocket() {
    ws.onEvent(onWsEvent);
    server.addHandler(&ws);
    server.begin();
    
    Serial.println("WebSocket server started");
}

void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type,
               void *arg, uint8_t *data, size_t len) {
    switch (type) {
        case WS_EVT_CONNECT:
            Serial.printf("WebSocket client #%u connected from %s\n", 
                         client->id(), client->remoteIP().toString().c_str());
            break;
            
        case WS_EVT_DISCONNECT:
            Serial.printf("WebSocket client #%u disconnected\n", client->id());
            // Auto return to AUTO mode on disconnect
            setMode(MODE_AUTO);
            break;
            
        case WS_EVT_DATA:
            handleWebSocketMessage(arg, data, len);
            break;
            
        case WS_EVT_PONG:
        case WS_EVT_ERROR:
            break;
    }
}

void handleWebSocketMessage(void *arg, uint8_t *data, size_t len) {
    AwsFrameInfo *info = (AwsFrameInfo*)arg;
    
    if (info->final && info->index == 0 && info->len == len && info->opcode == WS_TEXT) {
        // Safely create null-terminated string without buffer overflow
        char buffer[256];
        size_t copyLen = min(len, sizeof(buffer) - 1);
        memcpy(buffer, data, copyLen);
        buffer[copyLen] = 0;
        
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, buffer);
        
        if (error) {
            Serial.print("JSON parse error: ");
            Serial.println(error.c_str());
            return;
        }
        
        const char* cmd = doc["cmd"];
        
        // Validate cmd is not null
        if (cmd == nullptr) {
            Serial.println("Error: Missing 'cmd' field in JSON");
            return;
        }
        
        if (strcmp(cmd, "setMode") == 0) {
            int mode = doc["mode"];
            // Validate mode value
            if (mode != MODE_MANUAL && mode != MODE_AUTO) {
                Serial.printf("Error: Invalid mode value: %d\n", mode);
                return;
            }
            setMode((ControlMode)mode);
            Serial.printf("Mode set to: %s\n", mode == MODE_MANUAL ? "MANUAL" : "AUTO");
        }
        else if (strcmp(cmd, "setPhoneGyro") == 0) {
            if (currentMode == MODE_MANUAL) {
                phoneGyroX = doc["gx"];
                phoneGyroY = doc["gy"];
                phoneGyroZ = doc["gz"];
                
                lastPhoneGyroTime = millis();
                
                // Apply deadband
                applyDeadband(phoneGyroX);
                applyDeadband(phoneGyroY);
                applyDeadband(phoneGyroZ);
                
                // Debug output (can be removed in production)
                static unsigned long lastPrint = 0;
                if (millis() - lastPrint > 1000) {
                    Serial.printf("Gyro: X=%.4f Y=%.4f Z=%.4f rad/s\n", 
                                 phoneGyroX, phoneGyroY, phoneGyroZ);
                    lastPrint = millis();
                }
            }
        }
    }
}

void processPhoneGyro() {
    // Apply gains to gyro rates
    float controlX = phoneGyroX * PHONE_GYRO_GAIN_X;
    float controlY = phoneGyroY * PHONE_GYRO_GAIN_Y;
    float controlZ = phoneGyroZ * PHONE_GYRO_GAIN_Z;
    
    // TODO: Send control commands to gimbal motors
    // This is where you would integrate with your gimbal control system
    // Example: setGimbalSpeed(controlX, controlY, controlZ);
}

void checkGyroTimeout() {
    // Only check timeout if we have received at least one gyro packet
    if (lastPhoneGyroTime > 0 && millis() - lastPhoneGyroTime > PHONE_GYRO_TIMEOUT_MS) {
        Serial.println("Phone gyro timeout - returning to AUTO mode");
        setMode(MODE_AUTO);
    }
}

void setMode(ControlMode mode) {
    currentMode = mode;
    
    if (mode == MODE_AUTO) {
        // Reset gyro values
        phoneGyroX = 0.0f;
        phoneGyroY = 0.0f;
        phoneGyroZ = 0.0f;
        
        // TODO: Return gimbal to automatic control
        // Example: enableAutoMode();
    }
}

void applyDeadband(float &value) {
    if (fabs(value) < PHONE_GYRO_DEADBAND_RAD_S) {
        value = 0.0f;
    }
}
