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
        // Set update interval slightly faster than streaming rate for fresh data
        motionManager.gyroUpdateInterval = 0.9 / Double(rate)
        
        // Start gyro updates
        motionManager.startGyroUpdates()
        
        // Start streaming timer on main RunLoop
        let interval = 1.0 / Double(rate)
        streamTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendGyroData()
        }
        
        // Ensure timer runs on main RunLoop
        if let timer = streamTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopStreaming() {
        streamTimer?.invalidate()
        streamTimer = nil
        motionManager.stopGyroUpdates()
        webSocketManager = nil
    }
    
    private func sendGyroData() {
        guard let gyroData = motionManager.gyroData else {
            // Don't increment counter if no data available
            return
        }
        
        let rotationRate = gyroData.rotationRate
        let data = GyroData(gx: rotationRate.x, gy: rotationRate.y, gz: rotationRate.z)
        
        // Send to WebSocket
        let json: [String: Any] = [
            "cmd": "setPhoneGyro",
            "gx": data.gx,
            "gy": data.gy,
            "gz": data.gz
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to serialize gyro data to JSON")
            return
        }
        
        webSocketManager?.sendMessage(jsonString)
        
        // Only increment counter after successful send
        DispatchQueue.main.async {
            self.lastGyroData = data
            self.packetCount += 1
        }
    }
}
