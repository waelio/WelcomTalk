import Foundation
import SwiftUI

struct MessagingServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WebSocketService.customServerURLKey) private var customServerURL = ""

    private var trimmedURL: String {
        customServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ws://192.168.1.100:8080", text: $customServerURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)

                    Text("Current app default: \(WebSocketService.defaultServerURL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Messaging Server")
                } footer: {
                    Text("For two physical phones on the same Wi‑Fi, enter your Mac's WebSocket server address, for example ws://192.168.1.100:8080. Leave blank to use the built-in default.")
                }

                Section {
                    Button("Use Hosted Messaging Server") {
                        customServerURL = "wss://waelio-messaging.onrender.com"
                    }

                    Button("Use Local Simulator Server") {
                        customServerURL = "ws://localhost:8080"
                    }

                    Button("Clear Custom Server") {
                        customServerURL = ""
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Quick Actions")
                }

                Section {
                    Text(trimmedURL.isEmpty ? WebSocketService.defaultServerURL : trimmedURL)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                } header: {
                    Text("Effective URL")
                }
            }
            .navigationTitle("Messaging Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        customServerURL = trimmedURL
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MessagingServerSettingsView()
}
