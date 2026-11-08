import AppKit
import XCTest
@testable import TaskovskyCore

/// Pending list arms through the real production mechanics: assigned typing
/// attributes (which AppKit strips of textLists — asserted, not assumed),
/// real `insertText` first input, `pendingListTarget` paragraph resolution,
/// `setList` application exactly as `applyPendingListArm` calls it, then
/// extraction plus painted-marker geometry on the prefix-free body.
final class PendingListArmTests: XCTestCase {
    private func laidOut(_ attributed: NSAttributedString, width: CGFloat) -> (NSTextStorage, ListLayoutManager, NSTextContainer) {
        let storage = NSTextStorage(attributedString: attributed)
        let layout = ListLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 5
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        return (storage, layout, container)
    }

    /// The full empty-document path: arm bullet, Return exits, first input
    /// opens a real bulleted paragraph with a painted marker.
    func testEmptyDocBulletArmAppliesOnFirstInput() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        // The production arm assigns textLists; AppKit strips them even here.
        let armStyle = NSMutableParagraphStyle()
        armStyle.textLists = [RichRender.textList(for: .bullet)]
        armStyle.headIndent = 24
        view.typingAttributes = [.font: RichRender.baseFont, .paragraphStyle: armStyle]
        XCTAssertNil(((view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists ?? []).first,
                     "assigned textLists do not survive typing (AppKit)")
        // Return before first input exits (the pending arm counts as armed).
        XCTAssertEqual(
            RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                  typingAttributes: view.typingAttributes, pending: .bullet),
            .exitTrailingBlock)
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        // First input: real insertion, then the production apply call.
        view.insertText("First item", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First item")
        let storage = view.textStorage!
        let target = RichMutate.pendingListTarget(in: storage, caret: view.selectedRange().location, style: .bullet)
        XCTAssertEqual(target?.location, 0)
        XCTAssertEqual(target?.length, 10)
        RichMutate.setList(.bullet, checked: nil, in: storage, range: target!)
        let extracted = RichRender.extract(text: view.string, storage: storage)
        XCTAssertEqual(extracted.rich?.blocks.count, 1)
        XCTAssertEqual(extracted.rich?.blocks.first?.list, .bullet)
        // Painted marker with gutter geometry on a prefix-free body.
        let output = RichRender.attributedString(text: extracted.text, rich: extracted.rich)
        XCTAssertFalse(extracted.text.contains("•"))
        // NOTE: the laid-out storage must stay bound (NSLayoutManager holds
        // its textStorage weakly) or layout reports zero glyphs.
        let (keptStorage, layout, _) = laidOut(output, width: 300)
        _ = keptStorage
        let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers.map(\.kind), [.bullet])
        XCTAssertLessThanOrEqual(markers[0].rect.maxX, markers[0].textRect.minX + 5 + ListDecoration.gutterWidth + 0.5)
    }

    func testChecklistCheckedStatePreserved() {
        for checked in [false, true] {
            let view = NSTextView()
            view.textStorage?.setAttributedString(NSTextStorage(string: ""))
            view.setSelectedRange(NSRange(location: 0, length: 0))
            let armStyle = NSMutableParagraphStyle()
            armStyle.textLists = [RichRender.textList(for: .checklist)]
            armStyle.headIndent = 24
            view.typingAttributes = [.font: RichRender.baseFont, .paragraphStyle: armStyle]
            view.insertText("Box", replacementRange: view.selectedRange())
            let storage = view.textStorage!
            let target = RichMutate.pendingListTarget(in: storage, caret: view.selectedRange().location, style: .checklist)
            XCTAssertNotNil(target, "checked=\(checked)")
            RichMutate.setList(.checklist, checked: checked, in: storage, range: target!)
            let extracted = RichRender.extract(text: view.string, storage: storage)
            XCTAssertEqual(extracted.rich?.blocks.first?.list, .checklist)
            XCTAssertEqual(extracted.rich?.blocks.first?.checked, checked ? true : nil)
            let output = RichRender.attributedString(text: extracted.text, rich: extracted.rich)
            let (keptStorage, layout, _) = laidOut(output, width: 300)
            XCTAssertEqual(keptStorage.length, (output.string as NSString).length)
            let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
            XCTAssertEqual(markers.map(\.kind), [.checkbox(checked: checked)])
        }
    }

    func testTrailingParagraphArmApplies() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(attributedString: RichRender.attributedString(
            text: "Item\n", rich: RichBody(text: "Item\n", blocks: []))))
        view.setSelectedRange(NSRange(location: 5, length: 0))
        let armStyle = NSMutableParagraphStyle()
        armStyle.textLists = [RichRender.textList(for: .numbered)]
        armStyle.headIndent = 24
        view.typingAttributes = [.font: RichRender.baseFont, .paragraphStyle: armStyle]
        view.insertText("Step", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "Item\nStep")
        let storage = view.textStorage!
        let target = RichMutate.pendingListTarget(in: storage, caret: view.selectedRange().location, style: .numbered)
        XCTAssertEqual(target?.location, 5)
        XCTAssertEqual(target?.length, 4)
        RichMutate.setList(.numbered, checked: nil, in: storage, range: target!)
        let extracted = RichRender.extract(text: view.string, storage: storage)
        XCTAssertEqual(extracted.rich?.blocks.count, 1, "the plain first paragraph stays unstyled")
        XCTAssertEqual(extracted.rich?.blocks.first?.list, .numbered)
        XCTAssertEqual(extracted.rich?.blocks.first?.location, 5)
        let output = RichRender.attributedString(text: extracted.text, rich: extracted.rich)
        let (keptStorage, layout, _) = laidOut(output, width: 300)
            XCTAssertEqual(keptStorage.length, (output.string as NSString).length)
        let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers.map(\.kind), [.number(1)])
    }

    func testPendingTargetGuards() {
        // Already styled: no target (never toggles off by applying).
        let listed = NSTextStorage(string: "a\nb\n")
        RichMutate.setList(.bullet, checked: nil, in: listed, range: NSRange(location: 0, length: 2))
        XCTAssertNil(RichMutate.pendingListTarget(in: listed, caret: 1, style: .bullet))
        // A different style still targets (the arm overwrites on apply).
        XCTAssertNotNil(RichMutate.pendingListTarget(in: listed, caret: 1, style: .numbered))
        // Empty storage and out-of-bounds carets: no target.
        XCTAssertNil(RichMutate.pendingListTarget(in: NSTextStorage(string: ""), caret: 0, style: .bullet))
        XCTAssertNil(RichMutate.pendingListTarget(in: listed, caret: -1, style: .bullet))
        XCTAssertNil(RichMutate.pendingListTarget(in: listed, caret: 99, style: .bullet))
        // EOF caret resolves to the last paragraph, not off the end.
        XCTAssertEqual(RichMutate.pendingListTarget(in: listed, caret: 4, style: .bullet)?.location, 2)
        XCTAssertEqual(RichMutate.pendingListTarget(in: listed, caret: 4, style: .bullet)?.length, 2)
    }

    func testReturnBeforeFirstInputExitsArmedEmptyDoc() {
        let empty = NSTextStorage(string: "")
        // Stripped assigned typing (no markers) + pending arm still exits.
        XCTAssertEqual(
            RichMutate.returnExit(in: empty, range: NSRange(location: 0, length: 0),
                                  typingAttributes: RichRender.baseAttributes, pending: .bullet),
            .exitTrailingBlock)
        XCTAssertEqual(
            RichMutate.returnExit(in: empty, range: NSRange(location: 0, length: 0),
                                  typingAttributes: RichRender.baseAttributes, pending: nil),
            .insertNewline)
    }
}
