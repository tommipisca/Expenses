import SwiftUI
import ExpensesCore

/// Scelta della cartella iCloud Drive condivisa tra iPhone e iPad e stato della sincronizzazione.
struct SyncSettingsSection: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(SyncService.self) private var sync
    @State private var showingPicker = false

    var body: some View {
        Section {
            if let folder = sync.folderName {
                LabeledContent("Cartella", value: folder)
                LabeledContent("Ultima sincronizzazione") {
                    if sync.isSyncing {
                        ProgressView()
                    } else {
                        Text(sync.lastSync.map { $0.formatted(.relative(presentation: .named).locale(Formatting.italian)) } ?? "Mai")
                    }
                }
                LabeledContent("Ultimo backup automatico") {
                    Text(sync.lastAutoBackup.map { $0.formatted(.relative(presentation: .named).locale(Formatting.italian)) } ?? "Mai")
                }
                if let error = sync.errorMessage {
                    Label(error, systemImage: "exclamationmark.icloud").font(.footnote).foregroundStyle(Theme.warning)
                }
                Button {
                    Task { await sync.sync(store: store) }
                } label: {
                    Label("Sincronizza ora", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(sync.isSyncing)
                Button("Scollega cartella", role: .destructive) { sync.unlink() }
            } else {
                Button { showingPicker = true } label: {
                    Label("Scegli cartella in iCloud Drive", systemImage: "icloud")
                }
            }
        } header: {
            Text("Sincronizzazione").sectionHeaderStyle()
        } footer: {
            Text("Scegli la stessa cartella su iPhone e iPad: i dati si uniscono spesa per spesa e, se modifichi la stessa spesa su entrambi, vince la modifica più recente. Ogni giorno viene salvato un backup nella sottocartella Backup (gli ultimi 14).")
        }
        .listRowBackground(Theme.surface)
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            sync.link(folder: url)
            Task { await sync.sync(store: store) }
        }
    }
}
