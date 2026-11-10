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
    case toggle(RichInlineFormat, NSRange)
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
        case .toggle(let format, let range):
            try Self.validate(range, in: body.text, empty: false)
            let inline = Self.inlineContent(body)
            var allStyled = true
            inline.enumerateAttribute(format.attribute, in: range) { value, _, stop in
                if value == nil { allStyled = false; stop.pointee = true }
            }
            if allStyled { inline.removeAttribute(format.attribute, range: range) }
            else { inline.addAttribute(format.attribute, value: true, range: range) }
            return RichBody(text: body.text, runs: Self.extractInline(inline), blocks: body.blocks)
        case .setLink(let link, let range):
            try Self.validate(range, in: body.text, empty: false)
            let inline = Self.inlineContent(body)
            if let link {
                guard let components = URLComponents(string: link),
                      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
                      let host = components.host, !host.isEmpty, components.url != nil
                else { throw RichBodyEditError.invalidLink }
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

    private static func validate(_ range: NSRange, in text: String, empty: Bool = true) throws {
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
                (.strikethrough, run.strikethrough), (.highlight, run.highlight), (.code, run.code)
            ]
            for (format, enabled) in active where enabled {
                inline.addAttribute(format.attribute, value: true, range: range)
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
            let run = RichInlineRun(location: range.location, length: range.length,
                                    bold: present(.bold), italic: present(.italic), underline: present(.underline),
                                    strikethrough: present(.strikethrough), highlight: present(.highlight),
                                    code: present(.code), link: link)
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
        let blocks = try body.blocks.flatMap { block -> [RichBlockRun] in
            let annotated = NSRange(location: block.location, length: block.length)
            var copy = block
            if NSIntersectionRange(annotated, touched).length > 0 {
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

    private static func splitsCRLF(_ text: NSString, at offset: Int) -> Bool {
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
                                     list: original.list, checked: retainsOriginal ? original.checked : nil)
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
                block.heading = level
            case .quote(let enabled):
                block.quote = enabled
            case .list(let style):
                if style != block.list { block.checked = nil }
                block.list = style
            case .checklistChecked(let checked):
                guard block.list == .checklist else { throw RichBodyEditError.invalidParagraph }
                block.checked = checked ? true : nil
            case .horizontalRule(let enabled):
                guard !enabled || contentEnd == offset else { throw RichBodyEditError.invalidParagraph }
                block.rule = enabled
            case .clear:
                block = RichBlockRun(location: offset, length: paragraph.length)
            }
            if !block.isEmpty { blocks.append(block) }
            offset = end
        }
        return RichBody(text: body.text, runs: body.runs, blocks: blocks.sorted { $0.location < $1.location })
    }
}
