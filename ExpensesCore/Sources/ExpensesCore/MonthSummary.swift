import Foundation

/// Una fetta dell'anello: un tag, o "Senza tag" (`id == nil`) per le spese senza tag o con un tag eliminato.
public struct TagSlice: Identifiable, Hashable, Codable, Sendable {
    public static let untaggedName = "Senza tag"

    public var id: UUID?
    public var name: String
    public var colorIndex: Int?
    public var cents: Int
    public var fraction: Double

    public init(id: UUID?, name: String, colorIndex: Int?, cents: Int, fraction: Double) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.cents = cents
        self.fraction = fraction
    }
}

public struct Comparison: Hashable, Sendable {
    public var previousMonth: MonthKey
    public var previousCents: Int
    public var percentChange: Int
    /// true se il mese precedente è considerato solo fino allo stesso giorno (mese in corso).
    public var sameDay: Bool
}

public struct MonthSummary: Sendable {
    public var month: MonthKey
    public var totalCents: Int
    public var count: Int
    public var slices: [TagSlice]
    public var comparison: Comparison?

    public static func make(expenses: [Expense], tags: [Tag], month: MonthKey, now: Date, calendar: Calendar) -> MonthSummary {
        let range = month.range(calendar: calendar)
        let inMonth = expenses.filter { range.contains($0.date) }
        let total = inMonth.reduce(0) { $0 + $1.amountCents }

        let tagsByID = Dictionary(tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var centsByTag: [UUID?: Int] = [:]
        for expense in inMonth {
            let key = expense.tagID.flatMap { tagsByID[$0] == nil ? nil : $0 }
            centsByTag[key, default: 0] += expense.amountCents
        }
        let slices = centsByTag.map { key, cents in
            let tag = key.flatMap { tagsByID[$0] }
            return TagSlice(id: key, name: tag?.name ?? TagSlice.untaggedName, colorIndex: tag?.colorIndex,
                            cents: cents, fraction: total > 0 ? Double(cents) / Double(total) : 0)
        }
        .sorted { ($0.cents, $1.name) > ($1.cents, $0.name) }

        return MonthSummary(month: month, totalCents: total, count: inMonth.count, slices: slices,
                            comparison: comparison(expenses: expenses, month: month, total: total, now: now, calendar: calendar))
    }

    private static func comparison(expenses: [Expense], month: MonthKey, total: Int, now: Date, calendar: Calendar) -> Comparison? {
        let previous = month.adding(months: -1)
        var range = previous.range(calendar: calendar)
        let sameDay = MonthKey(date: now, calendar: calendar) == month
        if sameDay {
            let day = min(calendar.component(.day, from: now), previous.numberOfDays(calendar: calendar))
            let startOfDay = calendar.date(byAdding: .day, value: day - 1, to: range.lowerBound)!
            range = range.lowerBound..<calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        }
        let previousCents = expenses.filter { range.contains($0.date) }.reduce(0) { $0 + $1.amountCents }
        guard previousCents > 0 else { return nil }
        let change = (Double(total - previousCents) / Double(previousCents) * 100).rounded()
        return Comparison(previousMonth: previous, previousCents: previousCents, percentChange: Int(change), sameDay: sameDay)
    }
}
