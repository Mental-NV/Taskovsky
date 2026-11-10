import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

extension TaskPriority {
    var phoneLabel: String { self == .none ? "None" : rawValue.capitalized }
    var phoneColor: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }
}

enum PhoneTaskMetadataKind: String {
    case priority = "Priority"
    case progress = "Task Progress"
    case tags = "Tags"
    case checklist = "Checklist"
}

struct PhoneTaskMetadataRequest: Identifiable {
    let id = UUID()
    let task: TaskItem
    let revision: WorkspaceRevision
    let kind: PhoneTaskMetadataKind
}

struct PhoneTaskMetadataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneTaskMetadataRequest
    @State private var tagIDs: [UUID]
    @State private var items: [ChecklistItem]
    @State private var progress: Double
    @State private var query = ""
    @State private var newTitle = ""
    @State private var newID = UUID()
    @State private var composingID: UUID?
    @State private var focus: FocusRequest?
    @State private var error: String?
    @State private var confirmDiscard = false

    private struct FocusRequest {
        let field: UUID
        let token = UUID()
    }

    init(model: PhoneWorkspaceModel, request: PhoneTaskMetadataRequest) {
        self.model = model
        self.request = request
        _tagIDs = State(initialValue: request.task.tagIDs)
        _items = State(initialValue: request.task.checklist)
        _progress = State(initialValue: Double(request.task.progressPercent))
    }

    private var hasChanges: Bool {
        Int(progress) != request.task.progressPercent || tagIDs != request.task.tagIDs ||
            !TaskMetadataChange.sameChecklist(items, request.task.checklist) ||
            !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || composingID != nil
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(request.kind.rawValue)
                .navigationBarTitleDisplayMode(.inline)
                .disabled(model.isBusy)
                .safeAreaInset(edge: .bottom) {
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding().background(.regularMaterial).accessibilityIdentifier("taskMetadataError")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            if hasChanges { confirmDiscard = true } else { dismiss() }
                        }.disabled(model.isBusy).accessibilityIdentifier("taskMetadataCancel")
                    }
                    if request.kind != .priority {
                        ToolbarItemGroup(placement: .confirmationAction) {
                            if request.kind == .checklist { EditButton().disabled(model.isBusy || composingID != nil) }
                            Button("Done") { saveDraft() }
                                .disabled(model.isBusy || composingID != nil).accessibilityIdentifier("taskMetadataDone")
                        }
                    }
                }
        }
        .presentationDetents(request.kind == .progress ? [.medium, .large] : [.large])
        .interactiveDismissDisabled(model.isBusy || hasChanges)
        .alert("Discard changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    @ViewBuilder private var content: some View {
        switch request.kind {
        case .priority:
            List(TaskPriority.allCases, id: \.self) { priority in
                Button { submit(.priority(priority)) } label: {
                    HStack {
                        Label(priority.phoneLabel, systemImage: priority == .none ? "flag" : "flag.fill")
                            .foregroundStyle(priority.phoneColor)
                        Spacer()
                        if priority == request.task.priority { Image(systemName: "checkmark") }
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("taskPriority-" + priority.rawValue)
                    .accessibilityAddTraits(priority == request.task.priority ? .isSelected : [])
            }
        case .progress:
            VStack(spacing: 20) {
                Stepper(value: $progress, in: 0...100) {
                    Text("\(Int(progress))%").font(.title2.monospacedDigit())
                        .accessibilityIdentifier("taskProgressDraftValue")
                }
                .accessibilityIdentifier("taskProgressStepper")
                Slider(value: Binding(get: { progress }, set: { progress = $0.rounded() }), in: 0...100) {
                    Text("Progress percentage")
                }.accessibilityIdentifier("taskProgressSlider")
                Spacer()
            }.padding(24)
        case .tags: tagPicker
        case .checklist: checklistEditor
        }
    }

    private var tagPicker: some View {
        let tags = model.document?.snapshot.workspace.tags ?? []
        let available = Set(tags.map(\.id))
        let unavailable = tagIDs.filter { !available.contains($0) }
        let visible = tags.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
        return List {
            Section {
                TextField("Search existing tags", text: $query)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("searchTaskTags")
            }
            if visible.isEmpty { Text(query.isEmpty ? "No tags in this workspace" : "No matching tags").foregroundStyle(.secondary) }
            ForEach(visible) { tag in
                let selected = tagIDs.contains(tag.id)
                Button {
                    if selected { tagIDs.removeAll { $0 == tag.id } } else { tagIDs.append(tag.id) }
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(tag.name)
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityIdentifier("taskTag-" + tag.id.uuidString)
            }
            if !unavailable.isEmpty {
                Section {
                    Button("Remove unavailable tags") { tagIDs.removeAll { !available.contains($0) } }
                } footer: { Text("Unavailable saved tag references are kept until you remove them.") }
            }
        }.scrollDismissesKeyboard(.interactively)
    }

    private var checklistEditor: some View {
        List {
            Section("Items") {
                ForEach(items) { item in
                    let id = item.id
                    HStack {
                        Button {
                            if let index = items.firstIndex(where: { $0.id == id }) {
                                items[index].isCompleted.toggle()
                            }
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.square" : "square")
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel((item.isCompleted ? "Uncheck " : "Check ") + item.title)
                            .accessibilityIdentifier("draftChecklistToggle-" + id.uuidString)
                        titleInput(text: itemTitle(id), id: id, label: "Checklist item",
                                   identifier: "checklistItem-" + id.uuidString) { advance(after: id) }
                        Button(role: .destructive) {
                            items.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus.circle").frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).foregroundStyle(.red)
                            .disabled(composingID != nil)
                            .accessibilityLabel("Remove " + item.title)
                            .accessibilityIdentifier("removeChecklistItem-" + id.uuidString)
                    }
                }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            Section {
                HStack {
                    titleInput(text: $newTitle, id: newID, label: "Add checklist item", identifier: "newChecklistItem") {
                        addEntry()
                        focus = FocusRequest(field: newID)
                    }
                    Button {
                        addEntry()
                        focus = FocusRequest(field: newID)
                    } label: {
                        Image(systemName: "plus.circle.fill").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(.tint)
                        .accessibilityLabel("Add checklist item")
                        .accessibilityIdentifier("addChecklistItem")
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || composingID != nil)
                }
            } footer: { Text("Next adds a nonempty entry. Done saves your checklist changes.") }
        }
    }

    private func itemTitle(_ id: UUID) -> Binding<String> {
        Binding(get: { items.first { $0.id == id }?.title ?? "" }, set: { title in
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].title = title
            }
        })
    }

    private func titleInput(text: Binding<String>, id: UUID, label: String, identifier: String,
                            next: @escaping () -> Void) -> some View {
        NativeFieldInput(text: text, composing: Binding(
            get: { composingID == id },
            set: { marked in
                if marked { composingID = id } else if composingID == id { composingID = nil }
            }
        ), editorID: id, title: false, editable: !model.isBusy, focusOnAppear: false,
           accessibilityID: identifier, focusRequest: focus?.field == id ? focus?.token : nil,
           fieldLabel: label, next: next)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            focus = FocusRequest(field: id)
        })
        .overlay(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(label).foregroundStyle(.tertiary).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    private func advance(after id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let next = items.index(after: index)
        focus = FocusRequest(field: next == items.endIndex ? newID : items[next].id)
    }

    private func addEntry() {
        guard composingID == nil else { return }
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        items.append(ChecklistItem(title: title))
        newTitle = ""
    }

    private func saveDraft() {
        switch request.kind {
        case .priority: break
        case .progress: submit(.progress(Int(progress)))
        case .tags: submit(.tags(tagIDs))
        case .checklist:
            guard composingID == nil else { return }
            addEntry()
            submit(.checklist(items))
        }
    }

    private func submit(_ change: TaskMetadataChange) {
        Task {
            error = await model.saveTaskMetadata(change, taskID: request.task.id, expected: request.revision)
            if error == nil { dismiss() }
        }
    }
}
