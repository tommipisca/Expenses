import Foundation
import Observation

public enum StoreError: Error, Equatable, Sendable {
    case corruptedData
    case saveFailed
    case readFailed

    public var message: String {
        switch self {
        case .corruptedData:
            "I dati salvati erano illeggibili: sono stati messi da parte in un file \"expenses.corrupt\" e l'app è ripartita da zero."
        case .saveFailed:
            "Impossibile salvare le modifiche."
        case .readFailed:
            "Impossibile leggere i dati salvati. Per non sovrascriverli, le modifiche non verranno salvate: chiudi e riapri l'app."
        }
    }
}

/// Tutto ciò che l'app salva, in un unico file JSON (eliminazioni comprese, così restano coerenti con i dati).
public struct StoredData: Codable, Equatable, Sendable {
    public var expenses: [Expense]
    public var tags: [Tag]
    public var recurring: [RecurringExpense]
    public var settings: SyncedSettings
    /// Id eliminati (spese, tag, spese periodiche) → data dell'eliminazione.
    public var deletions: [String: Date]
    /// Avvisi di budget già inviati (`AlertKey.id`), condivisi tra i dispositivi.
    public var sentAlerts: Set<String>

    public init(expenses: [Expense] = [], tags: [Tag] = [], recurring: [RecurringExpense] = [],
                settings: SyncedSettings = SyncedSettings(), deletions: [String: Date] = [:], sentAlerts: Set<String> = []) {
        self.expenses = expenses
        self.tags = tags
        self.recurring = recurring
        self.settings = settings
        self.deletions = deletions
        self.sentAlerts = sentAlerts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        expenses = try c.decode([Expense].self, forKey: .expenses)
        tags = try c.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        recurring = try c.decodeIfPresent([RecurringExpense].self, forKey: .recurring) ?? []
        settings = try c.decodeIfPresent(SyncedSettings.self, forKey: .settings) ?? SyncedSettings()
        deletions = try c.decodeIfPresent([String: Date].self, forKey: .deletions) ?? [:]
        sentAlerts = try c.decodeIfPresent(Set<String>.self, forKey: .sentAlerts) ?? []
    }
}

enum StoreCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
@Observable
public final class ExpenseStore {
    public private(set) var data = StoredData()
    public var lastError: StoreError?
    /// Chiamato dopo ogni salvataggio riuscito (sync, avvisi, widget).
    @ObservationIgnored public var onChange: (() -> Void)?

    public var expenses: [Expense] { data.expenses }
    public var tags: [Tag] { data.tags }
    public var recurring: [RecurringExpense] { data.recurring }
    public var settings: SyncedSettings { data.settings }

    private let fileURL: URL
    private let calendar: Calendar
    private let now: () -> Date
    /// Vero se il file esiste ma non si legge (es. protetto prima del primo sblocco): non si salva per non sovrascriverlo.
    private var isReadBlocked = false

    public init(fileURL: URL, calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.now = now
        load()
    }

    // MARK: Lettura

    public func tag(id: UUID?) -> Tag? {
        guard let id else { return nil }
        return data.tags.first { $0.id == id }
    }

    public func summary(for month: MonthKey) -> MonthSummary {
        MonthSummary.make(expenses: data.expenses, tags: data.tags, month: month, now: now(), calendar: calendar)
    }

    public func budgetStatuses(for month: MonthKey) -> [BudgetStatus] {
        ExpensesCore.budgetStatuses(summary: summary(for: month), tags: data.tags, settings: data.settings)
    }

    public var currentMonth: MonthKey { MonthKey(date: now(), calendar: calendar) }

    /// Tag dell'ultima spesa con lo stesso esercente (senza distinguere maiuscole e spazi), se il tag esiste ancora.
    public func suggestedTagID(forMerchant merchant: String) -> UUID? {
        let wanted = normalizedMerchant(merchant)
        guard !wanted.isEmpty else { return nil }
        let latest = data.expenses
            .filter { $0.merchant.map(normalizedMerchant) == wanted }
            .max { $0.date < $1.date }
        return tag(id: latest?.tagID)?.id
    }

    // MARK: Spese

    public func addExpense(_ expense: Expense) {
        var expense = expense
        expense.date = expense.date.roundedToSecond
        expense.modifiedAt = stamp(after: nil)
        data.expenses.append(expense)
        save()
    }

    /// Spese arrivate da Wallet e non ancora controllate, dalla più recente.
    public var pendingReview: [Expense] {
        data.expenses.filter(\.needsReview).sorted { $0.date > $1.date }
    }

    /// Salva una spesa da Wallet senza passare dal modulo. Un importo non in euro resta a 0 e finisce nella nota;
    /// il tag è quello usato l'ultima volta con lo stesso esercente.
    @discardableResult
    public func addPendingExpense(amountText: String?, merchant: String?, date: Date) -> Expense {
        let rawAmount = amountText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var cents = 0
        var note: String?
        if !rawAmount.isEmpty {
            if case .euros(let value) = readAmount(rawAmount) { cents = value } else { note = "Importo da Wallet: \(rawAmount)" }
        }
        let expense = Expense(amountCents: cents, date: date, tagID: name.isEmpty ? nil : suggestedTagID(forMerchant: name),
                              merchant: name.isEmpty ? nil : name, note: note, source: .wallet, needsReview: true)
        addExpense(expense)
        return data.expenses.last ?? expense
    }

    /// Salva le modifiche e toglie la spesa da quelle da confermare.
    public func confirmExpense(_ expense: Expense) {
        var expense = expense
        expense.needsReview = false
        updateExpense(expense)
    }

    public func updateExpense(_ expense: Expense) {
        guard let index = data.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        var expense = expense
        expense.date = expense.date.roundedToSecond
        expense.modifiedAt = stamp(after: data.expenses[index].modifiedAt)
        data.expenses[index] = expense
        save()
    }

    public func deleteExpense(id: UUID) {
        let previous = data.expenses.first { $0.id == id }?.modifiedAt
        data.expenses.removeAll { $0.id == id }
        data.deletions[id.uuidString] = stamp(after: previous)
        save()
    }

    // MARK: Tag

    @discardableResult
    public func addTag(name: String) -> Tag {
        let tag = Tag(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                      colorIndex: Palette.balancedColorIndex(used: data.tags.map(\.colorIndex)),
                      modifiedAt: stamp(after: nil))
        data.tags.append(tag)
        save()
        return tag
    }

    public func updateTag(_ tag: Tag) {
        guard let index = data.tags.firstIndex(where: { $0.id == tag.id }) else { return }
        var tag = tag
        tag.modifiedAt = stamp(after: data.tags[index].modifiedAt)
        data.tags[index] = tag
        save()
    }

    public func setTagBudget(id: UUID, cents: Int?) {
        guard var tag = tag(id: id) else { return }
        tag.budgetCents = cents
        updateTag(tag)
    }

    /// Elimina il tag. Le spese e le spese periodiche non vengono riscritte (una modifica fatta intanto
    /// su un altro dispositivo non andrebbe persa): un tag che non esiste più vale ovunque "Senza tag".
    public func deleteTag(id: UUID) {
        let previous = tag(id: id)?.modifiedAt
        data.tags.removeAll { $0.id == id }
        data.deletions[id.uuidString] = stamp(after: previous)
        save()
    }

    // MARK: Spese periodiche

    public func addRecurring(_ rule: RecurringExpense) {
        var rule = normalized(rule)
        rule.modifiedAt = stamp(after: nil)
        data.recurring.append(rule)
        save()
    }

    public func updateRecurring(_ rule: RecurringExpense) {
        guard let index = data.recurring.firstIndex(where: { $0.id == rule.id }) else { return }
        var rule = normalized(rule)
        rule.modifiedAt = stamp(after: data.recurring[index].modifiedAt)
        data.recurring[index] = rule
        save()
    }

    public func setRecurringActive(id: UUID, active: Bool) {
        guard var rule = data.recurring.first(where: { $0.id == id }), rule.isActive != active else { return }
        rule.isActive = active
        if active { rule.resumedAt = timestamp() } else { rule.pausedAt = timestamp() }
        updateRecurring(rule)
    }

    public func deleteRecurring(id: UUID) {
        let previous = data.recurring.first { $0.id == id }?.modifiedAt
        data.recurring.removeAll { $0.id == id }
        data.deletions[id.uuidString] = stamp(after: previous)
        save()
    }

    /// Crea le spese periodiche dovute fino ad adesso; restituisce quelle nuove.
    @discardableResult
    public func generateDueRecurring() -> [Expense] {
        let deleted = Set(data.deletions.keys.compactMap(UUID.init(uuidString:)))
        let result = ExpensesCore.generateDue(rules: data.recurring, deletedIDs: deleted,
                                              existingIDs: Set(data.expenses.map(\.id)), now: now(), calendar: calendar)
        guard !result.expenses.isEmpty || result.updatedRules != data.recurring else { return [] }
        data.expenses.append(contentsOf: result.expenses)
        data.recurring = result.updatedRules
        save()
        return result.expenses
    }

    // MARK: Budget e avvisi

    public func setMonthlyBudget(cents: Int?) {
        data.settings.monthlyBudgetCents = cents
        data.settings.modifiedAt = stamp(after: data.settings.modifiedAt)
        save()
    }

    public func markAlertsSent(_ keys: [AlertKey]) {
        guard !keys.isEmpty else { return }
        data.sentAlerts.formUnion(keys.map(\.id))
        save()
    }

    // MARK: Widget

    public func writeWidgetSummary(to url: URL) {
        let month = currentMonth
        let summary = WidgetSummary.make(summary: summary(for: month), statuses: budgetStatuses(for: month),
                                         tags: data.tags, expenses: data.expenses, calendar: calendar,
                                         generatedAt: timestamp())
        do {
            try StoreCoding.encoder().encode(summary).write(to: url, options: .atomic)
        } catch {
            NSLog("Expenses: scrittura del riepilogo per il widget fallita (%@)", String(describing: error))
        }
    }

    // MARK: Persistenza

    /// Sostituisce tutti i dati (usato dalla sincronizzazione); non salva se non cambia nulla.
    func replaceData(_ newData: StoredData) {
        guard newData != data else { return }
        data = newData
        save()
    }

    private func timestamp() -> Date {
        Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
    }

    /// Data di modifica sempre successiva alla precedente: una modifica fatta qui vince
    /// anche se l'orologio dell'altro dispositivo era avanti.
    private func stamp(after previous: Date?) -> Date {
        max(timestamp(), (previous ?? .distantPast).addingTimeInterval(1))
    }

    /// Spese periodiche a inizio giornata (dovute dalla mezzanotte), fine fino all'ultimo secondo del giorno.
    private func normalized(_ rule: RecurringExpense) -> RecurringExpense {
        var rule = rule
        rule.startDate = calendar.startOfDay(for: rule.startDate)
        if let end = rule.endDate {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
            rule.endDate = nextDay.addingTimeInterval(-1)
        }
        return rule
    }

    private func normalizedMerchant(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func load() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let raw: Data
        do {
            raw = try Data(contentsOf: fileURL)
        } catch {
            NSLog("Expenses: lettura dei dati fallita (%@)", String(describing: error))
            isReadBlocked = true
            lastError = .readFailed
            return
        }
        do {
            data = try StoreCoding.decoder().decode(StoredData.self, from: raw)
        } catch {
            let stamp = Int(now().timeIntervalSince1970)
            let corruptURL = fileURL.deletingLastPathComponent().appendingPathComponent("expenses.corrupt-\(stamp).json")
            try? fileManager.moveItem(at: fileURL, to: corruptURL)
            NSLog("Expenses: dati illeggibili spostati in %@ (%@)", corruptURL.lastPathComponent, String(describing: error))
            lastError = .corruptedData
        }
    }

    private func save() {
        guard !isReadBlocked else {
            lastError = .readFailed
            return
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try StoreCoding.encoder().encode(data).write(to: fileURL, options: .atomic)
            onChange?()
        } catch {
            NSLog("Expenses: salvataggio fallito (%@)", String(describing: error))
            lastError = .saveFailed
        }
    }
}
