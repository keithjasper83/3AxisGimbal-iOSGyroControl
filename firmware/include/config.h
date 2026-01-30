#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration (ESP32 as Access Point)
#define WIFI_SSID "Gimbal-AP"
#define WIFI_PASSWORD "gimbal123"

// Phone Gyro Control Gains
// These multiply the incoming phone gyro rates (rad/s) to control gimbal speed
#define PHONE_GYRO_GAIN_X 1.0f    // Pitch axis gain
#define PHONE_GYRO_GAIN_Y 1.0f    // Roll axis gain
#define PHONE_GYRO_GAIN_Z 1.0f    // Yaw axis gain

// Phone Gyro Deadband (rad/s)
// Gyro rates below this threshold are ignored to reduce noise/drift
#define PHONE_GYRO_DEADBAND_RAD_S 0.01f

// Phone Gyro Timeout (milliseconds)
// If no gyro data received within this time, automatically return to AUTO mode
#define PHONE_GYRO_TIMEOUT_MS 1000

// WebSocket Configuration
#define WS_PORT 80
#define WS_PATH "/ws"

#endif // CONFIG_H
