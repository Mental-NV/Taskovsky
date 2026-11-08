import AppKit
import XCTest
@testable import TaskovskyCore

/// Empty-editor Quote toggle: on -> off -> type is plain. The controller
/// cannot be imported by tests (app target), so these tests drive the exact
/// production policy and transforms the controller calls — the armed-state
/// decision plus the shared arm/disarm typing transforms — against real
/// `NSTextView` typing state, mirroring the controller's call order (empty
/// document and trailing empty paragraph), with undo/redo and pending-list
/// transitions. This is not a live controller verification: the UndoManager
/// grouping here mirrors `setTyping`'s discipline, and the one-line
/// controller wiring (check-then-disarm vs arm) stays reviewable — the
/// parent exercises the real toolbar taps in the QA app.
final class QuoteToggleTests: XCTestCase {
    /// Undo-grouped typing assignment mirroring `setTyping`'s discipline
    /// (before/after snapshots with an inverse registration, foreground
    /// color assignment, pending tri-state applied alongside).
    final class PendingBox { var value: RichListStyle?? = nil }

    private func setUndoableTyping(_ view: NSTextView, _ attrs: [NSAttributedString.Key: Any],
                                   box: PendingBox, _ update: RichListStyle??,
                                   _ undo: UndoManager) {
        let before = view.typingAttributes
        let pendingBefore: RichListStyle?? = box.value
        if let update { box.value = update }
        let pendingAfter: RichListStyle?? = box.value
        undo.beginUndoGrouping()
        var next = attrs
        next[.foregroundColor] = NSColor.labelColor
        view.typingAttributes = next
        let after = next
        undo.registerUndo(withTarget: view) { [box] target in
            box.value = pendingBefore
            target.typingAttributes = before
            undo.registerUndo(withTarget: target) { [box] inner in
                box.value = pendingAfter
                inner.typingAttributes = after
            }
        }
        undo.endUndoGrouping()
    }

    private func quoteOf(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        (attrs[RichRender.quoteKey] as? Bool) == true
    }

    private func indentsOf(_ attrs: [NSAttributedString.Key: Any]) -> (CGFloat, CGFloat) {
        let style = attrs[.paragraphStyle] as? NSParagraphStyle ?? NSParagraphStyle()
        return (style.headIndent, style.firstLineHeadIndent)
    }

    // MARK: - Decision policy

    func testQuoteArmedDecision() {
        XCTAssertFalse(RichTyping.isQuoteArmed(in: RichRender.baseAttributes))
        // List-armed typing (textLists, no marker) is not quote-armed.
        let listStyle = NSMutableParagraphStyle()
        listStyle.textLists = [RichRender.textList(for: .bullet)]
        listStyle.headIndent = 24
        XCTAssertFalse(RichTyping.isQuoteArmed(in: [.paragraphStyle: listStyle]))
        XCTAssertTrue(RichTyping.isQuoteArmed(in: RichTyping.armedQuoteAttributes(from: RichRender.baseAttributes)))
        XCTAssertFalse(RichTyping.isQuoteArmed(in: RichTyping.disarmedQuoteAttributes(
            from: RichTyping.armedQuoteAttributes(from: RichRender.baseAttributes))))
    }

    // MARK: - Shared transforms

    func testArmedTransformPreservesInlineFormatting() {
        var attrs = RichRender.baseAttributes
        RichTyping.toggleBold(in: &attrs)
        let armed = RichTyping.armedQuoteAttributes(from: attrs)
        XCTAssertTrue(quoteOf(armed))
        XCTAssertEqual(indentsOf(armed).0, 16)
        XCTAssertEqual(indentsOf(armed).1, 16)
        XCTAssertEqual(armed[RichRender.boldKey] as? Bool, true)
    }

    func testDisarmedTransformPreservesInlineFormatting() {
        var attrs = RichRender.baseAttributes
        RichTyping.toggleBold(in: &attrs)
        let armed = RichTyping.armedQuoteAttributes(from: attrs)
        let plain = RichTyping.disarmedQuoteAttributes(from: armed)
        XCTAssertFalse(quoteOf(plain))
        XCTAssertEqual(indentsOf(plain).0, 0)
        XCTAssertEqual(indentsOf(plain).1, 0)
        XCTAssertEqual(plain[RichRender.boldKey] as? Bool, true,
                       "toggle-off must preserve unrelated inline formatting")
    }

    // MARK: - Empty document: on -> off -> type is plain

    /// The reported bug: a second Quote tap in an empty editor re-armed
    /// instead of toggling off. Mirroring the controller's call order: arm
    /// (first tap), decide armed -> disarm (second tap), type, extract.
    func testEmptyDocQuoteOnOffThenTypeIsPlain() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.typingAttributes = RichRender.baseAttributes
        let box = PendingBox()
        // No runloop in tests: event-based grouping would coalesce the two
        // taps, so the helper's explicit groups fully control undo — the
        // same explicit begin/end discipline production `setTyping` uses.
        let undo = UndoManager()
        undo.groupsByEvent = false
        // First tap: arm (production `armEmptyDocumentForBlock` assigns the
        // same marker + indents the shared transform applies).
        setUndoableTyping(view, RichTyping.armedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        XCTAssertTrue(quoteOf(view.typingAttributes))
        XCTAssertNil(box.value ?? nil)
        // Second tap: the decision now disarms instead of re-arming.
        XCTAssertTrue(RichTyping.isQuoteArmed(in: view.typingAttributes),
                      "second tap must see the armed state (pre-fix: re-armed unconditionally)")
        setUndoableTyping(view, RichTyping.disarmedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        // Undo restores the armed state; redo disarms again.
        XCTAssertFalse(quoteOf(view.typingAttributes))
        undo.undo()
        XCTAssertTrue(quoteOf(view.typingAttributes))
        XCTAssertEqual(indentsOf(view.typingAttributes).0, 16)
        undo.redo()
        XCTAssertFalse(quoteOf(view.typingAttributes))
        XCTAssertEqual(indentsOf(view.typingAttributes).0, 0)
        // Typing now produces plain text.
        view.insertText("hello", replacementRange: view.selectedRange())
        let storage = view.textStorage!
        XCTAssertNil(storage.attribute(RichRender.quoteKey, at: 0, effectiveRange: nil))
        let extracted = RichRender.extract(text: view.string, storage: storage)
        XCTAssertEqual(extracted.text, "hello")
        XCTAssertNil(extracted.rich, "toggled-off quote must persist plain, not resurrect")
    }

    func testEmptyDocQuoteOffThenOnRearms() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.typingAttributes = RichRender.baseAttributes
        let box = PendingBox()
        let undo = UndoManager()
        setUndoableTyping(view, RichTyping.armedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        setUndoableTyping(view, RichTyping.disarmedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        XCTAssertFalse(RichTyping.isQuoteArmed(in: view.typingAttributes))
        // Third tap: not armed, so arm again.
        setUndoableTyping(view, RichTyping.armedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        XCTAssertTrue(quoteOf(view.typingAttributes))
        view.insertText("quoted", replacementRange: view.selectedRange())
        XCTAssertEqual(view.textStorage!.attribute(RichRender.quoteKey, at: 0, effectiveRange: nil) as? Bool, true)
    }

    // MARK: - Trailing empty paragraph comparison

    /// Same on -> off -> type sequence from a trailing empty paragraph
    /// (the path that already toggled): guards the shared-transform
    /// refactor against behavior drift.
    func testTrailingParagraphQuoteOnOffThenTypeIsPlain() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: "Para\n"))
        view.setSelectedRange(NSRange(location: 5, length: 0))
        view.typingAttributes = RichRender.baseAttributes
        XCTAssertTrue(view.string.hasSuffix("\n"))
        let box = PendingBox()
        let undo = UndoManager()
        setUndoableTyping(view, RichTyping.armedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        XCTAssertTrue(RichTyping.isQuoteArmed(in: view.typingAttributes))
        setUndoableTyping(view, RichTyping.disarmedQuoteAttributes(from: view.typingAttributes),
                          box: box, nil, undo)
        XCTAssertFalse(quoteOf(view.typingAttributes))
        view.insertText("plain", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "Para\nplain")
        XCTAssertNil(view.textStorage!.attribute(RichRender.quoteKey, at: 5, effectiveRange: nil))
        let extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(extracted.rich?.blocks.count ?? 0, 0)
    }

    // MARK: - Pending-list transitions

    /// Quote displaces a pending list arm; toggling quote off afterwards
    /// leaves plain typing (no list ghost, no quote ghost).
    func testQuoteDisplacesPendingListArm() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.typingAttributes = RichRender.baseAttributes
        let box = PendingBox(); box.value = .some(.bullet)
        let undo = UndoManager()
        // Quote tap while a list is armed: quote was never armed, so arm it
        // and displace the pending list (production passes .some(nil)).
        XCTAssertFalse(RichTyping.isQuoteArmed(in: view.typingAttributes))
        setUndoableTyping(view, RichTyping.armedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        XCTAssertTrue(quoteOf(view.typingAttributes))
        XCTAssertNil(box.value ?? nil)
        // Second tap: disarm to plain.
        setUndoableTyping(view, RichTyping.disarmedQuoteAttributes(from: view.typingAttributes),
                          box: box, .some(nil), undo)
        XCTAssertFalse(quoteOf(view.typingAttributes))
        XCTAssertNil(box.value ?? nil)
        view.insertText("plain", replacementRange: view.selectedRange())
        let extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertNil(extracted.rich)
    }
}
