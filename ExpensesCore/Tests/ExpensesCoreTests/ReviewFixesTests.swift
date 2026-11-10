import Foundation
import Testing
@testable import ExpensesCore

@MainActor
@Suite struct ReviewFixesTests {
    func tempURL(_ name: String = "expenses.json") -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ReviewFixes-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(name)
    }

    // C1: una modifica fatta mentre la sincronizzazione era in corso non deve sparire.
    @Test func applySyncedKeepsEditsMadeAfterSnapshot() {
        let store = ExpenseStore(fileURL: tempURL(), calendar: rome, now: { date(2026, 11, 10) })
        let snapshot = store.snapshot()
        store.addExpense(Expense(amountCents: 1250, date: date(2026, 11, 10)))
        let remote = SyncSnapshot(expenses: [Expense(amountCents: 700, date: date(2026, 11, 2), modifiedAt: date(2026, 11, 2))])
        store.applySynced(SyncSnapshot.merge(local: snapshot, remote: remote))
        #expect(Set(store.expenses.map(\.amountCents)) == [1250, 700])
    }

    // C2: un'occorrenza eliminata su un dispositivo non torna se l'altro la rigenera più tardi.
    @Test func regeneratedOccurrenceDoesNotUndoDeletion() {
        let rule = RecurringExpense(amountCents: 52000, frequency: .monthly, startDate: date(2026, 11, 1), modifiedAt: date(2026, 10, 1))
        let iphone = generateDue(rules: [rule], deletedIDs: [], existingIDs: [], now: date(2026, 11, 1, 13), calendar: rome)
        let id = iphone.expenses[0].id
        let deletedOnIPhone = SyncSnapshot(recurring: iphone.updatedRules, deletions: [id.uuidString: date(2026, 11, 1, 13, 5)])
        let ipad = generateDue(rules: [rule], deletedIDs: [], existingIDs: [], now: date(2026, 11, 2), calendar: rome)
        let merged = SyncSnapshot.merge(local: SyncSnapshot(expenses: ipad.expenses, recurring: ipad.updatedRules),
                                        remote: deletedOnIPhone)
        #expect(merged.expenses.isEmpty)
    }

    @Test func regeneratedOccurrenceDoesNotUndoEdit() {
        let rule = RecurringExpense(amountCents: 52000, frequency: .monthly, startDate: date(2026, 11, 1), modifiedAt: date(2026, 10, 1))
        var edited = generateDue(rules: [rule], deletedIDs: [], existingIDs: [], now: date(2026, 11, 1, 13), calendar: rome).expenses[0]
        edited.amountCents = 50000
        edited.modifiedAt = date(2026, 11, 1, 13, 5)
        let ipad = generateDue(rules: [rule], deletedIDs: [], existingIDs: [], now: date(2026, 11, 2), calendar: rome)
        let merged = SyncSnapshot.merge(local: SyncSnapshot(expenses: ipad.expenses), remote: SyncSnapshot(expenses: [edited]))
        #expect(merged.expenses.map(\.amountCents) == [50000])
    }

    // I1: con l'orologio dell'altro dispositivo avanti, l'eliminazione vince comunque.
    @Test func deletionBeatsFutureModificationStamp() {
        let store = ExpenseStore(fileURL: tempURL(), calendar: rome, now: { date(2026, 11, 10, 12) })
        let fromIPad = Expense(amountCents: 900, date: date(2026, 11, 10), modifiedAt: date(2026, 11, 10, 12, 3))
        store.applySynced(SyncSnapshot(expenses: [fromIPad]))
        store.deleteExpense(id: fromIPad.id)
        let merged = SyncSnapshot.merge(local: store.snapshot(), remote: SyncSnapshot(expenses: [fromIPad]))
        #expect(merged.expenses.isEmpty)
    }

    // I2: eliminare un tag non riscrive le spese (che restano "Senza tag" tramite il tag mancante).
    @Test func deleteTagLeavesExpensesUntouched() {
        let store = ExpenseStore(fileURL: tempURL(), calendar: rome, now: { date(2026, 11, 10) })
        let tag = store.addTag(name: "Svago")
        store.addExpense(Expense(amountCents: 1000, date: date(2026, 11, 2), tagID: tag.id))
        let before = store.expenses
        store.deleteTag(id: tag.id)
        #expect(store.expenses == before)
        #expect(store.summary(for: MonthKey(year: 2026, month: 11)).slices.map(\.name) == ["Senza tag"])
    }

    // I4: dati in Documents e nel gruppo insieme vengono uniti, non persi.
    @Test func mergesDocumentsIntoExistingGroupFile() throws {
        let group = tempURL().deletingLastPathComponent().appendingPathComponent("group")
        let documents = tempURL().deletingLastPathComponent().appendingPathComponent("docs")
        for folder in [group, documents] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let groupStore = ExpenseStore(fileURL: group.appendingPathComponent("expenses.json"), calendar: rome)
        groupStore.addExpense(Expense(amountCents: 100, date: date(2026, 11, 1)))
        let documentsStore = ExpenseStore(fileURL: documents.appendingPathComponent("expenses.json"), calendar: rome)
        documentsStore.addExpense(Expense(amountCents: 200, date: date(2026, 11, 5)))

        let url = AppGroup.resolveDataFileURL(groupContainer: group, documents: documents)
        #expect(url == group.appendingPathComponent("expenses.json"))
        #expect(Set(ExpenseStore(fileURL: url, calendar: rome).expenses.map(\.amountCents)) == [100, 200])
        #expect(!FileManager.default.fileExists(atPath: documents.appendingPathComponent("expenses.json").path))
    }

    // Spese periodiche: date senza frazioni di secondo e a inizio giornata.
    @Test func recurringDatesAreNormalized() {
        let url = tempURL()
        let store = ExpenseStore(fileURL: url, calendar: rome, now: { date(2026, 11, 10, 15) })
        let start = date(2026, 11, 10, 15).addingTimeInterval(0.37)
        store.addRecurring(RecurringExpense(amountCents: 900, frequency: .monthly, startDate: start, endDate: date(2027, 1, 10, 8)))
        #expect(store.recurring[0].startDate == date(2026, 11, 10, 0))
        #expect(store.recurring[0].endDate == date(2027, 1, 11, 0).addingTimeInterval(-1))
        #expect(store.generateDueRecurring().count == 1)
        #expect(ExpenseStore(fileURL: url, calendar: rome).data == store.data)
    }
}
