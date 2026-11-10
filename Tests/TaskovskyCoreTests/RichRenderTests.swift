import AppKit
import XCTest
@testable import TaskovskyCore

/// Render/extract composition: H1–H6, mixed inline survival through heading
/// add/remove, highlight/code wash interplay, real list markers with
/// continuation, and overflow-safe range math (emoji, hostile offsets).
final class RichRenderTests: XCTestCase {
    func testRecoloringKeepsInlineCodeAndOtherHighlightRanges() throws {
        let text = "abc"
        let rich = RichBody(text: text, runs: [
            .init(location: 0, length: 2, bold: true, highlightColor: .pink),
            .init(location: 1, length: 1, code: true),
            .init(location: 2, length: 1, highlight: true),
        ])
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: rich))
        XCTAssertEqual(storage.attribute(.backgroundColor, at: 1, effectiveRange: nil) as? NSColor, RichRender.highlightWash(for: .pink))
        let target = NSRange(location: 1, length: 1)
        RichMutate.setHighlight(.green, in: storage, range: target)
        let recolored = try XCTUnwrap(RichRender.extract(text: text, storage: storage).rich)
        XCTAssertEqual(recolored.runs.map(\.effectiveHighlight), [.pink, .green, .yellow])
        XCTAssertTrue(recolored.runs[1].bold && recolored.runs[1].code)
        RichMutate.setHighlight(nil, in: storage, range: target)
        XCTAssertEqual(storage.attribute(.backgroundColor, at: 1, effectiveRange: nil) as? NSColor, RichRender.codeWash)
        XCTAssertEqual(try XCTUnwrap(RichRender.extract(text: text, storage: storage).rich).runs.map(\.effectiveHighlight), [.pink, nil, .yellow])
    }

    func testCodeBlockTypingDoesNotLeakIntoAnUnstyledTrailingCaret() throws {
        let id = UUID()
        let text = "code\r\n"
        let rich = RichBody(text: text, blocks: [.init(location: 0, length: text.utf16.count, codeBlockID: id)])
        let view = NSTextView()
        let storage = try XCTUnwrap(view.textStorage)
        storage.setAttributedString(RichRender.attributedString(text: text, rich: rich))
        view.typingAttributes = storage.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(view.typingAttributes[RichRender.codeBlockKey] as? String, id.uuidString)
        XCTAssertNil(RichRender.attributes(at: text.utf16.count, in: view)[RichRender.codeBlockKey])
        XCTAssertEqual(RichRender.attributes(at: 0, in: view)[RichRender.codeBlockKey] as? String, id.uuidString)
    }

    func testCodeBlockRenderAndExtractKeepsParagraphsAndCanChangeStyle() throws {
        let text = "print(🧩)\n"
        let code = RichBody(text: text, blocks: [.init(location: 0, length: text.utf16.count, codeBlockID: UUID())])
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: code))
        XCTAssertEqual(RichRender.extract(text: text, storage: storage).rich, code)
        XCTAssertNotNil(storage.attribute(.backgroundColor, at: 0, effectiveRange: nil))
        RichMutate.setHeading(2, in: storage, range: NSRange(location: 0, length: text.utf16.count))
        let changed = try XCTUnwrap(RichRender.extract(text: text, storage: storage).rich)
        XCTAssertNil(changed.blocks.first?.codeBlockID)
        XCTAssertEqual(changed.blocks.first?.heading, 2)
        XCTAssertNil(storage.attribute(.backgroundColor, at: 0, effectiveRange: nil))
    }

    // MARK: - Range safety

    func testSanitizedSurvivesHostileRanges() {
        let text = "a🎉b" // 4 UTF-16 units: a | 🎉(2) | b
        XCTAssertEqual((text as NSString).length, 4)
        let rich = RichBody(
            text: text,
            runs: [
                RichInlineRun(location: 1, length: 2, bold: true),
                RichInlineRun(location: 2, length: 1, italic: true),
                RichInlineRun(location: Int.max, length: Int.max, underline: true),
                RichInlineRun(location: Int.min, length: Int.max, strikethrough: true),
                RichInlineRun(location: -10, length: 20, highlight: true),
                RichInlineRun(location: 1, length: Int.max, code: true),
                RichInlineRun(location: 0, length: -5, link: "https://example.com"),
                RichInlineRun(location: 0, length: Int.min, bold: true),
            ],
            blocks: [
                RichBlockRun(location: Int.min, length: Int.max, quote: true),
                RichBlockRun(location: 3, length: Int.max, heading: 2),
            ])
        let clean = rich.sanitized() // must not trap
        XCTAssertEqual(clean.runs.map { "\($0.location):\($0.length)" }, ["0:4", "1:2", "1:3", "2:1"])
        XCTAssertEqual(clean.blocks.map { "\($0.location):\($0.length)" }, ["3:1"])
    }

    func testNegativeLocationsClipToRealIntersection() {
        // "hello" is 5 UTF-16 units. A fully-negative interval drops; a
        // straddling one covers only the in-bounds part (never shifts styles
        // onto new characters by keeping the full original length).
        func clipped(_ location: Int, _ length: Int, end: Int = 5) -> (Int, Int)? {
            let rich = RichBody(text: "hello", runs: [RichInlineRun(location: location, length: length, bold: true)])
            return rich.sanitized().runs.first.map { ($0.location, $0.length) }
        }
        XCTAssertNil(clipped(-5, 2))
        XCTAssertEqual(clipped(-2, 4)?.0, 0)
        XCTAssertEqual(clipped(-2, 4)?.1, 2)
        XCTAssertEqual(clipped(-2, 20)?.1, 5)
        XCTAssertEqual(clipped(4, 1)?.1, 1)
        XCTAssertNil(clipped(5, 1))
        XCTAssertNil(clipped(0, Int.min))
        // Emoji (surrogate pair): offsets are UTF-16 units, not characters.
        let emoji = RichBody(text: "a🎉b", runs: [RichInlineRun(location: 1, length: 2, italic: true)])
        let clean = emoji.sanitized()
        XCTAssertEqual(clean.runs.count, 1)
        XCTAssertEqual(clean.runs.first?.location, 1)
        XCTAssertEqual(clean.runs.first?.length, 2)
    }

    func testIdentityIsUTF16NotStringEquality() {
        // "café" precomposed (U+00E9, 4 units) vs decomposed (e + U+0301,
        // 5 units): String == is true, but offsets would misalign.
        let composed = "caf\u{E9}"
        let decomposed = "cafe\u{301}"
        XCTAssertEqual(composed, decomposed)
        XCTAssertFalse(RichBody.sameCodeUnits(composed, decomposed))
        XCTAssertTrue(RichBody.sameCodeUnits(composed, composed))
        let rich = RichBody(text: composed, runs: [RichInlineRun(location: 0, length: 4, bold: true)])
        XCTAssertNotNil(rich.valid(for: composed))
        XCTAssertNil(rich.valid(for: decomposed), "normalization change must not reuse old offsets")
        // Emoji identity: same string, same units.
        XCTAssertTrue(RichBody.sameCodeUnits("a🎉b", "a🎉b"))
    }

    func testEmptyTextDropsAllRuns() {
        let rich = RichBody(text: "", runs: [RichInlineRun(location: 0, length: 5, bold: true)],
                            blocks: [RichBlockRun(location: 0, length: 5, quote: true)])
        XCTAssertTrue(rich.sanitized().runs.isEmpty)
        XCTAssertTrue(rich.sanitized().blocks.isEmpty)
    }

    // MARK: - Headings

    func testHeadingLevelsOneThroughSix() {
        for level in 1...6 {
            XCTAssertEqual(RichBlockRun(location: 0, length: 1, heading: level).validHeading, level)
        }
        XCTAssertNil(RichBlockRun(location: 0, length: 1, heading: 0).validHeading)
        XCTAssertNil(RichBlockRun(location: 0, length: 1, heading: 7).validHeading)
        XCTAssertNil(RichBlockRun(location: 0, length: 1).validHeading)
        var previous = CGFloat.greatestFiniteMagnitude
        for level in 1...6 {
            let size = RichRender.headingFont(level).pointSize
            XCTAssertLessThan(size, previous)
            previous = size
        }
    }

    func testHeadingSixRoundTrips() {
        let text = "Small"
        let rich = RichBody(text: text, blocks: [RichBlockRun(location: 0, length: 5, heading: 6)])
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: rich))
        let extracted = RichRender.extract(text: text, storage: storage)
        XCTAssertEqual(extracted.rich?.blocks.first?.heading, 6)
    }

    // MARK: - Composition

    /// Mixed inline styles survive adding and removing a heading; only
    /// explicit bold is implied by the semibold heading weight (and excluded
    /// from extraction under a heading marker).
    func testHeadingPreservesMixedInlineAttributes() {
        let text = "Title words here link"
        // bold "Title", italic "words", code+underline "here", highlight link "link"
        let rich = RichBody(
            text: text,
            runs: [
                RichInlineRun(location: 0, length: 5, bold: true),
                RichInlineRun(location: 6, length: 5, italic: true),
                RichInlineRun(location: 12, length: 4, underline: true, code: true),
                RichInlineRun(location: 17, length: 4, highlight: true, link: "https://example.com"),
            ],
            blocks: [RichBlockRun(location: 0, length: 21, heading: 3)])
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: rich))
        let first = RichRender.extract(text: text, storage: storage).rich
        XCTAssertEqual(first?.blocks.first?.heading, 3)
        let byOffset: [Int: RichInlineRun] = Dictionary(uniqueKeysWithValues: (first?.runs ?? []).map { ($0.location, $0) })
        XCTAssertEqual(byOffset[6]?.italic, true)
        XCTAssertEqual(byOffset[12]?.code, true)
        XCTAssertEqual(byOffset[12]?.underline, true)
        XCTAssertEqual(byOffset[17]?.link, "https://example.com")
        XCTAssertEqual(byOffset[17]?.highlight, true)
        // Removing the heading restores base size per character without
        // destroying the mixed traits.
        RichMutate.setHeading(nil, in: storage, range: NSRange(location: 0, length: 21))
        let second = RichRender.extract(text: text, storage: storage).rich
        XCTAssertTrue(second?.blocks.isEmpty == true)
        let after: [Int: RichInlineRun] = Dictionary(uniqueKeysWithValues: (second?.runs ?? []).map { ($0.location, $0) })
        XCTAssertEqual(after[6]?.italic, true)
        XCTAssertEqual(after[12]?.code, true)
        XCTAssertEqual(after[12]?.underline, true)
        XCTAssertEqual(after[17]?.link, "https://example.com")
    }

    func testBoldSubsectionSurvivesHeadingOnOffAndReload() {
        let text = "Title words"
        let storage = NSTextStorage(attributedString: RichRender.attributedString(
            text: text, rich: RichBody(text: text, runs: [RichInlineRun(location: 0, length: 5, bold: true)])))
        // Bold on plain text renders bold with an explicit marker.
        XCTAssertEqual(storage.attribute(RichRender.boldKey, at: 0, effectiveRange: nil) as? Bool, true)
        // Adding a heading keeps the marker (no restyle needed).
        RichMutate.setHeading(2, in: storage, range: NSRange(location: 0, length: 11))
        XCTAssertEqual(storage.attribute(RichRender.boldKey, at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(storage.attribute(RichRender.headingKey, at: 0, effectiveRange: nil) as? Int, 2)
        let headed = RichRender.extract(text: text, storage: storage).rich
        XCTAssertEqual(headed?.blocks.first?.heading, 2)
        XCTAssertEqual(headed?.runs.first?.bold, true)
        XCTAssertEqual(headed?.runs.first?.location, 0)
        XCTAssertEqual(headed?.runs.first?.length, 5)
        // Removing the heading restores the original mixed traits: marked
        // bold only where the marker was, not semibold-derived bold.
        RichMutate.setHeading(nil, in: storage, range: NSRange(location: 0, length: 11))
        let plain = RichRender.extract(text: text, storage: storage).rich
        XCTAssertTrue(plain?.blocks.isEmpty == true)
        XCTAssertEqual(plain?.runs.map { "\($0.location):\($0.length)" }, ["0:5"])
        XCTAssertEqual(plain?.runs.first?.bold, true)
        // Reloading the extracted model reproduces the same styles.
        let reloaded = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: plain))
        XCTAssertEqual(RichRender.extract(text: text, storage: reloaded).rich, plain)
    }

    func testToggleBoldInsideHeadingsRecordsMarker() {
        let text = "Head"
        let storage = NSTextStorage(attributedString: RichRender.attributedString(
            text: text, rich: RichBody(text: text, blocks: [RichBlockRun(location: 0, length: 4, heading: 1)])))
        // Toggling bold inside a heading records the explicit marker (the
        // semibold heading font needs no visual change) instead of disabling.
        RichMutate.toggleTrait(.boldFontMask, in: storage, range: NSRange(location: 0, length: 4))
        XCTAssertEqual(storage.attribute(RichRender.boldKey, at: 0, effectiveRange: nil) as? Bool, true)
        let extracted = RichRender.extract(text: text, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.first?.heading, 1)
        XCTAssertEqual(extracted?.runs.first?.bold, true)
        XCTAssertEqual(RichRender.toolbarState(for: NSRange(location: 0, length: 4), in: headedView(storage)).bold, true)
        // A second toggle clears the marker again.
        RichMutate.toggleTrait(.boldFontMask, in: storage, range: NSRange(location: 0, length: 4))
        XCTAssertNil(storage.attribute(RichRender.boldKey, at: 0, effectiveRange: nil) as? Bool)
    }

    private func headedView(_ storage: NSTextStorage) -> NSTextView {
        let view = NSTextView()
        view.textStorage?.setAttributedString(storage)
        return view
    }

    // MARK: - Highlight / code

    func testRemovingHighlightFromCodeKeepsWashImmediately() {
        let text = "code"
        let storage = NSTextStorage(attributedString: RichRender.attributedString(
            text: text, rich: RichBody(text: text, runs: [RichInlineRun(location: 0, length: 4, highlight: true, code: true)])))
        RichMutate.toggleHighlight(in: storage, range: NSRange(location: 0, length: 4))
        XCTAssertNil(storage.attribute(RichRender.highlightKey, at: 0, effectiveRange: nil) as? Bool)
        XCTAssertEqual(storage.attribute(RichRender.codeKey, at: 0, effectiveRange: nil) as? Bool, true)
        let wash = storage.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(wash, RichRender.codeWash)
    }

    // MARK: - Lists

    func testListMarkersRenderAndRoundTrip() {
        let text = "b1\nb2\nn1\nn2\nu1\nc1"
        let po: [Int] = [0, 3, 6, 9, 12, 15]
        let rich = RichBody(
            text: text,
            blocks: [
                RichBlockRun(location: po[0], length: 3, list: .bullet),
                RichBlockRun(location: po[1], length: 3, list: .bullet),
                RichBlockRun(location: po[2], length: 3, list: .numbered),
                RichBlockRun(location: po[3], length: 3, list: .numbered),
                RichBlockRun(location: po[4], length: 3, list: .checklist, checked: false),
                RichBlockRun(location: po[5], length: 2, list: .checklist, checked: true),
            ])
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: rich))
        func marker(at location: Int) -> NSTextList.MarkerFormat? {
            (storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
        }
        XCTAssertEqual(marker(at: po[0]), .disc)
        XCTAssertEqual(marker(at: po[2]), .decimal)
        XCTAssertEqual(marker(at: po[4]), .box)
        XCTAssertEqual(marker(at: po[5]), .check)
        // Numbered siblings share one marker object so numbering continues.
        let first = (storage.attribute(.paragraphStyle, at: po[2], effectiveRange: nil) as? NSParagraphStyle)?.textLists.first
        let second = (storage.attribute(.paragraphStyle, at: po[3], effectiveRange: nil) as? NSParagraphStyle)?.textLists.first
        XCTAssertTrue(first === second)
        // Full round trip preserves every list kind and checked state.
        let extracted = RichRender.extract(text: text, storage: storage).rich
        let styles = (extracted?.blocks ?? []).map { ($0.list, $0.checked ?? false) }
        XCTAssertEqual(styles.count, 6)
        XCTAssertTrue(styles[0].0 == .bullet && styles[1].0 == .bullet)
        XCTAssertTrue(styles[2].0 == .numbered && styles[3].0 == .numbered)
        XCTAssertTrue(styles[4].0 == .checklist && styles[4].1 == false)
        XCTAssertTrue(styles[5].0 == .checklist && styles[5].1 == true)
    }

    func testToggleListAndExtract() {
        let storage = NSTextStorage(string: "one\ntwo")
        RichMutate.toggleList(.numbered, in: storage, range: NSRange(location: 0, length: 7))
        let extracted = RichRender.extract(text: storage.string, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.compactMap(\.list), [.numbered, .numbered])
        RichMutate.toggleList(.numbered, in: storage, range: NSRange(location: 0, length: 7))
        XCTAssertNil(RichRender.extract(text: storage.string, storage: storage).rich)
        RichMutate.setList(.checklist, checked: true, in: storage, range: NSRange(location: 0, length: 3))
        let check = RichRender.extract(text: storage.string, storage: storage).rich
        XCTAssertEqual(check?.blocks.count, 1)
        XCTAssertEqual(check?.blocks.first?.list, .checklist)
        XCTAssertEqual(check?.blocks.first?.checked, true)
    }

    func testInsertHorizontalRuleMidDocument() {
        let storage = NSTextStorage(string: "AB\nCD")
        let caret = RichMutate.insertHorizontalRule(in: storage, at: 1)
        XCTAssertEqual(caret, 4)
        XCTAssertEqual(storage.string, "AB\n\nCD")
        XCTAssertEqual((storage.attribute(RichRender.ruleKey, at: 3, effectiveRange: nil) as? Bool), true)
        XCTAssertNil(storage.attribute(RichRender.ruleKey, at: 0, effectiveRange: nil) as? Bool)
        let extracted = RichRender.extract(text: storage.string, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.map { ($0.location, $0.length, $0.rule) }.map { "\($0.0):\($0.1):\($0.2)" }, ["3:1:true"])
    }

    func testInsertHorizontalRuleAtDocumentEnd() {
        // At the end the first newline only terminates "AB"; the rule takes
        // the paragraph after it and the caret lands past it.
        let storage = NSTextStorage(string: "AB")
        let caret = RichMutate.insertHorizontalRule(in: storage, at: 2)
        XCTAssertEqual(caret, 4)
        XCTAssertEqual(storage.string, "AB\n\n")
        XCTAssertNil(storage.attribute(RichRender.ruleKey, at: 2, effectiveRange: nil) as? Bool)
        XCTAssertEqual((storage.attribute(RichRender.ruleKey, at: 3, effectiveRange: nil) as? Bool), true)
        let extracted = RichRender.extract(text: storage.string, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.map { "\($0.location):\($0.length):\($0.rule)" }, ["3:1:true"])
    }

    func testInsertHorizontalRuleAtEndWithTrailingNewline() {
        let storage = NSTextStorage(string: "AB\n")
        let caret = RichMutate.insertHorizontalRule(in: storage, at: 3)
        XCTAssertEqual(caret, 5)
        XCTAssertEqual(storage.string, "AB\n\n\n")
        XCTAssertEqual((storage.attribute(RichRender.ruleKey, at: 4, effectiveRange: nil) as? Bool), true)
        let extracted = RichRender.extract(text: storage.string, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.map { "\($0.location):\($0.length):\($0.rule)" }, ["4:1:true"])
    }

    func testInsertHorizontalRuleEmptyDocument() {
        let storage = NSTextStorage(string: "")
        let caret = RichMutate.insertHorizontalRule(in: storage, at: 0)
        XCTAssertEqual(caret, 2)
        XCTAssertEqual(storage.string, "\n\n")
        XCTAssertNil(RichMutate.insertHorizontalRule(in: storage, at: 99))
        let extracted = RichRender.extract(text: storage.string, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.first?.rule, true)
    }

    func testRuleRenderRoundTrip() {
        let text = "above\n\nbelow"
        let rich = RichBody(text: text, blocks: [RichBlockRun(location: 6, length: 1, rule: true)])
        let storage = NSTextStorage(attributedString: RichRender.attributedString(text: text, rich: rich))
        XCTAssertEqual((storage.attribute(RichRender.ruleKey, at: 6, effectiveRange: nil) as? Bool), true)
        let extracted = RichRender.extract(text: text, storage: storage).rich
        XCTAssertEqual(extracted?.blocks.map { "\($0.location):\($0.length):\($0.rule)" }, ["6:1:true"])
    }

    func testRuleOnTextParagraphSelfHeals() {
        // A rule marker that somehow reached a text paragraph is ignored on
        // extract and dropped on the next render — never styling text.
        let storage = NSTextStorage(string: "abc")
        storage.addAttribute(RichRender.ruleKey, value: true, range: NSRange(location: 0, length: 3))
        let extracted = RichRender.extract(text: "abc", storage: storage)
        XCTAssertNil(extracted.rich)
        let rerendered = NSTextStorage(attributedString: RichRender.attributedString(text: "abc", rich: nil))
        XCTAssertNil(rerendered.attribute(RichRender.ruleKey, at: 0, effectiveRange: nil) as? Bool)
    }

    func testExitEmptyBlock() {
        // Empty list item exits.
        let listed = NSTextStorage(string: "a\n\nb")
        RichMutate.toggleList(.bullet, in: listed, range: NSRange(location: 2, length: 1))
        XCTAssertTrue(RichMutate.exitEmptyBlock(in: listed, range: NSRange(location: 2, length: 0)))
        XCTAssertNil(RichRender.extract(text: listed.string, storage: listed).rich)
        // Empty heading exits to base (caret inside the empty paragraph;
        // position 3 already belongs to "b" and must let Return through).
        let headed = NSTextStorage(string: "a\n\nb")
        RichMutate.setHeading(2, in: headed, range: NSRange(location: 2, length: 1))
        XCTAssertNotNil(headed.attribute(RichRender.headingKey, at: 2, effectiveRange: nil))
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: headed, range: NSRange(location: 3, length: 0)))
        XCTAssertTrue(RichMutate.exitEmptyBlock(in: headed, range: NSRange(location: 2, length: 0)))
        XCTAssertNil(RichRender.extract(text: headed.string, storage: headed).rich)
        // Empty quote exits.
        let quoted = NSTextStorage(string: "a\n\nb")
        RichMutate.toggleQuote(in: quoted, range: NSRange(location: 2, length: 1))
        XCTAssertTrue(RichMutate.exitEmptyBlock(in: quoted, range: NSRange(location: 2, length: 0)))
        XCTAssertNil(RichRender.extract(text: quoted.string, storage: quoted).rich)
        // Text paragraphs, rule lines, ranged selections, and empty storage
        // all let the newline through.
        let text = NSTextStorage(string: "a\n\nb")
        RichMutate.toggleList(.bullet, in: text, range: NSRange(location: 0, length: 1))
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: text, range: NSRange(location: 1, length: 0)))
        let ruled = NSTextStorage(string: "a\n\nb")
        _ = RichMutate.insertHorizontalRule(in: ruled, at: 0)
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: ruled, range: NSRange(location: 2, length: 0)))
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: text, range: NSRange(location: 0, length: 1)))
        XCTAssertFalse(RichMutate.exitEmptyBlock(in: NSTextStorage(string: ""), range: NSRange(location: 0, length: 0)))
    }

    func testClearFormattingDropsRule() {
        let storage = NSTextStorage(string: "a\n\nb")
        _ = RichMutate.insertHorizontalRule(in: storage, at: 0)
        RichMutate.clearFormatting(in: storage, range: NSRange(location: 0, length: storage.length))
        XCTAssertNil(RichRender.extract(text: storage.string, storage: storage).rich)
    }

    // Old-API behavioral proof for the trailing-exit fix (compiles against
    // the pre-fix code, where it FAILS): after an exit, EOF reads must
    // follow the live typing instead of clamping onto the previous
    // paragraph. Uses only long-standing API.
    func testTrailingReadsFollowLiveTyping() {
        let view = NSTextView()
        view.textStorage?.setAttributedString(NSTextStorage(attributedString: RichRender.attributedString(
            text: "First heading\n", rich: RichBody(text: "First heading\n", blocks: [RichBlockRun(location: 0, length: 14, heading: 1)]))))
        view.setSelectedRange(NSRange(location: 14, length: 0))
        view.typingAttributes = RichRender.baseAttributes
        XCTAssertNil(RichRender.attributes(at: 14, in: view)[RichRender.headingKey])
        XCTAssertNil(RichRender.toolbarState(for: NSRange(location: 14, length: 0), in: view).heading)
    }

    func testReturnContinuesNumberedList() {
        // Simulates the editor path: caret at a list paragraph end, typing
        // attributes inherited, Return inserts a newline.
        let view = NSTextView()
        let storage = NSTextStorage(attributedString: RichRender.attributedString(
            text: "a\nb",
            rich: RichBody(text: "a\nb", blocks: [
                RichBlockRun(location: 0, length: 2, list: .numbered),
                RichBlockRun(location: 2, length: 1, list: .numbered),
            ])))
        view.textStorage?.setAttributedString(storage)
        view.setSelectedRange(NSRange(location: 1, length: 0))
        view.typingAttributes = RichRender.attributes(at: 1, in: view)
        view.insertText("\n", replacementRange: view.selectedRange())
        XCTAssertEqual(view.string, "a\n\nb")
        let paras = (view.string as NSString).allParagraphRanges()
        XCTAssertEqual(paras.count, 3)
        for para in paras {
            let marker = (view.textStorage?.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
            XCTAssertEqual(marker, .decimal, "list continues on Return")
        }
    }
}
