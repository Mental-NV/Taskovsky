import TaskovskyDomain
import AppKit
import Foundation

/// Visible list/quote decorations for prefix-free bodies.
///
/// The persisted body carries no literal markers (no `•`, `1.`, `[ ]`, `>`)
/// — they would corrupt UTF-16 style ranges, search, and the caret — so the
/// renderer must DRAW them. `textLists` paragraph metadata alone does not
/// draw in this TextKit 1 view, so the custom layout manager paints markers
/// and quote gutters from storage attributes, and this projection computes
/// the same marker/indent contract in a testable, AppKit-drawing-free form.
///
/// Gutter contract (points): list paragraphs reserve `gutterWidth` on the
/// first AND wrapped lines (`firstLineHeadIndent == headIndent == 24`), so
/// markers painted in `[padding, padding + 24)` never overlap text.
/// Quote paragraphs indent 16 with a 2pt bar drawn inside the indent.
public enum ListDecoration {
    /// Marker gutter reserved on every line of a list paragraph.
    public static let gutterWidth: CGFloat = 24
    /// Shared measurement and painting font; geometry is never persisted.
    public static let numberFont = NSFont.systemFont(ofSize: 13)

    /// Normalize decimal-run indents outside TextKit layout/drawing. All items
    /// in a run reserve its widest label, including off-screen predecessors.
    /// Attribute-only edits preserve text, ranges and all other paragraph style.
    @discardableResult public static func normalizeNumberedGutters(in storage: NSMutableAttributedString) -> Bool {
        let string = storage.string as NSString
        let paragraphs = string.paragraphRanges(intersecting: NSRange(location: 0, length: string.length))
        var changes: [(NSRange, NSMutableParagraphStyle)] = []
        var run: [NSRange] = []
        func finishRun() {
            guard !run.isEmpty else { return }
            let width = max(gutterWidth, ceil((1...run.count).map {
                ("\($0)." as NSString).size(withAttributes: [.font: numberFont]).width + 4
            }.max() ?? gutterWidth))
            for range in run {
                guard let old = storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle,
                      old.headIndent != width || old.firstLineHeadIndent != width,
                      let style = old.mutableCopy() as? NSMutableParagraphStyle else { continue }
                style.headIndent = width
                style.firstLineHeadIndent = width
                changes.append((range, style))
            }
            run.removeAll(keepingCapacity: true)
        }
        for paragraph in paragraphs where paragraph.length > 0 {
            let style = storage.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
            if style?.textLists.first?.markerFormat == .decimal { run.append(paragraph) }
            else { finishRun() }
        }
        finishRun()
        guard !changes.isEmpty else { return false }
        storage.beginEditing()
        for (range, style) in changes { storage.addAttribute(.paragraphStyle, value: style, range: range) }
        storage.endEditing()
        return true
    }

    /// Indent of a quote paragraph (bar drawn inside it).
    public static let quoteIndent: CGFloat = 16
    /// Width of the quote bar.
    public static let quoteBarWidth: CGFloat = 2

    /// A drawable marker. Numbers are 1-based positions in their contiguous
    /// group; unknown formats degrade to bullets (mirroring
    /// `RichRender.listStyle(for:)`).
    public enum MarkerKind: Equatable, Sendable {
        case bullet
        case number(Int)
        case checkbox(checked: Bool)
    }

    /// One paragraph's decoration inputs.
    public struct Paragraph: Sendable {
        public var range: NSRange
        /// `NSTextList` marker format from the paragraph style (nil = plain).
        public var markerFormat: NSTextList.MarkerFormat?
        public var quote: Bool
        public init(range: NSRange, markerFormat: NSTextList.MarkerFormat? = nil, quote: Bool = false) {
            self.range = range; self.markerFormat = markerFormat; self.quote = quote
        }
    }

    /// Marker per paragraph (nil = none). Numbered runs count contiguous
    /// immediately-preceding `.decimal` paragraphs; any other paragraph
    /// (plain, bullet, checklist, quote-only) resets the run, so numbering
    /// continues within a group and restarts after a break.
    public static func markers(for paragraphs: [Paragraph]) -> [MarkerKind?] {
        var out: [MarkerKind?] = []
        var run = 0
        for paragraph in paragraphs {
            switch paragraph.markerFormat {
            case .decimal:
                run += 1
                out.append(.number(run))
            case .box:
                run = 0
                out.append(.checkbox(checked: false))
            case .check:
                run = 0
                out.append(.checkbox(checked: true))
            case .none:
                run = 0
                out.append(nil)
            case .some:
                run = 0
                out.append(.bullet)
            }
        }
        return out
    }

    /// Paragraph entries derived from the persisted model (tests and
    /// model-side previews). Each model paragraph takes the list style of
    /// the block covering its first character and the quote flag covering
    /// it; unknown marker formats degrade to bullets at draw time.
    public static func entries(text: NSString, blocks: [RichBlockRun]) -> [Paragraph] {
        text.paragraphRanges(intersecting: NSRange(location: 0, length: text.length)).map { para in
            let block = blocks.first { NSLocationInRange(para.location, NSRange(location: $0.location, length: max($0.length, 1))) }
            let format: NSTextList.MarkerFormat? = {
                guard let list = block?.list else { return nil }
                switch list {
                case .bullet: return .disc
                case .numbered: return .decimal
                case .checklist: return (block?.checked ?? false) ? .check : .box
                }
            }()
            return Paragraph(range: para, markerFormat: format, quote: block?.quote ?? false)
        }
    }
}
