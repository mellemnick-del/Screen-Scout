import Foundation

enum APIError: LocalizedError {
    case server(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): message
        case .badResponse: "The server sent back something unexpected. Try again."
        }
    }
}

struct APIClient {
    static let shared = APIClient()

    /// Reviews take a while (downloading frames + AI analysis), so allow a long wait.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    private struct ReviewBody: Encodable {
        let url: String
        let child_age: Int?
        let refresh: Bool
    }

    private struct ErrorBody: Decodable {
        let detail: String
    }

    func review(url: String, childAge: Int?, refresh: Bool = false) async throws -> ReviewResult {
        var request = URLRequest(url: Config.baseURL.appendingPathComponent("api/review"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONEncoder().encode(
            ReviewBody(url: url.trimmingCharacters(in: .whitespacesAndNewlines), child_age: childAge, refresh: refresh)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .notConnectedToInternet {
            throw APIError.server("Can't reach the Screen Scout server. Check your connection.")
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
            throw APIError.server(message ?? "Server error (\(http.statusCode)). Try again.")
        }
        do {
            return try JSONCoding.decoder.decode(ReviewResult.self, from: data)
        } catch {
            throw APIError.badResponse
        }
    }
}
