import Foundation
import Testing
@testable import ExpensesCore

/// Spese salvate dall'automazione di Wallet senza aprire l'app, da confermare in seguito.
@MainActor
@Suite struct PendingReviewTests {
    let fileURL: URL
    let clock = date(2026, 11, 12, 18)

    init() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PendingReviewTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("expenses.json")
    }

    func makeStore() -> ExpenseStore {
        let now = clock
        return ExpenseStore(fileURL: fileURL, calendar: rome, now: { now })
    }

    @Test func savesPendingExpenseFromWallet() throws {
        let store = makeStore()
        let expense = store.addPendingExpense(amountText: "€3,20", merchant: " Bar Mario ", date: date(2026, 11, 12, 8, 30))
        #expect(expense.amountCents == 320)
        #expect(expense.merchant == "Bar Mario")
        #expect(expense.note == nil)
        #expect(expense.source == .wallet)
        #expect(expense.needsReview)
        #expect(store.pendingReview.map(\.id) == [expense.id])
        #expect(makeStore().pendingReview.map(\.id) == [expense.id])
    }

    @Test func pendingExpenseCountsInMonthTotal() {
        let store = makeStore()
        store.addPendingExpense(amountText: "12,50", merchant: nil, date: date(2026, 11, 12))
        #expect(store.summary(for: MonthKey(year: 2026, month: 11)).totalCents == 1250)
    }

    @Test func unreadableAmountIsKeptInNote() {
        let store = makeStore()
        let foreign = store.addPendingExpense(amountText: "$10.00", merchant: "Shop", date: clock)
        #expect(foreign.amountCents == 0)
        #expect(foreign.note == "Importo da Wallet: $10.00")
        let missing = store.addPendingExpense(amountText: "  ", merchant: nil, date: clock)
        #expect(missing.amountCents == 0)
        #expect(missing.note == nil)
        #expect(missing.merchant == nil)
    }

    @Test func usesTagOfLastExpenseFromSameMerchant() {
        let store = makeStore()
        let bar = store.addTag(name: "Bar")
        store.addExpense(Expense(amountCents: 150, date: date(2026, 11, 1), tagID: bar.id, merchant: "Bar Mario"))
        let expense = store.addPendingExpense(amountText: "1,50", merchant: "bar mario", date: clock)
        #expect(expense.tagID == bar.id)
    }

    @Test func confirmingRemovesFromPendingAndKeepsEdits() throws {
        let store = makeStore()
        var expense = store.addPendingExpense(amountText: "$10", merchant: "Shop", date: clock)
        expense.amountCents = 930
        store.confirmExpense(expense)
        #expect(store.pendingReview.isEmpty)
        let saved = try #require(store.expenses.first)
        #expect(saved.amountCents == 930)
        #expect(!saved.needsReview)
    }

    @Test func pendingReviewIsNewestFirst() {
        let store = makeStore()
        let older = store.addPendingExpense(amountText: "1", merchant: "A", date: date(2026, 11, 10))
        let newer = store.addPendingExpense(amountText: "2", merchant: "B", date: date(2026, 11, 11))
        store.addExpense(Expense(amountCents: 100, date: date(2026, 11, 12)))
        #expect(store.pendingReview.map(\.id) == [newer.id, older.id])
    }

    @Test func oldFilesDecodeAsReviewed() throws {
        let json = #"{"id":"8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F","amountCents":500,"date":"2026-11-01T10:00:00Z"}"#
        let expense = try StoreCoding.decoder().decode(Expense.self, from: Data(json.utf8))
        #expect(!expense.needsReview)
    }
}
