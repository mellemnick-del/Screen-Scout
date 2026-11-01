import SwiftUI

struct ContentView: View {
    @Environment(HistoryStore.self) private var history
    @AppStorage("childAge") private var childAge: Int = 0

    @State private var urlText = ""
    @State private var isLoading = false
    @State private var stepIndex = 0
    @State private var errorMessage: String?
    @State private var path: [ReviewResult] = []
    @FocusState private var urlFocused: Bool

    private var canSubmit: Bool {
        !isLoading && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .popIn()
                    scoutCard
                        .popIn(delay: 0.05)
                    if let errorMessage {
                        ErrorBanner(message: errorMessage) {
                            withAnimation { self.errorMessage = nil }
                        }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    historySection
                        .popIn(delay: 0.1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReviewResult.self) { result in
                ReportView(result: result)
            }
            .overlay {
                if isLoading {
                    LoadingView(stepIndex: stepIndex)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLoading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            ScoutBadge(size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Scout")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("Peek before they watch.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.softInk)
            }
        }
        .padding(.top, 12)
    }

    // MARK: Scout card

    private var scoutCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What's on the watch list?")
                    .font(.title2.weight(.heavy))
                Text("Drop in a YouTube or YouTube Kids link and we'll scout it for you.")
                    .font(.subheadline.weight(.medium))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)

            // Link field (always light so it pops on the gradient)
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.headline)
                    .foregroundStyle(Theme.grape)
                TextField("Paste a video link", text: $urlText)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($urlFocused)
                    .onSubmit { if canSubmit { Task { await runReview() } } }
                if !urlText.isEmpty {
                    Button {
                        urlText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                    .accessibilityLabel("Clear link")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.white, in: Capsule())
            .environment(\.colorScheme, .light)

            PasteButton(payloadType: String.self) { strings in
                Task { @MainActor in
                    urlText = strings.first ?? ""
                    errorMessage = nil
                }
            }
            .buttonBorderShape(.capsule)
            .tint(Theme.sunshine)

            VStack(alignment: .leading, spacing: 10) {
                Text("Who's watching?")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                AgePicker(selection: $childAge)
            }

            Button {
                Task { await runReview() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "binoculars.fill")
                    Text("Scout This Video")
                }
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Theme.buttonGradient, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1.5))
                .shadow(color: Theme.coral.opacity(0.45), radius: 10, y: 6)
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.6)
        }
        .padding(20)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.heroGradient)
                // Playful background bubbles
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 180, height: 180)
                    .offset(x: 150, y: -150)
                Circle()
                    .fill(Theme.sunshine.opacity(0.22))
                    .frame(width: 110, height: 110)
                    .offset(x: -160, y: 170)
                Circle()
                    .fill(Theme.bubblegum.opacity(0.22))
                    .frame(width: 60, height: 60)
                    .offset(x: 140, y: 60)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .shadow(color: Theme.grape.opacity(0.3), radius: 18, y: 10)
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Scouted Videos")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !history.items.isEmpty {
                    Text("\(history.items.count)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.grape, in: Capsule())
                }
            }

            if history.items.isEmpty {
                EmptyHistoryCard()
            } else {
                ForEach(Array(history.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        ReviewCard(item: item)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { history.remove(item) }
                        } label: {
                            Label("Delete Review", systemImage: "trash")
                        }
                    }
                    .popIn(delay: Double(min(index, 6)) * 0.05)
                }
                Text("Tip: press and hold a video to delete it.")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Actions

    @MainActor
    private func runReview() async {
        urlFocused = false
        isLoading = true
        errorMessage = nil
        stepIndex = 0
        let ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                if stepIndex < LoadingView.steps.count - 1 {
                    withAnimation(.spring) { stepIndex += 1 }
                }
            }
        }
        defer {
            ticker.cancel()
            isLoading = false
        }

        do {
            let result = try await APIClient.shared.review(
                url: urlText,
                childAge: childAge == 0 ? nil : childAge
            )
            history.add(result)
            urlText = ""
            path.append(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Age picker

struct AgePicker: View {
    @Binding var selection: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(age: 0, label: "Any")
                    ForEach(2...17, id: \.self) { age in
                        chip(age: age, label: "\(age)")
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
    }

    private func chip(age: Int, label: String) -> some View {
        let selected = selection == age
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selection = age
            }
        } label: {
            Text(label)
                .font(.headline.weight(.heavy))
                .foregroundStyle(selected ? Theme.darkInk : .white)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, age == 0 ? 8 : 0)
                .background {
                    Capsule()
                        .fill(selected ? Theme.sunshine : Color.white.opacity(0.2))
                }
                .overlay {
                    Capsule().stroke(.white.opacity(selected ? 0.9 : 0.3), lineWidth: 2)
                }
                .scaleEffect(selected ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .id(age)
        .accessibilityLabel(age == 0 ? "Any age" : "\(age) years old")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Cards

struct ReviewCard: View {
    let item: ReviewResult

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: item.video.thumbnail) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Theme.heroGradient.opacity(0.4)
            }
            .frame(width: 112, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Text(formatDuration(item.video.duration))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7), in: Capsule())
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.video.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    VerdictPill(verdict: item.report.verdict)
                    AgeBadge(age: item.report.recommendedMinAge, compact: true)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Theme.softInk.opacity(0.6))
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct EmptyHistoryCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.grape.opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.grape)
            }
            Text("No videos scouted yet")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.ink)
            Text("Paste a link above to scout your first video. Your reviews will show up right here.")
                .font(.subheadline)
                .foregroundStyle(Theme.softInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.title2)
                .foregroundStyle(Theme.coral)
            VStack(alignment: .leading, spacing: 4) {
                Text("Hmm, that didn't work")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.softInk)
                    .padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .cardStyle(tint: Theme.coral)
    }
}

// MARK: - Loading

struct LoadingView: View {
    let stepIndex: Int

    static let steps: [(symbol: String, text: String)] = [
        ("play.rectangle.fill", "Grabbing the video"),
        ("captions.bubble.fill", "Listening to what's said"),
        ("photo.stack.fill", "Peeking at the pictures"),
        ("sparkles", "Writing your report"),
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ScoutBadge(size: 104, animated: true)
                VStack(spacing: 6) {
                    Text("Scouting…")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text("This usually takes under a minute.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.softInk)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Self.steps.indices, id: \.self) { i in
                        let done = i < stepIndex
                        let current = i == stepIndex
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(done ? Theme.mint : (current ? Theme.grape : Theme.softInk.opacity(0.2)))
                                Image(systemName: done ? "checkmark" : Self.steps[i].symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 34, height: 34)
                            Text(Self.steps[i].text)
                                .font(.headline)
                                .foregroundStyle(i <= stepIndex ? Theme.ink : Theme.softInk)
                            Spacer()
                            if current {
                                ProgressView()
                            }
                        }
                    }
                }
                .cardStyle(padding: 20)
            }
            .padding(28)
        }
    }
}

#Preview {
    ContentView()
        .environment(HistoryStore())
}
