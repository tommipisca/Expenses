import Foundation

public enum BudgetTarget: Hashable, Codable, Sendable {
    case total
    case tag(UUID)

    public var key: String {
        switch self {
        case .total: "total"
        case .tag(let id): "tag:\(id.uuidString)"
        }
    }
}

public struct BudgetStatus: Hashable, Codable, Sendable {
    public var target: BudgetTarget
    public var limitCents: Int
    public var spentCents: Int

    public init(target: BudgetTarget, limitCents: Int, spentCents: Int) {
        self.target = target
        self.limitCents = limitCents
        self.spentCents = spentCents
    }

    public var remainingCents: Int { limitCents - spentCents }
    public var fraction: Double { limitCents > 0 ? Double(spentCents) / Double(limitCents) : 0 }
}

/// Stato dei soli budget impostati (tutti facoltativi): prima il totale, poi i tag nell'ordine dato.
public func budgetStatuses(summary: MonthSummary, tags: [Tag], settings: SyncedSettings) -> [BudgetStatus] {
    var statuses: [BudgetStatus] = []
    if let limit = settings.monthlyBudgetCents, limit > 0 {
        statuses.append(BudgetStatus(target: .total, limitCents: limit, spentCents: summary.totalCents))
    }
    for tag in tags {
        guard let limit = tag.budgetCents, limit > 0 else { continue }
        let spent = summary.slices.first { $0.id == tag.id }?.cents ?? 0
        statuses.append(BudgetStatus(target: .tag(tag.id), limitCents: limit, spentCents: spent))
    }
    return statuses
}

public enum AlertThreshold: Int, Codable, Sendable, CaseIterable {
    case eighty = 80
    case hundred = 100
}

public struct AlertKey: Hashable, Codable, Sendable {
    public var target: BudgetTarget
    public var month: MonthKey
    public var threshold: AlertThreshold

    public init(target: BudgetTarget, month: MonthKey, threshold: AlertThreshold) {
        self.target = target
        self.month = month
        self.threshold = threshold
    }

    public var id: String { "\(target.key)|\(month.id)|\(threshold.rawValue)" }
}

/// Avvisi da inviare: per ogni budget la soglia più alta raggiunta, se non è già stata inviata.
/// Superare il 100% senza aver ricevuto l'80% invia solo l'avviso del 100%.
public func pendingAlerts(statuses: [BudgetStatus], month: MonthKey, alreadySent: Set<String>) -> [AlertKey] {
    statuses.compactMap { status in
        let reached = AlertThreshold.allCases.last { status.spentCents * 100 >= status.limitCents * $0.rawValue }
        guard let reached else { return nil }
        let key = AlertKey(target: status.target, month: month, threshold: reached)
        return alreadySent.contains(key.id) ? nil : key
    }
}
