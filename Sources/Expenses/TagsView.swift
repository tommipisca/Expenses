import SwiftUI
import ExpensesCore

/// Elenco dei tag con totale del mese corrente ed eventuale budget.
struct TagsView: View {
    @Environment(ExpenseStore.self) private var store
    @State private var editing: TagSheet?
    @Environment(\.isWideLayout) private var isWide

    struct TagSheet: Identifiable {
        let id = UUID()
        var tag: ExpensesCore.Tag?
    }

    var body: some View {
        let month = store.currentMonth
        let summary = store.summary(for: month)
        let statuses = store.budgetStatuses(for: month)
        NavigationStack {
            Group {
                if isWide, !store.tags.isEmpty {
                    grid(month: month, summary: summary, statuses: statuses)
                } else {
                    list(month: month, summary: summary, statuses: statuses)
                }
            }
            .navigationTitle("Tag")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { editing = TagSheet(tag: nil) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Nuovo tag")
                }
            }
            .sheet(item: $editing) { sheet in TagFormView(tag: sheet.tag) }
        }
    }

    private func list(month: MonthKey, summary: MonthSummary, statuses: [BudgetStatus]) -> some View {
        List {
            if store.tags.isEmpty {
                ContentUnavailableView("Nessun tag", systemImage: "tag",
                                       description: Text("Crea i tag con cui dividere le spese, ad esempio Casa, Spesa, Svago."))
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(store.tags) { tag in
                    Button { editing = TagSheet(tag: tag) } label: {
                        row(tag, cents: summary.slices.first { $0.id == tag.id }?.cents ?? 0,
                            budget: statuses.first { $0.target == .tag(tag.id) })
                    }
                    .listRowBackground(Theme.surface)
                }
            } header: {
                if !store.tags.isEmpty {
                    Text("Spese di \(Formatting.monthName(month))").sectionHeaderStyle()
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedListBackground()
    }

    /// iPad in orizzontale: un riquadro per tag, tre per riga.
    private func grid(month: MonthKey, summary: MonthSummary, statuses: [BudgetStatus]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spese di \(Formatting.monthName(month))").sectionHeaderStyle()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(store.tags) { tag in
                        Button { editing = TagSheet(tag: tag) } label: {
                            tile(tag, cents: summary.slices.first { $0.id == tag.id }?.cents ?? 0,
                                 budget: statuses.first { $0.target == .tag(tag.id) })
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
    }

    private func tile(_ tag: ExpensesCore.Tag, cents: Int, budget: BudgetStatus?) -> some View {
        let color = Theme.tagColor(index: tag.colorIndex)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 34)
                    .overlay(TagDot(colorIndex: tag.colorIndex, size: 12))
                Text(tag.name).font(.body.weight(.semibold)).lineLimit(1)
            }
            Text(Money.format(cents)).font(.rounded(.title2, weight: .bold)).monospacedDigit()
            if let budget {
                VStack(alignment: .leading, spacing: 6) {
                    Text("di \(Money.format(budget.limitCents))").font(.caption).foregroundStyle(Theme.textSecondary)
                    ProgressLine(fraction: budget.fraction, color: Theme.budgetColor(fraction: budget.fraction))
                }
            } else {
                Text("Nessun budget").font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .card()
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Modifica il tag")
    }

    private func row(_ tag: ExpensesCore.Tag, cents: Int, budget: BudgetStatus?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TagDot(colorIndex: tag.colorIndex, size: 12)
                Text(tag.name).font(.body.weight(.medium))
                Spacer()
                Text(Money.format(cents)).font(.rounded(.body, weight: .semibold)).monospacedDigit()
            }
            if let budget {
                HStack {
                    ProgressLine(fraction: budget.fraction, color: Theme.budgetColor(fraction: budget.fraction))
                    Text("di \(Money.format(budget.limitCents))").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                .padding(.leading, 24)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 4)
    }
}

/// Crea o modifica un tag: nome, colore, budget facoltativo.
struct TagFormView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(BudgetNotifier.self) private var notifier
    @Environment(\.dismiss) private var dismiss

    private let original: ExpensesCore.Tag?
    @State private var name: String
    @State private var colorIndex: Int
    @State private var hasBudget: Bool
    @State private var budgetText: String
    @State private var confirmingDelete = false

    init(tag: ExpensesCore.Tag?) {
        original = tag
        _name = State(initialValue: tag?.name ?? "")
        _colorIndex = State(initialValue: tag?.colorIndex ?? -1)
        _hasBudget = State(initialValue: tag?.budgetCents != nil)
        _budgetText = State(initialValue: tag?.budgetCents.map(Formatting.editableAmount) ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var nameIsTaken: Bool {
        store.tags.contains { $0.id != original?.id && $0.name.lowercased() == trimmedName.lowercased() }
    }

    private var budgetCents: Int? {
        if case .euros(let cents) = readAmount(budgetText) { cents } else { nil }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !nameIsTaken && (!hasBudget || budgetCents != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $name).textInputAutocapitalization(.sentences)
                } footer: {
                    if nameIsTaken { Text("Esiste già un tag con questo nome.").foregroundStyle(Theme.warning) }
                }
                .listRowBackground(Theme.surface)

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(Theme.tagPalette.indices, id: \.self) { index in
                            Button { colorIndex = index } label: {
                                Circle().fill(Theme.tagPalette[index])
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Theme.textPrimary, lineWidth: colorIndex == index ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colore \(index + 1)")
                            .accessibilityAddTraits(colorIndex == index ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Colore").sectionHeaderStyle()
                }
                .listRowBackground(Theme.surface)

                Section {
                    Toggle("Budget mensile", isOn: $hasBudget.animation())
                    if hasBudget {
                        HStack {
                            Text("Importo")
                            Spacer()
                            TextField("0,00", text: $budgetText).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).monospacedDigit()
                            Text("€").foregroundStyle(Theme.textSecondary)
                        }
                    }
                } footer: {
                    Text("Facoltativo. Ricevi un avviso all'80% e al superamento.")
                }
                .listRowBackground(Theme.surface)

                if original != nil {
                    Section {
                        Button("Elimina tag", role: .destructive) { confirmingDelete = true }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themedListBackground()
            .onAppear {
                if colorIndex < 0 { colorIndex = Palette.balancedColorIndex(used: store.tags.map(\.colorIndex)) }
            }
            .navigationTitle(original == nil ? "Nuovo tag" : "Modifica tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
            .confirmationDialog("Eliminare il tag «\(original?.name ?? "")»?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    if let original { store.deleteTag(id: original.id) }
                    dismiss()
                }
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var deleteMessage: String {
        let count = store.expenses.filter { $0.tagID == original?.id }.count
        return count == 0 ? "Nessuna spesa usa questo tag."
            : count == 1 ? "La spesa con questo tag resterà, senza tag."
            : "Le \(count) spese con questo tag resteranno, senza tag."
    }

    private func save() {
        let budget = hasBudget ? budgetCents : nil
        if var tag = original {
            tag.name = trimmedName
            tag.colorIndex = colorIndex >= 0 ? colorIndex : tag.colorIndex
            tag.budgetCents = budget
            store.updateTag(tag)
        } else {
            var tag = store.addTag(name: trimmedName)
            if colorIndex >= 0 || budget != nil {
                if colorIndex >= 0 { tag.colorIndex = colorIndex }
                tag.budgetCents = budget
                store.updateTag(tag)
            }
        }
        if budget != nil { Task { await notifier.requestAuthorizationIfNeeded() } }
        dismiss()
    }
}
