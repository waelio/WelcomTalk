import Foundation

public struct User: Identifiable, Codable {
    public let id: String
    public let displayName: String
    public let joinedAt: Date
    
    public init(id: String = UUID().uuidString,
                displayName: String,
                joinedAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.joinedAt = joinedAt
    }
}
