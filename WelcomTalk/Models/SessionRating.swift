import Foundation

public struct SessionRating: Codable, Identifiable {
    public let id: String
    public let sessionId: String
    public let userId: String
    public let overallRating: Int // 1-5 stars
    public let respectfulnessRating: Int // 1-5 stars
    public let agreementReached: Bool
    public let wouldNegotiateAgain: Bool
    public let feedback: String?
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        userId: String,
        overallRating: Int,
        respectfulnessRating: Int,
        agreementReached: Bool,
        wouldNegotiateAgain: Bool,
        feedback: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.overallRating = overallRating
        self.respectfulnessRating = respectfulnessRating
        self.agreementReached = agreementReached
        self.wouldNegotiateAgain = wouldNegotiateAgain
        self.feedback = feedback
        self.createdAt = createdAt
    }
}
