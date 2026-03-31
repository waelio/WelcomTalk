import Foundation
import Speech
import AVFoundation
import Combine

/// Manages on-device speech recognition for a single participant's turn.
/// Call `startRecognition()` when the turn begins and `stopRecognition()` when it ends.
/// The returned final transcript can then be logged against the session.
@MainActor
final class SpeechRecognitionService: ObservableObject {

    // MARK: - Published state

    /// Rolling, live transcript updated as the user speaks.
    @Published var liveTranscript: String = ""

    /// Set to true while the audio engine + recognizer are active.
    @Published var isRecognizing: Bool = false

    /// Non-nil if a permission or runtime error occurs.
    @Published var errorMessage: String?

    // MARK: - Private

    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Accumulates the final (non-volatile) segments as recognition progresses
    /// so that we always have a stable string available when the turn ends.
    private var committedText: String = ""

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Public API

    /// Request both microphone and speech-recognition authorization.
    /// Returns `true` when both are granted.
    func requestAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
        return true  // Skip permission dialogs in simulator
        #endif
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition permission denied. Enable it in Settings → Privacy → Speech Recognition."
            return false
        }

        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else {
            errorMessage = "Microphone permission denied. Enable it in Settings → Privacy → Microphone."
            return false
        }

        return true
    }

    /// Start capturing audio and delivering a live transcript.
    /// Safe to call multiple times — a running session is stopped first.
    func startRecognition() {
        stopRecognition()
        liveTranscript = ""
        committedText = ""
        errorMessage = nil

        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available on this device."
            return
        }

        do {
#if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
#endif

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Keep recognition on-device when possible for privacy.
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecognizing = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    // Update the live transcript with the best hypothesis.
                    let best = result.bestTranscription.formattedString
                    Task { @MainActor in
                        self.liveTranscript = best
                    }

                    // Commit finalized segments to avoid drift on long turns.
                    if result.isFinal {
                        Task { @MainActor in
                            self.committedText = best
                            self.stopAudioEngine()
                            self.isRecognizing = false
                        }
                    }
                }

                if let error {
                    // Code 1110 = "No speech detected" — not a real failure.
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        return
                    }
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                        self.stopAudioEngine()
                        self.isRecognizing = false
                    }
                }
            }
        } catch {
            errorMessage = "Could not start audio session: \(error.localizedDescription)"
            stopAudioEngine()
        }
    }

    /// Stop recognition and return the final transcript captured so far.
    /// Calling this on an already-stopped service is a no-op and returns whatever was transcribed.
    @discardableResult
    func stopRecognition() -> String {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        stopAudioEngine()
        isRecognizing = false

        // Prefer the live transcript (most recent) if no committed text yet.
        let final = committedText.isEmpty ? liveTranscript : committedText
        return final
    }

    // MARK: - Private helpers

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }
}
