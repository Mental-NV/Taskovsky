import SwiftUI
import UIKit
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
    @State private var metadataRequest: PhoneTaskMetadataRequest?
    @State private var hierarchyRequest: PhoneTaskHierarchyRequest?
    @State private var relatedTasks: [UUID] = []
    @State private var checklistError: String?
    private var taskID: UUID { relatedTasks.last ?? route.id }
    private var current: TaskItem? { model.document?.snapshot.workspace.tasks.first { $0.id == taskID } }
    private var writable: Bool {
        guard let task = current, let data = model.document?.snapshot.workspace else { return false }
        return model.canBeginEditing && task.deletedAt == nil && !SmartListEligibility.isArchived(task, lists: data.lists)
    }
    private var editor: Binding<TaskFieldDraft?> {
        Binding(get: { !route.preferEditor && model.activeDraft?.taskID == taskID ? model.activeDraft : nil },
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
    @ViewBuilder private func description(_ task: TaskItem) -> some View {
        let preview = task.richBody.flatMap { RichDescriptionPreview(body: task.body, rich: $0) }
        if let preview, task.richBody?.isEmpty == false {
            PhoneFoldableRichDescription(preview: preview, revision: task.updatedAt,
                                         clipboardSession: model.isQA ? model.directory?.lastPathComponent : nil).id(task.id)
        } else {
            if task.richBody != nil, preview == nil {
                Text("This formatting cannot be displayed. The saved description is shown below.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("richDescriptionFallback")
            }
            Text(task.body.isEmpty ? "No description" : task.body)
                .accessibilityIdentifier("taskDescription").textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                        PhoneScheduleFeedback(model: model, surface: .tasks)
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
                            progressRow(task)
                        }
                        description(task)
                        Button("Edit description") { Task { await model.begin(taskID: task.id, field: .plainBody) } }
                            .disabled(!writable || task.richBody != nil).frame(minHeight: 44)
                        if (try? RichBodyEdit.applying([], to: task.body, rich: task.richBody)) != nil {
                            Button("Format description") { Task { await model.begin(taskID: task.id, field: .richBody) } }
                                .disabled(!writable).frame(minHeight: 44).accessibilityIdentifier("editRichDescription")
                        }
                        metadata(task, data: data)
                        if task.kind == .task || task.parentID != nil {
                            PhoneTaskHierarchy(model: model, task: task, data: data, writable: writable,
                                               navigate: openRelatedTask) { kind in
                                guard let revision = model.document?.revision else { return }
                                hierarchyRequest = PhoneTaskHierarchyRequest(task: task, revision: revision, kind: kind)
                            }
                        }
                        if let error = model.editorError, model.activeDraft == nil { Text(error).font(.footnote).foregroundStyle(.secondary) }
                    }.padding(20)
                } else { ContentUnavailableView("Task unavailable", systemImage: "doc.questionmark", description: Text("Any saved edit is kept separately.")) }
            }.id(taskID).toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        if !relatedTasks.isEmpty {
                            Button { openRelatedTask(relatedTasks.dropLast().last ?? route.id) } label: {
                                Image(systemName: "chevron.backward")
                            }.accessibilityLabel("Previous task").accessibilityIdentifier("relatedTaskBack")
                                .disabled(model.isBusy)
                        }
                        Button { showActions = true } label: { Image(systemName: "ellipsis") }
                            .accessibilityLabel("Task actions").accessibilityIdentifier("taskActions")
                            .disabled(!model.canBeginEditing || current == nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close).disabled(model.isBusy).accessibilityIdentifier("taskDetailDone")
                }
            }
            .sheet(item: $metadataRequest) { request in
                PhoneTaskMetadataSheet(model: model, request: request)
            }
            .sheet(item: $hierarchyRequest) { request in
                PhoneTaskHierarchySheet(model: model, request: request)
            }
            .sheet(item: $scheduleRequest) { request in
                PhoneScheduleSheet(model: model, request: request)
            }
            .sheet(isPresented: $showActions, onDismiss: {
                if current == nil {
                    if relatedTasks.isEmpty { close() }
                    else { openRelatedTask(relatedTasks.dropLast().last ?? route.id) }
                }
            }) {
                PhoneTaskActions(model: model, taskID: taskID, openDuplicate: openRelatedTask)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func openRelatedTask(_ id: UUID) {
        guard id != taskID else { return }
        checklistError = nil
        if id == route.id { relatedTasks = [] }
        else if let index = relatedTasks.firstIndex(of: id) {
            relatedTasks = Array(relatedTasks.prefix(through: index))
        } else {
            relatedTasks.append(id)
        }
    }

    private func openMetadata(_ kind: PhoneTaskMetadataKind, task: TaskItem) {
        guard let revision = model.document?.revision else { return }
        metadataRequest = PhoneTaskMetadataRequest(task: task, revision: revision, kind: kind)
    }

    @ViewBuilder private func progressRow(_ task: TaskItem) -> some View {
        let indicator = HStack(spacing: 8) {
            ProgressView(value: Double(task.progressPercent), total: 100)
                .progressViewStyle(.linear).accessibilityHidden(true)
            Text("\(task.progressPercent)%").monospacedDigit().foregroundStyle(.secondary)
        }
        if task.canEditManualProgress {
            Button { openMetadata(.progress, task: task) } label: {
                indicator.frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(!writable)
            .accessibilityLabel("Set task progress").accessibilityValue("\(task.progressPercent)%")
            .accessibilityIdentifier("editTaskProgress")
        } else {
            indicator.accessibilityElement(children: .ignore)
                .accessibilityLabel(task.checklist.isEmpty ? "Task progress" : "Task progress from checklist")
                .accessibilityValue("\(task.progressPercent)%")
                .accessibilityIdentifier("taskProgressSummary")
        }
    }

    private func metadata(_ task: TaskItem, data: WorkspaceData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataButton("Priority", detail: task.priority.phoneLabel, symbol: task.priority == .none ? "flag" : "flag.fill",
                           identifier: "editTaskPriority") { openMetadata(.priority, task: task) }
            let names = task.tagIDs.compactMap { id in data.tags.first { $0.id == id }?.name }
            let extra = task.tagIDs.count - names.count
            let labels = names + (extra > 0 ? ["\(extra) unavailable"] : [])
            metadataButton("Tags", detail: labels.isEmpty ? "None" : labels.joined(separator: ", "),
                           symbol: "tag", identifier: "editTaskTags") { openMetadata(.tags, task: task) }
            if task.kind == .task || !task.checklist.isEmpty {
                let editable = task.kind == .task && writable && Set(task.checklist.map(\.id)).count == task.checklist.count
                HStack {
                    Text("Checklist").font(.headline)
                    Spacer()
                    Text("\(task.checklist.filter(\.isCompleted).count) of \(task.checklist.count)").foregroundStyle(.secondary)
                    if task.kind == .task {
                        Button(task.checklist.isEmpty ? "Add" : "Edit") { openMetadata(.checklist, task: task) }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(task.checklist.isEmpty ? "Add checklist items" : "Edit checklist")
                            .accessibilityIdentifier("editTaskChecklist")
                            .disabled(!editable)
                    }
                }
                ForEach(task.checklist.indices, id: \.self) { index in
                    let item = task.checklist[index]
                    Button {
                        guard let revision = model.document?.revision else { return }
                        Task {
                            checklistError = await model.saveTaskMetadata(
                                .setChecklistCompleted(id: item.id, completed: !item.isCompleted),
                                taskID: task.id, expected: revision)
                        }
                    } label: {
                        Label(item.title, systemImage: item.isCompleted ? "checkmark.square" : "square")
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!editable)
                    .accessibilityLabel((item.isCompleted ? "Uncheck " : "Check ") + item.title)
                    .accessibilityValue(item.isCompleted ? "Checked" : "Unchecked")
                    .accessibilityIdentifier("checklistToggle-" + item.id.uuidString)
                }
                if let checklistError {
                    Text(checklistError).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("checklistError")
                }
            }
        }
    }

    private func metadataButton(_ title: String, detail: String, symbol: String,
                                identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: symbol)
                Spacer()
                Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(title).accessibilityValue(detail).accessibilityIdentifier(identifier)
            .disabled(!writable)
    }

}

struct PhoneCompletionButton: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let task: TaskItem
    let lists: [TaskList]
    var isSubtaskRow = false
    @State private var progressRequest: PhoneTaskMetadataRequest?

    var body: some View {
        let revision = model.document?.revision
        let isHistory = task.completedAt != nil || task.wontDoAt != nil
        let command: TaskLifecycleCommand = isHistory ? .reopen : .complete
        let symbol = task.kind == .note ? "doc.text" : task.completedAt != nil ? "checkmark.square" :
            task.wontDoAt != nil ? "xmark.square" : "square"
        let icon = Image(systemName: symbol).font(.system(size: 17))
            .foregroundStyle(isHistory || task.kind == .note ? .secondary : task.priority.phoneColor)
            .frame(width: 44, height: 44).contentShape(Rectangle())
        if TaskLifecycle.refusal(for: command, task: task, lists: lists) == nil {
            Button {
                guard let revision else { return }
                Task {
                    await model.performLifecycle(command, taskID: task.id, expected: revision, fromSubtaskRow: isSubtaskRow)
                }
            } label: { icon }
                .buttonStyle(.plain)
                .disabled(!model.canBeginEditing)
                .accessibilityLabel((isHistory ? "Reopen " : "Complete ") + task.title)
                .accessibilityIdentifier((isSubtaskRow ? "subtaskToggle-" : "lifecycleToggle-") + task.id.uuidString)
                .contextMenu {
                    if task.canEditManualProgress, let revision {
                        Button("Set Progress", systemImage: "chart.bar") {
                            progressRequest = PhoneTaskMetadataRequest(task: task, revision: revision, kind: .progress)
                        }
                    }
                }
                .sheet(item: $progressRequest) { request in
                    PhoneTaskMetadataSheet(model: model, request: request)
                }
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

enum PhoneTaskSwipeEdge { case leading, trailing }

struct PhoneTaskSwipeSelection: Equatable {
    let taskID: UUID
    let edge: PhoneTaskSwipeEdge
}

struct PhoneTaskSwipeAction: Identifiable {
    enum Kind: String {
        case complete, reopen, restore, schedule, priority, move, trash

        var title: String {
            switch self {
            case .complete: "Complete"
            case .reopen: "Reopen"
            case .restore: "Restore"
            case .schedule: "Schedule"
            case .priority: "Priority"
            case .move: "Move to List"
            case .trash: "Move to Trash"
            }
        }

        var icon: String {
            switch self {
            case .complete: "checkmark"
            case .reopen, .restore: "arrow.uturn.backward"
            case .schedule: "calendar"
            case .priority: "flag"
            case .move: "folder"
            case .trash: "trash"
            }
        }

        var color: Color {
            switch self {
            case .complete, .reopen, .restore: .green
            case .schedule: .blue
            case .priority: .orange
            case .move: .indigo
            case .trash: .red
            }
        }
    }

    let id: Kind
    let run: () -> Void
    var title: String { id.title }
}

struct PhoneTaskSwipeRow<Content: View>: View {
    let taskID: UUID
    let leading: [PhoneTaskSwipeAction]
    let trailing: [PhoneTaskSwipeAction]
    @Binding var selection: PhoneTaskSwipeSelection?
    @ViewBuilder let content: (PhoneRowHorizontalPan) -> Content
    @Environment(\.layoutDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var translation: CGFloat = 0
    private let actionWidth: CGFloat = 64

    private var sign: CGFloat { direction == .leftToRight ? 1 : -1 }
    private var leadingWidth: CGFloat { CGFloat(leading.count) * actionWidth }
    private var trailingWidth: CGFloat { CGFloat(trailing.count) * actionWidth }
    private var selected: Bool { selection?.taskID == taskID }
    private var rest: CGFloat {
        guard selected else { return 0 }
        return selection?.edge == .leading ? leadingWidth : -trailingWidth
    }
    private var offset: CGFloat { min(leadingWidth, max(-trailingWidth, rest + translation)) }

    var body: some View {
        content(PhoneRowHorizontalPan(track: track))
            .background(offset == 0 ? .clear : PhoneStyle.card)
            .offset(x: offset * sign)
            .overlay(alignment: offset >= 0 ? .leading : .trailing) {
                if offset != 0 {
                    HStack(spacing: 0) {
                        ForEach(offset > 0 ? leading : trailing) { action in
                            Button {
                                selection = nil
                                action.run()
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: action.id.icon).font(.subheadline)
                                    Text(action.id == .move ? "Move" : action.id == .trash ? "Trash" : action.title)
                                        .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(width: actionWidth).frame(maxHeight: .infinity)
                                .foregroundStyle(.white)
                                .background(action.id.color)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(action.title)
                            .accessibilityIdentifier("taskSwipe-" + action.id.rawValue)
                        }
                    }
                    .frame(width: abs(offset), alignment: offset > 0 ? .leading : .trailing)
                    .clipped()
                    .allowsHitTesting(selected && translation == 0)
                    .accessibilityHidden(!selected)
                }
            }
            .clipped()
            .onDisappear { if selected { selection = nil } }
    }

    private func track(_ distance: CGFloat, _ state: UIGestureRecognizer.State) {
        let movement = distance * sign
        switch state {
        case .began, .changed:
            translation = movement
        case .ended:
            let ending = rest + movement
            let edge: PhoneTaskSwipeEdge = ending >= 0 ? .leading : .trailing
            let width = edge == .leading ? leadingWidth : trailingWidth
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                translation = 0
                selection = width > 0 && abs(ending) >= min(44, width / 2)
                    ? PhoneTaskSwipeSelection(taskID: taskID, edge: edge) : nil
            }
        default:
            translation = 0
        }
    }
}

/// Limit the horizontal recognizer to the title so the checkbox and grip keep their own gestures.
struct PhoneRowHorizontalPan: UIViewRepresentable {
    let track: (CGFloat, UIGestureRecognizer.State) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        anchor.moved = { [weak coordinator = context.coordinator] anchor in
            coordinator?.attach(to: anchor)
        }
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        context.coordinator.track = track
        context.coordinator.attach(to: anchor)
    }

    static func dismantleUIView(_ anchor: Anchor, coordinator: Coordinator) {
        anchor.moved = nil
        coordinator.detach()
    }

    final class Anchor: UIView {
        var moved: ((Anchor) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            moved?(self)
        }
    }

    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var track: ((CGFloat, UIGestureRecognizer.State) -> Void)?
        private weak var anchor: Anchor?
        private weak var scroll: UIScrollView?
        private lazy var pan: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan))
            gesture.delegate = self
            gesture.maximumNumberOfTouches = 1
            return gesture
        }()

        func attach(to anchor: Anchor) {
            self.anchor = anchor
            var ancestor = anchor.window == nil ? nil : anchor.superview
            while let current = ancestor, !(current is UIScrollView) { ancestor = current.superview }
            let list = ancestor as? UIScrollView
            guard list !== scroll else { return }
            detach()
            scroll = list
            list?.addGestureRecognizer(pan)
        }

        func detach() {
            scroll?.removeGestureRecognizer(pan)
            scroll = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let anchor else { return false }
            return anchor.bounds.contains(touch.location(in: anchor))
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let movement = pan.translation(in: scroll)
            return abs(movement.x) > 1.5 * abs(movement.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other === scroll?.panGestureRecognizer
        }

        @objc private func didPan() {
            track?(pan.translation(in: scroll).x, pan.state)
        }
    }
}

struct PhoneTaskMoveRequest: Identifiable {
    let task: TaskItem
    let revision: WorkspaceRevision
    var id: UUID { task.id }
}

enum PhoneTaskRowEditor: Identifiable {
    case schedule(PhoneScheduleRequest)
    case priority(PhoneTaskMetadataRequest)
    case move(PhoneTaskMoveRequest)

    var id: UUID {
        switch self {
        case .schedule(let request): request.id
        case .priority(let request): request.id
        case .move(let request): request.id
        }
    }
}

struct PhoneTaskMoveSheet: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneTaskMoveRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PhoneTaskMoveChoices(model: model, request: request) { dismiss() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.disabled(model.isBusy)
                    }
                }
        }.interactiveDismissDisabled(model.isBusy)
    }
}

private struct PhoneTaskMoveChoices: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneTaskMoveRequest
    let moved: () -> Void

    var body: some View {
        List {
            moveTarget("Inbox", id: nil)
            ForEach((model.document?.snapshot.workspace.lists ?? []).filter { !$0.isArchived }) { list in
                moveTarget(list.name, id: list.id)
            }
            PhoneLifecycleFeedback(model: model)
        }.navigationTitle("Move to List")
    }

    private func moveTarget(_ title: String, id: UUID?) -> some View {
        Button(title) {
            Task {
                if await model.performLifecycle(.move(id), taskID: request.task.id, expected: request.revision) { moved() }
            }
        }.disabled(!model.canBeginEditing || request.task.listID == id)
    }
}

private struct PhoneTaskActions: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let taskID: UUID
    let openDuplicate: (UUID) -> Void
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
                                PhoneTaskMoveChoices(model: model, request: PhoneTaskMoveRequest(task: task, revision: document.revision)) {
                                    dismiss()
                                }
                            }
                        }
                        action("Duplicate", .duplicate(copyID: UUID()), task: task, document: document)
                        let kind: TaskKind = task.kind == .task ? .note : .task
                        action(kind == .note ? "Convert to Note" : "Convert to Task", .setKind(kind),
                               task: task, document: document)
                        action("Move to Trash", .trash, role: .destructive, task: task, document: document)
                        action("Restore", .restore, task: task, document: document)
                        if TaskLifecycle.refusal(for: .purge, task: task, lists: lists) == nil {
                            Button("Delete Forever", role: .destructive) {
                                purge = PurgeRequest(id: task.id, title: task.title, revision: document.revision)
                            }
                        }
                    }.disabled(!model.canBeginEditing)
                    if task.deletedAt == nil {
                        Section("Templates") {
                            NavigationLink("Save as Template") {
                                PhoneSaveTaskAsTemplate(model: model, task: task, revision: document.revision) { dismiss() }
                            }
                            if !SmartListEligibility.isArchived(task, lists: lists), !document.snapshot.workspace.templates.isEmpty {
                                NavigationLink("Apply Template") {
                                    PhoneApplyTaskTemplate(model: model, taskID: task.id, revision: document.revision) { dismiss() }
                                }
                            }
                        }.disabled(!model.canBeginEditing)
                    }
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

    private func run(_ command: TaskLifecycleCommand, revision: WorkspaceRevision) {
        Task {
            if await model.performLifecycle(command, taskID: taskID, expected: revision) {
                if case .duplicate(let copyID) = command { openDuplicate(copyID) }
                dismiss()
            }
        }
    }
}
