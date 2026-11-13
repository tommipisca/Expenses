import SwiftUI
import ExpensesCore

/// Tema "inchiostro", lo stesso di ExamsTrack, con una voce propria: lo scontrino.
/// Importi in SF Mono, righe con i puntini guida fino all'importo, perforazioni tra le parti.
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
    /// Testo dell'interfaccia: SF Pro.
    static func ui(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, weight: weight)
    }

    /// Importi: SF Mono, come su uno scontrino. Solo per gli importi, non per date o conteggi.
    static func amount(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }

    static func amount(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Il mese: New York, come i nomi degli esami in ExamsTrack.
    static func monthTitle(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif, weight: .semibold)
    }
}

extension View {
    /// Riquadro su superficie, senza bordo: la separazione la fanno lo sfondo e lo spazio.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Lista o form sullo sfondo del tema, con righe su superficie.
    func themedListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }

    func sectionHeaderStyle() -> some View {
        font(.ui(.subheadline, weight: .semibold))
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

/// Perforazione tra le parti dello scontrino.
struct Perforation: View {
    var body: some View {
        Line()
            .stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5]))
            .frame(height: 1.5)
            .accessibilityHidden(true)
    }
}

/// Puntini guida dal nome all'importo, appoggiati sulla linea di base del testo.
struct DottedLeader: View {
    var body: some View {
        Line()
            .stroke(Theme.textSecondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 5]))
            .frame(height: 1.5)
            .frame(minWidth: 12)
            .accessibilityHidden(true)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
