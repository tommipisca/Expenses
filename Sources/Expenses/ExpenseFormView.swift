import SwiftUI
import ExpensesCore

/// Inserimento o modifica di una spesa. Da Wallet arriva precompilata; solo l'importo è obbligatorio.
struct ExpenseFormView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let original: Expense?
    /// Spesa salvata dall'automazione senza aprire l'app: si conferma da qui.
    private let reviewing: Bool
    private let fromWallet: Bool
    private let card: String?
    private let amountWarning: String?

    @State private var amountText: String
    @State private var merchant: String
    @State private var date: Date
    @State private var note: String
    @State private var tagID: UUID?
    /// L'utente ha scelto un tag a mano: il suggerimento per esercente non lo cambia più.
    @State private var tagChosenByUser: Bool
    @State private var showingNewTag = false
    @State private var newTagName = ""
    @State private var confirmingDelete = false
    @FocusState private var amountFocused: Bool

    init(sheet: ExpenseSheet) {
        original = sheet.expense
        reviewing = sheet.expense?.needsReview == true
        let prefill = sheet.prefill
        fromWallet = prefill != nil || reviewing
        card = prefill?.card
        var amount = ""
        var warning: String?
        switch prefill?.amount {
        case .euros(let cents): amount = Formatting.editableAmount(cents)
        case .foreign(let currency): warning = "Pagamento in \(currency): inserisci l'importo in euro"
        case .refund: warning = "Possibile rimborso: inserisci l'importo"
        case .unreadable: warning = "Importo non leggibile: inseriscilo a mano"
        case nil: break
        }
        if let expense = sheet.expense {
            if expense.needsReview, expense.amountCents == 0 {
                warning = "Importo non arrivato in euro: inseriscilo a mano"
            } else {
                amount = Formatting.editableAmount(expense.amountCents)
            }
        }
        amountWarning = warning
        _amountText = State(initialValue: amount)
        _merchant = State(initialValue: sheet.expense?.merchant ?? prefill?.merchant ?? "")
        _date = State(initialValue: sheet.expense?.date ?? .now)
        _note = State(initialValue: sheet.expense?.note ?? "")
        _tagID = State(initialValue: sheet.expense?.tagID)
        _tagChosenByUser = State(initialValue: sheet.expense != nil)
    }

    private var cents: Int? {
        if case .euros(let value) = readAmount(amountText) { value } else { nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if fromWallet {
                        Label(reviewing ? "Salvata da Wallet · da confermare"
                                        : "Compilata da Wallet" + (card.map { " · \($0)" } ?? ""),
                              systemImage: "creditcard")
                            .font(.caption)
                            .foregroundStyle(Color(hex: 0x38BDF8))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(hex: 0x38BDF8).opacity(0.12), in: Capsule())
                            .frame(maxWidth: .infinity)
                    }
                    amountField
                    detailsCard
                    tagSection
                    if original != nil {
                        Button("Elimina spesa", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(reviewing ? "Conferma spesa" : original == nil ? "Nuova spesa" : "Modifica spesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(reviewing ? "Conferma" : "Salva") { save() }.fontWeight(.semibold).disabled(cents == nil)
                }
            }
            .alert("Nuovo tag", isPresented: $showingNewTag) {
                TextField("Nome", text: $newTagName)
                Button("Annulla", role: .cancel) { newTagName = "" }
                Button("Crea") { createTag() }
            }
            .confirmationDialog("Eliminare questa spesa?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    if let original { store.deleteExpense(id: original.id) }
                    dismiss()
                }
            }
            .onAppear {
                if original == nil, cents == nil { amountFocused = true }
                suggestTag()
            }
            .onChange(of: merchant) { suggestTag() }
        }
        .presentationDragIndicator(.visible)
    }

    private var amountField: some View {
        VStack(spacing: 6) {
            Text("Importo").font(.footnote).foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("€").font(.amount(size: 40)).foregroundStyle(Theme.textSecondary)
                TextField("0,00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.amount(size: 56))
                    .fixedSize()
                    .accessibilityLabel("Importo in euro")
            }
            if let amountWarning {
                Label(amountWarning, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(Theme.warning)
                    .multilineTextAlignment(.center)
            } else if !amountText.isEmpty, cents == nil {
                Text("Scrivi l'importo come 12,50").font(.footnote).foregroundStyle(Theme.warning)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            row("Esercente") {
                TextField("Facoltativo", text: $merchant).multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }
            Divider().overlay(Theme.elevated)
            row("Data") {
                DatePicker("Data", selection: $date).labelsHidden()
            }
            Divider().overlay(Theme.elevated)
            row("Nota") {
                TextField("Facoltativa", text: $note).multilineTextAlignment(.trailing)
            }
        }
        .card(padding: 0)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary).frame(width: 90, alignment: .leading)
            Spacer(minLength: 8)
            content()
        }
        .frame(minHeight: 54)
        .padding(.horizontal, 16)
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tag").font(.ui(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            FlowLayout(spacing: 8) {
                ForEach(store.tags) { tag in
                    chip(name: tag.name, colorIndex: tag.colorIndex, selected: tagID == tag.id) {
                        tagChosenByUser = true
                        tagID = tagID == tag.id ? nil : tag.id
                    }
                }
                Button { showingNewTag = true } label: {
                    Label("Nuovo tag", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14).frame(height: 40)
                        .overlay(Capsule().strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4])))
                }
                .foregroundStyle(Theme.textSecondary)
            }
            if !tagChosenByUser, let tagID, let name = store.tag(id: tagID)?.name, !merchant.isEmpty {
                Text("Suggerito: l'ultima volta da \(merchant) hai usato «\(name)».")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func chip(name: String, colorIndex: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        let color = Theme.tagColor(index: colorIndex)
        return Button(action: action) {
            HStack(spacing: 8) {
                TagDot(colorIndex: colorIndex, size: 8)
                Text(name).font(.subheadline.weight(selected ? .semibold : .medium))
                if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(color) }
            }
            .padding(.horizontal, 14).frame(height: 40)
            .background(selected ? color.opacity(0.16) : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(selected ? color : Theme.stroke, lineWidth: 1))
        }
        .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func suggestTag() {
        guard !tagChosenByUser else { return }
        tagID = store.suggestedTagID(forMerchant: merchant)
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        newTagName = ""
        guard !name.isEmpty else { return }
        if let existing = store.tags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            tagID = existing.id
        } else {
            tagID = store.addTag(name: name).id
        }
        tagChosenByUser = true
    }

    private func save() {
        guard let cents else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if var expense = original {
            expense.amountCents = cents
            expense.date = date
            expense.tagID = tagID
            expense.merchant = trimmedMerchant.isEmpty ? nil : trimmedMerchant
            expense.note = trimmedNote.isEmpty ? nil : trimmedNote
            if reviewing { store.confirmExpense(expense) } else { store.updateExpense(expense) }
        } else {
            store.addExpense(Expense(amountCents: cents, date: date, tagID: tagID,
                                     merchant: trimmedMerchant.isEmpty ? nil : trimmedMerchant,
                                     note: trimmedNote.isEmpty ? nil : trimmedNote,
                                     source: fromWallet ? .wallet : .manual))
        }
        dismiss()
    }
}
