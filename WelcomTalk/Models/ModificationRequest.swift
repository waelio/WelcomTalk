import Foundation

public struct ModificationRequest: Identifiable, Codable {
    public let id: String
    public let sessionId: String
    public let requestingUserId: String
    public let type: ModificationType
    public let reason: String
    public var status: RequestStatus
    public let createdAt: Date
    public var respondedAt: Date?
    
    public enum ModificationType: String, Codable {
        case extendTurn
        case addTurn
        case pauseSession
        case resumeSession
        case endSession
        
        public var description: String {
            switch self {
            case .extendTurn: return "Extend Current Turn"
            case .addTurn: return "Add Extra Turn"
            case .pauseSession: return "Pause Session"
            case .resumeSession: return "Resume Session"
            case .endSession: return "End Session"
            }
        }
    }
    
    public enum RequestStatus: String, Codable {
        case pending
        case approved
        case denied
    }
    
    public init(id: String = UUID().uuidString,
                sessionId: String,
                requestingUserId: String,
                type: ModificationType,
                reason: String,
                status: RequestStatus = .pending,
                createdAt: Date = Date(),
                respondedAt: Date? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.requestingUserId = requestingUserId
        self.type = type
        self.reason = reason
        self.status = status
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }
}
