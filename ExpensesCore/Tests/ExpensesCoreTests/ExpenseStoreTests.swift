import Foundation
import Testing
@testable import ExpensesCore

@MainActor
@Suite struct ExpenseStoreTests {
    let folder: URL
    let fileURL: URL
    var clock = date(2026, 11, 10, 15)

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("ExpenseStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("expenses.json")
    }

    func makeStore() -> ExpenseStore {
        let now = clock
        return ExpenseStore(fileURL: fileURL, calendar: rome, now: { now })
    }

    @Test func savesAndReloads() {
        let store = makeStore()
        let tag = store.addTag(name: "Casa")
        store.addExpense(Expense(amountCents: 1250, date: date(2026, 11, 9), tagID: tag.id, merchant: "Esselunga"))
        store.setMonthlyBudget(cents: 150000)
        store.setTagBudget(id: tag.id, cents: 50000)
        store.addRecurring(RecurringExpense(amountCents: 900, frequency: .monthly, startDate: date(2026, 12, 1)))
        store.markAlertsSent([AlertKey(target: .total, month: MonthKey(year: 2026, month: 11), threshold: .eighty)])

        let reloaded = makeStore()
        #expect(reloaded.data == store.data)
        #expect(reloaded.expenses.first?.modifiedAt == date(2026, 11, 10, 15))
        #expect(reloaded.settings.monthlyBudgetCents == 150000)
        #expect(reloaded.tags.first?.budgetCents == 50000)
        #expect(reloaded.data.sentAlerts == ["total|2026-11|80"])
    }

    @Test func opensFileWithOnlyExpenses() throws {
        try Data("""
        {"expenses":[{"id":"8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F","amountCents":500,"date":"2026-11-01T10:00:00Z"}]}
        """.utf8).write(to: fileURL)
        let store = makeStore()
        #expect(store.expenses.count == 1)
        #expect(store.tags.isEmpty)
        #expect(store.lastError == nil)
    }

    @Test func missingFileGivesEmptyStore() {
        let store = makeStore()
        #expect(store.expenses.isEmpty)
        #expect(store.lastError == nil)
    }

    @Test func corruptFileIsKeptAside() throws {
        try Data("non è json".utf8).write(to: fileURL)
        let store = makeStore()
        #expect(store.expenses.isEmpty)
        #expect(store.lastError == .corruptedData)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names.contains { $0.hasPrefix("expenses.corrupt-") })
        store.addTag(name: "Nuovo")
        let corrupt = try #require(names.first { $0.hasPrefix("expenses.corrupt-") })
        #expect(try String(contentsOf: folder.appendingPathComponent(corrupt), encoding: .utf8) == "non è json")
    }

    @Test func deleteTagKeepsExpensesUntagged() {
        let store = makeStore()
        let tag = store.addTag(name: "Svago")
        store.addExpense(Expense(amountCents: 1000, date: date(2026, 11, 2), tagID: tag.id))
        store.addRecurring(RecurringExpense(amountCents: 900, tagID: tag.id, frequency: .monthly, startDate: date(2026, 12, 1)))
        store.deleteTag(id: tag.id)
        #expect(store.tags.isEmpty)
        #expect(store.expenses.count == 1)
        #expect(store.tag(id: store.expenses[0].tagID) == nil)
        #expect(store.tag(id: store.recurring[0].tagID) == nil)
        #expect(store.data.deletions[tag.id.uuidString] != nil)
    }

    @Test func deleteExpenseRecordsDeletion() {
        let store = makeStore()
        let expense = Expense(amountCents: 1000, date: date(2026, 11, 2))
        store.addExpense(expense)
        store.deleteExpense(id: expense.id)
        #expect(store.expenses.isEmpty)
        #expect(store.data.deletions[expense.id.uuidString] == date(2026, 11, 10, 15).addingTimeInterval(1))
    }

    @Test func modificationStampsAlwaysIncrease() {
        let store = makeStore()
        var expense = Expense(amountCents: 1000, date: date(2026, 11, 2))
        store.addExpense(expense)
        expense.amountCents = 2000
        store.updateExpense(expense)
        #expect(store.expenses[0].amountCents == 2000)
        #expect(store.expenses[0].modifiedAt == date(2026, 11, 10, 15).addingTimeInterval(1))
    }

    @Test func addTagPicksLeastUsedColor() {
        let store = makeStore()
        #expect(store.addTag(name: "A").colorIndex == 0)
        #expect(store.addTag(name: "B").colorIndex == 1)
        #expect(store.addTag(name: "C").colorIndex == 2)
    }

    @Test func suggestsTagOfLatestSameMerchant() {
        let store = makeStore()
        let spesa = store.addTag(name: "Spesa")
        let casa = store.addTag(name: "Casa")
        store.addExpense(Expense(amountCents: 100, date: date(2026, 10, 1), tagID: casa.id, merchant: "Esselunga"))
        store.addExpense(Expense(amountCents: 100, date: date(2026, 11, 1), tagID: spesa.id, merchant: "ESSELUNGA"))
        #expect(store.suggestedTagID(forMerchant: "  esselunga ") == spesa.id)
        #expect(store.suggestedTagID(forMerchant: "Coop") == nil)
        store.deleteTag(id: spesa.id)
        #expect(store.suggestedTagID(forMerchant: "esselunga") == nil)
    }

    @Test func generateDueRecurringIsIdempotent() {
        let store = makeStore()
        store.addRecurring(RecurringExpense(amountCents: 52000, frequency: .monthly, startDate: date(2026, 9, 1)))
        #expect(store.generateDueRecurring().count == 3)
        #expect(store.generateDueRecurring().isEmpty)
        #expect(store.expenses.count == 3)
        #expect(makeStore().generateDueRecurring().isEmpty)
    }

    @Test func deletedRecurringOccurrenceStaysDeleted() {
        let store = makeStore()
        store.addRecurring(RecurringExpense(amountCents: 52000, frequency: .monthly, startDate: date(2026, 11, 1)))
        let generated = store.generateDueRecurring()
        store.deleteExpense(id: generated[0].id)
        var rule = store.recurring[0]
        rule.lastGeneratedDate = nil
        store.updateRecurring(rule)
        #expect(store.generateDueRecurring().isEmpty)
    }

    @Test func pauseAndResumeSetDates() {
        let store = makeStore()
        let rule = RecurringExpense(amountCents: 900, frequency: .monthly, startDate: date(2026, 12, 1))
        store.addRecurring(rule)
        store.setRecurringActive(id: rule.id, active: false)
        #expect(store.recurring[0].isActive == false)
        #expect(store.recurring[0].pausedAt == date(2026, 11, 10, 15))
        store.setRecurringActive(id: rule.id, active: true)
        #expect(store.recurring[0].isActive)
        #expect(store.recurring[0].resumedAt == date(2026, 11, 10, 15))
    }

    @Test func widgetSummaryGroupsSmallTagsIntoAltro() throws {
        let store = makeStore()
        for (index, cents) in [7000, 6000, 5000, 4000, 3000, 2000, 1000].enumerated() {
            let tag = store.addTag(name: "T\(index)")
            store.addExpense(Expense(amountCents: cents, date: date(2026, 11, 2), tagID: tag.id))
        }
        store.setMonthlyBudget(cents: 50000)
        let url = folder.appendingPathComponent("widget-summary.json")
        store.writeWidgetSummary(to: url)
        let summary = try #require(WidgetSummary.read(from: url))
        #expect(summary.month == MonthKey(year: 2026, month: 11))
        #expect(summary.totalCents == 28000)
        #expect(summary.slices.map(\.name) == ["T0", "T1", "T2", "T3", "Altro"])
        #expect(summary.slices.last?.cents == 6000)
        #expect(summary.slices.last?.id == WidgetSummary.otherID)
        #expect(summary.monthlyBudget?.remainingCents == 22000)
    }

    @Test func notifiesOnChange() {
        let store = makeStore()
        var calls = 0
        store.onChange = { calls += 1 }
        store.addTag(name: "Casa")
        #expect(calls == 1)
    }
}
