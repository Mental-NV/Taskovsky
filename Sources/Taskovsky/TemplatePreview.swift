import SwiftUI
import TaskovskyCore

/// A snapshot preview: applying never silently substitutes a changed template.
struct TemplatePreview: View {
    @ObservedObject var store: TaskStore
    let template: TaskTemplate
    @Environment(\.dismiss) private var dismiss
    @StateObject private var richController = RichBodyController()
    @State private var richHeight: CGFloat = 60
    @State private var showingHelp = false
    @State private var error: String?
    @State private var applied = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Preview").font(.system(size: 14, weight: .semibold))
                HStack {
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                        .buttonStyle(.plain).accessibilityLabel("Close preview")
                        .accessibilityIdentifier("templatePreviewClose")
                        .keyboardShortcut(.cancelAction)
                }
            }.padding(.horizontal, 14).padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(template.title).font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    if !template.body.isEmpty {
                        if let rich = template.richBody, let preview = RichDescriptionPreview(body: template.body, rich: rich) {
                            RichBodyEditor(controller: richController, documentID: template.id,
                                           text: preview.text, rich: preview.displayRichBody, disabled: true,
                                           onChange: { _, _ in }, onHeightChange: { richHeight = $0 })
                                .frame(height: max(60, richHeight))
                                .accessibilityLabel("Read-only template description")
                        } else {
                            Text(template.body).font(.system(size: 13)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(template.checklist) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: item.isCompleted ? "checkmark.square" : "square")
                                    .foregroundStyle(.secondary).accessibilityHidden(true)
                                Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
                            }.font(.system(size: 13))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel((item.isCompleted ? "Completed: " : "Incomplete: ") + item.title)
                        }
                    }
                }.padding(20)
            }.accessibilityIdentifier("templatePreviewContent")
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if let error {
                    Text(error).font(.system(size: 12)).foregroundStyle(.red)
                        .accessibilityIdentifier("templatePreviewError")
                }
                HStack {
                    Button("How to edit a template") { showingHelp = true }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                        .popover(isPresented: $showingHelp) {
                            Text("Close Preview, open the template’s options menu, and choose Edit. Apply creates a new task; it does not replace the saved template.")
                                .font(.system(size: 12)).padding(16).frame(width: 280)
                        }
                    Spacer()
                    Button("Apply", action: apply).buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction).disabled(applied)
                        .accessibilityIdentifier("templatePreviewApply")
                }
            }.padding(.horizontal, 14).padding(.vertical, 12)
        }.frame(width: 560, height: 400).tint(accent)
    }

    private func apply() {
        guard !applied else { return }
        guard store.data.templates.first(where: { $0.id == template.id }) == template else {
            error = "This template changed or was removed. Close Preview and open it again."
            return
        }
        applied = true
        guard store.createTaskFromTemplate(id: template.id, expectedTemplate: template) != nil else {
            applied = false
            error = store.storageError ?? "The task could not be saved. Try Apply again."
            return
        }
        dismiss()
    }
}
