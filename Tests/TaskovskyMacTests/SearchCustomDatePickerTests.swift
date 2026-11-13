import XCTest
@testable import Taskovsky

final class SearchCustomDatePickerTests: XCTestCase {
    func testEmptyDraftCannotConfirmAndHasNoBounds() {
        let draft = SearchCustomDateDraft(from: .distantPast, hasFrom: false, to: .distantFuture, hasTo: false)
        XCTAssertFalse(draft.canConfirm)
        XCTAssertNil(draft.lowerBound); XCTAssertNil(draft.upperBound)
    }
    func testEachOneSidedRangeCanConfirm() {
        var draft = SearchCustomDateDraft(from: .distantPast, hasFrom: true, to: .distantFuture, hasTo: false)
        XCTAssertTrue(draft.canConfirm); XCTAssertEqual(draft.lowerBound, .distantPast); XCTAssertNil(draft.upperBound)
        draft.hasFrom = false; draft.hasTo = true
        XCTAssertTrue(draft.canConfirm); XCTAssertNil(draft.lowerBound); XCTAssertEqual(draft.upperBound, .distantFuture)
    }
    func testCanceledCopyDoesNotChangeAppliedBoundsAndRetainsInactiveDates() {
        let applied = SearchCustomDateDraft(from: .distantPast, hasFrom: true, to: .distantFuture, hasTo: true)
        var draft = applied
        draft.hasFrom = false; draft.to = .now
        XCTAssertEqual(applied.lowerBound, .distantPast); XCTAssertEqual(applied.upperBound, .distantFuture)
        draft.hasFrom = true
        XCTAssertEqual(draft.lowerBound, .distantPast)
    }
    func testInvertedRangeIsNotSilentlyReordered() {
        let draft = SearchCustomDateDraft(from: .distantFuture, hasFrom: true, to: .distantPast, hasTo: true)
        XCTAssertTrue(draft.canConfirm)
        XCTAssertEqual(draft.lowerBound, .distantFuture); XCTAssertEqual(draft.upperBound, .distantPast)
    }
}
