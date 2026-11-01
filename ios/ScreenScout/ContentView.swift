import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(HistoryStore.self) private var history
    @Environment(AuthManager.self) private var auth
    @Environment(PendingScout.self) private var pending
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("childAge") private var childAge: Int = 0
    @AppStorage("selectedKidId") private var selectedKidId: String = ""
    @AppStorage("dismissedClipboardChange") private var dismissedClipboardChange: Int = -1

    @State private var urlText = ""
    @State private var isLoading = false
    @State private var stepIndex = 0
    @State private var errorMessage: String?
    @State private var path: [ReviewResult] = []
    @State private var showAccount = false
    @State private var showKidEditor = false
    @State private var clipboardHasLink = false
    @State private var searchText = ""
    @State private var verdictFilter: Verdict?
    @State private var kidFilter: String?
    @FocusState private var urlFocused: Bool

    private var kids: [Kid] { auth.me?.family.kidList ?? [] }

    /// The kid picked in "Who's watching?", if that kid still exists.
    private var selectedKid: Kid? { kids.first { $0.id == selectedKidId } }

    private var canSubmit: Bool {
        !isLoading && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredItems: [ReviewResult] {
        history.items.filter { item in
            let query = searchText.trimmingCharacters(in: .whitespaces)
            let matchesSearch = query.isEmpty
                || item.video.title.localizedCaseInsensitiveContains(query)
                || item.video.channel.localizedCaseInsensitiveContains(query)
            let matchesVerdict = verdictFilter == nil || item.report.verdict == verdictFilter
            let matchesKid = kidFilter == nil || item.kidId == kidFilter
            return matchesSearch && matchesVerdict && matchesKid
        }
    }

    private var showFilters: Bool { history.items.count >= 4 }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .popIn()
                    if clipboardHasLink && urlText.isEmpty && !isLoading {
                        clipboardBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
                // Keep a comfortable reading width on iPad.
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await history.refresh()
                await auth.refreshMe()
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
            }
            .sheet(isPresented: $showKidEditor) {
                KidEditorSheet(kid: nil)
            }
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
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: clipboardHasLink)
            .sensoryFeedback(trigger: isLoading) { _, started in started ? .impact(weight: .medium) : nil }
            .sensoryFeedback(trigger: errorMessage) { _, message in message == nil ? nil : .error }
            .onAppear {
                checkClipboard()
                handlePendingScout()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { checkClipboard() }
            }
            .onChange(of: pending.url) { _, _ in
                handlePendingScout()
            }
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
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Peek before they watch.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.softInk)
            }
            Spacer(minLength: 0)
            Button {
                showAccount = true
            } label: {
                Avatar(initials: auth.me?.user.initials ?? "?", color: Theme.coral, size: 46)
                    .shadow(color: Theme.coral.opacity(0.35), radius: 6, y: 3)
            }
            .accessibilityLabel("Account and family")
        }
        .padding(.top, 12)
    }

    // MARK: Copied-link banner

    private var clipboardBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.sunshine.gradient)
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.darkInk)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Copied a link?")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("Paste it to start scouting right away.")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }

            Spacer(minLength: 0)

            PasteButton(payloadType: String.self) { strings in
                Task { @MainActor in
                    pasteAndScout(strings.first)
                }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(Theme.grape)

            Button {
                dismissedClipboardChange = UIPasteboard.general.changeCount
                clipboardHasLink = false
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.softInk)
                    .padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .cardStyle(tint: Theme.sunshine, padding: 14)
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
                    clipboardHasLink = false
                }
            }
            .buttonBorderShape(.capsule)
            .tint(Theme.sunshine)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Who's watching?")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        showKidEditor = true
                    } label: {
                        Label(kids.isEmpty ? "Add your kids" : "Add", systemImage: "plus")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
                if !kids.isEmpty {
                    KidPicker(kids: kids, selectedKidId: $selectedKidId)
                }
                if selectedKid == nil {
                    AgePicker(selection: $childAge)
                }
            }

            Button {
                Task { await runReview() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "binoculars.fill")
                    Text(selectedKid.map { "Scout for \($0.name)" } ?? "Scout This Video")
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

            if let usage = auth.me?.family.usage, !usage.isUnlimited {
                Text(usage.remaining == 1 ? "1 new review left this month" : "\(usage.remaining) new reviews left this month")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
            }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scouted Videos")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    if let family = auth.me?.family, family.members.count > 1 {
                        Text("Shared with \(family.name)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.softInk)
                    }
                }
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

            if showFilters {
                searchAndFilters
            }

            if history.items.isEmpty {
                EmptyHistoryCard {
                    path.append(SampleData.review)
                }
            } else if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Text("🔍").font(.largeTitle)
                    Text("No videos match")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Button("Clear filters") {
                        withAnimation {
                            searchText = ""
                            verdictFilter = nil
                            kidFilter = nil
                        }
                    }
                    .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .cardStyle(padding: 24)
            } else {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        ReviewCard(item: item)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await history.delete(item) }
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

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.softInk)
                TextField("Search your videos", text: $searchText)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.softInk)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isOn: verdictFilter == nil && kidFilter == nil, color: Theme.grape) {
                        verdictFilter = nil
                        kidFilter = nil
                    }
                    ForEach(Verdict.allCases, id: \.self) { verdict in
                        FilterChip(title: "\(verdict.emoji) \(verdict.label)", isOn: verdictFilter == verdict, color: verdict.color) {
                            verdictFilter = verdictFilter == verdict ? nil : verdict
                        }
                    }
                    ForEach(kids) { kid in
                        FilterChip(title: kid.name, isOn: kidFilter == kid.id, color: kid.themeColor) {
                            kidFilter = kidFilter == kid.id ? nil : kid.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .sensoryFeedback(.selection, trigger: verdictFilter)
        .sensoryFeedback(.selection, trigger: kidFilter)
    }

    // MARK: Actions

    private func checkClipboard() {
        let board = UIPasteboard.general
        // hasURLs doesn't trigger the "Allow Paste" prompt.
        clipboardHasLink = board.hasURLs && board.changeCount != dismissedClipboardChange
    }

    private func pasteAndScout(_ text: String?) {
        dismissedClipboardChange = UIPasteboard.general.changeCount
        clipboardHasLink = false
        guard let text, !text.isEmpty else { return }
        urlText = text
        errorMessage = nil
        if text.localizedCaseInsensitiveContains("youtu") {
            Task { await runReview() }
        }
    }

    private func handlePendingScout() {
        guard let link = pending.url, !isLoading else { return }
        pending.url = nil
        urlText = link
        path.removeAll()
        Task { await runReview() }
    }

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

        let kid = selectedKid
        do {
            let result = try await APIClient.shared.review(
                url: urlText,
                childAge: kid == nil && childAge != 0 ? childAge : nil,
                kidId: kid?.id
            )
            history.add(result)
            urlText = ""
            path.append(result)
            await auth.refreshMe()
        } catch APIError.unauthorized {
            // The app has already returned to the sign-in screen.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Kid picker

struct KidPicker: View {
    let kids: [Kid]
    @Binding var selectedKidId: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kids) { kid in
                    chip(
                        id: kid.id,
                        selected: selectedKidId == kid.id,
                        label: {
                            HStack(spacing: 8) {
                                Avatar(initials: kid.initial, color: kid.themeColor, size: 30)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(kid.name)
                                        .font(.subheadline.weight(.heavy))
                                    Text("Age \(kid.age)")
                                        .font(.caption2.weight(.bold))
                                        .opacity(0.8)
                                }
                            }
                        }
                    )
                    .accessibilityLabel("\(kid.name), age \(kid.age)")
                }
                chip(id: "", selected: selectedKidId.isEmpty || !kids.contains { $0.id == selectedKidId }, label: {
                    Text("Other age")
                        .font(.subheadline.weight(.heavy))
                        .padding(.horizontal, 4)
                })
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .sensoryFeedback(.selection, trigger: selectedKidId)
    }

    private func chip<Label: View>(id: String, selected: Bool, @ViewBuilder label: () -> Label) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedKidId = id
            }
        } label: {
            label()
                .foregroundStyle(selected ? Theme.darkInk : .white)
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .frame(minHeight: 46)
                .background {
                    Capsule().fill(selected ? Theme.sunshine : Color.white.opacity(0.2))
                }
                .overlay {
                    Capsule().stroke(.white.opacity(selected ? 0.9 : 0.3), lineWidth: 2)
                }
                .scaleEffect(selected ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FilterChip: View {
    let title: String
    let isOn: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? .white : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Theme.card), in: Capsule())
                .overlay(Capsule().stroke(isOn ? Color.clear : Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
        .sensoryFeedback(.selection, trigger: selection)
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
                if let kidName = item.kidName {
                    Label("For \(kidName)", systemImage: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.softInk)
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
    var showSample: (() -> Void)?

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
            if let showSample {
                Button(action: showSample) {
                    Label("See a sample report", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.grape)
                }
                .padding(.top, 4)
            }
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
        .environment(AuthManager())
        .environment(PendingScout.shared)
}
