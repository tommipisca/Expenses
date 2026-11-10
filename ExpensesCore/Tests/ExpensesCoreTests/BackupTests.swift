import Foundation
import Testing
@testable import ExpensesCore

@Suite struct BackupTests {
    @Test func keepsNewestAndIgnoresOtherFiles() {
        let names = ["Expenses-backup-2026-10-01.json", "Expenses-backup-2026-10-03.json", "appunti.txt",
                     "Expenses-backup-2026-10-02.json", "Expenses-backup-2026-10-04.json"]
        #expect(BackupRotation.filesToDelete(names, keep: 2) == ["Expenses-backup-2026-10-02.json", "Expenses-backup-2026-10-01.json"])
    }

    @Test func dailyFileNameIsAlwaysGregorian() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Europe/Rome")!
        #expect(BackupRotation.fileName(for: date(2026, 10, 13), calendar: buddhist) == "Expenses-backup-2026-10-13.json")
    }

    @Test func mergesSeveralVersions() {
        let a = Expense(amountCents: 1, date: date(2026, 11, 1), modifiedAt: date(2026, 11, 1))
        let b = Expense(amountCents: 2, date: date(2026, 11, 1), modifiedAt: date(2026, 11, 1))
        let c = Expense(amountCents: 3, date: date(2026, 11, 1), modifiedAt: date(2026, 11, 1))
        let merged = SyncSnapshot.mergeAll(local: SyncSnapshot(expenses: [a]),
                                           remotes: [SyncSnapshot(expenses: [b]), SyncSnapshot(expenses: [c])])
        #expect(merged.expenses.map(\.amountCents) == [1, 2, 3])
    }

    @MainActor
    @Test func backupIsTheSnapshot() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString).json")
        let store = ExpenseStore(fileURL: url, calendar: rome, now: { date(2026, 11, 10) })
        store.addTag(name: "Casa")
        #expect(try SyncSnapshot.decode(store.exportBackup()) == store.snapshot())
    }
}
