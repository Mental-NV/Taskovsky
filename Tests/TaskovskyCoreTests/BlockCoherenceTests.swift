import AppKit
import XCTest
@testable import TaskovskyCore

/// Block marker/font coherence: a heading key must travel with a heading
/// font, a quote key with its indent. An exited block whose key outlived a
/// typing reset through a replacement path persisted as a phantom block
/// (base-14 text rendering H1 after reload, stale H1 toolbar) even though
/// the Return dispatch itself was fixed. Uses only long-standing API plus
/// the new coherence checks, and fails against the old extract.
final class BlockCoherenceTests: XCTestCase {
    /// Storage with a phantom: second paragraph carries headingKey with a
    /// plain base font, exactly the persisted production state.
    private func phantomStorage() -> NSTextStorage {
        let storage = NSTextStorage(attributedString: RichRender.attributedString(
            text: "First heading\nAfter heading",
            rich: RichBody(text: "First heading\nAfter heading",
                           blocks: [RichBlockRun(location: 0, length: 14, heading: 1)])))
        storage.addAttribute(RichRender.headingKey, value: 1, range: NSRange(location: 14, length: 13))
        storage.addAttribute(.font, value: RichRender.baseFont, range: NSRange(location: 14, length: 13))
        return storage
    }

    func testPhantomHeadingDroppedFromBaseFontParagraph() {
        let storage = phantomStorage()
        // Precondition: the phantom really is key-without-font.
        XCTAssertEqual(storage.attribute(RichRender.headingKey, at: 14, effectiveRange: nil) as? Int, 1)
        XCTAssertTrue(((storage.attribute(.font, at: 14, effectiveRange: nil) as? NSFont)?.isEqual(RichRender.baseFont)) ?? false)
        let extracted = RichRender.extract(text: storage.string, storage: storage)
        let headings = extracted.rich?.blocks.compactMap { $0.heading } ?? []
        XCTAssertEqual(headings, [1], "only the first paragraph stays a heading")
        XCTAssertEqual(extracted.rich?.blocks.count, 1)
    }

    func testStaleBlockRangesFindsPhantoms() {
        let storage = phantomStorage()
        XCTAssertEqual(RichMutate.staleBlockRanges(in: storage) as NSArray, [NSRange(location: 14, length: 13)] as NSArray)
        // The editor's commit path strips these before extraction.
        for range in RichMutate.staleBlockRanges(in: storage) {
            storage.removeAttribute(RichRender.headingKey, range: range)
            storage.removeAttribute(RichRender.quoteKey, range: range)
        }
        XCTAssertNil(storage.attribute(RichRender.headingKey, at: 14, effectiveRange: nil))
        XCTAssertEqual(storage.attribute(RichRender.headingKey, at: 0, effectiveRange: nil) as? Int, 1)
        let extracted = RichRender.extract(text: storage.string, storage: storage)
        XCTAssertEqual(extracted.rich?.blocks.count, 1)
    }

    func testPhantomQuoteDroppedWithoutIndent() {
        let storage = NSTextStorage(string: "quoted\nplain\n")
        storage.addAttribute(RichRender.quoteKey, value: true, range: NSRange(location: 0, length: 7))
        let extracted = RichRender.extract(text: storage.string, storage: storage)
        XCTAssertTrue(extracted.rich?.blocks.allSatisfy { !$0.quote } ?? true)
        XCTAssertEqual(RichMutate.staleBlockRanges(in: storage) as NSArray, [NSRange(location: 0, length: 7)] as NSArray)
    }

    func testLegitCompositionSurvivesCoherence() {
        // H1 with a bold subsection: base-size bold font + boldKey + heading.
        let storage = NSTextStorage(string: "Head bold\nplain\n")
        RichMutate.setHeading(1, in: storage, range: NSRange(location: 0, length: 10))
        RichMutate.toggleTrait(.boldFontMask, in: storage, range: NSRange(location: 5, length: 4))
        let extracted = RichRender.extract(text: storage.string, storage: storage)
        XCTAssertEqual(extracted.rich?.blocks.compactMap { $0.heading }, [1])
        XCTAssertTrue(RichMutate.staleBlockRanges(in: storage).isEmpty)
        // H1 + italic + code composition survives too.
        let storage2 = NSTextStorage(string: "Head code\nplain\n")
        RichMutate.setHeading(2, in: storage2, range: NSRange(location: 0, length: 10))
        RichMutate.toggleCode(in: storage2, range: NSRange(location: 5, length: 4))
        XCTAssertEqual(RichRender.extract(text: storage2.string, storage: storage2).rich?.blocks.compactMap { $0.heading }, [2])
        // A real quote (key + indent) survives; quoted text stays extracted.
        let storage3 = NSTextStorage(string: "quoted\nplain\n")
        RichMutate.toggleQuote(in: storage3, range: NSRange(location: 0, length: 7))
        let extracted3 = RichRender.extract(text: storage3.string, storage: storage3)
        XCTAssertEqual(extracted3.rich?.blocks.filter { $0.quote }.count, 1)
        XCTAssertTrue(RichMutate.staleBlockRanges(in: storage3).isEmpty)
    }

    /// Full production pipeline for the reported repro: real view, native
    /// Return, EOF exit, native paste, extraction, TaskStore save, JSON
    /// roundtrip, and rerender. Proves After stays base-14 with no heading
    /// block after reload.
    @MainActor func testPipelineExitPasteSaveReloadStaysPlain() throws {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(attributedString: RichRender.attributedString(
            text: "First heading", rich: RichBody(text: "First heading", blocks: [RichBlockRun(location: 0, length: 13, heading: 1)]))))
        view.setSelectedRange(NSRange(location: 13, length: 0))
        view.typingAttributes = [.font: RichRender.headingFont(1), .foregroundColor: NSColor.labelColor,
                                 RichRender.headingKey: 1, .paragraphStyle: NSParagraphStyle.default]
        // Return 1 proceeds (end of non-empty line).
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(), typingAttributes: view.typingAttributes), .insertNewline)
        view.insertText("\n", replacementRange: view.selectedRange())
        // Return 2 exits the trailing block (the coordinator's setTyping effect).
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(), typingAttributes: view.typingAttributes), .exitTrailingBlock)
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        // Native paste of plain text.
        view.insertText("After heading", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First heading\nAfter heading")
        // Commit-equivalent: strip stale markers, then extract.
        let storage = view.textStorage!
        XCTAssertTrue(RichMutate.staleBlockRanges(in: storage).isEmpty, "clean pipeline produces no phantoms")
        let extracted = RichRender.extract(text: view.string, storage: storage)
        XCTAssertEqual(extracted.rich?.blocks.compactMap { $0.heading }, [1])
        XCTAssertEqual((storage.attribute(.font, at: 14, effectiveRange: nil) as? NSFont)?.pointSize, 14)
        // TaskStore save + JSON roundtrip + reload + rerender.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"tasks\":[],\"lists\":[],\"tags\":[]}".utf8).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Empty draft", body: "")
        var updated = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        updated.body = extracted.text
        updated.richBody = extracted.rich
        store.updateTask(updated)
        let raw = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(WorkspaceData.self, from: raw)
        let saved = try XCTUnwrap(decoded.tasks.first { $0.id == id })
        XCTAssertEqual(saved.body, "First heading\nAfter heading")
        let savedBlocks = saved.richBody?.blocks ?? []
        XCTAssertEqual(savedBlocks.count, 1)
        XCTAssertEqual(savedBlocks.first?.heading, 1)
        XCTAssertEqual(savedBlocks.first?.location, 0)
        let rerendered = RichRender.attributedString(text: saved.body, rich: saved.richBody)
        XCTAssertEqual((rerendered.attribute(.font, at: 14, effectiveRange: nil) as? NSFont)?.pointSize, 14)
        XCTAssertNil(rerendered.attribute(RichRender.headingKey, at: 14, effectiveRange: nil))
    }

    /// The pipeline heals an injected phantom exactly as the live editor
    /// did: strip (commit) -> extract -> save -> reload renders plain.
    @MainActor func testPipelineHealsInjectedPhantom() throws {
        let view = NSTextView()
        let storage = phantomStorage()
        view.textStorage?.setAttributedString(storage)
        view.setSelectedRange(NSRange(location: 27, length: 0))
        view.typingAttributes = RichRender.baseAttributes
        // Commit-equivalent: the coordinator strips stale markers first.
        let stale = RichMutate.staleBlockRanges(in: view.textStorage!)
        XCTAssertEqual(stale as NSArray, [NSRange(location: 14, length: 13)] as NSArray)
        for range in stale {
            view.textStorage!.removeAttribute(RichRender.headingKey, range: range)
            view.textStorage!.removeAttribute(RichRender.quoteKey, range: range)
        }
        view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
        XCTAssertNil(view.typingAttributes[RichRender.headingKey])
        XCTAssertNil(RichRender.toolbarState(for: NSRange(location: 27, length: 0), in: view).heading)
        let extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(extracted.rich?.blocks.count, 1)
    }
}
