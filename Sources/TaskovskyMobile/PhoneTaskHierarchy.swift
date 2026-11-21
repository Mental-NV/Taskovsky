import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

struct PhoneTaskHierarchyRequest: Identifiable {
    enum Kind { case child, parent }
    let id = UUID()
    let task: TaskItem
    let revision: WorkspaceRevision
    let kind: Kind
}

struct PhoneTaskHierarchy: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let task: TaskItem
    let data: WorkspaceData
    let writable: Bool
    let navigate: (UUID) -> Void
    let edit: (PhoneTaskHierarchyRequest.Kind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let parent = data.tasks.first(where: { $0.id == task.parentID }) {
                relatedButton(parent, label: "Subtask of", identifier: "openParentTask")
            }
            if task.kind == .task {
                if writable {
                    Button { edit(.parent) } label: {
                        Label(task.parentID == nil ? "Make Subtask Of" : "Change Parent", systemImage: "arrow.turn.up.right")
                            .frame(minHeight: 44)
                    }.accessibilityIdentifier("editParentTask")
                }
                Divider()
                HStack {
                    Text("Subtasks").font(.headline)
                    Spacer()
                    if let progress = TaskHierarchy.progress(of: task.id, in: data.tasks) {
                        Text("\(progress.done) of \(progress.total)").foregroundStyle(.secondary)
                            .accessibilityIdentifier("subtaskProgress")
                    }
                    if writable {
                        Button("Add") { edit(.child) }.frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Add subtask").accessibilityIdentifier("addSubtask")
                    }
                }
                ForEach(TaskHierarchy.children(of: task.id, in: data.tasks)) { child in
                    HStack(spacing: 4) {
                        PhoneCompletionButton(model: model, task: child, lists: data.lists, isSubtaskRow: true)
                            .disabled(!writable)
                        relatedButton(child, label: "Open subtask", identifier: "openSubtask-" + child.id.uuidString)
                    }
                }
            }
        }
    }

    private func relatedButton(_ related: TaskItem, label: String, identifier: String) -> some View {
        Button { navigate(related.id) } label: {
            HStack {
                if label == "Subtask of" { Text(label).foregroundStyle(.secondary) }
                Text(related.title.isEmpty ? "Untitled" : related.title).lineLimit(2)
                if related.deletedAt != nil {
                    Text("In Trash").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.secondary)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .disabled(model.isBusy)
            .accessibilityLabel(label + " " + related.title)
            .accessibilityIdentifier(identifier)
    }
}

struct PhoneTaskHierarchySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneTaskHierarchyRequest
    @State private var title = ""
    @State private var composing = false
    @State private var selection: UUID?
    @State private var query = ""
    @State private var confirmDiscard = false
    @State private var showError = false

    init(model: PhoneWorkspaceModel, request: PhoneTaskHierarchyRequest) {
        self.model = model
        self.request = request
        _selection = State(initialValue: request.task.parentID)
    }

    private var titleValue: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var adding: Bool { request.kind == .child }
    private var changed: Bool { adding ? !title.isEmpty || composing : selection != request.task.parentID }

    var body: some View {
        NavigationStack {
            Group {
                if adding {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Subtask of " + request.task.title).font(.subheadline).foregroundStyle(.secondary)
                            NativeFieldInput(text: $title, composing: $composing, editorID: request.id,
                                             title: true, editable: !model.isBusy, accessibilityID: "newSubtaskTitle",
                                             fieldLabel: "Subtask title")
                                .frame(minHeight: 52, alignment: .topLeading)
                                .overlay(alignment: .topLeading) {
                                    if title.isEmpty {
                                        Text("Subtask title").font(.title2).foregroundStyle(.tertiary)
                                            .allowsHitTesting(false).accessibilityHidden(true)
                                    }
                                }
                        }.padding(20)
                    }
                } else {
                    parentPicker
                }
            }
            .disabled(model.isBusy)
            .navigationTitle(adding ? "Add Subtask" : "Parent Task")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if showError { PhoneLifecycleFeedback(model: model).padding().background(.regularMaterial) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { confirmDiscard = true } else { dismiss() } }
                        .disabled(model.isBusy).accessibilityIdentifier("taskHierarchyCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(adding ? "Add" : "Done", action: save)
                        .disabled(model.isBusy || composing || (adding ? titleValue.isEmpty : !changed))
                        .accessibilityIdentifier("taskHierarchyDone")
                }
            }
        }
        .interactiveDismissDisabled(changed || model.isBusy)
        .alert("Discard changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    private var parentPicker: some View {
        let data = model.document?.snapshot.workspace ?? WorkspaceData()
        let forbidden = Set(TaskHierarchy.descendants(of: request.task.id, in: data.tasks).map(\.id) + [request.task.id])
        let eligible = data.tasks.filter {
            $0.kind == .task && $0.deletedAt == nil && $0.completedAt == nil && $0.wontDoAt == nil &&
                !forbidden.contains($0.id) && !SmartListEligibility.isArchived($0, lists: data.lists)
        }
        let visible = eligible.filter {
            query.isEmpty || $0.title.localizedStandardContains(query) || listName($0.listID, in: data).localizedStandardContains(query)
        }
        return List {
            if let selected = eligible.first(where: { $0.id == selection }), selected.listID != request.task.listID {
                Text("This task and its subtasks will move to \(listName(selected.listID, in: data)).")
                    .font(.footnote).accessibilityIdentifier("parentMoveSummary")
            }
            Section {
                TextField("Search tasks or lists", text: $query).autocorrectionDisabled()
                parentChoice("Top level", list: nil, id: nil)
            }
            if visible.isEmpty {
                Text(query.isEmpty ? "No available parent tasks" : "No matching parent tasks").foregroundStyle(.secondary)
            }
            ForEach(visible) { parent in
                parentChoice(parent.title.isEmpty ? "Untitled" : parent.title,
                             list: listName(parent.listID, in: data), id: parent.id)
            }
        }.scrollDismissesKeyboard(.interactively)
    }

    private func parentChoice(_ title: String, list: String?, id: UUID?) -> some View {
        Button { selection = id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    if let list { Text(list).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if selection == id { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(list.map { title + ", " + $0 } ?? title)
            .accessibilityAddTraits(selection == id ? .isSelected : [])
            .accessibilityIdentifier(id.map { "parentChoice-" + $0.uuidString } ?? "parentChoice-top")
    }

    private func listName(_ id: UUID?, in data: WorkspaceData) -> String {
        guard let id else { return "Inbox" }
        return data.lists.first { $0.id == id }?.name ?? "Unavailable list"
    }

    private func save() {
        let command: TaskLifecycleCommand = adding ? .addSubtask(id: request.id, title: titleValue) : .setParent(selection)
        Task {
            if await model.performLifecycle(command, taskID: request.task.id, expected: request.revision) {
                dismiss()
            } else { showError = true }
        }
    }
}
