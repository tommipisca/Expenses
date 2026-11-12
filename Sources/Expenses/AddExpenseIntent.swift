import AppIntents
import ExpensesCore

/// Azione di Comandi Rapidi per l'automazione "Transazione" di Wallet: salva la spesa senza aprire l'app,
/// anche a telefono bloccato. La spesa resta tra quelle da confermare finché non la controlli.
///
/// Su Linux la descrizione dell'azione (`Metadata.appintents`) la genera `xdev` dopo la build
/// (vedi `~/ios/LINEE-GUIDA-xtool-WSL.md`): con il solo `xtool dev` l'azione non compare in Comandi Rapidi.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Aggiungi spesa"
    static let description = IntentDescription("Salva una spesa in Expenses senza aprire l'app: la confermi dopo.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Importo")
    var amount: String?

    @Parameter(title: "Esercente")
    var merchant: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Aggiungi spesa di \(\.$amount) da \(\.$merchant)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedStore.store
        store.lastError = nil
        let expense = store.addPendingExpense(amountText: amount, merchant: merchant, date: .now)
        if let error = store.lastError {
            throw AddExpenseIntentError.saveFailed(error.message)
        }
        await AppRefresh.afterChange(store: store, notifier: BudgetNotifier())
        let what = expense.amountCents > 0 ? Money.format(expense.amountCents) : "Spesa"
        return .result(dialog: "\(what) salvata in Expenses, da confermare")
    }
}

enum AddExpenseIntentError: Error, CustomLocalizedStringResourceConvertible {
    case saveFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .saveFailed(let message): "Spesa non salvata: \(message)"
        }
    }
}
