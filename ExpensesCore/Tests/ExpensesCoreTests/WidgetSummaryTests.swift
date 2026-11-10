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

@MainActor
@Suite struct LargeWidgetDataTests {
    func makeStore() -> ExpenseStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("widget-\(UUID().uuidString).json")
        return ExpenseStore(fileURL: url, calendar: rome, now: { date(2026, 11, 10, 15) })
    }

    @Test func includesCountComparisonBudgetsAndRecent() throws {
        let store = makeStore()
        let casa = store.addTag(name: "Casa")
        let svago = store.addTag(name: "Svago")
        store.setTagBudget(id: casa.id, cents: 10000)
        store.addExpense(Expense(amountCents: 1000, date: date(2026, 10, 5), tagID: casa.id))
        for day in 1...6 {
            store.addExpense(Expense(amountCents: 100 * day, date: date(2026, 11, day), tagID: day.isMultiple(of: 2) ? casa.id : svago.id,
                                     merchant: day == 6 ? "Esselunga" : nil, note: day == 5 ? "Cinema" : nil))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("summary-\(UUID().uuidString).json")
        store.writeWidgetSummary(to: url)
        let summary = try #require(WidgetSummary.read(from: url))
        #expect(summary.count == 6)
        #expect(summary.comparison?.percentChange == 110)
        #expect(summary.tagBudgets.map(\.name) == ["Casa"])
        #expect(summary.tagBudgets.first?.status.spentCents == 1200)
        #expect(summary.recent.count == 5)
        #expect(summary.recent.map(\.title) == ["Esselunga", "Cinema", "Casa", "Svago", "Casa"])
        #expect(summary.recent.first?.colorIndex == casa.colorIndex)
    }

    @Test func decodesSummaryWithoutNewFields() throws {
        let json = """
        {"month":{"year":2026,"month":11},"totalCents":500,"slices":[],"generatedAt":"2026-11-10T10:00:00Z"}
        """
        let summary = try StoreCoding.decoder().decode(WidgetSummary.self, from: Data(json.utf8))
        #expect(summary.count == 0)
        #expect(summary.comparison == nil)
        #expect(summary.tagBudgets.isEmpty)
        #expect(summary.recent.isEmpty)
    }

    @Test func newMonthClearsDetails() throws {
        let store = makeStore()
        let casa = store.addTag(name: "Casa")
        store.setTagBudget(id: casa.id, cents: 10000)
        store.addExpense(Expense(amountCents: 1000, date: date(2026, 11, 5), tagID: casa.id))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("summary-\(UUID().uuidString).json")
        store.writeWidgetSummary(to: url)
        let shown = try #require(WidgetSummary.read(from: url)).displayed(at: date(2026, 12, 1, 1), calendar: rome)
        #expect(shown.count == 0)
        #expect(shown.recent.isEmpty)
        #expect(shown.comparison == nil)
        #expect(shown.tagBudgets.first?.status.spentCents == 0)
    }
}
