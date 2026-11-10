import TaskovskyDomain
import AppKit
import Foundation

/// Geometry the layout manager paints for one list marker, in view
/// coordinates. `rect` is the marker paint rect inside the gutter;
/// `textRect` is the paragraph's first-line fragment (for overlap checks:
/// the marker must end where the 24pt gutter ends).
public struct DrawnMarker: Equatable, Sendable {
    public var paragraph: NSRange
    public var kind: ListDecoration.MarkerKind
    public var rect: NSRect
    public var textRect: NSRect
}

/// Geometry for one quote gutter bar, in view coordinates.
public struct DrawnQuote: Equatable, Sendable {
    public var paragraph: NSRange
    public var rect: NSRect
}

/// Layout manager that paints visible list/quote/rule decorations for
/// prefix-free bodies. Markers and quote gutters paint from storage
/// metadata (`textLists`/`quoteKey`), so typing, Return, deletes, and style
/// selection redraw them on the next display pass with no model work.
/// Nothing here touches the persisted body: no literal markers are ever
/// inserted, so UTF-16 ranges, search, and the caret are safe.
///
/// Lives in Core (not the app target) so geometry tests exercise the real
/// drawing computation: `decorationsToDraw` returns the same marker/quote
/// geometry the draw pass paints.
open class ListLayoutManager: NSLayoutManager {
    /// Number label font: one step below the 14pt body.
    private static let numberFont = NSFont.systemFont(ofSize: 13)

    /// Markers and quote bars the manager would paint for the visible
    /// glyphs: same computation as the draw pass, exposed for geometry
    /// tests (gutter containment, no text overlap, numbering, wrapping).
    public func decorationsToDraw(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) -> (markers: [DrawnMarker], quotes: [DrawnQuote]) {
        guard let storage = textStorage, storage.length > 0,
              let container = textContainers.first else { return ([], []) }
        ensureLayout(for: container)
        let string = storage.string as NSString
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        // Numbering counts contiguous preceding numbered paragraphs, so
        // entries cover the whole prefix through the visible range (not just
        // the visible paragraphs).
        let prefixEnd = min(NSMaxRange(chars), string.length)
        let entries: [ListDecoration.Paragraph] = string
            .paragraphRanges(intersecting: NSRange(location: 0, length: prefixEnd))
            .map { para in
                let format = (storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
                let quote = (storage.attribute(RichRender.quoteKey, at: para.location, effectiveRange: nil) as? Bool) ?? false
                return ListDecoration.Paragraph(range: para, markerFormat: format, quote: quote)
            }
        let kinds = ListDecoration.markers(for: entries)
        let left = container.lineFragmentPadding
        let gutterEnd = left + ListDecoration.gutterWidth
        var markers: [DrawnMarker] = []
        var quotes: [DrawnQuote] = []
        for (index, entry) in entries.enumerated() {
            guard entry.range.length > 0, NSIntersectionRange(entry.range, chars).length > 0 else { continue }
            let glyphs = glyphRange(forCharacterRange: NSRange(location: entry.range.location, length: 1), actualCharacterRange: nil)
            guard glyphs.length > 0 else { continue }
            var frag = lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            frag.origin.x += origin.x
            frag.origin.y += origin.y
            if entry.quote {
                let bounds = boundingRect(forGlyphRange: glyphRange(forCharacterRange: entry.range, actualCharacterRange: nil), in: container)
                let bar = NSRect(x: origin.x + left + 2, y: origin.y + bounds.minY, width: ListDecoration.quoteBarWidth, height: max(bounds.height, 2))
                quotes.append(DrawnQuote(paragraph: entry.range, rect: bar))
            }
            guard let kind = kinds[index] else { continue }
            let midY = frag.midY
            switch kind {
            case .bullet:
                let rect = NSRect(x: origin.x + left + 9, y: midY - 3, width: 6, height: 6)
                markers.append(DrawnMarker(paragraph: entry.range, kind: kind, rect: rect, textRect: frag))
            case .number(let n):
                let label = "\(n)." as NSString
                let size = label.size(withAttributes: [.font: Self.numberFont])
                let rect = NSRect(x: origin.x + gutterEnd - 4 - size.width, y: midY - size.height / 2, width: size.width, height: size.height)
                markers.append(DrawnMarker(paragraph: entry.range, kind: kind, rect: rect, textRect: frag))
            case .checkbox:
                let rect = NSRect(x: origin.x + left + 5, y: midY - 6, width: 12, height: 12)
                markers.append(DrawnMarker(paragraph: entry.range, kind: kind, rect: rect, textRect: frag))
            }
        }
        return (markers, quotes)
    }

    public func checklistMarker(at point: NSPoint, origin: NSPoint) -> DrawnMarker? {
        guard let container = textContainers.first else { return nil }
        let left = origin.x + container.lineFragmentPadding
        guard point.x >= left, point.x < left + ListDecoration.gutterWidth else { return nil }
        let glyphs = glyphRange(for: container)
        return decorationsToDraw(forGlyphRange: glyphs, at: origin).markers.first { marker in
            guard case .checkbox = marker.kind else { return false }
            let hit = marker.rect.insetBy(dx: -3, dy: -3)
            return hit.contains(point) && point.y >= marker.textRect.minY && point.y < marker.textRect.maxY
        }
    }

    override public func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, storage.length > 0,
              let container = textContainers.first else { return }
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let string = storage.string as NSString
        // origin offsets glyph coordinates into view space; the container
        // width bounds the line.
        let left = container.lineFragmentPadding
        let width = max(0, container.size.width - left * 2)
        guard width > 0 else { return }
        NSColor.tertiaryLabelColor.setFill()
        for para in string.paragraphRanges(intersecting: chars) {
            guard (storage.attribute(RichRender.ruleKey, at: para.location, effectiveRange: nil) as? Bool) == true else { continue }
            let glyphs = glyphRange(forCharacterRange: para, actualCharacterRange: nil)
            let rect = boundingRect(forGlyphRange: glyphs, in: container)
            let line = NSRect(x: origin.x + left, y: origin.y + rect.midY - 0.5, width: width, height: 1)
            line.fill()
        }
        // List markers and quote gutters paint from storage metadata
        // (textLists/quoteKey), so typing, Return, deletes, and style
        // selection redraw them on the next display pass with no model work.
        // Nothing here touches the persisted body: no literal markers are
        // ever inserted, so UTF-16 ranges, search, and the caret are safe.
        let (markers, quotes) = decorationsToDraw(forGlyphRange: glyphsToShow, at: origin)
        NSColor.tertiaryLabelColor.setFill()
        for quote in quotes { quote.rect.fill() }
        for marker in markers {
            switch marker.kind {
            case .bullet:
                NSColor.labelColor.setFill()
                NSBezierPath(ovalIn: marker.rect).fill()
            case .number(let n):
                ("\(n)." as NSString).draw(at: marker.rect.origin, withAttributes: [.font: Self.numberFont, .foregroundColor: NSColor.labelColor])
            case .checkbox(let checked):
                NSColor.secondaryLabelColor.setStroke()
                let box = NSBezierPath(rect: marker.rect)
                box.lineWidth = 1.5
                box.stroke()
                if checked {
                    NSColor.labelColor.setStroke()
                    let check = NSBezierPath()
                    check.move(to: NSPoint(x: marker.rect.minX + 2.5, y: marker.rect.minY + 5))
                    check.line(to: NSPoint(x: marker.rect.minX + 5.5, y: marker.rect.minY + 8.5))
                    check.line(to: NSPoint(x: marker.rect.minX + 9.5, y: marker.rect.minY + 3))
                    check.lineWidth = 1.8
                    check.lineCapStyle = .round
                    check.lineJoinStyle = .round
                    check.stroke()
                }
            }
        }
    }
}
