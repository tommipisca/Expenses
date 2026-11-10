import Testing
@testable import ExpensesCore

@Suite struct PaletteTests {
    @Test func tagColorsAreDistinct() {
        #expect(Set(Palette.tagColors).count == Palette.tagColors.count)
        #expect(Palette.tagColors.count == 14)
    }

    @Test func balancedColorPicksLeastUsed() {
        #expect(Palette.balancedColorIndex(used: []) == 0)
        #expect(Palette.balancedColorIndex(used: [0, 0, 1]) == 2)
    }
}
