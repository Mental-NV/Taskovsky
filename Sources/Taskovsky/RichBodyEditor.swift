import SwiftUI
import AppKit
import TaskovskyCore
import TaskovskyClipboard
import TaskovskyWorkspace

/// Native AppKit rich-text body editor.
///
/// An `NSTextView` renders the plain body with `RichBody` styles; every edit
/// (typing or toolbar) reports `(body, rich)` through `onChange`, where
/// `rich.text` always mirrors `body`. Search, snippets, summaries, and row
/// previews keep reading the plain `body` and never touch styling.
///
/// Caret/selection safety: `updateNSView` only rebuilds the text storage when
/// the model string actually differs from the view string (external change:
/// template apply, selection switch, undo from another path). Keystrokes flow
/// one way through `textDidChange` and never disturb the caret.
/// Layout manager that draws horizontal rules: paragraphs carrying
/// `RichRender.ruleKey` render as a hairline instead of a blank line.
/// List/quote/rule painting lives in `ListLayoutManager` (TaskovskyCore)
/// so geometry tests can exercise the real drawing computation.
final class RuleDrawingLayoutManager: ListLayoutManager {
}

/// The body editor's text view. It owns a per-view UndoManager (instead of
/// the window's shared one) so switching documents can drop this editor's
/// history without clearing undo for the title field or other views.
/// Typing and formatting undo/redo keep working within one document.
final class RichBodyTextView: NSTextView {
    fileprivate private(set) var handlingTextKey = false
    private let ownedUndo = UndoManager()
    private static let fragmentType = NSPasteboard.PasteboardType(RichBodyClipboard.typeIdentifier)
    private static let qaClipboard: NSPasteboard? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard Bundle.main.bundleIdentifier == "local.taskovsky.native-qa",
              arguments.contains("--workspace") else { return nil }
        let pasteboard = NSPasteboard.withUniqueName()
        if let fixture = arguments.firstIndex(of: "--qa-plain-clipboard"), arguments.indices.contains(fixture + 1) {
            let item = NSPasteboardItem()
            item.setString(arguments[fixture + 1], forType: .string)
            if let html = arguments.firstIndex(of: "--qa-html-clipboard"), arguments.indices.contains(html + 1) {
                item.setData(Data(arguments[html + 1].utf8), forType: .html)
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([item])
        }
        return pasteboard
    }()

    static var descriptionClipboard: NSPasteboard { qaClipboard ?? .general }

    override var undoManager: UndoManager? { ownedUndo }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleHistoryKey(event) || handleQAClipboardKey(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if isEditable, !hasMarkedText(), event.clickCount == 1,
           event.modifierFlags.intersection([.control, .option, .shift]).isEmpty,
           let layout = layoutManager as? ListLayoutManager,
           let marker = layout.checklistMarker(at: convert(event.locationInWindow, from: nil), origin: textContainerOrigin),
           case .checkbox(let checked) = marker.kind,
           let coordinator = delegate as? RichBodyEditor.Coordinator {
            window?.makeFirstResponder(self)
            coordinator.toggleChecklistMarker(marker.paragraph, checked: !checked)
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleHistoryKey(event) || handleQAClipboardKey(event) { return }
        let inCode = selectionStartsInCodeParagraph
        if !inCode, event.characters == "/", !event.isARepeat,
           event.modifierFlags.intersection([.command, .control]).isEmpty,
           (delegate as? RichBodyEditor.Coordinator)?.showSlashMenu(in: self) == true { return }
        handlingTextKey = event.modifierFlags.intersection([.command, .control]).isEmpty
        // Keep the second leading hyphen literal so the third can form a
        // divider. Prose and the system's Smart Dashes preference are untouched.
        let keepsDividerPrefix = isAutomaticDashSubstitutionEnabled && handlingTextKey &&
            event.characters == "-" && !hasMarkedText() && isSecondDividerHyphen
        let restoreDashes = isAutomaticDashSubstitutionEnabled && (keepsDividerPrefix || inCode)
        let restoreQuotes = isAutomaticQuoteSubstitutionEnabled && inCode
        if restoreDashes { isAutomaticDashSubstitutionEnabled = false }
        if restoreQuotes { isAutomaticQuoteSubstitutionEnabled = false }
        defer {
            if restoreDashes { isAutomaticDashSubstitutionEnabled = true }
            if restoreQuotes { isAutomaticQuoteSubstitutionEnabled = true }
            handlingTextKey = false
        }
        super.keyDown(with: event)
    }

    private var selectionStartsInCodeParagraph: Bool {
        guard let storage = textStorage else { return false }
        let paragraph = (string as NSString).paragraphRange(for: NSRange(location: selectedRange().location, length: 0))
        return paragraph.length > 0 && storage.attribute(RichRender.codeBlockKey, at: paragraph.location, effectiveRange: nil) != nil
    }

    private var isSecondDividerHyphen: Bool {
        let caret = selectedRange()
        let text = string as NSString
        guard selectedRanges.count == 1, caret.length == 0, caret.location > 0, caret.location <= text.length,
              text.character(at: caret.location - 1) == 45 else { return false }
        var start = 0, end = 0
        text.getParagraphStart(&start, end: nil, contentsEnd: &end, for: caret)
        return caret.location == start + 1 && caret.location == end
    }

    override func copy(_ sender: Any?) {
        guard !hasMarkedText(), selectedRanges.count == 1, selectedRange().length > 0 else {
            if Self.qaClipboard == nil { super.copy(sender) }
            return
        }
        let selection = selectedRange()
        let extracted = RichRender.extract(from: self)
        let text = (extracted.text as NSString).substring(with: selection)
        let body = extracted.rich ?? RichBody(text: extracted.text)
        let bytes = RichBodyClipboard.fragment(from: body, selection: selection)
            .flatMap(RichBodyClipboard.encode)
        guard bytes != nil || Self.qaClipboard != nil else { super.copy(sender); return }
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if let rtf = rtf(from: selection) { item.setData(rtf, forType: .rtf) }
        if let bytes { item.setData(bytes, forType: Self.fragmentType) }
        let board = Self.qaClipboard ?? .general
        board.clearContents()
        board.writeObjects([item])
    }

    override func cut(_ sender: Any?) {
        if Self.qaClipboard == nil { super.cut(sender) }
    }

    override func pasteAsPlainText(_ sender: Any?) {
        guard isEditable, !hasMarkedText() else { return }
        let board = Self.descriptionClipboard
        if selectedRanges.count == 1, let item = Self.foreignItem(from: board) {
            if let text = item.string(forType: .string) ?? Self.foreignFragment(from: item, plain: nil)?.text {
                pasteLiteral(text)
            }
        } else if Self.qaClipboard == nil {
            super.pasteAsPlainText(sender)
        } else if let text = board.string(forType: .string) {
            pasteLiteral(text)
        }
    }

    override func paste(_ sender: Any?) {
        guard isEditable, !hasMarkedText() else { return }
        if selectedRanges.count != 1 {
            if Self.qaClipboard == nil { super.paste(sender) }
            return
        }
        let board = Self.descriptionClipboard
        let coordinator = delegate as? RichBodyEditor.Coordinator
        let data = board.data(forType: Self.fragmentType)
        let text = board.string(forType: .string)
        if let data, let text, let fragment = RichBodyClipboard.decode(data, matching: text) {
            coordinator?.pasteClipboard(.paste(selectedRange(), fragment: fragment), into: self,
                                        length: fragment.text.utf16.count)
            return
        }
        if let item = Self.foreignItem(from: board) {
            let plain = item.string(forType: .string)
            let fragment = data == nil ? Self.foreignFragment(from: item, plain: plain) : nil
            if let fragment,
               coordinator?.pasteClipboard(.paste(selectedRange(), fragment: fragment), into: self,
                                            length: fragment.text.utf16.count) == true { return }
            if let literal = plain ?? fragment?.text { pasteLiteral(literal) }
            return
        }
        if let text {
            if data == nil, board.availableType(from: [.rtfd, .rtf, .html, .string]) == .string,
               !selectionStartsInCodeParagraph,
               let fragment = RichBodyClipboard.formattedPlainText(text, replacing: selectedRange(), in: string),
               coordinator?.pasteClipboard(.paste(selectedRange(), fragment: fragment), into: self,
                                            length: fragment.text.utf16.count) == true {
                return
            }
            if Self.qaClipboard != nil { pasteLiteral(text) }
        }
        if Self.qaClipboard == nil { super.paste(sender) }
    }

    private func pasteLiteral(_ text: String) {
        (delegate as? RichBodyEditor.Coordinator)?
            .pasteClipboard(.replace(selectedRange(), with: text, style: .plain), into: self, length: text.utf16.count)
    }

    private static func foreignItem(from board: NSPasteboard) -> NSPasteboardItem? {
        guard let items = board.pasteboardItems, items.count == 1, let item = items.first,
              item.types.contains(.html) || item.types.contains(.rtf) else { return nil }
        return item
    }

    private static func foreignFragment(from item: NSPasteboardItem, plain: String?) -> RichBody? {
        ForeignRichPaste.fragment(plain: plain, html: item.data(forType: .html), rtf: item.data(forType: .rtf))
    }

    private func handleQAClipboardKey(_ event: NSEvent) -> Bool {
        guard Self.qaClipboard != nil, window?.firstResponder === self else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
        if modifiers == [.command, .shift, .option], event.charactersIgnoringModifiers?.lowercased() == "v" {
            pasteAsPlainText(nil)
            return true
        }
        guard modifiers == .command else { return false }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c": copy(nil)
        case "v": paste(nil)
        default: return false
        }
        return true
    }

    private func handleHistoryKey(_ event: NSEvent) -> Bool {
        guard window?.firstResponder === self, isEditable, !hasMarkedText(),
              event.charactersIgnoringModifiers?.lowercased() == "z" else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
        switch flags {
        case [.command]:
            if ownedUndo.canUndo { ownedUndo.undo() }
        case [.command, .shift]:
            if ownedUndo.canRedo { ownedUndo.redo() }
        default:
            return false
        }
        return true
    }
}

struct RichBodyEditor: NSViewRepresentable {
    @ObservedObject var controller: RichBodyController
    /// Owning task (or note) ID. The AppKit view is reused across selections,
    /// so the coordinator keys its committed state AND its undo stack on
    /// this: switching documents always invalidates, even for identical
    /// bodies. Pass the selected record's ID from every call site.
    var documentID: UUID
    var text: String
    var rich: RichBody?
    var disabled: Bool
    var onChange: (String, RichBody?) -> Void
    var onHeightChange: (CGFloat) -> Void
    var onFocusChange: (Bool) -> Void = { _ in }
    var descriptionSession: MacDescriptionSession? = nil
    var descriptionRevision: Int? = nil
    var readerHeadings: [RichDescriptionPreview.Heading] = []
    var onHeadingPositions: ([Int: CGFloat]) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextView {
        // Custom layout manager up front: rules draw as hairlines.
        let storage = NSTextStorage()
        let layout = RuleDrawingLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer()
        layout.addTextContainer(container)
        let view = RichBodyTextView(frame: .zero, textContainer: container)
        view.isRichText = true
        view.importsGraphics = false
        view.allowsUndo = true
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.textContainerInset = NSSize(width: 0, height: 4)
        view.drawsBackground = false
        view.font = RichRender.baseFont
        view.typingAttributes = RichRender.baseAttributes
        view.delegate = context.coordinator
        view.isAutomaticQuoteSubstitutionEnabled = false
        context.coordinator.host = self
        context.coordinator.configure(view)
        controller.textView = view
        return view
    }

    static func dismantleNSView(_ view: NSTextView, coordinator: Coordinator) {
        coordinator.captureBeforeDetach(view)
        // The old document owns any remaining input-method context. Never let
        // it deliver into a later document's text storage.
        coordinator.endOldComposition(view)
        view.delegate = nil
        DescriptionEditorLifecycle.unregister(coordinator.editorID)
    }
    func updateNSView(_ view: NSTextView, context: Context) {
        if context.coordinator.committedDocumentID != nil && context.coordinator.committedDocumentID != documentID {
            context.coordinator.captureBeforeDetach(view)
            context.coordinator.endOldComposition(view)
        }
        context.coordinator.host = self
        controller.textView = view
        view.isEditable = !disabled && descriptionSession?.conflict(taskID: documentID, editorID: context.coordinator.editorID) == nil
        view.isSelectable = true
        context.coordinator.reloadIfNeeded(view)
        // Pane resize / drawer-vs-main reuse with unchanged text: the frame
        // notification usually covers it, but re-check here so a width change
        // can never leave a stale height. Publishing stays async, so this is
        // safe inside the update pass.
        let width = view.bounds.width
        if width > 0, abs(width - context.coordinator.lastWidth) > 0.5 {
            context.coordinator.reportHeight(view)
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var host: RichBodyEditor
        let editorID = UUID()
        private var acceptedRevision: Int?
        private weak var liveView: NSTextView?
        /// Document the storage was last built for. The view is reused
        /// across selections: switching documents always invalidates, even
        /// when text and styles match.
        var committedDocumentID: UUID?
        /// Last model text committed out (or rendered in); typing that matches
        /// it never triggers a storage rebuild, so the caret never jumps.
        var committedText: String?
        var committedRich: RichBody?
        /// True while applying a programmatic storage rebuild; delegate
        /// callbacks during it must not echo back into the model.
        var applying = false
        private var slashSelection: RichSlashFormat?
        private var markdownArm: RichMarkdownTyping.ArmedParagraph?

        init(_ host: RichBodyEditor) {
            self.host = host
            committedDocumentID = host.documentID
            acceptedRevision = host.descriptionRevision
            committedText = host.text
            committedRich = host.rich
        }

        func configure(_ view: NSTextView) {
            applying = true
            defer { applying = false }
            let storage = RichRender.attributedString(text: host.text, rich: host.rich)
            view.textStorage?.setAttributedString(storage)
            committedDocumentID = host.documentID
            acceptedRevision = host.descriptionRevision
            committedText = host.text
            committedRich = host.rich
            // Rewraps on window/pane resizes change content height; the view
            // width tracks its container, so frame changes re-measure.
            view.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(frameChanged(_:)),
                name: NSView.frameDidChangeNotification, object: view)
            reportHeight(view)
            updateToolbarState(view)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func captureBeforeDetach(_ view: NSTextView) {
            guard let session = host.descriptionSession, let id = committedDocumentID else { return }
            if view.hasMarkedText() || session.conflict(taskID: id, editorID: editorID) != nil {
                let value = RichRender.extract(from: view)
                if let content = DescriptionSnapshot(body: value.text, rich: value.rich) ?? DescriptionSnapshot(body: value.text, rich: nil) {
                    session.retainUncommitted(taskID: id, editorID: editorID, content: content)
                }
            } else if session.hasComposition(editorID: editorID) { commit(view) }
        }
        func endOldComposition(_ view: NSTextView) {
            guard host.descriptionSession != nil, view.hasMarkedText() else { return }
            applying = true
            view.inputContext?.discardMarkedText()
            view.unmarkText()
            applying = false
        }
        private func captureComposition(_ view: NSTextView) {
            guard let session = host.descriptionSession, let id = committedDocumentID else { return }
            let value = RichRender.extract(from: view)
            session.trackComposition(taskID: id, editorID: editorID,
                content: DescriptionSnapshot(body: value.text, rich: value.rich) ?? DescriptionSnapshot(body: value.text, rich: nil))
        }
        func reloadIfNeeded(_ view: NSTextView) {
            liveView = view
            if host.descriptionSession != nil {
                DescriptionEditorLifecycle.register(editorID) { [weak self, weak view] in
                    guard let self, let view else { return }
                    if view.hasMarkedText() { self.captureComposition(view) }
                    else if self.host.descriptionSession?.hasComposition(editorID: self.editorID) == true { self.commit(view) }
                }
            }
            if committedDocumentID == host.documentID {
                if view.hasMarkedText() { captureComposition(view); return }
                if host.descriptionSession?.hasComposition(editorID: editorID) == true {
                    // Final delegate delivery can lag a SwiftUI refresh. Preserve
                    // the finished native text against its actual old revision.
                    commit(view); return
                }
                if host.descriptionSession?.conflict(taskID: host.documentID, editorID: editorID) != nil { return }
                if let acceptedRevision, let incoming = host.descriptionRevision, incoming < acceptedRevision { return }
            }

            // Document-scoped invalidation (see EditorDocumentGate): a new
            // document always rebuilds and drops the undo stack, even when
            // text and styles match — otherwise B inherits A's history and
            // undo resurrects A's text into B. The same document rebuilds
            // only when the model moved underneath the view (template apply,
            // external fill) or the view drifted; otherwise the storage is
            // left alone so the caret never jumps while typing.
            let reset = EditorDocumentGate.shouldReset(
                lastDocumentID: committedDocumentID, lastBody: committedText, lastRich: committedRich,
                documentID: host.documentID, body: host.text, rich: host.rich)
            if !reset,
               let committedText, RichBody.sameCodeUnits(committedText, host.text),
               committedRich == host.rich, RichBody.sameCodeUnits(view.string, host.text) {
                acceptedRevision = host.descriptionRevision
                return
            }
            let selection = view.selectedRange()
            markdownArm = nil
            applying = true
            let storage = RichRender.attributedString(text: host.text, rich: host.rich)
            view.textStorage?.setAttributedString(storage)
            // The view owns its UndoManager, so clearing here drops only
            // this editor's history — the title field and other views keep
            // theirs. Undo must never resurrect a replaced body or another
            // document's text into this one.
            view.undoManager?.removeAllActions()
            applying = false
            if reset {
                // New document: the live typing (and any pending list arm)
                // belongs to the previous document — drop it before seeding
                // from the fresh storage, or the old trailing style leaks in.
                view.typingAttributes = RichRender.baseAttributes
                host.controller.pendingListArm = nil
            }
            let length = (host.text as NSString).length
            if length == 0 {
                view.setSelectedRange(NSRange(location: 0, length: 0))
            } else {
                let clamped = NSRange(
                    location: min(max(0, selection.location), length),
                    length: min(max(0, selection.length), length - min(max(0, selection.location), length)))
                view.setSelectedRange(clamped)
            }
            view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
            // Rebuilds replace storage wholesale; re-arm continuation from
            // the fresh paragraph (same-document rebuilds preserve typing
            // continuity, new documents were cleared above).
            host.controller.repairContinuation(beforeTyping: nil)
            committedDocumentID = host.documentID
            acceptedRevision = host.descriptionRevision
            committedText = host.text
            committedRich = host.rich
            reportHeight(view)
            updateToolbarState(view)
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            (view as? RichBodyTextView)?.undoManager
        }

        func textDidChange(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView else { return }
            if host.descriptionSession != nil && view.hasMarkedText() { captureComposition(view); return }
            host.controller.applyPendingListArm(view)
            commit(view)
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard !applying, notification.object is NSTextView else { return }
            host.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView else { return }
            if host.descriptionSession?.hasComposition(editorID: editorID) == true { commit(view) }
            host.onFocusChange(false)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView else { return }
            if host.descriptionSession != nil && view.hasMarkedText() { captureComposition(view); return }
            if let arm = markdownArm, arm.caret != view.selectedRange() { markdownArm = nil }
            // The assignment below strips AppKit-derived textLists from
            // typing, dropping list continuation the native Return just
            // derived. Repair re-arms exactly what was lost (never invents:
            // exited/cleared typing has no lists to lose).
            let beforeTyping = view.typingAttributes
            view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
            host.controller.repairContinuation(beforeTyping: beforeTyping)
            updateToolbarState(view)
        }

        func toggleChecklistMarker(_ paragraph: NSRange, checked: Bool) {
            host.controller.toggleChecklistMarker(paragraph, checked: checked)
        }

        @discardableResult
        func pasteClipboard(_ command: RichBodyEdit, into view: NSTextView, length: Int) -> Bool {
            guard !applying, view.isEditable, !view.hasMarkedText() else { return false }
            markdownArm = nil
            let original = RichRender.extract(from: view)
            guard let body = try? RichBodyEdit.applying([command], to: original.text, rich: original.rich) else { return false }
            let caret = view.selectedRange().location + length
            host.controller.replaceEditorBody(body, caret: caret, label: "Paste Description")
            return true
        }

        // The key reaches this path before AppKit inserts a character. A
        // formatting choice uses the toolbar's edit and undo transaction. If
        // dismissed, AppKit gets the original key and inserts the literal slash.
        func showSlashMenu(in view: NSTextView) -> Bool {
            guard !applying, view.isEditable, !view.hasMarkedText(), let window = view.window,
                  window.firstResponder === view else { return false }
            let selection = view.selectedRange()
            let text = view.string as NSString
            guard selection.length == 0, selection.location <= text.length else { return false }
            if selection.location > 0 {
                guard let previous = UnicodeScalar(text.character(at: selection.location - 1)),
                      CharacterSet.whitespacesAndNewlines.contains(previous) else { return false }
            }
            let document = host.documentID
            let menu = NSMenu(title: "Format description")
            menu.autoenablesItems = false
            for (index, group) in RichSlashFormat.groups.enumerated() {
                if index > 0 { menu.addItem(.separator()) }
                for format in group {
                    let item = NSMenuItem(title: format.title, action: #selector(chooseSlashFormat(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = format
                    menu.addItem(item)
                }
            }
            let caret = view.firstRect(forCharacterRange: selection, actualRange: nil)
            let anchor = caret.height > 0
                ? view.convert(window.convertPoint(fromScreen: caret.origin), from: nil)
                : CGPoint(x: view.textContainerInset.width, y: view.textContainerInset.height + 16)
            slashSelection = nil
            menu.popUp(positioning: nil, at: anchor, in: view)
            let format = slashSelection
            slashSelection = nil
            guard host.documentID == document, view.window === window, window.firstResponder === view,
                  view.isEditable, !view.hasMarkedText(), view.selectedRange() == selection else { return true }
            guard let format else { return false }
            format.apply(to: host.controller)
            return true
        }

        @objc private func chooseSlashFormat(_ item: NSMenuItem) {
            slashSelection = item.representedObject as? RichSlashFormat
        }

        func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
            guard !applying, affectedRanges.count == 1, let range = affectedRanges.first?.rangeValue,
                  let replacementStrings, replacementStrings.count == 1, let text = replacementStrings.first else { return true }
            if let view = textView as? RichBodyTextView, view.handlingTextKey, !view.hasMarkedText(),
               view.selectedRanges.count == 1, range == view.selectedRange(), range.length == 0, text.count == 1,
               applyMarkdown(text, at: range, in: view) { return false }
            markdownArm = nil
            guard text == "\n" else { return true }
            // Return in an empty list item, heading, or quote exits the block
            // instead of inserting a newline. Shared with the command path
            // below so real key dispatch and programmatic "\n" agree.
            return !host.controller.handleReturn()
        }

        private func applyMarkdown(_ text: String, at range: NSRange, in view: NSTextView) -> Bool {
            let remaining = (view.textStorage?.length ?? 0) - range.location
            let mayFillList = (1...2).contains(remaining) &&
                (view.textStorage?.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.textLists.first != nil
            guard markdownArm != nil || text == " " || text == "-" || text == "\n" || mayFillList else { return false }
            let original = RichRender.extract(from: view)
            let prior = original.rich ?? RichBody(text: original.text)
            let markdown = markdownArm?.inserting(text, at: range, in: prior)
                ?? RichMarkdownTyping.change(for: text, at: range, in: prior)
            let list = markdown == nil ? RichMarkdownTyping.listContinuation(for: text, at: range, in: prior) : nil
            guard let change = markdown ?? list,
                  let body = try? RichBodyEdit.applying([change.edit], to: prior.text, rich: prior) else { return false }
            host.controller.replaceEditorBody(body, caret: change.caret.location,
                                              label: list == nil ? "Format Markdown" : "Continue List",
                                              undoSelection: true, storedListChange: list != nil)
            markdownArm = change.armedParagraph
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // The actual Return key dispatches as insertNewline:, which may
            // never reach shouldChangeTextInRanges — intercept the command
            // itself with the same shared policy.
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let view = textView as? RichBodyTextView, view.handlingTextKey, !view.hasMarkedText(),
                   view.selectedRanges.count == 1, view.selectedRange().length == 0,
                   applyMarkdown("\n", at: view.selectedRange(), in: view) { return true }
                markdownArm = nil
                return host.controller.handleReturn()
            }
            return false
        }

        func commit(_ view: NSTextView) {
            if host.descriptionSession != nil && view.hasMarkedText() { captureComposition(view); return }

            // Strip stale block markers (an exited block whose key outlived
            // its style through a replacement path) before extraction, so
            // the model, the toolbar, and later reads agree. Attribute-only
            // edits never move the caret; `applying` swallows the nested
            // notification so this terminates in one extra pass with no
            // duplicate save (updateBody skips unchanged body+rich).
            if let storage = view.textStorage {
                let stale = RichMutate.staleBlockRanges(in: storage)
                if !stale.isEmpty {
                    let beforeTyping = view.typingAttributes
                    applying = true
                    for range in stale {
                        storage.removeAttribute(RichRender.headingKey, range: range)
                        storage.removeAttribute(RichRender.quoteKey, range: range)
                    }
                    applying = false
                    if view.selectedRange().length == 0 {
                        view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
                        host.controller.repairContinuation(beforeTyping: beforeTyping)
                    }
                }
            }
            if let storage = view.textStorage {
                // Recompute after typing, formatting and Undo/Redo, not in
                // TextKit's layout callback. Keep the current typing arm.
                let typing = view.typingAttributes
                applying = true
                let changed = ListDecoration.normalizeNumberedGutters(in: storage)
                applying = false
                if changed {
                    view.typingAttributes = typing
                    host.controller.repairContinuation(beforeTyping: typing)
                }
            }
            let extracted = RichRender.extract(from: view)
            if let session = host.descriptionSession, let id = committedDocumentID {
                guard let content = DescriptionSnapshot(body: extracted.text, rich: extracted.rich), let revision = acceptedRevision else { return }
                session.trackComposition(taskID: id, editorID: editorID, content: nil)
                if let committedText, content == DescriptionSnapshot(body: committedText, rich: committedRich) { return }
                guard let next = session.propose(taskID: id, content: content, expectedRevision: revision, editorID: editorID) else {
                    session.retainUncommitted(taskID: id, editorID: editorID, content: content)
                    view.isEditable = false
                    return
                }
                acceptedRevision = next
            } else { host.onChange(extracted.text, extracted.rich) }
            committedText = extracted.text
            committedRich = extracted.rich
            reportHeight(view)
            updateToolbarState(view)
        }

        /// Last height reported to SwiftUI; repeats within half a point are
        /// swallowed so frame notifications never feed a layout loop.
        var lastHeight: CGFloat = 0

        /// Width the last report measured at; NaN until the view has a real
        /// frame. Width changes (task switch reuse, pane resize, drawer vs
        /// main) re-measure even when the text is unchanged.
        var lastWidth: CGFloat = .nan
        private var headingPositions: [Int: CGFloat] = [:]

        private func reportHeadingPositions(in view: NSTextView) {
            guard !host.readerHeadings.isEmpty, let layout = view.layoutManager, let container = view.textContainer else { return }
            layout.ensureLayout(for: container)
            var positions: [Int: CGFloat] = [:]
            let length = view.textStorage?.length ?? 0
            for heading in host.readerHeadings where heading.range.location < length {
                let glyph = layout.glyphIndexForCharacter(at: heading.range.location)
                let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                positions[heading.id] = line.minY + view.textContainerOrigin.y
            }
            guard headingPositions != positions else { return }
            headingPositions = positions
            DispatchQueue.main.async { [weak self] in
                guard let self, self.headingPositions == positions else { return }
                self.host.onHeadingPositions(positions)
            }
        }

        func reportHeight(_ view: NSTextView) {
            // Explicit-width measurement on a throwaway layout: at initial
            // load the view still has a zero frame (the live container has no
            // usable width yet, so its usedRect under-reports), and the live
            // layout may be mid-flight while typing. Unknown widths record
            // nothing, so the first real frame always publishes.
            var width = view.bounds.width
            if width <= 0, let containerWidth = view.textContainer?.size.width, containerWidth > 0 {
                width = containerWidth
            }
            guard width > 0, let storage = view.textStorage else { return }
            reportHeadingPositions(in: view)
            let height = RichEditorSizing.measuredHeight(
                for: storage, width: width,
                insetHeight: view.textContainerInset.height)
            guard abs(height - lastHeight) > 0.5 || abs(width - lastWidth) > 0.5 else { return }
            lastHeight = height
            lastWidth = width
            // Always async: makeNSView/updateNSView run inside SwiftUI's view
            // update pass, where a synchronous @State write is dropped (the
            // stuck-at-min-height bug: lastHeight latched, bodyHeight never
            // updated, later identical measurements swallowed). The captured
            // text guards against delivering a stale task's height.
            let text = storage.string
            let host = self.host
            DispatchQueue.main.async { [weak view] in
                guard let view, RichBody.sameCodeUnits(view.string, text) else { return }
                host.onHeightChange(height)
            }
        }

        @objc func frameChanged(_ note: Notification) {
            guard let view = note.object as? NSTextView else { return }
            reportHeight(view)
        }

        func updateToolbarState(_ view: NSTextView) {
            host.controller.active = host.controller.toolbarWithPending(for: view.selectedRange(), in: view)
        }
    }
}

private enum RichSlashFormat {
    case heading(Int)
    case quote, bullet, numbered, checklist, rule, codeBlock
    case bold, italic, underline, strikethrough, highlight, code

    static let groups: [[Self]] = [
        (1...6).map(Self.heading),
        [.quote, .bullet, .numbered, .checklist, .rule, .codeBlock],
        [.bold, .italic, .underline, .strikethrough, .highlight, .code]
    ]

    var title: String {
        switch self {
        case .heading(let level): "Heading \(level)"
        case .quote: "Quote"
        case .bullet: "Bulleted List"
        case .numbered: "Numbered List"
        case .checklist: "Checklist"
        case .rule: "Horizontal Rule"
        case .codeBlock: "Code Block"
        case .bold: "Bold"
        case .italic: "Italic"
        case .underline: "Underline"
        case .strikethrough: "Strikethrough"
        case .highlight: "Highlight"
        case .code: "Inline Code"
        }
    }

    func apply(to controller: RichBodyController) {
        switch self {
        case .heading(let level): controller.setHeading(level)
        case .quote: controller.toggleQuote()
        case .bullet: controller.toggleList(.bullet)
        case .numbered: controller.toggleList(.numbered)
        case .checklist: controller.toggleList(.checklist)
        case .rule: controller.insertRule()
        case .codeBlock: controller.toggleCodeBlock()
        case .bold: controller.toggleTrait(.boldFontMask)
        case .italic: controller.toggleTrait(.italicFontMask)
        case .underline: controller.toggleUnderline()
        case .strikethrough: controller.toggleStrikethrough()
        case .highlight: controller.toggleHighlight()
        case .code: controller.toggleCode()
        }
    }
}

/// Owns the text view for toolbar commands. Shared by the toolbar and the
/// editor so controls operate on the live selection and typing attributes.
@MainActor final class RichBodyController: ObservableObject {
    weak var textView: NSTextView?
    @Published var active = RichToolbarState()
    @Published var linkDraft = ""

    var hasTextView: Bool { textView != nil }

    /// Focuses the editor (the "Write something" placeholder action).
    func focus() {
        guard let view = textView else { return }
        view.window?.makeFirstResponder(view)
    }

    /// True when there is a live non-empty selection to restyle.
    private var hasRangedSelection: Bool {
        guard let view = textView else { return false }
        let selected = view.selectedRange()
        return selected.length > 0 && NSMaxRange(selected) <= (view.string as NSString).length
    }

    /// Inline toggles with a collapsed caret restyle nothing: they flip the
    /// typing attributes (with undo) so newly typed text inherits the style.
    /// Collapsed links are a no-op — there is no range to attach to.
    private func editInlineOrTyping(label: String, storageEdit: (NSTextStorage, NSRange) -> Void, typingEdit: (inout [NSAttributedString.Key: Any]) -> Void) {
        guard let view = textView, view.isEditable else { return }
        if hasRangedSelection {
            edit(label: label) { storage in storageEdit(storage, self.affectedRange()) }
            return
        }
        let before = view.typingAttributes
        let beforePending = pendingListArm
        view.undoManager?.beginUndoGrouping()
        view.undoManager?.setActionName(label)
        var attrs = before
        typingEdit(&attrs)
        attrs[.foregroundColor] = NSColor.labelColor
        view.typingAttributes = attrs
        if let undo = view.undoManager {
            let after = attrs
            let afterPending = pendingListArm
            undo.registerUndo(withTarget: self) { target in
                target.restoreTyping(snapshot: before, inverse: after, label: label, pending: beforePending, inversePending: afterPending)
            }
            undo.endUndoGrouping()
        }
        refreshState()
    }

    private func restoreTyping(snapshot: [NSAttributedString.Key: Any], inverse: [NSAttributedString.Key: Any], label: String, pending: PendingListArm? = nil, inversePending: PendingListArm? = nil) {
        guard let view = textView else { return }
        view.undoManager?.beginUndoGrouping()
        view.undoManager?.setActionName(label)
        pendingListArm = pending
        view.typingAttributes = snapshot
        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { target in
                target.restoreTyping(snapshot: inverse, inverse: snapshot, label: label, pending: inversePending, inversePending: pending)
            }
            undo.endUndoGrouping()
        }
        refreshState()
    }

    private func refreshState() {
        guard let view = textView else { return }
        active = toolbarWithPending(for: view.selectedRange(), in: view)
    }

    /// Toolbar state with the pending list arm reflected: assigned typing
    /// drops textLists (AppKit), so without this the list button would stay
    /// inactive after arming an empty document or trailing paragraph. Only
    /// applies to a collapsed caret in an arm context (empty document or
    /// trailing empty paragraph); anywhere else the arm is stale for the
    /// visible selection and storage decides.
    func toolbarWithPending(for selection: NSRange, in view: NSTextView) -> RichToolbarState {
        var state = RichRender.toolbarState(for: selection, in: view)
        if selection.length == 0, let arm = pendingListArm {
            let string = view.string as NSString
            if string.length == 0 || (selection.location >= string.length && string.hasSuffix("\n")) {
                state.bullet = arm.style == .bullet
                state.numbered = arm.style == .numbered
                state.checklist = arm.style == .checklist
                state.checklistChecked = arm.style == .checklist && arm.checked
            }
        }
        return state
    }

    /// Typing attributes with list membership cleared, for disarming.
    private func clearedListTyping() -> [NSAttributedString.Key: Any] {
        var attrs = textView?.typingAttributes ?? RichRender.baseAttributes
        let cleared = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        cleared.textLists = []
        cleared.headIndent = 0
        cleared.firstLineHeadIndent = 0
        attrs[.paragraphStyle] = cleared
        return attrs
    }

    /// Applies a toolbar mutation with explicit undo. Full snapshots are used
    /// because bodies are small and attribute runs make range math fragile;
    /// each undo registers its own inverse so redo chains correctly.
    private func edit(label: String, undoSelection: Bool = false, storedListChange: Bool = false,
                      _ apply: (NSTextStorage) -> Void) {
        guard let view = textView, let storage = view.textStorage, view.isEditable else { return }
        let before = NSAttributedString(attributedString: storage)
        let beforeSelection = undoSelection ? view.selectedRange() : nil
        view.undoManager?.beginUndoGrouping()
        view.undoManager?.setActionName(label)
        apply(storage)
        let after = NSAttributedString(attributedString: storage)
        let afterSelection = undoSelection ? view.selectedRange() : nil
        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { target in
                target.restore(snapshot: before, inverse: after, label: label, selection: beforeSelection,
                               inverseSelection: afterSelection, storedListChange: storedListChange)
            }
            undo.endUndoGrouping()
        }
        // Continued typing inherits the style at the caret after every toggle.
        // The assignment strips AppKit-derived textLists; the caret
        // paragraph's stored style is authoritative here (the edit already
        // removed what the user removed), so re-arm from storage.
        refreshTyping(in: view, storedListChange: storedListChange)
        (view.delegate as? RichBodyEditor.Coordinator)?.commit(view)
    }

    func replaceEditorBody(_ body: RichBody, caret: Int, label: String, undoSelection: Bool = false,
                           storedListChange: Bool = false) {
        guard let view = textView, view.isEditable else { return }
        view.breakUndoCoalescing()
        edit(label: label, undoSelection: undoSelection, storedListChange: storedListChange) { storage in
            storage.setAttributedString(RichRender.attributedString(text: body.text, rich: body))
            view.setSelectedRange(NSRange(location: caret, length: 0))
            if body.hasCodeBlocks, caret == storage.length, !body.isInCodeParagraph(at: caret) {
                view.typingAttributes = RichRender.baseAttributes
            }
        }
    }

    func toggleCodeBlock() {
        guard let view = textView, view.isEditable, !view.hasMarkedText() else { return }
        let selection = view.selectedRange()
        let original = RichRender.extract(from: view)
        let body = original.rich ?? RichBody(text: original.text)
        guard let change = RichBodyEdit.togglingCodeBlock(in: body, selection: selection),
              let updated = try? RichBodyEdit.applying([change], to: body.text, rich: body) else { return }
        view.breakUndoCoalescing()
        edit(label: "Code Block", undoSelection: true) { storage in
            storage.setAttributedString(RichRender.attributedString(text: updated.text, rich: updated))
            view.setSelectedRange(selection)
        }
    }

    private func restore(snapshot: NSAttributedString, inverse: NSAttributedString, label: String,
                         selection: NSRange?, inverseSelection: NSRange?, storedListChange: Bool) {
        guard let view = textView, let storage = view.textStorage else { return }
        view.undoManager?.beginUndoGrouping()
        view.undoManager?.setActionName(label)
        storage.setAttributedString(snapshot)
        if let selection { view.setSelectedRange(selection) }
        clampSelection(view)
        let caret = view.selectedRange().location
        if storedListChange {
            refreshTyping(in: view, storedListChange: true)
        } else if view.typingAttributes[RichRender.codeBlockKey] != nil ||
                    (caret < storage.length && storage.attribute(RichRender.codeBlockKey, at: caret, effectiveRange: nil) != nil) {
            view.typingAttributes = RichRender.attributes(at: caret, in: view)
        }
        // Undo/redo swaps storage wholesale without touching typing; re-arm
        // from the restored paragraph so continuation survives the swap.
        if !storedListChange { repairContinuation(beforeTyping: nil) }
        if let undo = view.undoManager {
            undo.registerUndo(withTarget: self) { target in
                target.restore(snapshot: inverse, inverse: snapshot, label: label, selection: inverseSelection,
                               inverseSelection: selection, storedListChange: storedListChange)
            }
            undo.endUndoGrouping()
        }
        (view.delegate as? RichBodyEditor.Coordinator)?.commit(view)
    }

    private func refreshTyping(in view: NSTextView, storedListChange: Bool) {
        if storedListChange { pendingListArm = nil }
        if storedListChange && isCaretInTrailingEmptyParagraph {
            // Exiting the stored blank item leaves an unstyled caret at EOF.
            view.typingAttributes = RichRender.baseAttributes
        } else {
            view.typingAttributes = RichRender.attributes(at: view.selectedRange().location, in: view)
            repairContinuation(beforeTyping: nil)
        }
        refreshState()
    }

    /// Keeps the caret inside the storage after an undo swap changes length.
    private func clampSelection(_ view: NSTextView) {
        let length = (view.string as NSString).length
        let selected = view.selectedRange()
        guard NSMaxRange(selected) > length else { return }
        view.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))
    }

    func toggleTrait(_ trait: NSFontTraitMask) {
        editInlineOrTyping(
            label: trait == .boldFontMask ? "Bold" : "Italic",
            storageEdit: { storage, range in RichMutate.toggleTrait(trait, in: storage, range: range) },
            typingEdit: { attrs in
                if trait == .boldFontMask {
                    RichTyping.toggleBold(in: &attrs)
                    return
                }
                let font = (attrs[.font] as? NSFont) ?? RichRender.baseFont
                let has = RichRender.traits(of: font).contains(trait)
                attrs[.font] = has
                    ? NSFontManager.shared.convert(font, toNotHaveTrait: trait)
                    : NSFontManager.shared.convert(font, toHaveTrait: trait)
            })
    }

    func toggleUnderline() {
        editInlineOrTyping(
            label: "Underline",
            storageEdit: { storage, range in RichMutate.toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, in: storage, range: range) },
            typingEdit: { attrs in RichTyping.toggleFlag(.underlineStyle, value: NSUnderlineStyle.single.rawValue, in: &attrs) })
    }

    func toggleStrikethrough() {
        editInlineOrTyping(
            label: "Strikethrough",
            storageEdit: { storage, range in RichMutate.toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, in: storage, range: range) },
            typingEdit: { attrs in RichTyping.toggleFlag(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, in: &attrs) })
    }

    func toggleHighlight() {
        editInlineOrTyping(
            label: "Highlight",
            storageEdit: { storage, range in RichMutate.toggleHighlight(in: storage, range: range) },
            typingEdit: { attrs in RichTyping.toggleHighlight(in: &attrs) })
    }

    func setHighlight(_ color: RichHighlightColor?) {
        editInlineOrTyping(
            label: color.map { "Highlight \($0.title)" } ?? "Remove Highlight",
            storageEdit: { storage, range in RichMutate.setHighlight(color, in: storage, range: range) },
            typingEdit: { attrs in RichTyping.setHighlight(color, in: &attrs) })
    }

    func toggleCode() {
        editInlineOrTyping(
            label: "Code",
            storageEdit: { storage, range in RichMutate.toggleCode(in: storage, range: range) },
            typingEdit: { attrs in RichTyping.toggleCode(in: &attrs) })
    }

    func setHeading(_ level: Int?) {
        // Choosing a heading is a different block: it displaces a pending
        // list arm (with undo). Removing the heading leaves the arm alone.
        if armEmptyDocumentForBlock(font: level.map(RichRender.headingFont) ?? RichRender.baseFont,
                                    markers: level.map { [RichRender.headingKey: $0] } ?? [:],
                                    label: "Heading", pending: level != nil ? .some(nil) : nil) { return }
        if isCaretInTrailingEmptyParagraph {
            // No characters to restyle: arm the typing attributes so the
            // next typed text carries (or drops) the heading, mirroring
            // RichMutate.setHeading's per-run font semantics on one font.
            var attrs = textView?.typingAttributes ?? RichRender.baseAttributes
            let current = attrs[.font] as? NSFont ?? RichRender.baseFont
            let italic = RichRender.traits(of: current).contains(.italicFontMask)
            if let level {
                var font = RichRender.headingFont(level)
                if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
                if (attrs[RichRender.codeKey] as? Bool) == true { font = RichRender.codeFont(from: font) }
                attrs[.font] = font
                attrs[RichRender.headingKey] = level
                setTyping(attrs, label: "Heading", pending: .some(nil))
            } else {
                var font = RichRender.baseFont
                if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
                if (attrs[RichRender.boldKey] as? Bool) == true { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
                if (attrs[RichRender.codeKey] as? Bool) == true { font = RichRender.codeFont(from: font) }
                attrs[.font] = font
                attrs.removeValue(forKey: RichRender.headingKey)
                setTyping(attrs, label: "Heading")
            }
            return
        }
        edit(label: "Heading") { storage in
            RichMutate.setHeading(level, in: storage, range: self.paragraphRange())
        }
    }

    func toggleQuote() {
        // A second tap while quote is armed in an empty document disarms
        // (a tap must toggle off, not re-arm) — mirroring the list and
        // checklist toggle. Unrelated inline formatting survives; the
        // pending-list displacement rides the same undo group.
        if ((textView?.string ?? "") as NSString).length == 0,
           RichTyping.isQuoteArmed(in: textView?.typingAttributes ?? [:]) {
            setTyping(RichTyping.disarmedQuoteAttributes(from: textView?.typingAttributes ?? RichRender.baseAttributes),
                      label: "Quote", pending: .some(nil))
            return
        }
        // Choosing a quote is a different block: it displaces a pending
        // list arm (with undo).
        if armEmptyDocumentForBlock(font: nil,
                                    markers: [RichRender.quoteKey: true],
                                    label: "Quote",
                                    paragraph: { $0.headIndent = RichTyping.quoteIndent; $0.firstLineHeadIndent = RichTyping.quoteIndent },
                                    pending: .some(nil)) { return }
        if isCaretInTrailingEmptyParagraph {
            // Toggle the typing attributes: the trailing paragraph has no
            // characters, so quoting arms (or disarms) future text. Shared
            // transforms keep the constants identical to the empty-document
            // path above.
            let attrs = textView?.typingAttributes ?? RichRender.baseAttributes
            if RichTyping.isQuoteArmed(in: attrs) {
                setTyping(RichTyping.disarmedQuoteAttributes(from: attrs), label: "Quote")
            } else {
                setTyping(RichTyping.armedQuoteAttributes(from: attrs), label: "Quote", pending: .some(nil))
            }
            return
        }
        edit(label: "Quote") { storage in
            RichMutate.toggleQuote(in: storage, range: self.paragraphRange())
        }
    }

    func toggleList(_ style: RichListStyle) {
        let label = style == .bullet ? "Bulleted List" : "Numbered List"
        // Tapping the active list in an empty document disarms (a second tap
        // must toggle off, not re-arm).
        if ((textView?.string ?? "") as NSString).length == 0, pendingListArm?.style == style {
            setTyping(clearedListTyping(), label: label, pending: .some(nil))
            return
        }
        if armEmptyDocumentForBlock(font: nil,
                                    markers: [:],
                                    label: label,
                                    paragraph: {
                                        $0.textLists = [RichRender.textList(for: style)]
                                        $0.headIndent = 24; $0.firstLineHeadIndent = 0
                                    },
                                    // Assigned typing drops textLists (AppKit):
                                    // record the arm so the first input still
                                    // opens the list; refreshState inside the
                                    // arm already reflects it in the toolbar.
                                    pending: .some(PendingListArm(style: style, checked: false))) { return }
        if isCaretInTrailingEmptyParagraph {
            // Toggle the typing attributes with the same constants the
            // empty-document arm uses, so the next typed text continues or
            // leaves the list. Assigned textLists do not survive (AppKit),
            // so arming also records a pending style applied on next input.
            var attrs = textView?.typingAttributes ?? RichRender.baseAttributes
            let listStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            let current = RichRender.listStyle(for: listStyle.textLists.first?.markerFormat)?.0
            if current == style || pendingListArm?.style == style {
                listStyle.textLists = []
                listStyle.headIndent = 0
                listStyle.firstLineHeadIndent = 0
                attrs[.paragraphStyle] = listStyle
                setTyping(attrs, label: label, pending: .some(nil))
            } else {
                listStyle.textLists = [RichRender.textList(for: style)]
                listStyle.headIndent = 24
                listStyle.firstLineHeadIndent = 0
                attrs[.paragraphStyle] = listStyle
                setTyping(attrs, label: label, pending: .some(PendingListArm(style: style, checked: false)))
            }
            return
        }
        edit(label: style == .bullet ? "Bulleted List" : "Numbered List") { storage in
            RichMutate.toggleList(style, in: storage, range: self.paragraphRange())
        }
    }

    /// Inserts a horizontal rule as its own paragraph and leaves the caret in
    /// a fresh paragraph after it with clean typing attributes.
    func insertRule() {
        guard let view = textView, view.isEditable else { return }
        let at = min(max(0, view.selectedRange().location), (view.string as NSString).length)
        edit(label: "Horizontal Rule") { storage in
            if let caret = RichMutate.insertHorizontalRule(in: storage, at: at) {
                view.setSelectedRange(NSRange(location: caret, length: 0))
            }
        }
        view.typingAttributes = RichRender.baseAttributes
        refreshState()
    }

    /// Pending list style for a paragraph with no characters to restyle (an
    /// armed empty document, or the trailing empty paragraph): AppKit strips
    /// `textLists` from *assigned* typing attributes, so the style is
    /// recorded here and applied to the paragraph once text arrives (see
    /// `applyPendingListArm`). Typing-derived continuation (a real newline
    /// insertion) keeps its lists, so this only covers the assign path.
    /// Document-scoped: cleared on document switch, on apply, on toggle-off,
    /// on Clear Formatting, on choosing a different block, and on any Return
    /// (a newline abandons the arm). Undo snapshots capture it alongside the
    /// typing attributes so undoing an arm leaves no ghost.
    struct PendingListArm: Equatable {
        var style: RichListStyle
        var checked: Bool
    }
    var pendingListArm: PendingListArm?

    /// Shared Return-key policy for the command (`insertNewline:`) and
    /// text-change (`shouldChangeTextInRanges` "\n") dispatch paths. True
    /// consumes the newline: an empty list item, heading, or quote exits the
    /// block instead. False lets the newline through (plain paragraphs, rule
    /// lines, ranged selections).
    func handleReturn() -> Bool {
        guard let view = textView, view.isEditable,
              let storage = view.textStorage else { return false }
        let selected = view.selectedRange()
        guard selected.length == 0 else { return false }
        // A rule marker must never propagate onto the new paragraph: the
        // newline always starts clean, so splitting a rule line leaves a
        // fresh paragraph after it.
        if view.typingAttributes[RichRender.ruleKey] != nil {
            var typing = view.typingAttributes
            typing.removeValue(forKey: RichRender.ruleKey)
            view.typingAttributes = typing
        }
        // Decide first so plain newlines never open an undo group or commit:
        // `exitEmptyBlock` stays authoritative for the storage mutation.
        // The pending arm counts as armed even though assigned typing drops
        // textLists, so an armed empty editor still exits on Return.
        let decision = RichMutate.returnExit(in: storage, range: selected, typingAttributes: view.typingAttributes, pending: pendingListArm?.style)
        switch decision {
        case .insertNewline:
            // A newline abandons a pending arm: it styles next text.
            pendingListArm = nil
            return false
        case .exitBlock:
            pendingListArm = nil
            var consumed = false
            edit(label: "Exit Block") { storage in
                consumed = RichMutate.exitEmptyBlock(in: storage, range: selected)
            }
            return consumed
        case .exitTrailingBlock:
            // The trailing empty paragraph (or an armed empty document) has
            // no characters to mutate and the preceding block keeps its
            // style; only the typing attributes reset so continued text is
            // plain. The pending clear rides the same undo group, so undoing
            // the exit restores the arm instead of leaving a ghost.
            setTyping(RichTyping.exitedBlockAttributes(from: view.typingAttributes), label: "Exit Block", pending: .some(nil))
            return true
        }
    }

    /// Collapsed caret in the trailing empty paragraph (EOF past a final
    /// newline, non-empty body). Its block style lives in the typing
    /// attributes — storage has no characters to restyle.
    var isCaretInTrailingEmptyParagraph: Bool {
        guard let view = textView else { return false }
        let selected = view.selectedRange()
        guard selected.length == 0 else { return false }
        let string = view.string as NSString
        return string.length > 0 && selected.location >= string.length && string.hasSuffix("\n")
    }

    /// Assigns typing attributes with undo, mirroring the toolbar's typing
    /// edits. Document-scoped: the view owns its UndoManager.
    /// `pending` tri-state: nil leaves the pending list arm alone,
    /// `.some(arm)` records it (nil clears) — captured in the same undo
    /// group as the typing so undoing an arm leaves no ghost.
    func setTyping(_ attrs: [NSAttributedString.Key: Any], label: String, pending: PendingListArm?? = nil) {
        guard let view = textView, view.isEditable else { return }
        let before = view.typingAttributes
        let beforePending = pendingListArm
        view.undoManager?.beginUndoGrouping()
        view.undoManager?.setActionName(label)
        if let pending { pendingListArm = pending }
        var attrs = attrs
        attrs[.foregroundColor] = NSColor.labelColor
        view.typingAttributes = attrs
        if let undo = view.undoManager {
            let after = attrs
            let afterPending = pendingListArm
            undo.registerUndo(withTarget: self) { target in
                target.restoreTyping(snapshot: before, inverse: after, label: label, pending: beforePending, inversePending: afterPending)
            }
            undo.endUndoGrouping()
        }
        refreshState()
    }

    /// Re-arms list continuation after a typing assignment that may have
    /// stripped AppKit-derived textLists. Pass the typing from before the
    /// assignment to repair only what it destroyed (selection and rebuild
    /// refreshes); pass nil for storage edits, where the caret paragraph's
    /// stored style is authoritative (toggle paths). Never invents: exited,
    /// cleared, and explicitly chosen styles carry no lists to lose, and the
    /// post-exit typing they leave behind is list-free by construction.
    func repairContinuation(beforeTyping: [NSAttributedString.Key: Any]?) {
        guard pendingListArm == nil, let view = textView, let storage = view.textStorage else { return }
        if let repaired = RichMutate.continuationList(beforeTyping: beforeTyping, typingAttributes: view.typingAttributes, storage: storage, selection: view.selectedRange()) {
            pendingListArm = PendingListArm(style: repaired.style, checked: repaired.checked)
        }
    }

    /// Applies a pending list arm once text arrives (called on the text-input
    /// path before commit, so the model includes the style). The arm targets
    /// the paragraph holding the caret; when that paragraph already carries
    /// the style there is nothing to do. Undo stays two-step (the input, then
    /// the style) because the input's undo group already closed.
    func applyPendingListArm(_ view: NSTextView) {
        guard let arm = pendingListArm, view.isEditable,
              let storage = view.textStorage, storage.length > 0 else { return }
        let selected = view.selectedRange()
        guard selected.length == 0,
              let para = RichMutate.pendingListTarget(in: storage, caret: selected.location, style: arm.style) else { return }
        pendingListArm = nil
        edit(label: arm.style == .bullet ? "Bulleted List" : "Numbered List") { storage in
            RichMutate.setList(arm.style, checked: arm.style == .checklist ? arm.checked : nil, in: storage, range: para)
        }
    }

    /// Empty-document block start: with no storage to style, the toolbar arms
    /// the typing attributes instead, so the first typed characters open the
    /// block. Returns true when it handled the tap (with undo).
    private func armEmptyDocumentForBlock(font: NSFont?, markers: [NSAttributedString.Key: Any], label: String, paragraph: ((NSMutableParagraphStyle) -> Void)? = nil, pending: PendingListArm?? = nil) -> Bool {
        guard let view = textView, view.isEditable,
              (view.string as NSString).length == 0 else { return false }
        let before = view.typingAttributes
        let beforePending = pendingListArm
        view.undoManager?.beginUndoGrouping()
        view.undoManager?.setActionName(label)
        if let pending { pendingListArm = pending }
        var attrs = before
        if let font { attrs[.font] = font }
        for (key, value) in markers { attrs[key] = value }
        if paragraph != nil || font != nil || !markers.isEmpty {
            let style = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            paragraph?(style)
            attrs[.paragraphStyle] = style
        }
        attrs[.foregroundColor] = NSColor.labelColor
        view.typingAttributes = attrs
        if let undo = view.undoManager {
            let after = attrs
            let afterPending = pendingListArm
            undo.registerUndo(withTarget: self) { target in
                target.restoreTyping(snapshot: before, inverse: after, label: label, pending: beforePending, inversePending: afterPending)
            }
            undo.endUndoGrouping()
        }
        refreshState()
        return true
    }

    func toggleChecklistMarker(_ paragraph: NSRange, checked: Bool) {
        textView?.breakUndoCoalescing()
        edit(label: checked ? "Check Item" : "Uncheck Item") { storage in
            RichMutate.setChecklistChecked(checked, in: storage, paragraph: paragraph)
        }
    }

    /// Inline checklist checked state. Explicit values always apply (marking
    /// already-checked items checked again is a no-op, never a removal).
    /// With no characters to restyle (empty document, trailing empty
    /// paragraph) the checked state arms pending instead, applied to the
    /// paragraph on first input — assigned typing cannot hold the box.
    func setChecklist(_ checked: Bool) {
        let label = checked ? "Check Items" : "Uncheck Items"
        let arm = PendingListArm(style: .checklist, checked: checked)
        if ((textView?.string ?? "") as NSString).length == 0 {
            if pendingListArm == arm {
                setTyping(clearedListTyping(), label: label, pending: .some(nil))
                return
            }
            if armEmptyDocumentForBlock(font: nil, markers: [:], label: label, paragraph: {
                $0.textLists = [RichRender.textList(for: .checklist)]
                $0.headIndent = 24; $0.firstLineHeadIndent = 0
            }, pending: .some(arm)) { return }
        }
        if isCaretInTrailingEmptyParagraph {
            var attrs = textView?.typingAttributes ?? RichRender.baseAttributes
            let listStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            if pendingListArm == arm {
                listStyle.textLists = []
                listStyle.headIndent = 0
                listStyle.firstLineHeadIndent = 0
                attrs[.paragraphStyle] = listStyle
                setTyping(attrs, label: label, pending: .some(nil))
            } else {
                listStyle.textLists = [RichRender.textList(for: .checklist)]
                listStyle.headIndent = 24
                listStyle.firstLineHeadIndent = 0
                attrs[.paragraphStyle] = listStyle
                setTyping(attrs, label: label, pending: .some(arm))
            }
            return
        }
        edit(label: label) { storage in
            RichMutate.setList(.checklist, checked: checked, in: storage, range: self.paragraphRange())
        }
    }

    func applyLink(_ urlString: String) {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, hasRangedSelection else { return }
        edit(label: "Link") { storage in
            RichMutate.setLink(cleaned, in: storage, range: self.affectedRange())
        }
    }

    func removeLink() {
        guard hasRangedSelection else { return }
        edit(label: "Remove Link") { storage in
            RichMutate.removeLink(in: storage, range: self.affectedRange())
        }
    }

    func clearFormatting() {
        // A collapsed caret clears typing (with undo); the pending arm must
        // go in the same group so undo restores the arm and redo clears it.
        // A ranged selection clears storage instead; the arm is abandoned.
        if !hasRangedSelection {
            setTyping(RichRender.baseAttributes, label: "Clear Formatting", pending: .some(nil))
            return
        }
        pendingListArm = nil
        editInlineOrTyping(
            label: "Clear Formatting",
            storageEdit: { storage, range in RichMutate.clearFormatting(in: storage, range: range) },
            typingEdit: { attrs in attrs = RichRender.baseAttributes })
    }

    private func affectedRange() -> NSRange {
        guard let view = textView else { return NSRange(location: 0, length: 0) }
        let selected = view.selectedRange()
        if selected.length > 0 { return selected }
        return NSRange(location: 0, length: (view.string as NSString).length)
    }

    private func paragraphRange() -> NSRange {
        guard let view = textView else { return NSRange(location: 0, length: 0) }
        // Shared production policy (tested): the exclusive range end never
        // pulls the next paragraph in when a selection ends after "\n".
        return RichMutate.blockRange(for: view.selectedRange(), in: view.string as NSString)
    }

}
/// The reader owns an independent, selectable projection of the saved body.
struct RichBodyReader: View {
    let documentID: UUID
    let preview: RichDescriptionPreview
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = RichBodyController()
    @State private var collapsed: Set<Int> = []
    @State private var positions: [Int: CGFloat] = [:]
    @State private var height: CGFloat = 60
    @State private var copiedCode: Int?

    var body: some View {
        let reading = preview.readingView(collapsed: collapsed)
        let code = reading.preview.codeBlocks
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Read Description").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if !code.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(code.enumerated()), id: \.element.id) { index, block in
                            Button(copiedCode == block.id ? "Copied" : code.count == 1 ? "Copy Code Block" : "Copy Code Block \(index + 1)", systemImage: "doc.on.doc") {
                                let board = RichBodyTextView.descriptionClipboard
                                board.clearContents()
                                if board.setString(block.text, forType: .string) { copiedCode = block.id }
                            }.accessibilityIdentifier("copyRichCodeBlock-\(index)")
                        }
                    }
                }
            }
            ScrollView {
                ZStack(alignment: .topLeading) {
                    RichBodyEditor(controller: controller, documentID: documentID, text: reading.preview.text,
                                   rich: reading.preview.displayRichBody, disabled: true, onChange: { _, _ in },
                                   onHeightChange: { height = $0 }, readerHeadings: reading.headings,
                                   onHeadingPositions: { positions = $0 })
                        .frame(height: max(60, height)).padding(.leading, 26)
                        .accessibilityLabel("Read-only description")
                    ForEach(reading.headings) { heading in
                        if let y = positions[heading.id] {
                            let folded = collapsed.contains(heading.id)
                            Button {
                                if folded { collapsed.remove(heading.id) } else { collapsed.insert(heading.id) }
                            } label: {
                                Image(systemName: folded ? "chevron.right" : "chevron.down")
                                    .font(.caption.weight(.semibold)).frame(width: 24, height: 22)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityLabel((folded ? "Expand " : "Collapse ") + heading.title)
                                .accessibilityIdentifier("richFoldHeading-" + String(heading.id))
                                .offset(y: y)
                        }
                    }
                }
            }
        }.padding(18).frame(width: 530, height: 430)
            .onChange(of: collapsed) { _, _ in copiedCode = nil }
    }
}

/// Inline formatting toolbar for the body editor. Every control operates on
/// the live selection (or typing attributes when collapsed); bold, italic,
/// and underline also answer to ⌘B/⌘I/⌘U with native undo behind each edit.
struct RichBodyToolbar: View {
    @ObservedObject var controller: RichBodyController
    var disabled: Bool
    @State private var showLink = false

    var body: some View {
        // Horizontal scroll keeps every tool reachable in narrow panes
        // (drawer, pop-up) instead of clipping trailing controls.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                toolButton(symbol: "bold", label: "Bold (⌘B)", active: controller.active.bold) {
                    controller.toggleTrait(.boldFontMask)
                }.keyboardShortcut("b", modifiers: .command)
            toolButton(symbol: "italic", label: "Italic (⌘I)", active: controller.active.italic) {
                controller.toggleTrait(.italicFontMask)
            }.keyboardShortcut("i", modifiers: .command)
            toolButton(symbol: "underline", label: "Underline (⌘U)", active: controller.active.underline) {
                controller.toggleUnderline()
            }.keyboardShortcut("u", modifiers: .command)
            toolButton(symbol: "strikethrough", label: "Strikethrough", active: controller.active.strikethrough) {
                controller.toggleStrikethrough()
            }
            Divider().frame(height: 16)
            Menu {
                Button("None") { controller.setHeading(nil) }
                ForEach(1...6, id: \.self) { level in Button("Heading \(level)") { controller.setHeading(level) } }
            } label: {
                Text(controller.active.heading.map { "H\($0)" } ?? "H")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 24)
                    .background(controller.active.heading != nil ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(controller.active.heading != nil ? Color.accentColor : Color.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Heading")
            .accessibilityLabel(controller.active.heading.map { "Heading \($0)" } ?? "Heading")
            .disabled(disabled)
            toolButton(symbol: "link", label: controller.active.link ?? "Add Link", active: controller.active.link != nil) {
                controller.linkDraft = controller.active.link ?? ""
                showLink = true
            }
            .popover(isPresented: $showLink, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Link").font(.headline)
                    TextField("https://…", text: $controller.linkDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    HStack {
                        if controller.active.link != nil {
                            Button("Remove") { controller.removeLink(); showLink = false }
                        }
                        Spacer()
                        Button("Cancel") { showLink = false }.keyboardShortcut(.cancelAction)
                        Button("Apply") { controller.applyLink(controller.linkDraft); showLink = false }
                            .keyboardShortcut(.defaultAction)
                            .disabled(controller.linkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(14).frame(width: 300)
            }
            toolButton(symbol: "highlighter", label: "Highlight", active: controller.active.highlight) {
                controller.toggleHighlight()
            }
            highlightPalette
            toolButton(symbol: "chevron.left.forwardslash.chevron.right", label: "Inline Code", active: controller.active.code) {
                controller.toggleCode()
            }
            toolButton(symbol: "curlybraces", label: "Code Block", active: false) { controller.toggleCodeBlock() }
            Divider().frame(height: 16)
            toolButton(symbol: "text.quote", label: "Block Quote", active: controller.active.quote) {
                controller.toggleQuote()
            }
            toolButton(symbol: "list.bullet", label: "Bulleted List", active: controller.active.bullet) {
                controller.toggleList(.bullet)
            }
            toolButton(symbol: "list.number", label: "Numbered List", active: controller.active.numbered) {
                controller.toggleList(.numbered)
            }
            Menu {
                Button("Checklist") { controller.toggleList(.checklist) }
                Divider()
                Button("Mark Checked") { controller.setChecklist(true) }
                Button("Mark Unchecked") { controller.setChecklist(false) }
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 24)
                    .background(controller.active.checklist ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(controller.active.checklist ? Color.accentColor : Color.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(controller.active.checklist ? (controller.active.checklistChecked ? "Checklist (checked)" : "Checklist (unchecked)") : "Checklist")
            .accessibilityLabel("Checklist")
            .disabled(disabled)
            toolButton(symbol: "eraser", label: "Clear Formatting", active: false) {
                controller.clearFormatting()
            }
            toolButton(symbol: "minus", label: "Insert Horizontal Rule", active: false) {
                controller.insertRule()
            }
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .padding(.vertical, 2)
        .accessibilityLabel("Text formatting")
    }

    private func toolButton(symbol: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 26, height: 24)
                .background(active ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .disabled(disabled)
    }

    private var highlightPalette: some View {
        Menu {
            ForEach(RichHighlightColor.allCases, id: \.self) { color in
                Button { controller.setHighlight(color) } label: {
                    Label(color.title, systemImage: "circle.fill")
                        .foregroundStyle(Color(nsColor: RichRender.highlightWash(for: color).withAlphaComponent(1)))
                }
            }
            Divider()
            Button("Remove Highlight") { controller.setHighlight(nil) }
        } label: {
            Label("Highlight Colors", systemImage: "chevron.down").labelStyle(.iconOnly)
                .font(.system(size: 9, weight: .semibold)).frame(width: 14, height: 24)
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Highlight Colors").accessibilityLabel("Highlight Colors").disabled(disabled)
    }
}
