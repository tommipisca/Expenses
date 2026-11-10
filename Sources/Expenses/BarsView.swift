import SwiftUI
import ExpensesCore

/// Vista alternativa del mese: barra segmentata e un riquadro per tag.
struct BarsView: View {
    let summary: MonthSummary
    let tagBudgets: [UUID: BudgetStatus]
    let onSelect: (TagSlice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GeometryReader { proxy in
                let spacing: CGFloat = 4
                let available = proxy.size.width - spacing * CGFloat(max(summary.slices.count - 1, 0))
                HStack(spacing: spacing) {
                    ForEach(summary.slices) { slice in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Theme.tagColor(index: slice.colorIndex))
                            .frame(width: max(available * slice.fraction, 6))
                    }
                }
            }
            .frame(height: 18)
            .clipShape(Capsule())

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(summary.slices) { slice in
                    Button { onSelect(slice) } label: { tile(slice) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func tile(_ slice: TagSlice) -> some View {
        let budget = slice.id.flatMap { tagBudgets[$0] }
        let largest = summary.slices.first?.cents ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TagDot(colorIndex: slice.colorIndex, size: 8)
                Text(slice.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text(Formatting.percent(slice.fraction)).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Text(Money.format(slice.cents)).font(.rounded(.title3, weight: .semibold)).monospacedDigit()
            if let budget {
                ProgressLine(fraction: budget.fraction, color: Theme.budgetColor(fraction: budget.fraction))
            } else {
                ProgressLine(fraction: Double(slice.cents) / Double(max(largest, 1)), color: Theme.tagColor(index: slice.colorIndex))
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .card(padding: 14)
    }
}
