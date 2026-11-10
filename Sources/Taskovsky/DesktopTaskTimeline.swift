import SwiftUI
import TaskovskyCore

struct DesktopTaskTimeline: View {
    @ObservedObject var store: TaskStore
    let scope: TaskTimelineScope
    let now: Date
    let open: (UUID) -> Void
    @State private var request: ScheduleRequest?
    @State private var captureRequest: CaptureRequest?
    @State private var gesture: GestureRequest?
    @State private var undo: CalendarScheduleUndo?
    @State private var notice: String?

    private struct ScheduleRequest: Identifiable {
        var id: UUID { draft.id }
        let taskID: UUID
        let before: CalendarScheduleSnapshot
        let draft: CalendarEditorDraft
    }

    private struct CaptureRequest: Identifiable {
        let id = UUID()
        let destination: TaskDestination
        let day: Date
        let listID: UUID?
    }

    private struct GestureRequest {
        let taskID: UUID
        let before: CalendarScheduleSnapshot
        let operation: CalendarScheduleOperation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let notice {
                HStack {
                    Text(notice).font(.caption)
                    if let undo {
                        Button("Undo") {
                            self.notice = store.undoCalendarSchedule(undo) ? "Schedule restored" : "Schedule changed since this edit"
                            self.undo = nil
                        }
                    }
                }.padding(.horizontal, 16)
            }
            TaskTimelineView(scope: scope, data: store.data, now: now, calendar: store.settings.calendar,
                             color: Color.init(hex:), open: open, arrange: edit,
                             capture: store.needsRecovery ? nil : beginCapture,
                             beginAdjustment: store.needsRecovery ? nil : beginAdjustment,
                             arrangement: store.needsRecovery ? nil : TaskTimelineArrangeControls(drop: arrangeByDrop))
        }
        .sheet(item: $request) { request in
            CalendarTaskEditor(draft: request.draft, lists: [], calendar: store.settings.calendar,
                               removeDate: {
                commit(.unschedule, taskID: request.taskID, before: request.before)
                self.request = nil
            }) { draft in
                if draft.restoreOccurrence { commit(.restoreOccurrence, taskID: request.taskID, before: request.before) }
                else if let operation = draft.schedule.operation {
                    commit(operation, taskID: request.taskID, before: request.before, scope: draft.scope)
                }
                self.request = nil
            }
        }
        .sheet(item: $captureRequest) { request in
            let available = store.data.lists.filter { !$0.isArchived && $0.kind == .task }
            DesktopTimelineCapture(day: request.day, calendar: store.settings.calendar, listID: request.listID,
                                   selectableLists: filterCapture(request.destination) ? available : nil) { title, listID in
                guard scope.captureDestinations(in: store.data).contains(request.destination) else {
                    return "The destination changed. Open a new capture."
                }
                guard let taskID = store.createTimelineTask(title: title, on: request.day, listID: listID) else {
                    return store.storageError ?? "Could not add the task to this list."
                }
                notice = "Task added to Timeline"
                if case .filter(let id) = scope,
                   let task = store.data.tasks.first(where: { $0.id == taskID }),
                   store.data.filters.first(where: { $0.id == id })?.matches(task, lists: store.data.lists, now: now, calendar: store.settings.calendar) == false {
                    notice = "Task added. It does not match this filter."
                }
                return nil
            }
        }
        .confirmationDialog("Apply schedule change to", isPresented: Binding(get: { gesture != nil }, set: {
            if !$0 { gesture = nil }
        }), titleVisibility: .visible, presenting: gesture) { change in
            Button("This occurrence") { confirm(change, scope: .currentOccurrence) }
            Button("Series") { confirm(change, scope: .series) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func edit(_ id: UUID, _ focus: Date) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        let draft = CalendarEditorDraft(taskID: id, title: task.title,
            schedule: CalendarScheduleDraft(task: task, focus: focus, hourly: false, calendar: store.settings.calendar),
            listID: task.listID,
            canRescheduleOccurrence: CalendarScheduling.canRescheduleCurrentOccurrence(task, in: store.data.tasks),
            hasOccurrenceOverride: task.originalOccurrenceSchedule != nil)
        request = ScheduleRequest(taskID: id, before: CalendarScheduleSnapshot(task), draft: draft)
    }

    private func filterCapture(_ destination: TaskDestination) -> Bool {
        if case .filter = destination { return true }
        return false
    }

    private func beginCapture(_ destination: TaskDestination, _ day: Date) {
        let listID: UUID?
        if case .list(let id) = destination { listID = id }
        else {
            listID = store.data.lists.first {
                $0.id == store.settings.defaultListID && !$0.isArchived && $0.kind == .task
            }?.id
        }
        captureRequest = CaptureRequest(destination: destination, day: day, listID: listID)
    }

    private func arrangeByDrop(_ payload: TaskTimelineArrangeDrag, _ operation: CalendarScheduleOperation) -> Bool {
        guard let task = store.data.tasks.first(where: { $0.id == payload.taskID }),
              task.updatedAt == payload.updatedAt, task.dueDate == nil,
              task.completedAt == nil, task.wontDoAt == nil, task.deletedAt == nil,
              !SmartListEligibility.isArchived(task, lists: store.data.lists) else { return false }
        return commit(operation, taskID: task.id, before: CalendarScheduleSnapshot(task))
    }

    private func beginAdjustment(_ id: UUID) -> ((CalendarScheduleOperation) -> Void)? {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return nil }
        let before = CalendarScheduleSnapshot(task)
        let completedAt = task.completedAt, wontDoAt = task.wontDoAt
        return { operation in
            guard self.gesture == nil,
                  let current = store.data.tasks.first(where: { $0.id == id }),
                  current.completedAt == completedAt, current.wontDoAt == wontDoAt,
                  CalendarScheduleSnapshot(current) == before else { return }
            let change = GestureRequest(taskID: id, before: before, operation: operation)
            if CalendarScheduling.canRescheduleCurrentOccurrence(current, in: store.data.tasks) { gesture = change }
            else { confirm(change, scope: .series) }
        }
    }

    private func confirm(_ change: GestureRequest, scope: CalendarScheduleScope) {
        gesture = nil
        commit(change.operation, taskID: change.taskID, before: change.before, scope: scope)
    }

    @discardableResult private func commit(_ operation: CalendarScheduleOperation, taskID: UUID, before: CalendarScheduleSnapshot,
                        scope: CalendarScheduleScope = .series) -> Bool {
        guard let task = store.data.tasks.first(where: { $0.id == taskID }),
              CalendarScheduleSnapshot(task) == before else {
            notice = "Schedule changed. Review the current task and try again."
            return false
        }
        if let token = store.scheduleOnCalendar(id: taskID, operation: operation, scope: scope) {
            undo = token
            notice = scope == .currentOccurrence ? "This occurrence updated" : "Schedule updated"
            return true
        }
        notice = store.storageError ?? "Schedule unchanged"
        return false
    }
}

private struct DesktopTimelineCapture: View {
    @Environment(\.dismiss) private var dismiss
    let day: Date
    let calendar: Calendar
    @State var listID: UUID?
    let selectableLists: [TaskList]?
    let save: (String, UUID?) -> String?
    @State private var title = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Timeline task").font(.title3.bold())
            Text(day.formatted(Date.FormatStyle(date: .complete, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)))
                .foregroundStyle(.secondary)
            TextField("Task title", text: $title).focused($focused).accessibilityIdentifier("timelineCaptureTitle")
            if let selectableLists {
                Picker("List", selection: $listID) {
                    Text("Inbox").tag(UUID?.none)
                    ForEach(selectableLists) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Task") {
                    error = save(title, listID)
                    if error == nil { dismiss() }
                }.keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(22).frame(width: 360).onAppear { focused = true }
    }
}
