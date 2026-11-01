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
                .environment(PendingScout.shared)
                .fontDesign(.rounded)
                .tint(Theme.grape)
        }
    }
}

/// Shows the welcome screen or the app, depending on whether someone is signed in.
struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(HistoryStore.self) private var history
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                SplashView()
            case .signedOut:
                if hasSeenOnboarding {
                    SignInView()
                } else {
                    OnboardingView { hasSeenOnboarding = true }
                }
            case .signedIn:
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.state)
        .animation(.easeInOut(duration: 0.35), value: hasSeenOnboarding)
        .task {
            await auth.restore()
            if auth.state == .signedIn {
                await history.refresh()
            }
        }
    }
}
