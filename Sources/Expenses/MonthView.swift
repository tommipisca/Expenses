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
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.floatingTabBarHeight) private var tabBarHeight

    var body: some View {
        let shown = month ?? store.currentMonth
        let summary = store.summary(for: shown)
        let statuses = store.budgetStatuses(for: shown)
        let tagBudgets = Dictionary(statuses.compactMap { status -> (UUID, BudgetStatus)? in
            if case .tag(let id) = status.target { return (id, status) } else { return nil }
        }, uniquingKeysWith: { first, _ in first })

        ZStack(alignment: .bottomTrailing) {
            Group {
                if isWide {
                    wideBody(shown: shown, summary: summary, statuses: statuses, tagBudgets: tagBudgets)
                } else {
                    narrowBody(shown: shown, summary: summary, statuses: statuses, tagBudgets: tagBudgets)
                }
            }
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
                    .overlay(Circle().stroke(Theme.background, lineWidth: 3))
            }
            .accessibilityLabel("Aggiungi spesa")
            .padding(20)
            .padding(.bottom, tabBarHeight)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: Layout

    /// Telefono e iPad in verticale: tutto in una colonna.
    private func narrowBody(shown: MonthKey, summary: MonthSummary, statuses: [BudgetStatus],
                            tagBudgets: [UUID: BudgetStatus]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header(shown)
                if !store.pendingReview.isEmpty {
                    pendingSection(store.pendingReview)
                }
                if summary.count == 0 {
                    emptyState(shown, maxWidth: 260)
                } else if style == .ring {
                    ringSection(summary, maxWidth: 300)
                } else {
                    barsHeader(summary)
                    BarsView(summary: summary, tagBudgets: tagBudgets) { open($0, month: shown) }
                }
                let total = statuses.first(where: { $0.target == .total })
                if style == .ring, summary.count > 0 {
                    tagList(summary, tagBudgets: tagBudgets, month: shown, total: total)
                } else if let total {
                    totalBudgetCard(total)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .floatingTabBarClearance()
    }

    /// iPad in orizzontale: a sinistra mese e anello grande, a destra (scorre) da confermare, budget e tag.
    private func wideBody(shown: MonthKey, summary: MonthSummary, statuses: [BudgetStatus],
                          tagBudgets: [UUID: BudgetStatus]) -> some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(spacing: 24) {
                header(shown)
                Spacer(minLength: 0)
                if summary.count == 0 {
                    emptyState(shown, maxWidth: 420)
                } else if style == .ring {
                    ringSection(summary, maxWidth: 460)
                } else {
                    barsHeader(summary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.bottom, 24 + tabBarHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(spacing: 20) {
                    if !store.pendingReview.isEmpty {
                        pendingSection(store.pendingReview)
                    }
                    let total = statuses.first(where: { $0.target == .total })
                    if style == .ring, summary.count > 0 {
                        tagList(summary, tagBudgets: tagBudgets, month: shown, total: total)
                    } else if let total {
                        totalBudgetCard(total)
                    }
                    if style == .bars, summary.count > 0 {
                        BarsView(summary: summary, tagBudgets: tagBudgets) { open($0, month: shown) }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .floatingTabBarClearance()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
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
                VStack(spacing: 4) {
                    Text(Formatting.monthTitle(shown))
                        .font(.monthTitle(.title2))
                        .foregroundStyle(Theme.textPrimary)
                    // Fuori dal mese corrente, un pulsante per tornarci (prima era un'etichetta da toccare).
                    if shown != store.currentMonth {
                        Button("Torna a \(Formatting.monthName(store.currentMonth))") {
                            withAnimation(.snappy) { month = nil }
                        }
                        .font(.ui(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                roundButton("chevron.right", label: "Mese successivo") { change(by: 1) }
            }
        }
    }

    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel(label)
    }

    private func ringSection(_ summary: MonthSummary, maxWidth: CGFloat) -> some View {
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
        .frame(maxWidth: maxWidth)
    }

    private func barsHeader(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            amountText(summary.totalCents, size: 56)
            HStack(spacing: 8) {
                if let comparison = summary.comparison { comparisonCapsule(comparison) }
                Text("\(summary.count) \(summary.count == 1 ? "spesa" : "spese")")
                    .font(.caption).foregroundStyle(Theme.textSecondary)

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountText(_ cents: Int, size: CGFloat) -> some View {
        let parts = Money.formatParts(cents)
        return (Text(parts.euros) + Text(parts.decimals).font(.amount(size: size * 0.55, weight: .semibold))
            .foregroundColor(Theme.textSecondary))
            .font(.amount(size: size, weight: .bold))
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

    private func emptyState(_ shown: MonthKey, maxWidth: CGFloat) -> some View {
        ZStack {
            // Mese senza spese: un cerchio appena accennato, trasparente sullo sfondo (come nel widget).
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 26).padding(13)
            VStack(spacing: 6) {
                amountText(0, size: 36)
                Text("Nessuna spesa a \(Formatting.monthName(shown))")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: maxWidth)
        .aspectRatio(1, contentMode: .fit)
    }

    /// Spese salvate dall'automazione di Wallet senza aprire l'app: si toccano per controllarle e confermarle.
    private func pendingSection(_ pending: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Da confermare", systemImage: "checkmark.circle.badge.questionmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                Spacer()
                Text("\(pending.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            }
            VStack(spacing: 4) {
                ForEach(pending) { expense in
                    Button { router.edit(expense) } label: {
                        HStack {
                            ExpenseRow(expense: expense)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Apre la spesa per controllarla e confermarla")
                }
            }
        }
        .card()
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

    /// L'elenco dei tag come uno scontrino: nome, puntini, importo; sotto la perforazione, il budget del mese.
    private func tagList(_ summary: MonthSummary, tagBudgets: [UUID: BudgetStatus], month: MonthKey,
                         total: BudgetStatus? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(summary.slices) { slice in
                Button { open(slice, month: month) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TagDot(colorIndex: slice.colorIndex)
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                            Text(slice.name).font(.body.weight(.medium)).lineLimit(1)
                            Text(Formatting.percent(slice.fraction))
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize()
                            DottedLeader()
                            Text(Money.format(slice.cents))
                                .font(.amount(.body))
                                .fixedSize()
                        }
                        if let budget = slice.id.flatMap({ tagBudgets[$0] }) {
                            ProgressLine(fraction: budget.fraction, color: Theme.budgetColor(fraction: budget.fraction), height: 3)
                                .padding(.leading, 18)
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityElement(children: .combine)
            }
            if let total {
                Perforation().padding(.vertical, 10)
                budgetLines(total)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Il budget del mese in coda allo scontrino.
    private func budgetLines(_ status: BudgetStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Budget mensile").font(.subheadline.weight(.semibold))
                Text(Formatting.percent(status.fraction)).font(.footnote).foregroundStyle(Theme.textSecondary)
                DottedLeader()
                Text(Money.format(status.limitCents)).font(.amount(.subheadline)).fixedSize()
            }
            Text(status.remainingCents >= 0
                 ? "Restano \(Money.format(status.remainingCents))"
                 : "Superato di \(Money.format(-status.remainingCents))")
                .font(.footnote)
                .foregroundStyle(status.remainingCents >= 0 ? Theme.textSecondary : Theme.danger)
            ProgressLine(fraction: status.fraction, color: Theme.budgetColor(fraction: status.fraction), height: 6)
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func open(_ slice: TagSlice, month: MonthKey) {
        router.openHistory(tagID: slice.id, month: month)
    }

    private func change(by months: Int) {
        withAnimation(.snappy) { month = (month ?? store.currentMonth).adding(months: months) }
    }
}
