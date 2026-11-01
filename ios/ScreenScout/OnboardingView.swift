import SwiftUI

/// A three-page welcome tour shown the first time the app opens.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var showSample = false

    private struct Page {
        let symbol: String
        let color: Color
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(
            symbol: "binoculars.fill", color: Theme.sky,
            title: "Peek before they watch",
            text: "Paste any YouTube or YouTube Kids link. Screen Scout watches it for you and tells you what's inside."
        ),
        Page(
            symbol: "square.grid.2x2.fill", color: Theme.grape,
            title: "See the full picture",
            text: "Violence, scary stuff, ads, bad attitudes, overstimulation, and more, with timestamps you can tap."
        ),
        Page(
            symbol: "person.2.fill", color: Theme.coral,
            title: "Scout as a family",
            text: "Add your kids and invite your partner or grandparents, so everyone's on the same page."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip", action: onFinish)
                            .font(.headline)
                            .foregroundStyle(Theme.softInk)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 24)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 14) {
                    Button {
                        if page < pages.count - 1 {
                            withAnimation { page += 1 }
                        } else {
                            onFinish()
                        }
                    } label: {
                        Text(page < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.buttonGradient, in: Capsule())
                            .shadow(color: Theme.coral.opacity(0.4), radius: 10, y: 6)
                    }
                    .buttonStyle(BouncyButtonStyle())

                    Button("See a sample report") {
                        showSample = true
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.grape)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 560)
        }
        .sensoryFeedback(.selection, trigger: page)
        .sheet(isPresented: $showSample) {
            SampleReportSheet()
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 230, height: 230)
                Circle()
                    .fill(page.color.gradient)
                    .frame(width: 150, height: 150)
                    .shadow(color: page.color.opacity(0.45), radius: 18, y: 10)
                Image(systemName: page.symbol)
                    .font(.system(size: 62, weight: .bold))
                    .foregroundStyle(.white)
                Circle()
                    .fill(Theme.sunshine)
                    .frame(width: 34, height: 34)
                    .offset(x: 95, y: -80)
                Circle()
                    .fill(Theme.bubblegum.opacity(0.8))
                    .frame(width: 20, height: 20)
                    .offset(x: -100, y: 70)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(page.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.softInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 40)
    }
}

/// The sample report in its own sheet, for people who haven't signed in yet.
struct SampleReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ReportView(result: SampleData.review)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                            .bold()
                    }
                }
        }
    }
}
