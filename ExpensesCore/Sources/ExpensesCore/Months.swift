import Foundation

/// Un mese di calendario (anno e mese), indipendente dal fuso: le date si assegnano al mese
/// secondo il calendario passato, quello del dispositivo nell'app.
public struct MonthKey: Hashable, Comparable, Codable, Sendable, Identifiable {
    public var year: Int
    public var month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year!, month: parts.month!)
    }

    public var id: String { String(format: "%04d-%02d", year, month) }

    public func adding(months: Int) -> MonthKey {
        let index = year * 12 + (month - 1) + months
        return MonthKey(year: index / 12, month: index % 12 + 1)
    }

    public func range(calendar: Calendar) -> Range<Date> {
        start(calendar: calendar)..<adding(months: 1).start(calendar: calendar)
    }

    public func start(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    public func numberOfDays(calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: start(calendar: calendar))!.count
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
