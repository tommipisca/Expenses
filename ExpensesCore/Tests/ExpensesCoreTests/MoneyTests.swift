import Testing
@testable import ExpensesCore

@Suite struct MoneyTests {
    @Test(arguments: [
        (0, "€ 0,00"), (5, "€ 0,05"), (124860, "€ 1.248,60"), (100000000, "€ 1.000.000,00"), (99999, "€ 999,99"),
    ])
    func formats(cents: Int, expected: String) {
        #expect(Money.format(cents) == expected)
    }

    @Test func formatsNegative() {
        #expect(Money.format(-1250) == "−€ 12,50")
    }

    @Test func splitsParts() {
        #expect(Money.formatParts(124860) == ("€ 1.248", ",60"))
    }
}
