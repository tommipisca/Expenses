import Foundation

/// Riepilogo del mese scritto dall'app nell'App Group e letto dal widget.
public struct WidgetSummary: Codable, Equatable, Sendable {
    public static let fileName = "widget-summary.json"
    public var month: MonthKey
    public var totalCents: Int
    public var slices: [TagSlice]
    public var monthlyBudget: BudgetStatus?
    public var generatedAt: Date
    /// Campi per i widget grandi, aggiunti dopo: facoltativi nella decodifica.
    public var count: Int
    public var comparison: Comparison?
    public var tagBudgets: [TagBudgetLine]
    /// Ultime spese del mese, dalla più recente.
    public var recent: [RecentExpense]

    public static let recentLimit = 5

    public struct TagBudgetLine: Codable, Equatable, Sendable {
        public var name: String
        public var colorIndex: Int?
        public var status: BudgetStatus
    }

    public struct RecentExpense: Codable, Equatable, Sendable {
        public var title: String
        public var colorIndex: Int?
        public var cents: Int
        public var date: Date
    }

    public init(month: MonthKey, totalCents: Int, slices: [TagSlice], monthlyBudget: BudgetStatus?, generatedAt: Date,
                count: Int = 0, comparison: Comparison? = nil, tagBudgets: [TagBudgetLine] = [], recent: [RecentExpense] = []) {
        self.month = month
        self.totalCents = totalCents
        self.slices = slices
        self.monthlyBudget = monthlyBudget
        self.generatedAt = generatedAt
        self.count = count
        self.comparison = comparison
        self.tagBudgets = tagBudgets
        self.recent = recent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decode(MonthKey.self, forKey: .month)
        totalCents = try c.decode(Int.self, forKey: .totalCents)
        slices = try c.decodeIfPresent([TagSlice].self, forKey: .slices) ?? []
        monthlyBudget = try c.decodeIfPresent(BudgetStatus.self, forKey: .monthlyBudget)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        comparison = try c.decodeIfPresent(Comparison.self, forKey: .comparison)
        tagBudgets = try c.decodeIfPresent([TagBudgetLine].self, forKey: .tagBudgets) ?? []
        recent = try c.decodeIfPresent([RecentExpense].self, forKey: .recent) ?? []
    }

    public static func make(summary: MonthSummary, statuses: [BudgetStatus], tags: [Tag] = [],
                            expenses: [Expense] = [], calendar: Calendar = .current, generatedAt: Date) -> WidgetSummary {
        // Tutti i tag, ciascuno col suo colore: l'anello li disegna tutti, gli elenchi mostrano quelli che ci stanno.
        let slices = summary.slices
        let tagsByID = Dictionary(tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let tagBudgets = statuses.compactMap { status -> TagBudgetLine? in
            guard case .tag(let id) = status.target, let tag = tagsByID[id] else { return nil }
            return TagBudgetLine(name: tag.name, colorIndex: tag.colorIndex, status: status)
        }
        let range = summary.month.range(calendar: calendar)
        let recent = expenses.filter { range.contains($0.date) }
            .sorted { $0.date > $1.date }
            .prefix(recentLimit)
            .map { expense in
                let tag = expense.tagID.flatMap { tagsByID[$0] }
                return RecentExpense(title: expense.merchant ?? expense.note ?? tag?.name ?? "Spesa",
                                     colorIndex: tag?.colorIndex, cents: expense.amountCents, date: expense.date)
            }
        return WidgetSummary(month: summary.month, totalCents: summary.totalCents, slices: slices,
                             monthlyBudget: statuses.first { $0.target == .total }, generatedAt: generatedAt,
                             count: summary.count, comparison: summary.comparison, tagBudgets: tagBudgets, recent: Array(recent))
    }

    public static func read(from url: URL) -> WidgetSummary? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? StoreCoding.decoder().decode(WidgetSummary.self, from: data)
    }
}

extension WidgetSummary {
    /// Il riepilogo da mostrare a una certa data: se nel frattempo è iniziato un nuovo mese
    /// (e l'app non è stata aperta), il mese nuovo parte da zero con lo stesso budget.
    public func displayed(at date: Date, calendar: Calendar) -> WidgetSummary {
        let month = MonthKey(date: date, calendar: calendar)
        guard month != self.month else { return self }
        let budget = monthlyBudget.map { BudgetStatus(target: $0.target, limitCents: $0.limitCents, spentCents: 0) }
        let tagBudgets = tagBudgets.map { line in
            TagBudgetLine(name: line.name, colorIndex: line.colorIndex,
                          status: BudgetStatus(target: line.status.target, limitCents: line.status.limitCents, spentCents: 0))
        }
        return WidgetSummary(month: month, totalCents: 0, slices: [], monthlyBudget: budget, generatedAt: generatedAt,
                             tagBudgets: tagBudgets)
    }

    public static func startOfNextMonth(after date: Date, calendar: Calendar) -> Date {
        MonthKey(date: date, calendar: calendar).adding(months: 1).start(calendar: calendar)
    }
}
