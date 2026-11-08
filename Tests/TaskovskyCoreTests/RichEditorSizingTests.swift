import AppKit
import XCTest
@testable import TaskovskyCore

/// Editor sizing: the frame must fit the laid-out content at the pane width.
///
/// Regression: at initial load the AppKit view still has a zero frame, so
/// measuring the live layout manager's usedRect under-reports (each
/// paragraph collapses to ~one line). The editor therefore measures on a
/// throwaway layout at the explicit frame width instead. These tests pin the
/// helper's contract: full content height, narrower panes taller than wide
/// ones, deterministic, finite for degenerate widths, insets-only for empty.
final class RichEditorSizingTests: XCTestCase {
    /// Eleven paragraphs mirroring the QA 'Release QA' sample shape.
    private func sampleContent() -> NSAttributedString {
        let lines = [
            "Launch checklist",
            "Ship the release",
            "Bold and italic mix here",
            "bulleted item with enough words to wrap onto a second line",
            "second bullet",
            "first step of the numbered sequence",
            "second step of the numbered sequence",
            "unchecked box item",
            "checked box item",
            "a quoted line with some extra words for wrapping",
            "code snippet and link below in the final paragraph",
        ]
        let text = lines.joined(separator: "\n")
        var off = 0
        var blocks: [RichBlockRun] = []
        for (i, line) in lines.enumerated() {
            let len = (line as NSString).length + 1 // include newline
            switch i {
            case 0: blocks.append(RichBlockRun(location: off, length: len, heading: 1))
            case 3, 4: blocks.append(RichBlockRun(location: off, length: len, list: .bullet))
            case 5, 6: blocks.append(RichBlockRun(location: off, length: len, list: .numbered))
            case 9: blocks.append(RichBlockRun(location: off, length: len, quote: true))
            default: break
            }
            off += len
        }
        let rich = RichBody(
            text: text,
            runs: [RichInlineRun(location: 0, length: 4, bold: true)],
            blocks: blocks)
        return RichRender.attributedString(text: text, rich: rich.valid(for: text))
    }

    /// The old load-time path (live usedRect at zero frame) reports a
    /// fraction of the real height; the explicit-width helper must not.
    func testZeroFrameLiveMeasurementUnderReports() {
        let content = sampleContent()
        let view = NSTextView(frame: .zero)
        view.textStorage?.setAttributedString(content)
        view.layoutManager?.ensureLayout(for: view.textContainer!)
        let stale = view.layoutManager!.usedRect(for: view.textContainer!).height
        let measured = RichEditorSizing.measuredHeight(for: content, width: 300)
        XCTAssertLessThan(stale, measured, "zero-frame usedRect (\(stale)) must under-report vs explicit width (\(measured))")
        XCTAssertGreaterThan(measured - stale, 20, "the under-report must be material, got \(measured - stale)")
        XCTAssertGreaterThan(measured, 150, "11 mixed paragraphs at 300pt must need real height, got \(measured)")
    }

    func testNarrowPaneTallerThanWidePane() {
        let content = sampleContent()
        let narrow = RichEditorSizing.measuredHeight(for: content, width: 300)
        let wide = RichEditorSizing.measuredHeight(for: content, width: 600)
        XCTAssertGreaterThan(narrow, wide)
        XCTAssertGreaterThan(wide, 150)
    }

    func testManyParagraphsNeedProportionalHeight() {
        let text = (0..<30).map { "Paragraph \($0) carries a full sentence so wrapping is exercised" }.joined(separator: "\n")
        let content = RichRender.attributedString(text: text, rich: nil)
        let narrow = RichEditorSizing.measuredHeight(for: content, width: 300)
        let wide = RichEditorSizing.measuredHeight(for: content, width: 900)
        XCTAssertGreaterThan(narrow, 400, "30 paragraphs must exceed the 60/120pt minimums, got \(narrow)")
        XCTAssertGreaterThanOrEqual(narrow, wide)
    }

    func testEmptyBodyStaysBelowMinimums() {
        // An empty document still lays out one line; it must stay well under
        // the task/note minimum frame heights (60/120) so the floor applies.
        let height = RichEditorSizing.measuredHeight(for: NSAttributedString(string: ""), width: 300)
        XCTAssertGreaterThan(height, RichEditorSizing.containerInsetHeight * 2)
        XCTAssertLessThan(height, 60)
    }

    func testDegenerateWidthStaysFinite() {
        let content = sampleContent()
        for width in [0, -50] {
            let height = RichEditorSizing.measuredHeight(for: content, width: CGFloat(width))
            XCTAssertTrue(height.isFinite && height > 0, "width \(width) gave \(height)")
        }
    }

    func testMeasurementIsDeterministic() {
        let content = sampleContent()
        XCTAssertEqual(
            RichEditorSizing.measuredHeight(for: content, width: 300),
            RichEditorSizing.measuredHeight(for: content, width: 300))
    }
}
