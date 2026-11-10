import Foundation

/// A render-only projection of the shared prefix-free rich description.
public struct RichDescriptionPreview: Sendable {
    public enum Marker: Equatable, Sendable {
        case bullet, number(Int), checklist(checked: Bool)
    }

    public struct Paragraph: Equatable, Sendable {
        public let range: NSRange
        public let heading: Int?
        public let quote: Bool
        public let marker: Marker?
        public let rule: Bool
    }

    public let text: String
    public let inline: [RichInlineRun]
    public let paragraphs: [Paragraph]

    /// Bounds and text identity are checked before constructing any native
    /// ranges. Malformed records can still show their authoritative plain text.
    public init?(body: String, rich: RichBody) {
        guard rich.valid(for: body) != nil else { return nil }
        let units = Array(body.utf16)
        func valid(_ location: Int, _ length: Int) -> Bool {
            guard location >= 0, length > 0, location < units.count,
                  length <= units.count - location else { return false }
            let end = location + length
            // A range may style a combining mark but must not split a
            // surrogate pair, which would attach attributes to half a scalar.
            func scalarBoundary(_ index: Int) -> Bool {
                index == units.count || !(0xDC00...0xDFFF).contains(units[index])
            }
            return scalarBoundary(location) && scalarBoundary(end)
        }
        guard rich.runs.allSatisfy({ valid($0.location, $0.length) }),
              rich.blocks.allSatisfy({
                  valid($0.location, $0.length) && ($0.heading == nil || $0.validHeading != nil)
              }) else { return nil }

        text = body
        inline = rich.runs.filter { !$0.isEmpty }.sorted { $0.location < $1.location }
        let string = body as NSString
        var blocks: [Int: RichBlockRun] = [:]
        for block in rich.blocks.sorted(by: { $0.location < $1.location }) where !block.isEmpty {
            let end = block.location + block.length
            var paragraph = string.paragraphRange(for: NSRange(location: block.location, length: 1))
            while paragraph.location < end {
                var combined = blocks[paragraph.location] ?? RichBlockRun(location: paragraph.location, length: paragraph.length)
                if let heading = block.heading { combined.heading = heading }
                combined.quote = combined.quote || block.quote
                if let list = block.list {
                    combined.list = list
                    combined.checked = block.checked
                }
                combined.rule = combined.rule || block.rule
                blocks[paragraph.location] = combined
                let next = NSMaxRange(paragraph)
                if next >= end { break }
                paragraph = string.paragraphRange(for: NSRange(location: next, length: 1))
            }
        }

        var result: [Paragraph] = []
        var offset = 0
        var number = 0
        while offset < string.length {
            var end = 0
            var contentEnd = 0
            string.getParagraphStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: offset, length: 1))
            let block = blocks[offset]
            let marker: Marker?
            if block?.list == .numbered {
                number += 1
                marker = .number(number)
            } else {
                number = 0
                switch block?.list {
                case .bullet: marker = .bullet
                case .checklist: marker = .checklist(checked: block?.checked ?? false)
                default: marker = nil
                }
            }
            result.append(Paragraph(range: NSRange(location: offset, length: end - offset),
                                    heading: block?.heading, quote: block?.quote ?? false,
                                    marker: marker, rule: block?.rule == true && offset == contentEnd))
            offset = end
        }
        paragraphs = result
    }

    public func matches(_ other: Self) -> Bool {
        RichBody.sameCodeUnits(text, other.text) && inline == other.inline && paragraphs == other.paragraphs &&
            zip(inline, other.inline).allSatisfy { RichBody.sameCodeUnits($0.link ?? "", $1.link ?? "") }
    }
}
