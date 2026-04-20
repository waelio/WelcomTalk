import Foundation

public struct LogEntry: Identifiable, Codable {
    public let id: String
    public let sessionId: String
    public let type: LogType
    public let message: String
    public let timestamp: Date
    public let metadata: [String: String]?
    
    public enum LogType: String, Codable {
        case sessionStarted
        case sessionEnded
        case claimRecorded
        case communicationModeSelected
        case evidenceAdded
        case documentAttached
        case turnStarted
        case turnEnded
        case turnTranscription
        case modificationRequested
        case modificationApproved
        case modificationDenied
        case noteAdded
        case pause
        case resume
        case userJoined
        case userLeft
    }
    
    public init(id: String = UUID().uuidString,
                sessionId: String,
                type: LogType,
                message: String,
                timestamp: Date = Date(),
                metadata: [String: String]? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.type = type
        self.message = message
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
