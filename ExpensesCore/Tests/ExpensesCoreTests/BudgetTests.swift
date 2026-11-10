import Foundation
import Testing
@testable import ExpensesCore

@Suite struct BudgetTests {
    let november = MonthKey(year: 2026, month: 11)

    func summary(_ items: [(Int, Tag?)], tags: [Tag]) -> MonthSummary {
        let expenses = items.map { Expense(amountCents: $0.0, date: date(2026, 11, 2), tagID: $0.1?.id) }
        return MonthSummary.make(expenses: expenses, tags: tags, month: november, now: date(2026, 11, 10), calendar: rome)
    }

    @Test func noBudgetsNoStatuses() {
        let casa = Tag(name: "Casa")
        #expect(budgetStatuses(summary: summary([(1000, casa)], tags: [casa]), tags: [casa], settings: SyncedSettings()).isEmpty)
    }

    @Test func onlyConfiguredBudgetsTotalFirst() {
        let casa = Tag(name: "Casa", budgetCents: 50000)
        let svago = Tag(name: "Svago")
        let statuses = budgetStatuses(summary: summary([(30000, casa), (2000, svago)], tags: [casa, svago]),
                                      tags: [casa, svago], settings: SyncedSettings(monthlyBudgetCents: 100000))
        #expect(statuses.map(\.target) == [.total, .tag(casa.id)])
        #expect(statuses[0].spentCents == 32000)
        #expect(statuses[1].spentCents == 30000)
        #expect(statuses[1].remainingCents == 20000)
    }

    @Test func tagBudgetWithoutSpendingIsZero() {
        let casa = Tag(name: "Casa", budgetCents: 50000)
        let statuses = budgetStatuses(summary: summary([], tags: [casa]), tags: [casa], settings: SyncedSettings())
        #expect(statuses.first?.spentCents == 0)
    }

    @Test func overspentHasNegativeRemaining() {
        let status = BudgetStatus(target: .total, limitCents: 1000, spentCents: 1500)
        #expect(status.remainingCents == -500)
        #expect(status.fraction == 1.5)
    }

    @Test(arguments: [(79, [AlertThreshold]()), (80, [.eighty]), (99, [.eighty]), (100, [.hundred]), (120, [.hundred])])
    func thresholds(percent: Int, expected: [AlertThreshold]) {
        let status = BudgetStatus(target: .total, limitCents: 10000, spentCents: percent * 100)
        #expect(pendingAlerts(statuses: [status], month: november, alreadySent: []).map(\.threshold) == expected)
    }

    @Test func eightyAlreadySentThenHundred() {
        let status = BudgetStatus(target: .total, limitCents: 10000, spentCents: 10000)
        let sent: Set<String> = ["total|2026-11|80"]
        #expect(pendingAlerts(statuses: [status], month: november, alreadySent: sent).map(\.id) == ["total|2026-11|100"])
    }

    @Test func doesNotRepeatSentAlerts() {
        let status = BudgetStatus(target: .total, limitCents: 10000, spentCents: 8500)
        #expect(pendingAlerts(statuses: [status], month: november, alreadySent: ["total|2026-11|80"]).isEmpty)
    }

    @Test func tagAlertKey() {
        let id = UUID(uuidString: "8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F")!
        let key = AlertKey(target: .tag(id), month: november, threshold: .eighty)
        #expect(key.id == "tag:8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F|2026-11|80")
    }
}
