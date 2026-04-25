import Foundation

/// A cross-platform view model that exposes session details in display-friendly text.
///
/// This type is intentionally free of Apple-only frameworks so it can be reused by
/// SwiftUI, Tokamak, SwiftWasm, and test targets.
public struct SessionSummaryViewModel {
    public let session: Session

    public init(session: Session) {
        self.session = session
    }

    public var title: String {
        session.title
    }

    public var sessionCode: String {
        session.sessionCode
    }

    public var participantsLine: String {
        "\(session.partyAName) • \(session.partyBName)"
    }

    public var currentSpeakerName: String {
        session.name(for: session.currentTurn)
    }

    public var currentSpeakerRole: String {
        session.currentTurn.displayName
    }

    public var turnProgressText: String {
        "Turn \(min(session.currentTurnNumber, session.totalTurns)) of \(session.totalTurns)"
    }

    public var totalRoundsText: String {
        "\(session.maxTurns) equal rounds each"
    }

    public var fairnessLine: String {
        "Equal time for each participant • \(totalRoundsText) • \(turnDurationText)"
    }

    public var turnDurationText: String {
        Self.format(duration: session.turnDuration)
    }

    public var statusText: String {
        switch session.status {
        case .waiting:
            return "Waiting to start"
        case .active:
            return "Live now"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        }
    }

    public var accessibilitySummary: String {
        "\(title), code \(sessionCode), \(statusText), \(turnProgressText), current speaker \(currentSpeakerName), \(fairnessLine)."
    }

    private static func format(duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 && seconds == 0 {
            return minutes == 1 ? "1 minute per turn" : "\(minutes) minutes per turn"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s per turn"
        }

        return seconds == 1 ? "1 second per turn" : "\(seconds) seconds per turn"
    }
}