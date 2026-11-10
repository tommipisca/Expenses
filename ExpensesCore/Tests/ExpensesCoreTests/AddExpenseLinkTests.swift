import Foundation
import Testing
@testable import ExpensesCore

@Suite struct AddExpenseLinkTests {
    @Test(arguments: [
        ("€12,50", 1250), ("12.50 €", 1250), ("12,5", 1250), ("EUR 12,50", 1250), ("eur12,50", 1250),
        ("1.234,56", 123456), ("€ 1.234,56", 123456), ("1,234.56", 123456), ("1.234.567", 123456700),
        ("12", 1200), ("12\u{00A0}€", 1200), ("€\u{202F}8,05", 805),
    ])
    func readsEuros(text: String, cents: Int) {
        #expect(readAmount(text) == .euros(cents: cents))
    }

    @Test(arguments: ["1.234", "1,234", "", "abc", "0", "0,00", "12.", "1.23.4", "12,345,6", "€"])
    func unreadable(text: String) {
        #expect(readAmount(text) == .unreadable)
    }

    @Test(arguments: ["-12,50", "12,50-", "(12,50)", "−12,50", "-€12,50"])
    func refunds(text: String) {
        #expect(readAmount(text) == .refund)
    }

    @Test(arguments: [("$12.50", "USD"), ("12,50 USD", "USD"), ("£8", "GBP"), ("CHF 20", "CHF"), ("¥1500", "JPY"), ("12 usd", "USD")])
    func foreign(text: String, currency: String) {
        #expect(readAmount(text) == .foreign(currency: currency))
    }

    @Test func parsesFullLink() throws {
        let url = try #require(URL(string: "expenses://add?amount=%E2%82%AC12,50&merchant=Esselunga&card=Visa"))
        let request = try #require(parseAddExpenseLink(url))
        #expect(request.amount == .euros(cents: 1250))
        #expect(request.merchant == "Esselunga")
        #expect(request.card == "Visa")
    }

    @Test func parsesEncodedSpaces() throws {
        let url = try #require(URL(string: "expenses://add?amount=12,50%20%E2%82%AC&merchant=Bar%20Mario"))
        let request = try #require(parseAddExpenseLink(url))
        #expect(request.amount == .euros(cents: 1250))
        #expect(request.merchant == "Bar Mario")
    }

    @Test func emptyLinkHasNoValues() throws {
        let request = try #require(parseAddExpenseLink(URL(string: "expenses://add")!))
        #expect(request == AddExpenseRequest(amount: nil, merchant: nil, card: nil))
    }

    @Test func emptyParametersAreNil() throws {
        let request = try #require(parseAddExpenseLink(URL(string: "expenses://add?amount=&merchant=%20&card=")!))
        #expect(request == AddExpenseRequest(amount: nil, merchant: nil, card: nil))
    }

    @Test func rejectsOtherLinks() {
        #expect(parseAddExpenseLink(URL(string: "https://add?amount=12")!) == nil)
        #expect(parseAddExpenseLink(URL(string: "expenses://month")!) == nil)
    }
}
