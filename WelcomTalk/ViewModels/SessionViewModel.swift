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
    @Published var pendingParticipantName: String?

    // MARK: - Grace Period & Pause
    @Published var isInGracePeriod = false
    @Published var graceTimeRemaining: TimeInterval = 15

    private let graceDuration: TimeInterval = 15
    private var graceTimer: Timer?

    // MARK: - Speech Recognition
    let speechService = SpeechRecognitionService()
    /// Forwarded from speechService so views can bind directly to the view-model.
    @Published var liveTranscript: String = ""
    @Published var speechAuthorizationGranted: Bool = false
    private var speechCancellable: AnyCancellable?

    var myParty: Session.TurnParty?
    let currentUserId: String
    private let userName: String
    private let isHost: Bool
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Peer-to-peer Sync
    private var multipeerService: MultipeerService?
    @Published private var pendingParticipantId: String?
    
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
    
    var isWaitingForParticipant: Bool {
        guard let session = session else { return false }
        return session.status == .waiting && session.partyBId.isEmpty
    }

    var isWaitingForApproval: Bool {
        isHost && session?.status == .waiting && pendingParticipantId != nil
    }
    
    init(session: Session? = nil, userId: String? = nil, userName: String = "User", isHost: Bool = false) {
        self.currentUserId = userId ?? UUID().uuidString
        self.userName = userName
        self.isHost = isHost

        if let session = session {
            self.session = session
            self.myParty = session.partyAId == self.currentUserId ? .partyA : .partyB
            self.timeRemaining = session.turnDuration

            if isHost {
                addLogEntry(type: .sessionStarted, message: "\(userName) created session")
            } else {
                addLogEntry(type: .userJoined, message: "\(userName) joined session")
            }

            enableMultipeerSync()
        } else {
            // For demo: create a mock session
            createMockSession()
        }

        // Forward live transcript from the speech service.
        speechCancellable = speechService.$liveTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: \.liveTranscript, on: self)

        // Request microphone + speech permissions asynchronously.
        Task { @MainActor in
            self.speechAuthorizationGranted = await self.speechService.requestAuthorization()
        }
    }
    
    // MARK: - Session Management
    
    func startTimer() {
        guard isHost else { return }
        startGracePeriod()
    }

    // MARK: - Grace Period

    private func startGracePeriod() {
        guard isHost else { return }
        graceTimer?.invalidate()
        graceTimer = nil
        isInGracePeriod = true
        graceTimeRemaining = graceDuration
        broadcastCurrentSessionState()
        graceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.graceTimeRemaining > 1 {
                self.graceTimeRemaining -= 1
                self.broadcastCurrentSessionState()
            } else {
                self.endGracePeriod()
            }
        }
    }

    private func endGracePeriod() {
        graceTimer?.invalidate()
        graceTimer = nil
        isInGracePeriod = false
        broadcastCurrentSessionState()
        startActualTimer()
    }

    private func startActualTimer() {
        guard isHost else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.handleTurnEnd()
            }
            self.updateMuteStatus()
            self.broadcastCurrentSessionState()
        }
        startSpeechRecognitionIfMyTurn()
        updateMuteStatus()
    }

    // MARK: - Pause / Resume

    /// Either party can call this — no approval required.
    func pauseSession() {
        if isHost {
            applyPause()
        } else {
            multipeerService?.sendCommand("pause", userId: currentUserId)
        }
    }

    func resumeSession() {
        if isHost {
            applyResume()
        } else {
            multipeerService?.sendCommand("resume", userId: currentUserId)
        }
    }

    func extendGrace() {
        if isHost {
            graceTimeRemaining = graceDuration
            broadcastCurrentSessionState()
        } else {
            multipeerService?.sendCommand("extend-grace", userId: currentUserId)
        }
    }

    private func applyPause() {
        guard var session = session else { return }
        guard session.status == .active || isInGracePeriod else { return }
        graceTimer?.invalidate()
        graceTimer = nil
        timer?.invalidate()
        timer = nil
        let wasInGrace = isInGracePeriod
        isInGracePeriod = false
        session.status = .paused
        self.session = session
        addLogEntry(type: .pause, message: wasInGrace ? "Session paused during grace period" : "Session paused")
        broadcastCurrentSessionState()
    }

    private func applyResume() {
        guard var session = session else { return }
        guard session.status == .paused else { return }
        session.status = .active
        self.session = session
        addLogEntry(type: .resume, message: "Session resumed")
        startGracePeriod()
    }
    
    func endSession() {
        guard var session = session else { return }
        graceTimer?.invalidate()
        graceTimer = nil
        timer?.invalidate()
        timer = nil
        isInGracePeriod = false
        // Stop transcription and log whatever was captured for the current turn.
        stopSpeechRecognitionAndLog(for: session.currentTurn, turnNumber: session.currentTurnNumber)
        session.status = .completed
        self.session = session
        clearPendingParticipantHandshake()
        addLogEntry(type: .sessionEnded, message: "Session ended by user")
        broadcastCurrentSessionState()
        multipeerService?.disconnect()
        multipeerService = nil
        showRatingView = true
    }
    
    private func handleTurnEnd() {
        guard isHost else { return }
        guard var session = session else { return }

        // Invalidate the running countdown timer first.
        timer?.invalidate()
        timer = nil

        // Stop transcription for the turn that just ended and log it.
        stopSpeechRecognitionAndLog(for: session.currentTurn, turnNumber: session.currentTurnNumber)

        addLogEntry(type: .turnEnded, message: "\(session.currentTurn.displayName) turn ended")

        // Switch turns
        session.currentTurn = session.currentTurn == .partyA ? .partyB : .partyA
        session.currentTurnNumber += 1
        session.turnStartedAt = Date()

        if session.currentTurnNumber > session.maxTurns {
            session.status = .completed
            addLogEntry(type: .sessionEnded, message: "Session completed - max turns reached")
            self.session = session
            broadcastCurrentSessionState()
            showRatingView = true
        } else {
            addLogEntry(type: .turnStarted, message: "\(session.currentTurn.displayName) turn started")
            timeRemaining = session.turnDuration
            self.session = session
            startGracePeriod()
        }
    }

    private func updateMuteStatus() {
        isMuted = !isMyTurn
    }

    // MARK: - Speech Recognition helpers

    func startSpeechRecognitionIfMyTurn(nextTurn: Session.TurnParty? = nil) {
        let activeTurn = nextTurn ?? session?.currentTurn
        guard speechAuthorizationGranted,
              let activeTurn,
              activeTurn == myParty else { return }
        speechService.startRecognition()
    }

    private func stopSpeechRecognitionAndLog(for party: Session.TurnParty, turnNumber: Int) {
        guard party == myParty else { return }
        let transcript = speechService.stopRecognition()
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        addLogEntry(
            type: .turnTranscription,
            message: "[Turn \(turnNumber) – \(party.displayName)] \(transcript)"
        )
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
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        let logText = logEntries.reversed().map { entry in
            let time = formatter.string(from: entry.timestamp)
            if entry.type == .turnTranscription {
                return "[\(time)] 🎙 \(entry.message)"
            }
            return "[\(time)] \(entry.type.rawValue): \(entry.message)"
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
        // Scenario: Two colleagues — Alex (you) and Sam — wrapping up a positive
        // discussion about reclaiming work-life balance. 3 turns already done,
        // Sam is mid-way through turn 4 (the final turn). Short & positive.
        let samId = "user-sam-demo"
        let session = Session(
            title: "Finding More Time Together",
            sessionCode: "DEMO42",
            status: .active,
            currentTurn: .partyB,       // Sam's turn is live
            currentTurnNumber: 4,
            maxTurns: 4,
            turnDuration: 45,
            partyAId: currentUserId,
            partyBId: samId,
            partyAName: "Alex",         // You
            partyBName: "Sam",
            turnStartedAt: Date()
        )

        self.session = session
        self.myParty = .partyA          // You are Alex
        self.timeRemaining = 32         // Sam is mid-turn

        // ── Pre-seed log (build array directly so we control timestamps) ──
        let ago: (TimeInterval) -> Date = { Date(timeIntervalSinceNow: $0) }

        logEntries = [
            // Turn 4 — most recent at top
            LogEntry(sessionId: session.id, type: .turnStarted,
                     message: "Sam's turn started",
                     timestamp: ago(-13)),
            LogEntry(sessionId: session.id, type: .turnEnded,
                     message: "Alex's turn ended",
                     timestamp: ago(-15)),
            LogEntry(sessionId: session.id, type: .turnTranscription,
                     message: "[Turn 3 – Alex] Wednesday dinner is a great idea. Even just 30 minutes reconnecting in the middle of the week makes such a difference. I feel really good about where this conversation is going.",
                     timestamp: ago(-17)),
            LogEntry(sessionId: session.id, type: .noteAdded,
                     message: "Note added",
                     timestamp: ago(-40)),
            // Turn 3
            LogEntry(sessionId: session.id, type: .turnStarted,
                     message: "Alex's turn started",
                     timestamp: ago(-60)),
            LogEntry(sessionId: session.id, type: .turnEnded,
                     message: "Sam's turn ended",
                     timestamp: ago(-62)),
            LogEntry(sessionId: session.id, type: .turnTranscription,
                     message: "[Turn 2 – Sam] I completely agree. If we protect Sundays as our day — no work, no phones — and maybe add a Wednesday dinner just the two of us, I think we'd both feel so much more connected.",
                     timestamp: ago(-64)),
            LogEntry(sessionId: session.id, type: .noteAdded,
                     message: "Note added",
                     timestamp: ago(-80)),
            // Turn 2
            LogEntry(sessionId: session.id, type: .turnStarted,
                     message: "Sam's turn started",
                     timestamp: ago(-105)),
            LogEntry(sessionId: session.id, type: .turnEnded,
                     message: "Alex's turn ended",
                     timestamp: ago(-107)),
            LogEntry(sessionId: session.id, type: .turnTranscription,
                     message: "[Turn 1 – Alex] I feel like we've both been so busy lately. I really miss our quality time together — I want us to protect some space just for us, even if it's small.",
                     timestamp: ago(-109)),
            // Turn 1
            LogEntry(sessionId: session.id, type: .turnStarted,
                     message: "Alex's turn started",
                     timestamp: ago(-120)),
            LogEntry(sessionId: session.id, type: .sessionStarted,
                     message: "Demo session started",
                     timestamp: ago(-122)),
        ]

        // ── Pre-seed Alex's private notes (your perspective) ──
        notes = [
            Note(sessionId: session.id, userId: currentUserId,
                 content: "Suggest pasta night at home on Wednesdays 🍝",
                 createdAt: ago(-42), turnNumber: 3),
            Note(sessionId: session.id, userId: currentUserId,
                 content: "Sunday blocked ✓ — remind Sam to update shared calendar",
                 createdAt: ago(-82), turnNumber: 2),
            Note(sessionId: session.id, userId: currentUserId,
                 content: "Ask about the Wednesday idea — seemed really open to it",
                 createdAt: ago(-111), turnNumber: 1),
        ]

        updateMuteStatus()
    }

    // MARK: - Real-time Sync

    private func enableMultipeerSync() {
        guard let session = session, multipeerService == nil else { return }

        let service = MultipeerService(userId: currentUserId, userName: userName, sessionCode: session.sessionCode)
        multipeerService = service

        // Announce ourselves as soon as a peer connects
        service.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                // Short delay: MCSession marks the peer as .connected before the
                // data channel is fully open. Sending immediately can silently drop.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }
                    self.multipeerService?.announceSession(
                        userId: self.currentUserId,
                        userName: self.userName,
                        isHost: self.isHost,
                        confirmationCode: nil
                    )
                }
            }
            .store(in: &cancellables)

        service.$joinAnnouncement
            .compactMap { $0 }
            .sink { [weak self] announcement in
                guard let self else { return }
                guard announcement.userId != self.currentUserId else { return }
                if self.isHost,
                   self.session?.status == .waiting,
                   announcement.isHost == false {
                    self.handleParticipantJoinRequest(
                        participantId: announcement.userId,
                        participantName: announcement.userName
                    )
                }
            }
            .store(in: &cancellables)

        service.$sessionState
            .compactMap { $0 }
            .sink { [weak self] state in
                self?.applyRemoteSessionState(state)
            }
            .store(in: &cancellables)

        // Host handles instant commands sent by the guest (pause, resume, extend-grace).
        service.$commandReceived
            .compactMap { $0 }
            .filter { [weak self] cmd in cmd.userId != self?.currentUserId }
            .sink { [weak self] cmd in
                guard let self, self.isHost else { return }
                switch cmd.requestType {
                case "pause":        self.applyPause()
                case "resume":       self.applyResume()
                case "extend-grace": self.graceTimeRemaining = self.graceDuration
                                     self.broadcastCurrentSessionState()
                default: break
                }
            }
            .store(in: &cancellables)

        if isHost {
            service.startHosting()
        } else {
            service.startBrowsing()
        }
    }

    private func handleParticipantJoinRequest(participantId: String, participantName: String?) {
        guard session?.status == .waiting else { return }

        pendingParticipantId = participantId
        pendingParticipantName = participantName ?? "Someone"

        addLogEntry(
            type: .userJoined,
            message: "\(pendingParticipantName ?? "Someone") wants to join"
        )
    }

    /// Host taps "Let them in" — starts the session immediately on both devices.
    func approveParticipantJoin() {
        guard let participantId = pendingParticipantId else { return }
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
        self.isInGracePeriod = remoteSession.isInGracePeriod
        self.graceTimeRemaining = remoteSession.graceTimeRemaining
        updateMuteStatus()

        if session.status == .active && myParty == nil {
            myParty = (session.partyAId == currentUserId) ? .partyA : .partyB
        }

        timer?.invalidate()
        timer = nil
    }

    private func broadcastCurrentSessionState() {
        guard isHost, let session = session else { return }

        multipeerService?.broadcastSessionState(
            userId: currentUserId,
            title: session.title,
            currentTurn: session.currentTurn.rawValue,
            currentTurnNumber: session.currentTurnNumber,
            maxTurns: session.maxTurns,
            turnDuration: session.turnDuration,
            timeRemaining: timeRemaining,
            status: session.status.rawValue,
            partyAId: session.partyAId,
            partyBId: session.partyBId,
            graceTimeRemaining: graceTimeRemaining,
            isInGracePeriod: isInGracePeriod
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
    }

    static func generateCode(length: Int = 6) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}
