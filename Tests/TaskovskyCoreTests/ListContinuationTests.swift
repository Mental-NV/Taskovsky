import AppKit
import XCTest
@testable import TaskovskyCore

/// List continuation through the actual production callback order: native
/// `insertText` Returns, the coordinator's exact typing-refresh assignment
/// (`view.typingAttributes = RichRender.attributes(at:in:)`), the shared
/// `continuationList` repair policy, pending application, extraction, and
/// painted markers — then TaskStore save/JSON/reload for the acceptance.
///
/// These tests would NOT have caught the bug with manual-only Core calls:
/// the defect was the refresh assignment itself stripping AppKit-derived
/// textLists, so every test below performs that real assignment and proves
/// the policy recovers exactly what was lost (and never invents).
final class ListContinuationTests: XCTestCase {
    private func laidOut(_ attributed: NSAttributedString, width: CGFloat) -> (NSTextStorage, ListLayoutManager, NSTextContainer) {
        let storage = NSTextStorage(attributedString: attributed)
        let layout = ListLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 5
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        return (storage, layout, container)
    }

    /// Mirrors RichBodyController.repairContinuation + the coordinator lines
    /// that call it, in verbatim order: capture the typing from before the
    /// assignment, assign the refreshed typing, then re-arm only what the
    /// assignment stripped (never invents: exited/cleared typing stays gone).
    /// Works whether this host's AppKit keeps lists on assignment (typing
    /// then carries the decision) or strips them (the pending arm does).
    private func syncContinuity(_ view: NSTextView, pending: inout (style: RichListStyle, checked: Bool)?) {
        let before = view.typingAttributes
        view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
        if pending == nil,
           let repaired = RichMutate.continuationList(beforeTyping: before, typingAttributes: view.typingAttributes,
                                                      storage: view.textStorage!, selection: view.selectedRange()) {
            pending = (repaired.style, repaired.checked)
        }
    }

    /// Mirrors applyPendingListArm + edit's post-step: resolve the caret
    /// paragraph, style it from the arm, then run edit's exact typing
    /// assignment. A nil arm is a no-op, exactly like the controller guard.
    private func applyPending(_ view: NSTextView, pending: (style: RichListStyle, checked: Bool)?) {
        guard let arm = pending, let storage = view.textStorage, storage.length > 0 else { return }
        let selected = view.selectedRange()
        guard selected.length == 0,
              let target = RichMutate.pendingListTarget(in: storage, caret: selected.location, style: arm.style) else { return }
        RichMutate.setList(arm.style, checked: arm.style == .checklist ? arm.checked : nil, in: storage, range: target)
        view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
    }

    // MARK: - Acceptance: two items with one Return, empty exit, save/reload

    @MainActor func testTwoBulletsThenEmptyExit() throws {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        // Production toggle arm: assigned typing loses textLists (AppKit),
        // so the pending record is the style source until first input.
        let armStyle = NSMutableParagraphStyle()
        armStyle.textLists = [RichRender.textList(for: .bullet)]
        armStyle.headIndent = 24
        view.typingAttributes = [.font: RichRender.baseFont, .paragraphStyle: armStyle]
        var pending: (style: RichListStyle, checked: Bool)? = (.bullet, false)
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: pending?.style),
                       .exitTrailingBlock, "Return before first input exits the armed empty doc")
        // Paste 'First item' -> the pending arm styles its paragraph.
        view.insertText("First item", replacementRange: view.selectedRange())
        applyPending(view, pending: pending)
        pending = nil
        var extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(extracted.rich?.blocks.map { $0.list }, [.bullet])
        // ONE Return: the newline proceeds; the coordinator refresh then
        // runs through the shared repair, exactly like production.
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: nil), .insertNewline)
        view.insertText("\n", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First item\n")
        syncContinuity(view, pending: &pending)
        // Whatever channel carries the style (assigned-kept typing or the
        // repaired pending arm), the decision inputs agree on continuation.
        let continues = ((view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.first != nil) || pending?.style == .bullet
        XCTAssertTrue(continues, "continuation survives the refresh assignment")
        // Input 'Second item' -> listed paragraph either way.
        view.insertText("Second item", replacementRange: view.selectedRange())
        applyPending(view, pending: pending)
        pending = nil
        extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(view.string, "First item\nSecond item")
        XCTAssertEqual(extracted.rich?.blocks.map { $0.list }, [.bullet, .bullet], "two bullet items")
        XCTAssertFalse(extracted.text.contains("•"), "prefix-free body")
        // TWO Returns after the second item: continuation, then empty exit.
        view.insertText("\n", replacementRange: view.selectedRange())
        syncContinuity(view, pending: &pending)
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: pending?.style),
                       .exitTrailingBlock, "Return on the empty trailing item exits")
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        pending = nil
        // Paste 'After list' -> plain, with no extra empty paragraph.
        view.insertText("After list", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First item\nSecond item\nAfter list")
        extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(extracted.rich?.blocks.count, 2, "plain After needs no block")
        XCTAssertEqual(extracted.rich?.blocks.map { $0.list }, [.bullet, .bullet])
        XCTAssertEqual((view.textStorage!.attribute(.font, at: 24, effectiveRange: nil) as? NSFont)?.pointSize, 14)
        // Painted markers: exactly two bullets with gutter geometry.
        let output = RichRender.attributedString(text: extracted.text, rich: extracted.rich)
        let (kept, layout, _) = laidOut(output, width: 300)
        XCTAssertEqual(kept.length, (output.string as NSString).length)
        let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers.map(\.kind), [.bullet, .bullet])
        for marker in markers {
            XCTAssertLessThanOrEqual(marker.rect.maxX, marker.textRect.minX + 5 + ListDecoration.gutterWidth + 0.5)
        }
        // Save/JSON/reload roundtrip keeps two bullets plus plain After.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"tasks\":[],\"lists\":[],\"tags\":[]}".utf8).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Lists QA", body: "")
        var updated = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        updated.body = extracted.text
        updated.richBody = extracted.rich
        store.updateTask(updated)
        let raw = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(WorkspaceData.self, from: raw)
        let saved = try XCTUnwrap(decoded.tasks.first { $0.id == id })
        XCTAssertEqual(saved.body, "First item\nSecond item\nAfter list")
        XCTAssertFalse(saved.body.contains("•"))
        XCTAssertEqual(saved.richBody?.blocks.map { $0.list }, [.bullet, .bullet])
        let rerendered = RichRender.attributedString(text: saved.body, rich: saved.richBody)
        let (kept2, layout2, _) = laidOut(rerendered, width: 300)
        XCTAssertEqual(kept2.length, (rerendered.string as NSString).length)
        let (markers2, _) = layout2.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout2.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers2.map(\.kind), [.bullet, .bullet])
    }

    func testNumberedContinuationAndExit() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        // Full production arm prefix (assigned typing loses textLists).
        let armNumbered = NSMutableParagraphStyle()
        armNumbered.textLists = [RichRender.textList(for: .numbered)]
        armNumbered.headIndent = 24
        view.typingAttributes = [.font: RichRender.baseFont, .paragraphStyle: armNumbered]
        var pending: (style: RichListStyle, checked: Bool)? = (.numbered, false)
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: pending?.style),
                       .exitTrailingBlock)
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        view.insertText("First", replacementRange: view.selectedRange())
        applyPending(view, pending: pending)
        pending = nil
        view.insertText("\n", replacementRange: view.selectedRange())
        syncContinuity(view, pending: &pending)
        let numContinues = ((view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.first?.markerFormat == .decimal) || pending?.style == .numbered
        XCTAssertTrue(numContinues, "numbered continuation survives the refresh assignment")
        view.insertText("Second", replacementRange: view.selectedRange())
        applyPending(view, pending: pending)
        pending = nil
        let extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(extracted.rich?.blocks.map { $0.list }, [.numbered, .numbered])
        let output = RichRender.attributedString(text: extracted.text, rich: extracted.rich)
        let (kept, layout, _) = laidOut(output, width: 300)
        XCTAssertEqual(kept.length, (output.string as NSString).length)
        let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers.map(\.kind), [.number(1), .number(2)], "continuing numbers restart nothing mid-run")
        // Empty exit on the trailing item, then plain After.
        view.insertText("\n", replacementRange: view.selectedRange())
        syncContinuity(view, pending: &pending)
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: pending?.style),
                       .exitTrailingBlock)
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        view.insertText("After", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "First\nSecond\nAfter")
        XCTAssertEqual(RichRender.extract(text: view.string, storage: view.textStorage!).rich?.blocks.count, 2)
        XCTAssertEqual(RichRender.extract(text: view.string, storage: view.textStorage!).rich?.blocks.map { $0.list },
                       [.numbered, .numbered])
    }

    func testChecklistOpenBoxesContinuationAndExit() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(string: ""))
        view.setSelectedRange(NSRange(location: 0, length: 0))
        // Full production arm prefix (assigned typing loses textLists).
        let armCheck = NSMutableParagraphStyle()
        armCheck.textLists = [RichRender.textList(for: .checklist)]
        armCheck.headIndent = 24
        view.typingAttributes = [.font: RichRender.baseFont, .paragraphStyle: armCheck]
        var pending: (style: RichListStyle, checked: Bool)? = (.checklist, false)
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: pending?.style),
                       .exitTrailingBlock)
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        view.insertText("Box one", replacementRange: view.selectedRange())
        applyPending(view, pending: pending)
        pending = nil
        view.insertText("\n", replacementRange: view.selectedRange())
        syncContinuity(view, pending: &pending)
        let checkContinues = ((view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.first?.markerFormat == .box) || pending?.style == .checklist
        XCTAssertTrue(checkContinues, "checklist continuation survives the refresh assignment")
        if pending != nil {
            XCTAssertEqual(pending?.checked, false, "unchecked state survives the strip")
        }
        view.insertText("Box two", replacementRange: view.selectedRange())
        applyPending(view, pending: pending)
        pending = nil
        let extracted = RichRender.extract(text: view.string, storage: view.textStorage!)
        XCTAssertEqual(extracted.rich?.blocks.map { $0.list }, [.checklist, .checklist])
        XCTAssertEqual(extracted.rich?.blocks.map { $0.checked }, [nil, nil], "open boxes stay open")
        let output = RichRender.attributedString(text: extracted.text, rich: extracted.rich)
        let (kept, layout, _) = laidOut(output, width: 300)
        XCTAssertEqual(kept.length, (output.string as NSString).length)
        let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers.map(\.kind), [.checkbox(checked: false), .checkbox(checked: false)])
        view.insertText("\n", replacementRange: view.selectedRange())
        syncContinuity(view, pending: &pending)
        XCTAssertEqual(RichMutate.returnExit(in: view.textStorage!, range: view.selectedRange(),
                                             typingAttributes: view.typingAttributes, pending: pending?.style),
                       .exitTrailingBlock)
        view.typingAttributes = RichTyping.exitedBlockAttributes(from: view.typingAttributes)
        view.insertText("After", replacementRange: view.selectedRange())
        XCTAssertEqual(RichRender.extract(text: view.string, storage: view.textStorage!).rich?.blocks.count, 2)
        XCTAssertEqual(RichRender.extract(text: view.string, storage: view.textStorage!).rich?.blocks.map { $0.list },
                       [.checklist, .checklist])
    }

    // MARK: - The repair policy never invents

    func testRepairNeverInvents() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(attributedString: RichRender.attributedString(
            text: "Item\n", rich: RichBody(text: "Item\n", blocks: [RichBlockRun(location: 0, length: 5, list: .bullet)]))))
        view.setSelectedRange(NSRange(location: 5, length: 0))
        // Exited typing (base, no lists): no re-arm despite the listed
        // previous paragraph.
        XCTAssertNil(RichMutate.continuationList(beforeTyping: RichRender.baseAttributes,
                                                 typingAttributes: RichRender.baseAttributes,
                                                 storage: view.textStorage!, selection: view.selectedRange()))
        // H1 typing over a listed paragraph (different-block choice): no arm.
        let h1: [NSAttributedString.Key: Any] = [.font: RichRender.headingFont(1), RichRender.headingKey: 1]
        XCTAssertNil(RichMutate.continuationList(beforeTyping: h1, typingAttributes: h1,
                                                 storage: view.textStorage!, selection: view.selectedRange()))
        // Cleared typing after Clear Formatting: no arm.
        XCTAssertNil(RichMutate.continuationList(beforeTyping: RichRender.baseAttributes,
                                                 typingAttributes: RichRender.baseAttributes,
                                                 storage: view.textStorage!, selection: NSRange(location: 5, length: 0)))
        // Ranged selection and empty storage: no arm.
        XCTAssertNil(RichMutate.continuationList(beforeTyping: nil, typingAttributes: RichRender.baseAttributes,
                                                 storage: NSTextStorage(string: ""),
                                                 selection: NSRange(location: 0, length: 0)))
        XCTAssertNil(RichMutate.continuationList(beforeTyping: nil, typingAttributes: view.typingAttributes,
                                                 storage: view.textStorage!, selection: NSRange(location: 0, length: 5)))
        // Plain paragraph: nothing to continue.
        let plain = NSTextView()
        plain.textStorage?.setAttributedString(NSTextStorage(string: "plain\n"))
        plain.setSelectedRange(NSRange(location: 6, length: 0))
        XCTAssertNil(RichMutate.continuationList(beforeTyping: nil, typingAttributes: plain.typingAttributes,
                                                 storage: plain.textStorage!, selection: plain.selectedRange()))
    }

    func testEditRefreshArmsFromStorage() {
        // The edit-post path: storage is authoritative (toggle paths).
        let storage = NSTextStorage(string: "a\n\nb")
        RichMutate.toggleList(.bullet, in: storage, range: NSRange(location: 2, length: 1))
        let stripped: [NSAttributedString.Key: Any] = [.font: RichRender.baseFont]
        let armed = RichMutate.continuationList(beforeTyping: nil, typingAttributes: stripped,
                                               storage: storage, selection: NSRange(location: 2, length: 0))
        XCTAssertEqual(armed?.style, .bullet, "middle empty listed paragraph re-arms")
        // After a toggle-off the stored style is gone: no arm.
        RichMutate.toggleList(.bullet, in: storage, range: NSRange(location: 2, length: 1))
        XCTAssertNil(RichMutate.continuationList(beforeTyping: nil, typingAttributes: stripped,
                                                 storage: storage, selection: NSRange(location: 2, length: 0)))
    }
}
