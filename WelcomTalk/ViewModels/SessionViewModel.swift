import Foundation
import Combine

class SessionViewModel: ObservableObject {
    @Published var session: Session?
    @Published var timeRemaining: TimeInterval = 120
    @Published var currentNote: String = ""
    @Published var notes: [Note] = []
    @Published var logEntries: [LogEntry] = []
    @Published var pendingRequests: [ModificationRequest] = []
    @Published var isMuted: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showRatingView: Bool = false
    @Published var myConfirmationCode: String?
    @Published var pendingParticipantName: String?
    
    var myParty: Session.TurnParty?
    let currentUserId: String
    private let userName: String
    private let isHost: Bool
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - WebSocket Integration (Optional)
    private var webSocketService: WebSocketService?
    private var sessionMessaging: SessionMessagingService?
    private var pendingParticipantId: String?
    private var expectedParticipantConfirmationCode: String?
    
    var isMyTurn: Bool {
        guard let session = session, let myParty = myParty else { return false }
        return session.currentTurn == myParty
    }

    var drivesSessionClock: Bool {
        isHost
    }

    var isConnectingToHost: Bool {
        !isHost && session?.status == .waiting
    }

    var isWaitingForGuestConfirmation: Bool {
        isHost && session?.status == .waiting && pendingParticipantId != nil
    }
    
    var isWaitingForParticipant: Bool {
        guard let session = session else { return false }
        return session.status == .waiting && session.partyBId.isEmpty
    }
    
    init(session: Session? = nil, userId: String? = nil, userName: String = "User", isHost: Bool = false) {
        self.currentUserId = userId ?? UUID().uuidString
        self.userName = userName
        self.isHost = isHost
        
        if let session = session {
            self.session = session
            self.myParty = session.partyAId == self.currentUserId ? .partyA : .partyB
            self.timeRemaining = session.turnDuration

            if !isHost && session.status == .waiting {
                self.myConfirmationCode = Self.generateCode()
            }
            
            if isHost {
                addLogEntry(type: .sessionStarted, message: "\(userName) created session")
            } else {
                addLogEntry(type: .userJoined, message: "\(userName) joined session")
            }

            enableWebSocketSync()
        } else {
            // For demo: create a mock session
            createMockSession()
        }
    }
    
    // MARK: - Session Management
    
    func startTimer() {
        guard isHost else {
            timer?.invalidate()
            timer = nil
            return
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.handleTurnEnd()
            }
            
            // Auto-mute logic
            self.updateMuteStatus()
            self.broadcastCurrentSessionState()
        }
    }
    
    func endSession() {
        guard var session = session else { return }
        timer?.invalidate()
        timer = nil
        session.status = .completed
        self.session = session
        clearPendingParticipantHandshake()
        addLogEntry(type: .sessionEnded, message: "Session ended by user")
        broadcastCurrentSessionState()
        showRatingView = true
    }
    
    private func handleTurnEnd() {
        guard isHost else { return }
        guard var session = session else { return }
        
        addLogEntry(type: .turnEnded, message: "\(session.currentTurn.displayName) turn ended")
        
        // Switch turns
        session.currentTurn = session.currentTurn == .partyA ? .partyB : .partyA
        session.currentTurnNumber += 1
        session.turnStartedAt = Date()
        
        if session.currentTurnNumber > session.maxTurns {
            session.status = .completed
            timer?.invalidate()
            addLogEntry(type: .sessionEnded, message: "Session completed - max turns reached")
            showRatingView = true
        } else {
            addLogEntry(type: .turnStarted, message: "\(session.currentTurn.displayName) turn started")
            timeRemaining = session.turnDuration
        }
        
        self.session = session
        broadcastCurrentSessionState()
    }
    
    private func updateMuteStatus() {
        isMuted = !isMyTurn
    }
    
    // MARK: - Notes
    
    func saveNote() {
        guard let session = session, !currentNote.isEmpty else { return }
        
        let note = Note(
            sessionId: session.id,
            userId: currentUserId,
            content: currentNote,
            turnNumber: session.currentTurnNumber
        )
        
        notes.insert(note, at: 0)
        addLogEntry(type: .noteAdded, message: "Note added")
        currentNote = ""
    }
    
    // MARK: - Modification Requests
    
    func requestModification(type: ModificationRequest.ModificationType, reason: String) {
        guard let session = session else { return }
        
        let request = ModificationRequest(
            sessionId: session.id,
            requestingUserId: currentUserId,
            type: type,
            reason: reason
        )
        
        pendingRequests.append(request)
        addLogEntry(type: .modificationRequested, message: "Modification requested: \(type.description)")
    }
    
    func respondToRequest(_ request: ModificationRequest, approve: Bool) {
        guard let index = pendingRequests.firstIndex(where: { $0.id == request.id }) else { return }
        
        var updatedRequest = request
        updatedRequest.status = approve ? .approved : .denied
        updatedRequest.respondedAt = Date()
        
        pendingRequests.remove(at: index)
        
        if approve {
            applyModification(request.type)
            addLogEntry(type: .modificationApproved, message: "Approved: \(request.type.description)")
        } else {
            addLogEntry(type: .modificationDenied, message: "Denied: \(request.type.description)")
        }
    }
    
    private func applyModification(_ type: ModificationRequest.ModificationType) {
        guard var session = session else { return }
        
        switch type {
        case .extendTurn:
            timeRemaining += 60
        case .addTurn:
            session.maxTurns += 1
        case .pauseSession:
            session.status = .paused
            timer?.invalidate()
            timer = nil
            addLogEntry(type: .pause, message: "Session paused")
        case .resumeSession:
            session.status = .active
            startTimer()
            addLogEntry(type: .resume, message: "Session resumed")
        case .endSession:
            session.status = .completed
            timer?.invalidate()
            timer = nil
            addLogEntry(type: .sessionEnded, message: "Session ended by mutual agreement")
            showRatingView = true
        }
        
        self.session = session
        broadcastCurrentSessionState()
    }
    
    // MARK: - Logging
    
    private func addLogEntry(type: LogEntry.LogType, message: String) {
        guard let session = session else { return }
        
        let entry = LogEntry(
            sessionId: session.id,
            type: type,
            message: message
        )
        
        logEntries.insert(entry, at: 0)
    }
    
    func exportLog() -> URL? {
        let logText = logEntries.map { entry in
            "[\(entry.timestamp)] \(entry.type.rawValue): \(entry.message)"
        }.joined(separator: "\n")
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "session_log_\(Date().timeIntervalSince1970).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try logText.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            errorMessage = "Failed to export log: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Mock Data
    
    private func createMockSession() {
        let session = Session(
            title: "Demo Negotiation",
            sessionCode: "DEMO\(Int.random(in: 1000...9999))",
            status: .active,
            currentTurn: .partyA,
            currentTurnNumber: 1,
            maxTurns: 10,
            turnDuration: 120,
            partyAId: currentUserId,
            partyBId: "user-other",
            turnStartedAt: Date()
        )
        
        self.session = session
        self.myParty = .partyA
        self.timeRemaining = session.turnDuration
        
        addLogEntry(type: .sessionStarted, message: "Demo session started")
        addLogEntry(type: .turnStarted, message: "\(session.currentTurn.displayName) turn started")
        
        updateMuteStatus()
    }

    // MARK: - Real-time Sync

    private func enableWebSocketSync() {
        guard let session = session, webSocketService == nil else { return }

        let webSocket = WebSocketService(userId: currentUserId, userName: userName)
        let messaging = SessionMessagingService(webSocket: webSocket, sessionCode: session.sessionCode)

        webSocketService = webSocket
        sessionMessaging = messaging

        webSocket.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.sessionMessaging?.announceSession(
                    userId: self.currentUserId,
                    userName: self.userName,
                    isHost: self.isHost,
                    confirmationCode: self.myConfirmationCode
                )

                if !self.isHost {
                    self.broadcastCurrentSessionState()
                }
            }
            .store(in: &cancellables)

        messaging.$joinAnnouncement
            .compactMap { $0 }
            .sink { [weak self] announcement in
                guard let self = self else { return }
                guard announcement.userId != self.currentUserId else { return }

                if self.isHost,
                   self.session?.status == .waiting,
                   announcement.isHost == false {
                    self.handleParticipantJoinRequest(
                        participantId: announcement.userId,
                        participantName: announcement.userName,
                        confirmationCode: announcement.confirmationCode
                    )
                }
            }
            .store(in: &cancellables)

        messaging.$sessionState
            .compactMap { $0 }
            .sink { [weak self] state in
                self?.applyRemoteSessionState(state)
            }
            .store(in: &cancellables)

        webSocket.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)

        webSocket.connect()
    }

    private func handleParticipantJoinRequest(participantId: String, participantName: String?, confirmationCode: String?) {
        guard session?.status == .waiting else { return }

        pendingParticipantId = participantId
        pendingParticipantName = participantName ?? "Other person"
        expectedParticipantConfirmationCode = Self.normalizeCode(confirmationCode)
        errorMessage = expectedParticipantConfirmationCode == nil
            ? "The other phone joined, but its new authentication barcode did not arrive. Ask them to rejoin."
            : nil

        addLogEntry(
            type: .userJoined,
            message: "\(pendingParticipantName ?? "Other person") joined with your code. Scan their new barcode to authenticate and start both countdowns."
        )
    }

    func confirmPendingParticipantJoin(with scannedCode: String) {
        guard let participantId = pendingParticipantId else {
            errorMessage = "No new authentication barcode is waiting to be scanned yet."
            return
        }

        guard let expectedCode = expectedParticipantConfirmationCode else {
            errorMessage = "The new authentication barcode is missing. Ask the other person to leave and join again."
            return
        }

        let normalizedScannedCode = Self.normalizeCode(scannedCode)
        guard normalizedScannedCode == expectedCode else {
            errorMessage = "That barcode doesn't match the new authentication barcode from the other phone."
            return
        }

        guard var session = session, session.status == .waiting else { return }

        session.partyBId = participantId
        session.status = .active
        session.turnStartedAt = Date()
        self.session = session
        self.timeRemaining = session.turnDuration
        errorMessage = nil

        let participantLabel = pendingParticipantName ?? "Party B"
        clearPendingParticipantHandshake()
        addLogEntry(type: .userJoined, message: "\(participantLabel) joined the session")
        addLogEntry(type: .turnStarted, message: "\(session.currentTurn.displayName) turn started")

        startTimer()
        updateMuteStatus()
        broadcastCurrentSessionState()
    }

    private func applyRemoteSessionState(_ syncMessage: SessionMessagingService.SessionSyncMessage) {
          guard !isHost,
              syncMessage.userId != currentUserId,
              let remoteSession = syncMessage.session,
              var session = session else { return }

        if let turn = Session.TurnParty(rawValue: remoteSession.currentTurn) {
            session.currentTurn = turn
        }

        if let status = Session.SessionStatus(rawValue: remoteSession.status) {
            session.status = status
        }

        session.currentTurnNumber = remoteSession.currentTurnNumber
        session.title = remoteSession.title
        session.maxTurns = remoteSession.maxTurns
        session.turnDuration = remoteSession.turnDuration
        session.partyAId = remoteSession.partyAId
        session.partyBId = remoteSession.partyBId

        if session.partyBId.isEmpty && !isHost {
            session.partyBId = currentUserId
        }

        if session.status == .active {
            session.turnStartedAt = Date()
        }

        self.session = session
        self.timeRemaining = remoteSession.timeRemaining
        updateMuteStatus()

        if session.status == .active {
            myConfirmationCode = nil
        }

        timer?.invalidate()
        timer = nil
    }

    private func broadcastCurrentSessionState() {
        guard isHost, let session = session else { return }

        sessionMessaging?.broadcastSessionState(
            userId: currentUserId,
            title: session.title,
            currentTurn: session.currentTurn.rawValue,
            currentTurnNumber: session.currentTurnNumber,
            maxTurns: session.maxTurns,
            turnDuration: session.turnDuration,
            timeRemaining: timeRemaining,
            status: session.status.rawValue,
            partyAId: session.partyAId,
            partyBId: session.partyBId
        )
    }

    func simulateParticipantJoin() {
        guard var session = session, session.status == .waiting else { return }
        
        // Simulate Party B joining
        session.partyBId = "participant-\(UUID().uuidString)"
        session.status = .active
        session.turnStartedAt = Date()
        
        self.session = session
        
        addLogEntry(type: .userJoined, message: "Party B joined the session")
        addLogEntry(type: .turnStarted, message: "\(session.currentTurn.displayName) turn started")
        
        // Start the timer now that both parties are present
        startTimer()
        updateMuteStatus()
        broadcastCurrentSessionState()
    }

    private func clearPendingParticipantHandshake() {
        pendingParticipantId = nil
        pendingParticipantName = nil
        expectedParticipantConfirmationCode = nil
    }

    static func generateCode(length: Int = 6) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func normalizeCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let normalized = code
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        return normalized.isEmpty ? nil : normalized
    }
}
