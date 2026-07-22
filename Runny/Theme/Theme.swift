import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Theme {
    static let bg = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x15151C)
    static let surfaceLight = Color(hex: 0x1F1F28)
    static let stroke = Color.white.opacity(0.07)
    static let accent = Color(hex: 0xC9F73A)
    static let heart = Color(hex: 0xFF5A6E)
    static let textSecondary = Color(hex: 0x8B8B99)
    static let danger = Color(hex: 0xFF453A)
    static let warning = Color(hex: 0xFFD60A)
}

extension Font {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func metric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

struct CardBackground: ViewModifier {
    var corner: CGFloat = 24

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.label(12))
            .tracking(2)
            .foregroundStyle(Theme.textSecondary)
    }
}

extension View {
    func card(corner: CGFloat = 24) -> some View {
        modifier(CardBackground(corner: corner))
    }
}
