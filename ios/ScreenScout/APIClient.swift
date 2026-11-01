import Foundation

extension Notification.Name {
    /// The server rejected our login token (signed out elsewhere, account removed, etc.).
    static let scoutSessionExpired = Notification.Name("scoutSessionExpired")
    /// The user signed out on this device. Local data should be cleared.
    static let scoutSignedOut = Notification.Name("scoutSignedOut")
}

enum APIError: LocalizedError {
    case server(String)
    case badResponse
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .server(let message): message
        case .badResponse: "The server sent back something unexpected. Try again."
        case .unauthorized: "Please sign in again."
        }
    }
}

struct SignInResponse: Decodable {
    let token: String
    let me: Me
}

private struct OKResponse: Decodable {
    let ok: Bool
}

private struct ErrorBody: Decodable {
    let detail: String
}

struct APIClient {
    static let shared = APIClient()

    // MARK: Login token

    private static let tokenKey = "session-token"
    private(set) static var token: String? = Keychain.load(tokenKey)

    static func setToken(_ newToken: String?) {
        token = newToken
        if let newToken {
            Keychain.save(newToken, for: tokenKey)
        } else {
            Keychain.delete(tokenKey)
        }
    }

    // MARK: Plumbing

    /// Reviews take a while (downloading frames + AI analysis), so allow a long wait.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    private static let offlineCodes: [URLError.Code] = [
        .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .networkConnectionLost, .timedOut,
    ]

    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        body: (any Encodable)? = nil,
        authorized: Bool = true
    ) async throws -> Response {
        var request = URLRequest(url: Config.baseURL.appending(path: path))
        request.httpMethod = method
        if authorized, let token = Self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw APIError.server("Can't reach the Screen Scout server. Check your connection.")
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        if http.statusCode == 401 && authorized {
            NotificationCenter.default.post(name: .scoutSessionExpired, object: nil)
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
            throw APIError.server(message ?? "Server error (\(http.statusCode)). Try again.")
        }
        do {
            return try JSONCoding.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.badResponse
        }
    }

    // MARK: Account

    func signIn(
        identityToken: String,
        authorizationCode: String?,
        nonce: String,
        givenName: String?,
        familyName: String?
    ) async throws -> SignInResponse {
        struct Body: Encodable {
            let identityToken: String
            let authorizationCode: String?
            let nonce: String
            let givenName: String?
            let familyName: String?
        }
        return try await send(
            "POST", "api/auth/apple",
            body: Body(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce,
                givenName: givenName,
                familyName: familyName
            ),
            authorized: false
        )
    }

    func me() async throws -> Me {
        try await send("GET", "api/me")
    }

    func updateName(_ name: String) async throws -> Me {
        struct Body: Encodable { let name: String }
        return try await send("PATCH", "api/me", body: Body(name: name))
    }

    func signOut() async {
        do {
            let _: OKResponse = try await send("POST", "api/auth/logout")
        } catch {
            // Signing out locally still works if the server can't be reached.
        }
    }

    func deleteAccount() async throws {
        let _: OKResponse = try await send("DELETE", "api/me")
    }

    // MARK: Family

    func joinFamily(code: String) async throws -> Me {
        struct Body: Encodable { let code: String }
        return try await send("POST", "api/family/join", body: Body(code: code))
    }

    func leaveFamily() async throws -> Me {
        try await send("POST", "api/family/leave")
    }

    func renameFamily(_ name: String) async throws -> Me {
        struct Body: Encodable { let name: String }
        return try await send("PATCH", "api/family", body: Body(name: name))
    }

    func resetInviteCode() async throws -> Me {
        try await send("POST", "api/family/invite-code")
    }

    func removeMember(_ memberId: String) async throws -> Me {
        try await send("DELETE", "api/family/members/\(memberId)")
    }

    // MARK: Reviews

    func review(url: String, childAge: Int?, refresh: Bool = false) async throws -> ReviewResult {
        struct Body: Encodable {
            let url: String
            let childAge: Int?
            let refresh: Bool
        }
        return try await send(
            "POST", "api/review",
            body: Body(url: url.trimmingCharacters(in: .whitespacesAndNewlines), childAge: childAge, refresh: refresh)
        )
    }

    func reviews() async throws -> [ReviewResult] {
        try await send("GET", "api/reviews")
    }

    func deleteReview(_ review: ReviewResult) async throws {
        let _: OKResponse = try await send("DELETE", "api/reviews/\(review.videoId)/\(review.childAge)")
    }

    func importReviews(_ items: [ReviewResult]) async throws {
        struct Item: Encodable {
            let videoId: String
            let childAge: Int
        }
        struct Body: Encodable { let items: [Item] }
        let _: OKResponse = try await send(
            "POST", "api/reviews/import",
            body: Body(items: items.map { Item(videoId: $0.videoId, childAge: $0.childAge) })
        )
    }
}
