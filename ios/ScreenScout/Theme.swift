import SwiftUI
import UIKit

// MARK: - Colors

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A color that switches automatically between light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum Theme {
    // Surfaces
    static let background = Color(light: 0xFFF7EC, dark: 0x15131D)
    static let card = Color(light: 0xFFFFFF, dark: 0x23202E)
    static let cardBorder = Color(light: 0xF2E7D7, dark: 0x332F42)
    static let ink = Color(light: 0x2B2240, dark: 0xF4F1FA)
    static let softInk = Color(light: 0x6E6585, dark: 0xA9A2BC)
    static let darkInk = Color(hex: 0x2B2240)

    // Playful palette
    static let sunshine = Color(hex: 0xFFC83D)
    static let tangerine = Color(hex: 0xFF9142)
    static let coral = Color(hex: 0xFF5E6C)
    static let bubblegum = Color(hex: 0xFF77B4)
    static let grape = Color(hex: 0x7B61FF)
    static let lavender = Color(hex: 0xA77BFF)
    static let sky = Color(hex: 0x3BA4FF)
    static let teal = Color(hex: 0x1FC8B8)
    static let mint = Color(hex: 0x2FCB7E)
    static let berry = Color(hex: 0xE0384E)

    static let heroGradient = LinearGradient(
        colors: [sky, grape],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [coral, tangerine],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - How each rating looks and reads

extension Verdict {
    var label: String {
        switch self {
        case .safe: "Good to Go"
        case .caution: "Heads Up"
        case .notRecommended: "Skip It"
        }
    }

    var emoji: String {
        switch self {
        case .safe: "👍"
        case .caution: "👀"
        case .notRecommended: "✋"
        }
    }

    var color: Color {
        switch self {
        case .safe: Theme.mint
        case .caution: Theme.tangerine
        case .notRecommended: Theme.coral
        }
    }

    /// Readable text color on light or dark backgrounds.
    var textColor: Color {
        switch self {
        case .safe: Color(light: 0x13985A, dark: 0x5BE3A0)
        case .caution: Color(light: 0xD3620E, dark: 0xFFB070)
        case .notRecommended: Color(light: 0xD03344, dark: 0xFF8A95)
        }
    }
}

extension Fit {
    func label(age: Int) -> String {
        switch self {
        case .goodFit: "Great pick for your \(age)-year-old"
        case .watchTogether: "Best watched together"
        case .skip: "Not for your \(age)-year-old yet"
        }
    }

    var symbol: String {
        switch self {
        case .goodFit: "hand.thumbsup.fill"
        case .watchTogether: "person.2.fill"
        case .skip: "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .goodFit: Theme.mint
        case .watchTogether: Theme.tangerine
        case .skip: Theme.coral
        }
    }
}

extension Level {
    var label: String {
        switch self {
        case .none: "None"
        case .mild: "A little"
        case .moderate: "Some"
        case .strong: "A lot"
        case .severe: "Intense"
        }
    }

    var symbol: String {
        switch self {
        case .none: "checkmark.circle.fill"
        case .mild: "circle.bottomhalf.filled"
        case .moderate: "exclamationmark.circle.fill"
        case .strong: "exclamationmark.triangle.fill"
        case .severe: "xmark.octagon.fill"
        }
    }

    /// Deep enough for white text on top.
    var color: Color {
        switch self {
        case .none: Color(hex: 0x1FA866)
        case .mild: Color(hex: 0x2F86E0)
        case .moderate: Color(hex: 0xF07A1E)
        case .strong: Color(hex: 0xE8475A)
        case .severe: Color(hex: 0xC22A41)
        }
    }
}

extension Category {
    /// Full name, used in the detail sheet.
    var label: String {
        switch self {
        case .violence: "Violence"
        case .scaryOrDisturbing: "Scary or disturbing"
        case .language: "Language"
        case .sexualContent: "Sexual content"
        case .dangerousImitableBehavior: "Stunts kids might copy"
        case .badBehaviorAndAttitudes: "Bad behavior and attitudes"
        case .commercialism: "Ads and buying pressure"
        case .misleadingOrHijackedCharacters: "Misused kids' characters"
        case .overstimulation: "Overstimulation"
        }
    }

    /// Short name for the tiles.
    var shortLabel: String {
        switch self {
        case .violence: "Violence"
        case .scaryOrDisturbing: "Scary stuff"
        case .language: "Language"
        case .sexualContent: "Sexual content"
        case .dangerousImitableBehavior: "Risky stunts"
        case .badBehaviorAndAttitudes: "Attitude"
        case .commercialism: "Ads & buying"
        case .misleadingOrHijackedCharacters: "Misused characters"
        case .overstimulation: "Overstimulation"
        }
    }

    /// What this category means, in plain words.
    var explainer: String {
        switch self {
        case .violence: "Hitting, fighting, weapons, or people getting hurt."
        case .scaryOrDisturbing: "Jump scares, creepy images, or upsetting situations."
        case .language: "Swearing, insults, or rude words."
        case .sexualContent: "Kissing, innuendo, or anything grown-up."
        case .dangerousImitableBehavior: "Pranks, challenges, or stunts a kid might try at home."
        case .badBehaviorAndAttitudes: "Rudeness, bullying, or bad behavior shown as funny."
        case .commercialism: "Unboxings, product pushing, or 'ask your parents to buy this'."
        case .misleadingOrHijackedCharacters: "Familiar characters put in weird, gross, or inappropriate situations."
        case .overstimulation: "Nonstop loud noises, flashing, and rapid-fire editing."
        }
    }

    var symbol: String {
        switch self {
        case .violence: "hand.raised.fill"
        case .scaryOrDisturbing: "eye.fill"
        case .language: "text.bubble.fill"
        case .sexualContent: "heart.slash.fill"
        case .dangerousImitableBehavior: "flame.fill"
        case .badBehaviorAndAttitudes: "hand.thumbsdown.fill"
        case .commercialism: "cart.fill"
        case .misleadingOrHijackedCharacters: "theatermasks.fill"
        case .overstimulation: "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .violence: Theme.coral
        case .scaryOrDisturbing: Theme.grape
        case .language: Theme.sky
        case .sexualContent: Theme.bubblegum
        case .dangerousImitableBehavior: Theme.tangerine
        case .badBehaviorAndAttitudes: Color(hex: 0xE5A50A)
        case .commercialism: Theme.mint
        case .misleadingOrHijackedCharacters: Theme.teal
        case .overstimulation: Theme.lavender
        }
    }
}

// MARK: - Reusable styles

struct CardStyle: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Theme.card)
                    if let tint {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(tint.opacity(0.12))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(tint?.opacity(0.25) ?? Theme.cardBorder, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }
}

extension View {
    func cardStyle(tint: Color? = nil, padding: CGFloat = 18) -> some View {
        modifier(CardStyle(tint: tint, padding: padding))
    }

    /// Fades and slides a view in when it first appears.
    func popIn(delay: Double = 0) -> some View {
        modifier(PopIn(delay: delay))
    }
}

struct PopIn: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                    shown = true
                }
            }
    }
}

/// Squishes slightly when tapped.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shared pieces

/// The Screen Scout mascot: binoculars in a colorful badge.
struct ScoutBadge: View {
    var size: CGFloat = 56
    var animated = false

    var body: some View {
        ZStack {
            Circle().fill(Theme.heroGradient)
            Image(systemName: "binoculars.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating, isActive: animated)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(Theme.sunshine)
                .offset(x: size * 0.06, y: -size * 0.06)
        }
        .shadow(color: Theme.grape.opacity(0.35), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

struct VerdictPill: View {
    let verdict: Verdict

    var body: some View {
        Text("\(verdict.emoji) \(verdict.label)")
            .font(.caption.weight(.bold))
            .foregroundStyle(verdict.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(verdict.color.opacity(0.16), in: Capsule())
    }
}

struct AgeBadge: View {
    let age: Int
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
            Text("Ages \(age)+")
        }
        .font(compact ? .caption.weight(.bold) : .subheadline.weight(.heavy))
        .foregroundStyle(Theme.darkInk)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(Theme.sunshine, in: Capsule())
    }
}

struct LevelPill: View {
    let level: Level

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.symbol)
            Text(level.label)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(level.color, in: Capsule())
    }
}

struct SectionHeader: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.gradient)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.ink)
        }
    }
}
