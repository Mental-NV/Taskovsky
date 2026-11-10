import SwiftUI
import TaskovskyDomain

struct TaskBatchSheet: View {
    let scope: String
    let tasks: [TaskItem]
    let lists: [TaskList]
    let tags: [TaskTag]
    let calendar: Calendar
    let save: (TaskBatchEdit) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<UUID> = []
    @State private var choosingAction = false
    @State private var kind: TaskBatchEdit.Kind?
    @State private var date: Date
    @State private var clearDate = false
    @State private var priority: TaskPriority = .none
    @State private var tagIDs: Set<UUID> = []
    @State private var removeTags = false
    @State private var listID: UUID?
    @State private var confirmingTrash = false
    @State private var busy = false
    @State private var error: String?

    init(scope: String, tasks: [TaskItem], lists: [TaskList], tags: [TaskTag], calendar: Calendar,
         today: Date, save: @escaping (TaskBatchEdit) async -> String?) {
        self.scope = scope
        self.tasks = tasks
        self.lists = lists
        self.tags = tags
        self.calendar = calendar
        self.save = save
        _date = State(initialValue: today)
    }

    private var selected: [TaskItem] { tasks.filter { selection.contains($0.id) } }
    private var available: [TaskBatchEdit.Kind] {
        TaskBatchEdit.Kind.allCases.filter { $0.isAvailable(for: selected, lists: lists) && ($0 != .tags || !tags.isEmpty) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("batchError")
                }
                if let kind {
                    actionFields(kind)
                } else if choosingAction {
                    Section("Choose an action for \(selected.count) selected") {
                        ForEach(available, id: \.self) { action in
                            Button(action.title) { kind = action }
                                .accessibilityIdentifier(action.identifier)
                        }
                    }
                } else {
                    Section("\(scope) · \(selection.count) selected") {
                        ForEach(TaskHierarchy.displayOrder(tasks), id: \.task.id) { task, depth in
                            selectionRow(task, depth: depth)
                        }
                    }
                }
            }
            .navigationTitle(kind?.title ?? (choosingAction ? "Batch Actions" : "Select Tasks"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(choosingAction ? "Back" : "Cancel") { goBack() }
                        .disabled(busy).accessibilityIdentifier("batchBack")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let kind {
                        Button("Apply") {
                            if kind == .trash { confirmingTrash = true }
                            else { apply() }
                        }
                        .disabled(busy || (kind == .tags && tagIDs.isEmpty))
                        .accessibilityIdentifier("batchApply")
                    } else if !choosingAction {
                        Button("Choose Action") { choosingAction = true }
                            .disabled(selection.isEmpty).accessibilityIdentifier("batchChooseAction")
                    }
                }
            }
            .alert("Move selected items to Trash?", isPresented: $confirmingTrash) {
                Button("Cancel", role: .cancel) {}
                Button("Move to Trash", role: .destructive) { apply() }
            } message: {
                Text("Subtasks follow their selected parent. You can restore items from Trash.")
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .interactiveDismissDisabled(busy)
        #if os(macOS)
        .frame(minWidth: 390, idealWidth: 460, minHeight: 420)
        #endif
    }

    private func selectionRow(_ task: TaskItem, depth: Int) -> some View {
        let checked = selection.contains(task.id)
        return Button {
            if checked { selection.remove(task.id) }
            else { selection.insert(task.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).foregroundStyle(.primary)
                    if let list = lists.first(where: { $0.id == task.listID }) {
                        Text(list.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.leading, CGFloat(min(4, depth)) * 14)
            .frame(minHeight: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityAddTraits(checked ? .isSelected : [])
        .accessibilityIdentifier("batchTask-" + task.id.uuidString)
    }

    @ViewBuilder private func actionFields(_ kind: TaskBatchEdit.Kind) -> some View {
        Section("\(selected.count) selected") {
            switch kind {
            case .schedule:
                Toggle("Clear Date", isOn: $clearDate).accessibilityIdentifier("batchClearDate")
                if !clearDate {
                    DatePicker("Start Date", selection: $date, displayedComponents: .date)
                        .accessibilityIdentifier("batchStartDate")
                }
                Text(clearDate
                     ? "Clearing the date also removes the scheduled range, reminders and recurrence."
                     : "Timed tasks keep their start time in this view. Date ranges move together.")
                    .foregroundStyle(.secondary)
            case .priority:
                ForEach(TaskPriority.allCases.reversed(), id: \.self) { value in
                    choice(value == .none ? "None" : value.rawValue.capitalized, checked: priority == value,
                           identifier: "batchPriority-" + value.rawValue) { priority = value }
                }
            case .tags:
                Toggle("Remove Selected Tags", isOn: $removeTags)
                    .accessibilityIdentifier("batchRemoveTags")
                ForEach(tags) { tag in
                    choice(tag.name, checked: tagIDs.contains(tag.id), identifier: "batchTag-" + tag.id.uuidString) {
                        if tagIDs.contains(tag.id) { tagIDs.remove(tag.id) }
                        else { tagIDs.insert(tag.id) }
                    }
                }
            case .move:
                choice("Inbox", checked: listID == nil, identifier: "batchMoveInbox") { listID = nil }
                ForEach(lists.filter { !$0.isArchived }) { list in
                    choice(list.name, checked: listID == list.id, identifier: "batchList-" + list.id.uuidString) { listID = list.id }
                }
                Text("Subtasks follow their selected parent.").foregroundStyle(.secondary)
            case .complete:
                Text("Active subtasks follow their selected parent. Repeating tasks follow their usual recurrence rules.")
            case .trash:
                Text("The selected items and their subtasks can be restored from Trash.")
            }
        }
    }

    private func choice(_ name: String, checked: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                Spacer()
                if checked { Image(systemName: "checkmark").accessibilityHidden(true) }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func goBack() {
        error = nil
        if kind != nil { kind = nil }
        else if choosingAction { choosingAction = false }
        else { dismiss() }
    }

    private func apply() {
        guard !busy, let kind else { return }
        let action: TaskBatchEdit.Action = switch kind {
        case .schedule: .schedule(clearDate ? nil : date)
        case .priority: .priority(priority)
        case .tags: .tags(tags.filter { tagIDs.contains($0.id) }.map(\.id), remove: removeTags)
        case .move: .move(listID)
        case .complete: .complete
        case .trash: .trash
        }
        let edit = TaskBatchEdit(ids: selected.map(\.id), action: action)
        error = nil
        busy = true
        Task {
            error = await save(edit)
            busy = false
            if error == nil { dismiss() }
        }
    }
}

private extension TaskBatchEdit.Kind {
    var title: String {
        switch self {
        case .schedule: "Change Date"
        case .priority: "Set Priority"
        case .tags: "Edit Tags"
        case .move: "Move to List"
        case .complete: "Complete Tasks"
        case .trash: "Move to Trash"
        }
    }

    var identifier: String {
        switch self {
        case .schedule: "batchSchedule"
        case .priority: "batchPriority"
        case .tags: "batchTags"
        case .move: "batchMove"
        case .complete: "batchComplete"
        case .trash: "batchTrash"
        }
    }
}

extension TaskBatchRefusal {
    var batchMessage: String {
        switch self {
        case .invalidSelection: "Select tasks again. The previous selection is no longer available."
        case .readOnlyRecord: "This action is unavailable for one or more selected items."
        case .unavailableList: "Choose Inbox or an active list."
        case .unavailableTag: "Choose tags that still exist in this workspace."
        case .invalidSchedule: "One or more selected tasks have a schedule that could not be changed."
        }
    }
}
