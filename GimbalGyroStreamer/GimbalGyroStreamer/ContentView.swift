import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var gyroService = GyroStreamService()
    
    @State private var targetHost: String = "192.168.4.1"
    @State private var streamRate: Int = 20
    @Environment(\.scenePhase) private var scenePhase
    
    private let availableRates = [10, 20, 50]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                StatusPillView(status: webSocketManager.connectionState)
                
                // Target Host Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Host")
                        .font(.headline)
                    TextField("IP Address", text: $targetHost)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .autocapitalization(.none)
                        .disabled(webSocketManager.connectionState != .disconnected)
                }
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
                    .disabled(webSocketManager.connectionState != .disconnected)
                }
                .padding(.horizontal)
                
                // Connect/Disconnect Button
                Button(action: {
                    if webSocketManager.connectionState == .disconnected {
                        connect()
                    } else {
                        disconnect()
                    }
                }) {
                    Text(webSocketManager.connectionState == .disconnected ? "Connect" : "Disconnect")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(webSocketManager.connectionState == .disconnected ? Color.blue : Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(webSocketManager.connectionState == .connecting)
                
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
                if let error = webSocketManager.lastError {
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
                    if webSocketManager.connectionState != .disconnected {
                        disconnect()
                    }
                }
            }
        }
    }
    
    private func connect() {
        guard let url = validateAndCreateURL(from: targetHost) else {
            webSocketManager.lastError = "Invalid host address"
            return
        }
        
        webSocketManager.connect(to: url)
        gyroService.startStreaming(rate: streamRate, webSocketManager: webSocketManager)
    }
    
    private func disconnect() {
        gyroService.stopStreaming()
        webSocketManager.disconnect()
    }
    
    private func validateAndCreateURL(from host: String) -> URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        
        if trimmedHost.isEmpty {
            return nil
        }
        
        let urlString = "ws://\(trimmedHost)/ws"
        return URL(string: urlString)
    }
}

struct StatusPillView: View {
    let status: ConnectionState
    
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
