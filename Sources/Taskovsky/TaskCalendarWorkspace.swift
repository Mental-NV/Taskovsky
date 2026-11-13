import AppKit
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
    var canRescheduleOccurrence = false
    var hasOccurrenceOverride = false
    var skipBaseline: CalendarScheduleSnapshot?
    var scope: CalendarScheduleScope = .series
    var restoreOccurrence = false
    var skipOccurrence = false
}

private struct CalendarOccurrenceChange {
    let taskID: UUID
    let before: CalendarScheduleSnapshot
    let operation: CalendarScheduleOperation
}

struct TaskCalendarWorkspace: View {
    private struct PostponeRequest: Identifiable {
        let id = UUID()
        let tasks: [TaskItem]
        let data: WorkspaceData
        let settings: AppSettings
    }

    private static let modeShortcuts: [(mode: TaskCalendarMode, letter: String)] = [
        (.day, "d"), (.week, "w"), (.month, "m"), (.year, "y"), (.agenda, "a")
    ]
    @ObservedObject var store: TaskStore
    var onOpenTask: (UUID) -> Void
    var onComplete: (UUID) -> Void
    var embeddedInTasks = false
    @State private var focus = Date()
    @State private var showArrange = false
    @State private var sidebarOverlay = false
    @State private var viewOptions = false
    @State private var jumpDate = false
    @State private var editor: CalendarEditorDraft?
    @State private var yearDayPreview: CalendarDayPreview?
    @State private var postponeRequest: PostponeRequest?
    @State private var occurrenceChange: CalendarOccurrenceChange?
    @StateObject private var feedback = DesktopNotice()
    @State private var compactLayout = false
    @State private var agendaWindow = CalendarAgendaWindow()
    @State private var optionHeld = false
    private var calendar: Calendar { store.settings.calendar }
    private var options: Binding<TaskCalendarOptions> {
        Binding(get: { store.settings.calendarOptions }, set: { store.settings.calendarOptions = $0 })
    }
    private var mode: TaskCalendarMode { store.settings.calendarOptions.mode }
    private var dateJumpAction: (() -> Void)? {
        guard editor == nil, yearDayPreview == nil, occurrenceChange == nil, postponeRequest == nil, !jumpDate, !viewOptions else { return nil }
        return { jumpDate = true }
    }

    var body: some View {
        GeometryReader { geometry in
            let days = CalendarDates.visibleDays(focus: focus, mode: mode, options: options.wrappedValue,
                                                calendar: calendar, agendaWindow: agendaWindow)
            let range = CalendarDates.interval(for: days, calendar: calendar) ?? DateInterval(start: focus, duration: 86_400)
            let projection = TaskCalendarProjection.project(data: store.data, range: range, options: options.wrappedValue, calendar: calendar)
            let compact = geometry.size.width < 760
            HStack(spacing: 0) {
                if !compact && options.wrappedValue.showSidebar {
                    CalendarNavigationSidebar(store: store, focus: $focus, range: range)
                        .frame(width: 222)
                    Divider()
                }
                VStack(spacing: 0) {
                    header(compact: compact).overlay(alignment: .bottom) { Divider() }
                    HStack(spacing: 0) {
                        content(days: days, entries: projection.entries)
                            .environment(\.calendarTemporarilyShowsIcons, optionHeld)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if showArrange && !compact {
                            Divider()
                            CalendarArrangePanel(store: store, focus: focus, calendar: calendar,
                                close: { showArrange = false }, open: onOpenTask, schedule: edit)
                                .frame(width: 234)
                        }
                    }
                    if !projection.truncatedTaskIDs.isEmpty {
                        Text("Some repeat previews reach the 5,000-occurrence preview limit.")
                            .font(.caption).foregroundStyle(.secondary).padding(6)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if compact && sidebarOverlay {
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.08).onTapGesture { sidebarOverlay = false }
                        CalendarNavigationSidebar(store: store, focus: $focus, range: range)
                            .frame(width: 222).background(Color(nsColor: .textBackgroundColor))
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
        .onDisappear { feedback.dismiss() }
        .focusedSceneValue(\.calendarDateJump, dateJumpAction)
        .background {
            WindowKeyboardInput(optionChanged: { optionHeld = $0 }, handleKeyDown: { event in
                guard !embeddedInTasks, editor == nil, yearDayPreview == nil, occurrenceChange == nil, postponeRequest == nil, !jumpDate, !viewOptions,
                      event.modifierFlags.intersection([.command, .control, .option, .shift, .function]).isEmpty,
                      let characters = event.characters,
                      let shortcut = Self.modeShortcuts.enumerated().first(where: {
                          characters == $0.element.letter || characters == String($0.offset + 1)
                      }) else { return false }
                let next = shortcut.element.mode
                if mode != next { options.wrappedValue.mode = next }
                return true
            })
            .frame(width: 0, height: 0).accessibilityHidden(true)
        }
        .tint(CalendarAppearance.accent)
        .onChange(of: focus) { _, _ in agendaWindow = CalendarAgendaWindow() }
        .onChange(of: mode) { _, _ in agendaWindow = CalendarAgendaWindow() }
        .sheet(item: $yearDayPreview) { preview in
            let listNames = Dictionary(store.data.lists.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            CalendarYearDayPreviewSheet(day: preview.day,
                projection: preview.project(data: store.data, options: options.wrappedValue, calendar: calendar),
                listNames: listNames, calendar: calendar) {
                focus = preview.day
                options.wrappedValue.mode = .week
            }
        }
        .sheet(item: $postponeRequest) { request in
            TaskBatchSheet(scope: "Calendar sources", tasks: request.tasks, data: request.data,
                           calendar: request.settings.calendar, today: focus, onlyAction: .postpone) { edit in
                let error = saveDesktopTaskBatch(edit, to: store, expected: request.data, settings: request.settings)
                if error == nil {
                    feedback.show(edit.action.kind.completionMessage)
                }
                return error
            }
        }
        .sheet(item: $editor) { draft in
            CalendarTaskEditor(draft: draft, lists: store.data.lists.filter { !$0.isArchived }, calendar: calendar, removeDate: {
                if let id = draft.taskID { commitSchedule(id, .unschedule, scope: .series) }; editor = nil
            }) { value in
                save(value)
            }
        }
        .confirmationDialog("Apply schedule change to", isPresented: Binding(get: { occurrenceChange != nil },
            set: { if !$0 { occurrenceChange = nil } }), titleVisibility: .visible, presenting: occurrenceChange) { change in
            Button("This occurrence") { confirmSchedule(change, scope: .currentOccurrence) }
            Button("Series") { confirmSchedule(change, scope: .series) }
            Button("Cancel", role: .cancel) { }
        }
        .overlay(alignment: .bottom) {
            if let event = feedback.event {
                HStack(spacing: 14) {
                    Text(event.message)
                    if event.undo != nil {
                        Button("Undo schedule") { feedback.undo(in: store) }.buttonStyle(.borderless)
                    }
                    Button { feedback.dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss Calendar feedback")
                }.font(.system(size: 12)).padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 6).padding(.bottom, 58).padding(.horizontal)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in
            if !embeddedInTasks { create(on: focus) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            guard !embeddedInTasks else { return }
            if compactLayout { sidebarOverlay.toggle() } else { options.wrappedValue.showSidebar.toggle() }
        }
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Button {
                    if compact { sidebarOverlay.toggle() } else { options.wrappedValue.showSidebar.toggle() }
                } label: { Image(systemName: "sidebar.left").font(.system(size: 16)).frame(width: 18) }
                    .accessibilityLabel("Toggle Calendar sidebar")
                Button(CalendarText.date(focus, mode == .year ? "yyyy" : "MMMM y", calendar: calendar)) { jumpDate.toggle() }
                    .font(.system(size: compact ? 16 : 20, weight: .semibold)).lineLimit(1)
                    .help("Jump to Date")
                    .popover(isPresented: $jumpDate) {
                        CalendarDateJumpPicker(date: focus, calendar: calendar, showWeekNumbers: store.settings.showWeekNumbers,
                            cancel: { jumpDate = false }, go: { date in
                                focus = calendar.startOfDay(for: date)
                                jumpDate = false
                            })
                    }
                Spacer(minLength: 4)
                if !compact { headerControls }
            }
            if compact { HStack { Spacer(minLength: 0); headerControls } }
        }.buttonStyle(.plain).foregroundStyle(.primary).padding(.top, compact ? 0 : 10)
            .padding(.horizontal, compact ? 10 : 20).frame(maxWidth: .infinity).frame(height: compact ? 78 : 54)
    }
    private var headerControls: some View {
        HStack(spacing: 12) {
            Button { create(on: focus) } label: { Image(systemName: "plus").font(.system(size: 17, weight: .light)).frame(width: 28, height: 28) }
                .background { RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.18), lineWidth: 0.7) }
                .help("Add a task to Calendar").accessibilityLabel("Add Calendar task")
            Menu {
                ForEach(TaskCalendarMode.allCases, id: \.self) { value in
                    Button { options.wrappedValue.mode = value } label: {
                        Label(modeMenuTitle(value), systemImage: mode == value ? "checkmark" : "calendar")
                    }
                }
            } label: {
                HStack(spacing: 5) { Text(modeLabel); Image(systemName: "chevron.down").font(.system(size: 8)) }
                    .padding(.horizontal, 10).frame(minWidth: 48, minHeight: 28)
                    .background { RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.18), lineWidth: 0.7) }
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Calendar view")
            HStack(spacing: 0) {
                Button { navigate(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 11)).frame(width: 32, height: 28) }.accessibilityLabel("Previous Calendar period")
                Divider().frame(height: 28)
                Button("Today") { agendaWindow = CalendarAgendaWindow(); focus = Date() }
                    .frame(width: 58, height: 28).accessibilityLabel("Calendar Today")
                Divider().frame(height: 28)
                Button { navigate(1) } label: { Image(systemName: "chevron.right").font(.system(size: 11)).frame(width: 32, height: 28) }.accessibilityLabel("Next Calendar period")
            }.fixedSize().background { RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.18), lineWidth: 0.7) }
            Menu {
                Button("View Options…") { viewOptions = true }
                Button(showArrange ? "Hide Arrange tasks" : "Arrange tasks") { showArrange.toggle(); sidebarOverlay = false }
                let candidates = TaskBatchEdit.calendarPostponeCandidates(in: store.data, options: options.wrappedValue)
                Button("Postpone Tasks…") {
                    postponeRequest = PostponeRequest(tasks: candidates, data: store.data, settings: store.settings)
                }.disabled(candidates.isEmpty)
            } label: { Image(systemName: "ellipsis").font(.system(size: 16)).frame(width: 24, height: 28) }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
                .accessibilityLabel("Calendar actions")
                .sheet(isPresented: $viewOptions) {
                    VStack(alignment: .leading, spacing: 18) {
                        ScrollView { CalendarViewOptions(options: options, calendar: calendar, store: store) }
                        HStack { Spacer(); Button("Done") { viewOptions = false }.keyboardShortcut(.cancelAction) }
                    }.padding(18).frame(width: 360, height: 560)
                }
        }.font(.system(size: 13)).foregroundStyle(.primary)
    }
    private func modeMenuTitle(_ value: TaskCalendarMode) -> String {
        guard !embeddedInTasks, let index = Self.modeShortcuts.firstIndex(where: { $0.mode == value }) else {
            return value.title
        }
        return "\(value.title)  \(Self.modeShortcuts[index].letter.uppercased())/\(index + 1)"
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
                open: onOpenTask, complete: complete, create: createRange, schedule: schedule, edit: editEntry,
                selectDay: { day in focus = day; options.wrappedValue.mode = .day },
                saveFoldedHours: { cutoffs in
                    guard cutoffs != options.wrappedValue.foldedHours else { return }
                    options.wrappedValue.foldedHours = cutoffs
                },
                saveAllDayRows: { rows in
                    guard rows != options.wrappedValue.allDayRows else { return }
                    options.wrappedValue.allDayRows = rows
                })
        } else if mode == .year {
            CalendarYearView(focus: focus, entries: entries, calendar: calendar, style: options.wrappedValue.yearStyle,
                selectMonth: { month in focus = month; options.wrappedValue.mode = .month },
                preview: { yearDayPreview = CalendarDayPreview($0, calendar: calendar) }) { day in
                focus = day; options.wrappedValue.mode = .week
            }
        } else if mode == .agenda {
            CalendarAgendaView(days: days, entries: entries, calendar: calendar, options: options.wrappedValue,
                open: onOpenTask, complete: complete, edit: editEntry, create: create,
                canExtend: agendaWindow.canExtend, showMore: { agendaWindow.extend() })
                .id(calendar.startOfDay(for: focus))
        } else {
            CalendarMonthView(days: days, focus: focus, entries: entries, calendar: calendar, options: options.wrappedValue,
                open: onOpenTask, complete: complete, edit: editEntry, create: create, move: moveToDay, schedule: schedule, createRange: createRange)
        }
    }
    private func navigate(_ direction: Int) {
        focus = CalendarDates.navigate(focus, direction: direction, mode: mode, options: options.wrappedValue, calendar: calendar)
    }
    private func complete(_ entry: CalendarEntry) {
        guard entry.canChangeCompletion else { return }
        if let itemID = entry.checklistID {
            store.setChecklistItemCompleted(taskID: entry.taskID, itemID: itemID, completed: !entry.isCompleted)
        } else {
            feedback.dismiss()
            onComplete(entry.taskID)
        }
    }
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
            schedule: CalendarScheduleDraft(task: task, focus: focus, hourly: mode.isHourly, calendar: calendar), listID: task.listID,
            canRescheduleOccurrence: CalendarScheduling.canRescheduleCurrentOccurrence(task, in: store.data.tasks),
            hasOccurrenceOverride: task.originalOccurrenceSchedule != nil,
            skipBaseline: CalendarScheduling.canSkipCurrentOccurrence(task, in: store.data.tasks, calendar: calendar)
                ? CalendarScheduleSnapshot(task) : nil)
    }
    private func save(_ draft: CalendarEditorDraft) -> Bool {
        if let id = draft.taskID {
            if draft.skipOccurrence {
                if let baseline = draft.skipBaseline, let current = store.data.tasks.first(where: { $0.id == id }),
                   CalendarScheduleSnapshot(current) == baseline,
                   CalendarScheduling.canSkipCurrentOccurrence(current, in: store.data.tasks, calendar: calendar) {
                    commitSchedule(id, .skipOccurrence, scope: .series)
                } else { feedback.show("Schedule changed. Open the current task and try again.", persistent: true) }
            } else if draft.restoreOccurrence { commitSchedule(id, .restoreOccurrence, scope: .series) }
            else if let operation = draft.schedule.operation { commitSchedule(id, operation, scope: draft.scope) }
            else { feedback.show("Schedule unchanged") }
        } else {
            let window = TaskDurationRange(start: draft.schedule.start, end: draft.schedule.end, isAllDay: draft.schedule.allDay)
            guard let id = store.createCalendarTask(title: draft.title, listID: draft.listID, duration: window) else {
                feedback.show(store.storageError ?? "Could not add the Calendar task. Review the draft and try again.", persistent: true)
                return false
            }
            feedback.show("Task added to Calendar")
            if let task = store.data.tasks.first(where: { $0.id == id }), !options.wrappedValue.includes(task, data: store.data) {
                feedback.show("Task added. Its list or tags are hidden by the Calendar filter.")
            }
        }
        editor = nil
        return true
    }
    private func schedule(_ id: UUID, _ operation: CalendarScheduleOperation) {
        guard occurrenceChange == nil else { return }
        if let task = store.data.tasks.first(where: { $0.id == id }),
           CalendarScheduling.canRescheduleCurrentOccurrence(task, in: store.data.tasks) {
            occurrenceChange = CalendarOccurrenceChange(taskID: id, before: CalendarScheduleSnapshot(task), operation: operation)
        } else { commitSchedule(id, operation, scope: .series) }
    }
    private func confirmSchedule(_ change: CalendarOccurrenceChange, scope: CalendarScheduleScope) {
        guard let task = store.data.tasks.first(where: { $0.id == change.taskID }),
              CalendarScheduling.canRescheduleCurrentOccurrence(task, in: store.data.tasks),
              CalendarScheduleSnapshot(task) == change.before else {
            feedback.show("Schedule changed. Review the current task and try again.", persistent: true)
            return
        }
        commitSchedule(change.taskID, change.operation, scope: scope)
    }
    private func commitSchedule(_ id: UUID, _ operation: CalendarScheduleOperation, scope: CalendarScheduleScope) {
        if let token = store.scheduleOnCalendar(id: id, operation: operation, calendar: calendar, scope: scope) {
            if case .skipOccurrence = operation { feedback.show("Occurrence skipped", undo: token) }
            else { feedback.show(scope == .currentOccurrence ? "This occurrence updated" : "Schedule updated", undo: token) }
        } else if case .skipOccurrence = operation {
            feedback.show(store.storageError ?? "Could not skip this occurrence.", persistent: true)
        } else {
            feedback.show(store.storageError ?? "Schedule unchanged", persistent: store.storageError != nil)
        }
    }
    private func moveToDay(_ id: UUID, _ day: Date, _ forceAllDay: Bool) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        schedule(id, CalendarScheduling.moveOnDay(task, day: day, forceAllDay: forceAllDay, calendar: calendar))
    }
}

private struct CalendarDateJumpPicker: View {
    @State var date: Date
    let calendar: Calendar
    let showWeekNumbers: Bool
    let cancel: () -> Void
    let go: (Date) -> Void

    var body: some View {
        VStack(spacing: 8) {
            CalendarGrid(date: $date, calendar: calendar, showWeekNumbers: showWeekNumbers, onSelect: { go(date) })
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.field)
                .padding(.horizontal, 12)
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Go") { go(date) }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }.padding(12)
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
    }
}

struct WindowKeyboardInput: NSViewRepresentable {
    let optionChanged: (Bool) -> Void
    var handleKeyDown: ((NSEvent) -> Bool)? = nil

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView(frame: .zero)
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: KeyView, context: Context) {
        view.optionChanged = optionChanged
        view.handleKeyDown = handleKeyDown
    }

    static func dismantleNSView(_ view: KeyView, coordinator: ()) { view.stopMonitoring() }

    final class KeyView: NSView {
        var optionChanged: ((Bool) -> Void)?
        var handleKeyDown: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard let window else { return }
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(resumeOptionMonitoring(_:)), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(clearOption(_:)), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(clearOption(_:)), name: NSWindow.willBeginSheetNotification, object: window)
            center.addObserver(self, selector: #selector(resumeOptionMonitoring(_:)), name: NSWindow.didEndSheetNotification, object: window)
            DispatchQueue.main.async { [weak self] in self?.syncOption(NSEvent.modifierFlags) }
            let mask: NSEvent.EventTypeMask = handleKeyDown == nil ? .flagsChanged : [.flagsChanged, .keyDown]
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                if event.type == .flagsChanged {
                    self?.syncOption(event.modifierFlags)
                    return event
                }
                guard let self, let window = self.window, event.window === window, window.isKeyWindow,
                      window.attachedSheet == nil, NSApp.modalWindow == nil,
                      !(window.firstResponder is NSTextView), !(window.firstResponder is NSTextField),
                      !(window.firstResponder is NSDatePicker), !event.isARepeat,
                      handleKeyDown?(event) == true else { return event }
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func resumeOptionMonitoring(_ notification: Notification) { syncOption(NSEvent.modifierFlags) }

        private func syncOption(_ flags: NSEvent.ModifierFlags) {
            let isAvailable = window?.isKeyWindow == true && window?.attachedSheet == nil && NSApp.modalWindow == nil
            optionChanged?(isAvailable && flags.contains(.option))
        }

        @objc private func clearOption(_ notification: Notification) { optionChanged?(false) }
    }
}

struct CalendarTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: CalendarEditorDraft
    var lists: [TaskList]
    var calendar: Calendar
    var removeDate: () -> Void
    var save: (CalendarEditorDraft) -> Bool
    @State private var saveFailed = false
    @State private var submitted = false
    @FocusState private var titleFocused: Bool
    private var valid: Bool {
        draft.restoreOccurrence || draft.skipOccurrence ||
            ((draft.taskID != nil || !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && draft.schedule.isValid)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.taskID == nil ? "Add Calendar task" : "Schedule task").font(.title3.bold())
            if draft.taskID == nil {
                TextField("Task title", text: $draft.title).focused($titleFocused).accessibilityLabel("Calendar task title")
            } else { Text(draft.title).font(.headline).lineLimit(2) }
            if draft.skipOccurrence {
                Text("Save moves this open task to its next scheduled occurrence.").font(.caption)
                Button("Keep editing") { draft.skipOccurrence = false }
            } else { scheduleFields }
            if saveFailed {
                Text("Could not add the task. Your draft is kept. Review it and try again, or Cancel.")
                    .font(.system(size: 12)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendarCreationSaveError")
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                if draft.taskID != nil && !draft.restoreOccurrence && !draft.skipOccurrence { Button("Remove date") { removeDate(); dismiss() } }
                Spacer()
                Button(draft.taskID == nil ? "Add Task" : "Save") {
                    guard !submitted else { return }
                    submitted = true
                    if save(draft) { dismiss() }
                    else { submitted = false; saveFailed = true }
                }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!valid || submitted)
            }
        }.textFieldStyle(.roundedBorder).padding(22).frame(width: 410)
            .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
            .onAppear { titleFocused = draft.taskID == nil }
    }

    @ViewBuilder private var scheduleFields: some View {
        Toggle("All day", isOn: Binding(get: { draft.schedule.allDay }, set: { draft.schedule.setAllDay($0, calendar: calendar) }))
        if draft.taskID != nil {
            Toggle("Duration", isOn: Binding(get: { draft.schedule.hasDuration }, set: { draft.schedule.setDuration($0) }))
                .accessibilityLabel("Calendar schedule duration")
        }
        if draft.canRescheduleOccurrence {
            if draft.restoreOccurrence {
                Text("Save restores the original schedule for this occurrence.").font(.caption)
                Button("Keep editing") { draft.restoreOccurrence = false }
            } else {
                Picker("Apply change to", selection: $draft.scope) {
                    Text("This occurrence").tag(CalendarScheduleScope.currentOccurrence)
                    Text("Series").tag(CalendarScheduleScope.series)
                }.pickerStyle(.segmented)
                if draft.skipBaseline != nil {
                    Button("Skip this occurrence") { draft.skipOccurrence = true }
                }
                if draft.hasOccurrenceOverride {
                    Button("Restore original schedule") { draft.restoreOccurrence = true }
                }
            }
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
    }
}

private struct CalendarSourceColorSettings: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TaskStore
    let mode: CalendarColorMode
    let original: CalendarColorSource.Overrides
    @State private var draft: CalendarColorSource.Overrides
    @State private var error: String?

    init(mode: CalendarColorMode, store: TaskStore) {
        self.mode = mode
        self.store = store
        let original = store.settings.calendarOptions.sourceColors
        self.original = original
        _draft = State(initialValue: original)
    }

    var body: some View {
        let rows = CalendarColorSource.swatches(in: store.data, by: mode)
        VStack(alignment: .leading, spacing: 14) {
            Text(mode == .list ? "Calendar List Colors" : "Calendar Tag Colors").font(.headline)
            Text(mode == .list ? "Named list colors apply in Tasks and Calendar. Inbox and existing overrides apply in Calendar." :
                "These colors apply only in Calendar.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    if rows.isEmpty { Text("No tags to customize.").foregroundStyle(.secondary) }
                    ForEach(rows) { row in
                        if case .list(let id) = row.id {
                            if let legacy = original[row.id] {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.name)
                                        Text(draft[row.id] == nil ? "Uses list color after save" : "Calendar override")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    CalendarSourceSwatch(color: draft[row.id] == nil ? row.defaultColor : legacy)
                                        .accessibilityHidden(true)
                                    Button("Use List Color") { draft[row.id] = nil }
                                        .disabled(draft[row.id] == nil)
                                        .accessibilityLabel("Use List Color for " + row.name)
                                }
                            } else {
                                CalendarSourceColorRow(row: row, override: .constant(nil), saveListColor: { expected, value in
                                    store.saveCalendarListColor(id: id, expected: expected, color: value)
                                })
                            }
                        } else {
                            CalendarSourceColorRow(row: row, override: Binding(get: { draft[row.id] }, set: { draft[row.id] = $0 }))
                        }
                    }
                }.padding(.vertical, 2)
            }.frame(maxHeight: 280)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(mode == .list ? "Cancel Calendar Changes" : "Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(mode == .list ? "Save Calendar Changes" : "Done") {
                    if store.saveCalendarSourceColors(draft, expected: original) { dismiss() }
                    else { error = store.storageError ?? "Calendar colors changed. Open the editor again to review them." }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(18).frame(width: 340)
    }
}

private struct CalendarSourceColorRow: View {
    let row: CalendarColorSource.Swatch
    @Binding var override: String?
    var saveListColor: ((String, String) -> Bool)? = nil
    @State private var editing = false
    @State private var hex = ""
    @State private var expectedColor = ""
    @State private var saveFailed = false

    private var color: String { override ?? row.defaultColor }
    private var normalizedHex: String? {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        return CalendarColorSource.Overrides.normalizedHex(value.hasPrefix("#") ? value : "#" + value)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(row.name).frame(maxWidth: .infinity, alignment: .leading)
            Button {
                expectedColor = color
                hex = color
                saveFailed = false
                editing = true
            } label: {
                CalendarSourceSwatch(color: color)
            }.buttonStyle(.plain)
                .accessibilityLabel("Color for " + row.name)
                .accessibilityValue(saveListColor == nil ? override ?? "Default" : color)
                .popover(isPresented: $editing, arrowEdge: .trailing) { picker }
            if saveListColor == nil {
                Button("Default") { override = nil }
                    .disabled(override == nil).accessibilityLabel("Use default color for " + row.name)
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(row.name).font(.headline)
            HStack(spacing: 6) {
                ForEach(palette, id: \.self) { preset in
                    Button {
                        if saveListColor == nil { select(preset) }
                        else { hex = preset }
                    } label: {
                        Circle().fill(Color(hex: preset)).frame(width: 22, height: 22)
                    }.buttonStyle(.plain).accessibilityLabel("Preset " + preset)
                }
            }
            HStack {
                TextField("Hex color", text: $hex).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Hex color").onSubmit(applyHex)
                Button("Apply", action: applyHex).disabled(normalizedHex == nil)
            }
            if saveListColor != nil {
                Text("Apply saves the list color in Tasks and Calendar.").font(.caption).foregroundStyle(.secondary)
                if saveFailed {
                    Text("The list color could not be saved. Check the workspace or reopen the editor.")
                        .font(.caption).foregroundStyle(.red)
                }
                Button("Cancel") { editing = false }.keyboardShortcut(.cancelAction)
            }
        }.padding(12).frame(width: 240)
    }

    private func applyHex() {
        if let normalizedHex { select(normalizedHex) }
    }

    private func select(_ value: String) {
        if let saveListColor {
            guard saveListColor(expectedColor, value) else { saveFailed = true; return }
        } else {
            override = value
        }
        editing = false
    }
}

private struct CalendarSourceSwatch: View {
    let color: String

    var body: some View {
        RoundedRectangle(cornerRadius: 4).fill(Color(hex: color))
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.18)) }
            .frame(width: 34, height: 19)
    }
}

struct CalendarViewOptions: View {
    @Binding var options: TaskCalendarOptions
    var calendar: Calendar
    @ObservedObject var store: TaskStore
    @State private var timeZoneSettings = false
    @State private var colorSettings = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calendar View Options").font(.headline)
            Picker("Color by", selection: $options.colorBy) {
                ForEach(CalendarColorMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            if options.colorBy != .priority {
                Button(options.colorBy == .list ? "Customize List Colors…" : "Customize Tag Colors…") { colorSettings = true }
                    .sheet(isPresented: $colorSettings) {
                        CalendarSourceColorSettings(mode: options.colorBy, store: store)
                    }
            }
            Picker("Style", selection: $options.itemStyle) { Text("Filled").tag(CalendarItemStyle.filled); Text("Outline").tag(CalendarItemStyle.outline) }
            if options.mode == .year {
                Picker("Year style", selection: $options.yearStyle) {
                    Text("Standard").tag(CalendarYearStyle.standard)
                    Text("Heatmap").tag(CalendarYearStyle.heatmap)
                }
            } else {
                Toggle("Show Item Icons", isOn: $options.showItemIcons)
                Group {
                    Toggle("Show Task Icons", isOn: $options.showTaskIcons)
                    Toggle("Show Note Icons", isOn: $options.showNoteIcons)
                }.disabled(!options.showItemIcons)
                Text("With task icons hidden, use the card menu to complete or reopen a task or checklist item.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Toggle("Show Completed", isOn: $options.showCompleted)
            Toggle("Show Checklist Items", isOn: $options.showChecklistItems)
            Toggle("Show All Repeat Cycles", isOn: $options.showRepeatCycles)
            Text("Future repeats are previews. Open the repeating task to edit its schedule.").font(.caption).foregroundStyle(.secondary)
            Stepper("Multi-Day: \(options.multiDayCount) days", value: $options.multiDayCount, in: 2...14)
            Stepper("Multi-Week: \(options.multiWeekCount) weeks", value: $options.multiWeekCount, in: 2...6)
            Picker("All-day rows", selection: $options.allDayRows) {
                Text("Automatic").tag(nil as Int?)
                ForEach(TaskCalendarOptions.allDayRowRange, id: \.self) { rows in
                    Text(rows == 1 ? "1 row" : "\(rows) rows").tag(Optional(rows))
                }
            }
            Divider()
            Toggle("Additional Time Zones", isOn: $options.showAdditionalTimeZones)
            HStack {
                Button("Time Zone Settings…") { timeZoneSettings = true }
                Spacer()
                Text("\(options.additionalTimeZones.count) configured").foregroundStyle(.secondary)
            }
                .sheet(isPresented: $timeZoneSettings) {
                    CalendarTimeZoneSettings(zones: options.additionalTimeZones, primary: calendar.timeZone) { zones in
                        options.additionalTimeZones = zones
                    }
                }
            Text("Rulers appear in Day, Week and Multi-Day. They use the first displayed date; hover an hour for its date in that zone.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Folded Hours").fontWeight(.semibold)
            ForEach(CalendarHourBand.allCases, id: \.self) { band in
                let value = options.foldedHours
                Stepper(band.cutoffTitle + ": " + String(format: "%02d:00", value.cutoff(band)), value: Binding(
                    get: { options.foldedHours.cutoff(band) },
                    set: { options.foldedHours = options.foldedHours.moving(band, to: $0) }
                ), in: value.range(for: band))
            }
            Button("Reset Folded Hours") { options.foldedHours = .init() }.disabled(options.foldedHours == .init())
            Text("Expand both bands to drag their boundaries in the timeline.").font(.caption).foregroundStyle(.secondary)
        }.font(.system(size: 12)).toggleStyle(.switch)
            .onChange(of: options.showAdditionalTimeZones) { _, enabled in
                if enabled && options.additionalTimeZones.isEmpty { timeZoneSettings = true }
            }
    }
}
