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

    @Test func timedCardBoundariesWithWidthDependentGrip() {
        // CalendarTimedBlock uses min(18, width / 3) for schedulable entries.
        // At these widths grip is still growing, unlike the fixed-inset tests.
        for (compact, boundary) in [(true, 51.0), (false, 52.5)] {
            let below = boundary - 0.125
            let above = boundary + 0.125
            #expect(!CalendarCardLayout.showsCompletionCheckbox(
                cardWidth: below, trailingInset: min(18, below / 3), compact: compact
            ))
            #expect(CalendarCardLayout.showsCompletionCheckbox(
                cardWidth: boundary, trailingInset: min(18, boundary / 3), compact: compact
            ))
            #expect(CalendarCardLayout.showsCompletionCheckbox(
                cardWidth: above, trailingInset: min(18, above / 3), compact: compact
            ))
        }
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

    @Test func startResizeGripClearsTheCheckboxAtNarrowAndWideWidths() {
        let checkboxEnd = CalendarCardLayout.horizontalPadding / 2 + CalendarCardLayout.completionIconWidth
        for cardWidth in [49.0, 51, 52.5, 55, 124] {
            let moveWidth = min(18, cardWidth / 3)
            let grip = CalendarCardLayout.startResizeGrip(
                cardWidth: cardWidth, trailingInset: moveWidth, height: 9, protectsCompletion: true
            )
            #expect(grip.leading > checkboxEnd)
            #expect(grip.leading + grip.width <= cardWidth - moveWidth)
            #expect(grip.height == 9)
        }
    }

    @Test func startResizeGripKeepsTheCenteredBaselineAndFitsVeryThinLanes() {
        let wide = CalendarCardLayout.startResizeGrip(
            cardWidth: 124, trailingInset: 18, height: 9, protectsCompletion: true
        )
        #expect(wide.leading == 42)
        #expect(wide.width == 22)

        let note = CalendarCardLayout.startResizeGrip(
            cardWidth: 55, trailingInset: 18, height: 9, protectsCompletion: false
        )
        #expect(note.leading == 7.5)
        #expect(note.width == 22)
        #expect(note.height == 9)

        let thin = CalendarCardLayout.startResizeGrip(
            cardWidth: 18, trailingInset: 6, height: 7.5, protectsCompletion: true
        )
        #expect(thin.leading == 0)
        #expect(thin.width == 12)
        #expect(thin.height == 2)
    }
}
