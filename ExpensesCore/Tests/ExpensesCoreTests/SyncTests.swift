import Foundation
import Testing
@testable import ExpensesCore

@Suite struct SyncTests {
    let t0 = date(2026, 11, 10, 10)

    func expense(_ cents: Int, modified: Date, id: UUID = UUID()) -> Expense {
        Expense(id: id, amountCents: cents, date: date(2026, 11, 2), modifiedAt: modified)
    }

    @Test func keepsChangesFromBothSides() {
        let a = expense(100, modified: t0), b = expense(200, modified: t0)
        var onA = a; onA.amountCents = 150; onA.modifiedAt = t0.addingTimeInterval(60)
        var onB = b; onB.amountCents = 250; onB.modifiedAt = t0.addingTimeInterval(30)
        let merged = SyncSnapshot.merge(local: SyncSnapshot(expenses: [onA, b]), remote: SyncSnapshot(expenses: [a, onB]))
        #expect(Set(merged.expenses.map(\.amountCents)) == [150, 250])
    }

    @Test func newerDeletionRemoves() {
        let a = expense(100, modified: t0)
        let remote = SyncSnapshot(deletions: [a.id.uuidString: t0.addingTimeInterval(5)])
        #expect(SyncSnapshot.merge(local: SyncSnapshot(expenses: [a]), remote: remote).expenses.isEmpty)
    }

    @Test func newerEditSurvivesOlderDeletion() {
        let a = expense(100, modified: t0.addingTimeInterval(10))
        let remote = SyncSnapshot(deletions: [a.id.uuidString: t0])
        let merged = SyncSnapshot.merge(local: SyncSnapshot(expenses: [a]), remote: remote)
        #expect(merged.expenses.count == 1)
        #expect(merged.deletions[a.id.uuidString] == t0)
    }

    @Test func sameRecurringOccurrenceMergesIntoOne() {
        let rule = RecurringExpense(amountCents: 52000, frequency: .monthly, startDate: date(2026, 11, 1), modifiedAt: t0)
        let onIPhone = generateDue(rules: [rule], deletedIDs: [], existingIDs: [], now: date(2026, 11, 10), calendar: rome)
        let onIPad = generateDue(rules: [rule], deletedIDs: [], existingIDs: [], now: date(2026, 11, 11), calendar: rome)
        let merged = SyncSnapshot.merge(
            local: SyncSnapshot(expenses: onIPhone.expenses, recurring: onIPhone.updatedRules),
            remote: SyncSnapshot(expenses: onIPad.expenses, recurring: onIPad.updatedRules))
        #expect(merged.expenses.count == 1)
        #expect(merged.recurring.count == 1)
    }

    @Test func recurringKeepsLatestGeneratedDate() {
        var older = RecurringExpense(amountCents: 900, frequency: .monthly, startDate: date(2026, 9, 1), modifiedAt: t0)
        var newer = older
        older.lastGeneratedDate = date(2026, 10, 1)
        newer.lastGeneratedDate = date(2026, 11, 1)
        newer.amountCents = 900
        let merged = SyncSnapshot.merge(local: SyncSnapshot(recurring: [older]), remote: SyncSnapshot(recurring: [newer]))
        #expect(merged.recurring.first?.lastGeneratedDate == date(2026, 11, 1))
    }

    @Test func tagsAndSettingsUseNewest() {
        let tag = Tag(name: "Casa", modifiedAt: t0)
        var renamed = tag; renamed.name = "Casa e bollette"; renamed.modifiedAt = t0.addingTimeInterval(1)
        let merged = SyncSnapshot.merge(
            local: SyncSnapshot(tags: [tag], settings: SyncedSettings(monthlyBudgetCents: 1000, modifiedAt: t0.addingTimeInterval(9))),
            remote: SyncSnapshot(tags: [renamed], settings: SyncedSettings(monthlyBudgetCents: nil, modifiedAt: t0)))
        #expect(merged.tags.map(\.name) == ["Casa e bollette"])
        #expect(merged.settings.monthlyBudgetCents == 1000)
    }

    @Test func sentAlertsAreUnited() {
        let merged = SyncSnapshot.merge(local: SyncSnapshot(sentAlerts: ["total|2026-11|80"]),
                                        remote: SyncSnapshot(sentAlerts: ["total|2026-11|100"]))
        #expect(merged.sentAlerts == ["total|2026-11|80", "total|2026-11|100"])
    }

    @Test func mergeIsSymmetric() {
        let id = UUID()
        let a = SyncSnapshot(expenses: [expense(100, modified: t0, id: id), expense(5, modified: t0)],
                             deletions: ["x": t0], sentAlerts: ["a"])
        let b = SyncSnapshot(expenses: [expense(300, modified: t0.addingTimeInterval(3), id: id)],
                             deletions: ["x": t0.addingTimeInterval(2)], sentAlerts: ["b"])
        #expect(SyncSnapshot.merge(local: a, remote: b).hasSameContent(as: SyncSnapshot.merge(local: b, remote: a)))
    }

    @Test func tieIsResolvedTheSameOnBothDevices() {
        let id = UUID()
        let a = SyncSnapshot(expenses: [expense(100, modified: t0, id: id)])
        let b = SyncSnapshot(expenses: [expense(200, modified: t0, id: id)])
        #expect(SyncSnapshot.merge(local: a, remote: b).hasSameContent(as: SyncSnapshot.merge(local: b, remote: a)))
    }

    @Test func decodesOldSyncFile() throws {
        let snapshot = try SyncSnapshot.decode(Data("""
        {"expenses":[{"id":"8F6B1C9E-2D4A-4B6C-9E1F-0A2B3C4D5E6F","amountCents":500,"date":"2026-11-01T10:00:00Z"}]}
        """.utf8))
        #expect(snapshot.expenses.count == 1)
        #expect(snapshot.recurring.isEmpty)
        #expect(snapshot.sentAlerts.isEmpty)
    }

    @Test func encodesAndDecodes() throws {
        let snapshot = SyncSnapshot(expenses: [expense(100, modified: t0)], tags: [Tag(name: "Casa", modifiedAt: t0)])
        #expect(try SyncSnapshot.decode(snapshot.encoded()) == snapshot)
    }

    @MainActor
    @Test func storeAppliesSyncedData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString).json")
        let store = ExpenseStore(fileURL: url, calendar: rome, now: { date(2026, 11, 10) })
        store.addTag(name: "Locale")
        let remote = SyncSnapshot(expenses: [expense(700, modified: t0)])
        store.applySynced(SyncSnapshot.merge(local: store.snapshot(), remote: remote))
        #expect(store.expenses.map(\.amountCents) == [700])
        #expect(store.tags.map(\.name) == ["Locale"])
        #expect(ExpenseStore(fileURL: url, calendar: rome).expenses.count == 1)
    }
}
