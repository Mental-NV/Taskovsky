import Foundation

/// Paragraph list style for rich body blocks. Rendered with native AppKit
/// `NSTextList` markers (disc, decimal, box/check). The box/check checklist
/// is an inline body format with toolbar toggling; click-to-toggle on the
/// marker itself is not implemented. It does not replace task subtasks.
public enum RichListStyle: String, Codable, Equatable, Sendable {
    case bullet
    case numbered
    case checklist
}

public enum RichHighlightColor: String, Codable, CaseIterable, Sendable {
    case yellow, green, blue, pink, purple

    public var title: String { rawValue.capitalized }
}

/// One inline character run. Offsets are UTF-16 code units so they map
/// directly onto `NSString`/`NSTextStorage` ranges without any `Character`
/// versus glyph ambiguity (emoji and other multi-unit text stays aligned).
public struct RichInlineRun: Codable, Equatable, Sendable {
    public var location: Int
    public var length: Int
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    public var highlight: Bool
    /// Nil keeps the legacy yellow representation for highlighted text.
    public var highlightColor: RichHighlightColor?
    public var code: Bool
    public var link: String?

    public init(location: Int, length: Int, bold: Bool = false, italic: Bool = false,
                underline: Bool = false, strikethrough: Bool = false,
                highlight: Bool = false, code: Bool = false, link: String? = nil,
                highlightColor: RichHighlightColor? = nil) {
        self.location = location; self.length = length
        self.bold = bold; self.italic = italic
        self.underline = underline; self.strikethrough = strikethrough
        self.highlight = highlight || highlightColor != nil
        self.highlightColor = highlightColor == .yellow ? nil : highlightColor
        self.code = code; self.link = link
    }

    public var effectiveHighlight: RichHighlightColor? { highlightColor ?? (highlight ? .yellow : nil) }

    /// True when the run carries no styling (never persisted).
    public var isEmpty: Bool {
        !bold && !italic && !underline && !strikethrough && effectiveHighlight == nil && !code && link == nil
    }

    private enum CodingKeys: String, CodingKey {
        case location, length, bold, italic, underline, strikethrough, highlight, highlightColor, code, link
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = try c.decodeIfPresent(Int.self, forKey: .location) ?? 0
        length = try c.decodeIfPresent(Int.self, forKey: .length) ?? 0
        bold = try c.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        italic = try c.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        underline = try c.decodeIfPresent(Bool.self, forKey: .underline) ?? false
        strikethrough = try c.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
        let color = try c.decodeIfPresent(RichHighlightColor.self, forKey: .highlightColor)
        highlightColor = color == .yellow ? nil : color
        highlight = (try c.decodeIfPresent(Bool.self, forKey: .highlight) ?? false) || color != nil
        code = try c.decodeIfPresent(Bool.self, forKey: .code) ?? false
        link = try c.decodeIfPresent(String.self, forKey: .link)
    }
}

/// One paragraph-level block run (heading, quote, or list). Offsets are
/// UTF-16 code units; the editor applies these to whole paragraphs.
public struct RichBlockRun: Codable, Equatable, Sendable {
    public var location: Int
    public var length: Int
    public var heading: Int?
    public var quote: Bool
    public var list: RichListStyle?
    /// Checklist state; meaningful only when `list == .checklist`.
    public var checked: Bool?
    /// Horizontal rule. Only meaningful on an otherwise empty paragraph: a
    /// rule is an empty line carrying the marker, so the plain body keeps a
    /// blank line and the rich companion records it without touching text.
    public var rule: Bool
    /// Adjacent code paragraphs with the same identity form one copyable block.
    public var codeBlockID: UUID?

    public init(location: Int, length: Int, heading: Int? = nil, quote: Bool = false, list: RichListStyle? = nil, checked: Bool? = nil, rule: Bool = false, codeBlockID: UUID? = nil) {
        self.location = location; self.length = length
        self.heading = heading; self.quote = quote; self.list = list; self.checked = checked
        self.rule = rule
        self.codeBlockID = codeBlockID
    }

    /// True when the run carries no styling (never persisted).
    public var isEmpty: Bool {
        validHeading == nil && !quote && list == nil && !rule && codeBlockID == nil
    }

    private enum CodingKeys: String, CodingKey {
        case location, length, heading, quote, list, checked, rule, codeBlockID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        location = try c.decodeIfPresent(Int.self, forKey: .location) ?? 0
        length = try c.decodeIfPresent(Int.self, forKey: .length) ?? 0
        heading = try c.decodeIfPresent(Int.self, forKey: .heading)
        quote = try c.decodeIfPresent(Bool.self, forKey: .quote) ?? false
        list = try c.decodeIfPresent(RichListStyle.self, forKey: .list)
        checked = try c.decodeIfPresent(Bool.self, forKey: .checked)
        rule = try c.decodeIfPresent(Bool.self, forKey: .rule) ?? false
        codeBlockID = try c.decodeIfPresent(UUID.self, forKey: .codeBlockID)
    }

    /// Normalized heading in 1...6 (reference exposes Heading 1–6), or nil
    /// when unset or out of range.
    public var validHeading: Int? {
        guard let heading, (1...6).contains(heading) else { return nil }
        return heading
    }
}

/// Safe Codable rich-text companion to `TaskItem.body`.
///
/// `text` mirrors the plain body it was extracted from and the plain body is
/// always authoritative: `valid(for:)` returns nil whenever `text` no longer
/// equals the task body, so attributes can never silently apply to different
/// text after templates, body edits, or URL-title fills replace it.
public struct RichBody: Codable, Equatable, Sendable {
    public var text: String
    public var runs: [RichInlineRun]
    public var blocks: [RichBlockRun]

    public init(text: String, runs: [RichInlineRun] = [], blocks: [RichBlockRun] = []) {
        self.text = text; self.runs = runs; self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey { case text, runs, blocks }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        runs = try c.decodeIfPresent([RichInlineRun].self, forKey: .runs) ?? []
        blocks = try c.decodeIfPresent([RichBlockRun].self, forKey: .blocks) ?? []
    }

    /// True when there is nothing styled to persist.
    public var isEmpty: Bool {
        runs.allSatisfy(\.isEmpty) && blocks.allSatisfy(\.isEmpty)
    }

    public var hasCodeBlocks: Bool { blocks.contains { $0.codeBlockID != nil } }

    public var hasCustomHighlightColors: Bool { runs.contains { $0.highlightColor != nil } }

    public func isInCodeParagraph(at offset: Int) -> Bool {
        guard hasCodeBlocks else { return false }
        let string = text as NSString
        guard (0...string.length).contains(offset) else { return false }
        let paragraph = string.paragraphRange(for: NSRange(location: offset, length: 0))
        return paragraph.length > 0 && blocks.contains { $0.codeBlockID != nil && $0.location == paragraph.location }
    }

    /// Exact UTF-16 identity (NOT `String ==`, which treats canonically
    /// equivalent composed/decomposed Unicode as equal even though UTF-16
    /// lengths and offsets differ). A normalization change must never apply
    /// old offsets to a different code-unit sequence.
    public static func sameCodeUnits(_ a: String, _ b: String) -> Bool {
        a.utf16.elementsEqual(b.utf16)
    }

    /// Returns self only when the stored text is UTF-16-identical to `body`;
    /// nil otherwise. Callers must treat nil as plain text (styles clear,
    /// never shifted).
    public func valid(for body: String) -> RichBody? {
        Self.sameCodeUnits(text, body) ? self : nil
    }

    /// Clipped copy: each run is replaced by its actual intersection with
    /// `[0, textUTF16Length)`. Out-of-range and empty runs drop out, survivors
    /// sort by location. Clipping the real interval (instead of clamping the
    /// start while keeping the full length) never shifts styles onto new
    /// characters: `(-5, 2)` drops, `(-2, 4)` covers only `0..<2`.
    ///
    /// Bounds math is overflow-safe: a trapping `location + length` is never
    /// computed, so hostile ranges (`Int.min`/`Int.max`, negative offsets
    /// from malformed JSON) clip or drop instead of trapping.
    public func sanitized() -> RichBody {
        let end = (text as NSString).length
        func clip(location: Int, length: Int) -> (Int, Int)? {
            // Non-positive lengths (including Int.min) carry nothing.
            guard length > 0, end > 0 else { return nil }
            let start = min(max(0, location), end)
            // Safe upper bound of [location, location + length).
            let upper: Int
            if location >= 0 {
                let (sum, overflow) = location.addingReportingOverflow(length)
                upper = min(end, overflow ? Int.max : sum)
            } else {
                // location in [Int.min, -1], length in [1, Int.max]: the sum
                // always fits (Int.min + Int.max == -1), so no trap.
                upper = min(end, location + length)
            }
            guard upper > start else { return nil }
            return (start, upper - start)
        }
        let cleanRuns = runs.compactMap { run -> RichInlineRun? in
            guard !run.isEmpty, let (location, length) = clip(location: run.location, length: run.length) else { return nil }
            var run = run; run.location = location; run.length = length; return run
        }.sorted { $0.location < $1.location }
        let cleanBlocks = blocks.compactMap { block -> RichBlockRun? in
            guard !block.isEmpty, let (location, length) = clip(location: block.location, length: block.length) else { return nil }
            var block = block; block.location = location; block.length = length; return block
        }.sorted { $0.location < $1.location }
        return RichBody(text: text, runs: cleanRuns, blocks: cleanBlocks)
    }
}

/// Pinned-row policy shared by the list grouping and the store.
///
/// A row counts as pinned only while it is active: completed, Won't Do, and
/// trashed records keep their stored flag (so reopening restores it) but
/// never render as pinned rows.
public enum PinnedGrouping {
    public static let pinnedGroupTitle = "Pinned"

    public static func isPinnedRow(_ task: TaskItem) -> Bool {
        task.isPinned && task.deletedAt == nil && task.completedAt == nil && task.wontDoAt == nil
    }

    /// Stable partition preserving each side's incoming order.
    public static func partition(_ tasks: [TaskItem]) -> (pinned: [TaskItem], rest: [TaskItem]) {
        var pinned: [TaskItem] = []
        var rest: [TaskItem] = []
        for task in tasks {
            if isPinnedRow(task) { pinned.append(task) } else { rest.append(task) }
        }
        return (pinned, rest)
    }

    /// True when a drag crosses the pinned boundary in either direction: the
    /// drop target is a pinned row but not every dragged task is pinned, or
    /// vice versa. The row commit layer refuses such drops with a message
    /// instead of silently absorbing them; same-side drops are unaffected.
    public static func crossesPinnedBoundary(draggedIDs: [UUID], targetID: UUID, in tasks: [UUID: TaskItem]) -> Bool {
        guard !draggedIDs.isEmpty else { return false }
        let targetPinned = tasks[targetID].map(isPinnedRow) ?? false
        let allDraggedPinned = draggedIDs.allSatisfy { tasks[$0].map(isPinnedRow) ?? false }
        return targetPinned != allDraggedPinned
    }
}

/// Document-scoped undo policy for the rich body editor.
///
/// The editor view is reused across selections (including two tasks with
/// byte-identical bodies), so the "did the model move underneath the view"
/// check must ALSO key on the document ID: switching from task A to task B
/// with identical text and styles still invalidates A's undo history.
/// Clearing is safe because the editor owns a per-view UndoManager — title
/// fields and other views keep theirs.
public enum EditorDocumentGate {
    /// True when the editor must rebuild storage and drop its undo stack.
    /// - `lastDocumentID`: the document the storage was last built for (nil
    ///   on first load, where the stack is already empty).
    /// - `lastBody`/`lastRich`: the model the storage was last built from.
    /// - `documentID`/`body`/`rich`: the incoming model.
    public static func shouldReset(lastDocumentID: UUID?, lastBody: String?, lastRich: RichBody?, documentID: UUID, body: String, rich: RichBody?) -> Bool {
        // A new document always resets, even when text and styles match —
        // otherwise B inherits A's undo history and undo resurrects A's
        // text into B.
        guard let last = lastDocumentID, last == documentID else { return lastDocumentID != nil }
        // Same document: reset only when the model moved underneath the
        // view (template apply, external fill). Identity is UTF-16 code
        // units, matching the storage rebuild check.
        if let lastBody, RichBody.sameCodeUnits(lastBody, body), lastRich == rich { return false }
        return true
    }
}
