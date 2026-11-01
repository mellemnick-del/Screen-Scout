import Foundation

// These mirror the JSON the backend returns from POST /api/review.
// Keys arrive in snake_case and are converted by JSONCoding below.
// Colors, labels and icons for these types live in Theme.swift.

struct ReviewResult: Codable, Identifiable, Hashable {
    let videoId: String
    let childAge: Int
    let created: Double
    let video: VideoInfo
    let report: Report
    var cached: Bool?

    var id: String { "\(videoId)-\(childAge)" }
    var createdDate: Date { Date(timeIntervalSince1970: created) }
}

struct VideoInfo: Codable, Hashable {
    let videoId: String
    let url: String
    let title: String
    let channel: String
    let duration: Int
    let thumbnailUrl: String?
    let hadTranscript: Bool
    let framesReviewed: Int
    let notes: [String]

    var thumbnail: URL? {
        URL(string: thumbnailUrl ?? "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
    }
}

struct Report: Codable, Hashable {
    let verdict: Verdict
    let recommendedMinAge: Int
    let fitForChild: Fit
    let headline: String
    let summary: String
    let categories: [CategoryRating]
    let flaggedMoments: [FlaggedMoment]
    let positives: [String]
    let educationalValue: Level
    let talkAboutIt: [String]
    let confidence: String
    let confidenceReason: String

    func rating(for category: Category) -> CategoryRating {
        categories.first { $0.category == category }
            ?? CategoryRating(category: category, level: .none, details: "Nothing found.")
    }

    /// How many categories had anything at all.
    var flaggedCategoryCount: Int {
        Category.allCases.filter { rating(for: $0).level != .none }.count
    }
}

struct CategoryRating: Codable, Hashable {
    let category: Category
    let level: Level
    let details: String
}

struct FlaggedMoment: Codable, Hashable, Identifiable {
    let timestamp: String
    let category: Category
    let description: String

    var id: String { timestamp + category.rawValue + description }

    /// "1:23" or "1:02:03" to seconds. nil for things like "throughout".
    var seconds: Int? {
        let parts = timestamp.split(separator: ":").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }

    func link(in videoURL: String) -> URL? {
        guard let seconds else { return nil }
        return URL(string: "\(videoURL)&t=\(seconds)s")
    }
}

enum Verdict: String, Codable, Hashable, CaseIterable {
    case safe
    case caution
    case notRecommended = "not_recommended"
}

enum Fit: String, Codable, Hashable {
    case goodFit = "good_fit"
    case watchTogether = "watch_together"
    case skip
}

enum Level: String, Codable, Hashable, CaseIterable {
    case none, mild, moderate, strong, severe

    var index: Int { Level.allCases.firstIndex(of: self) ?? 0 }
}

enum Category: String, Codable, Hashable, CaseIterable, Identifiable {
    case violence
    case scaryOrDisturbing = "scary_or_disturbing"
    case language
    case sexualContent = "sexual_content"
    case dangerousImitableBehavior = "dangerous_imitable_behavior"
    case badBehaviorAndAttitudes = "bad_behavior_and_attitudes"
    case commercialism
    case misleadingOrHijackedCharacters = "misleading_or_hijacked_characters"
    case overstimulation

    var id: String { rawValue }
}

// MARK: - Accounts and families (from GET /api/me)

struct Me: Codable, Hashable {
    let user: UserInfo
    let family: FamilyInfo
}

struct UserInfo: Codable, Hashable {
    let id: String
    let name: String?
    let email: String?

    var displayName: String { name ?? "Parent" }

    var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct FamilyInfo: Codable, Hashable {
    let id: String
    let name: String
    let inviteCode: String
    let isOwner: Bool
    let members: [Member]
    let maxMembers: Int
    let usage: Usage

    /// "ABC123" shown as "ABC-123" so it's easier to read out loud.
    var formattedInviteCode: String {
        guard inviteCode.count == 6 else { return inviteCode }
        return "\(inviteCode.prefix(3))-\(inviteCode.suffix(3))"
    }
}

struct Member: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let isOwner: Bool
    let isYou: Bool

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct Usage: Codable, Hashable {
    let used: Int
    let limit: Int
    let resetsAt: Double

    var isUnlimited: Bool { limit <= 0 }
    var remaining: Int { max(limit - used, 0) }
    var resetDate: Date { Date(timeIntervalSince1970: resetsAt) }
}

enum JSONCoding {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}

func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
