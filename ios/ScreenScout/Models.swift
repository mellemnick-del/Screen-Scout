import SwiftUI

// These mirror the JSON the backend returns from POST /api/review.
// Keys arrive in snake_case and are converted by JSONCoding below.

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
}

enum Verdict: String, Codable, Hashable {
    case safe
    case caution
    case notRecommended = "not_recommended"

    var label: String {
        switch self {
        case .safe: "Safe"
        case .caution: "Use Caution"
        case .notRecommended: "Not Recommended"
        }
    }

    var color: Color {
        switch self {
        case .safe: .green
        case .caution: .orange
        case .notRecommended: .red
        }
    }

    var symbol: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .notRecommended: "xmark.octagon.fill"
        }
    }
}

enum Fit: String, Codable, Hashable {
    case goodFit = "good_fit"
    case watchTogether = "watch_together"
    case skip

    var label: String {
        switch self {
        case .goodFit: "Good fit for your child"
        case .watchTogether: "Watch together"
        case .skip: "Skip this one"
        }
    }
}

enum Level: String, Codable, Hashable, CaseIterable {
    case none, mild, moderate, strong, severe

    var index: Int { Level.allCases.firstIndex(of: self) ?? 0 }

    var color: Color {
        switch self {
        case .none, .mild: Color(red: 0.45, green: 0.72, blue: 0.52)
        case .moderate: Color(red: 0.91, green: 0.72, blue: 0.27)
        case .strong: Color(red: 0.89, green: 0.50, blue: 0.27)
        case .severe: Color(red: 0.79, green: 0.26, blue: 0.23)
        }
    }
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

    var label: String {
        switch self {
        case .violence: "Violence"
        case .scaryOrDisturbing: "Scary or disturbing"
        case .language: "Language"
        case .sexualContent: "Sexual content"
        case .dangerousImitableBehavior: "Stunts kids may copy"
        case .badBehaviorAndAttitudes: "Bad behavior and attitudes"
        case .commercialism: "Ads and consumerism"
        case .misleadingOrHijackedCharacters: "Misused kids' characters"
        case .overstimulation: "Overstimulation"
        }
    }

    var symbol: String {
        switch self {
        case .violence: "hand.raised.fill"
        case .scaryOrDisturbing: "eye.trianglebadge.exclamationmark"
        case .language: "text.bubble.fill"
        case .sexualContent: "heart.slash.fill"
        case .dangerousImitableBehavior: "flame.fill"
        case .badBehaviorAndAttitudes: "face.dashed.fill"
        case .commercialism: "cart.fill"
        case .misleadingOrHijackedCharacters: "theatermasks.fill"
        case .overstimulation: "waveform.path.ecg"
        }
    }
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
