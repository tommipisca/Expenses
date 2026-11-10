import Foundation

/// Importi in centesimi interi, formattati all'italiana ("€ 1.248,60") senza NumberFormatter,
/// così il risultato è identico su iOS e su Linux.
public enum Money {
    public static func format(_ cents: Int) -> String {
        let parts = formatParts(cents)
        return parts.euros + parts.decimals
    }

    /// Parte intera con simbolo ("€ 1.248") e decimali con virgola (",60"), per l'anello.
    public static func formatParts(_ cents: Int) -> (euros: String, decimals: String) {
        let sign = cents < 0 ? "−" : ""
        let absolute = cents.magnitude
        let euros = absolute / 100
        let remainder = absolute % 100
        let decimals = remainder < 10 ? ",0\(remainder)" : ",\(remainder)"
        return ("\(sign)€ \(grouped(euros))", decimals)
    }

    private static func grouped(_ value: UInt) -> String {
        let digits = Array(String(value))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { result.append(".") }
            result.append(digit)
        }
        return result
    }
}
