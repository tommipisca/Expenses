import Foundation
import Testing
@testable import ExpensesCore

@Suite struct HistoryTests {
    let spesa = Tag(name: "Spesa")
    let ristoranti = Tag(name: "Ristoranti")
    let casa = Tag(name: "Casa")
    var tags: [Tag] { [spesa, ristoranti, casa] }

    var expenses: [Expense] {
        [
            Expense(amountCents: 6430, date: date(2026, 11, 9), tagID: spesa.id, merchant: "Esselunga"),
            Expense(amountCents: 3800, date: date(2026, 11, 7), tagID: ristoranti.id, merchant: "Pizzeria da Gino"),
            Expense(amountCents: 1250, date: date(2026, 10, 28), tagID: casa.id, note: "Caffè e cornetti"),
            Expense(amountCents: 900, date: date(2026, 10, 2), tagID: nil, merchant: "Edicola"),
            Expense(amountCents: 4000, date: date(2025, 12, 20), tagID: UUID(), merchant: "Regali"),
        ]
    }

    func run(_ text: String = "", tags tagIDs: Set<UUID?> = [], year: YearFilter = .all, month: MonthKey? = nil) -> HistoryResult {
        history(expenses: expenses, tags: tags, query: HistoryQuery(text: text, tagIDs: tagIDs, year: year, month: month),
                calendar: rome)
    }

    @Test func groupsByMonthDescending() {
        let result = run()
        #expect(result.months.map(\.id) == [MonthKey(year: 2026, month: 11), MonthKey(year: 2026, month: 10),
                                            MonthKey(year: 2025, month: 12)])
        #expect(result.months[0].expenses.map(\.merchant) == ["Esselunga", "Pizzeria da Gino"])
        #expect(result.months[0].totalCents == 10230)
        #expect(result.count == 5)
        #expect(result.totalCents == 16380)
    }

    @Test func multipleTagsAreUnion() {
        let result = run(tags: [spesa.id, ristoranti.id])
        #expect(result.count == 2)
        #expect(result.totalCents == 10230)
    }

    @Test func untaggedFilterIncludesDeletedTags() {
        let result = run(tags: [nil])
        #expect(Set(result.months.flatMap(\.expenses).map(\.merchant)) == ["Edicola", "Regali"])
    }

    @Test func searchIgnoresCaseAndAccents() {
        #expect(run("esselunga").count == 1)
        #expect(run("caffe").count == 1)
        #expect(run("ristor").count == 1)
    }

    @Test func searchByAmount() {
        #expect(run("12,50").months.flatMap(\.expenses).map(\.amountCents) == [1250])
    }

    @Test func filtersByYearAndMonth() {
        #expect(run(year: .year(2025)).count == 1)
        #expect(run(year: .year(2026)).count == 4)
        #expect(run(month: MonthKey(year: 2026, month: 10)).count == 2)
    }

    @Test func listsYearsDescending() {
        #expect(availableYears(expenses: expenses, calendar: rome) == [2026, 2025])
    }
}
