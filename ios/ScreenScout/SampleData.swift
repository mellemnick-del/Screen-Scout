import Foundation

/// A made-up report that shows new parents (and Apple's reviewers) what Screen Scout does
/// before they scout a real video. The video and channel are fictional.
enum SampleData {
    static let videoId = "SAMPLE00001"

    static let review = ReviewResult(
        videoId: videoId,
        childAge: 4,
        created: Date().timeIntervalSince1970,
        video: VideoInfo(
            videoId: videoId,
            url: "",
            title: "Sample: Counting Colors with Pip the Penguin",
            channel: "Sample Channel",
            duration: 512,
            thumbnailUrl: "",
            hadTranscript: true,
            framesReviewed: 16,
            notes: []
        ),
        report: Report(
            verdict: .caution,
            recommendedMinAge: 3,
            fitForChild: .watchTogether,
            headline: "Sweet counting fun, but nonstop sound effects and a toy plug make it a watch-together pick.",
            summary: "Pip the Penguin hops around a snowy town finding colorful objects and counting them out loud from 1 to 10. Songs repeat each color name, and Pip cheers kids on for counting along. Around the middle there's a burst of flashing colors with loud whooshes, and near the end Pip shows off a toy and suggests asking a grown-up to buy one.",
            categories: [
                CategoryRating(category: .overstimulation, level: .moderate, details: "Fast cuts, flashing colors, and loud sound effects, especially in the middle section."),
                CategoryRating(category: .commercialism, level: .mild, details: "Pip holds up a toy and says to ask a grown-up to get one."),
                CategoryRating(category: .violence, level: .none, details: "Nothing found."),
                CategoryRating(category: .scaryOrDisturbing, level: .none, details: "Nothing found."),
                CategoryRating(category: .language, level: .none, details: "Nothing found."),
                CategoryRating(category: .sexualContent, level: .none, details: "Nothing found."),
                CategoryRating(category: .dangerousImitableBehavior, level: .none, details: "Nothing found."),
                CategoryRating(category: .badBehaviorAndAttitudes, level: .none, details: "Nothing found."),
                CategoryRating(category: .misleadingOrHijackedCharacters, level: .none, details: "Nothing found."),
            ],
            flaggedMoments: [
                FlaggedMoment(timestamp: "3:05", category: .overstimulation, description: "About 30 seconds of rapid flashing colors and loud whooshes."),
                FlaggedMoment(timestamp: "7:40", category: .commercialism, description: "Pip shows a plush toy: \"Ask a grown-up to get one for you!\""),
            ],
            positives: [
                "Practices counting from 1 to 10",
                "Teaches color names with catchy songs",
                "Kind, encouraging tone throughout",
            ],
            educationalValue: .moderate,
            talkAboutIt: [
                "What was your favorite color Pip found?",
                "Can you count 5 blue things in this room?",
                "Do we need to buy every toy we see in a video?",
            ],
            confidence: "high",
            confidenceReason: "This is a sample report made up to show how Screen Scout works."
        )
    )
}
