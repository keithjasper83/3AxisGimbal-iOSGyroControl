#ifndef CONFIG_H
#define CONFIG_H

// BLE Configuration
#define BLE_DEVICE_NAME "Gimbal-ESP32"
#define BLE_SERVICE_UUID        "19B10000-E8F2-537E-4F6C-D104768A1214"
#define BLE_RX_CHAR_UUID        "19B10001-E8F2-537E-4F6C-D104768A1214"
#define BLE_TX_CHAR_UUID        "19B10002-E8F2-537E-4F6C-D104768A1214"

// Gyro Control gain
#define GYRO_GAIN 20.0f

// Axis clamp values (degrees)
#define AXIS_MIN -180.0f
#define AXIS_MAX 180.0f

// Servo pulse mapping (microseconds)
#define SERVO_MIN_PULSE_US 500
#define SERVO_MAX_PULSE_US 2500

// Stabilization blend factor (0.0 to 1.0)
// 0.0 = manual-only behavior
// 1.0 = full leveling assist
#define DEFAULT_STAB_BLEND 0.5f

// Mock MPU6050 Leveling correction values (for testing purposes)
#define MOCK_MPU_CORRECTION_PITCH 10.0f
#define MOCK_MPU_CORRECTION_ROLL -5.0f

#endif // CONFIG_H
