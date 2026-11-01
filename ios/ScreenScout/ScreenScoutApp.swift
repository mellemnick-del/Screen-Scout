import SwiftUI

@main
struct ScreenScoutApp: App {
    @State private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(history)
        }
    }
}
