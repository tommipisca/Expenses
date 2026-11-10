import Foundation

public enum AppGroup {
    /// Identificatore reale del gruppo. xtool lo riscrive in fase di firma
    /// (es. `group.XTL-<id>.com.Tommaso.Expenses`), quindi lo ricaviamo dal bundle ID in esecuzione.
    public static let identifier = groupIdentifier(forBundleID: Bundle.main.bundleIdentifier)

    private static let appBundleID = "com.Tommaso.Expenses"
    private static let widgetSuffix = ".Widget"

    /// `group.` + bundle ID dell'app; il widget (`<app>.Widget`) usa lo stesso gruppo dell'app.
    static func groupIdentifier(forBundleID bundleID: String?) -> String {
        var appID = bundleID ?? appBundleID
        if appID.hasSuffix(widgetSuffix) {
            appID.removeLast(widgetSuffix.count)
        }
        return "group.\(appID)"
    }

    /// Contenitore condiviso dell'App Group, se il profilo di provisioning lo concede.
    public static var containerURL: URL? {
        #if canImport(Darwin)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        #else
        nil
        #endif
    }

    public static var isAvailable: Bool { containerURL != nil }

    /// Preferenze condivise tra app e widget; senza App Group si usano quelle dell'app.
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// URL di `expenses.json`: nell'App Group se disponibile, altrimenti in Documents.
    public static func dataFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if containerURL == nil {
            NSLog("Expenses: App Group %@ non disponibile, uso Documents", identifier)
        }
        return resolveDataFileURL(groupContainer: containerURL, documents: documents)
    }

    /// Sceglie dove salvare i dati. Se il gruppo è disponibile ma i dati sono ancora in
    /// Documents (installazione precedente senza gruppo), li sposta nel gruppo.
    static func resolveDataFileURL(groupContainer: URL?, documents: URL) -> URL {
        let documentsFile = documents.appendingPathComponent("expenses.json")
        guard let groupContainer else { return documentsFile }

        let groupFile = groupContainer.appendingPathComponent("expenses.json")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: groupFile.path), fileManager.fileExists(atPath: documentsFile.path) {
            do {
                try fileManager.moveItem(at: documentsFile, to: groupFile)
                NSLog("Expenses: dati spostati da Documents all'App Group")
            } catch {
                NSLog("Expenses: spostamento dei dati nell'App Group fallito (%@)", String(describing: error))
                return documentsFile
            }
        } else if fileManager.fileExists(atPath: groupFile.path), fileManager.fileExists(atPath: documentsFile.path) {
            mergeDocuments(documentsFile, into: groupFile)
        }
        return groupFile
    }

    /// Dati in entrambi i posti (per esempio un'installazione fatta senza App Group dopo una con il gruppo):
    /// si uniscono nel gruppo e il file di Documents viene messo da parte, mai cancellato.
    static func mergeDocuments(_ documentsFile: URL, into groupFile: URL) {
        let decoder = StoreCoding.decoder()
        guard let documentsData = try? Data(contentsOf: documentsFile),
              let groupData = try? Data(contentsOf: groupFile),
              let fromDocuments = try? decoder.decode(StoredData.self, from: documentsData),
              let fromGroup = try? decoder.decode(StoredData.self, from: groupData) else {
            NSLog("Expenses: impossibile unire i dati di Documents con quelli dell'App Group")
            return
        }
        let merged = SyncSnapshot.merge(local: SyncSnapshot(stored: fromGroup), remote: SyncSnapshot(stored: fromDocuments))
        do {
            try StoreCoding.encoder().encode(StoredData(snapshot: merged)).write(to: groupFile, options: .atomic)
            let stamp = Int(Date().timeIntervalSince1970)
            let setAside = documentsFile.deletingLastPathComponent().appendingPathComponent("expenses.merged-\(stamp).json")
            try FileManager.default.moveItem(at: documentsFile, to: setAside)
            NSLog("Expenses: dati di Documents uniti a quelli dell'App Group")
        } catch {
            NSLog("Expenses: unione dei dati di Documents fallita (%@)", String(describing: error))
        }
    }
}
