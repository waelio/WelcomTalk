import SwiftUI

struct ScheduleMeetingView: View {
    let sessionTitle: String
    let myUserId: String
    let myName: String
    let onPropose: (ScheduledMeeting) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var scheduledDate: Date
    @State private var durationMinutes = 60

    private static let durations = [30, 60, 90, 120]

    init(sessionTitle: String, myUserId: String, myName: String, onPropose: @escaping (ScheduledMeeting) -> Void) {
        self.sessionTitle = sessionTitle
        self.myUserId = myUserId
        self.myName = myName
        self.onPropose = onPropose
        _title = State(initialValue: sessionTitle)
        // Default to tomorrow at the next round hour
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: tomorrow)
        let roundedHour = Calendar.current.date(from: components) ?? tomorrow
        _scheduledDate = State(initialValue: roundedHour)
    }

    var body: some View {
        Form {
            Section("Meeting Details") {
                TextField("Title", text: $title)

                DatePicker(
                    "Date & Time",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Picker("Duration", selection: $durationMinutes) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Proposed by you (\(myName))", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("The other party will see your proposal and can add it to their calendar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    let meeting = ScheduledMeeting(
                        title: title,
                        scheduledDate: scheduledDate,
                        durationMinutes: durationMinutes,
                        proposedByUserId: myUserId,
                        proposedByName: myName
                    )
                    onPropose(meeting)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Label("Send Proposal", systemImage: "calendar.badge.plus")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Schedule Next Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
