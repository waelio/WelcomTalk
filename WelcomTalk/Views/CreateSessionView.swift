import SwiftUI
import CoreNFC

struct CreateSessionView: View {
    private enum Field {
        case sessionTitle
        case userName
    }

    @Environment(\.dismiss) var dismiss
    @StateObject private var nfcManager = NFCSessionManager()
    @State private var sessionTitle: String = ""
    @State private var userName: String = ""
    @State private var maxTurns: Int = 10
    @State private var turnDuration: TimeInterval = 120
    @State private var createdSession: Session?
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Conversation Setup") {
                    TextField("Topic (e.g., Family Discussion)", text: $sessionTitle)
                        .textContentType(.none)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .sessionTitle)

                    TextField("Your Name", text: $userName)
                        .textContentType(.name)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .userName)
                    
                    Picker("Number of Turns", selection: $maxTurns) {
                        ForEach([5, 10, 15, 20], id: \.self) { turns in
                            Text("\(turns) turns each").tag(turns)
                        }
                    }
                    
                    Picker("Time Per Turn", selection: $turnDuration) {
                        Text("1 minute").tag(TimeInterval(60))
                        Text("2 minutes").tag(TimeInterval(120))
                        Text("3 minutes").tag(TimeInterval(180))
                        Text("5 minutes").tag(TimeInterval(300))
                    }
                }
                
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(icon: "timer", color: .blue, text: "Both people get equal, timed turns to speak")
                        InstructionRow(icon: "mic.slash", color: .red, text: "Only one person can talk at a time - no interruptions")
                        InstructionRow(icon: "square.and.arrow.up", color: .blue, text: "This phone shares the first code")
                        InstructionRow(icon: "person.wave.2.fill", color: .green, text: "When the other phone joins, tap \"Let Them In\" to approve them")
                        InstructionRow(icon: "play.circle.fill", color: .orange, text: "Both countdowns start immediately once you approve")
                    }
                }
                
                Section {
                    Button(action: createSession) {
                        HStack {
                            Spacer()
                            Text("Start Conversation")
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(sessionTitle.isEmpty || userName.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Start a Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissKeyboard()
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $createdSession) { session in
                NavigationStack {
                    SessionView(sessionViewModel: SessionViewModel(
                        session: session,
                        userId: session.partyAId,
                        userName: userName,
                        isHost: true
                    ))
                }
            }
        }
    }
    
    private func createSession() {
        dismissKeyboard()
        let userId = UUID().uuidString
        let sessionCode = SessionViewModel.generateCode()
        
        let session = Session(
            title: sessionTitle,
            sessionCode: sessionCode,
            status: .waiting,
            currentTurn: .partyA,
            currentTurnNumber: 1,
            maxTurns: maxTurns,
            turnDuration: turnDuration,
            partyAId: userId,
            partyBId: "",
            turnStartedAt: nil
        )
        
        createdSession = session
    }
    
    private func dismissKeyboard() {
        focusedField = nil
    }
}

private struct InstructionRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .frame(width: 18)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    CreateSessionView()
}
