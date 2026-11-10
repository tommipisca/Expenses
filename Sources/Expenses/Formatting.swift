import Foundation
import ExpensesCore

enum Formatting {
    static let italian = Locale(identifier: "it_IT")

    private static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italian
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let monthOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italian
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = italian
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    /// "Novembre 2026"
    static func monthTitle(_ month: MonthKey) -> String {
        monthYear.string(from: month.start(calendar: .current)).capitalized(with: italian)
    }

    /// "novembre"
    static func monthName(_ month: MonthKey) -> String {
        monthOnly.string(from: month.start(calendar: .current))
    }

    /// "9 nov"
    static func shortDate(_ date: Date) -> String {
        dayMonth.string(from: date)
    }

    /// Testo modificabile di un importo: 1250 → "12,50".
    static func editableAmount(_ cents: Int) -> String {
        String(Money.format(cents).dropFirst(2)).replacingOccurrences(of: ".", with: "")
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// "−8% vs ottobre allo stesso giorno"
    static func comparison(_ comparison: Comparison) -> String {
        let sign = comparison.percentChange > 0 ? "+" : comparison.percentChange < 0 ? "−" : "±"
        let suffix = comparison.sameDay ? " allo stesso giorno" : ""
        return "\(sign)\(abs(comparison.percentChange))% vs \(monthName(comparison.previousMonth))\(suffix)"
    }
}
