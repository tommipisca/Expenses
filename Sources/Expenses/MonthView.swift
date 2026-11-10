import SwiftUI
import ExpensesCore

enum MonthViewStyle: String {
    case ring, bars
}

/// Schermata principale: quanto ho speso nel mese e in cosa.
struct MonthView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("monthViewStyle") private var style: MonthViewStyle = .ring
    @State private var month: MonthKey?

    var body: some View {
        let shown = month ?? store.currentMonth
        let summary = store.summary(for: shown)
        let statuses = store.budgetStatuses(for: shown)
        let tagBudgets = Dictionary(statuses.compactMap { status -> (UUID, BudgetStatus)? in
            if case .tag(let id) = status.target { return (id, status) } else { return nil }
        }, uniquingKeysWith: { first, _ in first })

        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    header(shown)
                    if summary.count == 0 {
                        emptyState(shown)
                    } else if style == .ring {
                        ringSection(summary)
                    } else {
                        barsHeader(summary)
                        BarsView(summary: summary, tagBudgets: tagBudgets) { open($0, month: shown) }
                    }
                    if let total = statuses.first(where: { $0.target == .total }) {
                        totalBudgetCard(total)
                    }
                    if style == .ring, summary.count > 0 {
                        tagList(summary, tagBudgets: tagBudgets, month: shown)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5,
                      abs(value.translation.width) > 60 else { return }
                change(by: value.translation.width < 0 ? 1 : -1)
            })

            Button { router.newExpense() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 60, height: 60)
                    .background(Theme.accent, in: Circle())
                    .shadow(color: Theme.accent.opacity(0.35), radius: 15, y: 8)
            }
            .accessibilityLabel("Aggiungi spesa")
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: Parti

    private func header(_ shown: MonthKey) -> some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Picker("Vista", selection: $style) {
                    Image(systemName: "circle.circle").tag(MonthViewStyle.ring).accessibilityLabel("Anello")
                    Image(systemName: "square.grid.2x2").tag(MonthViewStyle.bars).accessibilityLabel("Barre e riquadri")
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            HStack {
                roundButton("chevron.left", label: "Mese precedente") { change(by: -1) }
                Spacer()
                VStack(spacing: 2) {
                    Text(shown == store.currentMonth ? "Mese corrente" : "Torna al mese corrente")
                        .font(.caption.weight(.semibold)).tracking(1.5).textCase(.uppercase)
                        .foregroundStyle(shown == store.currentMonth ? Theme.textSecondary : Theme.accent)
                    Text(Formatting.monthTitle(shown)).font(.rounded(.title3, weight: .semibold))
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.snappy) { month = nil } }
                Spacer()
                roundButton("chevron.right", label: "Mese successivo") { change(by: 1) }
            }
        }
    }

    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
        }
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel(label)
    }

    private func ringSection(_ summary: MonthSummary) -> some View {
        ZStack {
            RingChart(slices: summary.slices).id(summary.month)
            VStack(spacing: 6) {
                Text("Totale speso").font(.footnote).foregroundStyle(Theme.textSecondary)
                amountText(summary.totalCents, size: 40)
                Text("\(summary.count) \(summary.count == 1 ? "spesa" : "spese")")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                if let comparison = summary.comparison {
                    comparisonCapsule(comparison)
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: 300)
    }

    private func barsHeader(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            amountText(summary.totalCents, size: 56)
            HStack(spacing: 8) {
                if let comparison = summary.comparison { comparisonCapsule(comparison) }
                Text("\(summary.count) \(summary.count == 1 ? "spesa" : "spese")")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountText(_ cents: Int, size: CGFloat) -> some View {
        let parts = Money.formatParts(cents)
        return (Text(parts.euros) + Text(parts.decimals).font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .foregroundColor(Theme.textSecondary))
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private func comparisonCapsule(_ comparison: Comparison) -> some View {
        let color = comparison.percentChange <= 0 ? Theme.success : Theme.warning
        return Text(Formatting.comparison(comparison))
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .multilineTextAlignment(.center)
    }

    private func emptyState(_ shown: MonthKey) -> some View {
        ZStack {
            Circle().stroke(Theme.surface, lineWidth: 26).padding(13)
            VStack(spacing: 6) {
                amountText(0, size: 36)
                Text("Nessuna spesa a \(Formatting.monthName(shown))")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: 260)
        .aspectRatio(1, contentMode: .fit)
    }

    private func totalBudgetCard(_ status: BudgetStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Budget mensile").font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formatting.percent(status.fraction)).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Text(status.remainingCents >= 0
                 ? "Restano \(Money.format(status.remainingCents)) di \(Money.format(status.limitCents))"
                 : "Superato di \(Money.format(-status.remainingCents))")
                .font(.footnote)
                .foregroundStyle(status.remainingCents >= 0 ? Theme.textSecondary : Theme.danger)
            ProgressLine(fraction: status.fraction, color: Theme.budgetColor(fraction: status.fraction), height: 6)
        }
        .card()
    }

    private func tagList(_ summary: MonthSummary, tagBudgets: [UUID: BudgetStatus], month: MonthKey) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(summary.slices.enumerated()), id: \.element.id) { index, slice in
                Button { open(slice, month: month) } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            TagDot(colorIndex: slice.colorIndex)
                            Text(slice.name).font(.body.weight(.medium)).lineLimit(1)
                            Spacer()
                            Text(Formatting.percent(slice.fraction)).font(.footnote).foregroundStyle(Theme.textSecondary)
                                .frame(width: 44, alignment: .trailing)
                            Text(Money.format(slice.cents)).font(.rounded(.body, weight: .semibold)).monospacedDigit()
                                .frame(minWidth: 88, alignment: .trailing)
                        }
                        if let budget = slice.id.flatMap({ tagBudgets[$0] }) {
                            ProgressLine(fraction: budget.fraction, color: Theme.budgetColor(fraction: budget.fraction), height: 3)
                                .padding(.leading, 22)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                if index < summary.slices.count - 1 { Divider().overlay(Theme.elevated).padding(.leading, 38) }
            }
        }
        .card(padding: 0)
    }

    private func open(_ slice: TagSlice, month: MonthKey) {
        router.openHistory(tagID: slice.id, month: month)
    }

    private func change(by months: Int) {
        withAnimation(.snappy) { month = (month ?? store.currentMonth).adding(months: months) }
    }
}
