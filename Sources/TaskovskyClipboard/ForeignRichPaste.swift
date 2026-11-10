import Foundation
import libxml2
import TaskovskyDomain
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Reads rich clipboard representations into Taskovsky's existing description styles.
/// An accompanying plain representation keeps its exact text and line endings.
public enum ForeignRichPaste {
    private static let byteLimit = 1_048_576
    private static let unsupportedRTF = try! NSRegularExpression(
        pattern: #"\\(?:object|objdata|pict|filetbl|bin)\b|\\fldinst\s+(?:INCLUDETEXT|INCLUDEPICTURE|DDEAUTO|DDE|IMPORT)\b"#,
        options: .caseInsensitive
    )

    public static func fragment(plain: String?, html: Data?, rtf: Data?) -> RichBody? {
        let htmlFragment = html.flatMap(readHTML).flatMap { matching($0, to: plain) }
        if let htmlFragment, !htmlFragment.runs.isEmpty { return htmlFragment }
        let rtfFragment = rtf.flatMap(readRTF).flatMap { matching($0, to: plain ?? htmlFragment?.text) }
        if var htmlFragment, !htmlFragment.blocks.isEmpty {
            htmlFragment.runs = rtfFragment?.runs ?? []
            return htmlFragment
        }
        return rtfFragment ?? htmlFragment
    }

    private static func readHTML(_ data: Data) -> RichBody? {
        guard !data.isEmpty, data.count <= byteLimit else { return nil }
        let encoding: String.Encoding = data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) ? .utf16 : .utf8
        guard let text = String(data: data, encoding: encoding), !text.utf8.contains(0),
              text.utf8.count <= byteLimit else { return nil }
        let flags = HTML_PARSE_NONET.rawValue | HTML_PARSE_NODEFDTD.rawValue
                  | HTML_PARSE_NOERROR.rawValue | HTML_PARSE_NOWARNING.rawValue
        // Parse a memory buffer without a base URL. The walker reads only text
        // and allowlisted attributes. It does not resolve resources or run CSS.
        let count = Int32(text.utf8.count)
        let doc = text.withCString { buffer in
            htmlReadMemory(buffer, count, nil, "UTF-8", Int32(flags))
        }
        guard let doc else { return nil }
        defer { xmlFreeDoc(doc) }
        var reader = HTMLFragment()
        guard reader.walk(xmlDocGetRootElement(doc), style: .init(location: 0, length: 0)),
              !reader.body.text.isEmpty else { return nil }
        return reader.fragment()
    }

    private static func readRTF(_ data: Data) -> RichBody? {
        guard data.count <= byteLimit, data.starts(with: Data("{\\rtf".utf8)) else { return nil }
        // Control words are ASCII even when the text uses another code page.
        // Native RTF decoding is limited to text documents, with object, image
        // and external-content instructions refused before decoding.
        let controls = String(decoding: data, as: UTF8.self)
        guard unsupportedRTF.firstMatch(in: controls, range: NSRange(location: 0, length: controls.utf16.count)) == nil,
              let text = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                documentAttributes: nil),
              text.length > 0, text.length <= byteLimit,
              !text.string.contains("\u{FFFC}") else { return nil }
        var result = RichBody(text: text.string)
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            let font = attributes[.font]
            #if os(macOS)
            let traits = (font as? NSFont)?.fontDescriptor.symbolicTraits ?? []
            let bold = traits.contains(.bold), italic = traits.contains(.italic)
            #else
            let traits = (font as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            let bold = traits.contains(.traitBold), italic = traits.contains(.traitItalic)
            #endif
            let link = (attributes[.link] as? URL)?.absoluteString ?? attributes[.link] as? String
            let run = RichInlineRun(location: range.location, length: range.length, bold: bold, italic: italic,
                                    underline: (attributes[.underlineStyle] as? Int ?? 0) != 0,
                                    strikethrough: (attributes[.strikethroughStyle] as? Int ?? 0) != 0,
                                    link: link.flatMap { RichBodyEdit.supportsLink($0) ? $0 : nil })
            if !run.isEmpty { result.runs.append(run) }
        }
        return result
    }

    private static func matching(_ imported: RichBody, to plain: String?) -> RichBody? {
        guard let plain else { return imported }
        guard !plain.isEmpty, plain.utf8.count <= byteLimit else { return nil }
        if RichBody.sameCodeUnits(imported.text, plain) { return imported }

        let source = Array(imported.text.utf16), target = Array(plain.utf16)
        var positions = Array(repeating: -1, count: source.count)
        func skipWhitespace(_ units: [UInt16], from index: inout Int) {
            while index < units.count, clipboardWhitespace(units[index]) { index += 1 }
        }
        var i = 0, j = 0
        skipWhitespace(source, from: &i)
        skipWhitespace(target, from: &j)
        while i < source.count, j < target.count {
            if clipboardWhitespace(source[i]), clipboardWhitespace(target[j]) {
                skipWhitespace(source, from: &i)
                skipWhitespace(target, from: &j)
                continue
            }
            guard source[i] == target[j] else { return nil }
            positions[i] = j
            i += 1
            j += 1
        }
        skipWhitespace(source, from: &i)
        skipWhitespace(target, from: &j)
        guard i == source.count, j == target.count else { return nil }

        let runs = imported.runs.compactMap { run -> RichInlineRun? in
            let span = run.location..<(run.location + run.length)
            guard let first = positions[span].first(where: { $0 >= 0 }),
                  let last = positions[span].last(where: { $0 >= 0 }) else { return nil }
            var mapped = run
            mapped.location = first
            mapped.length = last - first + 1
            return mapped
        }
        return RichBody(text: plain, runs: runs, blocks: matchingBlocks(imported, to: plain, positions: positions))
    }

    private static func matchingBlocks(_ imported: RichBody, to plain: String, positions: [Int]) -> [RichBlockRun] {
        guard !imported.blocks.isEmpty else { return [] }
        let target = plain as NSString
        let exactLines = matchingCodeParagraphs(imported, target: target, positions: positions)
        return imported.blocks.compactMap { block in
            let paragraph: NSRange
            if block.codeBlockID != nil {
                guard let exact = exactLines[block.location] else { return nil }
                paragraph = exact
            } else {
                let mapped = positions[block.location..<block.location + block.length]
                guard let first = mapped.first(where: { $0 >= 0 }),
                      let last = mapped.last(where: { $0 >= 0 }) else { return nil }
                paragraph = target.paragraphRange(for: NSRange(location: first, length: 1))
                let content = nonWhitespaceRange(in: target, paragraph: paragraph)
                guard content.location == first, NSMaxRange(content) == last + 1 else { return nil }
            }
            var result = block
            result.location = paragraph.location
            result.length = paragraph.length
            return result
        }
    }

    /// Match each entire code block against the plain flavor. Its first
    /// mapped character anchors the search, including any preceding blank lines.
    private static func matchingCodeParagraphs(_ imported: RichBody, target: NSString, positions: [Int]) -> [Int: NSRange] {
        let source = imported.text as NSString
        let code = imported.blocks.filter { $0.codeBlockID != nil }
        let groups = Dictionary(grouping: code, by: \.codeBlockID)
        var matches: [Int: NSRange] = [:]
        var occupiedThrough = 0
        for group in groups.values.sorted(by: { $0[0].location < $1[0].location }) {
            guard let anchor = group.enumerated().lazy.compactMap({ index, paragraph -> (Int, Int)? in
                let points = positions[paragraph.location..<paragraph.location + paragraph.length]
                return points.first(where: { $0 >= 0 }).map { (index, $0) }
            }).first else { continue }
            var start = target.paragraphRange(for: NSRange(location: anchor.1, length: 1)).location
            var preceding = anchor.0
            while preceding > 0, start > 0 {
                start = target.paragraphRange(for: NSRange(location: start - 1, length: 1)).location
                preceding -= 1
            }
            guard preceding == 0, start >= occupiedThrough else { continue }
            var aligned: [Int: NSRange] = [:]
            for paragraph in group {
                guard start < target.length else { break }
                var sourceEnd = 0, targetEnd = 0, next = 0
                source.getParagraphStart(nil, end: nil, contentsEnd: &sourceEnd,
                                         for: NSRange(location: paragraph.location, length: 1))
                target.getParagraphStart(nil, end: &next, contentsEnd: &targetEnd,
                                         for: NSRange(location: start, length: 1))
                let before = source.substring(with: NSRange(location: paragraph.location, length: sourceEnd - paragraph.location))
                let after = target.substring(with: NSRange(location: start, length: targetEnd - start))
                guard RichBody.sameCodeUnits(before, after) else { break }
                let points = positions[paragraph.location..<paragraph.location + paragraph.length]
                let content = nonWhitespaceRange(in: target, paragraph: NSRange(location: start, length: next - start))
                if let first = points.first(where: { $0 >= 0 }), first != content.location { break }
                aligned[paragraph.location] = NSRange(location: start, length: next - start)
                start = next
            }
            if aligned.count == group.count {
                matches.merge(aligned) { first, _ in first }
                occupiedThrough = start
            }
        }
        return matches
    }
}

private func clipboardWhitespace(_ value: UInt16) -> Bool {
    value == 32 || value == 160 || (9...13).contains(value)
}

private func nonWhitespaceRange(in text: NSString, paragraph: NSRange) -> NSRange {
    var start = paragraph.location, end = NSMaxRange(paragraph)
    while start < end, clipboardWhitespace(text.character(at: start)) { start += 1 }
    while start < end, clipboardWhitespace(text.character(at: end - 1)) { end -= 1 }
    return NSRange(location: start, length: end - start)
}

private struct HTMLFragment {
    var body = RichBody(text: "")
    private var length = 0
    private var blockSpans: [RichBlockRun] = []
    private var nodes = 0
    private var pendingSpace: RichInlineRun?
    private var pendingBreak = false
    private static let ignored: Set<String> = [
        "head", "script", "style", "template", "iframe", "object", "svg", "noscript", "audio", "video",
    ]
    private static let paragraphs: Set<String> = [
        "p", "div", "section", "article", "blockquote", "pre", "ul", "ol", "li", "hr", "tr",
        "h1", "h2", "h3", "h4", "h5", "h6",
    ]

    mutating func walk(_ first: xmlNodePtr?, style: RichInlineRun,
                       block: RichBlockRun = .init(location: 0, length: 0), list: RichListStyle? = nil,
                       depth: Int = 0) -> Bool {
        guard depth < 128 else { return false }
        var next = first
        while let node = next {
            next = node.pointee.next
            nodes += 1
            guard nodes <= 16_384 else { return false }
            switch node.pointee.type {
            case XML_TEXT_NODE, XML_CDATA_SECTION_NODE:
                if let value = node.pointee.content {
                    let text = String(cString: value)
                    if block.codeBlockID != nil { write(text, style: style, block: block) }
                    else { writeCollapsed(text, style: style, block: block) }
                }
            case XML_ELEMENT_NODE:
                guard let name = node.pointee.name.map({ String(cString: $0) }), !Self.ignored.contains(name),
                      xmlHasProp(node, "hidden") == nil else { continue }
                if name == "br" {
                    pendingBreak = false
                    pendingSpace = nil
                    append("\n", style: .init(location: 0, length: 0), block: block)
                    continue
                }
                let isParagraph = Self.paragraphs.contains(name)
                if isParagraph { paragraphBoundary() }
                let childList: RichListStyle? = switch name {
                case "ul": .bullet
                case "ol": .numbered
                default: list
                }
                var childBlock = block
                if block.codeBlockID == nil {
                    switch name {
                    case "h1", "h2", "h3", "h4", "h5", "h6":
                        childBlock.heading = Int(name.dropFirst())
                    case "blockquote": childBlock.quote = true
                    case "li": childBlock.list = list
                    case "pre": childBlock = .init(location: 0, length: 0, codeBlockID: UUID())
                    default: break
                    }
                }
                guard walk(node.pointee.children, style: Self.style(for: node, name: name, inheriting: style),
                           block: childBlock, list: childList, depth: depth + 1) else { return false }
                if isParagraph { paragraphBoundary() }
            default:
                continue
            }
        }
        return true
    }

    func fragment() -> RichBody {
        var result = body
        let text = body.text as NSString
        for span in blockSpans {
            let end = span.location + span.length
            var offset = span.location
            while offset < end {
                let paragraph = text.paragraphRange(for: NSRange(location: offset, length: 1))
                let content = nonWhitespaceRange(in: text, paragraph: paragraph)
                let required = content.length > 0 ? content : paragraph
                if required.location >= span.location, NSMaxRange(required) <= end {
                    var block = span
                    block.location = paragraph.location
                    block.length = paragraph.length
                    result.blocks.append(block)
                }
                offset = NSMaxRange(paragraph)
            }
        }
        return result
    }

    private mutating func paragraphBoundary() {
        pendingSpace = nil
        pendingBreak = length > 0 && body.text.utf16.last != 10
    }

    private mutating func writeCollapsed(_ text: String, style: RichInlineRun, block: RichBlockRun) {
        func space(_ character: Character) -> Bool {
            character.unicodeScalars.allSatisfy { $0.value == 32 || (9...13).contains($0.value) }
        }
        if let first = text.first, space(first), pendingSpace == nil { pendingSpace = style }
        let words = text.split(whereSeparator: space)
        for (index, word) in words.enumerated() {
            if index > 0 { pendingSpace = style }
            write(String(word), style: style, block: block)
        }
        if let last = text.last, space(last), pendingSpace == nil { pendingSpace = style }
    }

    private mutating func write(_ text: String, style: RichInlineRun, block: RichBlockRun) {
        guard !text.isEmpty else { return }
        if pendingBreak {
            append("\n", style: .init(location: 0, length: 0))
        } else if let pendingSpace, length > 0, body.text.utf16.last != 10 {
            append(" ", style: pendingSpace, block: block)
        }
        pendingBreak = false
        pendingSpace = nil
        append(text, style: style, block: block)
    }

    private mutating func append(_ text: String, style: RichInlineRun,
                                 block: RichBlockRun = .init(location: 0, length: 0)) {
        var run = style
        run.location = length
        run.length = text.utf16.count
        body.text += text
        if !block.isEmpty {
            var span = block
            span.location = length
            span.length = run.length
            if let last = blockSpans.last, last.location + last.length == length {
                var comparable = last
                comparable.location = span.location
                comparable.length = span.length
                if comparable == span { blockSpans[blockSpans.count - 1].length += span.length }
                else { blockSpans.append(span) }
            } else { blockSpans.append(span) }
        }
        length += run.length
        guard !style.isEmpty else { return }
        if let last = body.runs.last, last.location + last.length == run.location {
            var previous = last
            previous.location = run.location
            previous.length = run.length
            if previous == run {
                body.runs[body.runs.count - 1].length += run.length
                return
            }
        }
        body.runs.append(run)
    }

    private static func style(for node: xmlNodePtr, name: String, inheriting inherited: RichInlineRun) -> RichInlineRun {
        var style = inherited
        switch name {
        case "b", "strong": style.bold = true
        case "i", "em": style.italic = true
        case "u", "ins": style.underline = true
        case "s", "strike", "del": style.strikethrough = true
        case "code", "kbd", "tt": style.code = true
        case "mark": style.highlight = true
        case "a":
            style.link = attribute("href", on: node).flatMap { RichBodyEdit.supportsLink($0) ? $0 : nil }
        default: break
        }
        if let css = attribute("style", on: node) {
            for declaration in css.lowercased().split(separator: ";") {
                let pair = declaration.split(separator: ":", maxSplits: 1)
                guard pair.count == 2 else { continue }
                let key = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
                switch key {
                case "font-weight":
                    if value == "normal" { style.bold = false }
                    else if value == "bold" || value == "bolder" { style.bold = true }
                    else if let weight = Int(value) { style.bold = weight >= 600 }
                case "font-style":
                    if value == "normal" { style.italic = false }
                    else if value == "italic" || value.hasPrefix("oblique") { style.italic = true }
                case "text-decoration", "text-decoration-line":
                    let marks = value.split(whereSeparator: \.isWhitespace)
                    style.underline = style.underline || marks.contains("underline")
                    style.strikethrough = style.strikethrough || marks.contains("line-through")
                default: break
                }
            }
        }
        return style
    }

    private static func attribute(_ name: String, on node: xmlNodePtr) -> String? {
        guard let value = xmlGetProp(node, name) else { return nil }
        defer { xmlFree(value) }
        return String(cString: value)
    }
}
