import Foundation

public struct Note: Identifiable, Codable {
    public let id: String
    public let sessionId: String
    public let userId: String
    public let content: String
    public let createdAt: Date
    public let turnNumber: Int
    
    public init(id: String = UUID().uuidString,
                sessionId: String,
                userId: String,
                content: String,
                createdAt: Date = Date(),
                turnNumber: Int) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.turnNumber = turnNumber
    }
}
