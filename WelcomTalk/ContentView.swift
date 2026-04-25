//
//  ContentView.swift
//  WelcomTalk
//
//  Created by waelio on 07/03/2026.
//

import SwiftUI      

struct ContentView: View {
    @State private var showingCreateSession = false
    @State private var showingJoinSession = false
    @State private var showingPortalScanner = false
    @State private var showingMessagingSettings = false
    @State private var scannedPortalCode: String?
    @State private var importedPortalDraft: PortalSessionImport?
    @State private var portalImportError: String?
    @State private var isImportingPortalSession = false

    private var websiteStartURL: URL {
        URL(string: "https://welcomeport.netlify.app/")!
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    VStack(spacing: 10) {
                        Text("Equal Time for Every Voice")
                            .font(.title)
                            .bold()

                        Text("WelcomTalk is a fairness-first conversation app. One person speaks at a time, each participant gets the same timed turn, and the app stays neutral while everyone presents their side.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Equal timed turns by default", systemImage: "timer")
                        Label("Neutral structure without interruptions", systemImage: "arrow.left.arrow.right.circle")
                        Label("Notes, logs, and follow-up in one place", systemImage: "doc.text")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    VStack(spacing: 15) {
                        Button {
                            showingCreateSession = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start Fair Conversation")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start Fair Conversation")

                        Button {
                            showingJoinSession = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Join Equal-Time Session")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Join Equal-Time Session")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Start from WelcomTalk Portal")
                                .font(.headline)

                            Text("Anyone can begin in WelcomTalk Portal, fill the questionnaire, create the barcode, and then scan it here to start the session.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)

                            Link(destination: websiteStartURL) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Open WelcomTalk Portal")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.18))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Open WelcomTalk Portal")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(16)

                        Divider()
                            .padding(.vertical, 10)

                        Button {
                            portalImportError = nil
                            showingPortalScanner = true
                        } label: {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan Portal Barcode")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.18))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan Portal Barcode")
                    }
                    .padding(.horizontal, 40)

                    if let portalImportError {
                        Text(portalImportError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }

                    if isImportingPortalSession {
                        ProgressView("Opening portal request...")
                            .font(.caption)
                            .padding(.horizontal, 36)
                    }

                    Text("Current live session engine supports two participants today, while the broader product direction stays open to bigger moderated formats later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)

                    VStack(spacing: 8) {
                        HStack(spacing: 20) {
                            FeatureLabel(icon: "scale.3d", text: "Equal Turns", color: .blue)
                            FeatureLabel(icon: "note.text", text: "Private Notes", color: .orange)
                            FeatureLabel(icon: "list.bullet", text: "Session Log", color: .purple)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("WelcomTalk")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingMessagingSettings = true
                    } label: {
                        Image(systemName: "network")
                    }
                    .accessibilityLabel("network")
                    .tint(.blue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: appShareMessage) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }
            .sheet(isPresented: $showingCreateSession) {
                CreateSessionView()
            }
            .sheet(isPresented: $showingJoinSession) {
                JoinSessionView()
            }
            .sheet(isPresented: $showingMessagingSettings) {
                MessagingServerSettingsView()
            }
            .sheet(isPresented: $showingPortalScanner, onDismiss: handlePortalScannerDismiss) {
                QRCodeScannerView(scannedCode: $scannedPortalCode)
            }
            .onOpenURL(perform: handleIncomingURL)
            .fullScreenCover(item: $importedPortalDraft) { portalImport in
                CreateSessionView(
                    initialPortalImport: portalImport,
                    autoStartOnAppear: false
                )
            }
        }
    }

    private var appShareMessage: String {
        "Try WelcomTalk - Equal Time for Every Voice\n\nWelcomTalk helps people present their side fairly with equal timed turns, one speaker at a time, and a neutral structure that reduces interruptions.\n\nStart in WelcomTalk Portal, fill the questionnaire, create the barcode, and scan it in the app:\nhttps://welcomeport.netlify.app/\n\nThen continue in the app to start or join the conversation."
    }

    private func handlePortalScannerDismiss() {
        guard let scannedPortalCode else { return }

        defer {
            self.scannedPortalCode = nil
        }

        importPortalSession(from: scannedPortalCode)
    }

    private func handleIncomingURL(_ url: URL) {
        importPortalSession(from: url.absoluteString)
    }

    private func importPortalSession(from code: String) {
        showingCreateSession = false
        showingJoinSession = false
        showingPortalScanner = false
        showingMessagingSettings = false

        guard let portalImport = PortalSessionImport.parse(from: code) else {
            portalImportError = "That link or barcode is not a WelcomTalk Portal start code."
            return
        }

        portalImportError = nil
        isImportingPortalSession = true

        Task {
            do {
                let resolvedPortalImport = try await portalImport.resolvePortalImport()

                await MainActor.run {
                    importedPortalDraft = resolvedPortalImport
                    isImportingPortalSession = false
                }
            } catch {
                await MainActor.run {
                    portalImportError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isImportingPortalSession = false
                }
            }
        }
    }
}

struct PortalSessionImport: Identifiable {
    let requestId: String?
    let fullName: String
    let topic: String
    let summary: String
    let additionalNotes: String
    let attachments: [PortalRequestAttachment]

    var id: String {
        if let requestId,
           !requestId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return requestId
        }

        return [fullName, topic, summary, additionalNotes]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    static func parse(from code: String) -> PortalSessionImport? {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCode.isEmpty,
              let components = URLComponents(string: normalizedCode),
              let queryValues = queryValues(from: components) else {
            return nil
        }

                let requestId = queryValues["rid"]
                        ?? queryValues["requestid"]
                        ?? queryValues["request_id"]
        let fullName = queryValues["n"]
            ?? queryValues["fullname"]
            ?? queryValues["full_name"]
            ?? ""
        let topic = queryValues["t"]
            ?? queryValues["topic"]
            ?? ""
        let summary = queryValues["s"]
            ?? queryValues["summary"]
            ?? ""
        let additionalNotes = queryValues["notes"]
            ?? queryValues["a"]
            ?? queryValues["additionalnotes"]
            ?? queryValues["additional_notes"]
            ?? ""

        let normalizedRequestId = requestId?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedRequestId?.isEmpty == false
                || (!fullName.isEmpty && !topic.isEmpty && !summary.isEmpty) else {
            return nil
        }

        return PortalSessionImport(
            requestId: normalizedRequestId,
            fullName: fullName,
            topic: topic,
            summary: summary,
            additionalNotes: additionalNotes,
            attachments: []
        )
    }

    private static func queryValues(from components: URLComponents) -> [String: String]? {
        let normalizedScheme = (components.scheme ?? "").lowercased()

        switch normalizedScheme {
        case "welcomtalk":
            guard isPortalStartRoute(
                host: components.host,
                path: components.path,
                queryItems: components.queryItems,
                allowQueryFlag: false
            ) else {
                return nil
            }

        case "https", "http":
            guard isSupportedPortalHost(components.host),
                  isPortalStartRoute(
                    host: components.host,
                    path: components.path,
                    queryItems: components.queryItems,
                    allowQueryFlag: true
                  ) else {
                return nil
            }

        default:
            return nil
        }

        return parseQueryItems(components.queryItems ?? [])
    }

    private static func isSupportedPortalHost(_ host: String?) -> Bool {
        guard let normalizedHost = host?.lowercased() else { return false }

        return normalizedHost == "welcomeport.netlify.app"
            || normalizedHost == "www.welcomeport.netlify.app"
    }

    private static func isPortalStartRoute(
        host: String?,
        path: String,
        queryItems: [URLQueryItem]?,
        allowQueryFlag: Bool
    ) -> Bool {
        let normalizedHost = (host ?? "").lowercased()
        let normalizedPath = path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        if normalizedHost == "portal-start" || normalizedPath == "portal-start" {
            return true
        }

        guard allowQueryFlag else { return false }

        let queryValues = parseQueryItems(queryItems ?? [])
        let portalStartFlag = queryValues["portalstart"] ?? queryValues["portal-start"]

        switch portalStartFlag?.lowercased() {
        case "", "1", "true", "yes", "y":
            return true
        default:
            return false
        }
    }

    private static func parseQueryItems(_ items: [URLQueryItem]) -> [String: String] {
        items.reduce(into: [String: String]()) { result, item in
            let key = item.name.lowercased()
            let value = decodeQueryComponent(item.value ?? "")

            result[key] = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func decodeQueryComponent(_ value: String) -> String {
        let plusDecoded = value.replacingOccurrences(of: "+", with: " ")
        return plusDecoded.removingPercentEncoding ?? plusDecoded
    }

    func makeHostedSession() -> Session? {
        guard !fullName.isEmpty,
              !topic.isEmpty,
              !summary.isEmpty else {
            return nil
        }

        let hostId = UUID().uuidString
        return Session(
            title: topic,
            sessionCode: SessionViewModel.generateCode(),
            caseFile: SessionCaseFile(
                claimText: summary,
                requestedOutcome: additionalNotes,
                communicationMode: .structuredConversation,
                evidenceItems: []
            ),
            status: .waiting,
            currentTurn: .partyA,
            currentTurnNumber: 1,
            maxTurns: 2,
            turnDuration: 45,
            partyAId: hostId,
            partyBId: "",
            partyAName: fullName,
            partyBName: "Waiting for participant",
            turnStartedAt: nil
        )
    }
}

struct FeatureLabel: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
