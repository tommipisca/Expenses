import Foundation
import Testing
@testable import ExpensesCore

@Suite struct WidgetSummaryTests {
    let summary = WidgetSummary(
        month: MonthKey(year: 2026, month: 11), totalCents: 28000,
        slices: [TagSlice(id: UUID(), name: "Casa", colorIndex: 0, cents: 28000, fraction: 1)],
        monthlyBudget: BudgetStatus(target: .total, limitCents: 50000, spentCents: 28000),
        generatedAt: date(2026, 11, 10))

    @Test func sameMonthIsUnchanged() {
        #expect(summary.displayed(at: date(2026, 11, 30, 23), calendar: rome) == summary)
    }

    @Test func newMonthStartsFromZero() {
        let shown = summary.displayed(at: date(2026, 12, 1, 0, 1), calendar: rome)
        #expect(shown.month == MonthKey(year: 2026, month: 12))
        #expect(shown.totalCents == 0)
        #expect(shown.slices.isEmpty)
        #expect(shown.monthlyBudget == BudgetStatus(target: .total, limitCents: 50000, spentCents: 0))
    }

    @Test func nextMonthStart() {
        #expect(WidgetSummary.startOfNextMonth(after: date(2026, 12, 15), calendar: rome) == date(2027, 1, 1, 0))
    }
}
