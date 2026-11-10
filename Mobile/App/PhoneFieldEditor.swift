import SwiftUI
import UIKit
import UniformTypeIdentifiers
import TaskovskyWorkspace

struct PhoneFieldEditor: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let draftID: UUID
    let field: TaskDraftField
    var body: some View {
        NavigationStack {
            ScrollView {
                if let draft = model.activeDraft, draft.id == draftID {
                    VStack(alignment: .leading, spacing: 16) {
                        if model.staleDraft && model.editorError == nil { Text("This edit is based on an older task. Your text is kept; discard to reload the current task.").foregroundStyle(.orange) }
                        if let error = model.editorError { Text(error).foregroundStyle(.red).accessibilityIdentifier("fieldEditorError") }
                        if model.isComposing { Text("Finish your keyboard entry before saving.").font(.footnote).foregroundStyle(.secondary) }
                        Text(model.recoveryStatus).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("draftRecoveryStatus")
                        NativeFieldInput(text: Binding(get: { model.activeDraft?.id == draftID ? model.activeDraft!.text : draft.text },
                                                      set: { model.changeText($0, editorID: draftID) }),
                                         composing: Binding(get: { model.activeDraft?.id == draftID ? model.isComposing : false },
                                                            set: { if model.activeDraft?.id == draftID { model.isComposing = $0 } }), editorID: draftID,
                                         title: draft.field == .title, editable: !model.isBusy)
                            .id(draft.id).frame(minHeight: draft.field == .title ? 90 : 220, alignment: .topLeading)
                        if draft.field == .title && draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("A title cannot be empty.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }.padding(20)
                }
            }.navigationTitle(field == .title ? "Edit title" : "Edit description")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.requestCloseEditor() }.disabled(model.isBusy).accessibilityIdentifier("fieldEditorCancel") }
                    ToolbarItem(placement: .confirmationAction) { Button(model.isBusy ? "Saving…" : "Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Task { await model.save() }
                    }.disabled(!model.canSave).accessibilityIdentifier("fieldEditorDone") }
                }
        }.interactiveDismissDisabled(model.activeDraft?.hasChanges == true || model.isBusy)
            .alert("Discard this edit?", isPresented: $model.confirmDiscard) {
                Button("Discard", role: .destructive) { Task { await model.discardActive() } }
                Button("Keep Editing", role: .cancel) { }
            }
    }
}

/// Plain native host only. No extraction, autosubmit, or rich-format conversion.
/// Late callbacks carry the editor ID and are refused by the model after close.
struct NativeFieldInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var composing: Bool
    let editorID: UUID
    let title: Bool
    let editable: Bool
    var focusOnAppear = true
    var accessibilityID = "fieldEditor"
    var focusRequest: UUID? = nil
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> FocusTextView {
        let view = FocusTextView(); view.shouldFocus = focusOnAppear
        view.backgroundColor = .clear; view.isScrollEnabled = false
        view.allowsEditingTextAttributes = false
        view.pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [UTType.utf8PlainText.identifier])
        view.textContainerInset = .zero; view.textContainer.lineFragmentPadding = 0
        view.font = .preferredFont(forTextStyle: title ? .title2 : .body)
        view.adjustsFontForContentSizeCategory = true
        view.text = text; view.selectedRange = NSRange(location: text.utf16.count, length: 0)
        view.accessibilityIdentifier = accessibilityID; view.accessibilityLabel = title ? "Title" : "Description"
        view.delegate = context.coordinator
        return view
    }
    func updateUIView(_ view: FocusTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updating = true
        defer { context.coordinator.updating = false }
        if view.isEditable != editable { view.isEditable = editable; view.isSelectable = true }
        if let focusRequest, editable, context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak view] in
                guard let view, view.window != nil, view.isEditable else { return }
                view.selectedRange = NSRange(location: view.text.utf16.count, length: 0)
                view.becomeFirstResponder()
            }
        }
        if view.markedTextRange == nil && !view.text.utf16.elementsEqual(text.utf16) {
            view.undoManager?.removeAllActions(); view.text = text
            view.selectedRange = NSRange(location: text.utf16.count, length: 0)
        }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FocusTextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: height)
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeFieldInput
        var updating = false
        var lastFocusRequest: UUID?
        init(_ parent: NativeFieldInput) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { publish(textView) }
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !updating else { return }
            let marked = textView.markedTextRange != nil
            if parent.composing != marked { parent.composing = marked }
        }
        func textViewDidEndEditing(_ textView: UITextView) { publish(textView) }
        private func publish(_ view: UITextView) {
            guard !updating else { return }
            let marked = view.markedTextRange != nil
            if parent.composing != marked { parent.composing = marked }
            parent.text = view.text
        }
    }
}

final class FocusTextView: UITextView {
    var shouldFocus = true
    private var focusedOnce = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && shouldFocus && !focusedOnce { focusedOnce = true; becomeFirstResponder() }
    }
}
