import Foundation

public enum YearFilter: Hashable, Sendable {
    case all
    case year(Int)
}

public struct HistoryQuery: Hashable, Sendable {
    public var text: String
    /// Vuoto = tutti i tag; `nil` nell'insieme = "Senza tag" (anche tag eliminati).
    public var tagIDs: Set<UUID?>
    public var year: YearFilter
    /// Limita a un mese (aperto dalla schermata Mese toccando un tag).
    public var month: MonthKey?

    public init(text: String = "", tagIDs: Set<UUID?> = [], year: YearFilter = .all, month: MonthKey? = nil) {
        self.text = text
        self.tagIDs = tagIDs
        self.year = year
        self.month = month
    }
}

public struct HistoryMonth: Identifiable, Sendable {
    public var id: MonthKey
    public var totalCents: Int
    public var expenses: [Expense]
}

public struct HistoryResult: Sendable {
    public var months: [HistoryMonth]
    public var count: Int
    public var totalCents: Int
}

public func history(expenses: [Expense], tags: [Tag], query: HistoryQuery, calendar: Calendar) -> HistoryResult {
    let tagsByID = Dictionary(tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let needle = normalizedForSearch(query.text.trimmingCharacters(in: .whitespaces))
    let searchedCents: Int? = if case .euros(let cents) = readAmount(query.text) { cents } else { nil }

    let matching = expenses.filter { expense in
        let tag = expense.tagID.flatMap { tagsByID[$0] }
        if !query.tagIDs.isEmpty, !query.tagIDs.contains(tag?.id) { return false }
        let month = MonthKey(date: expense.date, calendar: calendar)
        if case .year(let year) = query.year, month.year != year { return false }
        if let wanted = query.month, month != wanted { return false }
        guard !needle.isEmpty else { return true }
        if expense.amountCents == searchedCents { return true }
        return [expense.merchant, expense.note, tag?.name].contains { field in
            field.map { normalizedForSearch($0).contains(needle) } ?? false
        }
    }

    let grouped = Dictionary(grouping: matching) { MonthKey(date: $0.date, calendar: calendar) }
    let months = grouped.map { key, items in
        HistoryMonth(id: key, totalCents: items.reduce(0) { $0 + $1.amountCents },
                     expenses: items.sorted { $0.date > $1.date })
    }
    .sorted { $0.id > $1.id }
    return HistoryResult(months: months, count: matching.count, totalCents: matching.reduce(0) { $0 + $1.amountCents })
}

public func availableYears(expenses: [Expense], calendar: Calendar) -> [Int] {
    Set(expenses.map { calendar.component(.year, from: $0.date) }).sorted(by: >)
}

func normalizedForSearch(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
}

/// Mesi con almeno una spesa (nell'anno scelto), dal più recente: le voci del menu "Mese" dello storico.
public func availableMonths(expenses: [Expense], year: YearFilter, calendar: Calendar) -> [MonthKey] {
    let months = Set(expenses.map { MonthKey(date: $0.date, calendar: calendar) })
    return months.filter { month in
        if case .year(let wanted) = year { month.year == wanted } else { true }
    }
    .sorted(by: >)
}
