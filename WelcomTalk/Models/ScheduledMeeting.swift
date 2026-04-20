import Foundation

/// A proposed or confirmed follow-up meeting between the two session parties.
///
/// Proposals are sent over Multipeer as a JSON-encoded payload inside a `"schedule-proposal"` command.
/// When the other party accepts, a `"schedule-confirmed"` command fires back and both devices
/// add the event to their iOS Calendar via EventKit.
public struct ScheduledMeeting: Identifiable, Codable {
    public let id: String
    public var title: String
    public var scheduledDate: Date
    public var durationMinutes: Int
    public var proposedByUserId: String
    public var proposedByName: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        scheduledDate: Date,
        durationMinutes: Int = 60,
        proposedByUserId: String,
        proposedByName: String
    ) {
        self.id = id
        self.title = title
        self.scheduledDate = scheduledDate
        self.durationMinutes = durationMinutes
        self.proposedByUserId = proposedByUserId
        self.proposedByName = proposedByName
    }

    public var endDate: Date {
        scheduledDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    public var formattedDateTime: String {
        scheduledDate.formatted(date: .abbreviated, time: .shortened)
    }

    public var formattedDuration: String {
        durationMinutes < 60
            ? "\(durationMinutes) min"
            : durationMinutes == 60
                ? "1 hour"
                : "\(durationMinutes / 60)h \(durationMinutes % 60 > 0 ? "\(durationMinutes % 60) min" : "")"
    }

    // MARK: - Multipeer payload encoding

    public func encodePayload() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    public static func decode(from payload: String) -> ScheduledMeeting? {
        guard let data = payload.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ScheduledMeeting.self, from: data)
    }
}
