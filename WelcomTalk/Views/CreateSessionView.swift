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
        NavigationView {
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
                        Text("• Both people get equal, timed turns to speak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Only one person can talk at a time - no interruptions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• This phone shares the first code")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• When the other phone joins, it turns to a new barcode for you to scan")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Scanning that new barcode starts the countdown on both phones")
                            .font(.caption)
                            .foregroundColor(.secondary)
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

#Preview {
    CreateSessionView()
}
