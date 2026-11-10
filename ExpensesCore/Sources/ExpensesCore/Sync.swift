import Foundation

/// Elemento sincronizzato elemento per elemento: vince la versione modificata più di recente.
protocol SyncItem: Codable, Hashable, Identifiable where ID == UUID {
    var modifiedAt: Date? { get }
}

extension Expense: SyncItem {}
extension Tag: SyncItem {}
extension RecurringExpense: SyncItem {}

/// Contenuto del file `expenses-sync.json` condiviso tra dispositivi.
public struct SyncSnapshot: Codable, Equatable, Sendable {
    public static let fileName = "expenses-sync.json"

    public var version = 1
    public var expenses: [Expense]
    public var tags: [Tag]
    public var recurring: [RecurringExpense]
    public var settings: SyncedSettings
    public var deletions: [String: Date]
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
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        expenses = try c.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        tags = try c.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        recurring = try c.decodeIfPresent([RecurringExpense].self, forKey: .recurring) ?? []
        settings = try c.decodeIfPresent(SyncedSettings.self, forKey: .settings) ?? SyncedSettings()
        deletions = try c.decodeIfPresent([String: Date].self, forKey: .deletions) ?? [:]
        sentAlerts = try c.decodeIfPresent(Set<String>.self, forKey: .sentAlerts) ?? []
    }

    /// Stesso contenuto, a prescindere dall'ordine (che può differire tra dispositivi).
    public func hasSameContent(as other: SyncSnapshot) -> Bool {
        Set(expenses) == Set(other.expenses) && expenses.count == other.expenses.count
            && Set(tags) == Set(other.tags) && tags.count == other.tags.count
            && Set(recurring) == Set(other.recurring) && recurring.count == other.recurring.count
            && settings == other.settings && deletions == other.deletions && sentAlerts == other.sentAlerts
    }

    public func encoded() throws -> Data {
        try StoreCoding.encoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> SyncSnapshot {
        try StoreCoding.decoder().decode(SyncSnapshot.self, from: data)
    }

    /// Unisce elemento per elemento: vince la modifica più recente, un'eliminazione vince sulle modifiche
    /// precedenti, gli avvisi inviati si sommano. A parità di data decide il contenuto, così entrambi
    /// i dispositivi arrivano allo stesso risultato.
    public static func merge(local: SyncSnapshot, remote: SyncSnapshot) -> SyncSnapshot {
        var deletions = local.deletions
        for (id, deletedAt) in remote.deletions {
            deletions[id] = max(deletions[id] ?? deletedAt, deletedAt)
        }
        var recurring = mergeItems(local.recurring, remote.recurring, deletions: deletions)
        // lastGeneratedDate avanza senza cambiare modifiedAt: si tiene il più avanzato dei due.
        let generated = Dictionary((local.recurring + remote.recurring).compactMap { rule in
            rule.lastGeneratedDate.map { (rule.id, $0) }
        }, uniquingKeysWith: max)
        for index in recurring.indices {
            if let latest = generated[recurring[index].id] { recurring[index].lastGeneratedDate = latest }
        }
        return SyncSnapshot(
            expenses: mergeItems(local.expenses, remote.expenses, deletions: deletions),
            tags: mergeItems(local.tags, remote.tags, deletions: deletions),
            recurring: recurring,
            settings: newer(local.settings, remote.settings, date: \.modifiedAt),
            deletions: deletions,
            sentAlerts: local.sentAlerts.union(remote.sentAlerts))
    }

    static func mergeItems<T: SyncItem>(_ local: [T], _ remote: [T], deletions: [String: Date]) -> [T] {
        func survives(_ item: T) -> Bool {
            guard let deletedAt = deletions[item.id.uuidString] else { return true }
            return (item.modifiedAt ?? .distantPast) > deletedAt
        }
        let localItems = unique(local)
        let remoteItems = unique(remote)
        let remoteByID = Dictionary(remoteItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let localIDs = Set(localItems.map(\.id))
        var merged: [T] = []
        for item in localItems {
            let winner = remoteByID[item.id].map { newer(item, $0, date: \.modifiedAt) } ?? item
            if survives(winner) { merged.append(winner) }
        }
        for item in remoteItems where !localIDs.contains(item.id) && survives(item) {
            merged.append(item)
        }
        return merged
    }

    static func unique<T: SyncItem>(_ items: [T]) -> [T] {
        var seen = Set<UUID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    static func newer<T: Codable & Equatable>(_ a: T, _ b: T, date: KeyPath<T, Date?>) -> T {
        let dateA = a[keyPath: date] ?? .distantPast
        let dateB = b[keyPath: date] ?? .distantPast
        if dateA != dateB { return dateA > dateB ? a : b }
        if a == b { return a }
        let encoder = StoreCoding.encoder()
        let dataA = (try? encoder.encode(a)) ?? Data()
        let dataB = (try? encoder.encode(b)) ?? Data()
        return dataA.lexicographicallyPrecedes(dataB) ? b : a
    }
}

extension ExpenseStore {
    public func snapshot() -> SyncSnapshot {
        SyncSnapshot(expenses: data.expenses, tags: data.tags, recurring: data.recurring, settings: data.settings,
                     deletions: data.deletions, sentAlerts: data.sentAlerts)
    }

    /// Applica il risultato di un'unione; non salva se non cambia nulla.
    public func applySynced(_ snapshot: SyncSnapshot) {
        replaceData(StoredData(expenses: snapshot.expenses, tags: snapshot.tags, recurring: snapshot.recurring,
                               settings: snapshot.settings, deletions: snapshot.deletions, sentAlerts: snapshot.sentAlerts))
    }
}
