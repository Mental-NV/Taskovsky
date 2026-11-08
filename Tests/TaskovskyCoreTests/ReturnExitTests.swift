import AppKit
import XCTest
@testable import TaskovskyCore

/// Return-on-empty-block policy through the actual native path: a live
/// NSTextView whose storage is built by `RichRender.attributedString`, real
/// `insertText("\n")` Return simulation (the same insertion `insertNewline:`
/// performs), and the shared `RichMutate.returnExit` decision the editor's
/// command and text-change dispatch both consult.
///
/// Two AppKit facts shape these tests: custom keys (`headingKey`,
/// `quoteKey`) survive a typing-attributes assignment, but `textLists` are
/// stripped from *assigned* typing attributes (even windowed) — while typing
/// *derived* by AppKit from a real newline insertion keeps them. List tests
/// below therefore derive continuation typing with a real `insertText`,
/// exactly as the editor does; assigned list typing would not reflect the
/// live control.
final class ReturnExitTests: XCTestCase {
    /// Live view with model-built storage and a collapsed caret.
    private func view(text: String, blocks: [RichBlockRun], caret: Int) -> NSTextView {
        let view = NSTextView()
        let storage = NSTextStorage(attributedString: RichRender.attributedString(
            text: text, rich: RichBody(text: text, blocks: blocks)))
        view.textStorage?.setAttributedString(storage)
        view.setSelectedRange(NSRange(location: caret, length: 0))
        return view
    }

    private func decision(for view: NSTextView) -> RichMutate.ReturnExit {
        RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(), typingAttributes: view.typingAttributes)
    }

    private func baseTyping() -> [NSAttributedString.Key: Any] {
        RichRender.baseAttributes
    }

    // The reported repro, end to end on the native path: "First heading"
    // (H1), Return (newline proceeds, style continues), Return on the empty
    // trailing block (consumed, trailing goes plain), then continued text
    // lands as plain base while the preceding heading survives.
    func testTrailingHeadingReturnExitsAndStaysPlain() {
        let view = view(text: "First heading",
                        blocks: [RichBlockRun(location: 0, length: 13, heading: 1)],
                        caret: 13)
        view.typingAttributes = [.font: RichRender.headingFont(1),
                                 .foregroundColor: NSColor.labelColor,
                                 RichRender.headingKey: 1]
        // First Return: caret is at the end of a non-empty line, so the
        // newline proceeds.
        XCTAssertEqual(decision(for: view), .insertNewline)
        view.insertText("\n", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First heading\n")
        // Second Return: the caret is in the trailing empty paragraph, whose
        // style lives in the derived typing attributes.
        XCTAssertEqual(view.typingAttributes[RichRender.headingKey] as? Int, 1)
        XCTAssertEqual(decision(for: view), .exitTrailingBlock)
        // Apply the prescribed trailing effect: typing resets, body and the
        // preceding heading are untouched.
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        XCTAssertEqual(view.string, "First heading\n")
        XCTAssertEqual(view.textStorage?.attribute(RichRender.headingKey, at: 0, effectiveRange: nil) as? Int, 1)
        XCTAssertNil(view.typingAttributes[RichRender.headingKey])
        XCTAssertEqual((view.typingAttributes[.font] as? NSFont)?.pointSize, RichRender.baseFont.pointSize)
        // Continued text (typed or pasted) lands as plain base.
        view.insertText("After heading", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First heading\nAfter heading")
        XCTAssertNil(view.textStorage?.attribute(RichRender.headingKey, at: 14, effectiveRange: nil))
        XCTAssertEqual((view.textStorage?.attribute(.font, at: 14, effectiveRange: nil) as? NSFont)?.pointSize,
                       RichRender.baseFont.pointSize)
        // Selection churn (what textViewDidChangeSelection assigns) and the
        // toolbar must not resurrect the heading after the exit.
        view.typingAttributes = RichRender.attributes(at: 14, in: view)
        XCTAssertNil(view.typingAttributes[RichRender.headingKey])
        view.setSelectedRange(NSRange(location: 28, length: 0))
        XCTAssertNil(RichRender.toolbarState(for: NSRange(location: 28, length: 0), in: view).heading)
    }

    // Bullet/numbered/checklist/quote analogues: first Return continues the
    // block, second Return on the trailing empty paragraph exits it.
    func testTrailingListAndQuoteReturnExits() {
        let cases: [(RichListStyle, RichBlockRun)] = [
            (.bullet, RichBlockRun(location: 0, length: 4, list: .bullet)),
            (.numbered, RichBlockRun(location: 0, length: 4, list: .numbered)),
            (.checklist, RichBlockRun(location: 0, length: 4, list: .checklist)),
        ]
        for (style, block) in cases {
            let view = view(text: "Item", blocks: [block], caret: 4)
            XCTAssertEqual(decision(for: view), .insertNewline, "\(style) first Return proceeds")
            view.insertText("\n", replacementRange: view.selectedRange())
            XCTAssertEqual(view.string, "Item\n")
            XCTAssertEqual(decision(for: view), .exitTrailingBlock, "trailing \(style) must exit")
            let after = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
            XCTAssertNil((after[.paragraphStyle] as? NSParagraphStyle)?.textLists.first, "trailing \(style) clears list")
            XCTAssertEqual((after[.paragraphStyle] as? NSParagraphStyle)?.headIndent, 0)
            XCTAssertEqual(view.string, "Item\n")
        }
        let quote = view(text: "Note", blocks: [RichBlockRun(location: 0, length: 4, quote: true)], caret: 4)
        XCTAssertEqual(decision(for: quote), .insertNewline)
        quote.insertText("\n", replacementRange: quote.selectedRange())
        XCTAssertEqual(decision(for: quote), .exitTrailingBlock)
        let quoteAfter = RichTyping.exitedBlockAttributes(from: quote.typingAttributes)
        XCTAssertNil(quoteAfter[RichRender.quoteKey])
        XCTAssertEqual((quoteAfter[.paragraphStyle] as? NSParagraphStyle)?.headIndent, 0)
        // After applying the exit, the toolbar no longer reports a quote.
        quote.typingAttributes = quoteAfter
        XCTAssertFalse(RichRender.toolbarState(for: NSRange(location: 5, length: 0), in: quote).quote)
    }

    func testTrailingPlainParagraphReturnInserts() {
        let view = view(text: "First", blocks: [], caret: 5)
        XCTAssertEqual(decision(for: view), .insertNewline)
        view.insertText("\n", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First\n")
        // The empty trailing plain paragraph keeps inserting newlines.
        view.typingAttributes = baseTyping()
        XCTAssertEqual(decision(for: view), .insertNewline)
        view.insertText("\n", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First\n\n")
    }

    func testMiddleEmptyBlockExitsViaStorage() {
        let storage = NSTextStorage(string: "a\n\nb")
        RichMutate.toggleList(.bullet, in: storage, range: NSRange(location: 2, length: 1))
        XCTAssertEqual(
            RichMutate.returnExit(in: storage, range: NSRange(location: 2, length: 0), typingAttributes: baseTyping()),
            .exitBlock)
        XCTAssertTrue(RichMutate.exitEmptyBlock(in: storage, range: NSRange(location: 2, length: 0)))
        XCTAssertNil(RichRender.extract(text: storage.string, storage: storage).rich)
    }

    func testNonEmptyAndRangedReturnInserts() {
        // End of a non-empty H1 line with no trailing newline: first Return
        // continues the style via typing, it must not exit.
        let headed = view(text: "First heading",
                          blocks: [RichBlockRun(location: 0, length: 13, heading: 1)],
                          caret: 13)
        headed.typingAttributes = [.font: RichRender.headingFont(1), RichRender.headingKey: 1]
        XCTAssertEqual(decision(for: headed), .insertNewline)
        // Mid-text caret and ranged selections always insert.
        let storage = NSTextStorage(string: "a\n\nb")
        XCTAssertEqual(RichMutate.returnExit(in: storage, range: NSRange(location: 3, length: 0), typingAttributes: baseTyping()), .insertNewline)
        XCTAssertEqual(RichMutate.returnExit(in: storage, range: NSRange(location: 0, length: 1), typingAttributes: baseTyping()), .insertNewline)
    }

    func testEmptyDocumentReturnPolicy() {
        let empty = NSTextStorage(string: "")
        // Armed empty editors exit (consume); unarmed ones insert.
        XCTAssertEqual(
            RichMutate.returnExit(in: empty, range: NSRange(location: 0, length: 0),
                                  typingAttributes: [.font: RichRender.headingFont(1), RichRender.headingKey: 1]),
            .exitTrailingBlock)
        XCTAssertEqual(
            RichMutate.returnExit(in: empty, range: NSRange(location: 0, length: 0), typingAttributes: baseTyping()),
            .insertNewline)
        let after = RichTyping.exitedBlockAttributes(from: [.font: RichRender.headingFont(1), RichRender.headingKey: 1])
        XCTAssertNil(after[RichRender.headingKey])
    }

    // Uses only long-standing API, so it also documents the old bug: with
    // body "a\n\n" (styled MIDDLE empty paragraph) and the caret at EOF, the
    // old clamp resolved to the middle paragraph and stripped its style.
    // The trailing paragraph has no characters; it must be left alone.
    func testTrailingExitPreservesPrecedingEmptyBlock() {
        let storage = NSTextStorage(string: "a\n\n")
        RichMutate.setHeading(1, in: storage, range: NSRange(location: 2, length: 1))
        XCTAssertEqual(storage.attribute(RichRender.headingKey, at: 2, effectiveRange: nil) as? Int, 1)
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: storage, range: NSRange(location: 3, length: 0)))
        XCTAssertEqual(storage.attribute(RichRender.headingKey, at: 2, effectiveRange: nil) as? Int, 1,
                       "preceding empty block keeps its style")
    }

    func testRuleLineReturnInsertsClean() {
        let storage = NSTextStorage(string: "a\n\nb")
        _ = RichMutate.insertHorizontalRule(in: storage, at: 0)
        XCTAssertEqual(
            RichMutate.returnExit(in: storage, range: NSRange(location: 2, length: 0), typingAttributes: baseTyping()),
            .insertNewline)
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: storage, range: NSRange(location: 2, length: 0)))
    }
}
