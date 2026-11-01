import SwiftUI

/// The family's scouted videos. Lives on the server so every device and every
/// family member sees the same list. A copy is kept on the phone for offline viewing.
@Observable
final class HistoryStore {
    private(set) var items: [ReviewResult] = []

    private let fileURL = URL.documentsDirectory.appending(path: "history.json")
    private var signedOutObserver: NSObjectProtocol?

    init() {
        load()
        signedOutObserver = NotificationCenter.default.addObserver(
            forName: .scoutSignedOut, object: nil, queue: .main
        ) { [weak self] _ in
            self?.clear()
        }
    }

    /// Adds a just-finished review to the top of the list right away.
    func add(_ result: ReviewResult) {
        items.removeAll { $0.id == result.id }
        items.insert(result, at: 0)
        save()
    }

    /// Pulls the latest family list from the server.
    @MainActor
    func refresh() async {
        guard let fresh = try? await APIClient.shared.reviews() else { return }
        items = fresh
        save()
    }

    @MainActor
    func delete(_ result: ReviewResult) async {
        items.removeAll { $0.id == result.id }
        save()
        try? await APIClient.shared.deleteReview(result)
    }

    /// After signing in, move any reviews saved on this phone into the family, then sync.
    @MainActor
    func didSignIn() async {
        if !items.isEmpty {
            try? await APIClient.shared.importReviews(items)
        }
        await refresh()
    }

    func clear() {
        items = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONCoding.decoder.decode([ReviewResult].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONCoding.encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
