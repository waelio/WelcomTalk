import Foundation
import Combine

/// WebSocket service to connect to waelio-messaging backend
class WebSocketService: NSObject, ObservableObject {
    static let customServerURLKey = "welcomtalk.messaging.serverURL"

    @Published var isConnected = false
    @Published var clientId: String?
    @Published var receivedMessages: [Message] = []
    @Published var onlineUsers: [String] = []
    @Published var error: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let serverURL: String
    private let userId: String
    private let userName: String
    
    struct Message: Identifiable {
        let id = UUID()
        let from: String
        let payload: String
        let isBroadcast: Bool
        let timestamp: Date
    }
    
    struct OutgoingMessage: Codable {
        let type: String
        let to: String?
        let payload: String
    }

    static var defaultServerURL: String {
        #if targetEnvironment(simulator)
        return "ws://localhost:8080"
        #else
        return "wss://waelio-messaging.onrender.com"
        #endif
    }

    static var configuredServerURL: String {
        if let savedURL = UserDefaults.standard.string(forKey: customServerURLKey),
           !savedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedURL
        }

        return defaultServerURL
    }
    
    init(serverURL: String? = nil, userId: String, userName: String) {
        self.serverURL = serverURL ?? Self.configuredServerURL
        self.userId = userId
        self.userName = userName
        super.init()
        
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }
    
    // MARK: - Connection
    
    func connect() {
        guard let url = URL(string: serverURL) else {
            error = "Invalid server URL"
            return
        }
        
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
    
    // MARK: - Sending Messages
    
    func sendDirectMessage(to userId: String, content: String) {
        let msg = OutgoingMessage(type: "route", to: userId, payload: content)
        sendMessage(msg)
    }
    
    func sendBroadcast(content: String) {
        let msg = OutgoingMessage(type: "broadcast", to: nil, payload: content)
        sendMessage(msg)
    }
    
    private func sendMessage(_ message: OutgoingMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            error = "Failed to encode message"
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(wsMessage) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = "Send error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Receiving Messages
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue listening
                self.receiveMessage()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.error = "Receive error: \(error.localizedDescription)"
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "register-success":
            DispatchQueue.main.async {
                self.clientId = json["id"] as? String
                self.isConnected = true
                self.error = nil
            }

        case "user-list":
            let users = json["users"] as? [String] ?? []
            DispatchQueue.main.async {
                self.onlineUsers = users
            }

        case "message":
            guard let from = json["from"] as? String,
                  let payload = json["payload"] as? String else {
                return
            }

            let message = Message(
                from: from,
                payload: payload,
                isBroadcast: json["isBroadcast"] as? Bool ?? false,
                timestamp: Date()
            )

            DispatchQueue.main.async {
                self.receivedMessages.append(message)
            }

        case "error":
            DispatchQueue.main.async {
                self.error = json["message"] as? String ?? "Unknown WebSocket error"
            }

        default:
            break
        }
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.error = nil
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}
