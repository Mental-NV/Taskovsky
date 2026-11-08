import AppKit
import XCTest
@testable import TaskovskyCore

/// Block-selection boundary policy: a nonempty `NSRange` has an exclusive
/// end, so the last paragraph resolves from the final INCLUDED UTF-16 unit.
/// A selection ending right after "\n" must not swallow the next,
/// unselected paragraph. These tests drive the `RichMutate.blockRange`
/// policy the editor's `paragraphRange()` delegates to — including the
/// production toggle path on a real `NSTextView` selection.
final class BlockRangeTests: XCTestCase {
    func testSelectionEndingBeforeNewlineCoversFirstParagraph() {
        let string = "First\nSecond" as NSString
        // "First" without the newline: the whole first paragraph.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 5), in: string),
                       NSRange(location: 0, length: 6))
    }

    func testSelectionEndingAfterNewlineExcludesNextParagraph() {
        let string = "First\nSecond" as NSString
        // "First\n": ends exactly at the start of "Second" — the fix.
        // The old policy resolved the end position to the second paragraph
        // and unioned it in ({0,12}).
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 6), in: string),
                       NSRange(location: 0, length: 6))
    }

    func testSelectionIntoFollowingParagraphCoversBoth() {
        let string = "First\nSecond" as NSString
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 8), in: string),
                       NSRange(location: 0, length: 12))
    }

    func testFullDocumentSelectionCoversAll() {
        let string = "First\nSecond" as NSString
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 12), in: string),
                       NSRange(location: 0, length: 12))
    }

    func testSelectionEndingAtEOFStaysInLastParagraph() {
        let string = "First\n" as NSString
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 6), in: string),
                       NSRange(location: 0, length: 6))
    }

    func testCollapsedCaretKeepsCaretParagraph() {
        let string = "First\nSecond" as NSString
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 2, length: 0), in: string),
                       NSRange(location: 0, length: 6))
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 7, length: 0), in: string),
                       NSRange(location: 6, length: 6))
    }

    func testExactEOFCaretKeepsLastParagraph() {
        let string = "First\n" as NSString
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 6, length: 0), in: string),
                       NSRange(location: 0, length: 6))
    }

    func testMultipleParagraphs() {
        let string = "A\nB\nC" as NSString
        // "A\nB\n": first two paragraphs, not C.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 4), in: string),
                       NSRange(location: 0, length: 4))
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 5), in: string),
                       NSRange(location: 0, length: 5))
        // Middle paragraph only.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 2, length: 1), in: string),
                       NSRange(location: 2, length: 2))
    }

    func testEmojiUTF16Boundaries() {
        // A(0) + emoji(1,2) + \n(3) + B(4).
        let string = "A😀\nB" as NSString
        XCTAssertEqual(string.length, 5)
        // Through the emoji, before the newline: whole first paragraph.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 3), in: string),
                       NSRange(location: 0, length: 4))
        // Including the newline: still only the first paragraph.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 4), in: string),
                       NSRange(location: 0, length: 4))
        // Caret at the start of B: second paragraph.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 4, length: 0), in: string),
                       NSRange(location: 4, length: 1))
    }

    func testEmptyString() {
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: 0), in: "" as NSString),
                       NSRange(location: 0, length: 0))
    }

    func testNotFoundLocationClampsWithoutTrapping() {
        let string = "First\nSecond" as NSString
        // NSNotFound caret: last paragraph, no integer-overflow trap.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: NSNotFound, length: 0), in: string),
                       NSRange(location: 6, length: 6))
        // NSNotFound span from a valid start: the whole string.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: NSNotFound), in: string),
                       NSRange(location: 0, length: 12))
        // Both ends unknown: the last paragraph.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: NSNotFound, length: NSNotFound), in: string),
                       NSRange(location: 6, length: 6))
    }

    func testOversizedAndNegativeBoundsClamp() {
        let string = "First\nSecond" as NSString
        // Oversized length from a valid start: the whole string, no trap.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 0, length: Int.max - 3), in: string),
                       NSRange(location: 0, length: 12))
        // Past-the-end location with a span: the last paragraph.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: 12, length: 5), in: string),
                       NSRange(location: 6, length: 6))
        // Negative location: from the string head.
        XCTAssertEqual(RichMutate.blockRange(for: NSRange(location: -5, length: 3), in: string),
                       NSRange(location: 0, length: 6))
    }

    /// Production path: a real text view with "First\n" selected applies a
    /// block toggle through the shared policy exactly as the controller
    /// does — the second paragraph keeps its styling.
    func testProductionTogglePathLeavesNextParagraphAlone() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSAttributedString(string: "First\nSecond"))
        view.setSelectedRange(NSRange(location: 0, length: 6))
        let storage = view.textStorage!
        let range = RichMutate.blockRange(for: view.selectedRange(), in: view.string as NSString)
        XCTAssertEqual(range, NSRange(location: 0, length: 6))
        RichMutate.toggleQuote(in: storage, range: range)
        XCTAssertEqual(storage.attribute(RichRender.quoteKey, at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertNil(storage.attribute(RichRender.quoteKey, at: 7, effectiveRange: nil))
        // Toggling again with the same selection clears the first paragraph.
        let range2 = RichMutate.blockRange(for: view.selectedRange(), in: view.string as NSString)
        RichMutate.toggleQuote(in: storage, range: range2)
        XCTAssertNil(storage.attribute(RichRender.quoteKey, at: 0, effectiveRange: nil))
    }
}
