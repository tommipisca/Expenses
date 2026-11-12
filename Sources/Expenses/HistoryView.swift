import SwiftUI
import ExpensesCore

/// Storico per anni e mesi, con ricerca e filtro su uno o più tag.
struct HistoryView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = HistoryQuery(year: .year(Calendar.current.component(.year, from: .now)))
    @State private var pendingDelete: Expense?
    @Environment(\.isWideLayout) private var isWide

    var body: some View {
        let result = history(expenses: store.expenses, tags: store.tags, query: query, calendar: .current)
        NavigationStack {
            Group {
                if isWide {
                    // iPad in orizzontale: filtri e riepilogo sempre visibili a sinistra, spese a destra.
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView {
                            sidebarFilters(result)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                        .floatingTabBarClearance()
                        .frame(width: 340)
                        expenseList(result, showsFilters: false)
                    }
                    .background(Theme.background)
                } else {
                    expenseList(result, showsFilters: true)
                }
            }
            .navigationTitle("Storico")
            .searchable(text: $query.text, prompt: "Esercente, nota o importo")
            .confirmationDialog("Eliminare questa spesa?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    if let pendingDelete { store.deleteExpense(id: pendingDelete.id) }
                }
            }
        }
        .onAppear(perform: consumePendingQuery)
        .onChange(of: router.pendingHistoryQuery) { consumePendingQuery() }
    }

    private func expenseList(_ result: HistoryResult, showsFilters: Bool) -> some View {
        List {
            if showsFilters {
                Section {
                    filters
                    summaryRow(result)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }

            if result.count == 0 {
                ContentUnavailableView(query.text.isEmpty ? "Nessuna spesa" : "Nessun risultato",
                                       systemImage: "magnifyingglass",
                                       description: Text("Prova a cambiare anno, tag o ricerca."))
                    .listRowBackground(Color.clear)
            }

            ForEach(result.months) { month in
                Section {
                    ForEach(month.expenses) { expense in
                        Button { router.edit(expense) } label: { ExpenseRow(expense: expense) }
                            .listRowBackground(Theme.surface)
                            .swipeActions {
                                Button("Elimina", systemImage: "trash", role: .destructive) { pendingDelete = expense }
                            }
                    }
                } header: {
                    HStack {
                        Text(Formatting.monthTitle(month.id))
                        Spacer()
                        Text(Money.format(month.totalCents)).monospacedDigit()
                    }
                    .sectionHeaderStyle()
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedListBackground()
        .floatingTabBarClearance()
    }

    /// Colonna dei filtri per l'iPad in orizzontale: anno, mese, tag e riepilogo, con i chip che vanno a capo.
    private func sidebarFilters(_ result: HistoryResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryRow(result)
            VStack(alignment: .leading, spacing: 8) {
                Text("Anno").sectionHeaderStyle()
                FlowLayout(spacing: 8) {
                    ForEach(availableYears(expenses: store.expenses, calendar: .current), id: \.self) { year in
                        FilterChip(title: String(year), colorIndex: nil, selected: query.year == .year(year)) {
                            query.year = .year(year)
                            if let month = query.month, month.year != year { query.month = nil }
                        }
                    }
                    FilterChip(title: "Tutti", colorIndex: nil, selected: query.year == .all) { query.year = .all }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Mese").sectionHeaderStyle()
                monthMenu
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Tag").sectionHeaderStyle()
                FlowLayout(spacing: 8) {
                    ForEach(store.tags) { tag in
                        tagChip(id: tag.id, name: tag.name, colorIndex: tag.colorIndex)
                    }
                    tagChip(id: nil, name: TagSlice.untaggedName, colorIndex: nil)
                }
            }
        }
    }

    private func consumePendingQuery() {
        guard let pending = router.pendingHistoryQuery else { return }
        router.pendingHistoryQuery = nil
        query = HistoryQuery(text: "", tagIDs: pending.tagIDs, year: .all, month: pending.month)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    monthMenu
                    ForEach(availableYears(expenses: store.expenses, calendar: .current), id: \.self) { year in
                        FilterChip(title: String(year), colorIndex: nil, selected: query.year == .year(year)) {
                            query.year = .year(year)
                            if let month = query.month, month.year != year { query.month = nil }
                        }
                    }
                    FilterChip(title: "Tutti", colorIndex: nil, selected: query.year == .all) { query.year = .all }
                }
            }
            .scrollIndicators(.hidden)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.tags) { tag in
                        tagChip(id: tag.id, name: tag.name, colorIndex: tag.colorIndex)
                    }
                    tagChip(id: nil, name: TagSlice.untaggedName, colorIndex: nil)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Menu per filtrare un mese (dell'anno scelto); con un mese attivo mostra il mese e una x per toglierlo.
    private var monthMenu: some View {
        Menu {
            if query.month != nil {
                Button("Tutti i mesi", systemImage: "xmark") { query.month = nil }
            }
            ForEach(availableMonths(expenses: store.expenses, year: query.year, calendar: .current)) { month in
                Button(Formatting.monthTitle(month)) {
                    query.month = month
                    if query.year != .all { query.year = .year(month.year) }
                }
            }
        } label: {
            let selected = query.month != nil
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.caption)
                Text(query.month.map(Formatting.monthTitle) ?? "Mese").font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(selected ? Theme.accent.opacity(0.16) : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(selected ? Theme.accent : Theme.stroke, lineWidth: 1))
            .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
        }
        .accessibilityLabel(query.month.map { "Mese: \(Formatting.monthTitle($0))" } ?? "Filtra per mese")
    }

    private func tagChip(id: UUID?, name: String, colorIndex: Int?) -> some View {
        FilterChip(title: name, colorIndex: colorIndex, showsDot: true, selected: query.tagIDs.contains(id)) {
            if query.tagIDs.contains(id) { query.tagIDs.remove(id) } else { query.tagIDs.insert(id) }
        }
    }

    private func summaryRow(_ result: HistoryResult) -> some View {
        HStack {
            Text(summaryText(result)).font(.footnote).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(Money.format(result.totalCents)).font(.rounded(.headline, weight: .semibold)).monospacedDigit()
        }
        .card(padding: 14)
    }

    private func summaryText(_ result: HistoryResult) -> String {
        var parts: [String] = []
        if !query.tagIDs.isEmpty { parts.append(query.tagIDs.count == 1 ? "1 tag" : "\(query.tagIDs.count) tag") }
        switch query.year {
        case .all: parts.append("tutti gli anni")
        case .year(let year): parts.append(String(year))
        }
        parts.append(result.count == 1 ? "1 spesa" : "\(result.count) spese")
        return parts.joined(separator: " · ")
    }
}

/// Riga di una spesa: tag colorato, titolo, dettagli e importo.
struct ExpenseRow: View {
    @Environment(ExpenseStore.self) private var store
    let expense: Expense

    var body: some View {
        let tag = store.tag(id: expense.tagID)
        let color = Theme.tagColor(index: tag?.colorIndex)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay(TagDot(colorIndex: tag?.colorIndex))
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant ?? expense.note ?? tag?.name ?? "Spesa")
                    .font(.body.weight(.medium)).lineLimit(1)
                Text(details(tag: tag)).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Money.format(expense.amountCents)).font(.rounded(.body, weight: .semibold)).monospacedDigit()
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 2)
    }

    private func details(tag: ExpensesCore.Tag?) -> String {
        var parts = [tag?.name ?? TagSlice.untaggedName, Formatting.shortDate(expense.date)]
        if expense.needsReview { parts.insert("Da confermare", at: 0) }
        switch expense.source {
        case .wallet: parts.append("Wallet")
        case .recurring: parts.append("Periodica")
        case .manual: break
        }
        if expense.merchant != nil, let note = expense.note { parts.append(note) }
        return parts.joined(separator: " · ")
    }
}

/// Chip selezionabile dei filtri.
struct FilterChip: View {
    let title: String
    var systemImage: String?
    let colorIndex: Int?
    var showsDot = false
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let color = showsDot ? Theme.tagColor(index: colorIndex) : Theme.accent
        Button(action: action) {
            HStack(spacing: 6) {
                if showsDot { TagDot(colorIndex: colorIndex, size: 8) }
                Text(title).font(.subheadline.weight(.medium))
                if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(selected ? color.opacity(0.16) : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(selected ? color : Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
