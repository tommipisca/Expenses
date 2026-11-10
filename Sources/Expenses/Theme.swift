import SwiftUI
import ExpensesCore

/// Tema scuro, lo stesso di ExamsTrack: superfici grafite a livelli e colori luminosi ma non saturi.
enum Theme {
    static let background = Color(hex: Palette.background)
    static let surface = Color(hex: Palette.surface)
    static let elevated = Color(hex: Palette.elevated)
    static let stroke = Color(hex: Palette.stroke)
    static let textPrimary = Color(hex: Palette.textPrimary)
    static let textSecondary = Color(hex: Palette.textSecondary)

    static let accent = Color(hex: Palette.accent)
    static let success = Color(hex: Palette.success)
    static let warning = Color(hex: Palette.warning)
    static let danger = Color(hex: Palette.danger)

    static let tagPalette: [Color] = Palette.tagColors.map { Color(hex: $0) }

    /// Colore di un tag; nil ("Senza tag", "Altro") è grigio.
    static func tagColor(index: Int?) -> Color {
        guard let index else { return textSecondary }
        return tagPalette[((index % tagPalette.count) + tagPalette.count) % tagPalette.count]
    }

    /// Colore di un budget in base a quanto è stato usato.
    static func budgetColor(fraction: Double) -> Color {
        fraction >= 1 ? danger : fraction >= 0.8 ? warning : accent
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension View {
    /// Riquadro su superficie con bordo sottile, come nelle bozze.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }

    /// Lista o form sullo sfondo del tema, con righe su superficie.
    func themedListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }

    func sectionHeaderStyle() -> some View {
        font(.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(nil)
    }
}

/// Pallino colorato di un tag.
struct TagDot: View {
    let colorIndex: Int?
    var size: CGFloat = 10

    var body: some View {
        Circle().fill(Theme.tagColor(index: colorIndex)).frame(width: size, height: size)
    }
}

/// Barra di avanzamento sottile (budget, riquadri).
struct ProgressLine: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.elevated)
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}
