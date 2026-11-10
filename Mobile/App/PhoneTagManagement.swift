import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

private struct PhoneTagRequest: Identifiable {
    let id = UUID()
    let tag: TaskTag
    let creating: Bool
    let revision: WorkspaceRevision
}

struct PhoneTagManagement: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    @State private var request: PhoneTagRequest?
    @State private var reordering = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Button("New Tag", systemImage: "tag") { open(TaskTag(name: "", color: "#4E64D8"), creating: true) }
                    .disabled(reordering || !model.canBeginEditing).accessibilityIdentifier("newTag")
                if let document = model.document {
                    let tags = document.snapshot.workspace.tags
                    ForEach(ordered(tags)) { tag in
                        let depth = TagHierarchy.ancestors(of: tag.id, in: tags).count
                        if reordering {
                            reorderRow(tag, tags: tags, depth: depth, revision: document.revision)
                        } else {
                            Button { open(tag) } label: {
                                HStack {
                                    label(tag)
                                    Spacer()
                                    if tag.isPinned { Image(systemName: "pin.fill").accessibilityHidden(true) }
                                    Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.secondary)
                                }.frame(minHeight: 44).padding(.leading, CGFloat(min(depth, 4)) * 12).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(!model.canBeginEditing)
                                .accessibilityIdentifier("manageTag-" + tag.id.uuidString)
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("tagManagementError") }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(reordering ? "Finish" : "Reorder") { reordering.toggle() }.disabled(!model.canBeginEditing)
                        .accessibilityIdentifier("tagReorder")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("tagManagerDone")
                }
            }
        }
        .interactiveDismissDisabled(model.isBusy)
        .sheet(item: $request) { PhoneTagEditor(model: model, request: $0) }
    }

    private func ordered(_ tags: [TaskTag]) -> [TaskTag] {
        var result: [TaskTag] = []
        var seen = Set<UUID>()
        func visit(_ tag: TaskTag) {
            guard seen.insert(tag.id).inserted else { return }
            result.append(tag)
            TagHierarchy.children(of: tag.id, in: tags).forEach(visit)
        }
        TagHierarchy.roots(in: tags).forEach(visit)
        tags.forEach(visit)
        return result
    }

    private func label(_ tag: TaskTag) -> some View {
        HStack {
            Image(systemName: "tag").foregroundStyle(PhoneEntityColor.read(tag.color)).accessibilityHidden(true)
            Text(tag.name)
        }
    }

    private func reorderRow(_ tag: TaskTag, tags: [TaskTag], depth: Int, revision: WorkspaceRevision) -> some View {
        let siblings = tags.filter { $0.parentID == tag.parentID }
        let index = siblings.firstIndex { $0.id == tag.id } ?? 0
        return HStack {
            label(tag)
            Spacer()
            move(tag, neighbor: index > 0 ? siblings[index - 1].id : nil, down: false, revision: revision)
            move(tag, neighbor: index + 1 < siblings.count ? siblings[index + 1].id : nil, down: true, revision: revision)
        }.padding(.leading, CGFloat(min(depth, 4)) * 12)
    }

    private func move(_ tag: TaskTag, neighbor: UUID?, down: Bool, revision: WorkspaceRevision) -> some View {
        Button {
            guard let neighbor else { return }
            Task { error = await model.saveTag(.reorder(tag.id, relativeTo: neighbor, after: down), expected: revision) }
        } label: {
            Image(systemName: down ? "arrow.down" : "arrow.up").frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(neighbor == nil || !model.canBeginEditing)
            .accessibilityLabel("Move " + tag.name + (down ? " down" : " up"))
    }

    private func open(_ tag: TaskTag, creating: Bool = false) {
        guard let revision = model.document?.revision else { return }
        request = PhoneTagRequest(tag: tag, creating: creating, revision: revision)
    }
}

private struct PhoneTagEditor: View {
    private enum Confirmation: String, Identifiable {
        case discard, delete, merge
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneTagRequest
    @State private var draft: TaskTag
    @FocusState private var editingName: Bool
    @State private var target: UUID?
    @State private var confirmation: Confirmation?
    @State private var error: String?

    init(model: PhoneWorkspaceModel, request: PhoneTagRequest) {
        self.model = model
        self.request = request
        _draft = State(initialValue: request.tag)
    }

    private var tags: [TaskTag] { model.document?.snapshot.workspace.tags ?? [] }
    private var others: [TaskTag] { tags.filter { $0.id != draft.id } }
    private var changed: Bool { draft != request.tag || !RichBody.sameCodeUnits(draft.name, request.tag.name) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Tag name", text: $draft.name)
                            .focused($editingName).submitLabel(.done)
                            .onSubmit { editingName = false }
                            .accessibilityIdentifier("tagName")
                        if !draft.name.isEmpty {
                            Button { draft.name = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Clear name").accessibilityIdentifier("tagClearName")
                        }
                    }
                    ColorPicker("Color", selection: Binding(get: { PhoneEntityColor.read(draft.color) },
                                                            set: { draft.color = PhoneEntityColor.encode($0) ?? draft.color }),
                                supportsOpacity: false)
                    Picker("Parent tag", selection: $draft.parentID) {
                        Text("Top level").tag(UUID?.none).accessibilityIdentifier("tagParentChoice-root")
                        ForEach(others.filter { TagOrganization.allowsParent($0.id, for: draft.id, in: tags) }) { tag in
                            Text(path(tag)).tag(Optional(tag.id))
                                .accessibilityIdentifier("tagParentChoice-" + tag.id.uuidString)
                        }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("tagParent")
                    Toggle("Pin tag", isOn: $draft.isPinned).accessibilityIdentifier("tagPin")
                }
                if !request.creating {
                    Section("Merge or delete") {
                        Picker("Merge into", selection: $target) {
                            Text("Choose a tag").tag(UUID?.none)
                            ForEach(others) { tag in
                                Text(path(tag)).tag(Optional(tag.id))
                                    .accessibilityIdentifier("tagMergeChoice-" + tag.id.uuidString)
                            }
                        }.pickerStyle(.navigationLink).accessibilityIdentifier("tagMergeTarget")
                        Button("Merge Tag") { confirmation = .merge }.disabled(target == nil)
                            .accessibilityIdentifier("mergeTag")
                        Button("Delete Tag", role: .destructive) { confirmation = .delete }
                            .accessibilityIdentifier("deleteTag")
                    }.disabled(changed)
                }
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("tagSaveError") }
            }
            .disabled(model.isBusy)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(request.creating ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { confirmation = .discard } else { dismiss() } }
                        .disabled(model.isBusy).accessibilityIdentifier("tagCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { submit(.save(draft, creating: request.creating)) }
                        .disabled(model.isBusy || TagOrganization.normalizedName(draft.name).isEmpty)
                        .accessibilityIdentifier("tagDone")
                }
            }
        }
        .interactiveDismissDisabled(model.isBusy || changed)
        .alert(item: $confirmation, content: confirm)
    }

    private func path(_ tag: TaskTag) -> String {
        (TagHierarchy.ancestors(of: tag.id, in: tags).reversed().map(\.name) + [tag.name]).joined(separator: " / ")
    }

    private func confirm(_ confirmation: Confirmation) -> Alert {
        switch confirmation {
        case .discard:
            return Alert(title: Text("Discard changes?"), primaryButton: .destructive(Text("Discard Changes")) { dismiss() },
                         secondaryButton: .cancel(Text("Keep Editing")))
        case .delete:
            return Alert(title: Text("Delete tag?"),
                         message: Text("“\(request.tag.name)” will be removed from tasks and templates. Filters keep the unavailable tag."),
                         primaryButton: .destructive(Text("Delete Tag")) { submit(.delete(request.tag.id)) }, secondaryButton: .cancel())
        case .merge:
            let name = others.first { $0.id == target }?.name ?? "the selected tag"
            return Alert(title: Text("Merge tags?"),
                         message: Text("Tasks, templates, filters and the default tag will follow “\(name)” when they use “\(request.tag.name)”."),
                         primaryButton: .destructive(Text("Merge Tag")) {
                             if let target { submit(.merge(request.tag.id, into: target)) }
                         }, secondaryButton: .cancel())
        }
    }

    private func submit(_ command: TagOrganizationCommand) {
        Task {
            error = await model.saveTag(command, expected: request.revision)
            if error == nil { dismiss() }
        }
    }
}
