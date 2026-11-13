import SwiftUI
import ExpensesCore

/// Una barretta per ogni giorno del mese: quanto si è speso, con oggi in evidenza e i giorni futuri appena accennati.
struct DailyBarsView: View {
    let daily: DailySpending
    let month: MonthKey
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let count = daily.cents.count
                let spacing: CGFloat = count > 0 ? min(3, proxy.size.width / CGFloat(count) * 0.3) : 0
                let barWidth = max(1, (proxy.size.width - spacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1)))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(daily.cents.enumerated()), id: \.offset) { index, cents in
                            bar(day: index + 1, cents: cents)
                                .frame(width: barWidth)
                        }
                    }
                    .frame(width: proxy.size.width, height: chartHeight, alignment: .bottomLeading)
                    axis(width: proxy.size.width, barWidth: barWidth, spacing: spacing)
                }
            }
            .frame(height: chartHeight + 20)

            if let busiest = daily.busiestDay {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Giorno con più spese: \(busiest) \(Formatting.monthName(month))")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 4)
                    Text(Money.format(daily.cents[busiest - 1]))
                        .font(.amount(.footnote))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spese giorno per giorno")
        .accessibilityValue(accessibilitySummary)
    }

    /// Primo e ultimo giorno ai lati, "oggi" sotto la sua barretta; un numero vicino a "oggi" si nasconde.
    private func axis(width: CGFloat, barWidth: CGFloat, spacing: CGFloat) -> some View {
        let count = daily.cents.count
        let todayX = daily.today.map { CGFloat($0 - 1) * (barWidth + spacing) + barWidth / 2 }
        let nearStart = todayX.map { $0 < 34 } ?? false
        let nearEnd = todayX.map { $0 > width - 34 } ?? false
        return ZStack(alignment: .leading) {
            if !nearStart {
                Text("1").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            if !nearEnd {
                Text("\(count)").font(.caption2).foregroundStyle(Theme.textSecondary)
                    .frame(width: width, alignment: .trailing)
            }
            if let todayX {
                Text("oggi")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
                    // Centrata sulla barretta, ma mai fuori dai bordi.
                    .offset(x: min(max(todayX - 11, 0), width - 22))
            }
        }
        .frame(width: width, height: 14, alignment: .leading)
    }

    @ViewBuilder
    private func bar(day: Int, cents: Int) -> some View {
        let isFuture = daily.today.map { day > $0 } ?? false
        let isToday = daily.today == day
        if cents > 0 {
            let fraction = Double(cents) / Double(max(daily.maxCents, 1))
            Capsule()
                .fill(isToday ? Theme.textPrimary : Theme.accent)
                .frame(height: max(6, chartHeight * fraction))
        } else {
            // Giorno senza spese: solo un segno sulla linea di base, più tenue se deve ancora arrivare.
            Capsule()
                .fill(isToday ? Theme.textPrimary : Theme.stroke.opacity(isFuture ? 0.6 : 1))
                .frame(height: 3)
        }
    }

    private var accessibilitySummary: String {
        let active = daily.cents.filter { $0 > 0 }.count
        guard let busiest = daily.busiestDay else { return "Nessuna spesa" }
        return "\(active) giorni con spese; il più caro il \(busiest) \(Formatting.monthName(month)), \(Money.format(daily.cents[busiest - 1]))"
    }
}

/// Le ultime spese del mese come righe di scontrino: giorno, esercente, puntini, importo.
struct RecentExpensesView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(AppRouter.self) private var router
    let expenses: [Expense]
    let month: MonthKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ultime spese").sectionHeaderStyle()
                Spacer()
                Button("Vedi tutte") { router.openHistory(month: month) }
                    .font(.ui(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(expenses) { expense in
                    Button { router.edit(expense) } label: { row(expense) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func row(_ expense: Expense) -> some View {
        let tag = store.tag(id: expense.tagID)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Formatting.shortDate(expense.date))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 50, alignment: .leading)
            TagDot(colorIndex: tag?.colorIndex, size: 8)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(expense.merchant ?? expense.note ?? tag?.name ?? "Spesa")
                .font(.subheadline)
                .lineLimit(1)
            DottedLeader()
            Text(Money.format(expense.amountCents))
                .font(.amount(.subheadline))
                .fixedSize()
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre la spesa")
    }
}
