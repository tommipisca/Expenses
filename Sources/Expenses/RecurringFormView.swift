import SwiftUI
import ExpensesCore

/// Crea o modifica una spesa periodica. Le modifiche valgono per le occorrenze future.
struct RecurringFormView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let original: RecurringExpense?
    @State private var amountText: String
    @State private var merchant: String
    @State private var tagID: UUID?
    @State private var frequency: Frequency
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var pendingCount: Int?

    init(rule: RecurringExpense?) {
        original = rule
        _amountText = State(initialValue: rule.map { Formatting.editableAmount($0.amountCents) } ?? "")
        _merchant = State(initialValue: rule?.merchant ?? "")
        _tagID = State(initialValue: rule?.tagID)
        _frequency = State(initialValue: rule?.frequency ?? .monthly)
        _startDate = State(initialValue: rule?.startDate ?? .now)
        _hasEndDate = State(initialValue: rule?.endDate != nil)
        _endDate = State(initialValue: rule?.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)!)
    }

    static func frequencyName(_ frequency: Frequency) -> String {
        switch frequency {
        case .weekly: "Ogni settimana"
        case .monthly: "Ogni mese"
        case .yearly: "Ogni anno"
        }
    }

    static func describe(_ rule: RecurringExpense) -> String {
        var text = "\(frequencyName(rule.frequency)) dal \(Formatting.shortDate(rule.startDate))"
        if let end = rule.endDate { text += " al \(Formatting.shortDate(end))" }
        if !rule.isActive { text += " · sospesa" }
        return text
    }

    private var cents: Int? {
        if case .euros(let value) = readAmount(amountText) { value } else { nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Importo")
                        Spacer()
                        TextField("0,00", text: $amountText).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).monospacedDigit()
                        Text("€").foregroundStyle(Theme.textSecondary)
                    }
                    TextField("Descrizione (es. Affitto)", text: $merchant)
                    Picker("Tag", selection: $tagID) {
                        Text(TagSlice.untaggedName).tag(UUID?.none)
                        ForEach(store.tags) { tag in Text(tag.name).tag(UUID?.some(tag.id)) }
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    Picker("Frequenza", selection: $frequency) {
                        ForEach(Frequency.allCases, id: \.self) { Text(Self.frequencyName($0)).tag($0) }
                    }
                    DatePicker("Prima volta", selection: $startDate, displayedComponents: .date)
                    Toggle("Data di fine", isOn: $hasEndDate.animation())
                    if hasEndDate {
                        DatePicker("Fine", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                } footer: {
                    Text(original == nil
                         ? "Se la prima volta è nel passato, verranno create anche le spese arretrate."
                         : "Le modifiche valgono per le prossime spese; quelle già create restano come sono.")
                }
                .listRowBackground(Theme.surface)
            }
            .themedListBackground()
            .onAppear { if store.tag(id: tagID) == nil { tagID = nil } }
            .navigationTitle(original == nil ? "Spesa periodica" : "Modifica periodica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { prepareSave() }.fontWeight(.semibold).disabled(cents == nil)
                }
            }
            .confirmationDialog(confirmationTitle, isPresented: Binding(
                get: { pendingCount != nil }, set: { if !$0 { pendingCount = nil } }
            ), titleVisibility: .visible) {
                Button("Crea e salva") { save() }
            }
        }
    }

    private var confirmationTitle: String {
        pendingCount == 1 ? "Verrà creata 1 spesa arretrata" : "Verranno create \(pendingCount ?? 0) spese arretrate"
    }

    private func makeRule() -> RecurringExpense? {
        guard let cents else { return nil }
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        var rule = original ?? RecurringExpense(amountCents: cents, frequency: frequency, startDate: startDate)
        rule.amountCents = cents
        rule.merchant = name.isEmpty ? nil : name
        rule.tagID = tagID
        rule.frequency = frequency
        rule.startDate = startDate
        rule.endDate = hasEndDate ? endDate : nil
        return rule
    }

    private func prepareSave() {
        guard let rule = makeRule() else { return }
        // Arretrate = prima di oggi: l'occorrenza di oggi è normale, non serve conferma.
        let today = Calendar.current.startOfDay(for: .now)
        let normalizedRule = { var r = rule; r.startDate = Calendar.current.startOfDay(for: r.startDate); return r }()
        let count = occurrenceDates(of: normalizedRule, through: today.addingTimeInterval(-1), calendar: .current).count
        if count > 0 { pendingCount = count } else { save() }
    }

    private func save() {
        guard let rule = makeRule() else { return }
        if original == nil { store.addRecurring(rule) } else { store.updateRecurring(rule) }
        store.generateDueRecurring()
        dismiss()
    }
}
