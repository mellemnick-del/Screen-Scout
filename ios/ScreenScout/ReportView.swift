import SwiftUI

struct ReportView: View {
    let result: ReviewResult

    private var report: Report { result.report }
    private var video: VideoInfo { result.video }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Card("What happens in it") {
                    Text(report.summary)
                }

                Card("Content breakdown") {
                    VStack(spacing: 0) {
                        ForEach(Category.allCases) { category in
                            let rating = report.rating(for: category)
                            CategoryRow(
                                symbol: category.symbol,
                                title: category.label,
                                level: rating.level,
                                details: rating.details
                            )
                            Divider()
                        }
                        CategoryRow(
                            symbol: "graduationcap.fill",
                            title: "Educational value",
                            level: report.educationalValue,
                            details: nil,
                            positive: true
                        )
                    }
                }

                Card("Moments to know about") {
                    if report.flaggedMoments.isEmpty {
                        Text("Nothing specific to flag.").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(report.flaggedMoments) { moment in
                                MomentRow(moment: moment, videoURL: video.url)
                            }
                        }
                    }
                }

                Card("The good stuff") {
                    BulletList(items: report.positives, empty: "None noted.")
                }

                Card("Talk about it") {
                    BulletList(items: report.talkAboutIt, empty: "None noted.")
                }

                footnote
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = URL(string: video.url) {
                    Link(destination: url) {
                        Image(systemName: "play.rectangle")
                    }
                    .accessibilityLabel("Open video")
                }
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: video.thumbnail) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(video.title)
                .font(.title3.bold())
            Text("\(video.channel) · \(formatDuration(video.duration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Label(report.verdict.label, systemImage: report.verdict.symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(report.verdict.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(report.verdict.color.opacity(0.15), in: Capsule())
                Text("Ages \(report.recommendedMinAge)+")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.background, in: Capsule())
                    .overlay(Capsule().stroke(.quaternary))
            }

            if result.childAge > 0 {
                Text("For your \(result.childAge) year old: \(report.fitForChild.label)")
                    .font(.subheadline.weight(.semibold))
            }

            Text(report.headline)
                .font(.headline)
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confidence: \(report.confidence.capitalized). \(report.confidenceReason)")
            Text("Reviewed \(video.framesReviewed) frames\(video.hadTranscript ? " and the full transcript" : ", no transcript available"). Reviewed \(result.createdDate.formatted(date: .abbreviated, time: .omitted)).")
            Text("AI reviews can miss things. Spot-check anything that matters to you.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var shareText: String {
        """
        Screen Scout review: \(video.title)
        \(report.verdict.label) · Ages \(report.recommendedMinAge)+
        \(report.headline)

        \(report.summary)

        \(video.url)
        """
    }
}

// MARK: - Pieces

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CategoryRow: View {
    let symbol: String
    let title: String
    let level: Level
    let details: String?
    var positive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.medium))
                Spacer()
                LevelMeter(level: level, positive: positive)
            }
            if let details, level != .none {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct LevelMeter: View {
    let level: Level
    var positive = false

    private var fill: Color { positive ? .accentColor : level.color }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(1...4, id: \.self) { i in
                    Capsule()
                        .fill(i <= level.index ? fill : Color.secondary.opacity(0.2))
                        .frame(width: 14, height: 7)
                }
            }
            Text(level.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.rawValue)
    }
}

private struct MomentRow: View {
    let moment: FlaggedMoment
    let videoURL: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let seconds = moment.seconds, let url = URL(string: "\(videoURL)&t=\(seconds)s") {
                Link(moment.timestamp, destination: url)
                    .font(.subheadline.monospacedDigit().bold())
                    .frame(width: 60, alignment: .leading)
            } else {
                Text(moment.timestamp)
                    .font(.subheadline.bold())
                    .frame(width: 60, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(moment.description)
                    .font(.subheadline)
                Text(moment.category.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BulletList: View {
    let items: [String]
    let empty: String

    var body: some View {
        if items.isEmpty {
            Text(empty).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(item)
                    }
                }
            }
        }
    }
}
