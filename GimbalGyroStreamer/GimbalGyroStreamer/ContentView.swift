import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var gyroService = GyroStreamService()
    
    @State private var streamRate: Int = 20
    @Environment(\.scenePhase) private var scenePhase
    
    private let availableRates = [10, 20, 50]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                StatusPillView(status: bleManager.connectionState)
                
                // Device Info Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Gimbal")
                        .font(.headline)
                    Text("Device Name: Gimbal-ESP32")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Service UUID: 19B10000-E8F2-537E...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Stream Rate Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stream Rate")
                        .font(.headline)
                    Picker("Rate", selection: $streamRate) {
                        ForEach(availableRates, id: \.self) { rate in
                            Text("\(rate) Hz").tag(rate)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(bleManager.connectionState != .disconnected)
                }
                .padding(.horizontal)
                
                // Connect/Disconnect/Scan Button
                Button(action: {
                    handleActionButton()
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(buttonColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(bleManager.connectionState == .connecting)
                
                // Gimbal Status (from TX Status Characteristic)
                if bleManager.connectionState == .connected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gimbal Status Feed")
                            .font(.headline)
                        Text(bleManager.statusMessage)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                // Statistics
                VStack(spacing: 12) {
                    StatRow(label: "Packets Sent", value: "\(gyroService.packetCount)")
                    
                    if let lastGyro = gyroService.lastGyroData {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Gyro Data")
                                .font(.headline)
                            Text("X: \(String(format: "%.4f", lastGyro.gx)) rad/s")
                                .font(.system(.body, design: .monospaced))
                            Text("Y: \(String(format: "%.4f", lastGyro.gy)) rad/s")
                                .font(.system(.body, design: .monospaced))
                            Text("Z: \(String(format: "%.4f", lastGyro.gz)) rad/s")
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Error Display
                if let error = bleManager.lastError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Gimbal Gyro Streamer")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background || newPhase == .inactive {
                    if bleManager.connectionState != .disconnected {
                        disconnect()
                    }
                }
            }
            .onChange(of: bleManager.connectionState) { newState in
                if newState == .connected {
                    gyroService.startStreaming(rate: streamRate, bleManager: bleManager)
                } else if newState == .disconnected {
                    gyroService.stopStreaming()
                }
            }
        }
    }
    
    private var buttonText: String {
        switch bleManager.connectionState {
        case .disconnected:
            return "Connect"
        case .scanning:
            return "Scanning... Tap to Stop"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Disconnect"
        }
    }
    
    private var buttonColor: Color {
        switch bleManager.connectionState {
        case .disconnected:
            return .blue
        case .scanning:
            return .orange
        case .connecting:
            return .gray
        case .connected:
            return .red
        }
    }
    
    private func handleActionButton() {
        switch bleManager.connectionState {
        case .disconnected:
            connect()
        case .scanning:
            bleManager.stopScanning()
        case .connecting:
            break
        case .connected:
            disconnect()
        }
    }
    
    private func connect() {
        bleManager.startScanning()
    }
    
    private func disconnect() {
        bleManager.disconnect()
    }
}

struct StatusPillView: View {
    let status: BLEConnectionState
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.2))
        .cornerRadius(20)
    }
    
    private var statusText: String {
        switch status {
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Streaming"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .disconnected:
            return .gray
        case .scanning:
            return .blue
        case .connecting:
            return .orange
        case .connected:
            return .green
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
