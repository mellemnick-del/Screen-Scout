import SwiftUI

struct ReportView: View {
    let result: ReviewResult

    @State private var selectedCategory: Category?
    @State private var appeared = false
    @State private var shareImage: Image?

    private var report: Report { result.report }
    private var video: VideoInfo { result.video }

    var body: some View {
        ScrollView {
            // Two columns when there's room (inner iPhone Duo screen, iPad),
            // one column otherwise.
            ViewThatFits(in: .horizontal) {
                wideLayout
                    .frame(minWidth: 760, maxWidth: 1100)
                narrowLayout
                    .frame(maxWidth: 720)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Scout Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    if let shareImage {
                        ShareLink(
                            item: shareImage,
                            preview: SharePreview(video.title, image: shareImage)
                        ) {
                            Label("Share as Picture", systemImage: "photo")
                        }
                    }
                    ShareLink(item: shareText) {
                        Label("Share as Text", systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share report")
            }
        }
        .task {
            if let image = await ShareCardRenderer.render(result) {
                shareImage = Image(uiImage: image)
            }
        }
        .onAppear { appeared = true }
        .sensoryFeedback(trigger: appeared) { _, shown in shown ? report.verdict.feedback : nil }
        .sensoryFeedback(.selection, trigger: selectedCategory)
        .sheet(item: $selectedCategory) { category in
            CategoryDetailSheet(
                category: category,
                rating: report.rating(for: category),
                moments: report.flaggedMoments.filter { $0.category == category },
                videoURL: video.url
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
    }

    // MARK: Layouts

    private var narrowLayout: some View {
        VStack(spacing: 18) {
            if result.isSample {
                sampleBanner
            }
            hero
                .popIn()
            verdictCard
                .popIn(delay: 0.06)
            summaryCard
                .popIn(delay: 0.12)
            breakdownCard
                .popIn(delay: 0.18)
            learningCard
                .popIn(delay: 0.22)
            momentsCard
                .popIn(delay: 0.26)
            goodStuffCard
                .popIn(delay: 0.3)
            talkCard
                .popIn(delay: 0.34)
            howWeScouted
                .popIn(delay: 0.38)
        }
    }

    private var wideLayout: some View {
        VStack(spacing: 18) {
            if result.isSample {
                sampleBanner
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 18) {
                    hero
                        .popIn()
                    verdictCard
                        .popIn(delay: 0.06)
                    summaryCard
                        .popIn(delay: 0.12)
                    learningCard
                        .popIn(delay: 0.18)
                    howWeScouted
                        .popIn(delay: 0.24)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 18) {
                    breakdownCard
                        .popIn(delay: 0.08)
                    momentsCard
                        .popIn(delay: 0.14)
                    goodStuffCard
                        .popIn(delay: 0.2)
                    talkCard
                        .popIn(delay: 0.26)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Sample banner

    private var sampleBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.grape)
            VStack(alignment: .leading, spacing: 2) {
                Text("This is a sample report")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("The video is made up. Scout a real one to see your own.")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(tint: Theme.grape, padding: 14)
    }

    // MARK: Hero

    private var hero: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: video.thumbnail) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Theme.heroGradient
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(video.channel) · \(formatDuration(video.duration))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(16)
            }
            .overlay {
                if !result.isSample, let url = URL(string: video.url) {
                    Link(destination: url) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 54))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.coral)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .accessibilityLabel("Watch on YouTube")
                    .offset(y: -12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }

    // MARK: Verdict

    private var verdictCard: some View {
        let verdict = report.verdict
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(verdict.color.gradient)
                    Text(verdict.emoji)
                        .font(.system(size: 40))
                }
                .frame(width: 78, height: 78)
                .shadow(color: verdict.color.opacity(0.45), radius: 10, y: 5)

                VStack(alignment: .leading, spacing: 8) {
                    Text(verdict.label)
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(verdict.textColor)
                    AgeBadge(age: report.recommendedMinAge)
                }
                Spacer(minLength: 0)
            }

            if result.childAge > 0 {
                Label(
                    report.fitForChild.label(age: result.childAge, kidName: result.kidName),
                    systemImage: report.fitForChild.symbol
                )
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(report.fitForChild.color.gradient, in: Capsule())
            }

            KidMeter(verdict: verdict)

            // The Scout's one-line take, as a speech bubble
            HStack(alignment: .top, spacing: 10) {
                ScoutBadge(size: 38)
                Text(report.headline)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .cardStyle(tint: verdict.color)
    }

    // MARK: Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What happens", symbol: "film.fill", color: Theme.sky)
            Text(report.summary)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: Breakdown grid

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What's inside", symbol: "square.grid.2x2.fill", color: Theme.grape)
            Text(breakdownSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.softInk)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Category.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        CategoryTile(category: category, level: report.rating(for: category).level)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.top, 4)
        }
        .cardStyle()
    }

    private var breakdownSubtitle: String {
        switch report.flaggedCategoryCount {
        case 0: "All clear across the board. Tap any tile to learn more."
        case 1: "1 thing to know about. Tap any tile for details."
        default: "\(report.flaggedCategoryCount) things to know about. Tap any tile for details."
        }
    }

    // MARK: Learning

    private var learningCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Learning value", symbol: "graduationcap.fill", color: Theme.sky)
                Text(learningBlurb)
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer(minLength: 0)
            StarRating(filled: report.educationalValue.index)
        }
        .cardStyle(tint: Theme.sky)
    }

    private var learningBlurb: String {
        switch report.educationalValue {
        case .none: "Just for fun. No real learning here."
        case .mild: "A little learning sprinkled in."
        case .moderate: "Some solid learning value."
        case .strong: "Packed with learning."
        case .severe: "Seriously educational!"
        }
    }

    // MARK: Moments timeline

    private var momentsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Moments to know", symbol: "flag.fill", color: Theme.coral)

            if report.flaggedMoments.isEmpty {
                HStack(spacing: 12) {
                    Text("🎉").font(.largeTitle)
                    Text("Nothing specific to flag. Nice!")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(report.flaggedMoments.enumerated()), id: \.element.id) { index, moment in
                        TimelineRow(
                            moment: moment,
                            videoURL: video.url,
                            isLast: index == report.flaggedMoments.count - 1
                        )
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: Good stuff

    private var goodStuffCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "The good stuff", symbol: "sparkles", color: Theme.mint)
            if report.positives.isEmpty {
                Text("Nothing that really stands out.")
                    .foregroundStyle(Theme.softInk)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.positives, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.mint)
                            Text(item)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .cardStyle(tint: Theme.mint)
    }

    // MARK: Talk about it

    private var talkCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Talk about it", symbol: "bubble.left.and.bubble.right.fill", color: Theme.grape)
            Text("Easy conversation starters for after the video.")
                .font(.subheadline)
                .foregroundStyle(Theme.softInk)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(report.talkAboutIt.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Theme.grape.gradient, in: Circle())
                        Text(question)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .cardStyle(tint: Theme.grape)
    }

    // MARK: How we scouted

    private var howWeScouted: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How we scouted this")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.ink)
            Label("\(video.framesReviewed) moments from the video checked", systemImage: "photo.stack.fill")
            Label(
                video.hadTranscript ? "Everything said was read" : "No captions available to read",
                systemImage: video.hadTranscript ? "captions.bubble.fill" : "captions.bubble"
            )
            Label("Confidence: \(report.confidence.capitalized)", systemImage: "checkmark.shield.fill")
            Text(report.confidenceReason)
                .padding(.top, 2)
            Text("Scouted \(result.createdDate.formatted(date: .abbreviated, time: .omitted)). AI can miss things, so trust your gut too.")
                .padding(.top, 4)
        }
        .font(.footnote)
        .foregroundStyle(Theme.softInk)
        .cardStyle()
    }

    private var shareText: String {
        """
        \(report.verdict.emoji) \(report.verdict.label) · Ages \(report.recommendedMinAge)+
        \(video.title)

        \(report.headline)

        \(report.summary)

        \(video.url)
        Scouted with Screen Scout
        """
    }
}

// MARK: - Pieces

/// Three-zone meter showing where this video lands.
struct KidMeter: View {
    let verdict: Verdict

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Verdict.allCases, id: \.self) { zone in
                let active = zone == verdict
                VStack(spacing: 6) {
                    Capsule()
                        .fill(active ? AnyShapeStyle(zone.color.gradient) : AnyShapeStyle(zone.color.opacity(0.22)))
                        .frame(height: active ? 14 : 10)
                        .overlay {
                            if active {
                                Capsule().stroke(.white.opacity(0.8), lineWidth: 2)
                            }
                        }
                    Text(zone.label)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(active ? zone.textColor : Theme.softInk.opacity(0.7))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(verdict.label)")
    }
}

struct CategoryTile: View {
    let category: Category
    let level: Level

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(category.color.gradient)
                Image(systemName: category.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            Text(category.shortLabel)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            LevelPill(level: level)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(category.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(category.color.opacity(level == .none ? 0.15 : 0.5), lineWidth: level == .none ? 1 : 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows details")
    }
}

struct StarRating: View {
    let filled: Int
    var total = 4

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < filled ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(i < filled ? Theme.sunshine : Theme.softInk.opacity(0.35))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) out of \(total) stars")
    }
}

struct TimestampChip: View {
    let moment: FlaggedMoment
    let videoURL: String

    var body: some View {
        if let url = moment.link(in: videoURL) {
            Link(destination: url) { chip(showPlay: true) }
                .accessibilityLabel("Watch at \(moment.timestamp)")
        } else {
            chip(showPlay: false)
        }
    }

    private func chip(showPlay: Bool) -> some View {
        HStack(spacing: 4) {
            if showPlay {
                Image(systemName: "play.fill")
            }
            Text(moment.timestamp.capitalized)
        }
        .font(.caption.weight(.heavy).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(moment.category.color.gradient, in: Capsule())
    }
}

struct TimelineRow: View {
    let moment: FlaggedMoment
    let videoURL: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(moment.category.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Theme.card, lineWidth: 3))
                    .padding(.top, 6)
                if !isLast {
                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 6) {
                TimestampChip(moment: moment, videoURL: videoURL)
                Text(moment.description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(moment.category.shortLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(moment.category.color)
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Pops up when a tile is tapped.
struct CategoryDetailSheet: View {
    let category: Category
    let rating: CategoryRating
    let moments: [FlaggedMoment]
    let videoURL: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(category.color.gradient)
                        Image(systemName: category.symbol)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.label)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                        LevelPill(level: rating.level)
                    }
                }

                LevelScale(level: rating.level)

                VStack(alignment: .leading, spacing: 6) {
                    Text("What we found")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text(rating.details)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !moments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When it happens")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                        ForEach(moments) { moment in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                TimestampChip(moment: moment, videoURL: videoURL)
                                Text(moment.description)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("What this covers")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text(category.explainer)
                        .font(.subheadline)
                        .foregroundStyle(Theme.softInk)
                }
            }
            .padding(24)
            .padding(.top, 8)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Five-step bar from None to Intense.
struct LevelScale: View {
    let level: Level

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Level.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step.index <= level.index ? level.color : Theme.softInk.opacity(0.18))
                        .frame(height: 10)
                }
            }
            HStack {
                Text("None")
                Spacer()
                Text("Intense")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.softInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level: \(level.label)")
    }
}
