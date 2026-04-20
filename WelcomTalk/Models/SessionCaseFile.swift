import Foundation

public struct SessionCaseFile: Codable, Hashable {
    public enum CommunicationMode: String, Codable, CaseIterable, Hashable {
        case structuredConversation
        case audioCall
        case videoCall

        public var displayName: String {
            switch self {
            case .structuredConversation:
                return "Structured in-app conversation"
            case .audioCall:
                return "Audio call"
            case .videoCall:
                return "Video call"
            }
        }

        public var symbolName: String {
            switch self {
            case .structuredConversation:
                return "bubble.left.and.bubble.right"
            case .audioCall:
                return "phone.fill"
            case .videoCall:
                return "video.fill"
            }
        }

        public var documentationNote: String {
            switch self {
            case .structuredConversation:
                return "Conversation stays in the app with timed turns and a full session log."
            case .audioCall:
                return "Audio-call mode is documented in the case file. Live calling infrastructure can be added on top later."
            case .videoCall:
                return "Video-call mode is documented in the case file. Live video infrastructure can be added on top later."
            }
        }
    }

    public var claimText: String
    public var requestedOutcome: String
    public var communicationMode: CommunicationMode
    public var evidenceItems: [SessionEvidence]
    public var createdAt: Date

    public init(
        claimText: String,
        requestedOutcome: String = "",
        communicationMode: CommunicationMode = .structuredConversation,
        evidenceItems: [SessionEvidence] = [],
        createdAt: Date = Date()
    ) {
        self.claimText = claimText
        self.requestedOutcome = requestedOutcome
        self.communicationMode = communicationMode
        self.evidenceItems = evidenceItems
        self.createdAt = createdAt
    }

    public var hasSupportingEvidence: Bool {
        !evidenceItems.isEmpty
    }
}

public struct SessionEvidence: Identifiable, Codable, Hashable {
    public enum Kind: String, Codable, CaseIterable, Hashable {
        case text
        case document

        public var displayName: String {
            switch self {
            case .text:
                return "Text evidence"
            case .document:
                return "Document evidence"
            }
        }

        public var symbolName: String {
            switch self {
            case .text:
                return "text.alignleft"
            case .document:
                return "doc.text.fill"
            }
        }
    }

    public let id: String
    public var title: String
    public var detail: String
    public var kind: Kind
    public var fileName: String?
    public var addedByUserId: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        detail: String,
        kind: Kind,
        fileName: String? = nil,
        addedByUserId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.fileName = fileName
        self.addedByUserId = addedByUserId
        self.createdAt = createdAt
    }

    public var documentationLine: String {
        let fileLine = fileName.map { " File: \($0)." } ?? ""
        return "\(kind.displayName): \(title) — \(detail).\(fileLine)"
    }
}
