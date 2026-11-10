import SwiftUI
import UIKit
import TaskovskyDomain

struct PhoneRichDescription: UIViewRepresentable {
    let preview: RichDescriptionPreview
    var identifier = "richTaskDescription"
    var headings: [RichDescriptionPreview.Heading] = []
    var onHeadingPositions: ([Int: CGFloat]) -> Void = { _ in }
    @ScaledMetric(relativeTo: .body) private var pointSize: CGFloat = 17

    func makeUIView(context: Context) -> RichPreviewTextView {
        let storage = NSTextStorage()
        let layout = RichPreviewLayout()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let view = RichPreviewTextView(frame: .zero, textContainer: container)
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.dataDetectorTypes = []
        view.accessibilityIdentifier = identifier
        return view
    }

    func updateUIView(_ view: RichPreviewTextView, context: Context) {
        view.headings = headings
        view.onHeadingPositions = onHeadingPositions
        guard view.renderedSize != pointSize || view.rendered?.matches(preview) != true else { return }
        let layout = view.layoutManager as? RichPreviewLayout
        let gutter = preview.paragraphs.reduce(0) { width, paragraph in
            guard case .number(let number) = paragraph.marker else { return width }
            return max(width, String(number).count)
        }
        let markerIndent = max(pointSize * 1.5, pointSize * 0.72 * CGFloat(gutter + 2))
        layout?.decorations = preview.paragraphs.filter { $0.marker != nil || $0.quote || $0.rule }
        layout?.pointSize = pointSize
        layout?.markerIndent = markerIndent
        view.attributedText = attributedDescription(preview, pointSize: pointSize, markerIndent: markerIndent)
        view.rendered = preview
        view.renderedSize = pointSize
        view.setNeedsLayout()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RichPreviewTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }
}

struct PhoneFoldableRichDescription: View {
    let preview: RichDescriptionPreview
    let revision: Date
    @State private var collapsed: Set<Int> = []
    @State private var positions: [Int: CGFloat] = [:]

    var body: some View {
        let reading = preview.readingView(collapsed: collapsed)
        ZStack(alignment: .topLeading) {
            PhoneRichDescription(preview: reading.preview, headings: reading.headings) { positions = $0 }
                .padding(.leading, reading.headings.isEmpty ? 0 : 34)
            ForEach(reading.headings) { heading in
                if let y = positions[heading.id] {
                    let folded = collapsed.contains(heading.id)
                    Button {
                        if folded { collapsed.remove(heading.id) } else { collapsed.insert(heading.id) }
                    } label: {
                        Image(systemName: folded ? "chevron.right" : "chevron.down")
                            .font(.caption.weight(.semibold)).frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel((folded ? "Expand " : "Collapse ") + heading.title)
                        .accessibilityIdentifier("richFoldHeading-" + String(heading.id))
                        .offset(y: y)
                }
            }
        }.onChange(of: revision) { _, _ in collapsed.removeAll() }
    }
}

final class RichPreviewTextView: UITextView {
    var rendered: RichDescriptionPreview?
    var renderedSize: CGFloat = 0
    var headings: [RichDescriptionPreview.Heading] = []
    var onHeadingPositions: ([Int: CGFloat]) -> Void = { _ in }
    private var headingPositions: [Int: CGFloat] = [:]

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !headings.isEmpty, bounds.width > 0 else { return }
        layoutManager.ensureLayout(for: textContainer)
        var positions: [Int: CGFloat] = [:]
        for heading in headings where heading.range.location < textStorage.length {
            let glyph = layoutManager.glyphIndexForCharacter(at: heading.range.location)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            positions[heading.id] = line.minY + textContainerInset.top
        }
        guard headingPositions != positions else { return }
        headingPositions = positions
        DispatchQueue.main.async { [weak self] in
            guard let self, self.headingPositions == positions else { return }
            self.onHeadingPositions(positions)
        }
    }
}

private extension NSAttributedString.Key {
    static let previewBold = Self("TaskovskyPreviewBold")
    static let previewItalic = Self("TaskovskyPreviewItalic")
    static let previewCode = Self("TaskovskyPreviewCode")
    static let previewHighlight = Self("TaskovskyPreviewHighlight")
    static let previewHeading = Self("TaskovskyPreviewHeading")
}

func attributedDescription(_ preview: RichDescriptionPreview, pointSize: CGFloat,
                                   markerIndent: CGFloat) -> NSAttributedString {
    let result = NSMutableAttributedString(string: preview.text, attributes: [.foregroundColor: UIColor.label])
    for run in preview.inline {
        let range = NSRange(location: run.location, length: run.length)
        if run.bold { result.addAttribute(.previewBold, value: true, range: range) }
        if run.italic { result.addAttribute(.previewItalic, value: true, range: range) }
        if run.code { result.addAttribute(.previewCode, value: true, range: range) }
        if run.highlight { result.addAttribute(.previewHighlight, value: true, range: range) }
        if run.underline || run.link != nil { result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        if run.strikethrough { result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        if let link = run.link, let url = URL(string: link),
           let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil {
            result.addAttribute(.link, value: url, range: range)
        }
    }
    for paragraph in preview.paragraphs {
        if let heading = paragraph.heading {
            result.addAttribute(.previewHeading, value: heading, range: paragraph.range)
        }
        if paragraph.marker != nil || paragraph.quote || paragraph.rule {
            let style = NSMutableParagraphStyle()
            let indent = (paragraph.marker == nil ? 0 : markerIndent) + (paragraph.quote ? pointSize * 0.85 : 0)
            style.headIndent = indent
            style.firstLineHeadIndent = indent
            if paragraph.rule {
                style.paragraphSpacingBefore = 4
                style.paragraphSpacing = 4
            }
            result.addAttribute(.paragraphStyle, value: style, range: paragraph.range)
        }
    }
    let scale: [CGFloat] = [1.6, 1.43, 1.29, 1.19, 1.1, 1.03]
    result.enumerateAttributes(in: NSRange(location: 0, length: result.length)) { attributes, range, _ in
        let level = attributes[.previewHeading] as? Int
        let size = level.map { pointSize * scale[$0 - 1] } ?? pointSize
        let weight: UIFont.Weight = (level != nil || attributes[.previewBold] != nil) ? .bold : .regular
        let code = attributes[.previewCode] != nil
        var font = code ? UIFont.monospacedSystemFont(ofSize: size, weight: weight) : UIFont.systemFont(ofSize: size, weight: weight)
        if attributes[.previewItalic] != nil,
           let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        result.addAttribute(.font, value: font, range: range)
        if attributes[.previewHighlight] != nil {
            result.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.28), range: range)
        } else if code {
            result.addAttribute(.backgroundColor, value: UIColor.secondarySystemFill, range: range)
        }
    }
    return result
}

final class RichPreviewLayout: NSLayoutManager {
    var decorations: [RichDescriptionPreview.Paragraph] = []
    var pointSize: CGFloat = 17
    var markerIndent: CGFloat = 26

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let container = textContainers.first else { return }
        let markerFont = UIFont.systemFont(ofSize: pointSize)
        let markerAttributes: [NSAttributedString.Key: Any] = [.font: markerFont, .foregroundColor: UIColor.secondaryLabel]
        let textLength = textStorage?.length ?? 0
        for paragraph in decorations {
            guard paragraph.range.location < textLength, paragraph.range.length <= textLength - paragraph.range.location else { continue }
            let glyphs = glyphRange(forCharacterRange: paragraph.range, actualCharacterRange: nil)
            guard NSIntersectionRange(glyphs, glyphsToShow).length > 0 else { continue }
            let first = lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            if paragraph.quote {
                let block = boundingRect(forGlyphRange: glyphs, in: container)
                UIColor.tertiaryLabel.setFill()
                UIBezierPath(rect: CGRect(x: origin.x + 2, y: origin.y + first.minY + 2,
                                          width: 2, height: max(2, block.height - 4))).fill()
            }
            if paragraph.rule {
                UIColor.separator.setFill()
                UIBezierPath(rect: CGRect(x: origin.x, y: origin.y + first.midY,
                                          width: max(0, container.size.width), height: 1)).fill()
            }
            if let marker = paragraph.marker {
                let markerText: String = switch marker {
                case .bullet: "•"
                case .number(let number): "\(number)."
                case .checklist(let checked): checked ? "☑" : "☐"
                }
                let text = markerText as NSString
                let size = text.size(withAttributes: markerAttributes)
                let quoteInset = paragraph.quote ? pointSize * 0.85 : 0
                let x = origin.x + quoteInset + max(0, markerIndent - size.width - pointSize * 0.3)
                text.draw(at: CGPoint(x: x, y: origin.y + first.midY - size.height / 2), withAttributes: markerAttributes)
            }
        }
    }
}
