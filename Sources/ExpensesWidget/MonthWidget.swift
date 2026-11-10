import SwiftUI
import WidgetKit
import ExpensesCore

enum WidgetTheme {
    static let background = Color(hex: Palette.background)
    static let surface = Color(hex: Palette.surface)
    static let textPrimary = Color(hex: Palette.textPrimary)
    static let textSecondary = Color(hex: Palette.textSecondary)
    static let warning = Color(hex: Palette.warning)
    static let danger = Color(hex: Palette.danger)
    static let accent = Color(hex: Palette.accent)

    static func tagColor(_ index: Int?) -> Color {
        guard let index else { return textSecondary }
        let colors = Palette.tagColors
        return Color(hex: colors[((index % colors.count) + colors.count) % colors.count])
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct MonthEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
}

struct MonthProvider: TimelineProvider {
    private var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(WidgetSummary.fileName)
    }

    func placeholder(in context: Context) -> MonthEntry {
        MonthEntry(date: .now, summary: WidgetSummary(
            month: MonthKey(date: .now, calendar: .current), totalCents: 124860,
            slices: [TagSlice(id: UUID(), name: "Casa", colorIndex: 0, cents: 52000, fraction: 0.42),
                     TagSlice(id: UUID(), name: "Spesa", colorIndex: 1, cents: 28640, fraction: 0.23),
                     TagSlice(id: UUID(), name: "Svago", colorIndex: 3, cents: 44220, fraction: 0.35)],
            monthlyBudget: nil, generatedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthEntry) -> Void) {
        let summary = fileURL.flatMap(WidgetSummary.read)
        completion(summary == nil && context.isPreview ? placeholder(in: context) : MonthEntry(date: .now, summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthEntry>) -> Void) {
        let now = Date.now
        let summary = fileURL.flatMap(WidgetSummary.read)
        let nextMonth = WidgetSummary.startOfNextMonth(after: now, calendar: .current)
        // Una voce adesso e una a mezzanotte del primo giorno del mese successivo, che riparte da zero.
        let entries = [MonthEntry(date: now, summary: summary), MonthEntry(date: nextMonth, summary: summary)]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthWidget", provider: MonthProvider()) { entry in
            MonthWidgetView(entry: entry)
                .widgetURL(AddExpenseLink.monthURL)
        }
        .configurationDisplayName("Spese del mese")
        .description("Totale del mese e ripartizione per tag.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct MonthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthEntry

    var body: some View {
        let summary = entry.summary?.displayed(at: entry.date, calendar: .current)
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(summary: summary).containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            AccessoryRectangularView(summary: summary).containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            AccessoryInlineView(summary: summary).containerBackground(for: .widget) { Color.clear }
        default:
            Group {
                if let summary {
                    switch family {
                    case .systemMedium: MediumView(summary: summary)
                    case .systemLarge: LargeView(summary: summary)
                    case .systemExtraLarge: ExtraLargeView(summary: summary)
                    default: SmallView(summary: summary)
                    }
                } else {
                    EmptyView_()
                }
            }
            .foregroundStyle(WidgetTheme.textPrimary)
            .containerBackground(for: .widget) { WidgetTheme.background }
        }
    }
}

// MARK: Parti comuni

enum WidgetFormat {
    static func monthName(_ month: MonthKey) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: month.start(calendar: .current))
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    /// Importo compatto per la schermata di blocco: "€ 248", "€ 1,2k".
    static func compact(_ cents: Int) -> String {
        let euros = Double(cents) / 100
        if euros >= 1000 {
            let value = (euros / 100).rounded() / 10
            return "€ " + String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",") + "k"
        }
        return "€ \(Int(euros.rounded()))"
    }

    static func comparison(_ comparison: Comparison) -> String {
        let sign = comparison.percentChange > 0 ? "+" : comparison.percentChange < 0 ? "−" : "±"
        return "\(sign)\(abs(comparison.percentChange))% vs \(monthName(comparison.previousMonth))"
    }

    static func budgetColor(_ fraction: Double) -> Color {
        fraction >= 1 ? WidgetTheme.danger : fraction >= 0.8 ? WidgetTheme.warning : WidgetTheme.accent
    }
}

struct AmountText: View {
    let cents: Int
    let size: CGFloat

    var body: some View {
        let parts = Money.formatParts(cents)
        (Text(parts.euros) + Text(parts.decimals).foregroundColor(WidgetTheme.textSecondary)
            .font(.system(size: size * 0.6, weight: .bold, design: .rounded)))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(WidgetTheme.textSecondary)
    }
}

struct ComparisonText: View {
    let comparison: Comparison
    var body: some View {
        Text(WidgetFormat.comparison(comparison))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(comparison.percentChange <= 0 ? Color(hex: Palette.success) : WidgetTheme.warning)
            .lineLimit(1)
    }
}

struct BudgetBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetTheme.surface)
                Capsule().fill(WidgetFormat.budgetColor(fraction)).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 5)
    }
}

struct SliceRow: View {
    let slice: TagSlice
    var showsPercent = true
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(WidgetTheme.tagColor(slice.colorIndex)).frame(width: 7, height: 7)
            Text(slice.name).font(.caption).lineLimit(1)
            Spacer(minLength: 4)
            if showsPercent {
                Text(WidgetFormat.percent(slice.fraction)).font(.caption2).foregroundStyle(WidgetTheme.textSecondary)
            }
            Text(Money.format(slice.cents)).font(.system(.caption, design: .rounded).weight(.semibold)).monospacedDigit()
        }
    }
}

struct MonthlyBudgetLine: View {
    let budget: BudgetStatus
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Budget mensile").font(.caption2.weight(.semibold))
                Spacer()
                Text(budget.remainingCents >= 0 ? "Restano \(Money.format(budget.remainingCents))"
                                                : "Superato di \(Money.format(-budget.remainingCents))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(budget.fraction >= 1 ? WidgetTheme.danger : WidgetTheme.textSecondary)
            }
            BudgetBar(fraction: budget.fraction)
        }
    }
}

struct EmptyView_: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.pie").font(.title2).foregroundStyle(WidgetTheme.accent)
            Text("Apri Expenses per iniziare").font(.caption).multilineTextAlignment(.center)
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }
}

// MARK: Schermata Home

struct SmallView: View {
    let summary: WidgetSummary
    var body: some View {
        ZStack {
            WidgetRing(slices: summary.slices, lineWidth: 12)
            VStack(spacing: 1) {
                Text(WidgetFormat.monthName(summary.month)).font(.system(size: 10, weight: .semibold)).textCase(.uppercase)
                    .foregroundStyle(WidgetTheme.textSecondary)
                AmountText(cents: summary.totalCents, size: 20)
            }
            .padding(.horizontal, 18)
        }
    }
}

struct MediumView: View {
    let summary: WidgetSummary
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                WidgetRing(slices: summary.slices, lineWidth: 12)
                AmountText(cents: summary.totalCents, size: 15).padding(.horizontal, 16)
            }
            .frame(width: 120)
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: WidgetFormat.monthName(summary.month).capitalized)
                ForEach(summary.slices.prefix(3)) { SliceRow(slice: $0, showsPercent: false) }
                if summary.slices.isEmpty {
                    Text("Nessuna spesa").font(.caption).foregroundStyle(WidgetTheme.textSecondary)
                }
                Spacer(minLength: 0)
                if let budget = summary.monthlyBudget {
                    Text(budget.remainingCents >= 0 ? "Restano \(Money.format(budget.remainingCents))"
                                                    : "Budget superato di \(Money.format(-budget.remainingCents))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(budget.fraction >= 1 ? WidgetTheme.danger
                                         : budget.fraction >= 0.8 ? WidgetTheme.warning : WidgetTheme.textSecondary)
                }
            }
        }
    }
}

/// Grande: anello e totale in alto, tutti i tag, budget mensile in fondo.
struct LargeView: View {
    let summary: WidgetSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                WidgetRing(slices: summary.slices, lineWidth: 14).frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle(text: WidgetFormat.monthName(summary.month).capitalized)
                    AmountText(cents: summary.totalCents, size: 30)
                    Text("\(summary.count) \(summary.count == 1 ? "spesa" : "spese")")
                        .font(.caption).foregroundStyle(WidgetTheme.textSecondary)
                    if let comparison = summary.comparison { ComparisonText(comparison: comparison) }
                }
            }
            Rectangle().fill(Color(hex: Palette.stroke)).frame(height: 1)
            VStack(spacing: 8) {
                ForEach(summary.slices) { SliceRow(slice: $0) }
                if summary.slices.isEmpty {
                    Text("Nessuna spesa").font(.caption).foregroundStyle(WidgetTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
            if let budget = summary.monthlyBudget { MonthlyBudgetLine(budget: budget) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Solo iPad: a sinistra anello e tag, a destra ultime spese e budget.
struct ExtraLargeView: View {
    let summary: WidgetSummary
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 18) {
                    ZStack {
                        WidgetRing(slices: summary.slices, lineWidth: 16)
                        AmountText(cents: summary.totalCents, size: 18).padding(.horizontal, 22)
                    }
                    .frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle(text: WidgetFormat.monthName(summary.month).capitalized)
                        Text("\(summary.count) \(summary.count == 1 ? "spesa" : "spese")")
                            .font(.footnote).foregroundStyle(WidgetTheme.textSecondary)
                        if let comparison = summary.comparison { ComparisonText(comparison: comparison) }
                    }
                }
                Rectangle().fill(Color(hex: Palette.stroke)).frame(height: 1)
                VStack(spacing: 9) { ForEach(summary.slices) { SliceRow(slice: $0) } }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Rectangle().fill(Color(hex: Palette.stroke)).frame(width: 1)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Ultime spese")
                if summary.recent.isEmpty {
                    Text("Nessuna spesa questo mese").font(.footnote).foregroundStyle(WidgetTheme.textSecondary)
                }
                ForEach(Array(summary.recent.enumerated()), id: \.offset) { _, expense in
                    HStack(spacing: 8) {
                        Circle().fill(WidgetTheme.tagColor(expense.colorIndex)).frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(expense.title).font(.caption.weight(.medium)).lineLimit(1)
                            Text(WidgetFormat.shortDate(expense.date)).font(.caption2).foregroundStyle(WidgetTheme.textSecondary)
                        }
                        Spacer(minLength: 4)
                        Text(Money.format(expense.cents)).font(.system(.caption, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
                if summary.monthlyBudget != nil || !summary.tagBudgets.isEmpty {
                    SectionTitle(text: "Budget")
                    if let budget = summary.monthlyBudget { MonthlyBudgetLine(budget: budget) }
                    ForEach(Array(summary.tagBudgets.prefix(3).enumerated()), id: \.offset) { _, line in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(WidgetTheme.tagColor(line.colorIndex)).frame(width: 7, height: 7)
                                Text(line.name).font(.caption2.weight(.semibold)).lineLimit(1)
                                Spacer()
                                Text("\(Money.format(line.status.spentCents)) di \(Money.format(line.status.limitCents))")
                                    .font(.caption2).foregroundStyle(WidgetTheme.textSecondary).monospacedDigit()
                            }
                            BudgetBar(fraction: line.status.fraction)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: Schermata di blocco

/// Con un budget mensile: indicatore di quanto è stato usato; altrimenti l'anello dei tag con il totale.
struct AccessoryCircularView: View {
    let summary: WidgetSummary?
    var body: some View {
        if let summary, let budget = summary.monthlyBudget {
            Gauge(value: min(budget.fraction, 1)) {
                Image(systemName: "eurosign")
            } currentValueLabel: {
                Text(WidgetFormat.compact(summary.totalCents)).minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                if let summary, !summary.slices.isEmpty {
                    WidgetRing(slices: summary.slices, lineWidth: 5, background: .clear)
                }
                Text(WidgetFormat.compact(summary?.totalCents ?? 0))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 6)
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let summary: WidgetSummary?
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let summary {
                Text("Spese di \(WidgetFormat.monthName(summary.month))").font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Text(Money.format(summary.totalCents)).font(.system(.title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6).lineLimit(1)
                if let budget = summary.monthlyBudget {
                    Text(budget.remainingCents >= 0 ? "Restano \(Money.format(budget.remainingCents))"
                                                    : "Budget superato")
                        .font(.caption2).lineLimit(1)
                } else if let top = summary.slices.first {
                    Text("\(top.name) \(WidgetFormat.percent(top.fraction))").font(.caption2).lineLimit(1)
                }
            } else {
                Text("Expenses").font(.caption.weight(.semibold))
                Text("Apri l'app per iniziare").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let summary: WidgetSummary?
    var body: some View {
        if let summary {
            Text("\(Image(systemName: "eurosign.circle")) \(Money.format(summary.totalCents)) a \(WidgetFormat.monthName(summary.month))")
        } else {
            Text("Expenses")
        }
    }
}

/// Anello come nell'app: estremi arrotondati e spazio tra le fette.
struct WidgetRing: View {
    let slices: [TagSlice]
    let lineWidth: CGFloat
    var background: Color = WidgetTheme.surface
    var gapDegrees: Double = 4

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let circumference = Double.pi * Double(max(diameter - lineWidth, 1))
            // Ogni estremo arrotondato sporge di metà spessore: si accorcia la fetta di altrettanto.
            let inset = slices.count > 1 ? Double(lineWidth / 2) / circumference + gapDegrees / 720 : 0
            ZStack {
                Circle().stroke(background, lineWidth: lineWidth)
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let from = segment.start + inset
                    Circle()
                        .trim(from: from, to: max(from, segment.end - inset))
                        .stroke(WidgetTheme.tagColor(segment.colorIndex),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: slices.count > 1 ? .round : .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(lineWidth / 2)
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var segments: [(start: Double, end: Double, colorIndex: Int?)] {
        var start = 0.0
        return slices.map { slice in
            defer { start += slice.fraction }
            return (start, start + slice.fraction, slice.colorIndex)
        }
    }
}
