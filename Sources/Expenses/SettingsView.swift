import SwiftUI
import UIKit
import ExpensesCore

struct SettingsView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(BudgetNotifier.self) private var notifier
    @State private var budgetText = ""
    @State private var editingRule: RuleSheet?
    @State private var copied = false
    @FocusState private var budgetFocused: Bool
    @Environment(\.isWideLayout) private var isWide

    struct RuleSheet: Identifiable {
        let id = UUID()
        var rule: RecurringExpense?
    }

    var body: some View {
        NavigationStack {
            Group {
                if isWide {
                    // iPad in orizzontale: a sinistra le impostazioni di tutti i giorni,
                    // a destra quelle che si configurano una volta.
                    HStack(alignment: .top, spacing: 0) {
                        Form {
                            budgetSection
                            recurringSection
                        }
                        .themedListBackground()
                        .floatingTabBarClearance()
                        Form {
                            SyncSettingsSection()
                            walletSection
                            installationSection
                        }
                        .themedListBackground()
                        .floatingTabBarClearance()
                    }
                    .background(Theme.background)
                } else {
                    Form {
                        budgetSection
                        recurringSection
                        SyncSettingsSection()
                        walletSection
                        installationSection
                    }
                    .themedListBackground()
                    .floatingTabBarClearance()
                }
            }
            .navigationTitle("Impostazioni")
            .sheet(item: $editingRule) { sheet in RecurringFormView(rule: sheet.rule) }
            .onAppear { budgetText = store.settings.monthlyBudgetCents.map(Formatting.editableAmount) ?? "" }
            .onDisappear(perform: commitBudget)
        }
    }

    // MARK: Budget

    private var hasBudget: Binding<Bool> {
        Binding {
            store.settings.monthlyBudgetCents != nil
        } set: { enabled in
            if enabled {
                store.setMonthlyBudget(cents: currentBudgetCents ?? 100_000)
                budgetText = Formatting.editableAmount(store.settings.monthlyBudgetCents ?? 0)
                Task { await notifier.requestAuthorizationIfNeeded() }
            } else {
                store.setMonthlyBudget(cents: nil)
            }
        }
    }

    private var currentBudgetCents: Int? {
        if case .euros(let cents) = readAmount(budgetText) { cents } else { nil }
    }

    private var budgetSection: some View {
        Section {
            Toggle("Budget mensile totale", isOn: hasBudget.animation())
            if store.settings.monthlyBudgetCents != nil {
                HStack {
                    Text("Importo")
                    Spacer()
                    TextField("0,00", text: $budgetText)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospacedDigit()
                        .focused($budgetFocused)
                        // Si salva quando il campo perde il focus, non a ogni cifra: i valori
                        // intermedi (es. "2" scrivendo "2000") farebbero partire avvisi falsi.
                        .onChange(of: budgetFocused) { _, focused in if !focused { commitBudget() } }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Fine") { budgetFocused = false }
                            }
                        }
                    Text("€").foregroundStyle(Theme.textSecondary)
                }
            }
        } header: {
            Text("Budget").sectionHeaderStyle()
        } footer: {
            Text("Facoltativo, come i budget dei singoli tag (si impostano nella scheda Tag). Ricevi un avviso all'80% e al superamento.")
        }
        .listRowBackground(Theme.surface)
    }

    private func commitBudget() {
        guard let cents = currentBudgetCents, cents != store.settings.monthlyBudgetCents else { return }
        store.setMonthlyBudget(cents: cents)
    }

    // MARK: Spese periodiche

    private var recurringSection: some View {
        Section {
            ForEach(store.recurring) { rule in
                HStack(spacing: 12) {
                    Button { editingRule = RuleSheet(rule: rule) } label: { ruleLabel(rule) }
                        .buttonStyle(.plain)
                    Toggle("Attiva", isOn: Binding(
                        get: { rule.isActive },
                        set: { store.setRecurringActive(id: rule.id, active: $0) }
                    ))
                    .labelsHidden()
                }
                .swipeActions {
                    Button("Elimina", systemImage: "trash", role: .destructive) { store.deleteRecurring(id: rule.id) }
                }
            }
            Button { editingRule = RuleSheet(rule: nil) } label: {
                Label("Aggiungi spesa periodica", systemImage: "plus")
            }
        } header: {
            Text("Spese periodiche").sectionHeaderStyle()
        } footer: {
            Text("Vengono aggiunte da sole quando arriva la data, appena apri l'app. Sospendendone una, le date saltate non vengono recuperate; eliminandola, le spese già create restano.")
        }
        .listRowBackground(Theme.surface)
    }

    private func ruleLabel(_ rule: RecurringExpense) -> some View {
        let tag = store.tag(id: rule.tagID)
        return HStack(spacing: 12) {
            TagDot(colorIndex: tag?.colorIndex)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.merchant ?? rule.note ?? tag?.name ?? "Spesa periodica").font(.body.weight(.medium))
                Text(RecurringFormView.describe(rule)).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(Money.format(rule.amountCents)).font(.rounded(.body, weight: .semibold)).monospacedDigit()
        }
        .opacity(rule.isActive ? 1 : 0.5)
        .contentShape(Rectangle())
    }

    // MARK: Wallet

    private var walletSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                step(1, "Apri Comandi Rapidi › Automazione › Nuova automazione › Transazione.")
                step(2, "Scegli le carte e seleziona «Esegui immediatamente».")
                step(3, "Aggiungi l'azione «Aggiungi spesa» di Expenses e collega Importo ed Esercente alle variabili della transazione.")
                step(4, "Dopo ogni pagamento la spesa si salva senza aprire l'app, anche a telefono bloccato, e compare in «Da confermare» nella schermata Mese.")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("In alternativa, per aprire subito il modulo compilato, usa l'azione «Apri URL» con questo link, sostituendo ogni segnaposto (parentesi comprese) con la variabile.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
                Text(AddExpenseLink.example).font(.footnote.monospaced()).textSelection(.enabled)
                Button(copied ? "Copiato" : "Copia link", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = AddExpenseLink.example
                    copied = true
                }
            }
        } header: {
            Text("Pagamenti con Wallet").sectionHeaderStyle()
        } footer: {
            Text("Per pagamenti in altre valute o rimborsi l'importo resta vuoto: lo inserisci tu in euro quando confermi la spesa.")
        }
        .listRowBackground(Theme.surface)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)").font(.rounded(.footnote, weight: .bold)).foregroundStyle(Theme.accent)
            Text(text).font(.footnote)
        }
    }

    // MARK: Installazione

    private var installationSection: some View {
        Section {
            if let expiration = ProvisioningProfile.embeddedExpirationDate() {
                let days = Calendar.current.dateComponents(
                    [.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: expiration)
                ).day ?? 0
                LabeledContent("Scadenza dell'app") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(days <= 0 ? "Oggi" : days == 1 ? "Domani" : "Tra \(days) giorni")
                            .font(.rounded(.body, weight: .semibold))
                            .foregroundStyle(days <= 1 ? Theme.danger : days <= 3 ? Theme.warning : Theme.textPrimary)
                        Text(expiration.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()
                            .locale(Formatting.italian)))
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            } else {
                LabeledContent("Scadenza dell'app", value: "Non disponibile")
            }
        } header: {
            Text("Installazione").sectionHeaderStyle()
        } footer: {
            Text("Con l'account sviluppatore gratuito l'app va reinstallata ogni 7 giorni con xtool dev. I dati restano.")
        }
        .listRowBackground(Theme.surface)
    }
}
