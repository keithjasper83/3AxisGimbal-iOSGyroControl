# Gimbal Gyro Streamer

Stream phone gyroscope data to ESP32 gimbal controller via WebSocket at configurable rates (10/20/50 Hz).

## Project Structure

```
.
├── GimbalGyroStreamer/          # iOS App (SwiftUI)
│   ├── GimbalGyroStreamer.xcodeproj/
│   └── GimbalGyroStreamer/
│       ├── GimbalGyroStreamerApp.swift
│       ├── ContentView.swift
│       ├── WebSocketManager.swift
│       ├── GyroStreamService.swift
│       ├── Info.plist
│       └── Assets.xcassets/
└── firmware/                    # ESP32 Firmware (PlatformIO)
    ├── platformio.ini
    ├── include/
    │   └── config.h
    └── src/
        └── main.cpp
```

## Features

### iOS App
- **WebSocket Connection**: Connect to ESP32 at configurable IP (default: 192.168.4.1)
- **Gyro Streaming**: Stream phone gyro data at 10/20/50 Hz (default: 20 Hz)
- **Connection Status**: Visual status indicator (Disconnected/Connecting/Streaming)
- **Statistics**: Packet counter and live gyro data display
- **Background Handling**: Automatically stops streaming and returns to auto mode

### ESP32 Firmware
- **WebSocket Server**: Listens on `/ws` endpoint
- **Mode Control**: Manual (phone control) / Auto (autonomous)
- **Configurable Parameters**:
  - `PHONE_GYRO_GAIN_X/Y/Z`: Sensitivity multipliers for each axis
  - `PHONE_GYRO_DEADBAND_RAD_S`: Noise threshold (default: 0.01 rad/s)
  - `PHONE_GYRO_TIMEOUT_MS`: Auto-return timeout (default: 1000 ms)

## Protocol

### WebSocket Messages (JSON)

**Start Manual Mode:**
```json
{"cmd":"setMode","mode":0}
```

**Return to Auto Mode:**
```json
{"cmd":"setMode","mode":1}
```

**Gyro Data (20 Hz default):**
```json
{"cmd":"setPhoneGyro","gx":0.012,"gy":-0.034,"gz":0.005}
```
- `gx`, `gy`, `gz`: Rotation rates in rad/s from `CMMotionManager`

## Setup Instructions

### ESP32 Firmware

1. **Install PlatformIO**:
   ```bash
   # Using pip
   pip install platformio
   
   # Or using Homebrew (macOS)
   brew install platformio
   ```

2. **Build and Upload**:
   ```bash
   cd firmware
   pio run -t upload
   ```

3. **Configure WiFi** (optional):
   Edit `firmware/include/config.h`:
   ```cpp
   #define WIFI_SSID "Gimbal-AP"
   #define WIFI_PASSWORD "gimbal123"
   ```

4. **Tune Gains** (optional):
   Edit `firmware/include/config.h`:
   ```cpp
   #define PHONE_GYRO_GAIN_X 1.0f
   #define PHONE_GYRO_GAIN_Y 1.0f
   #define PHONE_GYRO_GAIN_Z 1.0f
   #define PHONE_GYRO_DEADBAND_RAD_S 0.01f
   #define PHONE_GYRO_TIMEOUT_MS 1000
   ```

### iOS App

1. **Open in Xcode**:
   ```bash
   open GimbalGyroStreamer/GimbalGyroStreamer.xcodeproj
   ```

2. **Select Target Device**: Choose your iPhone/iPad

3. **Build and Run**: ⌘R or click the Run button

4. **Grant Permissions**: Allow motion sensor access when prompted

## Usage

1. **Power on ESP32**: It will create a WiFi Access Point
   - SSID: `Gimbal-AP`
   - Password: `gimbal123`
   - IP: `192.168.4.1`

2. **Connect iPhone to WiFi**: Join the `Gimbal-AP` network

3. **Launch App**: Open Gimbal Gyro Streamer

4. **Configure** (optional):
   - Target Host: Default is `192.168.4.1`
   - Stream Rate: Choose 10, 20, or 50 Hz

5. **Connect**: Tap "Connect" button
   - Status will show "Connecting" → "Streaming"
   - Packet counter will increment
   - Live gyro data will display

6. **Control Gimbal**: Move your phone to control the gimbal

7. **Disconnect**: Tap "Disconnect" to stop streaming

## Behavior

- **On Connect**: Opens WebSocket, sends manual mode command, starts gyro stream
- **On Background**: Stops stream, sends auto mode command, closes WebSocket
- **On Disconnect**: Same as background
- **On Timeout**: If no gyro data for 1 second, ESP32 returns to auto mode

## Troubleshooting

### ESP32 Firmware
- **Monitor Serial Output**:
  ```bash
  pio device monitor
  ```
- Check WiFi AP is active
- Verify IP address (should be 192.168.4.1)

### iOS App
- Ensure motion permissions are granted
- Check WiFi connection to ESP32 AP
- Verify target host IP matches ESP32
- Check error messages in app

## Development

### Adding Gimbal Control
To integrate with your gimbal hardware, modify `firmware/src/main.cpp`:

```cpp
void processPhoneGyro() {
    float controlX = phoneGyroX * PHONE_GYRO_GAIN_X;
    float controlY = phoneGyroY * PHONE_GYRO_GAIN_Y;
    float controlZ = phoneGyroZ * PHONE_GYRO_GAIN_Z;
    
    // Add your gimbal control code here
    setGimbalSpeed(controlX, controlY, controlZ);
}

void setMode(ControlMode mode) {
    currentMode = mode;
    
    if (mode == MODE_AUTO) {
        // Add your auto mode code here
        enableAutoMode();
    }
}
```

## License

MIT License - See LICENSE file for details
