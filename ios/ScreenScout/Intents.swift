import AppIntents
import Foundation
import Observation

/// A link handed to the app from Siri or Shortcuts, waiting to be scouted.
@Observable
final class PendingScout {
    static let shared = PendingScout()
    var url: String?
}

/// "Hey Siri, scout a video with Screen Scout", and a Shortcuts action that
/// can be added to the share sheet.
struct ScoutVideoIntent: AppIntent {
    static var title: LocalizedStringResource = "Scout a Video"
    static var description = IntentDescription("Check what's in a YouTube video before your kids watch it.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Video Link", description: "A YouTube or YouTube Kids link")
    var link: URL

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingScout.shared.url = link.absoluteString
        return .result()
    }
}

struct ScreenScoutShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScoutVideoIntent(),
            phrases: [
                "Scout a video with \(.applicationName)",
                "Check a video in \(.applicationName)",
            ],
            shortTitle: "Scout a Video",
            systemImageName: "binoculars.fill"
        )
    }
}
