import CoreTransferable
import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace
import UniformTypeIdentifiers

struct PhoneListModeControl: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let list: TaskList
    @State private var error: String?
    @State private var manageSections = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("List view", selection: Binding(get: { list.isArchived && list.viewMode == .timeline ? .list : list.viewMode }, set: select)) {
                    ForEach(list.isArchived ? [.list, .board] : TaskListViewMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("listViewMode")
                if !list.isArchived {
                    Button { manageSections = true } label: {
                        Image(systemName: "list.bullet.indent").frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Manage Sections")
                }
            }.disabled(list.isArchived || !model.canBeginEditing)
            if let error {
                Text(error).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("listViewModeError")
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $manageSections) {
            PhoneTaskSectionsSheet(model: model, listID: list.id)
        }
    }

    private func select(_ mode: TaskListViewMode) {
        guard let revision = model.document?.revision else { return }
        Task { error = await model.saveOrganization(.setListViewMode(list.id, mode), expected: revision) }
    }
}

struct PhoneBoardDrag: Codable, Transferable {
    let session: UUID
    let listID: UUID?
    let taskID: UUID
    var revision: WorkspaceRevision? = nil

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "local.taskovsky.board-card"))
    }
}

private struct PhoneTaskSectionsSheet: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let listID: UUID

    var body: some View {
        if let list = model.document?.snapshot.workspace.lists.first(where: { $0.id == listID }) {
            TaskSectionOrganizer(list: list, editable: !list.isArchived && model.canBeginEditing) {
                await model.saveSection(.init(listID: listID, operation: $0))
            }
        } else {
            ContentUnavailableView("List unavailable", systemImage: "list.bullet")
        }
    }
}

struct PhoneTaskBoard: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let list: TaskList
    let data: WorkspaceData
    let openTask: (UUID) -> Void
    @State private var selected: BoardProjection.Column = .open
    @State private var dragSession = UUID()
    @State private var targeted: BoardProjection.Column?
    @State private var refusal: String?

    private typealias Column = BoardProjection.Column
    private var writable: Bool { !list.isArchived && model.canBeginEditing }

    var body: some View {
        let groups = BoardProjection.split(BoardProjection.tasks(forList: list.id, in: data))
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                columnTab(.open, count: groups.open.count)
                columnTab(.completed, count: groups.completed.count)
                columnTab(.wontDo, count: groups.wontDo.count)
            }
            .padding(4).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            if list.isArchived {
                Text("Archived list · Read only").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("boardArchiveNotice")
            }
            if let refusal {
                Text(refusal).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("boardMoveNotice")
            }
            TabView(selection: $selected) {
                column(.open, tasks: groups.open).tag(Column.open)
                column(.completed, tasks: groups.completed).tag(Column.completed)
                column(.wontDo, tasks: groups.wontDo).tag(Column.wontDo)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onChange(of: selected) { _, _ in refusal = nil }
    }

    private func columnTab(_ column: Column, count: Int) -> some View {
        let tab = Button { selected = column } label: {
            VStack(spacing: 3) {
                Text(column.title).font(.subheadline.weight(.semibold))
                Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(targeted == column ? Color.accentColor.opacity(0.2) :
                        selected == column ? Color.primary.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(column.title).accessibilityValue(count.formatted())
        .accessibilityAddTraits(selected == column ? .isSelected : [])
        .accessibilityIdentifier("boardColumn-" + column.rawValue)

        return tab.dropDestination(for: PhoneBoardDrag.self) { payloads, _ in
            guard payloads.count == 1, let drag = payloads.first, drag.listID == list.id, drag.session == dragSession else { return false }
            return move(drag.taskID, to: column)
        } isTargeted: { hovering in
            if hovering && writable { targeted = column }
            else if targeted == column { targeted = nil }
        }
    }

    private func column(_ column: Column, tasks: [TaskItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if tasks.isEmpty {
                    ContentUnavailableView("No " + column.title.lowercased() + " items", systemImage: "rectangle.stack")
                        .accessibilityIdentifier("boardEmpty-" + column.rawValue)
                }
                ForEach(tasks) { task in card(task) }
                Color.clear.frame(height: 90).accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        }
    }

    private func card(_ task: TaskItem) -> some View {
        HStack(spacing: 0) {
            PhoneCompletionButton(model: model, task: task, lists: data.lists)
            cardTitle(task)
            if writable && task.kind == .task {
                Menu {
                    ForEach(Column.allCases, id: \.self) { target in
                        if BoardProjection.move(task, to: target) != nil {
                            Button("Move to " + target.title) { _ = move(task.id, to: target) }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Change status of " + task.title)
                .accessibilityIdentifier("boardMove-" + task.id.uuidString)
            }
        }
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private func cardTitle(_ task: TaskItem) -> some View {
        let title = PhoneBoardTaskTitle(task: task, open: openTask)
        if writable { title.draggable(PhoneBoardDrag(session: dragSession, listID: list.id, taskID: task.id)) }
        else { title }
    }

    private func move(_ id: UUID, to target: Column) -> Bool {
        guard writable, let document = model.document,
              document.snapshot.workspace.lists.contains(where: { $0.id == list.id && !$0.isArchived && $0.viewMode == .board }),
              let task = document.snapshot.workspace.tasks.first(where: { $0.id == id && $0.listID == list.id && $0.deletedAt == nil })
        else { return false }
        if task.kind == .note && target != .open {
            refusal = "Notes stay in Open."
            return false
        }
        guard let command = BoardProjection.move(task, to: target) else { return false }
        refusal = nil
        Task {
            if await model.performLifecycle(command, taskID: task.id, expected: document.revision) {
                selected = target
            }
        }
        return true
    }
}

struct PhoneScopedTaskBoard: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let destination: TaskDestination
    let data: WorkspaceData
    let open: (UUID) -> Void
    let schedule: (UUID, CalendarScheduleOperation, WorkspaceRevision) -> Bool
    @State private var grouping: ScopedBoardGrouping
    @State private var selected: ScopedBoardColumn.ID?
    @State private var targeted: ScopedBoardColumn.ID?
    @State private var dragSession = UUID()
    @State private var choosingTask: (id: UUID, revision: WorkspaceRevision)?

    init(model: PhoneWorkspaceModel, destination: TaskDestination, data: WorkspaceData,
         open: @escaping (UUID) -> Void, schedule: @escaping (UUID, CalendarScheduleOperation, WorkspaceRevision) -> Bool) {
        self.model = model
        self.destination = destination
        self.data = data
        self.open = open
        self.schedule = schedule
        _grouping = State(initialValue: ScopedBoardProjection.defaultGrouping(for: destination))
    }

    private func projection(in workspace: WorkspaceData) -> ScopedBoardProjection {
        ScopedBoardProjection(destination: destination, grouping: grouping, in: workspace,
                              now: model.now, calendar: model.calendar)
    }

    var body: some View {
        let board = projection(in: data)
        let visible = board.columns.contains(where: { $0.id == selected }) ? selected : board.columns.first?.id
        VStack(spacing: 8) {
            Picker("Group board by", selection: $grouping) {
                ForEach(ScopedBoardGrouping.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("scopedBoardGrouping").padding(.horizontal, 16)
            PhoneScheduleFeedback(model: model, surface: .calendar).padding(.horizontal, 16)
            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(Array(board.columns.enumerated()), id: \.element.id) { index, column in
                            columnTab(column, index: index, selected: visible == column.id)
                                .id(column.id)
                        }
                    }.padding(.horizontal, 16)
                }.scrollIndicators(.hidden)
                    .onChange(of: visible) { _, column in
                        if let column { reader.scrollTo(column, anchor: .center) }
                    }
            }
            TabView(selection: Binding(get: { visible }, set: { selected = $0 })) {
                ForEach(board.columns) { column in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if column.tasks.isEmpty {
                                ContentUnavailableView("No items in " + column.title, systemImage: "rectangle.stack")
                            }
                            ForEach(column.tasks) { card($0, board: board) }
                            Color.clear.frame(height: 90).accessibilityHidden(true)
                        }.padding(.horizontal, 16)
                    }.tag(Optional(column.id))
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onChange(of: grouping) { _, _ in
            selected = nil
            targeted = nil
            dragSession = UUID()
        }
        .confirmationDialog("Move task", isPresented: Binding(get: { choosingTask != nil }, set: {
            if !$0 { choosingTask = nil }
        }), titleVisibility: .visible, presenting: choosingTask) { choice in
            ForEach(board.columns) { column in
                if board.move(choice.id, to: column.id) != nil {
                    Button("Move to " + column.title) {
                        _ = move(choice.id, to: column.id, expected: choice.revision)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func columnTab(_ column: ScopedBoardColumn, index: Int, selected isSelected: Bool) -> some View {
        Button { selected = column.id } label: {
            VStack(spacing: 3) {
                Text(column.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(column.tasks.count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal, 10).frame(minWidth: 90, minHeight: 48)
                .background(targeted == column.id ? Color.accentColor.opacity(0.2) :
                            isSelected ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 11))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(column.title).accessibilityValue(column.tasks.count.formatted())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("scopedBoardColumn-\(index)")
            .dropDestination(for: PhoneBoardDrag.self) { payloads, _ in
                guard payloads.count == 1, let drag = payloads.first, drag.session == dragSession,
                      let revision = drag.revision else { return false }
                return move(drag.taskID, to: column.id, expected: revision)
            } isTargeted: { hovering in
                if hovering && model.canBeginEditing { targeted = column.id }
                else if targeted == column.id { targeted = nil }
            }
    }

    private func card(_ task: TaskItem, board: ScopedBoardProjection) -> some View {
        let canMove = model.canBeginEditing && board.columns.contains { board.move(task.id, to: $0.id) != nil }
        return HStack(spacing: 0) {
            PhoneCompletionButton(model: model, task: task, lists: data.lists)
            PhoneBoardTaskTitle(task: task, open: open)
            if canMove, let revision = model.document?.revision {
                Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                    .frame(width: 36, height: 44).contentShape(Rectangle())
                    .accessibilityLabel("Drag " + task.title)
                    .draggable(PhoneBoardDrag(session: dragSession, listID: task.listID, taskID: task.id, revision: revision))
                Button { choosingTask = (task.id, revision) } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Move " + task.title)
            }
        }.padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func move(_ taskID: UUID, to target: ScopedBoardColumn.ID, expected: WorkspaceRevision) -> Bool {
        guard model.canBeginEditing, let document = model.document, expected == document.revision,
              let operation = projection(in: document.snapshot.workspace).move(taskID, to: target) else { return false }
        switch operation {
        case .list(let id):
            Task {
                if await model.performLifecycle(.move(id), taskID: taskID, expected: expected) {
                    selected = target
                }
            }
            return true
        case .schedule(let operation):
            let accepted = schedule(taskID, operation, expected)
            if accepted, let task = data.tasks.first(where: { $0.id == taskID }),
               !CalendarScheduling.canRescheduleCurrentOccurrence(task, in: data.tasks) {
                selected = target
            }
            return accepted
        }
    }
}

struct PhoneSectionBoard: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let list: TaskList
    let data: WorkspaceData
    let openTask: (UUID) -> Void
    let addTask: (UUID) -> Void
    @State private var selected: UUID?
    @State private var dragSession = UUID()
    @State private var refusal: String?

    private var writable: Bool { !list.isArchived && model.canBeginEditing }

    var body: some View {
        let groups = TaskSectionGroup.project(BoardProjection.tasks(forList: list.id, in: data), for: list, in: data)
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(groups) { group in tab(group) }
                }.padding(.horizontal, 16)
            }.scrollIndicators(.hidden)
            if let refusal {
                Text(refusal).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("boardMoveNotice")
            }
            if let group = groups.first(where: { $0.id == selected }) ?? groups.first {
                sectionColumn(group)
            }
        }
        .onChange(of: list.sections.map(\.id)) { _, ids in
            if let selected, !ids.contains(selected) { self.selected = nil }
        }
    }

    private func tab(_ group: TaskSectionGroup) -> some View {
        Button { selected = group.id; refusal = nil } label: {
            VStack(spacing: 3) {
                Text(group.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(group.tasks.count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).frame(minHeight: 48)
            .background(selected == group.id ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.title).accessibilityValue(group.tasks.count.formatted())
        .accessibilityAddTraits(selected == group.id ? .isSelected : [])
        .accessibilityIdentifier("boardSection-" + (group.id?.uuidString ?? "none"))
        .dropDestination(for: PhoneBoardDrag.self) { payloads, _ in
            guard writable, payloads.count == 1, let drag = payloads.first,
                  drag.session == dragSession, drag.listID == list.id else { return false }
            move(drag.taskID, to: group.id)
            return true
        }
    }

    private func sectionColumn(_ group: TaskSectionGroup) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let section = group.section, writable && model.canBeginCapture {
                    Button { addTask(section.id) } label: {
                        Label("Add task to " + section.name, systemImage: "plus").frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
                if group.tasks.isEmpty {
                    ContentUnavailableView("No tasks", systemImage: "rectangle.stack")
                }
                ForEach(TaskHierarchy.displayOrder(group.tasks), id: \.task.id) { entry in
                    HStack(spacing: 0) {
                        PhoneCompletionButton(model: model, task: entry.task, lists: data.lists)
                        title(entry.task)
                    }
                    .padding(.leading, CGFloat(min(entry.depth, 4)) * 14)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                Color.clear.frame(height: 90).accessibilityHidden(true)
            }.padding(.horizontal, 16)
        }
    }

    @ViewBuilder private func title(_ task: TaskItem) -> some View {
        let title = PhoneBoardTaskTitle(task: task, open: openTask)
        if writable && task.parentID == nil {
            HStack(spacing: 0) {
                title.contextMenu {
                    TaskSectionMoveMenu(sections: list.sections, current: task.sectionID) { target in
                        move(task.id, to: target)
                    }
                }
                PhoneSectionTaskGrip(task: task, session: dragSession, listID: list.id)
            }
        } else { title }
    }

    private func move(_ taskID: UUID, to sectionID: UUID?) {
        Task {
            refusal = await model.saveSection(.init(listID: list.id, operation: .assign(taskID: taskID, sectionID: sectionID)))
            if refusal == nil { selected = sectionID }
        }
    }
}

struct PhoneSectionTaskGrip: View {
    let task: TaskItem
    let session: UUID
    let listID: UUID

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary).frame(width: 44, height: 44)
            .contentShape(Rectangle()).accessibilityLabel("Drag " + task.title)
            .draggable(PhoneBoardDrag(session: session, listID: listID, taskID: task.id))
    }
}

private struct PhoneBoardTaskTitle: View {
    let task: TaskItem
    let open: (UUID) -> Void

    var body: some View {
        Button { open(task.id) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.body)
                if let due = task.dueDate {
                    Text(due.formatted(.dateTime.month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.trailing, 8).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityIdentifier("boardCard-" + task.id.uuidString)
    }
}
