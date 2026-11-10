import SwiftUI
import ExpensesCore

enum AppTab: Hashable {
    case month, history, tags, settings
}

/// Foglio "Nuova spesa" / "Modifica spesa".
struct ExpenseSheet: Identifiable {
    let id = UUID()
    var expense: Expense?
    var prefill: AddExpenseRequest?
}

/// Navigazione condivisa: scheda attiva, filtro iniziale dello storico, foglio della spesa.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .month
    var expenseSheet: ExpenseSheet?
    /// Filtro con cui aprire lo Storico (da un tag nella schermata Mese); consumato dallo Storico.
    var pendingHistoryQuery: HistoryQuery?

    func newExpense(prefill: AddExpenseRequest? = nil) {
        expenseSheet = ExpenseSheet(expense: nil, prefill: prefill)
    }

    func edit(_ expense: Expense) {
        expenseSheet = ExpenseSheet(expense: expense)
    }

    func openHistory(tagID: UUID?, month: MonthKey) {
        pendingHistoryQuery = HistoryQuery(tagIDs: [tagID], month: month)
        tab = .history
    }

    func handle(_ url: URL) {
        if let request = parseAddExpenseLink(url) {
            tab = .month
            newExpense(prefill: request)
        } else if url.host?.lowercased() == "month" {
            tab = .month
        }
    }
}

struct RootView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            MonthView()
                .tabItem { Label("Mese", systemImage: "chart.pie.fill") }
                .tag(AppTab.month)
            HistoryView()
                .tabItem { Label("Storico", systemImage: "list.bullet") }
                .tag(AppTab.history)
            TagsView()
                .tabItem { Label("Tag", systemImage: "tag.fill") }
                .tag(AppTab.tags)
            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .sheet(item: $router.expenseSheet) { sheet in
            ExpenseFormView(sheet: sheet)
        }
        .alert("Attenzione", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError?.message ?? "")
        }
    }
}
