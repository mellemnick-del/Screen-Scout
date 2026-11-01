import AuthenticationServices
import CryptoKit
import Foundation
import Observation

/// Keeps track of who's signed in, and runs account and family actions.
@Observable
final class AuthManager {
    enum State {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var state: State
    private(set) var me: Me?
    var errorMessage: String?

    private var currentNonce: String?
    private var expiredObserver: NSObjectProtocol?

    init() {
        state = APIClient.token == nil ? .signedOut : .loading
        expiredObserver = NotificationCenter.default.addObserver(
            forName: .scoutSessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            self?.signOutLocally()
        }
    }

    // MARK: Startup

    /// Called at launch. Confirms the saved login still works.
    @MainActor
    func restore() async {
        guard APIClient.token != nil else {
            state = .signedOut
            return
        }
        do {
            me = try await APIClient.shared.me()
            state = .signedIn
        } catch APIError.unauthorized {
            signOutLocally()
        } catch {
            // Offline or server down: stay signed in so saved reviews still show.
            state = .signedIn
        }
    }

    @MainActor
    func refreshMe() async {
        guard state == .signedIn else { return }
        if let fresh = try? await APIClient.shared.me() {
            me = fresh
        }
    }

    // MARK: Sign in with Apple

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    @MainActor
    func complete(_ result: Result<ASAuthorization, Error>, history: HistoryStore) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = "Sign in didn't go through. Please try again."

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple didn't send back sign-in details. Please try again."
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            do {
                let response = try await APIClient.shared.signIn(
                    identityToken: identityToken,
                    authorizationCode: code,
                    nonce: nonce,
                    givenName: credential.fullName?.givenName,
                    familyName: credential.fullName?.familyName
                )
                APIClient.setToken(response.token)
                me = response.me
                state = .signedIn
                await history.didSignIn()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Sign out / delete

    @MainActor
    func signOut() async {
        await APIClient.shared.signOut()
        signOutLocally()
    }

    @MainActor
    func deleteAccount() async throws {
        try await APIClient.shared.deleteAccount()
        signOutLocally()
    }

    private func signOutLocally() {
        APIClient.setToken(nil)
        me = nil
        state = .signedOut
        NotificationCenter.default.post(name: .scoutSignedOut, object: nil)
    }

    // MARK: Profile and family

    /// Runs an action that returns the updated account, and stores the result.
    @MainActor
    func perform(_ action: () async throws -> Me) async throws {
        me = try await action()
    }

    // MARK: Helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
