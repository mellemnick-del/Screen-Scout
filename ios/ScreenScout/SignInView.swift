import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(HistoryStore.self) private var history
    @Environment(\.colorScheme) private var colorScheme

    @State private var isWorking = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Playful background bubbles
            GeometryReader { geo in
                Circle()
                    .fill(Theme.sky.opacity(0.18))
                    .frame(width: 260, height: 260)
                    .position(x: geo.size.width + 30, y: 40)
                Circle()
                    .fill(Theme.sunshine.opacity(0.25))
                    .frame(width: 180, height: 180)
                    .position(x: -20, y: geo.size.height * 0.55)
                Circle()
                    .fill(Theme.bubblegum.opacity(0.18))
                    .frame(width: 90, height: 90)
                    .position(x: geo.size.width - 40, y: geo.size.height * 0.72)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 14) {
                        ScoutBadge(size: 120, animated: true)
                        Text("Screen Scout")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text("Peek before they watch.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.softInk)
                    }
                    .padding(.top, 40)
                    .popIn()

                    VStack(alignment: .leading, spacing: 18) {
                        FeatureRow(
                            symbol: "binoculars.fill", color: Theme.grape,
                            title: "Scout any video",
                            text: "Paste a YouTube link and see what's really in it."
                        )
                        FeatureRow(
                            symbol: "person.2.fill", color: Theme.coral,
                            title: "Share with your family",
                            text: "Invite your partner or grandparents. Everyone sees the same reviews."
                        )
                        FeatureRow(
                            symbol: "ipad.and.iphone", color: Theme.sky,
                            title: "On all your devices",
                            text: "Your reviews follow you from iPhone to iPad."
                        )
                    }
                    .cardStyle(padding: 22)
                    .popIn(delay: 0.08)

                    VStack(spacing: 14) {
                        SignInWithAppleButton(.continue) { request in
                            auth.prepare(request)
                        } onCompletion: { result in
                            Task {
                                isWorking = true
                                await auth.complete(result, history: history)
                                isWorking = false
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 56)
                        .clipShape(Capsule())
                        .disabled(isWorking)

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.coral)
                                .multilineTextAlignment(.center)
                        }

                        Text("No passwords to remember. We only use your Apple ID to keep your family's reviews in sync.")
                            .font(.footnote)
                            .foregroundStyle(Theme.softInk)
                            .multilineTextAlignment(.center)
                    }
                    .popIn(delay: 0.16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

            if isWorking {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.large)
                        Text("Signing you in…")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isWorking)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(color.gradient)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Shown for a moment at launch while we check the saved login.
struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScoutBadge(size: 110, animated: true)
        }
    }
}
