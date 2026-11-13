import XCTest
import AppKit
@testable import Taskovsky

@MainActor
final class SearchDateFormTests: XCTestCase {
    func testEmptyFormKeyLoopExcludesDisabledControls() {
        let form = SearchDateFormView()
        form.update(SearchCustomDateDraft(from: .distantPast, hasFrom: false, to: .distantFuture, hasTo: false))
        XCTAssertTrue(form.fromToggle.nextKeyView === form.toToggle)
        XCTAssertTrue(form.toToggle.nextKeyView === form.cancel)
        XCTAssertTrue(form.cancel.nextKeyView === form.fromToggle)
        XCTAssertFalse(form.confirm.canBecomeKeyView)
        XCTAssertTrue(form.fromToggle.canBecomeKeyView)
    }
    func testBothBoundsHaveCompleteCircularKeyLoop() {
        let form = SearchDateFormView()
        form.update(SearchCustomDateDraft(from: .distantPast, hasFrom: true, to: .distantFuture, hasTo: true))
        let expected: [NSView] = [form.fromToggle, form.fromDate, form.toToggle, form.toDate, form.cancel, form.confirm]
        XCTAssertEqual(form.orderedKeyViews.count, expected.count)
        for i in expected.indices { XCTAssertTrue(expected[i].nextKeyView === expected[(i + 1) % expected.count]) }
    }
    func testToggleUpdatesDraftAndLoopWithoutApplying() {
        let form = SearchDateFormView()
        form.update(SearchCustomDateDraft(from: .distantPast, hasFrom: false, to: .distantFuture, hasTo: false))
        var changed: SearchCustomDateDraft?
        var applied = false
        form.onChange = { changed = $0 }; form.onApply = { _ in applied = true }
        form.fromToggle.performClick(nil)
        XCTAssertEqual(changed?.hasFrom, true)
        XCTAssertFalse(applied)
        XCTAssertTrue(form.fromToggle.nextKeyView === form.fromDate)
        XCTAssertTrue(form.confirm.isEnabled)
    }
    func testNativeButtonsApplyOrCancelWithoutMutatingDateValues() {
        let form = SearchDateFormView()
        let draft = SearchCustomDateDraft(from: .distantPast, hasFrom: true, to: .distantFuture, hasTo: false)
        form.update(draft)
        var applied: SearchCustomDateDraft?
        var canceled = false
        form.onApply = { applied = $0 }; form.onCancel = { canceled = true }
        form.cancel.performClick(nil)
        XCTAssertTrue(canceled); XCTAssertNil(applied)
        form.confirm.performClick(nil)
        XCTAssertEqual(applied, draft)
    }
}
