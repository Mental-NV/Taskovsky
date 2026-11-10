import SwiftUI
import UIKit
import UniformTypeIdentifiers
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneRichFieldEditor: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let draftID: UUID
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: NSRange
    @State private var redo: [RichBodyEdit] = []
    @State private var linkRange: NSRange?
    @State private var link = ""
    @State private var showsLink = false

    init(model: PhoneWorkspaceModel, draftID: UUID, initialText: String) {
        self.model = model
        self.draftID = draftID
        _selection = State(initialValue: NSRange(location: initialText.utf16.count, length: 0))
    }

    private var state: RichFieldState? {
        guard model.activeDraft?.id == draftID else { return nil }
        return model.activeDraft?.richState
    }

    var body: some View {
        if let state {
            VStack(alignment: .leading, spacing: 12) {
                formattingToolbar(state)
                Text(model.recoveryStatus).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("draftRecoveryStatus")
                    .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                PhoneRichTextInput(content: state.content, selection: $selection,
                                   composing: Binding(get: { model.activeDraft?.id == draftID && model.isComposing },
                                                      set: { if model.activeDraft?.id == draftID { model.isComposing = $0 } }),
                                   editable: !model.isBusy,
                                   read: { self.state?.content }, apply: apply)
                    .frame(minHeight: 220, alignment: .topLeading)
            }
            .alert("Edit link", isPresented: $showsLink) {
                TextField("https://", text: $link).textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) {}
                Button("Apply") { if let linkRange { apply(.setLink(link, linkRange)) } }.disabled(link.isEmpty)
                Button("Remove Link", role: .destructive) { if let linkRange { apply(.setLink(nil, linkRange)) } }
            }
        }
    }

    private func formattingToolbar(_ state: RichFieldState) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                historyButtons(canUndo: !state.edits.isEmpty)
                formatMenus(hasText: !state.content.text.isEmpty)
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { historyButtons(canUndo: !state.edits.isEmpty) }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { formatMenus(hasText: !state.content.text.isEmpty) }
                        .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 8) { formatMenus(hasText: !state.content.text.isEmpty) }
                }
            }
        }
        .buttonStyle(.bordered)
        .disabled(model.isBusy || model.isComposing)
    }

    @ViewBuilder private func historyButtons(canUndo: Bool) -> some View {
        Button(action: undo) {
            Label("Undo", systemImage: "arrow.uturn.backward").labelStyle(.iconOnly)
                .frame(minWidth: 24, minHeight: 28)
        }.disabled(!canUndo).accessibilityIdentifier("richUndo")
        Button(action: redoEdit) {
            Label("Redo", systemImage: "arrow.uturn.forward").labelStyle(.iconOnly)
                .frame(minWidth: 24, minHeight: 28)
        }.disabled(redo.isEmpty).accessibilityIdentifier("richRedo")
    }

    @ViewBuilder private func formatMenus(hasText: Bool) -> some View {
        Menu("Paragraph", systemImage: "paragraphsign") {
            ForEach(1...6, id: \.self) { level in
                Button("Heading \(level)") { paragraph(.heading(level)) }
            }
            Button("Quote") { paragraph(.quote(true)) }
            Button("Bullet List") { paragraph(.list(.bullet)) }
            Button("Numbered List") { paragraph(.list(.numbered)) }
            Button("Checklist") { paragraph(.list(.checklist)) }
            Button("Check Item") { paragraph(.checklistChecked(true)) }
            Button("Uncheck Item") { paragraph(.checklistChecked(false)) }
            Button("Horizontal Rule") { paragraph(.horizontalRule(true)) }
            Button("Clear Paragraph Style") { paragraph(.clear) }
        }.disabled(!hasText).accessibilityIdentifier("richParagraphMenu")
        Menu("Inline", systemImage: "textformat") {
            ForEach(RichInlineFormat.allCases, id: \.self) { format in
                Button(format.rawValue.capitalized) { apply(.toggle(format, selection)) }
            }
            Button("Link", systemImage: "link") {
                linkRange = selection
                link = ""
                showsLink = true
            }
            Button("Clear Inline Styles") { apply(.clearInline(selection)) }
        }.disabled(selection.length == 0).accessibilityIdentifier("richInlineMenu")
    }

    @discardableResult
    private func apply(_ edit: RichBodyEdit) -> Bool {
        let count = state?.edits.count
        guard model.changeRich(edit, editorID: draftID) else { return false }
        if state?.edits.count != count { redo.removeAll() }
        return true
    }

    private func paragraph(_ edit: RichParagraphEdit) { apply(.paragraph(edit, selection)) }

    private func undo() {
        guard let state, let last = state.edits.last,
              model.restoreRichEdits(Array(state.edits.dropLast()), editorID: draftID) else { return }
        redo.append(last)
        clampSelection()
    }

    private func redoEdit() {
        guard let last = redo.last, model.changeRich(last, editorID: draftID) else { return }
        redo.removeLast()
        clampSelection()
    }

    private func clampSelection() {
        guard let text = state?.content.text else { return }
        let length = text.utf16.count
        let location = min(selection.location, length)
        selection = NSRange(location: location, length: min(selection.length, length - location))
    }
}

struct PhoneRichTextInput: UIViewRepresentable {
    let content: RichBody
    @Binding var selection: NSRange
    @Binding var composing: Bool
    let editable: Bool
    let read: () -> RichBody?
    let apply: (RichBodyEdit) -> Bool
    @ScaledMetric(relativeTo: .body) private var pointSize: CGFloat = 17

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> RichEditorTextView {
        let storage = NSTextStorage()
        let layout = RichPreviewLayout()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let view = RichEditorTextView(frame: .zero, textContainer: container)
        view.delegate = context.coordinator
        view.pastePlainText = { [weak coordinator = context.coordinator] view, text in
            coordinator?.paste(text, in: view)
        }
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.font = .preferredFont(forTextStyle: .body)
        view.allowsEditingTextAttributes = false
        view.dataDetectorTypes = []
        view.pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [UTType.utf8PlainText.identifier])
        view.accessibilityIdentifier = "richFieldEditor"
        view.accessibilityLabel = "Rich description"
        context.coordinator.render(content, in: view, selection: selection)
        return view
    }

    func updateUIView(_ view: RichEditorTextView, context: Context) {
        context.coordinator.parent = self
        if view.isEditable != editable {
            view.isEditable = editable
            view.isSelectable = true
        }
        guard view.markedTextRange == nil else { return }
        guard let preview = RichDescriptionPreview(body: content.text, rich: content),
              view.rendered?.matches(preview) != true || view.renderedPointSize != pointSize ||
              !RichBody.sameCodeUnits(view.text, content.text) else { return }
        // Native typing can update the caret after the text-change callback.
        // Re-render at the live selection instead of replaying a stale binding.
        context.coordinator.render(content, in: view, selection: view.selectedRange)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RichEditorTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PhoneRichTextInput
        private var rendering = false
        private var proposedRange: NSRange?
        private var compositionRange: NSRange?

        init(_ parent: PhoneRichTextInput) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if !rendering, textView.markedTextRange == nil, let prior = parent.read(),
               RichBody.sameCodeUnits(textView.text, prior.text) {
                proposedRange = range
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) { publish(textView) }
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !rendering else { return }
            if textView.markedTextRange != nil || parent.composing { publish(textView) }
            else if let prior = parent.read(), RichBody.sameCodeUnits(textView.text, prior.text) {
                updateSelection(textView)
            }
        }
        func textViewDidEndEditing(_ textView: UITextView) { publish(textView) }

        func paste(_ text: String, in view: RichEditorTextView) {
            let range = view.selectedRange
            guard !rendering, view.isEditable, view.markedTextRange == nil, let prior = parent.read(),
                  RichBody.sameCodeUnits(view.text, prior.text), range.length > 0 || !text.isEmpty,
                  parent.apply(.replace(range, with: text, style: .plain)), let updated = parent.read() else { return }
            let cursor = NSRange(location: range.location + text.utf16.count, length: 0)
            render(updated, in: view, selection: cursor)
            updateSelection(view)
        }

        func render(_ content: RichBody, in view: RichEditorTextView, selection: NSRange) {
            guard let preview = RichDescriptionPreview(body: content.text, rich: content) else { return }
            rendering = true
            defer { rendering = false }
            let size = parent.pointSize
            let widest = preview.paragraphs.reduce(0) { width, paragraph in
                if case .number(let number) = paragraph.marker { return max(width, String(number).count) }
                return width
            }
            let indent = max(size * 1.5, size * 0.72 * CGFloat(widest + 2))
            let layout = view.layoutManager as? RichPreviewLayout
            layout?.decorations = preview.paragraphs.filter { $0.marker != nil || $0.quote || $0.rule }
            layout?.pointSize = size
            layout?.markerIndent = indent
            view.attributedText = attributedDescription(preview, pointSize: size, markerIndent: indent)
            let location = min(selection.location, view.attributedText.length)
            view.selectedRange = NSRange(location: location, length: min(selection.length, view.attributedText.length - location))
            view.rendered = preview
            view.renderedPointSize = size
        }

        private func publish(_ textView: UITextView) {
            guard !rendering, let view = textView as? RichEditorTextView, let prior = parent.read() else { return }
            if view.markedTextRange != nil {
                if compositionRange == nil { compositionRange = proposedRange ?? parent.selection }
                proposedRange = nil
                if !parent.composing { parent.composing = true }
                return
            }
            let preferredRange = compositionRange ?? proposedRange
            compositionRange = nil
            proposedRange = nil
            if parent.composing { parent.composing = false }
            if let change = RichBodyEdit.replacement(from: prior.text, to: view.text,
                                                     style: .inherit, replacing: preferredRange),
               !parent.apply(change) {
                render(prior, in: view, selection: preferredRange ?? parent.selection)
            }
            updateSelection(view)
        }

        private func updateSelection(_ view: UITextView) {
            if parent.selection != view.selectedRange { parent.selection = view.selectedRange }
        }
    }
}

final class RichEditorTextView: UITextView {
    var rendered: RichDescriptionPreview?
    var renderedPointSize: CGFloat = 0
    var pastePlainText: ((RichEditorTextView, String) -> Void)?
    private var didFocus = false

    override var undoManager: UndoManager? { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !didFocus {
            didFocus = true
            becomeFirstResponder()
        }
    }

    override func paste(_ sender: Any?) {
        guard isEditable, markedTextRange == nil, let text = UIPasteboard.general.string else { return }
        pastePlainText?(self, text)
    }
}
