import Foundation

/// A lightweight protocol representing a structured debate or session engine.
///
/// The current app implements a two-party, equal-time conversation flow. This
/// protocol allows the session view model to be treated as a debate-session
/// engine while preserving the existing turn-based behavior.
public protocol DebateSessionProtocol: AnyObject {
    var session: Session? { get }
    var isMyTurn: Bool { get }
    var drivesSessionClock: Bool { get }

    func startSession()
    func pauseSession()
    func resumeSession()
    func endSession()
    func extendGrace()
}
