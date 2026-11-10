import Foundation
import Observation
import ExpensesCore

/// Sincronizza i dati con un file in una cartella scelta dall'utente (es. su iCloud Drive).
/// Ogni dispositivo legge il file, unisce i dati elemento per elemento e riscrive il risultato.
@MainActor
@Observable
final class SyncService {
    nonisolated static let fileName = SyncSnapshot.fileName
    private static let bookmarkKey = "syncFolderBookmark"
    private static let lastSyncKey = "syncLastDate"
    private static let lastBackupKey = "syncLastAutoBackup"

    private(set) var folderName: String?
    private(set) var lastSync: Date?
    /// Ultimo backup automatico scritto da questo dispositivo.
    private(set) var lastAutoBackup: Date?
    private(set) var errorMessage: String?
    private(set) var isSyncing = false
    /// Una sincronizzazione richiesta mentre un'altra era in corso: si ripete appena finisce,
    /// così una modifica fatta durante la sincronizzazione non resta indietro.
    private var needsAnotherPass = false

    /// Oltre questo tempo una lettura o scrittura su iCloud si considera bloccata.
    nonisolated private static let timeout: Duration = .seconds(30)

    var isEnabled: Bool { bookmark != nil }

    private var bookmark: Data? {
        didSet { UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey) }
    }

    init() {
        bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey)
        lastSync = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        lastAutoBackup = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date
        folderName = resolveFolder()?.lastPathComponent
    }

    // MARK: Collegamento

    /// Ricorda la cartella scelta con il selettore di file, così resta accessibile ai prossimi avvii.
    func link(folder: URL) {
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            bookmark = try folder.bookmarkData()
            folderName = folder.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = "Impossibile ricordare la cartella scelta."
        }
    }

    func unlink() {
        bookmark = nil
        folderName = nil
        errorMessage = nil
        lastSync = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
    }

    // MARK: Sincronizzazione

    /// Sincronizzazione in corso. Gira in un Task suo, così non si interrompe se chi l'ha chiesta
    /// viene annullato (per esempio l'attesa dopo una modifica, annullata dalla modifica successiva).
    @ObservationIgnored private var running: Task<Void, Never>?

    /// Legge il file condiviso, unisce con i dati locali e riscrive il file se serve.
    func sync(store: ExpenseStore) async {
        guard isEnabled else { return }
        if let running {
            // Una sincronizzazione è già in corso: ne servirà un'altra subito dopo.
            needsAnotherPass = true
            await running.value
            return
        }
        let task = Task { await runPasses(store: store) }
        running = task
        await task.value
    }

    private func runPasses(store: ExpenseStore) async {
        isSyncing = true
        repeat {
            needsAnotherPass = false
            await syncOnce(store: store)
        } while needsAnotherPass
        isSyncing = false
        running = nil
    }

    private func syncOnce(store: ExpenseStore) async {
        guard let folder = resolveFolder() else {
            errorMessage = "La cartella di sincronizzazione non è più accessibile: scollegala e sceglila di nuovo."
            return
        }
        let fileURL = folder.appendingPathComponent(Self.fileName)
        do {
            let remote = try await Self.withTimeout { try await Self.read(fileURL, scopedBy: folder) }
            let current = try remote.data.map(SyncSnapshot.decode) ?? SyncSnapshot()
            // Le copie in conflitto (scritture contemporanee offline) si uniscono, non si scartano.
            // Si segnano come risolte solo quelle lette e unite davvero.
            var conflicts: [SyncSnapshot] = []
            var mergedVersionIDs: [String] = []
            for conflict in remote.conflicts {
                guard let snapshot = try? SyncSnapshot.decode(conflict.data) else { continue }
                conflicts.append(snapshot)
                mergedVersionIDs.append(conflict.id)
            }
            let merged = SyncSnapshot.mergeAll(local: store.snapshot(), remotes: [current] + conflicts)
            // Backup del giorno con i dati di questo dispositivo, prima di applicare quelli dell'altro:
            // protegge da un errore che arriverebbe con la sincronizzazione.
            await makeDailyBackupIfNeeded(store: store, folder: folder)
            store.applySynced(merged)
            // L'ordine degli elementi può differire tra dispositivi: si riscrive solo se cambia il contenuto.
            if remote.data == nil || !mergedVersionIDs.isEmpty || !merged.hasSameContent(as: current) {
                let data = try merged.encoded()
                let versionIDs = mergedVersionIDs
                try await Self.withTimeout {
                    try await Self.write(data, to: fileURL, scopedBy: folder, resolvingVersions: versionIDs)
                }
            }
            lastSync = .now
            UserDefaults.standard.set(lastSync, forKey: Self.lastSyncKey)
            errorMessage = nil
        } catch is DecodingError {
            errorMessage = "Il file \(Self.fileName) non è leggibile: non è stato modificato."
        } catch SyncError.notDownloaded {
            errorMessage = "Il file su iCloud non è ancora scaricato su questo dispositivo: riprova tra poco."
        } catch is CancellationError {
            // Non è un errore di iCloud: si riprova alla prossima occasione, senza messaggi.
            needsAnotherPass = false
        } catch SyncError.timedOut {
            errorMessage = "iCloud non risponde: la sincronizzazione riproverà alla prossima apertura."
        } catch {
            NSLog("Expenses: sincronizzazione fallita (%@)", String(describing: error))
            errorMessage = "Sincronizzazione non riuscita. Controlla la connessione e che la cartella esista ancora."
        }
    }

    // MARK: Backup automatici

    /// Un backup al giorno nella sottocartella "Backup", tenendo solo gli ultimi 14.
    /// Protegge anche dagli errori che la sincronizzazione porterebbe su entrambi i dispositivi.
    private func makeDailyBackupIfNeeded(store: ExpenseStore, folder: URL) async {
        let today = Calendar.current.startOfDay(for: .now)
        if let last = lastAutoBackup, Calendar.current.isDate(last, inSameDayAs: today) { return }
        guard let data = try? store.exportBackup() else { return }
        let name = BackupRotation.fileName(for: today)
        do {
            try await Self.withTimeout { try await Self.writeBackup(data, named: name, in: folder) }
            lastAutoBackup = .now
            UserDefaults.standard.set(lastAutoBackup, forKey: Self.lastBackupKey)
        } catch {
            NSLog("Expenses: backup automatico non riuscito (%@)", String(describing: error))
        }
    }

    private func resolveFolder() -> URL? {
        guard let bookmark else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            // Il segnalibro va rinnovato (es. cartella spostata): lo ricrea finché è ancora valido,
            // ma tiene quello vecchio se il rinnovo fallisce.
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            if let renewed = try? url.bookmarkData() {
                self.bookmark = renewed
            }
        }
        return url
    }

    // MARK: Accesso coordinato ai file

    private enum SyncError: Error {
        case notDownloaded
        case timedOut
    }

    /// Smette di aspettare un'operazione su iCloud rimasta bloccata. Operazione e timer corrono in
    /// parallelo e il primo che finisce dà il risultato; nessuno aspetta l'altro (un gruppo di task
    /// aspetterebbe comunque l'operazione bloccata, e il timeout non scatterebbe mai).
    nonisolated private static func withTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            Task.detached {
                do { once.resume(with: .success(try await operation())) } catch { once.resume(with: .failure(error)) }
            }
            Task.detached {
                try? await Task.sleep(for: timeout)
                once.resume(with: .failure(SyncError.timedOut))
            }
        }
    }

    /// Riprende una continuation una volta sola, anche se due task provano a farlo.
    private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Error>?

        init(_ continuation: CheckedContinuation<T, Error>) {
            self.continuation = continuation
        }

        func resume(with result: Result<T, Error>) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(with: result)
        }
    }

    /// File condiviso letto da iCloud, con le eventuali copie in conflitto.
    private struct RemoteFile: Sendable {
        var data: Data?
        var conflicts: [ConflictVersion]
    }

    /// Una copia in conflitto creata da iCloud, con il suo identificativo per segnarla come risolta.
    private struct ConflictVersion: Sendable {
        var id: String
        var data: Data
    }

    /// Coda per le operazioni bloccanti sui file, fuori dai thread condivisi di Swift. Non seriale:
    /// un'operazione bloccata (e abbandonata per timeout) non deve trattenere le successive.
    nonisolated private static let ioQueue = DispatchQueue(
        label: "Expenses.sync-io", qos: .utility, attributes: .concurrent
    )

    nonisolated private static func onIOQueue<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async { continuation.resume(with: Result { try work() }) }
        }
    }

    /// Legge il file (nil se non esiste ancora). Il coordinamento fa scaricare da iCloud la versione aggiornata.
    nonisolated private static func read(_ fileURL: URL, scopedBy folder: URL) async throws -> RemoteFile {
        try await onIOQueue {
            let isScoped = folder.startAccessingSecurityScopedResource()
            defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
            try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)

            // File presente su iCloud ma non ancora scaricato: iOS mostra solo un segnaposto
            // ".nome.icloud". Non va trattato come "file assente", altrimenti lo sovrascriveremmo.
            let placeholder = folder.appendingPathComponent(".\(fileName).icloud")
            if !FileManager.default.fileExists(atPath: fileURL.path),
               FileManager.default.fileExists(atPath: placeholder.path) {
                throw SyncError.notDownloaded
            }

            var coordinationError: NSError?
            var result: Result<RemoteFile, Error> = .success(RemoteFile(data: nil, conflicts: []))
            NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                result = Result {
                    let conflicts = (NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).compactMap { version in
                        (try? Data(contentsOf: version.url)).map {
                            ConflictVersion(id: String(describing: version.persistentIdentifier), data: $0)
                        }
                    }
                    return RemoteFile(data: try Data(contentsOf: url), conflicts: conflicts)
                }
            }
            if let coordinationError {
                // Un file che non esiste ancora non è un errore: verrà creato.
                if coordinationError.domain == NSCocoaErrorDomain,
                   coordinationError.code == NSFileReadNoSuchFileError {
                    return RemoteFile(data: nil, conflicts: [])
                }
                throw coordinationError
            }
            return try result.get()
        }
    }

    /// Scrive il file; dopo un'unione delle copie in conflitto le segna come risolte e le rimuove.
    nonisolated private static func write(
        _ data: Data, to fileURL: URL, scopedBy folder: URL, resolvingVersions versionIDs: [String]
    ) async throws {
        try await onIOQueue {
            let isScoped = folder.startAccessingSecurityScopedResource()
            defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
            try coordinatedWrite(data, to: fileURL)
            guard !versionIDs.isEmpty else { return }
            // Solo le copie lette e unite; una comparsa nel frattempo resta per la volta successiva.
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { url in
                let pending = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
                for version in pending where versionIDs.contains(String(describing: version.persistentIdentifier)) {
                    version.isResolved = true
                    try? version.remove()
                }
            }
        }
    }

    /// Scrive il backup del giorno (se manca) e cancella quelli oltre gli ultimi 14.
    nonisolated private static func writeBackup(_ data: Data, named name: String, in folder: URL) async throws {
        try await onIOQueue {
            let isScoped = folder.startAccessingSecurityScopedResource()
            defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
            let backups = folder.appendingPathComponent(BackupRotation.folderName, isDirectory: true)
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)

            let fileURL = backups.appendingPathComponent(name)
            let placeholder = backups.appendingPathComponent(".\(name).icloud")
            // Già scritto (anche dall'altro dispositivo, magari non ancora scaricato qui): niente doppioni.
            if !FileManager.default.fileExists(atPath: fileURL.path),
               !FileManager.default.fileExists(atPath: placeholder.path) {
                try coordinatedWrite(data, to: fileURL)
            }
            let names = (try? FileManager.default.contentsOfDirectory(atPath: backups.path)) ?? []
            for old in BackupRotation.filesToDelete(names) {
                let url = backups.appendingPathComponent(old)
                var coordinationError: NSError?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { url in
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    nonisolated private static func coordinatedWrite(_ data: Data, to fileURL: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError {
            throw error
        }
    }
}
