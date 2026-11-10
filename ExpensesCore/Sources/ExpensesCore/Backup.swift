import Foundation

/// Backup automatici giornalieri nella cartella di sincronizzazione.
public enum BackupRotation {
    public static let folderName = "Backup"
    public static let keep = 14
    private static let prefix = "Expenses-backup-"

    /// "Expenses-backup-AAAA-MM-GG.json": il nome ordina i file per data.
    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        // Sempre gregoriano: con altri calendari l'ordine alfabetico dei file non sarebbe cronologico.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "\(prefix)%04d-%02d-%02d.json", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// I backup più vecchi oltre i `keep` più recenti; altri file nella cartella non vengono toccati.
    public static func filesToDelete(_ names: [String], keep: Int = keep) -> [String] {
        let backups = names.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }.sorted(by: >)
        return Array(backups.dropFirst(keep))
    }
}

extension SyncSnapshot {
    /// Unisce più versioni remote, per esempio le copie in conflitto create da iCloud.
    public static func mergeAll(local: SyncSnapshot, remotes: [SyncSnapshot]) -> SyncSnapshot {
        remotes.reduce(local) { merge(local: $0, remote: $1) }
    }
}

extension ExpenseStore {
    /// Backup completo: lo stesso formato del file di sincronizzazione.
    public func exportBackup() throws -> Data {
        try snapshot().encoded()
    }
}
