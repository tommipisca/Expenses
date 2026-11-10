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
                .containerBackground(for: .widget) { WidgetTheme.background }
                .widgetURL(AddExpenseLink.monthURL)
        }
        .configurationDisplayName("Spese del mese")
        .description("Totale del mese e ripartizione per tag.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MonthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MonthEntry

    var body: some View {
        if let summary = entry.summary?.displayed(at: entry.date, calendar: .current) {
            if family == .systemMedium { medium(summary) } else { small(summary) }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "chart.pie").font(.title2).foregroundStyle(WidgetTheme.accent)
                Text("Apri Expenses per iniziare").font(.caption).multilineTextAlignment(.center)
                    .foregroundStyle(WidgetTheme.textSecondary)
            }
        }
    }

    private func small(_ summary: WidgetSummary) -> some View {
        ZStack {
            WidgetRing(slices: summary.slices, lineWidth: 12)
            VStack(spacing: 1) {
                Text(monthName(summary.month)).font(.system(size: 10, weight: .semibold)).textCase(.uppercase)
                    .foregroundStyle(WidgetTheme.textSecondary)
                amount(summary.totalCents, size: 20)
            }
            .padding(.horizontal, 18)
        }
    }

    private func medium(_ summary: WidgetSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                WidgetRing(slices: summary.slices, lineWidth: 12)
                amount(summary.totalCents, size: 15).padding(.horizontal, 16)
            }
            .frame(width: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(monthName(summary.month).capitalized).font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)
                ForEach(summary.slices.prefix(3)) { slice in
                    HStack(spacing: 6) {
                        Circle().fill(WidgetTheme.tagColor(slice.colorIndex)).frame(width: 7, height: 7)
                        Text(slice.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Money.format(slice.cents)).font(.system(.caption, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                    }
                }
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
            .foregroundStyle(WidgetTheme.textPrimary)
        }
    }

    private func amount(_ cents: Int, size: CGFloat) -> some View {
        let parts = Money.formatParts(cents)
        return Text(parts.euros + parts.decimals)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(WidgetTheme.textPrimary)
    }

    private func monthName(_ month: MonthKey) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: month.start(calendar: .current))
    }
}

struct WidgetRing: View {
    let slices: [TagSlice]
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(WidgetTheme.surface, lineWidth: lineWidth)
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start, to: max(segment.start, segment.end - (slices.count > 1 ? 0.012 : 0)))
                    .stroke(WidgetTheme.tagColor(segment.colorIndex), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
    }

    private var segments: [(start: Double, end: Double, colorIndex: Int?)] {
        var start = 0.0
        return slices.map { slice in
            defer { start += slice.fraction }
            return (start, start + slice.fraction, slice.colorIndex)
        }
    }
}
