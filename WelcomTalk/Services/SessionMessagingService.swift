import Foundation
import Combine

/// Manages real-time session synchronization using waelio-messaging
class SessionMessagingService: ObservableObject {
    @Published var joinAnnouncement: SessionSyncMessage?
    @Published var sessionState: SessionSyncMessage?
    
    private let webSocket: WebSocketService
    private let sessionCode: String
    private var cancellables = Set<AnyCancellable>()
    
    struct SessionSyncMessage: Codable {
        let type: String // "join-session", "session-state", "turn-update", "request", "command"
        let sessionCode: String
        let userId: String
        let userName: String?
        let isHost: Bool?
        let confirmationCode: String?
        let session: SessionData?
        let requestType: String?
        let payload: String? // arbitrary command data (e.g. JSON-encoded ScheduledMeeting)

        init(
            type: String,
            sessionCode: String,
            userId: String,
            userName: String?,
            isHost: Bool?,
            confirmationCode: String?,
            session: SessionData?,
            requestType: String?,
            payload: String? = nil
        ) {
            self.type = type
            self.sessionCode = sessionCode
            self.userId = userId
            self.userName = userName
            self.isHost = isHost
            self.confirmationCode = confirmationCode
            self.session = session
            self.requestType = requestType
            self.payload = payload
        }
        
        struct SessionData: Codable {
            let title: String
            let currentTurn: String
            let currentTurnNumber: Int
            let maxTurns: Int
            let turnDuration: Double
            let timeRemaining: Double
            let status: String
            let partyAId: String
            let partyBId: String
            let graceTimeRemaining: Double
            let isInGracePeriod: Bool
        }
    }
    
    init(webSocket: WebSocketService, sessionCode: String) {
        self.webSocket = webSocket
        self.sessionCode = sessionCode
        
        // Listen for incoming messages
        webSocket.$receivedMessages
            .sink { [weak self] messages in
                guard let self = self, let lastMessage = messages.last else { return }
                self.handleIncomingMessage(lastMessage)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Actions
    
    func announceSession(userId: String, userName: String, isHost: Bool, confirmationCode: String?) {
        let message = SessionSyncMessage(
            type: "join-session",
            sessionCode: sessionCode,
            userId: userId,
            userName: userName,
            isHost: isHost,
            confirmationCode: confirmationCode,
            session: nil,
            requestType: nil
        )
        
        sendSessionMessage(message)
    }
    
    func broadcastSessionState(
        userId: String,
        title: String,
        currentTurn: String,
        currentTurnNumber: Int,
        maxTurns: Int,
        turnDuration: Double,
        timeRemaining: Double,
        status: String,
        partyAId: String,
        partyBId: String,
        graceTimeRemaining: Double,
        isInGracePeriod: Bool
    ) {
        let sessionData = SessionSyncMessage.SessionData(
            title: title,
            currentTurn: currentTurn,
            currentTurnNumber: currentTurnNumber,
            maxTurns: maxTurns,
            turnDuration: turnDuration,
            timeRemaining: timeRemaining,
            status: status,
            partyAId: partyAId,
            partyBId: partyBId,
            graceTimeRemaining: graceTimeRemaining,
            isInGracePeriod: isInGracePeriod
        )
        
        let message = SessionSyncMessage(
            type: "session-state",
            sessionCode: sessionCode,
            userId: userId,
            userName: nil,
            isHost: nil,
            confirmationCode: nil,
            session: sessionData,
            requestType: nil
        )
        
        sendSessionMessage(message)
    }
    
    func sendModificationRequest(userId: String, requestType: String) {
        let message = SessionSyncMessage(
            type: "request",
            sessionCode: sessionCode,
            userId: userId,
            userName: nil,
            isHost: nil,
            confirmationCode: nil,
            session: nil,
            requestType: requestType
        )
        
        sendSessionMessage(message)
    }
    
    // MARK: - Internal
    
    private func sendSessionMessage(_ message: SessionSyncMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        webSocket.sendBroadcast(content: jsonString)
    }
    
    private func handleIncomingMessage(_ message: WebSocketService.Message) {
        // Try to decode as session sync message
        guard let data = message.payload.data(using: .utf8),
              let syncMessage = try? JSONDecoder().decode(SessionSyncMessage.self, from: data) else {
            return
        }
        
        // Only process messages for this session
        guard syncMessage.sessionCode == sessionCode else { return }
        
        switch syncMessage.type {
        case "join-session":
            joinAnnouncement = syncMessage
            
        case "session-state":
            sessionState = syncMessage
            
        default:
            break
        }
    }
}
