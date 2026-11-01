import SwiftUI
import UIKit

/// A tidy picture of a report's verdict, made for texting or posting.
struct ShareCardView: View {
    let result: ReviewResult
    let thumbnail: UIImage?

    private var report: Report { result.report }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Theme.heroGradient
                    }
                }
                .frame(width: 360, height: 202)
                .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)

                Text(result.video.title)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(16)
            }
            .frame(width: 360, height: 202)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(report.verdict.color.gradient)
                        Text(report.verdict.emoji)
                            .font(.system(size: 30))
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(report.verdict.label)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(report.verdict.textColor)
                        AgeBadge(age: report.recommendedMinAge, compact: true)
                    }
                }

                Text(report.headline)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                let flagged = Category.allCases.filter { report.rating(for: $0).level != .none }.prefix(4)
                if !flagged.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(flagged)) { category in
                            Text(category.shortLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(category.color, in: Capsule())
                                .lineLimit(1)
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    ScoutBadge(size: 26)
                    Text("Scouted with Screen Scout")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .padding(20)
        }
        .frame(width: 360)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

enum ShareCardRenderer {
    /// Downloads the thumbnail, then draws the card as an image.
    @MainActor
    static func render(_ result: ReviewResult) async -> UIImage? {
        var thumbnail: UIImage?
        if let url = result.video.thumbnail, url.scheme?.hasPrefix("http") == true,
           let response = try? await URLSession.shared.data(from: url) {
            thumbnail = UIImage(data: response.0)
        }
        let card = ShareCardView(result: result, thumbnail: thumbnail)
            .padding(24)
            .background(Theme.heroGradient)
            .environment(\.colorScheme, .light)
            .fontDesign(.rounded)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}
