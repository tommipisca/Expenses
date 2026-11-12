import SwiftUI

/// Vero quando la finestra è larga (iPad in orizzontale o a tutto schermo): le pagine passano a due colonne.
/// In verticale, in Split View stretta e su iPhone resta il layout a una colonna.
private struct WideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isWideLayout: Bool {
        get { self[WideLayoutKey.self] }
        set { self[WideLayoutKey.self] = newValue }
    }
}

enum WideLayout {
    /// Larghezza minima: tutti gli iPad in orizzontale la superano (il più piccolo, mini, è 1133 punti),
    /// nessuno in verticale (il più grande, 13", è 1032).
    static let minWidth: CGFloat = 1100
}
