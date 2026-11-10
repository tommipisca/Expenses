import SwiftUI
import UIKit
import WidgetKit
import ExpensesCore

@main
struct ExpensesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ExpenseStore(fileURL: AppGroup.dataFileURL())
    @State private var router = AppRouter()
    @State private var sync = SyncService()
    @State private var notifier = BudgetNotifier()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(sync)
                .environment(notifier)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { router.handle($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await refresh() }
                    }
                    if phase == .background, sync.isEnabled {
                        // Uscendo dall'app invia i dati prima della sospensione.
                        var backgroundTask = UIBackgroundTaskIdentifier.invalid
                        backgroundTask = UIApplication.shared.beginBackgroundTask {
                            UIApplication.shared.endBackgroundTask(backgroundTask)
                            backgroundTask = .invalid
                        }
                        Task {
                            await sync.sync(store: store)
                            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
                        }
                    }
                }
                // Dopo ogni modifica (e all'avvio): sync, avvisi e widget, con 2 secondi di attesa
                // per raggruppare le modifiche ravvicinate.
                .task(id: store.data) {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    await sync.sync(store: store)
                    await afterChange()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await refresh() }
                }
        }
    }

    /// All'apertura e al ritorno in primo piano: spese periodiche dovute, dati dell'altro dispositivo, avvisi, widget.
    private func refresh() async {
        // Prima la sincronizzazione: le regole sospese o eliminate sull'altro dispositivo non generano nulla.
        await sync.sync(store: store)
        store.generateDueRecurring()
        await afterChange()
    }

    private func afterChange() async {
        await notifier.evaluate(store: store)
        if let container = AppGroup.containerURL {
            store.writeWidgetSummary(to: container.appendingPathComponent(WidgetSummary.fileName))
        } else {
            store.writeWidgetSummary(to: AppGroup.dataFileURL().deletingLastPathComponent()
                .appendingPathComponent(WidgetSummary.fileName))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
