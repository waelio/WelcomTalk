import SwiftUI
import CoreNFC

struct WaitingRoomView: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var nfcManager = NFCSessionManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                if sessionViewModel.isWaitingForApproval {
                    approvalSection
                } else {
                    shareCodeSection
                }

                // Session detail card
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(icon: "person.fill",         title: "Host",          value: sessionViewModel.session?.partyAName ?? "You")
                    DetailRow(icon: "timer",               title: "Equal time per turn", value: timeString(from: sessionViewModel.session?.turnDuration ?? 120))
                    DetailRow(icon: "arrow.left.arrow.right", title: "Equal rounds", value: "\(sessionViewModel.session?.maxTurns ?? 2) each  (\(sessionViewModel.session?.totalTurns ?? 4) total)")
                    if let communicationMode = sessionViewModel.session?.caseFile?.communicationMode {
                        DetailRow(icon: communicationMode.symbolName, title: "Mode", value: communicationMode.displayName)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fairness rule")
                        .font(.headline)

                    Text("WelcomTalk keeps the session neutral by giving each participant the same number of turns and the same amount of time by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.08)))
                .padding(.horizontal, 20)

                if let caseFile = sessionViewModel.session?.caseFile {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shared Session Context")
                            .font(.headline)

                        Text(caseFile.claimText)
                            .font(.subheadline)

                        if !caseFile.requestedOutcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Requested outcome: \(caseFile.requestedOutcome)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !caseFile.evidenceItems.isEmpty {
                            Divider()
                            ForEach(caseFile.evidenceItems) { evidence in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: evidence.kind.symbolName)
                                        .foregroundColor(evidence.kind == .document ? .green : .blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(evidence.title)
                                            .font(.subheadline.bold())
                                        Text(evidence.detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let fileName = evidence.fileName {
                                            Text(fileName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
                    .padding(.horizontal, 20)
                }

                if let errorMessage = sessionViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Demo helper
                Button("Simulate Join (Demo)") {
                    sessionViewModel.simulateParticipantJoin()
                }
                .font(.caption)
                .foregroundColor(.blue)

                Button("Cancel") { cancelWaitingSession() }
                    .foregroundColor(.red)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle(sessionViewModel.session?.title ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { cancelWaitingSession() }.foregroundColor(.red)
            }
        }
    }

    // MARK: - Share-code section (waiting for guest to scan/enter code)

    private var shareCodeSection: some View {
        VStack(spacing: 20) {
            Text("Share this code to invite someone")
                .font(.headline)
                .foregroundColor(.secondary)

            if let code = sessionViewModel.session?.sessionCode,
               let qrImage = QRCodeGenerator.generateQRCode(from: code) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 5)
            }

            Text(sessionViewModel.session?.sessionCode ?? "")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .tracking(6)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 2))
                )

            HStack(spacing: 12) {
                ShareLink(item: sessionShareMessage) {
                    Label("Share Code", systemImage: "square.and.arrow.up")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if NFCNDEFReaderSession.readingAvailable {
                    Button {
                        if let code = sessionViewModel.session?.sessionCode {
                            nfcManager.startWriting(code: code)
                        }
                    } label: {
                        Label(nfcManager.isWriting ? "Ready…" : "NFC",
                              systemImage: nfcManager.isWriting ? "wave.3.right.circle.fill" : "wave.3.right")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(nfcManager.isWriting)
                }
            }
            .padding(.horizontal, 20)

            ProgressView()
                .padding(.top, 4)
            Text("Waiting for the next participant to join…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Approval section (guest knocked — host taps to let them in)

    private var approvalSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("\(sessionViewModel.pendingParticipantName ?? "Someone") wants to join")
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Tap below to start the equal-time conversation.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                sessionViewModel.approveParticipantJoin()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Let Them In")
                        .bold()
                }
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return seconds == 0 ? "\(minutes) min" : "\(minutes)m \(seconds)s"
    }

    private var sessionShareMessage: String {
        let code = sessionViewModel.session?.sessionCode ?? "------"
        let claimSnippet = sessionViewModel.session?.caseFile?.claimText ?? ""
        if claimSnippet.isEmpty {
            return "Join my WelcomTalk conversation!\n\nOpen the app, tap \"Join Conversation\" and enter this code: \(code)"
        }

        return "Join my WelcomTalk conversation!\n\nClaim: \(claimSnippet)\n\nOpen the app, tap \"Join Conversation\" and enter this code: \(code)"
    }

    private func cancelWaitingSession() {
        sessionViewModel.endSession()
        dismiss()
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

#Preview {
    NavigationStack {
        WaitingRoomView(sessionViewModel: SessionViewModel(
            session: Session(
                title: "Weekend Plans",
                sessionCode: "ABC123",
                status: .waiting,
                currentTurn: .partyA,
                currentTurnNumber: 1,
                maxTurns: 2,
                turnDuration: 60,
                partyAId: "user1",
                partyBId: "",
                partyAName: "Alex",
                partyBName: "Sam",
                turnStartedAt: nil
            ),
            userId: "user1",
            userName: "Alex",
            isHost: true
        ))
    }
}

