import Foundation
import MultipeerConnectivity
import Combine

/// Peer-to-peer session discovery and sync using Apple's Multipeer Connectivity.
/// Works over local Wi-Fi, Wi-Fi Direct, and Bluetooth — no internet required.
/// Drop-in replacement for the WebSocket + SessionMessagingService stack.
class MultipeerService: NSObject, ObservableObject {

    // MARK: - Published (same API surface as WebSocket + SessionMessagingService combined)

    @Published var joinAnnouncement: SessionMessagingService.SessionSyncMessage?
    @Published var sessionState: SessionMessagingService.SessionSyncMessage?
    @Published var isConnected = false

    // MARK: - Private

    private let myPeerID: MCPeerID
    private let mcSession: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let sessionCode: String

    /// Bonjour service type registered in Info.plist NSBonjourServices.
    private static let serviceType = "welcomtalk"

    // MARK: - Init

    init(userId: String, userName: String, sessionCode: String) {
        self.sessionCode = sessionCode
        // MCPeerID.displayName max is 63 chars; embed short userId suffix for uniqueness
        let displayName = String("\(userName)-\(userId.prefix(6))".prefix(63))
        self.myPeerID = MCPeerID(displayName: displayName)
        self.mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)
        super.init()
        mcSession.delegate = self
    }

    // MARK: - Host: advertise session code

    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["code": sessionCode],
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Guest: browse for host with matching code

    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    // MARK: - Messaging (same API as SessionMessagingService)

    func announceSession(userId: String, userName: String, isHost: Bool, confirmationCode: String?) {
        send(SessionMessagingService.SessionSyncMessage(
            type: "join-session",
            sessionCode: sessionCode,
            userId: userId,
            userName: userName,
            isHost: isHost,
            confirmationCode: nil,
            session: nil,
            requestType: nil
        ))
    }

    func broadcastSessionState(
        userId: String,
        title: String,
        currentTurn: String,
        currentTurnNumber: Int,
        maxTurns: Int,
        turnDuration: Double,
        timeRemaining: Double,
        status: String,
        partyAId: String,
        partyBId: String
    ) {
        let data = SessionMessagingService.SessionSyncMessage.SessionData(
            title: title,
            currentTurn: currentTurn,
            currentTurnNumber: currentTurnNumber,
            maxTurns: maxTurns,
            turnDuration: turnDuration,
            timeRemaining: timeRemaining,
            status: status,
            partyAId: partyAId,
            partyBId: partyBId
        )
        send(SessionMessagingService.SessionSyncMessage(
            type: "session-state",
            sessionCode: sessionCode,
            userId: userId,
            userName: nil,
            isHost: nil,
            confirmationCode: nil,
            session: data,
            requestType: nil
        ))
    }

    func sendModificationRequest(userId: String, requestType: String) {
        send(SessionMessagingService.SessionSyncMessage(
            type: "request",
            sessionCode: sessionCode,
            userId: userId,
            userName: nil,
            isHost: nil,
            confirmationCode: nil,
            session: nil,
            requestType: requestType
        ))
    }

    func disconnect() {
        stopHosting()
        stopBrowsing()
        mcSession.disconnect()
    }

    // MARK: - Internal

    private func send(_ message: SessionMessagingService.SessionSyncMessage) {
        guard !mcSession.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(message) else { return }
        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
    }

    private func handle(data: Data) {
        guard let msg = try? JSONDecoder().decode(SessionMessagingService.SessionSyncMessage.self, from: data),
              msg.sessionCode.uppercased() == sessionCode.uppercased() else { return }

        DispatchQueue.main.async {
            switch msg.type {
            case "join-session":
                self.joinAnnouncement = msg
            case "session-state":
                self.sessionState = msg
            default:
                break
            }
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isConnected = !session.connectedPeers.isEmpty
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handle(data: data)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (Host auto-accepts invitations)

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Code already matched on the guest's side — accept unconditionally.
        invitationHandler(true, mcSession)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

// MARK: - MCNearbyServiceBrowserDelegate (Guest invites the host with the right code)

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["code"]?.uppercased() == sessionCode.uppercased() else { return }
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
