import Foundation

public enum ExpenseSource: String, Codable, Sendable {
    case manual, wallet, recurring
}

public struct Expense: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var amountCents: Int
    public var date: Date
    public var tagID: UUID?
    public var merchant: String?
    public var note: String?
    public var source: ExpenseSource
    public var recurringID: UUID?
    public var modifiedAt: Date?
    /// Salvata dall'automazione di Wallet senza aprire l'app: compare tra le spese da confermare.
    public var needsReview: Bool

    public init(id: UUID = UUID(), amountCents: Int, date: Date, tagID: UUID? = nil, merchant: String? = nil,
                note: String? = nil, source: ExpenseSource = .manual, recurringID: UUID? = nil, modifiedAt: Date? = nil,
                needsReview: Bool = false) {
        self.id = id
        self.amountCents = amountCents
        self.date = date
        self.tagID = tagID
        self.merchant = merchant
        self.note = note
        self.source = source
        self.recurringID = recurringID
        self.modifiedAt = modifiedAt
        self.needsReview = needsReview
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amountCents = try c.decode(Int.self, forKey: .amountCents)
        date = try c.decode(Date.self, forKey: .date)
        tagID = try c.decodeIfPresent(UUID.self, forKey: .tagID)
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        source = try c.decodeIfPresent(ExpenseSource.self, forKey: .source) ?? .manual
        recurringID = try c.decodeIfPresent(UUID.self, forKey: .recurringID)
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt)
        needsReview = try c.decodeIfPresent(Bool.self, forKey: .needsReview) ?? false
    }
}

public struct Tag: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorIndex: Int
    /// Budget mensile del tag; nil = nessun budget.
    public var budgetCents: Int?
    public var modifiedAt: Date?

    public init(id: UUID = UUID(), name: String, colorIndex: Int = 0, budgetCents: Int? = nil, modifiedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.budgetCents = budgetCents
        self.modifiedAt = modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        budgetCents = try c.decodeIfPresent(Int.self, forKey: .budgetCents)
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt)
    }
}

public enum Frequency: String, Codable, Sendable, CaseIterable {
    case weekly, monthly, yearly
}

public struct RecurringExpense: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var amountCents: Int
    public var tagID: UUID?
    public var merchant: String?
    public var note: String?
    public var frequency: Frequency
    public var startDate: Date
    public var endDate: Date?
    public var lastGeneratedDate: Date?
    public var isActive: Bool
    public var pausedAt: Date?
    public var resumedAt: Date?
    public var modifiedAt: Date?

    public init(id: UUID = UUID(), amountCents: Int, tagID: UUID? = nil, merchant: String? = nil, note: String? = nil,
                frequency: Frequency, startDate: Date, endDate: Date? = nil, lastGeneratedDate: Date? = nil,
                isActive: Bool = true, pausedAt: Date? = nil, resumedAt: Date? = nil, modifiedAt: Date? = nil) {
        self.id = id
        self.amountCents = amountCents
        self.tagID = tagID
        self.merchant = merchant
        self.note = note
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.lastGeneratedDate = lastGeneratedDate
        self.isActive = isActive
        self.pausedAt = pausedAt
        self.resumedAt = resumedAt
        self.modifiedAt = modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amountCents = try c.decode(Int.self, forKey: .amountCents)
        tagID = try c.decodeIfPresent(UUID.self, forKey: .tagID)
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        frequency = try c.decode(Frequency.self, forKey: .frequency)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        lastGeneratedDate = try c.decodeIfPresent(Date.self, forKey: .lastGeneratedDate)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        pausedAt = try c.decodeIfPresent(Date.self, forKey: .pausedAt)
        resumedAt = try c.decodeIfPresent(Date.self, forKey: .resumedAt)
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt)
    }
}

/// Impostazioni che viaggiano con la sincronizzazione.
public struct SyncedSettings: Codable, Hashable, Sendable {
    /// Budget mensile totale; nil = nessun budget.
    public var monthlyBudgetCents: Int?
    public var modifiedAt: Date?

    public init(monthlyBudgetCents: Int? = nil, modifiedAt: Date? = nil) {
        self.monthlyBudgetCents = monthlyBudgetCents
        self.modifiedAt = modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        monthlyBudgetCents = try c.decodeIfPresent(Int.self, forKey: .monthlyBudgetCents)
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt)
    }
}

extension Date {
    /// Timestamp arrotondato al secondo, come nei file di sync di ExamsTrack.
    public var roundedToSecond: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded())
    }
}
