import Testing
@testable import TaskovskyCore

@Suite struct CalendarCardLayoutTests {
    @Test func normalBoundaryUsesContentAfterPaddingAndGrip() {
        // 8 padding + 18 grip + 10 icon + 5 gap + 12 title em = 53.
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 52.99, trailingInset: 18))
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 53, trailingInset: 18))
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 53.01, trailingInset: 18))
    }

    @Test func compactBoundaryUsesCompactTitleEm() {
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 51.99, trailingInset: 18, compact: true))
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 52, trailingInset: 18, compact: true))
    }

    @Test func actualGripChangesAvailableSpace() {
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 37))
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 37, trailingInset: 37.0 / 3))
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 22, trailingInset: 22.0 / 3))
    }

    @Test func wideningRestoresWithoutPersistentState() {
        for _ in 0..<3 {
            #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 80, trailingInset: 18))
            #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 22, trailingInset: 22.0 / 3))
            #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 80, trailingInset: 18))
        }
    }

    @Test func savedPreferenceAndTemporaryOptionAreIndependent() {
        for width in [0.0, 22, 80] {
            #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: width, iconsEnabled: false))
            #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: width, iconsEnabled: false, forceReveal: true))
            #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: width, iconsEnabled: false, forceReveal: false))
        }
    }

    @Test func unmeasuredSurfacesRetainExistingBehavior() {
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: nil))
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: nil, iconsEnabled: false))
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: nil, iconsEnabled: false, forceReveal: true))
    }

    @Test func invalidOrExhaustedAllocationDoesNotExposeCheckbox() {
        for width in [-1.0, 0, .nan, .infinity] {
            #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: width))
        }
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 80, trailingInset: 100))
        #expect(!CalendarCardLayout.showsCompletionCheckbox(cardWidth: 80, trailingInset: .nan))
        #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 35, trailingInset: -10))
    }

    @Test func wideCardBaselineIsUnaffected() {
        for compact in [false, true] {
            #expect(CalendarCardLayout.showsCompletionCheckbox(cardWidth: 240, trailingInset: 18, compact: compact))
        }
    }
}
