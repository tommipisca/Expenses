import SwiftUI
import ExpensesCore

enum AppTab: CaseIterable, Hashable {
    case month, history, tags, settings

    var title: String {
        switch self {
        case .month: "Mese"
        case .history: "Storico"
        case .tags: "Tag"
        case .settings: "Impostazioni"
        }
    }

    var icon: String {
        switch self {
        case .month: "chart.pie.fill"
        case .history: "list.bullet"
        case .tags: "tag.fill"
        case .settings: "gearshape.fill"
        }
    }
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

    /// Lo Storico su un mese, senza filtri sui tag ("Vedi tutte" nella schermata Mese).
    func openHistory(month: MonthKey) {
        pendingHistoryQuery = HistoryQuery(month: month)
        tab = .history
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
    /// Altezza dell'isola con i suoi margini, misurata: le pagine la usano come spazio finale.
    @State private var tabBarHeight: CGFloat = 0

    var body: some View {
        @Bindable var router = router
        GeometryReader { proxy in
            tabs($router.tab)
                .environment(\.isWideLayout, proxy.size.width >= WideLayout.minWidth)
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

    /// Schede con barra personalizzata (come ExamsTrack): un'isola arrotondata che fluttua sopra il contenuto.
    private func tabs(_ selection: Binding<AppTab>) -> some View {
        TabView(selection: selection) {
            MonthView()
                .tag(AppTab.month)
                .toolbar(.hidden, for: .tabBar)
            HistoryView()
                .tag(AppTab.history)
                .toolbar(.hidden, for: .tabBar)
            TagsView()
                .tag(AppTab.tags)
                .toolbar(.hidden, for: .tabBar)
            SettingsView()
                .tag(AppTab.settings)
                .toolbar(.hidden, for: .tabBar)
        }
        .environment(\.floatingTabBarHeight, tabBarHeight)
        // L'isola fluttua sopra il contenuto, che può scorrerle sotto.
        .overlay(alignment: .bottom) {
            FloatingTabBar(selection: selection, badges: [.month: store.pendingReview.count])
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { tabBarHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, height in tabBarHeight = height }
                    }
                }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
