import SwiftUI
import TaskovskyCore

enum CalendarText {
    static func date(_ date: Date, _ template: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
    static func time(_ date: Date, calendar: Calendar) -> String { self.date(date, "HHmm", calendar: calendar) }
}

struct CalendarEditorDraft: Identifiable {
    let id = UUID()
    var taskID: UUID?
    var title = ""
    var schedule: CalendarScheduleDraft
    var listID: UUID?
}

struct TaskCalendarWorkspace: View {
    @ObservedObject var store: TaskStore
    var onOpenTask: (UUID) -> Void
    var onComplete: (UUID) -> Void
    @State private var focus = Date()
    @State private var showArrange = false
    @State private var sidebarOverlay = false
    @State private var viewOptions = false
    @State private var jumpDate = false
    @State private var editor: CalendarEditorDraft?
    @State private var undo: CalendarScheduleUndo?
    @State private var notice = ""
    @State private var compactLayout = false
    @State private var detailedMode: TaskCalendarMode = .week
    private var calendar: Calendar { store.settings.calendar }
    private var options: Binding<TaskCalendarOptions> {
        Binding(get: { store.settings.calendarOptions }, set: { store.settings.calendarOptions = $0 })
    }
    private var mode: TaskCalendarMode { store.settings.calendarOptions.mode }

    var body: some View {
        GeometryReader { geometry in
            let days = CalendarDates.visibleDays(focus: focus, mode: mode, options: options.wrappedValue, calendar: calendar)
            let range = CalendarDates.interval(for: days, calendar: calendar) ?? DateInterval(start: focus, duration: 86_400)
            let projection = TaskCalendarProjection.project(data: store.data, range: range, options: options.wrappedValue, calendar: calendar)
            let compact = geometry.size.width < 760
            VStack(spacing: 0) {
                header(compact: compact)
                Divider()
                HStack(spacing: 0) {
                    if !compact && options.wrappedValue.showSidebar {
                        CalendarNavigationSidebar(store: store, focus: $focus, range: range)
                            .frame(width: 234)
                        Divider()
                    }
                    content(days: days, entries: projection.entries)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if showArrange && !compact {
                        Divider()
                        CalendarArrangePanel(store: store, focus: focus, calendar: calendar,
                            close: { showArrange = false }, open: onOpenTask, schedule: edit)
                            .frame(width: compact ? 210 : 234)
                    }
                }
                if !projection.truncatedTaskIDs.isEmpty {
                    Text("Some repeat previews reach the 5,000-occurrence preview limit.")
                        .font(.caption).foregroundStyle(.secondary).padding(6)
                }
            }
            .overlay(alignment: .topLeading) {
                if compact && sidebarOverlay {
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.08).onTapGesture { sidebarOverlay = false }
                        CalendarNavigationSidebar(store: store, focus: $focus, range: range)
                            .frame(width: 234).background(Color(nsColor: .windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10)).shadow(radius: 12)
                            .padding(.top, 83).padding(.leading, 10)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if compact && showArrange {
                    CalendarArrangePanel(store: store, focus: focus, calendar: calendar,
                        close: { showArrange = false }, open: onOpenTask, schedule: edit)
                        .frame(width: 234).background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10)).shadow(radius: 12)
                        .padding(.top, 83).padding(.trailing, 8)
                }
            }
            .onAppear { compactLayout = compact }
            .onChange(of: geometry.size.width) { _, width in compactLayout = width < 760; if width >= 760 { sidebarOverlay = false } }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(item: $editor) { draft in
            CalendarTaskEditor(draft: draft, lists: store.data.lists.filter { !$0.isArchived }, calendar: calendar, removeDate: {
                if let id = draft.taskID { schedule(id, .unschedule) }; editor = nil
            }) { value in
                save(value)
            }
        }
        .overlay(alignment: .bottom) {
            if undo != nil || !notice.isEmpty {
                HStack(spacing: 14) {
                    Text(notice.isEmpty ? "Schedule updated" : notice)
                    if let undo {
                        Button("Undo schedule") {
                            notice = store.undoCalendarSchedule(undo) ? "Schedule restored" : "Schedule changed since this edit"
                            self.undo = nil
                        }.buttonStyle(.borderless)
                    }
                    Button { undo = nil; notice = "" } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss Calendar feedback")
                }.font(.system(size: 12)).padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 6).padding(.bottom, 58).padding(.horizontal)
            }
        }
        .onChange(of: mode) { _, new in if new != .year { detailedMode = new } }
        .onAppear { if mode != .year { detailedMode = mode } }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in create(on: focus) }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            if compactLayout { sidebarOverlay.toggle() } else { options.wrappedValue.showSidebar.toggle() }
        }
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 12) {
                Button {
                    if compact { sidebarOverlay.toggle() } else { options.wrappedValue.showSidebar.toggle() }
                } label: { Image(systemName: "sidebar.left") }
                    .accessibilityLabel("Toggle Calendar sidebar")
                Button(CalendarText.date(focus, mode == .year ? "yyyy" : "MMMM y", calendar: calendar)) { jumpDate.toggle() }
                    .font(.system(size: compact ? 16 : 19, weight: .semibold)).lineLimit(1)
                    .popover(isPresented: $jumpDate) {
                        CalendarGrid(date: $focus, calendar: calendar, showWeekNumbers: store.settings.showWeekNumbers, onSelect: { jumpDate = false })
                    }
                Spacer(minLength: 4)
                if !compact { headerControls }
            }
            if compact { HStack { Spacer(minLength: 0); headerControls } }
        }.buttonStyle(.borderless).padding(.horizontal, compact ? 10 : 18).frame(height: compact ? 78 : 58)
    }
    private var headerControls: some View {
        HStack(spacing: 12) {
            Button { create(on: focus) } label: { Image(systemName: "plus") }
                .help("Add a task to Calendar").accessibilityLabel("Add Calendar task")
            Menu {
                ForEach(TaskCalendarMode.allCases, id: \.self) { value in
                    Button { options.wrappedValue.mode = value } label: {
                        Label(value.title, systemImage: mode == value ? "checkmark" : "calendar")
                    }
                }
            } label: { Text(modeLabel).frame(minWidth: 48) }
                .accessibilityLabel("Calendar view")
            HStack(spacing: 0) {
                Button { navigate(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous Calendar period")
                Button("Today") { focus = Date() }.accessibilityLabel("Calendar Today")
                Button { navigate(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next Calendar period")
            }.controlSize(.small)
            Menu {
                Button("View Options…") { viewOptions = true }
                Button(showArrange ? "Hide Arrange tasks" : "Arrange tasks") { showArrange.toggle(); sidebarOverlay = false }
            } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Calendar actions")
                .sheet(isPresented: $viewOptions) {
                    VStack(alignment: .leading, spacing: 18) {
                        CalendarViewOptions(options: options)
                        HStack { Spacer(); Button("Done") { viewOptions = false }.keyboardShortcut(.cancelAction) }
                    }.padding(18).frame(width: 340)
                }
        }
    }
    private var modeLabel: String {
        switch mode {
        case .multiDay: return "\(options.wrappedValue.multiDayCount) Days"
        case .multiWeek: return "\(options.wrappedValue.multiWeekCount) Weeks"
        default: return mode.title
        }
    }
    @ViewBuilder private func content(days: [Date], entries: [CalendarEntry]) -> some View {
        if mode.isHourly {
            CalendarHourlyView(days: days, entries: entries, calendar: calendar, options: options.wrappedValue,
                open: onOpenTask, complete: complete, create: createRange, schedule: schedule, edit: editEntry)
        } else if mode == .year {
            CalendarYearView(focus: focus, entries: entries, calendar: calendar) { day in
                focus = day; options.wrappedValue.mode = detailedMode
            }
        } else if mode == .agenda {
            CalendarAgendaView(days: days, entries: entries, calendar: calendar, options: options.wrappedValue,
                open: onOpenTask, complete: complete, edit: editEntry, create: create)
        } else {
            CalendarMonthView(days: days, focus: focus, entries: entries, calendar: calendar, options: options.wrappedValue,
                open: onOpenTask, complete: complete, edit: editEntry, create: create, move: moveToDay)
        }
    }
    private func navigate(_ direction: Int) {
        focus = CalendarDates.navigate(focus, direction: direction, mode: mode, options: options.wrappedValue, calendar: calendar)
    }
    private func complete(_ id: UUID) { undo = nil; notice = ""; onComplete(id) }
    private func create(on day: Date) {
        let start = mode.isHourly ? CalendarDates.instant(on: day, minute: 9 * 60, calendar: calendar) : calendar.startOfDay(for: day)
        createRange(start, mode.isHourly ? start.addingTimeInterval(1_800) : start, !mode.isHourly)
    }
    private func createRange(_ start: Date, _ end: Date, _ allDay: Bool) {
        let scope = options.wrappedValue
        editor = CalendarEditorDraft(schedule: .init(start: start, end: end, allDay: allDay),
            listID: scope.listIDs?.count == 1 ? scope.listIDs?.first : store.settings.defaultListID)
    }
    private func editEntry(_ entry: CalendarEntry) {
        guard entry.canSchedule, let task = store.data.tasks.first(where: { $0.id == entry.taskID }) else { return }
        edit(task)
    }
    private func edit(_ task: TaskItem) {
        editor = CalendarEditorDraft(taskID: task.id, title: task.title,
            schedule: CalendarScheduleDraft(task: task, focus: focus, hourly: mode.isHourly, calendar: calendar), listID: task.listID)
    }
    private func save(_ draft: CalendarEditorDraft) {
        if let id = draft.taskID {
            if let operation = draft.schedule.operation { schedule(id, operation) }
            else { notice = "Schedule unchanged"; undo = nil }
        } else {
            let window = TaskDurationRange(start: draft.schedule.start, end: draft.schedule.end, isAllDay: draft.schedule.allDay)
            let id = store.createTask(title: draft.title, listID: draft.listID, dueDate: draft.schedule.end,
                useDefaultList: false, recognizeDates: false, duration: window)
            notice = "Task added to Calendar"; undo = nil
            if let task = store.data.tasks.first(where: { $0.id == id }), !options.wrappedValue.includes(task, data: store.data) {
                notice = "Task added. Its list or tags are hidden by the Calendar filter."
            }
        }
        editor = nil
    }
    private func schedule(_ id: UUID, _ operation: CalendarScheduleOperation) {
        if let token = store.scheduleOnCalendar(id: id, operation: operation, calendar: calendar) {
            undo = token; notice = "Schedule updated"
        }
    }
    private func moveToDay(_ id: UUID, _ day: Date, _ forceAllDay: Bool) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        if !forceAllDay, task.hasDueTime, let due = task.dueDate {
            let start = task.scheduledDuration?.start ?? due
            let parts = calendar.dateComponents([.hour, .minute], from: start)
            let target = CalendarDates.instant(on: day, minute: (parts.hour ?? 0) * 60 + (parts.minute ?? 0), calendar: calendar)
            schedule(id, .move(start: target, allDay: false))
        } else { schedule(id, .move(start: day, allDay: true)) }
    }
}

struct CalendarTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: CalendarEditorDraft
    var lists: [TaskList]
    var calendar: Calendar
    var removeDate: () -> Void
    var save: (CalendarEditorDraft) -> Void
    @FocusState private var titleFocused: Bool
    private var valid: Bool {
        (draft.taskID != nil || !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && draft.schedule.isValid
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.taskID == nil ? "Add Calendar task" : "Schedule task").font(.title3.bold())
            if draft.taskID == nil {
                TextField("Task title", text: $draft.title).focused($titleFocused).accessibilityLabel("Calendar task title")
            } else { Text(draft.title).font(.headline).lineLimit(2) }
            Toggle("All day", isOn: Binding(get: { draft.schedule.allDay }, set: { draft.schedule.setAllDay($0, calendar: calendar) }))
            if draft.taskID != nil {
                Toggle("Duration", isOn: Binding(get: { draft.schedule.hasDuration }, set: { draft.schedule.setDuration($0) }))
                    .accessibilityLabel("Calendar schedule duration")
            }
            DatePicker(draft.schedule.hasDuration ? "Start" : "Date", selection: $draft.schedule.start,
                displayedComponents: draft.schedule.allDay ? [.date] : [.date, .hourAndMinute])
            if draft.schedule.hasDuration {
                DatePicker("End", selection: $draft.schedule.end, displayedComponents: draft.schedule.allDay ? [.date] : [.date, .hourAndMinute])
            }
            if !draft.schedule.isValid { Text("End must not precede start.").foregroundStyle(.red).font(.caption) }
            if draft.taskID == nil {
                Picker("List", selection: $draft.listID) {
                    Text("Inbox").tag(UUID?.none)
                    ForEach(lists) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            if draft.taskID != nil { Text("Remove date also removes repeat rules and reminders. Undo schedule restores them.").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                if draft.taskID != nil { Button("Remove date") { removeDate(); dismiss() } }
                Spacer()
                Button(draft.taskID == nil ? "Add Task" : "Save") { save(draft); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }.textFieldStyle(.roundedBorder).padding(22).frame(width: 410)
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
            .onAppear { titleFocused = draft.taskID == nil }
    }
}

struct CalendarViewOptions: View {
    @Binding var options: TaskCalendarOptions
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calendar View Options").font(.headline)
            Picker("Color by", selection: $options.colorBy) {
                ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Style", selection: $options.itemStyle) { Text("Filled").tag(CalendarItemStyle.filled); Text("Outline").tag(CalendarItemStyle.outline) }
            Divider()
            Toggle("Show Completed", isOn: $options.showCompleted)
            Toggle("Show Checklist Items", isOn: $options.showChecklistItems)
            Toggle("Show All Repeat Cycles", isOn: $options.showRepeatCycles)
            Text("Future repeats are previews. Open the repeating task to edit its schedule.").font(.caption).foregroundStyle(.secondary)
            Stepper("Multi-Day: \(options.multiDayCount) days", value: $options.multiDayCount, in: 2...14)
            Stepper("Multi-Week: \(options.multiWeekCount) weeks", value: $options.multiWeekCount, in: 2...6)
            Divider()
            Picker("Additional time zone", selection: Binding(get: { options.additionalTimeZoneID ?? "" }, set: { options.additionalTimeZoneID = $0.isEmpty ? nil : $0 })) {
                Text("None").tag("")
                ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
            }
        }.font(.system(size: 12)).toggleStyle(.switch)
    }
}
