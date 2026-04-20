import Foundation

/// Represents a single structured conversation session between two parties.
/// Both parties alternate timed speaking turns; the session ends when all rounds are complete.
public struct Session: Identifiable, Codable {
    public let id: String
    public var title: String
    public var sessionCode: String
    public var status: SessionStatus
    public var currentTurn: TurnParty
    public var currentTurnNumber: Int
    /// Number of speaking rounds **per party**. Total turns across both parties = `maxTurns × 2`.
    public var maxTurns: Int
    /// Total turn slots across both parties combined (derived from `maxTurns`).
    public var totalTurns: Int { maxTurns * 2 }
    public var turnDuration: TimeInterval
    public var partyAId: String
    public var partyBId: String
    public var partyAName: String
    public var partyBName: String
    public var createdAt: Date
    public var turnStartedAt: Date?

    public enum SessionStatus: String, Codable {
        case waiting
        case active
        case paused
        case completed
    }

    public enum TurnParty: String, Codable {
        case partyA
        case partyB

        public var displayName: String {
            switch self {
            case .partyA: return "Party A"
            case .partyB: return "Party B"
            }
        }
    }

    public func name(for party: TurnParty) -> String {
        switch party {
        case .partyA: return partyAName
        case .partyB: return partyBName
        }
    }

    public init(id: String = UUID().uuidString,
                title: String,
                sessionCode: String,
                status: SessionStatus = .waiting,
                currentTurn: TurnParty = .partyA,
                currentTurnNumber: Int = 1,
                maxTurns: Int = 2,
                turnDuration: TimeInterval = 120,
                partyAId: String,
                partyBId: String,
                partyAName: String = "Party A",
                partyBName: String = "Party B",
                createdAt: Date = Date(),
                turnStartedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.sessionCode = sessionCode
        self.status = status
        self.currentTurn = currentTurn
        self.currentTurnNumber = currentTurnNumber
        self.maxTurns = maxTurns
        self.turnDuration = turnDuration
        self.partyAId = partyAId
        self.partyBId = partyBId
        self.partyAName = partyAName
        self.partyBName = partyBName
        self.createdAt = createdAt
        self.turnStartedAt = turnStartedAt
    }
}
