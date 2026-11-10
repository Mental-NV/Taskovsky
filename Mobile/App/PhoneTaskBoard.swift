import CoreTransferable
import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace
import UniformTypeIdentifiers

struct PhoneListModeControl: View {
    @ObservedObject var model: PhoneWorkspaceModel
    let list: TaskList
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("List view", selection: Binding(get: { list.viewMode }, set: select)) {
                ForEach(TaskListViewMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(list.isArchived || !model.canBeginEditing)
            .accessibilityIdentifier("listViewMode")
            if let error {
                Text(error).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("listViewModeError")
            }
        }
        .padding(.horizontal, 16)
    }

    private func select(_ mode: TaskListViewMode) {
        guard let revision = model.document?.revision else { return }
        Task { error = await model.saveOrganization(.setListViewMode(list.id, mode), expected: revision) }
    }
}

private struct PhoneBoardDrag: Codable, Transferable {
    let session: UUID
    let listID: UUID
    let taskID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "local.taskovsky.board-card"))
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
        let title = Button { openTask(task.id) } label: {
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
