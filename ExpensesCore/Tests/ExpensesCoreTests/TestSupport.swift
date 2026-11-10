import Foundation

let rome: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
    calendar.locale = Locale(identifier: "it_IT")
    return calendar
}()

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    rome.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@testable import ExpensesCore
/// `Tag` esiste anche in Swift Testing: nei test indica sempre il modello dell'app.
typealias Tag = ExpensesCore.Tag
