import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneTemplateManager: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    @State private var request: PhoneTemplateRequest?

    var body: some View {
        NavigationStack {
            List {
                Button("New Template", systemImage: "plus") { open(nil) }
                    .accessibilityIdentifier("newTemplate")
                ForEach(model.document?.snapshot.workspace.templates ?? []) { template in
                    Button { open(template) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                            Text(template.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.accessibilityLabel(template.name)
                }
            }
            .disabled(!model.canBeginEditing)
            .navigationTitle("Templates").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("templateManagerDone")
                }
            }
        }
        .sheet(item: $request) { PhoneTemplateEditor(model: model, request: $0) }
    }

    private func open(_ template: TaskTemplate?) {
        guard let revision = model.document?.revision else { return }
        request = PhoneTemplateRequest(id: template?.id ?? UUID(), original: template, revision: revision)
    }
}

private struct PhoneTemplateRequest: Identifiable {
    let id: UUID
    let original: TaskTemplate?
    let revision: WorkspaceRevision
}

private struct PhoneTemplateEditor: View {
    private enum Confirmation: String, Identifiable {
        case discard, delete
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneTemplateRequest
    @State private var draft: TaskTemplateFields
    @State private var confirmation: Confirmation?
    @State private var error: String?
    @State private var composing = false

    init(model: PhoneWorkspaceModel, request: PhoneTemplateRequest) {
        self.model = model
        self.request = request
        _draft = State(initialValue: TaskTemplateFields(template: request.original))
    }

    private var changed: Bool {
        let original = TaskTemplateFields(template: request.original)
        return !RichBody.sameCodeUnits(draft.name, original.name) || !RichBody.sameCodeUnits(draft.title, original.title) ||
            !RichBody.sameCodeUnits(draft.body, original.body) || !TaskMetadataChange.sameChecklist(draft.checklist, original.checklist) ||
            draft.priority != original.priority
    }

    private var canSave: Bool {
        !model.isBusy && !composing && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            draft.checklist.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template name", text: $draft.name).accessibilityIdentifier("templateName")
                    TextField("Task title", text: $draft.title).accessibilityIdentifier("templateTaskTitle")
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { Text($0.phoneLabel).tag($0) }
                    }
                }
                Section("Description") {
                    if let rich = request.original?.richBody {
                        if let preview = RichDescriptionPreview(body: draft.body, rich: rich) {
                            PhoneRichDescription(preview: preview)
                        } else {
                            Text(draft.body).textSelection(.enabled)
                        }
                        Text("Formatting is preserved. This description is read-only.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        NativeFieldInput(text: $draft.body, composing: $composing, editorID: request.id, title: false,
                                         editable: !model.isBusy, focusOnAppear: false, accessibilityID: "templateDescription")
                            .frame(minHeight: 90, alignment: .topLeading)
                    }
                }
                Section("Checklist") {
                    ForEach($draft.checklist) { $item in
                        HStack {
                            TextField("Step", text: $item.title)
                            Button("Remove step", systemImage: "minus.circle", role: .destructive) {
                                draft.checklist.removeAll { $0.id == item.id }
                            }.labelStyle(.iconOnly).buttonStyle(.borderless)
                        }
                    }
                    Button("Add step", systemImage: "plus") { draft.checklist.append(ChecklistItem(title: "")) }
                }
                if request.original != nil {
                    Button("Delete Template", role: .destructive) { confirmation = .delete }
                        .accessibilityIdentifier("deleteTemplate")
                }
            }
            .disabled(model.isBusy)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(request.original == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { PhoneTemplateError(message: error) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { confirmation = .discard } else { dismiss() } }
                        .disabled(model.isBusy).accessibilityIdentifier("templateCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        submit(request.original == nil ? .create(id: request.id, fields: draft) : .update(id: request.id, fields: draft))
                    }.disabled(!canSave).accessibilityIdentifier("templateDone")
                }
            }
        }
        .interactiveDismissDisabled(changed || model.isBusy)
        .alert(item: $confirmation) { confirmation in
            switch confirmation {
            case .discard:
                Alert(title: Text("Discard template changes?"), primaryButton: .destructive(Text("Discard Changes")) { dismiss() },
                      secondaryButton: .cancel(Text("Keep Editing")))
            case .delete:
                Alert(title: Text("Delete template?"), message: Text("Tasks created from this template will be kept."),
                      primaryButton: .destructive(Text("Delete Template")) { submit(.delete(request.id)) },
                      secondaryButton: .cancel())
            }
        }
    }

    private func submit(_ command: TaskTemplateChange) {
        Task {
            error = await model.saveTemplate(command, expected: request.revision)
            if error == nil { dismiss() }
        }
    }
}

struct PhoneSaveTaskAsTemplate: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let task: TaskItem
    let revision: WorkspaceRevision
    let onSaved: () -> Void
    @State private var name: String
    @State private var templateID = UUID()
    @State private var error: String?

    init(model: PhoneWorkspaceModel, task: TaskItem, revision: WorkspaceRevision, onSaved: @escaping () -> Void) {
        self.model = model
        self.task = task
        self.revision = revision
        self.onSaved = onSaved
        _name = State(initialValue: task.title)
    }

    var body: some View {
        Form {
            TextField("Template name", text: $name).accessibilityIdentifier("saveTaskTemplateName")
            Button("Save Template") {
                Task {
                    error = await model.saveTemplate(.saveFromTask(taskID: task.id, templateID: templateID, name: name),
                                                     expected: revision)
                    if error == nil { onSaved() }
                }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("saveTaskTemplateDone")
        }
        .disabled(model.isBusy)
        .navigationTitle("Save as Template")
        .safeAreaInset(edge: .top, spacing: 0) { PhoneTemplateError(message: error) }
    }
}

struct PhoneApplyTaskTemplate: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let taskID: UUID
    let revision: WorkspaceRevision
    let onApplied: () -> Void
    @State private var selection: TaskTemplate?
    @State private var error: String?

    var body: some View {
        List(model.document?.snapshot.workspace.templates ?? []) { template in
            Button { selection = template } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                    Text(template.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.accessibilityLabel(template.name).accessibilityIdentifier("applyTaskTemplate-" + template.id.uuidString)
        }
        .disabled(model.isBusy)
        .navigationTitle("Apply Template")
        .safeAreaInset(edge: .top, spacing: 0) { PhoneTemplateError(message: error) }
        .alert(item: $selection) { template in
            Alert(title: Text("Apply “\(template.name)”?"),
                  message: Text("This replaces template fields on the current task. Linked tasks stay in place."),
                  primaryButton: .destructive(Text("Apply Template")) {
                      Task {
                          error = await model.saveTemplate(.applyToTask(templateID: template.id, taskID: taskID), expected: revision)
                          if error == nil { onApplied() }
                      }
                  }, secondaryButton: .cancel())
        }
    }
}

private struct PhoneTemplateError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message).font(.footnote).foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
                .background(.regularMaterial).accessibilityIdentifier("templateError")
        }
    }
}
