import Foundation

/// Quanto si è speso in ciascun giorno di un mese, per la striscia "giorno per giorno".
public struct DailySpending: Equatable, Sendable {
    /// Centesimi per giorno: indice 0 = giorno 1, tanti quanti i giorni del mese.
    public var cents: [Int]
    /// Giorno di oggi (1...) se il mese è quello in corso, altrimenti nil.
    public var today: Int?

    public var maxCents: Int { cents.max() ?? 0 }

    /// Il giorno con la spesa più alta (1...), nil se il mese è vuoto.
    public var busiestDay: Int? {
        guard let max = cents.max(), max > 0 else { return nil }
        return cents.firstIndex(of: max).map { $0 + 1 }
    }

    public static func make(expenses: [Expense], month: MonthKey, now: Date, calendar: Calendar) -> DailySpending {
        let range = month.range(calendar: calendar)
        var cents = [Int](repeating: 0, count: month.numberOfDays(calendar: calendar))
        for expense in expenses where range.contains(expense.date) {
            let day = calendar.component(.day, from: expense.date)
            if cents.indices.contains(day - 1) { cents[day - 1] += expense.amountCents }
        }
        let today = MonthKey(date: now, calendar: calendar) == month ? calendar.component(.day, from: now) : nil
        return DailySpending(cents: cents, today: today)
    }
}

public extension Array where Element == Expense {
    /// Le spese più recenti di un mese, dalla più nuova; a parità di data, l'ultima modificata.
    func recent(in month: MonthKey, limit: Int, calendar: Calendar) -> [Expense] {
        let range = month.range(calendar: calendar)
        return filter { range.contains($0.date) }
            .sorted { ($0.date, $0.modifiedAt ?? .distantPast) > ($1.date, $1.modifiedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
}
