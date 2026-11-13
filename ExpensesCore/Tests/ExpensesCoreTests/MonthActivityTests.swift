import Foundation
import Testing
@testable import ExpensesCore

@Suite struct MonthActivityTests {
    let november = MonthKey(year: 2026, month: 11)

    @Test func dailyTotalsAndToday() {
        let expenses = [
            Expense(amountCents: 500, date: date(2026, 11, 1, 9)),
            Expense(amountCents: 250, date: date(2026, 11, 1, 20)),
            Expense(amountCents: 3_420, date: date(2026, 11, 12)),
            Expense(amountCents: 999, date: date(2026, 10, 31, 23, 30)),
        ]
        let daily = DailySpending.make(expenses: expenses, month: november, now: date(2026, 11, 13), calendar: rome)
        #expect(daily.cents.count == 30)
        #expect(daily.cents[0] == 750)
        #expect(daily.cents[11] == 3_420)
        #expect(daily.today == 13)
        #expect(daily.busiestDay == 12)
        #expect(daily.maxCents == 3_420)
    }

    @Test func pastMonthHasNoToday() {
        let daily = DailySpending.make(expenses: [], month: november, now: date(2026, 12, 3), calendar: rome)
        #expect(daily.today == nil)
        #expect(daily.busiestDay == nil)
    }

    @Test func recentExpensesNewestFirstWithinMonth() {
        let expenses = [
            Expense(amountCents: 1, date: date(2026, 11, 3), merchant: "A"),
            Expense(amountCents: 2, date: date(2026, 11, 12), merchant: "B"),
            Expense(amountCents: 3, date: date(2026, 11, 7), merchant: "C"),
            Expense(amountCents: 4, date: date(2026, 10, 30), merchant: "Ottobre"),
        ]
        #expect(expenses.recent(in: november, limit: 2, calendar: rome).map(\.merchant) == ["B", "C"])
    }
}
