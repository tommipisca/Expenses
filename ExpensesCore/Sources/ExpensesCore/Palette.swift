/// Colori del tema scuro come valori esadecimali RGB, condivisi da app e widget.
public enum Palette {
    public static let background: UInt32 = 0x0E1117
    public static let surface: UInt32 = 0x161B22
    public static let elevated: UInt32 = 0x1F2630
    public static let stroke: UInt32 = 0x2A3340
    public static let textPrimary: UInt32 = 0xE6EDF3
    public static let textSecondary: UInt32 = 0x8B949E

    public static let accent: UInt32 = 0x818CF8
    public static let success: UInt32 = 0x34D399
    public static let warning: UInt32 = 0xFBBF24
    public static let danger: UInt32 = 0xFB7185
    public static let gold: UInt32 = 0xFACC15

    /// Colori dei tag: tinte luminose e morbide per il tema scuro, senza rosso e oro
    /// (riservati agli avvisi). L'ordine alterna tinte lontane, così esami creati
    /// uno dopo l'altro hanno colori ben distinti.
    public static let tagColors: [UInt32] = [
        0x818CF8, // indaco
        0x34D399, // smeraldo
        0xFB923C, // arancio
        0x38BDF8, // azzurro
        0xE879F9, // fucsia
        0xA3E635, // lime
        0xA78BFA, // viola
        0x2DD4BF, // verde acqua
        0xFBBF24, // ambra
        0x60A5FA, // blu
        0xF472B6, // rosa
        0x4ADE80, // verde
        0xC084FC, // porpora
        0x22D3EE, // ciano
    ]

    /// Colore per un nuovo tag: il meno usato; a parità, il primo nell'ordine della tavolozza.
    public static func balancedColorIndex(used: [Int]) -> Int {
        var counts = [Int](repeating: 0, count: tagColors.count)
        for index in used where counts.indices.contains(index) {
            counts[index] += 1
        }
        let fewest = counts.min() ?? 0
        return counts.firstIndex(of: fewest) ?? 0
    }
}
