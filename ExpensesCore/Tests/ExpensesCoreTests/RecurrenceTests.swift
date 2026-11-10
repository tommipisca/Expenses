import Foundation
import Testing
@testable import ExpensesCore

@Suite struct RecurrenceTests {
    let tagID = UUID()

    func rule(_ frequency: Frequency, from start: Date, end: Date? = nil) -> RecurringExpense {
        RecurringExpense(amountCents: 52000, tagID: tagID, merchant: "Affitto", note: "mensile",
                         frequency: frequency, startDate: start, endDate: end)
    }

    @Test func monthlyFromEndOfMonthClampsWithoutDrifting() {
        let dates = occurrenceDates(of: rule(.monthly, from: date(2026, 1, 31, 9)), through: date(2026, 4, 15), calendar: rome)
        #expect(dates == [date(2026, 1, 31, 9), date(2026, 2, 28, 9), date(2026, 3, 31, 9)])
    }

    @Test func weekly() {
        let dates = occurrenceDates(of: rule(.weekly, from: date(2026, 10, 20, 9)), through: date(2026, 11, 10, 12), calendar: rome)
        #expect(dates == [date(2026, 10, 20, 9), date(2026, 10, 27, 9), date(2026, 11, 3, 9), date(2026, 11, 10, 9)])
    }

    @Test func yearly() {
        let dates = occurrenceDates(of: rule(.yearly, from: date(2024, 2, 29)), through: date(2026, 11, 10), calendar: rome)
        #expect(dates == [date(2024, 2, 29), date(2025, 2, 28), date(2026, 2, 28)])
    }

    @Test func respectsEndDate() {
        let dates = occurrenceDates(of: rule(.monthly, from: date(2026, 1, 5), end: date(2026, 3, 1)),
                                    through: date(2026, 11, 10), calendar: rome)
        #expect(dates == [date(2026, 1, 5), date(2026, 2, 5)])
    }

    @Test func inactiveGeneratesNothing() {
        var paused = rule(.monthly, from: date(2026, 1, 5))
        paused.isActive = false
        #expect(occurrenceDates(of: paused, through: date(2026, 11, 10), calendar: rome).isEmpty)
    }

    @Test func skipsPausedWindow() {
        var resumed = rule(.monthly, from: date(2026, 1, 15))
        resumed.lastGeneratedDate = date(2026, 2, 15)
        resumed.pausedAt = date(2026, 3, 1)
        resumed.resumedAt = date(2026, 4, 10)
        #expect(occurrenceDates(of: resumed, through: date(2026, 4, 20), calendar: rome) == [date(2026, 4, 15)])
    }

    @Test func generationIsIdempotent() {
        let first = generateDue(rules: [rule(.monthly, from: date(2026, 9, 1))], deletedIDs: [], existingIDs: [],
                                now: date(2026, 11, 10), calendar: rome)
        #expect(first.expenses.count == 3)
        #expect(first.updatedRules[0].lastGeneratedDate == date(2026, 11, 1))
        let second = generateDue(rules: first.updatedRules, deletedIDs: [], existingIDs: Set(first.expenses.map(\.id)),
                                 now: date(2026, 11, 10), calendar: rome)
        #expect(second.expenses.isEmpty)
    }

    @Test func generatedExpenseCopiesRule() {
        let r = rule(.monthly, from: date(2026, 11, 1))
        let expense = try! #require(generateDue(rules: [r], deletedIDs: [], existingIDs: [],
                                                now: date(2026, 11, 10, 8, 0), calendar: rome).expenses.first)
        #expect(expense.amountCents == 52000)
        #expect(expense.tagID == tagID)
        #expect(expense.merchant == "Affitto")
        #expect(expense.note == "mensile")
        #expect(expense.source == .recurring)
        #expect(expense.recurringID == r.id)
        #expect(expense.date == date(2026, 11, 1))
        #expect(expense.modifiedAt == date(2026, 11, 10, 8, 0))
    }

    @Test func sameOccurrenceSameIDAcrossDevices() {
        let r = rule(.monthly, from: date(2026, 9, 1))
        let iphone = generateDue(rules: [r], deletedIDs: [], existingIDs: [], now: date(2026, 11, 10), calendar: rome)
        let ipad = generateDue(rules: [r], deletedIDs: [], existingIDs: [], now: date(2026, 11, 12), calendar: rome)
        #expect(iphone.expenses.map(\.id) == ipad.expenses.map(\.id))
        #expect(Set(iphone.expenses.map(\.id)).count == 3)
        #expect(!iphone.expenses.map(\.id).contains(r.id))
    }

    @Test func deletedOccurrenceIsNotRecreated() {
        let r = rule(.monthly, from: date(2026, 11, 1))
        let deleted = occurrenceID(recurringID: r.id, date: date(2026, 11, 1), calendar: rome)
        let result = generateDue(rules: [r], deletedIDs: [deleted], existingIDs: [], now: date(2026, 11, 10), calendar: rome)
        #expect(result.expenses.isEmpty)
        #expect(result.updatedRules[0].lastGeneratedDate == date(2026, 11, 1))
    }
}
