import Foundation
import Testing
@testable import ExpensesCore

@Suite struct ModelsCodingTests {
    func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: encoder.encode(value))
    }

    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func roundTripsAllModels() throws {
        let tag = Tag(name: "Casa", colorIndex: 2, budgetCents: 50000, modifiedAt: date(2026, 11, 1))
        let expense = Expense(amountCents: 1250, date: date(2026, 11, 10), tagID: tag.id, merchant: "Esselunga",
                              note: "pane", source: .wallet, modifiedAt: date(2026, 11, 10))
        let rule = RecurringExpense(amountCents: 52000, tagID: tag.id, frequency: .monthly, startDate: date(2026, 1, 1),
                                    pausedAt: date(2026, 3, 1), resumedAt: date(2026, 4, 1))
        #expect(try roundTrip(tag) == tag)
        #expect(try roundTrip(expense) == expense)
        #expect(try roundTrip(rule) == rule)
        #expect(try roundTrip(SyncedSettings(monthlyBudgetCents: 150000)) == SyncedSettings(monthlyBudgetCents: 150000))
    }

    @Test func decodesMinimalExpense() throws {
        let expense = try decode(Expense.self, """
        {"id":"8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F","amountCents":1250,"date":"2026-11-10T10:00:00Z"}
        """)
        #expect(expense.amountCents == 1250)
        #expect(expense.source == .manual)
        #expect(expense.tagID == nil)
        #expect(expense.merchant == nil)
        #expect(expense.recurringID == nil)
        #expect(expense.modifiedAt == nil)
    }

    @Test func decodesMinimalRecurring() throws {
        let rule = try decode(RecurringExpense.self, """
        {"id":"8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F","amountCents":900,"frequency":"monthly","startDate":"2026-01-05T10:00:00Z"}
        """)
        #expect(rule.isActive == true)
        #expect(rule.pausedAt == nil)
        #expect(rule.resumedAt == nil)
        #expect(rule.lastGeneratedDate == nil)
        #expect(rule.endDate == nil)
    }

    @Test func decodesTagWithoutBudget() throws {
        let tag = try decode(Tag.self, """
        {"id":"8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F","name":"Svago"}
        """)
        #expect(tag.budgetCents == nil)
        #expect(tag.colorIndex == 0)
    }

    @Test func roundsToSecond() {
        let value = Date(timeIntervalSinceReferenceDate: 100.7)
        #expect(value.roundedToSecond == Date(timeIntervalSinceReferenceDate: 101))
    }
}
