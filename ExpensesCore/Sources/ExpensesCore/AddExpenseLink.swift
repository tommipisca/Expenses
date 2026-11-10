import Foundation

public enum AmountReading: Equatable, Sendable {
    case euros(cents: Int)
    case foreign(currency: String)
    case refund
    case unreadable
}

private let currencySymbols: [Character: String] = ["$": "USD", "£": "GBP", "¥": "JPY"]
private let minusSigns: Set<Character> = ["-", "−", "–"]

/// Legge un importo come arriva da Comandi Rapidi ("€12,50", "1.234,56", "12.50 €").
/// Non indovina mai: separatore seguito da 3 cifre ("1.234") è ambiguo e risulta `.unreadable`.
public func readAmount(_ text: String) -> AmountReading {
    var s = String(text.filter { !$0.isWhitespace })
    guard s.contains(where: \.isNumber) else { return .unreadable }

    // Valuta: "€" ed "EUR" sono euro; un altro simbolo o codice di 3 lettere è valuta estera.
    if let range = s.range(of: "EUR", options: .caseInsensitive) { s.removeSubrange(range) }
    s.removeAll { $0 == "€" }
    let letters = s.filter(\.isLetter)
    if !letters.isEmpty {
        return letters.count == 3 ? .foreign(currency: letters.uppercased()) : .unreadable
    }
    if let symbol = s.first(where: { !$0.isNumber && !",.()".contains($0) && !minusSigns.contains($0) }) {
        return .foreign(currency: currencySymbols[symbol] ?? String(symbol))
    }

    // Segno: meno iniziale o finale, oppure parentesi, indica un rimborso.
    if let first = s.first, let last = s.last,
       minusSigns.contains(first) || minusSigns.contains(last) || (first == "(" && last == ")") {
        return .refund
    }

    guard let cents = parseCents(s), cents > 0 else { return .unreadable }
    return .euros(cents: cents)
}

private func parseCents(_ s: String) -> Int? {
    guard !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }) else { return nil }
    let separators = s.filter { $0 == "." || $0 == "," }

    var integerPart = s
    var decimalPart = ""
    if Set(separators).count == 2 {
        // L'ultimo separatore è il decimale, l'altro raggruppa le migliaia.
        let decimal = separators.last!
        let index = s.lastIndex(of: decimal)!
        integerPart = String(s[..<index])
        decimalPart = String(s[s.index(after: index)...])
        guard !integerPart.contains(decimal) else { return nil }
    } else if separators.count == 1 {
        let index = s.firstIndex(of: separators.first!)!
        let after = String(s[s.index(after: index)...])
        guard (1...2).contains(after.count) else { return nil }
        integerPart = String(s[..<index])
        decimalPart = after
    }

    let groups = integerPart.split(separator: integerPart.contains(".") ? "." : ",", omittingEmptySubsequences: false)
    if groups.count > 1 {
        guard (1...3).contains(groups[0].count), groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
    }
    let digits = groups.joined()
    guard !digits.isEmpty, digits.count <= 12, decimalPart.count <= 2, let euros = Int(digits) else { return nil }
    let decimals = decimalPart.isEmpty ? 0 : Int(decimalPart.padding(toLength: 2, withPad: "0", startingAt: 0))!
    return euros * 100 + decimals
}

public struct AddExpenseRequest: Equatable, Sendable {
    /// nil quando il link non contiene l'importo.
    public var amount: AmountReading?
    public var merchant: String?
    public var card: String?

    public init(amount: AmountReading?, merchant: String?, card: String?) {
        self.amount = amount
        self.merchant = merchant
        self.card = card
    }
}

/// `expenses://add?amount=…&merchant=…&card=…`, aperto dall'automazione "Transazione" di Comandi Rapidi.
public func parseAddExpenseLink(_ url: URL) -> AddExpenseRequest? {
    guard url.scheme?.lowercased() == AddExpenseLink.scheme, url.host?.lowercased() == "add",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    func value(_ name: String) -> String? {
        let raw = components.queryItems?.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespaces)
        return raw?.isEmpty == false ? raw : nil
    }
    return AddExpenseRequest(amount: value("amount").map(readAmount), merchant: value("merchant"), card: value("card"))
}

public enum AddExpenseLink {
    public static let scheme = "expenses"
    public static let example = "expenses://add?amount=[Importo]&merchant=[Esercente]&card=[Carta]"
    public static let monthURL = URL(string: "expenses://month")!
}
