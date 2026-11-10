import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

enum PhoneCalendarEditMode: String {
    case schedule = "Calendar Schedule"
    case move = "Move Schedule"
    case resize = "Resize Schedule"
    case resizeStart = "Resize Start"
}

struct PhoneCalendarEditRequest: Identifiable {
    var id: UUID { task.id }
    let task: TaskItem
    let expected: WorkspaceRevision
    let focus: Date
    let hourly: Bool
    let calendar: Calendar
    let mode: PhoneCalendarEditMode
}

struct PhoneCalendarFeedback: View {
    @ObservedObject var model: PhoneWorkspaceModel

    var body: some View {
        if let notice = model.calendarNotice {
            HStack {
                Text(notice).font(.footnote).accessibilityIdentifier("calendarScheduleNotice")
                if model.canUndoCalendar {
                    Button("Undo") { Task { await model.undoCalendarSchedule() } }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("undoCalendarSchedule")
                }
            }
        }
    }
}

struct PhoneCalendarArrangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let focus: Date
    let options: TaskCalendarOptions
    @State private var grouping = CalendarColorMode.list
    @State private var selection = CalendarArrangeSelection.calendar
    @State private var overdue = false
    @State private var request: PhoneCalendarEditRequest?
    @State private var taskRoute: PhoneTaskRoute?

    var body: some View {
        NavigationStack {
            if let document = model.document { content(document) }
        }
        .sheet(item: $request) { PhoneCalendarEditSheet(model: model, request: $0) }
        .sheet(item: $taskRoute) { PhoneTaskSheet(model: model, route: $0, close: { taskRoute = nil }) }
        .interactiveDismissDisabled(model.isBusy)
    }

    private func content(_ document: WorkspaceDocument) -> some View {
        let data = document.snapshot.workspace
        let candidates = TaskCalendarProjection.arrangementTasks(data: data, options: options, overdue: overdue,
                                                                  now: model.now, calendar: model.calendar, selection: selection)
        let groups = TaskCalendarProjection.arrangementGroups(candidates, data: data, grouping: grouping)
        let date = Date.FormatStyle(date: .complete, time: .omitted, calendar: model.calendar, timeZone: model.calendar.timeZone)
        return List {
            Section {
                Picker("Group by", selection: $grouping) {
                    ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }.accessibilityIdentifier("arrangeGroup")
                Picker("List", selection: $selection) {
                    Text("Calendar sources").tag(CalendarArrangeSelection.calendar)
                    Text("Inbox").tag(CalendarArrangeSelection.inbox)
                    ForEach(data.lists.filter { !$0.isArchived }) { list in
                        Text(list.name).tag(CalendarArrangeSelection.list(list.id))
                    }
                }.accessibilityIdentifier("arrangeList")
                Toggle("Include overdue", isOn: $overdue).accessibilityIdentifier("arrangeOverdue")
            } footer: {
                Text("Schedule tasks for \(focus.formatted(date)).")
            }
            if model.calendarNotice != nil { Section { PhoneCalendarFeedback(model: model) } }
            if groups.isEmpty {
                Text("No tasks to arrange").foregroundStyle(.secondary).accessibilityIdentifier("arrangeEmpty")
            }
            ForEach(groups, id: \.name) { group in
                Section("\(group.name) · \(group.tasks.count)") {
                    ForEach(group.tasks) { task in
                        HStack(spacing: 0) {
                            Button {
                                taskRoute = PhoneTaskRoute(id: task.id)
                            } label: {
                                Label(task.title, systemImage: task.kind == .note ? "doc.text" : "square")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Button {
                                request = PhoneCalendarEditRequest(task: task, expected: document.revision,
                                                                   focus: focus, hourly: options.mode.isHourly,
                                                                   calendar: model.calendar, mode: .schedule)
                            } label: {
                                Image(systemName: "calendar.badge.plus")
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Schedule " + task.title)
                                .accessibilityIdentifier("arrangeSchedule-" + task.id.uuidString)
                                .disabled(!model.canBeginEditing)
                        }
                    }
                }
            }
        }
        .navigationTitle("Arrange Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("arrangeDone")
            }
        }
    }
}

struct PhoneCalendarEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: PhoneWorkspaceModel
    let request: PhoneCalendarEditRequest
    @State private var draft: CalendarScheduleDraft
    @State private var remove = false
    @State private var scope: CalendarScheduleScope = .series
    @State private var restoreOccurrence = false
    @State private var skipOccurrence = false
    @State private var error: String?

    private var original: CalendarScheduleDraft {
        CalendarScheduleDraft(task: request.task, focus: request.focus, hourly: request.hourly, calendar: request.calendar)
    }
    private var components: DatePickerComponents { draft.allDay ? .date : [.date, .hourAndMinute] }

    init(model: PhoneWorkspaceModel, request: PhoneCalendarEditRequest) {
        self.model = model
        self.request = request
        _draft = State(initialValue: CalendarScheduleDraft(task: request.task, focus: request.focus,
                                                          hourly: request.hourly, calendar: request.calendar))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(request.task.title).font(.headline) }
                if skipOccurrence {
                    Section {
                        Text("Done moves this open task to its next scheduled occurrence.")
                        Button("Keep editing") { skipOccurrence = false }
                    }
                } else if restoreOccurrence {
                    Section {
                        Text("Done restores the original schedule for this occurrence.")
                        Button("Keep editing") { restoreOccurrence = false }
                    }
                } else {
                    scheduleControls
                    if !remove, let data = model.document?.snapshot.workspace,
                       CalendarScheduling.canRescheduleCurrentOccurrence(request.task, in: data.tasks) {
                        Section("Apply change to") {
                            Picker("Apply change to", selection: $scope) {
                                Text("This occurrence").tag(CalendarScheduleScope.currentOccurrence)
                                Text("Series").tag(CalendarScheduleScope.series)
                            }.pickerStyle(.segmented).accessibilityIdentifier("calendarOccurrenceScope")
                            if request.mode == .schedule,
                               CalendarScheduling.canSkipCurrentOccurrence(request.task, in: data.tasks, calendar: request.calendar) {
                                Button("Skip this occurrence") { skipOccurrence = true }
                                    .accessibilityIdentifier("calendarSkipOccurrence")
                            }
                            if request.task.originalOccurrenceSchedule != nil {
                                Button("Restore original schedule") { restoreOccurrence = true }
                                    .accessibilityIdentifier("calendarOccurrenceRestore")
                            }
                        }
                    }
                }
                if !valid { Text("The end must be on or after the start.").font(.footnote).foregroundStyle(.red) }
            }
            .disabled(model.isBusy)
            .safeAreaInset(edge: .bottom) {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading).padding().background(.regularMaterial)
                        .accessibilityIdentifier("calendarEditError")
                }
            }
            .navigationTitle(request.mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("calendarEditCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.disabled(model.isBusy || !valid).accessibilityIdentifier("calendarEditDone")
                }
            }
        }
        .environment(\.calendar, request.calendar)
        .environment(\.timeZone, request.calendar.timeZone)
        .interactiveDismissDisabled(model.isBusy)
    }

    @ViewBuilder private var scheduleControls: some View {
        switch request.mode {
        case .schedule: scheduleSection
        case .move:
            Section {
                DatePicker(draft.hasDuration ? "New start" : "New date", selection: $draft.start,
                           displayedComponents: components)
            } footer: { Text("Moving keeps the existing duration and shifts manual reminders with the task.") }
        case .resize:
            Section {
                DatePicker("New end", selection: $draft.end, displayedComponents: components)
            } footer: { Text(draft.allDay ? "The start day stays fixed." : "The start stays fixed. A changed timed range lasts at least 15 minutes.") }
        case .resizeStart:
            Section {
                DatePicker("New start", selection: $draft.start, displayedComponents: components)
            } footer: { Text(draft.allDay ? "The end day and reminders stay fixed." :
                "The end and reminders stay fixed. A changed range lasts at least 15 minutes.") }
        }
    }

    private var scheduleSection: some View {
        Section {
            if remove {
                Button("Keep schedule") { remove = false }
                Text("Removal clears the date, duration, reminders, and repeat when you tap Done.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Toggle("All day", isOn: Binding(get: { draft.allDay }, set: {
                    draft.setAllDay($0, calendar: request.calendar)
                }))
                Toggle("Duration", isOn: Binding(get: { draft.hasDuration }, set: { draft.setDuration($0) }))
                DatePicker(draft.hasDuration ? "Start" : "Date", selection: $draft.start, displayedComponents: components)
                if draft.hasDuration {
                    DatePicker("End", selection: $draft.end, displayedComponents: components)
                }
                if request.task.dueDate != nil {
                    Button("Remove schedule", role: .destructive) { remove = true }
                        .accessibilityIdentifier("calendarEditRemove")
                }
            }
        }
    }

    private var valid: Bool {
        if restoreOccurrence || skipOccurrence { return true }
        return switch request.mode {
        case .schedule: remove || draft.isValid
        case .move: draft.start.timeIntervalSinceReferenceDate.isFinite
        case .resize: draft.end >= draft.start
        case .resizeStart: draft.start.timeIntervalSinceReferenceDate.isFinite
        }
    }

    private var operation: CalendarScheduleOperation? {
        if skipOccurrence { return .skipOccurrence }
        if restoreOccurrence { return .restoreOccurrence }
        return switch request.mode {
        case .schedule: remove ? .unschedule : draft.operation
        case .move: draft.start == original.start ? nil : .move(start: draft.start, allDay: draft.allDay)
        case .resize: draft.end == original.end ? nil : .resizeEnd(draft.end)
        case .resizeStart: draft.start == original.start ? nil : .resizeStart(draft.start)
        }
    }

    private func save() {
        guard let operation else { dismiss(); return }
        Task {
            error = await model.saveCalendarSchedule(operation, taskID: request.task.id, expected: request.expected,
                                                     scope: remove || restoreOccurrence || skipOccurrence ? .series : scope)
            if error == nil { dismiss() }
        }
    }
}
