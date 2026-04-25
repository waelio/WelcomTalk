import SwiftUI
import CoreNFC

struct JoinSessionView: View {
    private enum Field {
        case userName
        case sessionCode
    }

    @Environment(\.dismiss) var dismiss
    @StateObject private var nfcManager = NFCSessionManager()
    @State private var sessionCode: String = ""
    @State private var userName: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedSession: Session?
    @State private var importedPortalDraft: PortalSessionImport?
    @State private var showingQRScanner = false
    @State private var scannedCode: String?
    @FocusState private var focusedField: Field?

    private var canSubmitJoin: Bool {
        if PortalSessionImport.parse(from: sessionCode) != nil {
            return !isJoining
        }

        return normalizedSessionCode(from: sessionCode).count == 6
            && !trimmedUserName.isEmpty
            && !isJoining
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Your Details") {
                    TextField("Your Name", text: $userName)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .userName)
                        .onChange(of: userName) { oldValue, newValue in
                            handlePotentialPortalPaste(newValue)
                        }
                    
                    HStack {
                        TextField("Session Code", text: $sessionCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textContentType(.none)
                            .keyboardType(.asciiCapable)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .sessionCode)
                            .onChange(of: sessionCode) { oldValue, newValue in
                                if let portalImport = PortalSessionImport.parse(from: newValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    handlePotentialPortalPaste(newValue, parsedImport: portalImport)
                                    return
                                }

                                let normalizedValue = normalizedSessionCode(from: newValue)

                                if normalizedValue != newValue {
                                    sessionCode = normalizedValue
                                }
                            }
                        
                        if NFCNDEFReaderSession.readingAvailable {
                            Button(action: {
                                dismissKeyboard()
                                nfcManager.startReading()
                            }) {
                                Image(systemName: nfcManager.isReading ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .disabled(nfcManager.isReading)
                        }
                    }
                }
                
                if let error = errorMessage ?? nfcManager.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: {
                        dismissKeyboard()
                        showingQRScanner = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "qrcode.viewfinder")
                                .symbolRenderingMode(.hierarchical)
                            Text("Scan QR / Barcode")
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                } header: {
                    Text("Quick Join")
                } footer: {
                    Text("Scan the code shown on the first phone, or scan a WelcomTalk Portal QR/barcode to start from the questionnaire")
                        .font(.caption)
                }
                
                if NFCNDEFReaderSession.readingAvailable {
                    Section {
                        Button(action: {
                            dismissKeyboard()
                            nfcManager.startReading()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "wave.3.right")
                                    .symbolRenderingMode(.hierarchical)
                                Text(nfcManager.isReading ? "Scanning..." : "Scan with NFC")
                                    .bold()
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(nfcManager.isReading)
                    } header: {
                        Text("NFC")
                    } footer: {
                        Text("Tap your iPhone to another device to read the session code")
                            .font(.caption)
                    }
                }
                
                Section("How to Join") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Receive the first phone's code via AirDrop and paste it here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Or scan the code from the first phone's screen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Or enter the 6-character code the first phone shares")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if NFCNDEFReaderSession.readingAvailable {
                            Text("• Or tap phones together via NFC")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("• After you join, wait for the host to tap \"Let Them In\" — the session starts on both phones automatically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("Once joined, WelcomTalk gives each participant equal timed turns. Only one person speaks at a time, creating a fair space for respectful communication.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                Section {
                    Button(action: joinSession) {
                        HStack {
                            Spacer()
                            if isJoining {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isJoining ? "Joining..." : "Join Conversation")
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(!canSubmitJoin)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Join Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissKeyboard()
                        dismiss()
                    }
                }
            }
            .onChange(of: nfcManager.sessionCode) { oldValue, newValue in
                if let code = newValue {
                    handleIncomingCode(code)
                }
            }
            .sheet(isPresented: $showingQRScanner, onDismiss: handleScannerDismiss) {
                QRCodeScannerView(scannedCode: $scannedCode)
            }
            .fullScreenCover(item: $joinedSession) { session in
                NavigationStack {
                    SessionView(sessionViewModel: SessionViewModel(
                        session: session,
                        userId: session.partyBId,
                        userName: userName,
                        isHost: false
                    ))
                }
            }
            .fullScreenCover(item: $importedPortalDraft) { portalImport in
                CreateSessionView(
                    initialPortalImport: portalImport,
                    autoStartOnAppear: false
                )
            }
        }
    }

    private func handleIncomingCode(_ code: String) {
        dismissKeyboard()

        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        if let portalImport = PortalSessionImport.parse(from: trimmedCode) {
            errorMessage = nil
            sessionCode = trimmedCode
            startPortalImport(portalImport)
            return
        }

        let normalizedCode = normalizedSessionCode(from: trimmedCode)

        guard !normalizedCode.isEmpty else {
            errorMessage = "Couldn't read a WelcomTalk code."
            return
        }

        sessionCode = normalizedCode

        guard normalizedCode.count == 6 else {
            errorMessage = "That barcode isn't a valid WelcomTalk session code."
            return
        }

        guard !trimmedUserName.isEmpty else {
            errorMessage = "Enter your name, then tap Join Conversation to enter session \(normalizedCode)."
            focusedField = .userName
            return
        }

        errorMessage = nil
        joinSession(using: normalizedCode, userName: trimmedUserName)
    }

    private func handleScannerDismiss() {
        guard let scannedCode else { return }
        defer {
            self.scannedCode = nil
        }

        handleIncomingCode(scannedCode)
    }
    
    private func joinSession() {
        joinSession(using: sessionCode, userName: userName)
    }

    private func joinSession(using rawSessionCode: String, userName rawUserName: String) {
        dismissKeyboard()

        let normalizedCode = normalizedSessionCode(from: rawSessionCode)
        let normalizedUserName = rawUserName.trimmingCharacters(in: .whitespacesAndNewlines)

        sessionCode = normalizedCode
        userName = normalizedUserName
        isJoining = true
        errorMessage = nil

        if let portalImport = PortalSessionImport.parse(from: normalizedCode) {
            startPortalImport(portalImport)
            return
        }

        guard normalizedCode.count == 6 else {
            errorMessage = "Enter a valid 6-character session code."
            isJoining = false
            focusedField = .sessionCode
            return
        }

        guard !normalizedUserName.isEmpty else {
            errorMessage = "Enter your name before joining the session."
            isJoining = false
            focusedField = .userName
            return
        }
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // In a real app, this would query Firebase/backend for the session
            // For now, create a mock session
            let userId = UUID().uuidString
            
            let session = Session(
                title: "Session \(normalizedCode)",
                sessionCode: normalizedCode,
                status: .waiting,
                currentTurn: .partyA,
                currentTurnNumber: 1,
                maxTurns: 10,
                turnDuration: 120,
                partyAId: "pending-host",
                partyBId: userId,
                partyBName: normalizedUserName,
                turnStartedAt: nil
            )
            
            joinedSession = session
            isJoining = false
        }
    }

    private var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedSessionCode(from value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if isPotentialPortalInput(trimmedValue) {
            return trimmedValue
        }

        return trimmedValue.uppercased()
    }

    private func isPotentialPortalInput(_ value: String) -> Bool {
        let normalizedValue = value.lowercased()

        return normalizedValue.contains("://")
            || normalizedValue.contains("portal-start")
            || normalizedValue.contains("welcomeport")
            || normalizedValue.contains("rid=")
    }

    private func handlePotentialPortalPaste(_ rawValue: String, parsedImport: PortalSessionImport? = nil) {
        guard !isJoining else { return }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let portalImport = parsedImport ?? PortalSessionImport.parse(from: trimmedValue)

        guard isPotentialPortalInput(trimmedValue),
              let portalImport else {
            return
        }

        startPortalImport(portalImport)
    }

    private func startPortalImport(_ portalImport: PortalSessionImport) {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                let resolvedPortalImport = try await portalImport.resolvePortalImport()

                await MainActor.run {
                    importedPortalDraft = resolvedPortalImport
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isJoining = false
                }
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

#Preview {
    JoinSessionView()
}
