import SwiftUI

/// Past reviews, saved on the phone so parents can look them up again offline.
@Observable
final class HistoryStore {
    private(set) var items: [ReviewResult] = []

    private let fileURL = URL.documentsDirectory.appending(path: "history.json")

    init() {
        load()
    }

    func add(_ result: ReviewResult) {
        items.removeAll { $0.id == result.id }
        items.insert(result, at: 0)
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func remove(_ result: ReviewResult) {
        items.removeAll { $0.id == result.id }
        save()
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
