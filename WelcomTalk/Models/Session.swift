import Foundation

struct Session: Identifiable, Codable {
    let id: String
    var title: String
    var sessionCode: String
    var status: SessionStatus
    var currentTurn: TurnParty
    var currentTurnNumber: Int
    var maxTurns: Int
    var turnDuration: TimeInterval
    var partyAId: String
    var partyBId: String
    var partyAName: String
    var partyBName: String
    var createdAt: Date
    var turnStartedAt: Date?

    enum SessionStatus: String, Codable {
        case waiting
        case active
        case paused
        case completed
    }

    enum TurnParty: String, Codable {
        case partyA
        case partyB

        var displayName: String {
            switch self {
            case .partyA: return "Party A"
            case .partyB: return "Party B"
            }
        }
    }

    func name(for party: TurnParty) -> String {
        switch party {
        case .partyA: return partyAName
        case .partyB: return partyBName
        }
    }

    init(id: String = UUID().uuidString,
         title: String,
         sessionCode: String,
         status: SessionStatus = .waiting,
         currentTurn: TurnParty = .partyA,
         currentTurnNumber: Int = 1,
         maxTurns: Int = 10,
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
