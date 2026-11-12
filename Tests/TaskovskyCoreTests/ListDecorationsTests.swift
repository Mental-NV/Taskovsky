import XCTest
@testable import TaskovskyCore

/// Visible prefix-free list/quote decorations: the persisted body carries no
/// literal markers, so the layout manager must paint them. These tests assert
/// actual marker geometry/output — never storage metadata alone.
final class ListDecorationsTests: XCTestCase {
    func testLongNumberedRunsFitTheirAdaptiveGutterAndPreserveModel() throws {
        for count in [100, 1000] {
            let text = Array(repeating: "Long numbered item with wrapped content", count: count).joined(separator: "\n")
            let rich = RichBody(text: text, blocks: (text as NSString).paragraphRanges(intersecting: NSRange(location: 0, length: (text as NSString).length)).map { RichBlockRun(location: $0.location, length: $0.length, list: .numbered) })
            let output = RichRender.attributedString(text: text, rich: rich)
            let (storage, layout, _) = laidOut(output, width: 160)
            let baseline = RichRender.extract(text: text, storage: storage)
            XCTAssertEqual(baseline.text, text)
            XCTAssertEqual(baseline.rich?.blocks, rich.blocks)
            let style = try XCTUnwrap(storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
            XCTAssertGreaterThan(style.headIndent, ListDecoration.gutterWidth)
            XCTAssertEqual(style.firstLineHeadIndent, style.headIndent)
            let origin = NSPoint(x: 17, y: 11)
            let all = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: origin).markers
            XCTAssertEqual(all.count, count)
            for marker in all {
                XCTAssertGreaterThanOrEqual(marker.rect.minX, origin.x + 5)
                XCTAssertLessThanOrEqual(marker.rect.maxX, origin.x + 5 + style.headIndent - 4 + 0.01)
            }
            let last = try XCTUnwrap(all.last)
            let subset = layout.glyphRange(forCharacterRange: last.paragraph, actualCharacterRange: nil)
            XCTAssertEqual(layout.decorationsToDraw(forGlyphRange: subset, at: origin).markers.last, last)
            layout.enumerateLineFragments(forGlyphRange: subset) { _, _, _, range, _ in
                XCTAssertEqual(layout.location(forGlyphAt: range.location).x, 5 + style.headIndent, accuracy: 1.5)
            }
            XCTAssertFalse(ListDecoration.normalizeNumberedGutters(in: storage), "Repeated normalization is a no-op")
            XCTAssertEqual(RichRender.extract(text: text, storage: storage).rich, baseline.rich)
        }
    }

    func testNumberedGutterExpandsAndShrinksAfterEditsAndRunReset() throws {
        let text = Array(repeating: "item", count: 99).joined(separator: "\n")
        let rich = RichBody(text: text, blocks: (text as NSString).paragraphRanges(intersecting: NSRange(location: 0, length: (text as NSString).length)).map { RichBlockRun(location: $0.location, length: $0.length, list: .numbered) })
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: rich))
        func width(_ at: Int = 0) -> CGFloat {
            (storage.attribute(.paragraphStyle, at: at, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        }
        XCTAssertEqual(width(), 24)
        let before = NSAttributedString(attributedString: storage)
        let attrs = storage.attributes(at: storage.length - 1, effectiveRange: nil)
        storage.append(NSAttributedString(string: "\nitem", attributes: attrs))
        XCTAssertTrue(ListDecoration.normalizeNumberedGutters(in: storage))
        XCTAssertGreaterThan(width(), 24)
        let after = NSAttributedString(attributedString: storage)
        // Native Undo restores attributed snapshots; the editor uses the same
        // normalization path after both Undo and Redo notifications.
        storage.setAttributedString(before)
        ListDecoration.normalizeNumberedGutters(in: storage)
        XCTAssertEqual(width(), 24)
        storage.setAttributedString(after)
        ListDecoration.normalizeNumberedGutters(in: storage)
        XCTAssertGreaterThan(width(), 24)
        storage.deleteCharacters(in: NSRange(location: before.length, length: storage.length - before.length))
        XCTAssertTrue(ListDecoration.normalizeNumberedGutters(in: storage))
        XCTAssertEqual(width(), 24)
        XCTAssertEqual(storage.string, text)
        storage.append(NSAttributedString(string: "\nplain\n", attributes: [.font: NSFont.systemFont(ofSize: 14)]))
        let finalStart = storage.length
        storage.append(NSAttributedString(string: "new run", attributes: attrs))
        ListDecoration.normalizeNumberedGutters(in: storage)
        XCTAssertEqual(width(finalStart), 24)
        XCTAssertEqual(RichRender.extract(text: storage.string, storage: storage).text, storage.string)
    }

    private let lines = [
        "Launch checklist", // 0 heading
        "plain intro",      // 1 plain
        "bulleted item",    // 2 bullet
        "second bullet",    // 3 bullet
        "first step",       // 4 numbered
        "second step",      // 5 numbered
        "unchecked box",    // 6 checklist open
        "checked box",      // 7 checklist done
        "quoted line",      // 8 quote
        "tail",             // 9 plain
    ]

    private func qaFixture() -> (text: String, blocks: [RichBlockRun], paras: [NSRange]) {
        let text = lines.joined(separator: "\n")
        var starts: [Int] = []
        var idx = 0
        for (i, line) in lines.enumerated() {
            starts.append(idx)
            idx += (line as NSString).length + (i < lines.count - 1 ? 1 : 0)
        }
        let paras: [NSRange] = starts.enumerated().map { i, loc in
            NSRange(location: loc, length: (lines[i] as NSString).length + (i < lines.count - 1 ? 1 : 0))
        }
        func block(_ i: Int, heading: Int? = nil, quote: Bool = false, list: RichListStyle? = nil, checked: Bool? = nil) -> RichBlockRun {
            RichBlockRun(location: paras[i].location, length: paras[i].length, heading: heading, quote: quote, list: list, checked: checked)
        }
        let blocks = [
            block(0, heading: 1),
            block(2, list: .bullet), block(3, list: .bullet),
            block(4, list: .numbered), block(5, list: .numbered),
            block(6, list: .checklist, checked: false), block(7, list: .checklist, checked: true),
            block(8, quote: true),
        ]
        return (text, blocks, paras)
    }

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

    // MARK: - Model projection

    func testProjectionMarksPrefixFreeBody() {
        let (text, blocks, _) = qaFixture()
        XCTAssertFalse(text.contains("•"))
        XCTAssertFalse(text.contains("> "))
        let entries = ListDecoration.entries(text: text as NSString, blocks: blocks)
        XCTAssertEqual(entries.count, lines.count)
        let kinds = ListDecoration.markers(for: entries)
        XCTAssertEqual(kinds[0], nil) // heading: no marker
        XCTAssertEqual(kinds[1], nil)
        XCTAssertEqual(kinds[2], .bullet)
        XCTAssertEqual(kinds[3], .bullet)
        XCTAssertEqual(kinds[4], .number(1))
        XCTAssertEqual(kinds[5], .number(2))
        XCTAssertEqual(kinds[6], .checkbox(checked: false))
        XCTAssertEqual(kinds[7], .checkbox(checked: true))
        XCTAssertEqual(kinds[8], nil) // quote-only: bar, not a marker
        XCTAssertTrue(entries[8].quote)
        XCTAssertEqual(kinds[9], nil)
    }

    func testNumberingRestartsAfterBreak() {
        func kinds(_ formats: [NSTextList.MarkerFormat?]) -> [ListDecoration.MarkerKind?] {
            let paras = formats.enumerated().map { i, f in
                ListDecoration.Paragraph(range: NSRange(location: i, length: 1), markerFormat: f)
            }
            return ListDecoration.markers(for: paras)
        }
        // Numbered, plain, numbered: the second group restarts at 1.
        XCTAssertEqual(kinds([.decimal, .decimal, nil, .decimal])[0], .number(1))
        XCTAssertEqual(kinds([.decimal, .decimal, nil, .decimal])[1], .number(2))
        XCTAssertEqual(kinds([.decimal, .decimal, nil, .decimal])[3], .number(1))
        // A bullet or checklist between numbered items also restarts.
        XCTAssertEqual(kinds([.decimal, .disc, .decimal]), [.number(1), .bullet, .number(1)])
        XCTAssertEqual(kinds([.decimal, .box, .decimal]), [.number(1), .checkbox(checked: false), .number(1)])
        // Unknown formats degrade to bullets, never numbers.
        XCTAssertEqual(kinds([.decimal, .circle, .decimal]), [.number(1), .bullet, .number(1)])
    }

    // MARK: - Render reserves the gutter

    func testRenderReservesGutterOnBothLines() {
        let (text, blocks, _) = qaFixture()
        let rich = RichBody(text: text, blocks: blocks)
        let output = RichRender.attributedString(text: text, rich: rich)
        let ns = text as NSString
        func style(at location: Int) -> NSParagraphStyle? {
            output.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        }
        for i in [2, 3, 4, 5, 6, 7] {
            let loc = (ns.range(of: lines[i])).location
            let paragraphStyle = try? XCTUnwrap(style(at: loc))
            XCTAssertEqual(paragraphStyle?.headIndent, ListDecoration.gutterWidth, lines[i])
            XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, ListDecoration.gutterWidth, lines[i])
            XCTAssertFalse((paragraphStyle?.textLists ?? []).isEmpty, lines[i])
        }
        let quoteLoc = (ns.range(of: lines[8])).location
        XCTAssertEqual(style(at: quoteLoc)?.headIndent, ListDecoration.quoteIndent)
        XCTAssertNotNil(output.attribute(RichRender.quoteKey, at: quoteLoc, effectiveRange: nil))
        let plainLoc = (ns.range(of: lines[1])).location
        // Plain paragraphs carry no paragraph style (nil reads as zero).
        XCTAssertEqual(style(at: plainLoc)?.headIndent ?? 0, 0)
        XCTAssertEqual(style(at: plainLoc)?.firstLineHeadIndent ?? 0, 0)
        XCTAssertTrue((style(at: plainLoc)?.textLists ?? []).isEmpty)
    }

    // MARK: - Real layout geometry

    func testLayoutDrawsVisibleMarkersWithoutOverlap() {
        let (text, blocks, _) = qaFixture()
        let output = RichRender.attributedString(text: text, rich: RichBody(text: text, blocks: blocks))
        let (storage, layout, _) = laidOut(output, width: 300)
        XCTAssertGreaterThan(storage.length, 0)
        let glyphs = NSRange(location: 0, length: layout.numberOfGlyphs)
        let (markers, quotes) = layout.decorationsToDraw(forGlyphRange: glyphs, at: .zero)
        // Six markers in paragraph order, then the quote bar.
        XCTAssertEqual(markers.map(\.kind), [.bullet, .bullet, .number(1), .number(2), .checkbox(checked: false), .checkbox(checked: true)])
        XCTAssertEqual(quotes.count, 1)
        // Every marker sits inside the 24pt gutter (fragment origin +
        // padding + 24): it ends where the indented text begins, so it
        // cannot overlap text.
        for marker in markers {
            XCTAssertLessThanOrEqual(marker.rect.maxX, marker.textRect.minX + 5 + ListDecoration.gutterWidth + 0.5)
            XCTAssertGreaterThanOrEqual(marker.rect.minX, marker.textRect.minX + 5 - 0.5)
            XCTAssertGreaterThan(marker.rect.width, 0)
            XCTAssertGreaterThan(marker.rect.height, 0)
        }
        // The quote bar sits inside the 16pt quote indent with real height.
        let bar = try? XCTUnwrap(quotes.first)
        XCTAssertEqual(bar?.rect.width ?? -1, ListDecoration.quoteBarWidth)
        XCTAssertLessThanOrEqual((bar?.rect.maxX ?? 999), (markers.first?.textRect.minX ?? 0) + ListDecoration.quoteIndent + 0.5)
        XCTAssertGreaterThan(bar?.rect.height ?? 0, 0)
    }

    func testCheckboxHitAndEditPreserveAdjacentTextAndFormatting() throws {
        let (text, blocks, paragraphs) = qaFixture()
        let target = paragraphs[6]
        let rich = RichBody(text: text, runs: [.init(location: target.location, length: 5, bold: true)],
                            blocks: blocks)
        let (storage, layout, _) = laidOut(RichRender.attributedString(text: text, rich: rich), width: 140)
        let origin = NSPoint(x: 13, y: 9)
        let markers = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: origin).markers
        let checkbox = try XCTUnwrap(markers.first { $0.paragraph == target })
        let hit = NSPoint(x: checkbox.rect.midX, y: checkbox.rect.midY)
        XCTAssertEqual(layout.checklistMarker(at: hit, origin: origin), checkbox)
        XCTAssertNil(layout.checklistMarker(at: NSPoint(x: checkbox.rect.maxX + 5, y: hit.y), origin: origin))
        let bullet = try XCTUnwrap(markers.first { $0.kind == .bullet })
        XCTAssertNil(layout.checklistMarker(at: NSPoint(x: bullet.rect.midX, y: bullet.rect.midY), origin: origin))

        let originalStyle = storage.attribute(.paragraphStyle, at: target.location, effectiveRange: nil) as? NSParagraphStyle
        RichMutate.setChecklistChecked(true, in: storage, paragraph: target)
        XCTAssertEqual(layout.checklistMarker(at: hit, origin: origin)?.kind, .checkbox(checked: true))
        let edited = RichRender.extract(text: storage.string, storage: storage)
        XCTAssertEqual(edited.text, text)
        XCTAssertEqual(edited.rich?.runs, rich.runs)
        let changed = try XCTUnwrap(edited.rich?.blocks.first { $0.location == target.location })
        XCTAssertEqual(changed.checked, true)
        XCTAssertEqual(edited.rich?.blocks.filter { $0.location != target.location },
                       rich.blocks.filter { $0.location != target.location })
        let updatedStyle = storage.attribute(.paragraphStyle, at: target.location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(originalStyle?.headIndent, updatedStyle?.headIndent)

        RichMutate.setChecklistChecked(false, in: storage, paragraph: target)
        XCTAssertEqual(layout.checklistMarker(at: hit, origin: origin)?.kind, .checkbox(checked: false))
    }

    func testWrappedLinesRespectGutter() {
        let long = String(repeating: "wrapped text ", count: 20)
        let text = "short\n" + long
        let second = NSRange(location: 6, length: (text as NSString).length - 6)
        let rich = RichBody(text: text, blocks: [RichBlockRun(location: second.location, length: second.length, list: .bullet)])
        let output = RichRender.attributedString(text: text, rich: rich)
        let live = laidOut(output, width: 150)
        let (storage, layout, _) = (live.0, live.1, live.2)
        XCTAssertGreaterThan(storage.length, 0)
        // The first glyph of the item starts at padding + 24 ...
        let firstGlyph = layout.glyphIndexForCharacter(at: second.location)
        XCTAssertEqual(layout.location(forGlyphAt: firstGlyph).x, 5 + ListDecoration.gutterWidth, accuracy: 1.5)
        // ... and so does the first glyph of every wrapped fragment: the
        // gutter is reserved on all lines, not just the first.
        let firstFrag = layout.lineFragmentRect(forGlyphAt: firstGlyph, effectiveRange: nil)
        var wrappedChecked = false
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { rect, _, _, glyphRange, stop in
            if rect.minY > firstFrag.minY + 0.5 {
                XCTAssertEqual(layout.location(forGlyphAt: glyphRange.location).x, 5 + ListDecoration.gutterWidth, accuracy: 1.5)
                wrappedChecked = true
                stop.pointee = true
            }
        }
        XCTAssertTrue(wrappedChecked)
        let (markers, _) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
        XCTAssertEqual(markers.count, 1)
        XCTAssertLessThanOrEqual(markers[0].rect.maxX, 5 + ListDecoration.gutterWidth + 0.5)
    }

    func testEmptyTrailingItemsDoNotCrash() {
        for body in ["item\n\n", "", "item\n"] {
            let end = (body as NSString).length
            var blocks: [RichBlockRun] = []
            if end > 0 {
                let paras = (body as NSString).paragraphRanges(intersecting: NSRange(location: 0, length: end))
                blocks = paras.map { RichBlockRun(location: $0.location, length: $0.length, list: .bullet) }
            }
            let rich = RichBody(text: body, blocks: blocks.isEmpty ? [] : blocks)
            let output = RichRender.attributedString(text: body, rich: rich.isEmpty ? nil : rich)
            let live = laidOut(output, width: 300)
            let layout = live.1
            XCTAssertEqual(live.0.length, (body as NSString).length)
            let (markers, quotes) = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero)
            XCTAssertTrue(quotes.isEmpty)
            if body.isEmpty {
                XCTAssertTrue(markers.isEmpty)
            } else {
                XCTAssertFalse(markers.isEmpty)
            }
        }
    }

    // MARK: - Toggle / clear change the drawn output

    func testToggleAndClearChangeDecorations() {
        let output = RichRender.attributedString(text: "one\ntwo", rich: nil)
        let (storage, layout, _) = laidOut(output, width: 300)
        func kinds() -> [ListDecoration.MarkerKind?] {
            let glyphs = NSRange(location: 0, length: layout.numberOfGlyphs)
            return layout.decorationsToDraw(forGlyphRange: glyphs, at: .zero).markers.map(\.kind)
        }
        XCTAssertTrue(kinds().isEmpty)
        // Number both paragraphs: markers 1, 2 appear from storage alone.
        RichMutate.setList(.numbered, checked: nil, in: storage, range: NSRange(location: 0, length: storage.length))
        XCTAssertEqual(kinds(), [.number(1), .number(2)])
        // Checked state visibly changes the glyph.
        RichMutate.setList(.checklist, checked: true, in: storage, range: NSRange(location: 0, length: 3))
        let first = layout.decorationsToDraw(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: .zero).markers
        XCTAssertEqual(first.map(\.kind), [.checkbox(checked: true), .number(1)])
        // Clearing removes every decoration and restores the layout.
        RichMutate.clearFormatting(in: storage, range: NSRange(location: 0, length: storage.length))
        XCTAssertTrue(kinds().isEmpty)
        let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent, 0)
        XCTAssertEqual(style?.firstLineHeadIndent, 0)
    }

    // MARK: - View insertion / sizing / roundtrip

    func testViewInsertionPreservesStyles() {
        let (text, blocks, _) = qaFixture()
        let output = RichRender.attributedString(text: text, rich: RichBody(text: text, blocks: blocks))
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
        view.textStorage?.setAttributedString(output)
        guard let storage = view.textStorage else { return XCTFail("no storage") }
        let ns = text as NSString
        for i in [2, 4, 6] {
            let loc = ns.range(of: lines[i]).location
            let paragraphStyle = storage.attribute(.paragraphStyle, at: loc, effectiveRange: nil) as? NSParagraphStyle
            XCTAssertFalse((paragraphStyle?.textLists ?? []).isEmpty, lines[i])
            XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, ListDecoration.gutterWidth, lines[i])
        }
        let quoteLoc = ns.range(of: lines[8]).location
        XCTAssertNotNil(storage.attribute(RichRender.quoteKey, at: quoteLoc, effectiveRange: nil))
    }

    func testSizingMatchesLiveLayout() {
        let (text, blocks, _) = qaFixture()
        let output = RichRender.attributedString(text: text, rich: RichBody(text: text, blocks: blocks))
        let width: CGFloat = 300
        let measured = RichEditorSizing.measuredHeight(for: output, width: width)
        let live = laidOut(output, width: width - RichEditorSizing.lineFragmentPadding * 2)
        let (storage, layout, container) = (live.0, live.1, live.2)
        XCTAssertGreaterThan(storage.length, 0)
        XCTAssertEqual(container.lineFragmentPadding, RichEditorSizing.lineFragmentPadding)
        layout.ensureLayout(for: container)
        let liveUsed = layout.usedRect(for: container).height
        let measuredUsed = measured - RichEditorSizing.containerInsetHeight * 2 - RichEditorSizing.bottomPadding
        XCTAssertEqual(liveUsed, measuredUsed, accuracy: 0.5)
    }

    func testRoundtripKeepsBodyPrefixFree() {
        let (text, blocks, _) = qaFixture()
        let rich = RichBody(text: text, blocks: blocks)
        let output = RichRender.attributedString(text: text, rich: rich)
        let storage = NSTextStorage(attributedString: output)
        let round = RichRender.extract(text: text, storage: storage).rich
        XCTAssertEqual(round?.text, text)
        XCTAssertFalse((round?.text ?? "").contains("•"))
        // Model blocks survive the storage roundtrip unchanged.
        XCTAssertEqual(round?.blocks.count, blocks.count)
    }
}
