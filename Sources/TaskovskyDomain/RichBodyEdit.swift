import Foundation

public enum RichInlineFormat: String, CaseIterable, Codable, Sendable {
    case bold, italic, underline, strikethrough, highlight, code

    fileprivate var attribute: NSAttributedString.Key { .init("Taskovsky.richEdit." + rawValue) }
}

public enum RichParagraphEdit: Codable, Sendable {
    case heading(Int?)
    case quote(Bool)
    case list(RichListStyle?)
    case checklistChecked(Bool)
    case horizontalRule(Bool)
    case codeBlock(UUID?)
    case clear
}

public enum RichBodyEditError: Error, Equatable, Sendable {
    case invalidSource, invalidRange, invalidLink, invalidParagraph, styledParagraphBoundary
}

/// Semantic edits use UTF-16 ranges in the document produced by the
/// preceding operation. Platform editors own selection, composition and undo.
public enum RichBodyEdit: Codable, Sendable {
    public enum InsertionStyle: Codable, Equatable, Sendable { case inherit, plain }

    case replace(NSRange, with: String, style: InsertionStyle)
    case paste(NSRange, fragment: RichBody)
    case toggle(RichInlineFormat, NSRange)
    case setHighlight(RichHighlightColor?, NSRange)
    case setLink(String?, NSRange)
    case clearInline(NSRange)
    case paragraph(RichParagraphEdit, NSRange)

    public static func applying(_ edits: [Self], to body: String, rich: RichBody?) throws -> RichBody {
        if let rich {
            guard let preview = RichDescriptionPreview(body: body, rich: rich),
                  rich.blocks.allSatisfy({ $0.checked == nil || $0.list == .checklist })
            else { throw RichBodyEditError.invalidSource }
            let ruleParagraphs = preview.paragraphs.filter(\.rule)
            for block in rich.blocks where block.rule {
                let range = NSRange(location: block.location, length: block.length)
                guard ruleParagraphs.contains(where: { NSIntersectionRange($0.range, range).length > 0 })
                else { throw RichBodyEditError.invalidSource }
            }
        }
        var current = rich ?? RichBody(text: body)
        for edit in edits {
            current = try edit.applying(to: current)
        }
        return current
    }

    public static func togglingCodeBlock(in body: RichBody, selection: NSRange) -> Self? {
        guard (try? validate(selection, in: body.text)) != nil,
              let preview = RichDescriptionPreview(body: body.text, rich: body) else { return nil }
        let text = body.text as NSString
        let start = text.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let end = text.paragraphRange(for: NSRange(location: max(selection.location, NSMaxRange(selection) - 1), length: 0))
        let target = NSUnionRange(start, end)
        guard target.length > 0 else { return nil }
        let paragraphs = preview.paragraphs.filter { NSLocationInRange($0.range.location, target) }
        let id = paragraphs.allSatisfy { $0.codeBlockID != nil } ? nil : UUID()
        return .paragraph(.codeBlock(id), selection)
    }

    /// Reconciles a native text change, preserving the reported edit location
    /// when identical text could make a snapshot diff choose another range.
    public static func replacement(from original: String, to edited: String, style: InsertionStyle,
                                   replacing preferredRange: NSRange? = nil) -> Self? {
        let old = Array(original.utf16)
        let new = Array(edited.utf16)
        func boundary(_ offset: Int, in units: [UInt16]) -> Bool {
            offset == units.count || !(0xDC00...0xDFFF).contains(units[offset])
        }
        if let range = preferredRange, (try? validate(range, in: original)) != nil {
            let start = range.location
            let oldEnd = NSMaxRange(range)
            let newEnd = new.count - (old.count - oldEnd)
            if newEnd >= start, boundary(start, in: new), boundary(newEnd, in: new),
               old[..<start].elementsEqual(new[..<start]), old[oldEnd...].elementsEqual(new[newEnd...]) {
                let replacement = new[start..<newEnd]
                guard style == .plain || !old[start..<oldEnd].elementsEqual(replacement) else { return nil }
                return .replace(range, with: String(decoding: replacement, as: UTF16.self), style: style)
            }
        }

        guard old != new else { return nil }
        var start = 0
        while start < min(old.count, new.count), old[start] == new[start] { start += 1 }
        while !boundary(start, in: old) || !boundary(start, in: new) { start -= 1 }

        var oldEnd = old.count
        var newEnd = new.count
        while oldEnd > start, newEnd > start, old[oldEnd - 1] == new[newEnd - 1] {
            oldEnd -= 1
            newEnd -= 1
        }
        while !boundary(oldEnd, in: old) || !boundary(newEnd, in: new) {
            oldEnd += 1
            newEnd += 1
        }
        return .replace(NSRange(location: start, length: oldEnd - start),
                        with: String(decoding: new[start..<newEnd], as: UTF16.self), style: style)
    }

    private static let linkAttribute = NSAttributedString.Key("Taskovsky.richEdit.link")

    private func applying(to body: RichBody) throws -> RichBody {
        switch self {
        case .replace(let range, let replacement, let style):
            try Self.validate(range, in: body.text)
            return try Self.replace(range, with: replacement, style: style, in: body)
        case .paste(let range, let fragment):
            try Self.validate(range, in: body.text)
            return try Self.paste(fragment, replacing: range, in: body)
        case .toggle(let format, let range):
            try Self.validate(range, in: body.text, empty: false)
            let inline = Self.inlineContent(body)
            var allStyled = true
            inline.enumerateAttribute(format.attribute, in: range) { value, _, stop in
                if value == nil { allStyled = false; stop.pointee = true }
            }
            if allStyled { inline.removeAttribute(format.attribute, range: range) }
            else {
                let value: Any = format == .highlight ? RichHighlightColor.yellow.rawValue : true
                inline.addAttribute(format.attribute, value: value, range: range)
            }
            return RichBody(text: body.text, runs: Self.extractInline(inline), blocks: body.blocks)
        case .setHighlight(let color, let range):
            try Self.validate(range, in: body.text, empty: false)
            let inline = Self.inlineContent(body)
            if let color { inline.addAttribute(RichInlineFormat.highlight.attribute, value: color.rawValue, range: range) }
            else { inline.removeAttribute(RichInlineFormat.highlight.attribute, range: range) }
            return RichBody(text: body.text, runs: Self.extractInline(inline), blocks: body.blocks)
        case .setLink(let link, let range):
            try Self.validate(range, in: body.text, empty: false)
            let inline = Self.inlineContent(body)
            if let link {
                guard Self.supportsLink(link) else { throw RichBodyEditError.invalidLink }
                inline.addAttribute(Self.linkAttribute, value: Data(link.utf8), range: range)
            } else {
                inline.removeAttribute(Self.linkAttribute, range: range)
            }
            return RichBody(text: body.text, runs: Self.extractInline(inline), blocks: body.blocks)
        case .clearInline(let range):
            try Self.validate(range, in: body.text, empty: false)
            let inline = Self.inlineContent(body)
            inline.setAttributes([:], range: range)
            return RichBody(text: body.text, runs: Self.extractInline(inline), blocks: body.blocks)
        case .paragraph(let edit, let range):
            try Self.validate(range, in: body.text)
            return try Self.editParagraphs(edit, range: range, in: body)
        }
    }

    fileprivate static func validate(_ range: NSRange, in text: String, empty: Bool = true) throws {
        let units = text.utf16
        let count = units.count
        guard range.location >= 0, range.location <= count, range.length >= 0,
              range.length <= count - range.location, empty || range.length > 0
        else { throw RichBodyEditError.invalidRange }
        func boundary(_ offset: Int) -> Bool {
            offset == count || !(0xDC00...0xDFFF).contains(units[units.index(units.startIndex, offsetBy: offset)])
        }
        guard boundary(range.location), boundary(NSMaxRange(range)) else { throw RichBodyEditError.invalidRange }
    }

    public static func supportsLink(_ link: String) -> Bool {
        guard let components = URLComponents(string: link),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else { return false }
        return components.url != nil
    }

    private static func inlineContent(_ body: RichBody) -> NSMutableAttributedString {
        let inline = NSMutableAttributedString(string: body.text)
        // The preview layers inline styles by start offset. For equal starts,
        // retain stored order so the later link stays on top.
        for (_, run) in body.runs.enumerated().sorted(by: {
            $0.element.location == $1.element.location ? $0.offset < $1.offset : $0.element.location < $1.element.location
        }) {
            let range = NSRange(location: run.location, length: run.length)
            let active: [(RichInlineFormat, Bool)] = [
                (.bold, run.bold), (.italic, run.italic), (.underline, run.underline),
                (.strikethrough, run.strikethrough), (.code, run.code)
            ]
            for (format, enabled) in active where enabled {
                inline.addAttribute(format.attribute, value: true, range: range)
            }
            if let color = run.effectiveHighlight {
                inline.addAttribute(RichInlineFormat.highlight.attribute, value: color.rawValue, range: range)
            }
            if let link = run.link { inline.addAttribute(linkAttribute, value: Data(link.utf8), range: range) }
        }
        return inline
    }

    private static func extractInline(_ inline: NSAttributedString) -> [RichInlineRun] {
        var runs: [RichInlineRun] = []
        inline.enumerateAttributes(in: NSRange(location: 0, length: inline.length)) { attributes, range, _ in
            func present(_ format: RichInlineFormat) -> Bool { attributes[format.attribute] != nil }
            let link = (attributes[linkAttribute] as? Data).flatMap { String(data: $0, encoding: .utf8) }
            let color = (attributes[RichInlineFormat.highlight.attribute] as? String).flatMap(RichHighlightColor.init(rawValue:))
            let run = RichInlineRun(location: range.location, length: range.length,
                                    bold: present(.bold), italic: present(.italic), underline: present(.underline),
                                    strikethrough: present(.strikethrough), highlight: present(.highlight),
                                    code: present(.code), link: link, highlightColor: color)
            if !run.isEmpty { runs.append(run) }
        }
        return runs
    }

    private static func replace(_ range: NSRange, with replacement: String, style: InsertionStyle,
                                in body: RichBody) throws -> RichBody {
        let text = body.text as NSString
        let removed = text.substring(with: range)
        if style == .inherit && RichBody.sameCodeUnits(removed, replacement) { return body }

        let delta = replacement.utf16.count - range.length
        let start = text.paragraphRange(for: NSRange(location: range.location, length: 0))
        let end = text.paragraphRange(for: NSRange(location: NSMaxRange(range), length: 0))
        let touched = NSUnionRange(start, end)
        let editedText = text.replacingCharacters(in: range, with: replacement)
        let mergesParagraphs = removed.unicodeScalars.contains(where: CharacterSet.newlines.contains) ||
            splitsCRLF(text, at: range.location) || splitsCRLF(text, at: NSMaxRange(range))
        let insertsBreaks = replacement.unicodeScalars.contains(where: CharacterSet.newlines.contains)
        let affectedBlocks = body.blocks.filter {
            NSIntersectionRange(NSRange(location: $0.location, length: $0.length), touched).length > 0
        }
        let codeID = affectedBlocks.first?.codeBlockID
        let joinsCodeParagraphs = mergesParagraphs && codeID != nil &&
            !splitsCRLF(text, at: range.location) && !splitsCRLF(text, at: NSMaxRange(range)) &&
            affectedBlocks.allSatisfy { $0.codeBlockID == codeID } &&
            affectedBlocks.reduce(0) { $0 + $1.length } == touched.length
        let blocks = try body.blocks.flatMap { block -> [RichBlockRun] in
            let annotated = NSRange(location: block.location, length: block.length)
            var copy = block
            if NSIntersectionRange(annotated, touched).length > 0 {
                if joinsCodeParagraphs {
                    guard block.location == touched.location else { return [] }
                    return try splitParagraph(copy, editedLength: touched.length + delta, anchor: touched.location, in: editedText)
                }
                guard !mergesParagraphs else { throw RichBodyEditError.styledParagraphBoundary }
                guard annotated == start, start == end, !block.rule, affectedBlocks.count == 1
                else { throw RichBodyEditError.invalidParagraph }
                if insertsBreaks {
                    let anchor = range.location == start.location && range.length < start.length
                        ? range.location + replacement.utf16.count : start.location
                    return try splitParagraph(copy, editedLength: start.length + delta, anchor: anchor, in: editedText)
                }
                copy.length += delta
                return copy.length > 0 ? [copy] : []
            }
            if block.location >= NSMaxRange(touched) { copy.location += delta }
            return [copy]
        }

        let inline = inlineContent(body)
        var attributes: [NSAttributedString.Key: Any] = [:]
        if style == .inherit, inline.length > 0 {
            let anchor = max(0, range.location - 1)
            attributes = inline.attributes(at: anchor, effectiveRange: nil)
            if attributes[linkAttribute] != nil {
                var bounds = NSRange()
                _ = inline.attribute(linkAttribute, at: anchor, longestEffectiveRange: &bounds,
                                     in: NSRange(location: 0, length: inline.length))
                // Typing inside a link extends it. Typing at a boundary does
                // not make the adjacent text part of that link.
                if range.location <= bounds.location || NSMaxRange(range) >= NSMaxRange(bounds) {
                    attributes.removeValue(forKey: linkAttribute)
                }
            }
        }
        inline.replaceCharacters(in: range, with: NSAttributedString(string: replacement, attributes: attributes))
        guard RichBody.sameCodeUnits(inline.string, editedText)
        else { throw RichBodyEditError.invalidRange }
        return RichBody(text: inline.string, runs: extractInline(inline), blocks: blocks)
    }

    private static func paste(_ fragment: RichBody, replacing range: NSRange, in body: RichBody) throws -> RichBody {
        guard RichBodyClipboard.isValid(fragment) else { throw RichBodyEditError.invalidSource }
        let original = body.text as NSString
        let edited = original.replacingCharacters(in: range, with: fragment.text) as NSString
        let inserted = NSRange(location: range.location, length: fragment.text.utf16.count)
        let oldEnd = NSMaxRange(range)
        let newEnd = NSMaxRange(inserted)
        guard !splitsCRLF(original, at: range.location), !splitsCRLF(original, at: oldEnd),
              !splitsCRLF(edited, at: inserted.location), !splitsCRLF(edited, at: newEnd)
        else { throw RichBodyEditError.styledParagraphBoundary }

        var blocks: [RichBlockRun]
        if paragraphBoundary(range.location, in: original), paragraphBoundary(oldEnd, in: original),
           paragraphBoundary(inserted.location, in: edited), paragraphBoundary(newEnd, in: edited) {
            // Full paragraphs can be replaced without merging a neighboring
            // styled paragraph. Keep the old boundary checks for partial edits.
            let delta = inserted.length - range.length
            blocks = try body.blocks.compactMap { block in
                let span = NSRange(location: block.location, length: block.length)
                if NSMaxRange(span) <= range.location { return block }
                if span.location >= oldEnd {
                    var shifted = block
                    shifted.location += delta
                    return shifted
                }
                guard NSIntersectionRange(span, range) == span else { throw RichBodyEditError.styledParagraphBoundary }
                return nil
            }
        } else {
            blocks = try replace(range, with: fragment.text, style: .plain, in: body).blocks
        }

        // A paragraph joined to existing destination text keeps its
        // destination style. Only complete pasted paragraphs bring blocks.
        let interior = { (span: NSRange) in
            span.location >= inserted.location && NSMaxRange(span) <= newEnd &&
            edited.paragraphRange(for: NSRange(location: span.location, length: 1)) == span
        }
        blocks.removeAll { interior(NSRange(location: $0.location, length: $0.length)) }
        for var block in fragment.blocks {
            block.location += inserted.location
            if interior(NSRange(location: block.location, length: block.length)) { blocks.append(block) }
        }
        let inline = inlineContent(body)
        inline.replaceCharacters(in: range, with: inlineContent(fragment))
        guard RichBody.sameCodeUnits(inline.string, edited as String) else { throw RichBodyEditError.invalidRange }
        return RichBody(text: inline.string, runs: extractInline(inline), blocks: blocks.sorted { $0.location < $1.location })
    }

    private static func paragraphBoundary(_ offset: Int, in text: NSString) -> Bool {
        offset == text.length || text.paragraphRange(for: NSRange(location: offset, length: 1)).location == offset
    }

    fileprivate static func splitsCRLF(_ text: NSString, at offset: Int) -> Bool {
        offset > 0 && offset < text.length &&
            text.character(at: offset - 1) == 0x0D && text.character(at: offset) == 0x0A
    }

    private static func splitParagraph(_ original: RichBlockRun, editedLength: Int,
                                       anchor: Int, in edited: String) throws -> [RichBlockRun] {
        let text = edited as NSString
        let end = original.location + editedLength
        var offset = original.location
        var paragraphs: [RichBlockRun] = []
        while offset < end {
            let paragraph = text.paragraphRange(for: NSRange(location: offset, length: 1))
            guard paragraph.location == offset, NSMaxRange(paragraph) <= end
            else { throw RichBodyEditError.styledParagraphBoundary }
            let retainsOriginal = NSLocationInRange(anchor, paragraph)
            let block = RichBlockRun(location: offset, length: paragraph.length,
                                     heading: retainsOriginal ? original.heading : nil, quote: original.quote,
                                     list: original.list, checked: retainsOriginal ? original.checked : nil,
                                     codeBlockID: original.codeBlockID)
            if !block.isEmpty { paragraphs.append(block) }
            offset = NSMaxRange(paragraph)
        }
        return paragraphs
    }

    private static func editParagraphs(_ edit: RichParagraphEdit, range: NSRange, in body: RichBody) throws -> RichBody {
        let text = body.text as NSString
        let first = text.paragraphRange(for: NSRange(location: range.location, length: 0))
        let lastOffset = range.length > 0 ? NSMaxRange(range) - 1 : range.location
        let last = text.paragraphRange(for: NSRange(location: lastOffset, length: 0))
        let target = NSUnionRange(first, last)
        guard target.length > 0 else { throw RichBodyEditError.invalidParagraph }
        var blocks = body.blocks.filter {
            NSIntersectionRange(NSRange(location: $0.location, length: $0.length), target).length == 0
        }
        var offset = target.location
        while offset < NSMaxRange(target) {
            var end = 0
            var contentEnd = 0
            text.getParagraphStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: offset, length: 1))
            let paragraph = NSRange(location: offset, length: end - offset)
            let annotations = body.blocks.filter {
                NSIntersectionRange(NSRange(location: $0.location, length: $0.length), paragraph).length > 0
            }
            guard annotations.count <= 1, annotations.first.map({ $0.location == offset && $0.length == paragraph.length }) != false
            else { throw RichBodyEditError.invalidParagraph }
            var block = annotations.first ?? RichBlockRun(location: offset, length: paragraph.length)
            switch edit {
            case .heading(let level):
                if let level, !(1...6).contains(level) { throw RichBodyEditError.invalidParagraph }
                block.codeBlockID = nil
                block.heading = level
            case .quote(let enabled):
                block.codeBlockID = nil
                block.quote = enabled
            case .list(let style):
                block.codeBlockID = nil
                if style != block.list { block.checked = nil }
                block.list = style
            case .checklistChecked(let checked):
                guard block.list == .checklist else { throw RichBodyEditError.invalidParagraph }
                block.checked = checked ? true : nil
            case .horizontalRule(let enabled):
                guard !enabled || contentEnd == offset else { throw RichBodyEditError.invalidParagraph }
                block.codeBlockID = nil
                block.rule = enabled
            case .codeBlock(let id):
                if let id { block = .init(location: offset, length: paragraph.length, codeBlockID: id) }
                else { block.codeBlockID = nil }
            case .clear:
                block = RichBlockRun(location: offset, length: paragraph.length)
            }
            if !block.isEmpty { blocks.append(block) }
            offset = end
        }
        return RichBody(text: body.text, runs: body.runs, blocks: blocks.sorted { $0.location < $1.location })
    }
}

/// A typed shortcut is an ordinary rich edit with a new caret. A paragraph
/// with no text yet has no persisted run, so its style is armed in the editor.
public enum RichMarkdownTyping {
    public struct Change {
        public let edit: RichBodyEdit
        public let caret: NSRange
        public let armedParagraph: ArmedParagraph?
    }

    public struct ArmedParagraph {
        public let caret: NSRange
        fileprivate let text: String
        fileprivate let block: RichBlockRun

        public func accepts(_ selection: NSRange, in body: RichBody) -> Bool {
            selection == caret && RichBody.sameCodeUnits(text, body.text)
        }

        public func inserting(_ inserted: String, at range: NSRange, in body: RichBody) -> Change? {
            guard accepts(range, in: body), !inserted.isEmpty,
                  !inserted.unicodeScalars.contains(where: CharacterSet.newlines.contains) else { return nil }
            let source = body.text as NSString
            let paragraph = source.paragraphRange(for: caret)
            guard paragraph.location == caret.location else { return nil }
            let text = inserted + source.substring(with: paragraph)
            return styledParagraph(text, replacing: paragraph, block: block, caret: caret.location + inserted.utf16.count)
        }
    }

    public static func change(for inserted: String, at range: NSRange, in body: RichBody) -> Change? {
        let isReturn = inserted == "\n" || inserted == "\r" || inserted == "\r\n"
        guard (isReturn || inserted == " " || inserted == "-"), range.length == 0,
              (try? RichBodyEdit.validate(range, in: body.text)) != nil else { return nil }
        let source = body.text as NSString
        var start = 0, end = 0, contentEnd = 0
        source.getParagraphStart(&start, end: &end, contentsEnd: &contentEnd, for: range)
        let caret = range.location
        guard start <= caret, caret <= contentEnd else { return nil }
        let paragraph = NSRange(location: start, length: end - start)
        if isReturn { return codeReturn(inserted, at: range, paragraph: paragraph, contentEnd: contentEnd, in: body) }
        guard caret - start <= 4096, !body.isInCodeParagraph(at: caret) else { return nil }
        let prefixRange = NSRange(location: start, length: caret - start)
        let prefix = source.substring(with: prefixRange)
        if inserted == "-" {
            guard prefix == "--", caret == contentEnd, !protected(prefixRange, in: body),
                  !insideFence(before: start, in: body),
                  !body.blocks.contains(where: { $0.location == start }) else { return nil }
            let terminator = caret == end ? "\n" : source.substring(with: NSRange(location: caret, length: end - caret))
            return styledParagraph(terminator, replacing: NSRange(location: start, length: end - start),
                                   block: .init(location: 0, length: 0, rule: true),
                                   caret: start + terminator.utf16.count)
        }
        if let block = block(for: prefix, at: start, in: body), !protected(prefixRange, in: body),
           !insideFence(before: start, in: body) {
            if caret == contentEnd {
                let newCaret = NSRange(location: start, length: 0)
                let arm = ArmedParagraph(caret: newCaret, text: source.replacingCharacters(in: prefixRange, with: ""), block: block)
                return Change(edit: .replace(prefixRange, with: "", style: .plain), caret: newCaret, armedParagraph: arm)
            }
            let content = NSRange(location: caret, length: end - caret)
            guard let fragment = RichBodyClipboard.fragment(from: body, selection: content) else { return nil }
            return styledParagraph(fragment.text, replacing: paragraph, block: block, runs: fragment.runs, caret: start)
        }
        guard let change = inlineChange(prefix, start: start, in: body),
              !insideFence(before: start, in: body) else { return nil }
        return change
    }

    public static func listContinuation(for inserted: String, at range: NSRange, in body: RichBody) -> Change? {
        let isReturn = inserted == "\n" || inserted == "\r" || inserted == "\r\n"
        let source = body.text as NSString
        guard range.length == 0, range.location <= source.length,
              isReturn || (source.length - range.location <= 2 && !inserted.isEmpty &&
                           !inserted.unicodeScalars.contains(where: CharacterSet.newlines.contains)),
              (try? RichBodyEdit.validate(range, in: body.text)) != nil else { return nil }
        var start = 0, end = 0, contentEnd = 0
        source.getParagraphStart(&start, end: &end, contentsEnd: &contentEnd, for: range)
        let paragraph = NSRange(location: start, length: end - start)
        guard range.location <= contentEnd,
              var block = body.blocks.first(where: { $0.location == start && $0.length == paragraph.length }),
              block.list != nil, !block.rule else { return nil }

        if start == contentEnd {
            if end == source.length {
                // Give the blank marker a real range until the first input or exit.
                if isReturn {
                    return Change(edit: .paste(paragraph, fragment: RichBody(text: "")), caret: range, armedParagraph: nil)
                }
                block.location = 0
                return styledParagraph(inserted, replacing: paragraph, block: block, caret: start + inserted.utf16.count)
            }
            guard isReturn else { return nil }
            return Change(edit: .paragraph(.clear, paragraph), caret: range, armedParagraph: nil)
        }

        guard isReturn else { return nil }
        let lineBreak = contentEnd == end ? inserted : source.substring(with: NSRange(location: contentEnd, length: end - contentEnd))
        let replacement = range.location == source.length ? lineBreak + lineBreak : lineBreak
        return Change(edit: .replace(range, with: replacement, style: .plain),
                      caret: NSRange(location: range.location + lineBreak.utf16.count, length: 0), armedParagraph: nil)
    }

    private static func codeReturn(_ inserted: String, at range: NSRange, paragraph: NSRange,
                                   contentEnd: Int, in body: RichBody) -> Change? {
        let source = body.text as NSString
        let end = NSMaxRange(paragraph)
        let content = NSRange(location: paragraph.location, length: contentEnd - paragraph.location)
        let current = body.blocks.first { $0.location == paragraph.location }
        let existingBreak = source.substring(with: NSRange(location: contentEnd, length: end - contentEnd))
        let lineBreak = existingBreak.isEmpty ? inserted : existingBreak
        let isFence = range.location == contentEnd && content.length == 3 && source.substring(with: content) == "```"
        if current?.codeBlockID != nil {
            if isFence {
                // Leave a plain caret line ahead of existing text. At EOF the
                // preceding code paragraph already provides its separator.
                let text = end < source.length ? existingBreak : ""
                return Change(edit: .paste(paragraph, fragment: RichBody(text: text)),
                              caret: NSRange(location: paragraph.location, length: 0), armedParagraph: nil)
            }
            // If the last code paragraph has no terminator, keep a second
            // separator as the blank code paragraph the caret enters.
            let replacement = range.location == source.length ? lineBreak + lineBreak : lineBreak
            return Change(edit: .replace(range, with: replacement, style: .plain),
                          caret: NSRange(location: range.location + lineBreak.utf16.count, length: 0), armedParagraph: nil)
        }
        guard isFence, current == nil, !protected(content, in: body),
              !insideFence(before: paragraph.location, in: body) else { return nil }
        return styledParagraph(lineBreak, replacing: paragraph, block: .init(location: 0, length: 0, codeBlockID: UUID()),
                               caret: paragraph.location)
    }

    private static func block(for marker: String, at start: Int, in body: RichBody) -> RichBlockRun? {
        var block = RichBlockRun(location: 0, length: 0)
        switch marker {
        case "-": block.list = .bullet
        case "1.": block.list = .numbered
        case ">": block.quote = true
        case "- [ ]", "- [x]", "- [X]":
            block.list = .checklist
            if marker != "- [ ]" { block.checked = true }
        case "[ ]", "[x]", "[X]":
            guard body.blocks.contains(where: { $0.location == start && $0.list == .bullet }) else { return nil }
            block.list = .checklist
            if marker != "[ ]" { block.checked = true }
        default:
            guard (1...6).contains(marker.utf16.count), marker.utf16.allSatisfy({ $0 == 35 }) else { return nil }
            block.heading = marker.utf16.count
        }
        return block
    }

    private static func styledParagraph(_ text: String, replacing range: NSRange, block: RichBlockRun,
                                        runs: [RichInlineRun] = [], caret: Int) -> Change {
        var block = block
        block.length = text.utf16.count
        let fragment = RichBody(text: text, runs: runs, blocks: [block])
        return Change(edit: .paste(range, fragment: fragment), caret: NSRange(location: caret, length: 0), armedParagraph: nil)
    }

    private static func inlineChange(_ prefix: String, start: Int, in body: RichBody) -> Change? {
        guard !prefix.contains("`") else { return nil }
        let line = prefix as NSString
        for (marker, format) in [("**", RichInlineFormat.bold), ("*", .italic), ("==", .highlight), ("~~", .strikethrough)] {
            guard prefix.hasSuffix(marker) else { continue }
            let size = marker.utf16.count
            let close = line.length - size
            let open = line.range(of: marker, options: .backwards, range: NSRange(location: 0, length: close)).location
            guard open != NSNotFound, open + size < close else { continue }
            if open > 0 {
                guard let previous = UnicodeScalar(line.character(at: open - 1)),
                      CharacterSet.whitespaces.contains(previous) || "([{“‘".unicodeScalars.contains(previous)
                else { continue }
            }
            let range = NSRange(location: start + open, length: line.length - open)
            let content = NSRange(location: range.location + size, length: close - open - size)
            guard !protected(range, in: body),
                  var fragment = RichBodyClipboard.fragment(from: body, selection: content),
                  fragment.text.rangeOfCharacter(from: CharacterSet(charactersIn: "*~=")) == nil,
                  let first = fragment.text.unicodeScalars.first, let last = fragment.text.unicodeScalars.last,
                  !CharacterSet.whitespaces.contains(first), !CharacterSet.whitespaces.contains(last) else { continue }
            fragment.runs.append(RichInlineRun(location: 0, length: content.length, bold: format == .bold,
                                              italic: format == .italic, strikethrough: format == .strikethrough,
                                              highlight: format == .highlight))
            fragment.text += " "
            // A replacement of the entire final paragraph must carry its
            // block as well. Partial edits keep the destination block.
            if range.location == start, NSMaxRange(range) == body.text.utf16.count,
               let paragraph = RichBodyClipboard.fragment(from: body, selection: range) {
                fragment.blocks = paragraph.blocks.map { block in
                    var resized = block
                    resized.length = fragment.text.utf16.count
                    return resized
                }
            }
            return Change(edit: .paste(range, fragment: fragment),
                          caret: NSRange(location: range.location + content.length + 1, length: 0), armedParagraph: nil)
        }
        return nil
    }

    private static func protected(_ range: NSRange, in body: RichBody) -> Bool {
        body.runs.contains { run in
            (run.code || run.link != nil) && NSIntersectionRange(range, NSRange(location: run.location, length: run.length)).length > 0
        }
    }

    private static func insideFence(before limit: Int, in body: RichBody) -> Bool {
        let source = body.text as NSString
        let codeStarts = Set(body.blocks.compactMap { $0.codeBlockID == nil ? nil : $0.location })
        var fence: Substring?
        var offset = 0
        while offset < limit {
            let start = offset
            var contentEnd = 0
            source.getParagraphStart(nil, end: &offset, contentsEnd: &contentEnd,
                                     for: NSRange(location: start, length: 1))
            if codeStarts.contains(start) { continue }
            let line = source.substring(with: NSRange(location: start, length: contentEnd - start))
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first, first == "`" || first == "~" else { continue }
            let marker = trimmed.prefix { $0 == first }
            guard marker.count >= 3 else { continue }
            if let open = fence {
                if marker.hasPrefix(open), marker.count == trimmed.count { fence = nil }
            } else {
                fence = marker
            }
        }
        return fence != nil
    }
}

/// Versioned clipboard data carries only supported local description styles.
public enum RichBodyClipboard {
    public static let typeIdentifier = "local.taskovsky.rich-description"
    private static let maximumPayloadBytes = 1_048_576

    private struct Payload: Codable {
        let version: Int
        let fragment: RichBody
    }

    private static func version(for fragment: RichBody) -> Int {
        if fragment.hasCustomHighlightColors { return 3 }
        return fragment.hasCodeBlocks ? 2 : 1
    }

    public static func fragment(from body: RichBody, selection: NSRange) -> RichBody? {
        let text = body.text as NSString
        guard (try? RichBodyEdit.validate(selection, in: body.text, empty: false)) != nil,
              !RichBodyEdit.splitsCRLF(text, at: selection.location),
              !RichBodyEdit.splitsCRLF(text, at: NSMaxRange(selection)),
              let preview = RichDescriptionPreview(body: body.text, rich: body) else { return nil }

        let runs = preview.inline.compactMap { run -> RichInlineRun? in
            let span = NSIntersectionRange(selection, NSRange(location: run.location, length: run.length))
            guard span.length > 0 else { return nil }
            var clipped = run
            clipped.location = span.location - selection.location
            clipped.length = span.length
            if let link = clipped.link, !RichBodyEdit.supportsLink(link) { clipped.link = nil }
            return clipped.isEmpty ? nil : clipped
        }
        let blocks = preview.paragraphs.compactMap { paragraph -> RichBlockRun? in
            guard NSIntersectionRange(paragraph.range, selection) == paragraph.range else { return nil }
            var block = RichBlockRun(location: paragraph.range.location - selection.location, length: paragraph.range.length,
                                     heading: paragraph.heading, quote: paragraph.quote, rule: paragraph.rule,
                                     codeBlockID: paragraph.codeBlockID)
            switch paragraph.marker {
            case .bullet: block.list = .bullet
            case .number: block.list = .numbered
            case .checklist(let checked): block.list = .checklist; block.checked = checked ? true : nil
            case nil: break
            }
            return block.isEmpty ? nil : block
        }
        return RichBody(text: text.substring(with: selection), runs: runs, blocks: blocks)
    }

    public static func encode(_ fragment: RichBody) -> Data? {
        guard !fragment.text.isEmpty, isValid(fragment),
              let bytes = try? JSONEncoder().encode(Payload(version: version(for: fragment), fragment: fragment)),
              bytes.count <= maximumPayloadBytes else { return nil }
        return bytes
    }

    public static func decode(_ bytes: Data, matching text: String) -> RichBody? {
        guard bytes.count <= maximumPayloadBytes,
              let payload = try? JSONDecoder().decode(Payload.self, from: bytes),
              payload.version == version(for: payload.fragment),
              RichBody.sameCodeUnits(payload.fragment.text, text), isValid(payload.fragment),
              !payload.fragment.text.isEmpty else { return nil }
        var fragment = payload.fragment
        var newIDs: [UUID: UUID] = [:]
        for index in fragment.blocks.indices {
            guard let id = fragment.blocks[index].codeBlockID else { continue }
            let fresh = newIDs[id] ?? UUID()
            newIDs[id] = fresh
            fragment.blocks[index].codeBlockID = fresh
        }
        return fragment
    }

    private static let paragraphPrefix = try! NSRegularExpression(pattern: #"^(#{1,6}|-|[1-9][0-9]{0,8}\.|>) (\S.*)$"#)
    private static let inlinePattern = try! NSRegularExpression(
        pattern: #"`+[^`]*`+|(?<![*\\])\*\*(?![\s*])([^*\u2028]+)(?<!\s)\*\*(?!\*)|(?<!\S)((?i:https?://)[^\s<>`*]+)"#
    )

    /// Recognize the documented plain-paste shortcuts. Keep this separate
    /// from typed text, explicit plain paste, and same-editor clipboard data.
    public static func formattedPlainText(_ source: String, replacing selection: NSRange, in destination: String) -> RichBody? {
        guard source.utf8.count <= maximumPayloadBytes,
              (try? RichBodyEdit.validate(selection, in: destination)) != nil else { return nil }
        let input = source as NSString
        let combined = (destination as NSString).replacingCharacters(in: selection, with: source) as NSString
        var result = RichBody(text: "")
        var inputOffset = 0
        var outputOffset = 0
        var listNumber = 0
        var fence: String?

        while inputOffset < input.length {
            var end = 0
            var contentEnd = 0
            input.getParagraphStart(nil, end: &end, contentsEnd: &contentEnd,
                                    for: NSRange(location: inputOffset, length: 1))
            let inserted = NSRange(location: selection.location + inputOffset, length: end - inputOffset)
            let line = input.substring(with: NSRange(location: inputOffset, length: contentEnd - inputOffset))
            let terminator = input.substring(with: NSRange(location: contentEnd, length: end - contentEnd))
            inputOffset = end

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if fence == nil, line == "```", !terminator.isEmpty,
               combined.paragraphRange(for: NSRange(location: inserted.location, length: 1)) == inserted,
               let code = codeFence(in: input, from: end, insertedAt: selection.location, in: combined) {
                let id = UUID()
                let start = inputOffset
                let span = NSUnionRange(code.paragraphs[0], code.paragraphs[code.paragraphs.count - 1])
                result.text += input.substring(with: span)
                result.blocks += code.paragraphs.map {
                    .init(location: outputOffset + $0.location - start, length: $0.length, codeBlockID: id)
                }
                outputOffset += span.length
                inputOffset = code.end
                listNumber = 0
                continue
            }
            let delimiter = trimmed.prefix { $0 == trimmed.first && ($0 == "`" || $0 == "~") }
            let isFence = delimiter.count >= 3
            if let open = fence {
                if delimiter.hasPrefix(open), trimmed.dropFirst(delimiter.count).isEmpty { fence = nil }
            } else if isFence {
                fence = String(delimiter)
            }
            if fence != nil || isFence || line.hasPrefix("    ") || line.hasPrefix("\t") {
                result.text += line + terminator
                outputOffset += line.utf16.count + terminator.utf16.count
                listNumber = 0
                continue
            }

            let rawLine = line as NSString
            var paragraph = line
            var block = RichBlockRun(location: outputOffset, length: 0)
            let prefix = paragraphPrefix.firstMatch(in: line, range: NSRange(location: 0, length: rawLine.length))
            if let prefix, combined.paragraphRange(for: NSRange(location: inserted.location, length: 1)) == inserted {
                let marker = rawLine.substring(with: prefix.range(at: 1))
                switch marker.first {
                case "#": block.heading = marker.count
                case "-":
                    let content = rawLine.substring(with: prefix.range(at: 2))
                    if !content.hasPrefix("[ ]"), !content.lowercased().hasPrefix("[x]") { block.list = .bullet }
                case ">": block.quote = true
                default:
                    if let number = Int(marker.dropLast()), number == 1 || number == listNumber + 1 {
                        block.list = .numbered
                    }
                }
                if !block.isEmpty { paragraph = rawLine.substring(with: prefix.range(at: 2)) }
            }
            listNumber = block.list == .numbered ? listNumber + 1 : 0
            let formatted = formattedInline(paragraph, offset: outputOffset, runs: &result.runs)
            result.text += formatted + terminator
            let length = formatted.utf16.count + terminator.utf16.count
            if !block.isEmpty {
                block.length = length
                result.blocks.append(block)
            }
            outputOffset += length
        }
        return result.isEmpty ? nil : result
    }

    private static func codeFence(in input: NSString, from start: Int, insertedAt destination: Int,
                                  in combined: NSString) -> (paragraphs: [NSRange], end: Int)? {
        var offset = start
        var paragraphs: [NSRange] = []
        while offset < input.length {
            var end = 0
            var contentEnd = 0
            input.getParagraphStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: offset, length: 1))
            let range = NSRange(location: offset, length: end - offset)
            if input.substring(with: NSRange(location: offset, length: contentEnd - offset)) == "```" {
                let inserted = NSRange(location: destination + offset, length: range.length)
                guard !paragraphs.isEmpty,
                      combined.paragraphRange(for: NSRange(location: inserted.location, length: 1)) == inserted else { return nil }
                return (paragraphs, end)
            }
            paragraphs.append(range)
            offset = end
        }
        return nil
    }

    private static func formattedInline(_ text: String, offset: Int, runs: inout [RichInlineRun]) -> String {
        let input = text as NSString
        var output = ""
        var inputOffset = 0
        var outputOffset = offset
        for match in inlinePattern.matches(in: text, range: NSRange(location: 0, length: input.length)) {
            let leading = NSRange(location: inputOffset, length: match.range.location - inputOffset)
            output += input.substring(with: leading)
            outputOffset += leading.length
            let bold = match.range(at: 1)
            let url = match.range(at: 2)
            let content = bold.location == NSNotFound ? match.range : bold
            let value = input.substring(with: content)
            if bold.location != NSNotFound {
                runs.append(RichInlineRun(location: outputOffset, length: content.length, bold: true))
            } else if url.location != NSNotFound {
                let link = value.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                if RichBodyEdit.supportsLink(link) {
                    runs.append(RichInlineRun(location: outputOffset, length: link.utf16.count, link: link))
                }
            }
            output += value
            outputOffset += content.length
            inputOffset = NSMaxRange(match.range)
        }
        output += input.substring(from: inputOffset)
        return output
    }

    fileprivate static func isValid(_ fragment: RichBody) -> Bool {
        guard let preview = RichDescriptionPreview(body: fragment.text, rich: fragment),
              fragment.runs.allSatisfy({ $0.link.map(RichBodyEdit.supportsLink) ?? true }),
              Set(fragment.blocks.map(\.location)).count == fragment.blocks.count else { return false }
        let paragraphs = Dictionary(uniqueKeysWithValues: preview.paragraphs.map { ($0.range.location, $0) })
        return fragment.blocks.allSatisfy { block in
            guard let paragraph = paragraphs[block.location], paragraph.range.length == block.length else { return false }
            return (!block.rule || paragraph.rule) && (block.checked == nil || block.list == .checklist)
        }
    }
}
