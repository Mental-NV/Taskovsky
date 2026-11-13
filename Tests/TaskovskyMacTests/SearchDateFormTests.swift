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
            // Auto Layout uses alignment rectangles, not decorative button
            // frame margins (which overlap on macOS 15 rounded buttons).
            let alignment = controls.map { control in
                control.superview!.convert(control.alignmentRect(forFrame: control.frame), to: form)
            }
            for i in alignment.indices {
                for j in alignment.indices where j > i {
                    XCTAssertFalse(alignment[i].intersects(alignment[j]), "Alignment overlap: \(i), \(j)")
                }
            }
            if enabled {
                for index in [4, 5] {
                    let rect = alignment[index].insetBy(dx: 1, dy: 1)
                    for x in [rect.minX, rect.midX, rect.maxX] {
                        let point = NSPoint(x: x, y: rect.midY)
                        let hit = form.hitTest(point)
                        XCTAssertTrue(hit === controls[index] || hit?.isDescendant(of: controls[index]) == true,
                                      "Wrong footer hit at \(point): \(String(describing: hit))")
                    }
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
