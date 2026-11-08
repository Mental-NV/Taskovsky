import AppKit
import Foundation

/// Closed render/extract mapping between `RichBody` and `NSTextStorage`.
///
/// Only these attributes are ever written or read; anything else in the
/// storage is dropped on the next commit, so pasted content normalizes.
/// Heading application composes per character: adding a heading keeps each
/// character's italic/code traits, and removing one restores the base size
/// per character instead of smearing one font across the paragraph.
public enum RichRender {
    public static let highlightKey = NSAttributedString.Key("TaskovskyHighlight")
    public static let codeKey = NSAttributedString.Key("TaskovskyCode")
    public static let headingKey = NSAttributedString.Key("TaskovskyHeading")
    /// Explicit bold marker, independent of the rendered font weight. A bold
    /// subsection inside a heading keeps this marker (the semibold heading
    /// font already looks bold), so the state survives heading on/off and
    /// reload instead of being inferred from font traits.
    public static let boldKey = NSAttributedString.Key("TaskovskyBold")
    public static let quoteKey = NSAttributedString.Key("TaskovskyQuote")
    /// Horizontal-rule marker. Lives on otherwise empty paragraphs only; the
    /// layout manager draws the line, so no text is ever inserted for it.
    public static let ruleKey = NSAttributedString.Key("TaskovskyRule")

    public static var highlightWash: NSColor { NSColor.systemYellow.withAlphaComponent(0.28) }
    public static var codeWash: NSColor { NSColor.quaternaryLabelColor.withAlphaComponent(0.35) }

    public static var baseFont: NSFont { NSFont.systemFont(ofSize: 14) }

    public static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: NSColor.labelColor]
    }

    /// Taskovsky-chosen heading sizes (reference exposes Heading 1–6 without
    /// establishing point sizes).
    public static func headingFont(_ level: Int) -> NSFont {
        switch level {
        case 1: return NSFont.systemFont(ofSize: 20, weight: .semibold)
        case 2: return NSFont.systemFont(ofSize: 18, weight: .semibold)
        case 3: return NSFont.systemFont(ofSize: 17, weight: .semibold)
        case 4: return NSFont.systemFont(ofSize: 16, weight: .semibold)
        case 5: return NSFont.systemFont(ofSize: 15, weight: .semibold)
        default: return NSFont.systemFont(ofSize: 14, weight: .semibold)
        }
    }

    public static func codeFont(from font: NSFont) -> NSFont {
        let size = max(11, font.pointSize - 1)
        let mono = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return NSFontManager.shared.convert(mono, toHaveTrait: traits(of: font).intersection([.boldFontMask, .italicFontMask]))
    }

    public static func traits(of font: NSFont) -> NSFontTraitMask {
        NSFontManager.shared.traits(of: font)
    }

    public static func baseFontPreservingTraits(of font: NSFont) -> NSFont {
        NSFontManager.shared.convert(baseFont, toHaveTrait: traits(of: font).intersection([.boldFontMask, .italicFontMask]))
    }

    /// Attributes at a caret location (clamped), used for typing attributes
    /// and toolbar state when the selection is collapsed.
    public static func attributes(at location: Int, in view: NSTextView) -> [NSAttributedString.Key: Any] {
        guard let storage = view.textStorage, storage.length > 0 else { return baseAttributes }
        let string = storage.string as NSString
        // Caret in the trailing empty paragraph (EOF past a final newline):
        // that paragraph has no characters, so storage has nothing to
        // inherit — the live typing attributes are authoritative. Clamping
        // to the previous paragraph would resurrect a block style the user
        // already exited (or armed away from).
        if location >= string.length && string.hasSuffix("\n") {
            var attrs = view.typingAttributes
            attrs[.foregroundColor] = NSColor.labelColor
            return attrs
        }
        let index = min(max(0, location), storage.length - 1)
        var attrs = storage.attributes(at: index, effectiveRange: nil)
        attrs[.foregroundColor] = NSColor.labelColor
        return attrs
    }

    public static func attributedString(text: String, rich: RichBody?) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        guard let rich = rich?.valid(for: text)?.sanitized(), !text.isEmpty else { return result }
        let ns = text as NSString
        for run in rich.runs {
            let range = NSRange(location: run.location, length: run.length)
            guard NSMaxRange(range) <= ns.length else { continue }
            if run.bold { result.addAttribute(boldKey, value: true, range: range) }
            result.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                var font = (value as? NSFont) ?? baseFont
                if run.bold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
                if run.italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
                if run.code { font = codeFont(from: font) }
                result.addAttribute(.font, value: font, range: subrange)
            }
            if run.underline { result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if run.strikethrough { result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if run.highlight {
                result.addAttribute(highlightKey, value: true, range: range)
                result.addAttribute(.backgroundColor, value: highlightWash, range: range)
            }
            if run.code {
                result.addAttribute(codeKey, value: true, range: range)
                // Code keeps a highlight only when it is not highlighted: the
                // code wash must never hide an explicit highlight.
                if !run.highlight {
                    result.addAttribute(.backgroundColor, value: codeWash, range: range)
                }
            }
            if let link = run.link, URL(string: link) != nil {
                result.addAttribute(.link, value: link, range: range)
            }
        }
        // One shared marker object per contiguous run of equal list blocks:
        // adjacent numbered paragraphs carrying the same instance continue
        // 1, 2, 3 instead of restarting at each paragraph.
        var listKey: (RichListStyle, Bool)? = nil
        var listEnd = -1
        var sharedList: NSTextList? = nil
        for block in rich.blocks {
            let range = NSRange(location: block.location, length: block.length)
            guard NSMaxRange(range) <= ns.length else { continue }
            let paragraphs = ns.paragraphRanges(intersecting: range)
            for para in paragraphs {
                if let level = block.validHeading {
                    // Compose per character: the heading upgrades size/weight
                    // but each character keeps its italic trait and code font,
                    // and the explicit bold marker is left untouched (toggling
                    // bold inside a heading records state without restyling).
                    result.enumerateAttribute(.font, in: para, options: []) { value, subrange, _ in
                        let current = value as? NSFont ?? baseFont
                        var font = headingFont(level)
                        if traits(of: current).contains(.italicFontMask) {
                            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                        }
                        if (result.attribute(codeKey, at: subrange.location, effectiveRange: nil) as? Bool) == true {
                            font = codeFont(from: font)
                        }
                        result.addAttribute(.font, value: font, range: subrange)
                    }
                    result.addAttribute(headingKey, value: level, range: para)
                }
                if block.quote {
                    let style = mutableParagraphStyle(in: result, at: para.location)
                    style.headIndent = 16
                    style.firstLineHeadIndent = 16
                    result.addAttribute(.paragraphStyle, value: style, range: para)
                    result.addAttribute(quoteKey, value: true, range: para)
                }
                if let list = block.list {
                    let key = (list, block.checked ?? false)
                    if listKey.map({ $0.0 == key.0 && $0.1 == key.1 }) != true || block.location != listEnd {
                        sharedList = textList(for: list, checked: block.checked)
                        listKey = key
                    }
                    listEnd = block.location + block.length
                    let style = mutableParagraphStyle(in: result, at: para.location)
                    // Gutter on the first line too: markers paint in
                    // [padding, padding + 24), so firstLineHeadIndent must
                    // also be 24 or text overlaps the marker (and TextKit's
                    // own marker slot has no room). See ListDecoration.
                    style.headIndent = ListDecoration.gutterWidth
                    style.firstLineHeadIndent = ListDecoration.gutterWidth
                    style.textLists = [sharedList ?? textList(for: list, checked: block.checked)]
                    result.addAttribute(.paragraphStyle, value: style, range: para)
                }
                if block.rule, isRuleParagraph(para, in: ns) {
                    // A rule is an empty line: breathing room plus the marker
                    // the layout manager draws. Non-empty paragraphs never
                    // receive the marker, so a rule that gained text
                    // self-heals on the next extract instead of styling
                    // foreign text.
                    let style = mutableParagraphStyle(in: result, at: para.location)
                    style.paragraphSpacingBefore = 6
                    style.paragraphSpacing = 6
                    result.addAttribute(.paragraphStyle, value: style, range: para)
                    result.addAttribute(ruleKey, value: true, range: para)
                }
            }
        }
        return result
    }

    /// True when `para` is an empty line (only its newline): the only shape a
    /// horizontal rule may take, so rule markers never attach to text.
    public static func isRuleParagraph(_ para: NSRange, in string: NSString) -> Bool {
        guard para.length > 0, NSMaxRange(para) <= string.length else { return false }
        let bodyLength = string.substring(with: para).hasSuffix("\n") ? para.length - 1 : para.length
        return bodyLength == 0
    }

    /// Shared marker object per list kind: adjacent paragraphs carrying the
    /// same instance continue decimal numbering instead of restarting.
    public static func textList(for list: RichListStyle, checked: Bool? = nil) -> NSTextList {
        switch list {
        case .bullet: return NSTextList(markerFormat: .disc, options: 0)
        case .numbered: return NSTextList(markerFormat: .decimal, options: 0)
        case .checklist: return NSTextList(markerFormat: (checked ?? false) ? .check : .box, options: 0)
        }
    }

    /// Decodes a paragraph marker back to its list style. Markers the editor
    /// never writes (circle, diamond, square, …) read as bullets.
    public static func listStyle(for marker: NSTextList.MarkerFormat?) -> (RichListStyle, checked: Bool)? {
        switch marker {
        case .decimal: return (.numbered, false)
        case .box: return (.checklist, false)
        case .check: return (.checklist, true)
        case nil: return nil
        default: return (.bullet, false)
        }
    }

    public static func mutableParagraphStyle(in storage: NSAttributedString, at location: Int) -> NSMutableParagraphStyle {
        if let existing = storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle,
           let copy = existing.mutableCopy() as? NSMutableParagraphStyle {
            return copy
        }
        return NSMutableParagraphStyle()
    }

    /// Extracts `(text, rich)` from the live storage. Returns nil rich when
    /// nothing is styled so plain bodies persist exactly as before.
    public static func extract(from view: NSTextView) -> (text: String, rich: RichBody?) {
        guard let storage = view.textStorage else { return (view.string, nil) }
        return extract(text: view.string, storage: storage)
    }

    /// Storage-level extraction, testable without a view.
    public static func extract(text: String, storage: NSTextStorage) -> (text: String, rich: RichBody?) {
        let ns = text as NSString
        guard ns.length > 0, storage.length > 0 else { return (text, nil) }
        var runs: [RichInlineRun] = []
        storage.enumerateAttributes(in: NSRange(location: 0, length: min(ns.length, storage.length)), options: []) { attrs, range, _ in
            let font = attrs[.font] as? NSFont ?? baseFont
            let fontTraits = traits(of: font)
            let underline = (attrs[.underlineStyle] as? Int ?? 0) != 0
            let strike = (attrs[.strikethroughStyle] as? Int ?? 0) != 0
            let highlight = (attrs[highlightKey] as? Bool) ?? false
            let code = (attrs[codeKey] as? Bool) ?? false
            let link: String? = {
                if let url = attrs[.link] as? URL { return url.absoluteString }
                if let string = attrs[.link] as? String { return string }
                return nil
            }()
            // Explicit marker wins; otherwise infer from the font weight
            // (pasted content) unless a heading marker explains semibold.
            let headed = (attrs[headingKey] as? Int) != nil
            let run = RichInlineRun(
                location: range.location, length: range.length,
                bold: (attrs[boldKey] as? Bool) ?? (fontTraits.contains(.boldFontMask) && !headed),
                italic: fontTraits.contains(.italicFontMask),
                underline: underline, strikethrough: strike,
                highlight: highlight, code: code, link: link)
            if !run.isEmpty { runs.append(run) }
        }
        var blocks: [RichBlockRun] = []
        for para in ns.allParagraphRanges() {
            // Marker and style travel together: a heading key on a uniformly
            // base-font paragraph (or a quote key without its indent) is
            // stale — e.g. an exited block whose key outlived a typing reset
            // through a replacement path — and extracts as plain.
            let headingRaw = storage.attribute(headingKey, at: para.location, effectiveRange: nil) as? Int
            let quoteRaw = (storage.attribute(quoteKey, at: para.location, effectiveRange: nil) as? Bool) ?? false
            let heading = (headingRaw != nil && RichMutate.staleHeading(in: storage, para: para)) ? nil : headingRaw
            let quote = quoteRaw && !RichMutate.staleQuote(in: storage, para: para)
            let marker = (storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
            let decoded = listStyle(for: marker)
            // Rules only count on empty lines: a marker that somehow reached
            // a text paragraph is ignored here (and dropped on the next
            // render), never extracted as a rule over foreign text.
            let rule = ((storage.attribute(ruleKey, at: para.location, effectiveRange: nil) as? Bool) ?? false) && isRuleParagraph(para, in: ns)
            let block = RichBlockRun(location: para.location, length: para.length, heading: heading, quote: quote, list: decoded?.0, checked: decoded.map { $0.checked ? true : nil } ?? nil, rule: rule)
            if !block.isEmpty { blocks.append(block) }
        }
        let body = RichBody(text: text, runs: runs, blocks: blocks).sanitized()
        return (text, body.isEmpty ? nil : body)
    }

    /// Uniform selection state: a trait counts as active only when every
    /// character in the selection carries it (collapsed: typing attributes).
    public static func toolbarState(for selection: NSRange, in view: NSTextView) -> RichToolbarState {
        guard let storage = view.textStorage, storage.length > 0 else {
            // Empty document: reflect the typing attributes, so arming a
            // block (heading/list/quote) before the first character shows
            // the toolbar active instead of lying idle.
            var attrs = view.typingAttributes
            attrs[.foregroundColor] = NSColor.labelColor
            return stateFromAttributes(attrs, heading: attrs[headingKey] as? Int, view: view, location: 0)
        }
        if selection.length == 0 {
            let attrs = attributes(at: selection.location, in: view)
            return stateFromAttributes(attrs, heading: attrs[headingKey] as? Int, view: view, location: selection.location)
        }
        var state = RichToolbarState()
        state.hasSelection = true
        let range = NSIntersectionRange(selection, NSRange(location: 0, length: storage.length))
        guard range.length > 0 else { return state }
        var bold = true, italic = true, underline = true, strike = true
        var highlight = true, code = true
        var link: String?
        var linkUniform = true
        storage.enumerateAttributes(in: range, options: []) { attrs, _, _ in
            let font = attrs[.font] as? NSFont ?? baseFont
            let fontTraits = traits(of: font)
            let isHeading = (attrs[headingKey] as? Int) != nil
            if let marked = attrs[boldKey] as? Bool {
                bold = bold && marked
            } else {
                bold = bold && fontTraits.contains(.boldFontMask) && !isHeading
            }
            italic = italic && fontTraits.contains(.italicFontMask)
            underline = underline && (attrs[.underlineStyle] as? Int ?? 0) != 0
            strike = strike && (attrs[.strikethroughStyle] as? Int ?? 0) != 0
            highlight = highlight && ((attrs[highlightKey] as? Bool) ?? false)
            code = code && ((attrs[codeKey] as? Bool) ?? false)
            let current: String? = {
                if let url = attrs[.link] as? URL { return url.absoluteString }
                return attrs[.link] as? String
            }()
            if link == nil { link = current }
            else if link != current { linkUniform = false }
        }
        state.bold = bold; state.italic = italic; state.underline = underline
        state.strikethrough = strike; state.highlight = highlight; state.code = code
        state.link = linkUniform ? link : nil
        // Paragraph state is uniform only when every touched paragraph agrees.
        let ns = view.string as NSString
        let paras = ns.paragraphRanges(intersecting: range)
        var heading: Int?? = .some(nil)
        var quote = true, bullet = true, numbered = true, checklist = true, checked = true
        var first = true
        for para in paras {
            let level = storage.attribute(headingKey, at: para.location, effectiveRange: nil) as? Int
            let isQuote = (storage.attribute(quoteKey, at: para.location, effectiveRange: nil) as? Bool) ?? false
            let marker = (storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
            let decoded = listStyle(for: marker)
            if first {
                heading = .some(level); quote = isQuote
                bullet = decoded?.0 == .bullet
                numbered = decoded?.0 == .numbered
                checklist = decoded?.0 == .checklist
                checked = decoded?.checked ?? false
                first = false
            } else {
                if heading != .some(level) { heading = nil }
                quote = quote && isQuote
                bullet = bullet && decoded?.0 == .bullet
                numbered = numbered && decoded?.0 == .numbered
                let isCheck = decoded?.0 == .checklist
                checklist = checklist && isCheck
                checked = checked && isCheck && (decoded?.checked ?? false)
            }
        }
        if let resolved = heading { state.heading = resolved }
        state.quote = quote && !paras.isEmpty
        state.bullet = bullet && !paras.isEmpty
        state.numbered = numbered && !paras.isEmpty
        state.checklist = checklist && !paras.isEmpty
        state.checklistChecked = checked && !paras.isEmpty
        return state
    }

    private static func stateFromAttributes(_ attrs: [NSAttributedString.Key: Any], heading: Int?, view: NSTextView, location: Int) -> RichToolbarState {
        var state = RichToolbarState()
        let font = attrs[.font] as? NSFont ?? baseFont
        let fontTraits = traits(of: font)
        state.bold = (attrs[boldKey] as? Bool) ?? (fontTraits.contains(.boldFontMask) && heading == nil)
        state.italic = fontTraits.contains(.italicFontMask)
        state.underline = (attrs[.underlineStyle] as? Int ?? 0) != 0
        state.strikethrough = (attrs[.strikethroughStyle] as? Int ?? 0) != 0
        state.highlight = (attrs[highlightKey] as? Bool) ?? false
        state.code = (attrs[codeKey] as? Bool) ?? false
        if let url = attrs[.link] as? URL { state.link = url.absoluteString }
        else { state.link = attrs[.link] as? String }
        state.heading = heading
        // Paragraph state with no characters of its own (empty document, or
        // the caret in the trailing empty paragraph past a final newline)
        // lives in the typing attributes, never in clamped storage: the
        // trailing paragraph is styled by typing alone, and clamping would
        // report the previous paragraph's block after an exit.
        let typingParagraph: Bool = {
            guard let storage = view.textStorage, storage.length > 0 else { return true }
            let string = storage.string as NSString
            return location >= string.length && string.hasSuffix("\n")
        }()
        if !typingParagraph, let storage = view.textStorage, storage.length > 0 {
            let index = min(max(0, location), storage.length - 1)
            let marker = (storage.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
            let decoded = listStyle(for: marker)
            state.bullet = decoded?.0 == .bullet
            state.numbered = decoded?.0 == .numbered
            state.checklist = decoded?.0 == .checklist
            state.checklistChecked = decoded?.checked ?? false
            state.quote = (storage.attribute(quoteKey, at: index, effectiveRange: nil) as? Bool) ?? false
        } else {
            let typing = view.typingAttributes
            let marker = (typing[.paragraphStyle] as? NSParagraphStyle)?.textLists.first?.markerFormat
            let decoded = listStyle(for: marker)
            state.bullet = decoded?.0 == .bullet
            state.numbered = decoded?.0 == .numbered
            state.checklist = decoded?.0 == .checklist
            state.checklistChecked = decoded?.checked ?? false
            state.quote = (typing[quoteKey] as? Bool) ?? false
        }
        return state
    }
}

/// Typing-attribute toggles for a collapsed caret. Mirrors the storage
/// toggles so typing after a toolbar tap inherits exactly what a selection
/// toggle would have applied.
public enum RichTyping {
    /// Collapsed-caret bold: flips the explicit marker and converts the
    /// typing font so continued typing inherits the state.
    public static func toggleBold(in attrs: inout [NSAttributedString.Key: Any]) {
        let font = (attrs[.font] as? NSFont) ?? RichRender.baseFont
        if (attrs[RichRender.boldKey] as? Bool) == true {
            attrs.removeValue(forKey: RichRender.boldKey)
            attrs[.font] = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
        } else {
            attrs[RichRender.boldKey] = true
            attrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
    }
    public static func toggleFlag(_ key: NSAttributedString.Key, value: Int, in attrs: inout [NSAttributedString.Key: Any]) {
        if (attrs[key] as? Int ?? 0) != 0 { attrs.removeValue(forKey: key) }
        else { attrs[key] = value }
    }

    public static func toggleHighlight(in attrs: inout [NSAttributedString.Key: Any]) {
        if (attrs[RichRender.highlightKey] as? Bool) == true {
            attrs.removeValue(forKey: RichRender.highlightKey)
            // A surviving code marker keeps its wash; only a highlight-free
            // background clears.
            if (attrs[RichRender.codeKey] as? Bool) == true {
                attrs[.backgroundColor] = RichRender.codeWash
            } else {
                attrs.removeValue(forKey: .backgroundColor)
            }
        } else {
            attrs[RichRender.highlightKey] = true
            attrs[.backgroundColor] = RichRender.highlightWash
        }
    }

    public static func toggleCode(in attrs: inout [NSAttributedString.Key: Any]) {
        if (attrs[RichRender.codeKey] as? Bool) == true {
            attrs.removeValue(forKey: RichRender.codeKey)
            let font = (attrs[.font] as? NSFont) ?? RichRender.baseFont
            var restored = RichRender.baseFont
            if let level = attrs[RichRender.headingKey] as? Int {
                restored = RichRender.headingFont(level)
            }
            if RichRender.traits(of: font).contains(.italicFontMask) {
                restored = NSFontManager.shared.convert(restored, toHaveTrait: .italicFontMask)
            }
            if (attrs[RichRender.boldKey] as? Bool) == true {
                restored = NSFontManager.shared.convert(restored, toHaveTrait: .boldFontMask)
            }
            attrs[.font] = restored
            if (attrs[RichRender.highlightKey] as? Bool) != true {
                attrs.removeValue(forKey: .backgroundColor)
            }
        } else {
            attrs[RichRender.codeKey] = true
            let font = (attrs[.font] as? NSFont) ?? RichRender.baseFont
            attrs[.font] = RichRender.codeFont(from: font)
            if (attrs[RichRender.highlightKey] as? Bool) != true {
                attrs[.backgroundColor] = RichRender.codeWash
            }
        }
    }

    /// Typing-attribute half of a Return exit from a paragraph with no
    /// characters to mutate (the trailing empty paragraph, or an armed
    /// empty document). Mirrors what `exitEmptyBlock` clears in storage:
    /// heading/quote/list markers go, the font returns to base, indents
    /// reset — while deliberate inline flags (underline, highlight, code)
    /// survive exactly as the storage path leaves them on the newline.
    public static func exitedBlockAttributes(from attrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var attrs = attrs
        attrs[.font] = RichRender.baseFont
        attrs.removeValue(forKey: RichRender.headingKey)
        attrs.removeValue(forKey: RichRender.quoteKey)
        attrs.removeValue(forKey: RichRender.boldKey)
        let style = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.textLists = []
        style.headIndent = 0
        style.firstLineHeadIndent = 0
        attrs[.paragraphStyle] = style
        attrs[.foregroundColor] = NSColor.labelColor
        return attrs
    }
}

/// Storage mutations behind every toolbar command. Ranges are clamped to the
/// storage; empty ranges are no-ops. Toggle reads use uniform semantics (the
/// attribute flips off only when every character carries it), matching the
/// toolbar state computation.
public enum RichMutate {
    public static func clamped(_ range: NSRange, in storage: NSTextStorage) -> NSRange {
        // Preserve an exact-EOF collapsed caret: NSIntersectionRange maps a
        // boundary zero-length range to (0,0), which would teleport later
        // paragraph math onto the first paragraph instead of the caret.
        if range.length == 0, range.location == storage.length { return range }
        return NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
    }

    public static func toggleTrait(_ trait: NSFontTraitMask, in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0 else { return }
        if trait == .boldFontMask {
            // Explicit marker carries bold independently of the rendered
            // weight, so toggling inside a heading records state (the
            // semibold heading font needs no visual change).
            var allHave = true
            storage.enumerateAttribute(RichRender.boldKey, in: range, options: []) { value, _, _ in
                if (value as? Bool) != true { allHave = false }
            }
            if allHave { storage.removeAttribute(RichRender.boldKey, range: range) }
            else { storage.addAttribute(RichRender.boldKey, value: true, range: range) }
            return
        }
        var allHave = true
        storage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            let font = (value as? NSFont) ?? RichRender.baseFont
            if !RichRender.traits(of: font).contains(trait) { allHave = false }
        }
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? NSFont) ?? RichRender.baseFont
            let updated = allHave
                ? NSFontManager.shared.convert(font, toNotHaveTrait: trait)
                : NSFontManager.shared.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: updated, range: subrange)
        }
    }

    public static func toggleAttribute(_ key: NSAttributedString.Key, value: Any, in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0 else { return }
        var allHave = true
        storage.enumerateAttribute(key, in: range, options: []) { attrValue, _, _ in
            if !isSet(attrValue) { allHave = false }
        }
        if allHave {
            storage.removeAttribute(key, range: range)
        } else {
            storage.addAttribute(key, value: value, range: range)
        }
    }

    private static func isSet(_ value: Any?) -> Bool {
        if let number = value as? Int { return number != 0 }
        if let number = value as? NSNumber { return number != 0 }
        if let flag = value as? Bool { return flag }
        return value != nil
    }

    /// Highlight toggling that respects code: removing the highlight from
    /// coded text restores the code wash instead of clearing the background.
    public static func toggleHighlight(in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0 else { return }
        var allHave = true
        storage.enumerateAttribute(RichRender.highlightKey, in: range, options: []) { value, _, _ in
            if (value as? Bool) != true { allHave = false }
        }
        if allHave {
            storage.removeAttribute(RichRender.highlightKey, range: range)
            storage.enumerateAttribute(RichRender.codeKey, in: range, options: []) { value, subrange, _ in
                if (value as? Bool) == true {
                    storage.addAttribute(.backgroundColor, value: RichRender.codeWash, range: subrange)
                } else {
                    storage.removeAttribute(.backgroundColor, range: subrange)
                }
            }
        } else {
            storage.addAttribute(RichRender.highlightKey, value: true, range: range)
            storage.addAttribute(.backgroundColor, value: RichRender.highlightWash, range: range)
        }
    }

    public static func toggleCode(in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0 else { return }
        var allHave = true
        storage.enumerateAttribute(RichRender.codeKey, in: range, options: []) { value, _, _ in
            if (value as? Bool) != true { allHave = false }
        }
        if allHave {
            storage.removeAttribute(RichRender.codeKey, range: range)
            // Restore per attribute run: a heading font survives code-off,
            // bold survives only where its marker is set, and drop the
            // code wash (an explicit highlight underneath stays intact).
            storage.enumerateAttributes(in: range, options: []) { attrs, subrange, _ in
                let current = attrs[.font] as? NSFont ?? RichRender.baseFont
                let traits = RichRender.traits(of: current)
                var font = RichRender.baseFont
                if let level = attrs[RichRender.headingKey] as? Int {
                    font = RichRender.headingFont(level)
                }
                if traits.contains(.italicFontMask) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                if (attrs[RichRender.boldKey] as? Bool) == true {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                storage.addAttribute(.font, value: font, range: subrange)
            }
            storage.enumerateAttribute(RichRender.highlightKey, in: range, options: []) { value, subrange, _ in
                if (value as? Bool) != true {
                    storage.removeAttribute(.backgroundColor, range: subrange)
                }
            }
        } else {
            storage.addAttribute(RichRender.codeKey, value: true, range: range)
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let font = (value as? NSFont) ?? RichRender.baseFont
                storage.addAttribute(.font, value: RichRender.codeFont(from: font), range: subrange)
            }
            // Only wash where no explicit highlight already paints.
            storage.enumerateAttribute(RichRender.highlightKey, in: range, options: []) { value, subrange, _ in
                if (value as? Bool) != true {
                    storage.addAttribute(.backgroundColor, value: RichRender.codeWash, range: subrange)
                }
            }
        }
    }

    public static func setHeading(_ level: Int?, in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0, let string = storage.string as NSString? else { return }
        for para in string.paragraphRanges(intersecting: range) {
            if let level {
                // Compose per attribute run (see render): italic and code
                // survive. Full-run enumeration keeps marker boundaries, so a
                // code boundary inside one font never reads the wrong marker.
                storage.enumerateAttributes(in: para, options: []) { attrs, subrange, _ in
                    let current = attrs[.font] as? NSFont ?? RichRender.baseFont
                    var font = RichRender.headingFont(level)
                    if RichRender.traits(of: current).contains(.italicFontMask) {
                        font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    }
                    if (attrs[RichRender.codeKey] as? Bool) == true {
                        font = RichRender.codeFont(from: font)
                    }
                    storage.addAttribute(.font, value: font, range: subrange)
                }
                storage.addAttribute(RichRender.headingKey, value: level, range: para)
            } else {
                // Restore per attribute run from explicit markers: the heading
                // font is semibold-derived, so inferring bold from traits
                // would smear bold everywhere. Only marked bold survives, and
                // full-run enumeration keeps marker boundaries exact.
                storage.enumerateAttributes(in: para, options: []) { attrs, subrange, _ in
                    let current = attrs[.font] as? NSFont ?? RichRender.baseFont
                    var font = RichRender.baseFont
                    if RichRender.traits(of: current).contains(.italicFontMask) {
                        font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    }
                    if (attrs[RichRender.boldKey] as? Bool) == true {
                        font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                    }
                    if (attrs[RichRender.codeKey] as? Bool) == true {
                        font = RichRender.codeFont(from: font)
                    }
                    storage.addAttribute(.font, value: font, range: subrange)
                }
                storage.removeAttribute(RichRender.headingKey, range: para)
            }
        }
    }

    public static func toggleQuote(in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0, let string = storage.string as NSString? else { return }
        let paras = string.paragraphRanges(intersecting: range)
        guard !paras.isEmpty else { return }
        let allQuoted = paras.allSatisfy { (storage.attribute(RichRender.quoteKey, at: $0.location, effectiveRange: nil) as? Bool) ?? false }
        for para in paras {
            let style = RichRender.mutableParagraphStyle(in: storage, at: para.location)
            if allQuoted {
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                storage.addAttribute(.paragraphStyle, value: style, range: para)
                storage.removeAttribute(RichRender.quoteKey, range: para)
            } else {
                style.headIndent = 16
                style.firstLineHeadIndent = 16
                storage.addAttribute(.paragraphStyle, value: style, range: para)
                storage.addAttribute(RichRender.quoteKey, value: true, range: para)
            }
        }
    }

    public static func toggleList(_ listStyle: RichListStyle, in storage: NSTextStorage, range: NSRange) {
        setList(listStyle, checked: nil, in: storage, range: range)
    }

    /// Applies a list style to whole paragraphs. `nil` checklist state means
    /// the uniform toggle: on when not uniformly that list, off when it is.
    /// One shared marker object per call keeps numbered items continuous.
    public static func setList(_ listStyle: RichListStyle, checked: Bool?, in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0, let string = storage.string as NSString? else { return }
        let paras = string.paragraphRanges(intersecting: range)
        guard !paras.isEmpty else { return }
        let allMatch: Bool = {
            switch (listStyle, checked) {
            case (.checklist, .some(let want)):
                return paras.allSatisfy {
                    guard let state = paraListState(in: storage, at: $0.location) else { return false }
                    return state.0 == .checklist && state.1 == want
                }
            case (.checklist, nil):
                return paras.allSatisfy { paraListState(in: storage, at: $0.location)?.0 == .checklist }
            default:
                return paras.allSatisfy { paraListState(in: storage, at: $0.location)?.0 == listStyle }
            }
        }()
        // Checklist with an explicit checked value always applies (it is a
        // state change, not a toggle); every other call toggles uniformly.
        let shouldApply: Bool = {
            if case (.checklist, .some) = (listStyle, checked) { return true }
            return !allMatch
        }()
        let shared = RichRender.textList(for: listStyle, checked: checked ?? false)
        for para in paras {
            let style = RichRender.mutableParagraphStyle(in: storage, at: para.location)
            if shouldApply {
                style.textLists = [shared]
                style.headIndent = ListDecoration.gutterWidth
                style.firstLineHeadIndent = ListDecoration.gutterWidth
            } else {
                style.textLists = []
                style.headIndent = 0
                style.firstLineHeadIndent = 0
            }
            storage.addAttribute(.paragraphStyle, value: style, range: para)
        }
    }

    private static func paraListState(in storage: NSTextStorage, at location: Int) -> (RichListStyle, Bool)? {
        let marker = (storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
        return RichRender.listStyle(for: marker)
    }

    public static func setLink(_ urlString: String, in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0, URL(string: urlString) != nil else { return }
        storage.addAttribute(.link, value: urlString, range: range)
    }

    public static func removeLink(in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0 else { return }
        storage.removeAttribute(.link, range: range)
    }

    public static func clearFormatting(in storage: NSTextStorage, range: NSRange) {
        let range = clamped(range, in: storage)
        guard range.length > 0, let string = storage.string as NSString? else { return }
        // Inline: restore base font with no traits, drop link/underline/strike
        // markers and washes.
        storage.enumerateAttribute(.font, in: range, options: []) { _, subrange, _ in
            storage.addAttribute(.font, value: RichRender.baseFont, range: subrange)
        }
        for key: NSAttributedString.Key in [.underlineStyle, .strikethroughStyle, .link, RichRender.boldKey, RichRender.highlightKey, RichRender.codeKey, .backgroundColor] {
            storage.removeAttribute(key, range: range)
        }
        // Paragraph: drop heading/quote/list markers and restore indentation.
        for para in string.paragraphRanges(intersecting: range) {
            let style = RichRender.mutableParagraphStyle(in: storage, at: para.location)
            style.textLists = []
            style.headIndent = 0
            style.firstLineHeadIndent = 0
            storage.addAttribute(.paragraphStyle, value: style, range: para)
            storage.removeAttribute(RichRender.headingKey, range: para)
            storage.removeAttribute(RichRender.quoteKey, range: para)
        }
        storage.removeAttribute(RichRender.ruleKey, range: range)
    }

    /// Inserts a horizontal rule as its own empty paragraph at the end of the
    /// paragraph containing `location`, then returns the caret position for
    /// the fresh empty paragraph after it. The rule carries no text: the
    /// layout manager draws it and the plain body keeps a blank line.
    /// Returns nil when `location` is out of bounds.
    public static func insertHorizontalRule(in storage: NSTextStorage, at location: Int) -> Int? {
        let string = storage.string as NSString
        guard location >= 0, location <= string.length else { return nil }
        storage.beginEditing()
        defer { storage.endEditing() }
        if string.length == 0 {
            // "\n\n": the first newline is the rule paragraph, the second
            // opens a fresh paragraph for the caret.
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "\n\n")
            let rule = NSRange(location: 0, length: 1)
            applyRuleStyle(in: storage, range: rule)
            return 2
        }
        let oldLength = string.length
        let at = min(location, max(0, oldLength))
        let para = string.paragraphRange(for: NSRange(location: min(at, max(0, oldLength - 1)), length: 0))
        let insertAt = NSMaxRange(para)
        // One newline guarantees an empty paragraph at `insertAt` — unless it
        // lands at the very end, where it merely terminates the last
        // paragraph (a trailing newline alone starts no paragraph range).
        storage.replaceCharacters(in: NSRange(location: insertAt, length: 0), with: "\n")
        if insertAt == oldLength {
            // End of document: the newline just terminated the last
            // paragraph, so the rule paragraph comes after it.
            storage.replaceCharacters(in: NSRange(location: insertAt + 1, length: 0), with: "\n")
            let rule = NSRange(location: insertAt + 1, length: 1)
            applyRuleStyle(in: storage, range: rule)
            return insertAt + 2
        }
        applyRuleStyle(in: storage, range: NSRange(location: insertAt, length: 1))
        return insertAt + 1
    }

    private static func applyRuleStyle(in storage: NSTextStorage, range: NSRange) {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 6
        style.paragraphSpacing = 6
        storage.addAttribute(.paragraphStyle, value: style, range: range)
        storage.addAttribute(RichRender.ruleKey, value: true, range: range)
        storage.addAttribute(.font, value: RichRender.baseFont, range: range)
    }

    /// Return-key decision shared by the editor's command (`insertNewline:`)
    /// and text-change (`shouldChangeTextInRanges` "\n") dispatch paths.
    /// `.exitBlock`: a stored empty block paragraph to strip via
    /// `exitEmptyBlock`. `.exitTrailingBlock`: the caret sits in the
    /// trailing empty paragraph (EOF past a final newline) or an armed
    /// empty document — there are no characters to mutate, so the caller
    /// resets the typing attributes instead and must NOT touch the
    /// preceding paragraph's style. `.insertNewline`: the newline proceeds.
    public enum ReturnExit: Equatable {
        case insertNewline
        case exitBlock
        case exitTrailingBlock
    }

    public static func returnExit(in storage: NSTextStorage, range: NSRange, typingAttributes: [NSAttributedString.Key: Any], pending: RichListStyle? = nil) -> ReturnExit {
        let range = clamped(range, in: storage)
        guard range.length == 0 else { return .insertNewline }
        let string = storage.string as NSString
        let loc = min(range.location, string.length)
        // A pending list arm counts as armed even though AppKit strips
        // textLists from assigned typing attributes: the arm, not the
        // (stripped) typing, is the style source until first input.
        if string.length == 0 || (loc == string.length && string.hasSuffix("\n")) {
            return (hasBlockMarkers(typingAttributes) || pending != nil) ? .exitTrailingBlock : .insertNewline
        }
        let para = string.paragraphRange(for: NSRange(location: min(loc, max(0, string.length - 1)), length: 0))
        guard RichRender.isRuleParagraph(para, in: string) || paragraphBody(string, para).isEmpty else { return .insertNewline }
        if (storage.attribute(RichRender.ruleKey, at: para.location, effectiveRange: nil) as? Bool) == true { return .insertNewline }
        let listed = (storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first != nil
        let headed = (storage.attribute(RichRender.headingKey, at: para.location, effectiveRange: nil) as? Int) != nil
        let quoted = (storage.attribute(RichRender.quoteKey, at: para.location, effectiveRange: nil) as? Bool) == true
        return (listed || headed || quoted) ? .exitBlock : .insertNewline
    }

    /// Block markers in a typing-attributes dictionary — the trailing empty
    /// paragraph's only style source.
    public static func hasBlockMarkers(_ typingAttributes: [NSAttributedString.Key: Any]) -> Bool {
        let listed = (typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.first != nil
        let headed = (typingAttributes[RichRender.headingKey] as? Int) != nil
        let quoted = (typingAttributes[RichRender.quoteKey] as? Bool) == true
        return listed || headed || quoted
    }

    /// A heading marker with no heading application: every character is
    /// exactly the base font with no bold/code markers. All legitimate
    /// writers set the heading font alongside the key (composition only ever
    /// derives from it), so this state is stale and extracts — and strips —
    /// as plain.
    public static func staleHeading(in storage: NSTextStorage, para: NSRange) -> Bool {
        var stale = true
        storage.enumerateAttributes(in: para, options: []) { attrs, _, stop in
            let font = attrs[.font] as? NSFont ?? RichRender.baseFont
            if !font.isEqual(RichRender.baseFont) { stale = false; stop.pointee = true; return }
            if (attrs[RichRender.boldKey] as? Bool) == true { stale = false; stop.pointee = true; return }
            if (attrs[RichRender.codeKey] as? Bool) == true { stale = false; stop.pointee = true; return }
        }
        return stale
    }

    /// A quote marker without its indentation. Every legitimate writer sets
    /// the 16pt indents alongside the key and clears both together.
    public static func staleQuote(in storage: NSTextStorage, para: NSRange) -> Bool {
        let style = storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle
        return (style?.headIndent ?? 0) == 0 && (style?.firstLineHeadIndent ?? 0) == 0
    }

    /// Paragraphs whose block marker outlived its style (see above). The
    /// editor strips these from storage before extraction so the model, the
    /// toolbar, and later reads agree; plain text is untouched and no
    /// characters are inserted or removed.
    public static func staleBlockRanges(in storage: NSTextStorage) -> [NSRange] {
        var ranges: [NSRange] = []
        let string = storage.string as NSString
        guard string.length > 0, storage.length > 0 else { return [] }
        for para in string.allParagraphRanges() {
            if (storage.attribute(RichRender.headingKey, at: para.location, effectiveRange: nil) as? Int) != nil,
               staleHeading(in: storage, para: para) { ranges.append(para); continue }
            if (storage.attribute(RichRender.quoteKey, at: para.location, effectiveRange: nil) as? Bool) == true,
               staleQuote(in: storage, para: para) { ranges.append(para) }
        }
        return ranges
    }

    /// List continuation the editor re-arms as pending after a typing
    /// assignment. AppKit strips `textLists` from *assigned* typing
    /// attributes — including the coordinator's own refresh from
    /// `attributes(at:in:)` — while AppKit-*derived* continuation typing
    /// (from a real newline insertion) keeps them. So every refresh that
    /// assigns typing can silently drop list continuation the native Return
    /// just derived.
    ///
    /// - `beforeTyping` (the typing from before the assignment) repairs only
    ///   what the assignment destroyed: a re-arm requires lists present
    ///   before and gone after. Exited, cleared, and explicitly chosen
    ///   styles carry no lists, so they stay gone. Pass nil for storage
    ///   edits, where the caret paragraph's stored style is authoritative
    ///   (toggle paths): the edit already removed what the user removed.
    /// Returns the style (with its checked state) to record as pending, or
    /// nil when nothing was lost. The caret paragraph (previous paragraph
    /// at trailing EOF) must carry the list in storage.
    public static func continuationList(beforeTyping: [NSAttributedString.Key: Any]?, typingAttributes: [NSAttributedString.Key: Any], storage: NSTextStorage, selection: NSRange) -> (style: RichListStyle, checked: Bool)? {
        guard selection.length == 0 else { return nil }
        if let before = beforeTyping {
            guard (before[.paragraphStyle] as? NSParagraphStyle)?.textLists.first != nil else { return nil }
            guard ((typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.first) == nil else { return nil }
        } else {
            guard ((typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.first) == nil else { return nil }
        }
        let string = storage.string as NSString
        guard string.length > 0, storage.length > 0 else { return nil }
        let loc = min(selection.location, string.length)
        let anchor: Int
        if loc == string.length && string.hasSuffix("\n") {
            guard loc >= 1 else { return nil }
            anchor = loc - 1
        } else {
            anchor = min(loc, max(0, string.length - 1))
        }
        let para = string.paragraphRange(for: NSRange(location: anchor, length: 0))
        let marker = (storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
        guard let decoded = RichRender.listStyle(for: marker) else { return nil }
        return (decoded.0, decoded.1)
    }

    /// Caret paragraph for a pending list arm: the paragraph holding `caret`
    /// when it does not already carry `style`, nil otherwise (already
    /// styled, empty storage, ranged/out-of-bounds caret). The editor applies
    /// `setList` to the returned range on first input; tests drive this with
    /// real `insertText` and inspect the extracted model and painted markers.
    public static func pendingListTarget(in storage: NSTextStorage, caret: Int, style: RichListStyle) -> NSRange? {
        guard storage.length > 0 else { return nil }
        let string = storage.string as NSString
        guard caret >= 0, caret <= string.length else { return nil }
        let para = string.paragraphRange(for: NSRange(location: min(caret, max(0, string.length - 1)), length: 0))
        let marker = (storage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first?.markerFormat
        guard RichRender.listStyle(for: marker)?.0 != style else { return nil }
        return para
    }

    /// Return-key exit for empty block paragraphs: when the collapsed `range`
    /// sits in an empty list item, heading, or quote, the block styling is
    /// removed (list outdents, heading clears to base) and the newline is
    /// consumed (returns true). Text paragraphs and rule lines return false
    /// so the default newline proceeds — a rule splits into a fresh clean
    /// paragraph because the editor strips `ruleKey` from typing attributes.
    public static func exitEmptyBlock(in storage: NSTextStorage, range: NSRange) -> Bool {
        let range = clamped(range, in: storage)
        guard range.length == 0, storage.length > 0 else { return false }
        let string = storage.string as NSString
        let loc = min(range.location, string.length)
        // Trailing empty paragraph: no characters to mutate. Resolving the
        // paragraph here would land on the PRECEDING paragraph and erase a
        // style the user kept, so this returns false — `returnExit` routes
        // the caret-in-trailing case to the typing-attribute level instead.
        if loc == string.length && string.hasSuffix("\n") { return false }
        let para = string.paragraphRange(for: NSRange(location: min(loc, max(0, string.length - 1)), length: 0))
        guard RichRender.isRuleParagraph(para, in: string) || paragraphBody(string, para).isEmpty else { return false }
        // Rules never consume Return (see above); anything else empty does.
        if (storage.attribute(RichRender.ruleKey, at: para.location, effectiveRange: nil) as? Bool) == true { return false }
        var consumed = false
        if paraListState(in: storage, at: para.location) != nil {
            let style = RichRender.mutableParagraphStyle(in: storage, at: para.location)
            style.textLists = []
            style.headIndent = 0
            style.firstLineHeadIndent = 0
            storage.addAttribute(.paragraphStyle, value: style, range: para)
            consumed = true
        }
        if (storage.attribute(RichRender.headingKey, at: para.location, effectiveRange: nil) as? Int) != nil {
            storage.removeAttribute(RichRender.headingKey, range: para)
            storage.enumerateAttribute(.font, in: para, options: []) { _, subrange, _ in
                storage.addAttribute(.font, value: RichRender.baseFont, range: subrange)
            }
            storage.removeAttribute(RichRender.boldKey, range: para)
            consumed = true
        }
        if (storage.attribute(RichRender.quoteKey, at: para.location, effectiveRange: nil) as? Bool) == true {
            let style = RichRender.mutableParagraphStyle(in: storage, at: para.location)
            style.headIndent = 0
            style.firstLineHeadIndent = 0
            storage.addAttribute(.paragraphStyle, value: style, range: para)
            storage.removeAttribute(RichRender.quoteKey, range: para)
            consumed = true
        }
        return consumed
    }

    private static func paragraphBody(_ string: NSString, _ para: NSRange) -> String {
        let text = string.substring(with: para)
        return text.hasSuffix("\n") ? String(text.dropLast()) : text
    }
}

public extension NSString {
    /// Paragraph ranges intersecting `range` (each includes its newline).
    /// Public so the AppKit editor can share the exact paragraph math.
    func paragraphRanges(intersecting range: NSRange) -> [NSRange] {
        var result: [NSRange] = []
        var index = max(0, min(range.location, length))
        let end = max(index, min(range.location + range.length, length))
        if length == 0 || range.length == 0, length > 0 {
            result.append(paragraphRange(for: NSRange(location: min(index, length - 1), length: 0)))
            return result
        }
        while index < end {
            let para = paragraphRange(for: NSRange(location: index, length: 0))
            result.append(para)
            let next = NSMaxRange(para)
            if next <= index { break }
            index = next
        }
        if result.isEmpty, length > 0 {
            result.append(paragraphRange(for: NSRange(location: min(range.location, length - 1), length: 0)))
        }
        return result
    }

    /// Every paragraph range in the string.
    func allParagraphRanges() -> [NSRange] {
        guard length > 0 else { return [] }
        return paragraphRanges(intersecting: NSRange(location: 0, length: length))
    }
}

/// Selection-derived toolbar state published by the editor coordinator.
public struct RichToolbarState: Equatable {
    public var hasSelection = false
    public var bold = false
    public var italic = false
    public var underline = false
    public var strikethrough = false
    public var highlight = false
    public var code = false
    public var quote = false
    public var heading: Int?
    public var bullet = false
    public var numbered = false
    public var checklist = false
    public var checklistChecked = false
    public var link: String?
    public init() {}
}
