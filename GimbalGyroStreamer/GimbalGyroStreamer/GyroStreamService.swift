import Foundation
import CoreMotion
import Combine

struct GyroData {
    let gx: Double
    let gy: Double
    let gz: Double
}

class GyroStreamService: ObservableObject {
    @Published var packetCount: Int = 0
    @Published var lastGyroData: GyroData?
    
    private let motionManager = CMMotionManager()
    private var streamTimer: Timer?
    private weak var webSocketManager: WebSocketManager?
    
    func startStreaming(rate: Int, webSocketManager: WebSocketManager) {
        self.webSocketManager = webSocketManager
        
        guard motionManager.isGyroAvailable else {
            print("Gyroscope not available")
            return
        }
        
        // Reset counter
        packetCount = 0
        
        // Configure motion manager
        motionManager.gyroUpdateInterval = 1.0 / Double(rate)
        
        // Start gyro updates
        motionManager.startGyroUpdates()
        
        // Start streaming timer
        let interval = 1.0 / Double(rate)
        streamTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendGyroData()
        }
    }
    
    func stopStreaming() {
        streamTimer?.invalidate()
        streamTimer = nil
        motionManager.stopGyroUpdates()
        webSocketManager = nil
    }
    
    private func sendGyroData() {
        guard let gyroData = motionManager.gyroData else { return }
        
        let rotationRate = gyroData.rotationRate
        let data = GyroData(gx: rotationRate.x, gy: rotationRate.y, gz: rotationRate.z)
        
        // Update UI
        DispatchQueue.main.async {
            self.lastGyroData = data
            self.packetCount += 1
        }
        
        // Send to WebSocket
        let json: [String: Any] = [
            "cmd": "setPhoneGyro",
            "gx": data.gx,
            "gy": data.gy,
            "gz": data.gz
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocketManager?.sendMessage(jsonString)
        }
    }
}
