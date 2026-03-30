import Foundation

struct ScheduledMeeting: Identifiable, Codable {
    let id: String
    var title: String
    var scheduledDate: Date
    var durationMinutes: Int
    var proposedByUserId: String
    var proposedByName: String

    init(
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

    var endDate: Date {
        scheduledDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var formattedDateTime: String {
        scheduledDate.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedDuration: String {
        durationMinutes < 60
            ? "\(durationMinutes) min"
            : durationMinutes == 60
                ? "1 hour"
                : "\(durationMinutes / 60)h \(durationMinutes % 60 > 0 ? "\(durationMinutes % 60) min" : "")"
    }

    // MARK: - Multipeer payload encoding

    func encodePayload() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    static func decode(from payload: String) -> ScheduledMeeting? {
        guard let data = payload.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ScheduledMeeting.self, from: data)
    }
}
