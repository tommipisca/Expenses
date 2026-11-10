import Foundation

/// Riepilogo del mese scritto dall'app nell'App Group e letto dal widget.
public struct WidgetSummary: Codable, Equatable, Sendable {
    public static let fileName = "widget-summary.json"
    /// Id della fetta "Altro", che raccoglie i tag oltre i primi quattro.
    public static let otherID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    public static let maxSlices = 5

    public var month: MonthKey
    public var totalCents: Int
    public var slices: [TagSlice]
    public var monthlyBudget: BudgetStatus?
    public var generatedAt: Date

    public init(month: MonthKey, totalCents: Int, slices: [TagSlice], monthlyBudget: BudgetStatus?, generatedAt: Date) {
        self.month = month
        self.totalCents = totalCents
        self.slices = slices
        self.monthlyBudget = monthlyBudget
        self.generatedAt = generatedAt
    }

    public static func make(summary: MonthSummary, statuses: [BudgetStatus], generatedAt: Date) -> WidgetSummary {
        var slices = summary.slices
        if slices.count > maxSlices {
            let rest = slices[(maxSlices - 1)...]
            let cents = rest.reduce(0) { $0 + $1.cents }
            slices = Array(slices.prefix(maxSlices - 1))
            slices.append(TagSlice(id: otherID, name: "Altro", colorIndex: nil, cents: cents,
                                   fraction: rest.reduce(0) { $0 + $1.fraction }))
        }
        return WidgetSummary(month: summary.month, totalCents: summary.totalCents, slices: slices,
                             monthlyBudget: statuses.first { $0.target == .total }, generatedAt: generatedAt)
    }

    public static func read(from url: URL) -> WidgetSummary? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? StoreCoding.decoder().decode(WidgetSummary.self, from: data)
    }
}
