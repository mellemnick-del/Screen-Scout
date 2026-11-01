import SwiftUI

struct ContentView: View {
    @Environment(HistoryStore.self) private var history
    @AppStorage("childAge") private var childAge: Int = 0

    @State private var urlText = ""
    @State private var isLoading = false
    @State private var stepIndex = 0
    @State private var errorMessage: String?
    @State private var path: [ReviewResult] = []

    private let steps = [
        "Fetching the video…",
        "Reading the captions…",
        "Looking through the frames…",
        "Writing up the review…",
    ]

    private var canSubmit: Bool {
        !isLoading && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    TextField("Paste a YouTube or YouTube Kids link", text: $urlText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { Task { await runReview() } } }

                    PasteButton(payloadType: String.self) { strings in
                        Task { @MainActor in urlText = strings.first ?? "" }
                    }
                    .buttonBorderShape(.capsule)

                    Picker("Child's age", selection: $childAge) {
                        Text("Not set").tag(0)
                        ForEach(2...17, id: \.self) { age in
                            Text("\(age) years old").tag(age)
                        }
                    }

                    Button {
                        Task { await runReview() }
                    } label: {
                        HStack(spacing: 10) {
                            if isLoading { ProgressView() }
                            Text(isLoading ? steps[stepIndex] : "Review Video").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Know what's in it before they watch it.")
                        .textCase(nil)
                        .font(.subheadline)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section("Past Reviews") {
                    if history.items.isEmpty {
                        Text("Nothing reviewed yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(history.items) { item in
                        NavigationLink(value: item) {
                            HistoryRow(item: item)
                        }
                    }
                    .onDelete { history.remove(at: $0) }
                }
            }
            .navigationTitle("Screen Scout")
            .navigationDestination(for: ReviewResult.self) { result in
                ReportView(result: result)
            }
        }
    }

    @MainActor
    private func runReview() async {
        isLoading = true
        errorMessage = nil
        stepIndex = 0
        let ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                if stepIndex < steps.count - 1 { stepIndex += 1 }
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

struct HistoryRow: View {
    let item: ReviewResult

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.video.thumbnail) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
            .frame(width: 88, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.video.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: item.report.verdict.symbol)
                        .foregroundStyle(item.report.verdict.color)
                    Text("\(item.report.verdict.label) · Ages \(item.report.recommendedMinAge)+")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
        .environment(HistoryStore())
}
