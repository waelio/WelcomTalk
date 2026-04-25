import SwiftUI
import CoreNFC
import UniformTypeIdentifiers

struct CreateSessionView: View {
    private enum Field {
        case sessionTitle
        case userName
    }

    let initialPortalImport: PortalSessionImport?
    let autoStartOnAppear: Bool

    @Environment(\.dismiss) var dismiss
    @StateObject private var nfcManager = NFCSessionManager()
    @State private var sessionTitle: String = ""
    @State private var userName: String = ""
    @State private var claimText: String = ""
    @State private var requestedOutcome: String = ""
    @State private var communicationMode: SessionCaseFile.CommunicationMode = .structuredConversation
    @State private var evidenceTitle: String = ""
    @State private var evidenceDetail: String = ""
    @State private var evidenceItems: [DraftEvidenceItem] = []
    @State private var showingDocumentImporter = false
    @State private var documentImportError: String?
    @State private var portalImportError: String?
    @State private var isImportingPortalRequest = false
    /// Rounds per party. Total turn count = maxTurns × 2. Default: 2 rounds each (4 total).
    @State private var maxTurns: Int = 2
    /// Speaking time per turn in seconds. Default: 30 seconds.
    @State private var turnDuration: TimeInterval = 30
    @State private var createdSession: Session?
    @State private var hasAppliedInitialPortalImport = false
    @State private var hasAutoStartedImportedSession = false
    @FocusState private var focusedField: Field?

    init(initialPortalImport: PortalSessionImport? = nil, autoStartOnAppear: Bool = false) {
        self.initialPortalImport = initialPortalImport
        self.autoStartOnAppear = autoStartOnAppear
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Conversation Setup") {
                    TextField("Topic (e.g., Family Discussion)", text: $sessionTitle)
                        .textContentType(.none)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .sessionTitle)
                        .onChange(of: sessionTitle) { oldValue, newValue in
                            handlePotentialPortalPaste(newValue)
                        }

                    TextField("Your Name", text: $userName)
                        .textContentType(.name)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .userName)
                        .onChange(of: userName) { oldValue, newValue in
                            handlePotentialPortalPaste(newValue)
                        }
                    
                    Picker("Equal Rounds per Participant", selection: $maxTurns) {
                        Text("2 rounds each  (4 total)").tag(2)
                        Text("4 rounds each  (8 total)").tag(4)
                        Text("6 rounds each  (12 total)").tag(6)
                        Text("8 rounds each  (16 total)").tag(8)
                        Text("10 rounds each  (20 total)").tag(10)
                    }
                    
                    Picker("Equal Time per Turn", selection: $turnDuration) {
                        Text("30 seconds  (quick reply)").tag(TimeInterval(30))
                        Text("45 seconds  (standard reply)").tag(TimeInterval(45))
                        Text("50 seconds").tag(TimeInterval(50))
                        Text("1 minute").tag(TimeInterval(60))
                        Text("2 minutes").tag(TimeInterval(120))
                        Text("3 minutes").tag(TimeInterval(180))
                        Text("5 minutes").tag(TimeInterval(300))
                    }
                }

                Section("Conversation Focus & Supporting Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opening summary")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $claimText)
                            .frame(minHeight: 110)
                            .onChange(of: claimText) { oldValue, newValue in
                                handlePotentialPortalPaste(newValue)
                            }
                    }

                    TextField("Desired outcome or resolution", text: $requestedOutcome)
                        .textContentType(.none)
                        .onChange(of: requestedOutcome) { oldValue, newValue in
                            handlePotentialPortalPaste(newValue)
                        }

                    Picker("Communication Mode", selection: $communicationMode) {
                        ForEach(SessionCaseFile.CommunicationMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.symbolName)
                                .tag(mode)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add text evidence")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Evidence title", text: $evidenceTitle)
                            .textContentType(.none)

                        TextField("What does it prove?", text: $evidenceDetail)
                            .textContentType(.none)

                        Button {
                            addTextEvidence()
                        } label: {
                            Label("Add Text Evidence", systemImage: "plus.circle.fill")
                        }
                        .disabled(trimmed(evidenceTitle).isEmpty && trimmed(evidenceDetail).isEmpty)
                    }

                    Button {
                        showingDocumentImporter = true
                    } label: {
                        Label("Import Document Evidence", systemImage: "doc.badge.plus")
                    }

                    Text(communicationMode.documentationNote)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isImportingPortalRequest {
                        ProgressView("Importing portal barcode...")
                            .font(.caption)
                    }

                    if let portalImportError {
                        Text(portalImportError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if let documentImportError {
                        Text(documentImportError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if evidenceItems.isEmpty {
                        Text("Add at least one supporting text note or document before starting the session.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(evidenceItems) { item in
                            EvidenceDraftRow(item: item)
                        }
                        .onDelete(perform: removeEvidence)
                    }
                }
                
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(icon: "scale.3d", color: .blue, text: "WelcomTalk starts from a fairness rule: each participant gets the same number of turns and the same amount of time by default")
                        InstructionRow(icon: "timer", color: .blue, text: "Turn-taking keeps the conversation balanced so everyone has a chance to present their side")
                        InstructionRow(icon: "mic.slash", color: .red, text: "Only one person speaks at a time, which helps prevent interruptions and keeps the app neutral")
                        InstructionRow(icon: "pause.circle", color: .orange, text: "If emotions rise, anyone can pause or ask for a short grace period before the next turn")
                        InstructionRow(icon: "doc.text.fill", color: .green, text: "The opening summary, supporting details, notes, and transcripts are all logged for follow-up and export")
                    }
                }
                
                Section {
                    Button(action: createSession) {
                        HStack {
                            Spacer()
                            Text("Start Fair Conversation")
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!canCreateSession)
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
            .onAppear {
                applyInitialPortalImportIfNeeded()
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
            .fileImporter(
                isPresented: $showingDocumentImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true,
                onCompletion: importDocuments
            )
        }
    }

    private var canCreateSession: Bool {
        !trimmed(sessionTitle).isEmpty
            && !trimmed(userName).isEmpty
            && !trimmed(claimText).isEmpty
            && !evidenceItems.isEmpty
    }
    
    private func createSession() {
        dismissKeyboard()
        let userId = UUID().uuidString
        let sessionCode = SessionViewModel.generateCode()
        let caseFile = SessionCaseFile(
            claimText: trimmed(claimText),
            requestedOutcome: trimmed(requestedOutcome),
            communicationMode: communicationMode,
            evidenceItems: evidenceItems.map {
                SessionEvidence(
                    title: $0.title,
                    detail: $0.detail,
                    kind: $0.kind,
                    fileName: $0.fileName,
                    addedByUserId: userId
                )
            }
        )
        
        let session = Session(
            title: sessionTitle,
            sessionCode: sessionCode,
            caseFile: caseFile,
            status: .waiting,
            currentTurn: .partyA,
            currentTurnNumber: 1,
            maxTurns: maxTurns,
            turnDuration: turnDuration,
            partyAId: userId,
            partyBId: "",
            partyAName: userName,
            turnStartedAt: nil
        )
        
        createdSession = session
    }

    private func applyInitialPortalImportIfNeeded() {
        guard !hasAppliedInitialPortalImport,
              let portalImport = initialPortalImport else {
            return
        }

        hasAppliedInitialPortalImport = true

        applyPortalImport(portalImport, autoStart: autoStartOnAppear)
    }

    private func applyPortalImport(_ portalImport: PortalSessionImport, autoStart: Bool) {
        portalImportError = nil
        isImportingPortalRequest = false

        sessionTitle = trimmed(portalImport.topic)
        userName = trimmed(portalImport.fullName)
        claimText = trimmed(portalImport.summary)
        requestedOutcome = trimmed(portalImport.additionalNotes)
        communicationMode = .structuredConversation
        evidenceItems = importedEvidenceItems(from: portalImport)
        documentImportError = nil

        guard autoStart,
              !hasAutoStartedImportedSession else {
            return
        }

        hasAutoStartedImportedSession = true

        DispatchQueue.main.async {
            guard canCreateSession else {
                hasAutoStartedImportedSession = false
                return
            }

            createSession()
        }
    }

    private func handlePotentialPortalPaste(_ rawValue: String) {
        guard !isImportingPortalRequest else { return }

        let trimmedValue = trimmed(rawValue)

        guard looksLikePortalLink(trimmedValue),
              let portalImport = PortalSessionImport.parse(from: trimmedValue) else {
            return
        }

        dismissKeyboard()
        portalImportError = nil
        isImportingPortalRequest = true

        Task {
            do {
                let resolvedPortalImport = try await portalImport.resolvePortalImport()

                await MainActor.run {
                    applyPortalImport(resolvedPortalImport, autoStart: true)
                }
            } catch {
                await MainActor.run {
                    portalImportError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isImportingPortalRequest = false
                }
            }
        }
    }

    private func looksLikePortalLink(_ value: String) -> Bool {
        let normalizedValue = value.lowercased()

        return normalizedValue.contains("://")
            || normalizedValue.contains("welcomeport")
            || normalizedValue.contains("portalstart")
            || normalizedValue.contains("rid=")
    }

    private func importedEvidenceItems(from portalImport: PortalSessionImport) -> [DraftEvidenceItem] {
        var importedItems: [DraftEvidenceItem] = []

        let trimmedNotes = trimmed(portalImport.additionalNotes)
        let requestLabel = portalImport.requestId.map { "Portal request \($0)" } ?? "Portal barcode import"
        let importDetail = trimmedNotes.isEmpty
            ? "Imported from WelcomTalk Portal barcode to start the session."
            : trimmedNotes

        importedItems.append(
            DraftEvidenceItem(
                title: requestLabel,
                detail: importDetail,
                kind: .text,
                fileName: nil
            )
        )

        importedItems.append(
            contentsOf: portalImport.attachments.map { attachment in
                DraftEvidenceItem(
                    title: attachment.fileName,
                    detail: "Imported portal attachment reference: \(attachment.storageRef)",
                    kind: .document,
                    fileName: attachment.fileName
                )
            }
        )

        return importedItems
    }

    private func addTextEvidence() {
        let title = trimmed(evidenceTitle)
        let detail = trimmed(evidenceDetail)

        guard !title.isEmpty || !detail.isEmpty else { return }

        evidenceItems.append(
            DraftEvidenceItem(
                title: title.isEmpty ? "Supporting statement" : title,
                detail: detail.isEmpty ? "Text evidence submitted by the initiator." : detail,
                kind: .text,
                fileName: nil
            )
        )

        evidenceTitle = ""
        evidenceDetail = ""
        documentImportError = nil
    }

    private func importDocuments(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let newItems = urls.map { url in
                DraftEvidenceItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    detail: "Imported as supporting document evidence.",
                    kind: .document,
                    fileName: url.lastPathComponent
                )
            }
            evidenceItems.append(contentsOf: newItems)
            documentImportError = nil

        case .failure(let error):
            documentImportError = error.localizedDescription
        }
    }

    private func removeEvidence(at offsets: IndexSet) {
        evidenceItems.remove(atOffsets: offsets)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func dismissKeyboard() {
        focusedField = nil
    }
}

private struct DraftEvidenceItem: Identifiable {
    let id = UUID().uuidString
    let title: String
    let detail: String
    let kind: SessionEvidence.Kind
    let fileName: String?
}

private struct EvidenceDraftRow: View {
    let item: DraftEvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.symbolName)
                    .foregroundColor(item.kind == .document ? .green : .blue)
                Text(item.title)
                    .font(.subheadline.bold())
            }

            Text(item.detail)
                .font(.caption)
                .foregroundColor(.secondary)

            if let fileName = item.fileName {
                Text(fileName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InstructionRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
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
