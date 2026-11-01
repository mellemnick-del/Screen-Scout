import SwiftUI

@main
struct ScreenScoutApp: App {
    @State private var auth = AuthManager()
    @State private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(history)
                .fontDesign(.rounded)
                .tint(Theme.grape)
        }
    }
}

/// Shows the welcome screen or the app, depending on whether someone is signed in.
struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(HistoryStore.self) private var history

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                SplashView()
            case .signedOut:
                SignInView()
            case .signedIn:
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.state)
        .task {
            await auth.restore()
            if auth.state == .signedIn {
                await history.refresh()
            }
        }
    }
}
