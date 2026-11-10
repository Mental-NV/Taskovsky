import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneTaskRoute: Identifiable {
    let id: UUID
    var preferEditor = false
}

struct PhoneTaskSheet: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let route: PhoneTaskRoute
    let close: () -> Void
    @State private var showActions = false
    @State private var scheduleRequest: PhoneScheduleRequest?
    private var current: TaskItem? { model.document?.snapshot.workspace.tasks.first { $0.id == route.id } }
    private var writable: Bool {
        guard let task = current, let data = model.document?.snapshot.workspace else { return false }
        return model.canBeginEditing && task.deletedAt == nil && !SmartListEligibility.isArchived(task, lists: data.lists)
    }
    private var editor: Binding<TaskFieldDraft?> {
        Binding(get: { !route.preferEditor && model.activeDraft?.taskID == route.id ? model.activeDraft : nil },
                set: { value in if value == nil { model.requestCloseEditor() } })
    }
    var body: some View {
        Group {
            if route.preferEditor, let draft = model.activeDraft, draft.taskID == route.id {
                PhoneFieldEditor(model: model, draftID: draft.id, field: draft.field)
            } else {
                reader.sheet(item: editor) { draft in
                    PhoneFieldEditor(model: model, draftID: draft.id, field: draft.field).presentationDetents([.large])
                }
            }
        }.presentationDetents(route.preferEditor ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(model.activeDraft?.hasChanges == true || model.isBusy)
    }
    private var reader: some View {
        NavigationStack {
            ScrollView {
                if let task = current, let data = model.document?.snapshot.workspace {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            PhoneCompletionButton(model: model, task: task, lists: data.lists)
                            Text(task.listID.flatMap { id in data.lists.first { $0.id == id }?.name } ?? "Inbox")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if task.deletedAt != nil { Text("In Trash").font(.caption).foregroundStyle(.secondary) }
                            else if SmartListEligibility.isArchived(task, lists: data.lists) {
                                Text("Archived").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        PhoneLifecycleFeedback(model: model)
                        Button { Task { await model.begin(taskID: task.id, field: .title) } } label: {
                            Text(task.title).font(.title2.bold()).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).disabled(!writable).accessibilityIdentifier("editTitle")
                            .accessibilityLabel("Edit title, " + task.title)
                        if model.document?.allowsKnownFieldWrites == false {
                            Text("This workspace contains data this build cannot safely rewrite. Viewing remains available.").font(.footnote).foregroundStyle(.secondary)
                        }
                        if task.kind == .task {
                            Button {
                                guard let document = model.document else { return }
                                scheduleRequest = PhoneScheduleRequest(task: task, document: document,
                                                                       calendar: model.calendar, now: model.now)
                            } label: {
                                Label(PhoneScheduleRequest.summary(for: task, calendar: model.calendar),
                                      systemImage: "calendar")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .disabled(!writable)
                            .accessibilityIdentifier("editSchedule")
                            .accessibilityHint("Edit task schedule")
                        }
                        if task.richBody != nil {
                            Text("Formatting is shown as plain text in this preview. The original content is preserved.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(task.body.isEmpty ? "No description" : task.body).accessibilityIdentifier("taskDescription").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        Button("Edit description") { Task { await model.begin(taskID: task.id, field: .plainBody) } }
                            .disabled(!writable || task.richBody != nil).frame(minHeight: 44)
                        ForEach(task.checklist) { item in Label(item.title, systemImage: item.isCompleted ? "checkmark.square" : "square") }
                        if let error = model.editorError, model.activeDraft == nil { Text(error).font(.footnote).foregroundStyle(.secondary) }
                    }.padding(20)
                } else { ContentUnavailableView("Task unavailable", systemImage: "doc.questionmark", description: Text("Any saved edit is kept separately.")) }
            }.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showActions = true } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("Task actions").accessibilityIdentifier("taskActions")
                        .disabled(!model.canBeginEditing || current == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close).disabled(model.isBusy).accessibilityIdentifier("taskDetailDone")
                }
            }
            .sheet(item: $scheduleRequest) { request in
                PhoneScheduleSheet(model: model, request: request)
            }
            .sheet(isPresented: $showActions, onDismiss: { if current == nil { close() } }) {
                PhoneTaskActions(model: model, taskID: route.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct PhoneCompletionButton: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let task: TaskItem
    let lists: [TaskList]

    var body: some View {
        let revision = model.document?.revision
        let isHistory = task.completedAt != nil || task.wontDoAt != nil
        let command: TaskLifecycleCommand = isHistory ? .reopen : .complete
        let symbol = task.kind == .note ? "doc.text" : task.completedAt != nil ? "checkmark.square" :
            task.wontDoAt != nil ? "xmark.square" : "square"
        let icon = Image(systemName: symbol).font(.system(size: 17))
            .foregroundStyle(.secondary).frame(width: 44, height: 44).contentShape(Rectangle())
        if TaskLifecycle.refusal(for: command, task: task, lists: lists) == nil {
            Button {
                guard let revision else { return }
                Task { await model.performLifecycle(command, taskID: task.id, expected: revision) }
            } label: { icon }
                .buttonStyle(.plain)
                .disabled(!model.canBeginEditing)
                .accessibilityLabel((isHistory ? "Reopen " : "Complete ") + task.title)
                .accessibilityIdentifier("lifecycleToggle-" + task.id.uuidString)
        } else {
            icon.accessibilityHidden(true)
        }
    }
}

struct PhoneLifecycleFeedback: View {
    @ObservedObject var model: PhoneWorkspaceModel

    var body: some View {
        if let message = model.lifecycleNotice {
            HStack {
                Text(message).font(.footnote).accessibilityIdentifier("lifecycleFeedback")
                if model.canUndoLifecycle {
                    Button("Undo") { Task { await model.undoLifecycle() } }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("undoLifecycle")
                }
            }
        }
    }
}

private struct PhoneTaskActions: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let taskID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var purge: PurgeRequest?

    private struct PurgeRequest: Identifiable {
        let id: UUID
        let title: String
        let revision: WorkspaceRevision
    }

    var body: some View {
        NavigationStack {
            List {
                if let document = model.document,
                   let task = document.snapshot.workspace.tasks.first(where: { $0.id == taskID }) {
                    let lists = document.snapshot.workspace.lists
                    Section(task.title) {
                        action("Complete", .complete, task: task, document: document)
                        action("Reopen", .reopen, task: task, document: document)
                        action("Won't Do", .wontDo, task: task, document: document)
                        action(task.isPinned ? "Unpin" : "Pin", .setPinned(!task.isPinned), task: task, document: document)
                        if TaskLifecycle.refusal(for: .move(nil), task: task, lists: lists) == nil {
                            NavigationLink("Move to List") {
                                List {
                                    moveTarget("Inbox", id: nil, task: task, revision: document.revision)
                                    ForEach(lists.filter { !$0.isArchived }) { list in
                                        moveTarget(list.name, id: list.id, task: task, revision: document.revision)
                                    }
                                }.navigationTitle("Move to List")
                            }
                        }
                        action("Move to Trash", .trash, role: .destructive, task: task, document: document)
                        action("Restore", .restore, task: task, document: document)
                        if TaskLifecycle.refusal(for: .purge, task: task, lists: lists) == nil {
                            Button("Delete Forever", role: .destructive) {
                                purge = PurgeRequest(id: task.id, title: task.title, revision: document.revision)
                            }
                        }
                    }.disabled(!model.canBeginEditing)
                }
                PhoneLifecycleFeedback(model: model)
            }
            .navigationTitle("Task Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(model.isBusy)
                        .accessibilityIdentifier("taskActionsDone")
                }
            }
            .alert(item: $purge) { request in
                Alert(title: Text("Delete Forever?"),
                      message: Text("Permanently delete “\(request.title)”? Child tasks will be kept."),
                      primaryButton: .destructive(Text("Delete Forever")) {
                          run(.purge, revision: request.revision)
                      }, secondaryButton: .cancel())
            }
        }
        .interactiveDismissDisabled(model.isBusy)
    }

    @ViewBuilder private func action(_ title: String, _ command: TaskLifecycleCommand,
                                     role: ButtonRole? = nil, task: TaskItem, document: WorkspaceDocument) -> some View {
        if TaskLifecycle.refusal(for: command, task: task, lists: document.snapshot.workspace.lists) == nil {
            Button(title, role: role) { run(command, revision: document.revision) }
        }
    }

    private func moveTarget(_ title: String, id: UUID?, task: TaskItem, revision: WorkspaceRevision) -> some View {
        Button(title) { run(.move(id), revision: revision) }
            .disabled(!model.canBeginEditing || task.listID == id)
    }

    private func run(_ command: TaskLifecycleCommand, revision: WorkspaceRevision) {
        Task {
            if await model.performLifecycle(command, taskID: taskID, expected: revision) {
                dismiss()
            }
        }
    }
}
