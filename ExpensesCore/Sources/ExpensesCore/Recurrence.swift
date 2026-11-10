import Foundation

extension Frequency {
    fileprivate var component: (Calendar.Component, Int) {
        switch self {
        case .weekly: (.day, 7)
        case .monthly: (.month, 1)
        case .yearly: (.year, 1)
        }
    }
}

/// N-esima occorrenza, calcolata sempre dalla data di inizio: 31 gen → 28 feb → 31 mar, senza slittare.
func occurrence(_ n: Int, of rule: RecurringExpense, calendar: Calendar) -> Date {
    let (component, step) = rule.frequency.component
    return calendar.date(byAdding: component, value: n * step, to: rule.startDate)!
}

/// Date dovute e non ancora generate, fino a `now` incluso.
public func occurrenceDates(of rule: RecurringExpense, through now: Date, calendar: Calendar) -> [Date] {
    guard rule.isActive else { return [] }
    let limit = min(now, rule.endDate ?? now)
    var dates: [Date] = []
    var n = 0
    while true {
        let candidate = occurrence(n, of: rule, calendar: calendar)
        n += 1
        if candidate > limit { break }
        if let last = rule.lastGeneratedDate, candidate <= last { continue }
        if let paused = rule.pausedAt, let resumed = rule.resumedAt, paused <= candidate, candidate < resumed { continue }
        dates.append(candidate)
    }
    return dates
}

/// Id deterministico di un'occorrenza: iPhone e iPad generano la stessa spesa con lo stesso id,
/// che la sincronizzazione unisce. Byte dell'id della regola, ultimi 4 in XOR con il numero del giorno.
public func occurrenceID(recurringID: UUID, date: Date, calendar: Calendar) -> UUID {
    let reference = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1))!
    let days = calendar.dateComponents([.day], from: reference, to: calendar.startOfDay(for: date)).day ?? 0
    let dayBits = UInt32(truncatingIfNeeded: days) ^ 0xA5A5_A5A5
    var bytes = recurringID.uuid
    withUnsafeMutableBytes(of: &bytes) { raw in
        raw[12] ^= UInt8(truncatingIfNeeded: dayBits >> 24)
        raw[13] ^= UInt8(truncatingIfNeeded: dayBits >> 16)
        raw[14] ^= UInt8(truncatingIfNeeded: dayBits >> 8)
        raw[15] ^= UInt8(truncatingIfNeeded: dayBits)
        raw[6] = (raw[6] & 0x0F) | 0x80
    }
    return UUID(uuid: bytes)
}

/// Genera le spese periodiche dovute. `lastGeneratedDate` avanza anche sulle occorrenze già presenti
/// o eliminate, che non vengono ricreate. Il `modifiedAt` della regola non cambia, così non sovrascrive
/// in sync una modifica fatta dall'utente sull'altro dispositivo.
public func generateDue(rules: [RecurringExpense], deletedIDs: Set<UUID>, existingIDs: Set<UUID>,
                        now: Date, calendar: Calendar) -> (expenses: [Expense], updatedRules: [RecurringExpense]) {
    var expenses: [Expense] = []
    var updated: [RecurringExpense] = []
    for var rule in rules {
        let dates = occurrenceDates(of: rule, through: now, calendar: calendar)
        for date in dates {
            let id = occurrenceID(recurringID: rule.id, date: date, calendar: calendar)
            guard !deletedIDs.contains(id), !existingIDs.contains(id) else { continue }
            expenses.append(Expense(id: id, amountCents: rule.amountCents, date: date, tagID: rule.tagID,
                                    merchant: rule.merchant, note: rule.note, source: .recurring,
                                    recurringID: rule.id, modifiedAt: now.roundedToSecond))
        }
        if let last = dates.last { rule.lastGeneratedDate = last }
        updated.append(rule)
    }
    return (expenses, updated)
}
