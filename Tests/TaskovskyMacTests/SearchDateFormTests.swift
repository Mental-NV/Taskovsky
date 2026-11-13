import XCTest
import AppKit
@testable import Taskovsky

@MainActor
final class SearchDateFormTests: XCTestCase {
    func testNativeControlsFitFixedPopoverContentBounds() {
        let form = SearchDateFormView(frame: NSRect(x: 0, y: 0, width: 320, height: 174))
        for enabled in [false, true] {
            form.update(SearchCustomDateDraft(from: .now, hasFrom: enabled, to: .now, hasTo: enabled))
            form.layoutSubtreeIfNeeded()
            let controls: [NSView] = [form.fromToggle, form.fromDate, form.toToggle, form.toDate, form.cancel, form.confirm]
            let frames = controls.map { $0.convert($0.bounds, to: form) }
            for frame in frames {
                XCTAssertGreaterThan(frame.width, 0)
                XCTAssertGreaterThan(frame.height, 0)
                XCTAssertTrue(form.bounds.contains(frame), "Control outside form: \(frame)")
            }
            for i in frames.indices {
                for j in frames.indices where j > i {
                    XCTAssertFalse(frames[i].intersects(frames[j]), "Controls overlap: \(i), \(j); frames=\(frames[i]),\(frames[j]); alignment=\(controls[i].alignmentRect(forFrame: controls[i].frame)),\(controls[j].alignmentRect(forFrame: controls[j].frame)); insets=\(controls[i].alignmentRectInsets),\(controls[j].alignmentRectInsets)")
                }
            }
        }
    }
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
