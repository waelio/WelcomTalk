import Foundation

struct PortalRequestAttachment: Codable {
    let fileName: String
    let contentType: String
    let storageRef: String
}

struct PortalRequestRecord: Codable {
    let requestId: String
    let createdAt: String
    let source: String
    let fullName: String
    let topic: String
    let summary: String
    let additionalNotes: String
    let status: String
    let attachments: [PortalRequestAttachment]
    let expiresAt: String
}

enum PortalRequestServiceError: LocalizedError {
    case invalidPortalPayload
    case requestNotFound
    case invalidResponse
    case networkFailure(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidPortalPayload:
            return "That portal link is missing the session details it needs."
        case .requestNotFound:
            return "That portal request could not be found. Generate a fresh barcode or link from WelcomTalk Portal."
        case .invalidResponse:
            return "The portal request was found, but its saved data could not be read."
        case .networkFailure(let message):
            return "Couldn't reach the portal request service. \(message)"
        case .serverError(let message):
            return message.isEmpty
                ? "The portal request service returned an unexpected response."
                : message
        }
    }
}

struct PortalRequestService {
    private struct ErrorPayload: Codable {
        let error: String
    }

    var session: URLSession = .shared
    var baseURL: URL = Self.defaultBaseURL

    static var defaultBaseURL: URL {
        apiBaseURL(from: WebSocketService.configuredServerURL)
            ?? URL(string: "https://waelio-messaging.onrender.com")!
    }

    private static func apiBaseURL(from websocketURL: String) -> URL? {
        guard var components = URLComponents(string: websocketURL) else {
            return nil
        }

        switch components.scheme?.lowercased() {
        case "ws":
            components.scheme = "http"
        case "wss":
            components.scheme = "https"
        case "http", "https":
            break
        default:
            return nil
        }

        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func fetchRequest(requestId: String) async throws -> PortalRequestRecord {
        let normalizedRequestId = requestId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedRequestId.isEmpty else {
            throw PortalRequestServiceError.invalidPortalPayload
        }

        let requestURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("portal-requests")
            .appendingPathComponent(normalizedRequestId)

        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PortalRequestServiceError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PortalRequestServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(PortalRequestRecord.self, from: data)
            } catch {
                throw PortalRequestServiceError.invalidResponse
            }

        case 404:
            throw PortalRequestServiceError.requestNotFound

        default:
            if let errorPayload = try? JSONDecoder().decode(ErrorPayload.self, from: data) {
                throw PortalRequestServiceError.serverError(errorPayload.error)
            }

            throw PortalRequestServiceError.serverError(
                "The portal request service returned status \(httpResponse.statusCode)."
            )
        }
    }
}

extension PortalSessionImport {
    init(record: PortalRequestRecord) {
        self.init(
            requestId: record.requestId,
            fullName: record.fullName,
            topic: record.topic,
            summary: record.summary,
            additionalNotes: record.additionalNotes,
            attachments: record.attachments
        )
    }

    func resolvePortalImport(using service: PortalRequestService? = nil) async throws -> PortalSessionImport {
        if makeHostedSession() != nil {
            return self
        }

        guard let requestId,
              !requestId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PortalRequestServiceError.invalidPortalPayload
        }

        let requestService = service ?? PortalRequestService()
        let record = try await requestService.fetchRequest(requestId: requestId)
        return PortalSessionImport(record: record)
    }

    func resolveHostedSession(using service: PortalRequestService? = nil) async throws -> Session {
        let resolvedImport = try await resolvePortalImport(using: service)

        guard let hostedSession = resolvedImport.makeHostedSession() else {
            throw PortalRequestServiceError.invalidResponse
        }

        return hostedSession
    }
}