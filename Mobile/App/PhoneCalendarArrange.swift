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

struct PhoneCalendarArrangeSheet: View {
    let close: () -> Void
    @ObservedObject var model: PhoneWorkspaceModel
    let focus: Date
    let options: TaskCalendarOptions
    let drag: ((UUID, WorkspaceRevision) -> PhoneCalendarDrag?)?
    @State private var grouping = CalendarColorMode.list
    @State private var selection = CalendarArrangeSelection.calendar
    @State private var showFilter = false
    @State private var overdue = false
    @State private var undated = true
    @State private var showNotes = true
    @State private var showHierarchy = true
    @State private var collapsedHierarchy = Set<UUID>()
    @State private var request: PhoneCalendarEditRequest?
    @State private var taskRoute: PhoneTaskRoute?

    var body: some View {
        NavigationStack {
            if let document = model.document { content(document) }
        }
        .sheet(item: $request) { PhoneCalendarEditSheet(model: model, request: $0) }
        .sheet(item: $taskRoute) { PhoneTaskSheet(model: model, route: $0, close: { taskRoute = nil }) }
        .interactiveDismissDisabled(model.isBusy)
        .fullScreenCover(isPresented: $showFilter) {
            if let data = model.document?.snapshot.workspace {
                PhoneArrangeFilter(data: data, selection: selection) { selection = $0 }
                    .presentationBackground(.clear)
            }
        }
    }

    private func option(_ title: String, selected: Binding<Bool>, id: String) -> some View {
        Button { selected.wrappedValue.toggle() } label: {
            Label(title, systemImage: selected.wrappedValue ? "checkmark" : "circle")
        }.accessibilityIdentifier(id).accessibilityValue(selected.wrappedValue ? "On" : "Off")
    }

    private func content(_ document: WorkspaceDocument) -> some View {
        let data = document.snapshot.workspace
        let candidates = TaskCalendarProjection.arrangementTasks(data: data, options: options, overdue: overdue,
                                                                  now: model.now, calendar: model.calendar, selection: selection, undated: undated, showNotes: showNotes)
        let groups = TaskCalendarProjection.arrangementGroups(candidates, data: data, grouping: grouping)
        let date = Date.FormatStyle(date: .complete, time: .omitted, calendar: model.calendar, timeZone: model.calendar.timeZone)
        return List {
            if model.scheduleNotice(in: .calendar) != nil { Section { PhoneScheduleFeedback(model: model, surface: .calendar) } }
            if groups.isEmpty {
                Text("No tasks to arrange").foregroundStyle(.secondary).accessibilityIdentifier("arrangeEmpty")
            }
            ForEach(groups, id: \.name) { group in
                let rows = TaskCalendarProjection.arrangementRows(for: group.tasks, grouping: grouping,
                                                                  showHierarchy: showHierarchy,
                                                                  collapsed: collapsedHierarchy)
                Section("\(group.name) · \(group.tasks.count)") {
                    ForEach(rows, id: \.task.id) { row in
                        let task = row.task
                        HStack(spacing: 0) {
                            if row.hasChildren {
                                let collapsed = collapsedHierarchy.contains(task.id)
                                Button {
                                    if collapsed { collapsedHierarchy.remove(task.id) }
                                    else { collapsedHierarchy.insert(task.id) }
                                } label: {
                                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                                        .frame(width: 32, height: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel((collapsed ? "Expand " : "Collapse ") + task.title)
                                    .accessibilityIdentifier("arrangeDisclosure-" + task.id.uuidString)
                            }
                            if let payload = drag?(task.id, document.revision) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .draggable(payload) { Label(task.title, systemImage: "calendar").padding(8) }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Drag " + task.title)
                                    .accessibilityIdentifier("calendarArrangeDrag-" + task.id.uuidString)
                            }
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
                        .padding(.leading, CGFloat(row.depth) * 16)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Group by", selection: $grouping) {
                ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("arrangeGroup")
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.bar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { showFilter = true } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("arrangeList")
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8).background(.bar)
        }
        .navigationTitle("Arrange Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: close) { Image(systemName: "xmark") }
                    .accessibilityLabel("Close Arrange Tasks")
                    .disabled(model.isBusy).accessibilityIdentifier("arrangeDone")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    option("Undated Task", selected: $undated, id: "arrangeUndated")
                    option("Overdue Task", selected: $overdue, id: "arrangeOverdue")
                    option("Show Notes", selected: $showNotes, id: "arrangeNotes")
                    option("Show Task Hierarchy", selected: $showHierarchy, id: "arrangeHierarchy")
                    Text("Schedule tasks for \(focus.formatted(date)).")
                    if drag != nil { Text("Hold a grip and drag to a visible Calendar date or time.") }
                } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("Arrange options")
                    .accessibilityIdentifier("arrangeOptions")
            }
        }
    }
}

private struct PhoneArrangeFilter: View {
    @Environment(\.dismiss) private var dismiss
    let data: WorkspaceData
    let apply: (CalendarArrangeSelection) -> Void
    @State private var all: Bool
    @State private var inbox: Bool
    @State private var listIDs: Set<UUID>
    @State private var collapsed = Set<UUID>()

    init(data: WorkspaceData, selection: CalendarArrangeSelection, apply: @escaping (CalendarArrangeSelection) -> Void) {
        self.data = data; self.apply = apply
        switch selection {
        case .calendar: _all = State(initialValue: true); _inbox = State(initialValue: false); _listIDs = State(initialValue: [])
        case .inbox: _all = State(initialValue: false); _inbox = State(initialValue: true); _listIDs = State(initialValue: [])
        case .list(let id): _all = State(initialValue: false); _inbox = State(initialValue: false); _listIDs = State(initialValue: [id])
        case .sources(let ids, let inbox): _all = State(initialValue: false); _inbox = State(initialValue: inbox); _listIDs = State(initialValue: ids)
        }
    }
    private var lists: [TaskList] { data.lists.filter { !$0.isArchived } }
    private func choice(_ title: String, checked: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Image(systemName: checked ? "checkmark.circle.fill" : "circle").foregroundStyle(checked ? Color.accentColor : Color.secondary) }
                .frame(minHeight: 40).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id).accessibilityValue(checked ? "Selected" : "Not selected")
    }
    private func list(_ value: TaskList) -> some View {
        choice(value.name, checked: !all && listIDs.contains(value.id), id: "arrangeFilterList-" + value.id.uuidString) {
            all = false
            if !listIDs.insert(value.id).inserted { listIDs.remove(value.id) }
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 0) {
                    Text("Filter").font(.headline).padding(16)
                    ScrollView {
                        VStack(spacing: 4) {
                            choice("All", checked: all, id: "arrangeFilterAll") { all = true; inbox = false; listIDs.removeAll() }
                            choice("Inbox", checked: !all && inbox, id: "arrangeFilterInbox") { all = false; inbox.toggle() }
                            ForEach(lists.filter { value in value.folderID == nil || !data.folders.contains(where: { $0.id == value.folderID }) }) { value in list(value) }
                            ForEach(data.folders) { folder in
                                Button {
                                    if !collapsed.insert(folder.id).inserted { collapsed.remove(folder.id) }
                                } label: {
                                    HStack { Image(systemName: "folder"); Text(folder.name); Spacer(); Image(systemName: collapsed.contains(folder.id) ? "chevron.right" : "chevron.down") }
                                        .frame(minHeight: 40).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityIdentifier("arrangeFilterFolder-" + folder.id.uuidString)
                                if !collapsed.contains(folder.id) {
                                    ForEach(lists.filter { $0.folderID == folder.id }) { value in list(value).padding(.leading, 20) }
                                }
                            }
                        }.padding(.horizontal, 16)
                    }
                    Divider()
                    HStack {
                        Button("Cancel") { dismiss() }.accessibilityIdentifier("arrangeFilterCancel")
                        Spacer()
                        Button("Done") { apply(all ? .calendar : .sources(listIDs: listIDs, inbox: inbox)); dismiss() }
                            .accessibilityIdentifier("arrangeFilterDone")
                    }.padding(16)
                }.frame(width: min(340, geometry.size.width - 32), height: min(520, geometry.size.height - 64))
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.interactiveDismissDisabled()
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
                    PhoneOccurrenceSkipStage { skipOccurrence = false }
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
