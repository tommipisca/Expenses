import Foundation
import Testing
@testable import ExpensesCore

@Suite struct MonthSummaryTests {
    let casa = Tag(name: "Casa", colorIndex: 0)
    let spesa = Tag(name: "Spesa", colorIndex: 1)
    let ristoranti = Tag(name: "Ristoranti", colorIndex: 4)
    let november = MonthKey(year: 2026, month: 11)

    func expense(_ cents: Int, _ tag: Tag?, _ when: Date) -> Expense {
        Expense(amountCents: cents, date: when, tagID: tag?.id)
    }

    @Test func groupsByLocalMonth() {
        // 31 ottobre 2026 è il giorno del cambio d'ora in Italia.
        let lateOctober = date(2026, 10, 31, 23, 30)
        #expect(MonthKey(date: lateOctober, calendar: rome) == MonthKey(year: 2026, month: 10))
        let summary = MonthSummary.make(expenses: [expense(500, casa, lateOctober)], tags: [casa],
                                        month: november, now: date(2026, 11, 10), calendar: rome)
        #expect(summary.totalCents == 0)
        #expect(summary.count == 0)
    }

    @Test func monthKeyArithmeticAndID() {
        #expect(november.adding(months: 2) == MonthKey(year: 2027, month: 1))
        #expect(november.adding(months: -11) == MonthKey(year: 2025, month: 12))
        #expect(november.id == "2026-11")
        let range = november.range(calendar: rome)
        #expect(range.lowerBound == date(2026, 11, 1, 0))
        #expect(range.upperBound == date(2026, 12, 1, 0))
    }

    @Test func slicesSortedAndFractions() {
        let expenses = [
            expense(13200, ristoranti, date(2026, 11, 3)),
            expense(52000, casa, date(2026, 11, 1)),
            expense(20000, spesa, date(2026, 11, 2)),
            expense(8640, spesa, date(2026, 11, 4)),
        ]
        let summary = MonthSummary.make(expenses: expenses, tags: [casa, spesa, ristoranti],
                                        month: november, now: date(2026, 11, 10), calendar: rome)
        #expect(summary.slices.map(\.name) == ["Casa", "Spesa", "Ristoranti"])
        #expect(summary.slices.map(\.cents) == [52000, 28640, 13200])
        #expect(summary.slices[1].colorIndex == 1)
        #expect(abs(summary.slices.map(\.fraction).reduce(0, +) - 1) < 1e-9)
        #expect(summary.totalCents == 93840)
        #expect(summary.count == 4)
    }

    @Test func untaggedAndDeletedTagGoToSenzaTag() {
        let deleted = Tag(name: "Vecchio")
        let expenses = [expense(1000, nil, date(2026, 11, 2)), expense(500, deleted, date(2026, 11, 3)),
                        expense(300, casa, date(2026, 11, 3))]
        let summary = MonthSummary.make(expenses: expenses, tags: [casa], month: november,
                                        now: date(2026, 11, 10), calendar: rome)
        #expect(summary.slices.count == 2)
        let untagged = summary.slices[0]
        #expect(untagged.id == nil)
        #expect(untagged.name == "Senza tag")
        #expect(untagged.colorIndex == nil)
        #expect(untagged.cents == 1500)
    }

    @Test func currentMonthComparesSameDay() {
        let expenses = [expense(1000, casa, date(2026, 10, 5)), expense(5000, casa, date(2026, 10, 20)),
                        expense(900, casa, date(2026, 11, 3))]
        let summary = MonthSummary.make(expenses: expenses, tags: [casa], month: november,
                                        now: date(2026, 11, 10, 15), calendar: rome)
        let comparison = try! #require(summary.comparison)
        #expect(comparison.previousMonth == MonthKey(year: 2026, month: 10))
        #expect(comparison.previousCents == 1000)
        #expect(comparison.percentChange == -10)
        #expect(comparison.sameDay)
    }

    @Test func sameDayIncludesTheWholeDay() {
        let expenses = [expense(1000, casa, date(2026, 10, 10, 22)), expense(1000, casa, date(2026, 11, 1))]
        let summary = MonthSummary.make(expenses: expenses, tags: [casa], month: november,
                                        now: date(2026, 11, 10, 9), calendar: rome)
        #expect(summary.comparison?.previousCents == 1000)
        #expect(summary.comparison?.percentChange == 0)
    }

    @Test func pastMonthComparesWholeMonth() {
        let expenses = [expense(1000, casa, date(2026, 9, 5)), expense(1000, casa, date(2026, 9, 29)),
                        expense(3000, casa, date(2026, 10, 2))]
        let summary = MonthSummary.make(expenses: expenses, tags: [casa], month: MonthKey(year: 2026, month: 10),
                                        now: date(2026, 11, 10), calendar: rome)
        #expect(summary.comparison?.previousCents == 2000)
        #expect(summary.comparison?.percentChange == 50)
        #expect(summary.comparison?.sameDay == false)
    }

    @Test func noComparisonWhenPreviousEmpty() {
        let summary = MonthSummary.make(expenses: [expense(1000, casa, date(2026, 11, 2))], tags: [casa],
                                        month: november, now: date(2026, 11, 10), calendar: rome)
        #expect(summary.comparison == nil)
    }

    @Test func sameDayClampsShortMonth() {
        let expenses = [expense(1000, casa, date(2026, 2, 28, 20)), expense(2000, casa, date(2026, 3, 30))]
        let summary = MonthSummary.make(expenses: expenses, tags: [casa], month: MonthKey(year: 2026, month: 3),
                                        now: date(2026, 3, 31), calendar: rome)
        #expect(summary.comparison?.previousCents == 1000)
        #expect(summary.comparison?.percentChange == 100)
    }
}
