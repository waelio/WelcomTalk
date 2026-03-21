import SwiftUI
import CoreNFC

struct WaitingRoomView: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var nfcManager = NFCSessionManager()
    @State private var showingQRScanner = false
    @State private var scannedCode: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            if sessionViewModel.isWaitingForGuestConfirmation {
                guestConfirmationSection
            } else {
                myPhoneCodeSection
            }
            
            Spacer()
            
            // Waiting indicator
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(sessionViewModel.isWaitingForGuestConfirmation ? "Scan their new barcode to begin" : "Waiting for other person...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(waitingInstructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let errorMessage = sessionViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            
            Spacer()
            
            // Session details
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(icon: "person.fill", title: "Started by", value: sessionViewModel.myParty?.displayName ?? "You")
                DetailRow(icon: "timer", title: "Time per turn", value: timeString(from: sessionViewModel.session?.turnDuration ?? 120))
                DetailRow(icon: "arrow.left.arrow.right", title: "Total turns", value: "\(sessionViewModel.session?.maxTurns ?? 10) each")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button("Cancel") {
                cancelWaitingSession()
            }
            .foregroundColor(.red)
            .padding(.bottom, 10)
            
            // Demo: Simulate participant joining
            Button("Simulate Join (Demo)") {
                sessionViewModel.simulateParticipantJoin()
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.bottom, 20)
        }
        .navigationTitle(sessionViewModel.session?.title ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scannedCode) { oldValue, newValue in
            guard let code = newValue else { return }
            sessionViewModel.confirmPendingParticipantJoin(with: code)
            scannedCode = nil
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView(scannedCode: $scannedCode)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    cancelWaitingSession()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes) min"
    }

    private var myPhoneCodeSection: some View {
        VStack(spacing: 15) {
            Text("This iPhone's Code")
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
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(4)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                )

            ShareLink(item: sessionShareMessage) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share this iPhone's code")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if NFCNDEFReaderSession.readingAvailable {
                Button(action: {
                    if let code = sessionViewModel.session?.sessionCode {
                        nfcManager.startWriting(code: code)
                    }
                }) {
                    HStack {
                        Image(systemName: nfcManager.isWriting ? "wave.3.right.circle.fill" : "wave.3.right")
                        Text(nfcManager.isWriting ? "Ready to tap..." : "Share via NFC")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(nfcManager.isWriting)
            }
        }
    }

    private var guestConfirmationSection: some View {
        VStack(spacing: 16) {
            myPhoneCodeSection

            Divider()
                .padding(.horizontal, 20)

            Text("New Barcode From Other iPhone")
                .font(.headline)
                .foregroundColor(.secondary)

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("\(sessionViewModel.pendingParticipantName ?? "The other person") is ready.")
                .font(.headline)

            Text("They already joined using your code. Their iPhone has now turned that into a new authentication barcode. Scan it to authenticate the pair and start the countdown on both phones.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                showingQRScanner = true
            }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan new authentication barcode")
                        .bold()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var waitingInstructions: String {
        if sessionViewModel.isWaitingForGuestConfirmation {
            return "The other phone joined using your code and created a new barcode. Scan that new barcode to authenticate the session and start both countdowns."
        }

        return "Share your barcode by AirDrop, QR, or NFC. When the other phone joins with it, that phone will turn to a new barcode for you to scan."
    }

    private var sessionShareMessage: String {
        let code = sessionViewModel.session?.sessionCode ?? "------"
        return """
        Join my WelcomTalk conversation with this code: \(code)

        Enter this code on the other iPhone. After it joins, that iPhone will create a new barcode for me to scan so both countdowns can start.
        """
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
                title: "Demo Session",
                sessionCode: "ABC123",
                status: .waiting,
                currentTurn: .partyA,
                currentTurnNumber: 1,
                maxTurns: 10,
                turnDuration: 120,
                partyAId: "user1",
                partyBId: "",
                turnStartedAt: nil
            ),
            userId: "user1",
            userName: "Host User",
            isHost: true
        ))
    }
}
