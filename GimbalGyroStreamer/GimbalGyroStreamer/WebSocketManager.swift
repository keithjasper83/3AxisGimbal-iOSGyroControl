import Foundation
import Combine

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect(to url: URL) {
        guard connectionState == .disconnected else { return }
        
        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.lastError = nil
        }
        
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        // Send manual mode command
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendModeCommand(mode: 0)
        }
    }
    
    func disconnect() {
        sendModeCommand(mode: 1) // Return to auto mode
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
        }
    }
    
    func sendMessage(_ message: String) {
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(wsMessage) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.lastError = "Send error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func sendModeCommand(mode: Int) {
        let json = ["cmd": "setMode", "mode": mode] as [String : Any]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.lastError = "Failed to create mode command"
            }
            return
        }
        sendMessage(jsonString)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success:
                self?.receiveMessage()
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.lastError = "Receive error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
}
