import SwiftUI
import TaskovskyDomain
import TaskovskyWorkspace

@main
struct TaskovskyMobileApp: App {
    var body: some Scene { WindowGroup { MobileRootView() } }
}

private enum PhoneSection: String, CaseIterable { case tasks = "Tasks", calendar = "Calendar", search = "Search"
    var symbol: String { switch self { case .tasks: "checkmark.square.fill"; case .calendar: "calendar"; case .search: "magnifyingglass" } }
}
private struct PhoneOccurrenceChange {
    let drag: PhoneCalendarDrag
    let operation: CalendarScheduleOperation
}
enum PhoneStyle {
    static let accent = Color(red: 70/255, green: 112/255, blue: 250/255)
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let indigo = Color(red: 36/255, green: 43/255, blue: 87/255)
}

struct MobileRootView: View {
    @StateObject private var model = PhoneWorkspaceModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var initialized = false
    @State private var section: PhoneSection = .tasks
    @State private var destination: TaskDestination = .today
    @State private var alternateModes: [TaskDestination: TaskListViewMode] = [:]
    @State private var capturePresented = false
    @State private var drawer = false
    @State private var manageLists = false
    @State private var smartListRequest: PhoneSmartListRequest?
    @State private var manageFilters = false
    @State private var manageTags = false
    @State private var manageTemplates = false
    @State private var localSettingsRequest: PhoneLocalSettingsRequest?
    @State private var tagDrawerError: String?
    @State private var collapsedFolders: Set<UUID> = []
    @State private var selectedTask: PhoneTaskRoute?
    @State private var search = TaskFilter(name: "", status: .all)
    @State private var focus = MobilePreviewFixture.day
    @State private var sessionCalendarMode: TaskCalendarMode?
    @State private var calendarPreferenceRoute: PhoneCalendarPreferenceRoute?
    @State private var preferenceNotice: String?
    @State private var viewPicker = false
    @State private var jumpDatePresented = false
    @State private var showTaskSort = false
    @State private var showArrange = false
    @State private var showCalendarActions = false
    @State private var calendarEdit: PhoneCalendarEditRequest?
    @State private var occurrenceChange: PhoneOccurrenceChange?
    @State private var calendarDragSession = UUID()
    private var calendar: Calendar { model.calendar }
    private var options: TaskCalendarOptions {
        var displayed = model.document?.snapshot.settings.calendarOptions ?? TaskCalendarOptions()
        if let sessionCalendarMode { displayed.mode = sessionCalendarMode }
        return displayed
    }
    var body: some View {
        Group {
            if let document = model.document { shell(document.snapshot) }
            else if let failure = model.failure {
                VStack(spacing: 20) {
                    ContentUnavailableView("Workspace unavailable", systemImage: "exclamationmark.triangle", description: Text(failure))
                    Button("Retry") { Task { await model.retryOpen() } }.frame(minHeight: 44)
                }
            } else { ProgressView("Opening workspace…") }
        }.task { await model.open() }
            .onChange(of: model.document?.revision) { _, _ in
                if !initialized, model.document != nil {
                    initialized = true
                    focus = model.now
                }
            }
            .onChange(of: scenePhase) { _, phase in
                Task { if phase == .active { await model.refresh() } else { await model.flushDraft(); await model.flushCapture() } }
            }
            .alert("Resume saved edit?", isPresented: $model.recoveryPrompt) {
                Button("Resume") { resumeEdit() }
                Button("Discard", role: .destructive) { Task { await model.discardRecovery() } }
                Button("Later", role: .cancel) { }
            } message: { Text("An unfinished field edit was saved locally. It has not been submitted.") }
            .alert("Resume new task?", isPresented: $model.captureRecoveryPrompt) {
                Button("Resume") { resumeCapture() }
                Button("Discard", role: .destructive) { Task { await model.discardCaptureRecovery() } }
                Button("Later", role: .cancel) { }
            } message: { Text("A capture was saved locally. Resume never submits it; Retry checks the same task if a save was unfinished.") }
            .onChange(of: model.captureDraft?.id) { _, value in if value == nil { capturePresented = false } }
    }
    private func resumeCapture() {
        if model.captureDraft == nil { model.resumeCaptureRecovery() }
        capturePresented = model.captureDraft != nil
    }
    @State private var sectionListDragSession = UUID()
    @State private var sectionMoveNotice: String?

    private var showsCaptureButton: Bool {
        guard section == .tasks else { return true }
        if case .folder = destination { return false }
        return destination != .summary
    }

    private func addCapture() {
        Task {
            await model.beginCapture(destination: section == .tasks ? destination : .all, calendarDate: section == .calendar ? focus : nil)
            capturePresented = model.captureDraft != nil
        }
    }
    private func addSectionTask(listID: UUID, sectionID: UUID) {
        Task {
            await model.beginCapture(destination: .list(listID), calendarDate: nil, sectionID: sectionID)
            capturePresented = model.captureDraft != nil
        }
    }
    private func resumeEdit() {
        guard let draft = model.activeDraft ?? model.recoveredDraft else { return }
        if model.activeDraft == nil { model.resumeRecovery() }
        selectedTask = PhoneTaskRoute(id: draft.taskID, preferEditor: true)
    }
    private func shell(_ snapshot: ReadOnlyWorkspaceSnapshot) -> some View {
        let visibility = PhoneSmartDrawer(settings: snapshot.settings, data: snapshot.workspace, now: model.now, calendar: calendar)
        return ZStack(alignment: .bottom) {
            PhoneStyle.page.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    circle("Open navigation", symbol: "line.3.horizontal") { drawer = true }
                    Spacer()
                    if section == .calendar {
                        Button {
                            jumpDatePresented = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(focus.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.wide)))
                                    .font(.headline).lineLimit(1)
                                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Jump to Date")
                        .accessibilityValue(focus.formatted(Date.FormatStyle(date: .complete, time: .omitted,
                                                                            calendar: calendar, timeZone: calendar.timeZone)))
                        .accessibilityIdentifier("calendarJumpToDate")
                        Spacer()
                        Button { viewPicker = true } label: {
                            Image(systemName: "calendar").frame(width: 44, height: 44)
                        }.accessibilityLabel("Calendar view")
                            .popover(isPresented: $viewPicker, arrowEdge: .top) {
                                VStack(spacing: 0) {
                                    ForEach(TaskCalendarMode.allCases, id: \.self) { mode in
                                        Button { viewPicker = false; selectCalendarMode(mode, at: focus) } label: {
                                            HStack { Text(mode.title); Spacer(); if options.mode == mode { Image(systemName: "checkmark") } }
                                                .frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                    }
                                }.padding(8).frame(width: 220).presentationCompactAdaptation(.popover)
                            }
                        circle("Calendar filters", symbol: "line.3.horizontal.decrease") { openCalendarPreferences(.filters) }
                        circle("Calendar actions", symbol: "ellipsis") { showCalendarActions = true }
                            .popover(isPresented: $showCalendarActions, arrowEdge: .top) {
                                VStack(spacing: 0) {
                                    calendarAction("View Options", symbol: "slider.horizontal.3") {
                                        openCalendarPreferences(.display)
                                    }
                                    calendarAction("Arrange Tasks", symbol: "calendar.badge.plus") {
                                        showArrange = true
                                    }
                                }.padding(8).frame(width: 220).presentationCompactAdaptation(.popover)
                            }
                    } else {
                        Text("Taskovsky").font(.subheadline).foregroundStyle(.secondary)
                        if section == .tasks && showsTaskSort(in: snapshot.workspace) { taskSortMenu }
                    }
                }.padding(.horizontal, 16)
                Text(model.isQA ? "Sample workspace · Local editing" : "Local workspace · Early development").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("previewNotice")
                if model.recoveredDraft != nil || model.activeDraft != nil {
                    Button(model.activeDraft != nil ? "Continue your edit" : "Resume saved edit", action: resumeEdit).frame(minHeight: 44)
                }
                if let notice = model.creationNotice { Text(notice).font(.caption).accessibilityIdentifier("captureSuccess") }
                if selectedTask == nil { PhoneLifecycleFeedback(model: model).padding(.horizontal, 16) }
                if model.recoveredCapture != nil || model.captureDraft != nil {
                    Button("Resume new task", action: resumeCapture).frame(minHeight: 44).disabled(model.activeDraft != nil)
                }
                if model.protectedCapture { Text("A saved capture is unreadable or unsupported. Its file is kept; editing is blocked.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
                if let error = model.captureError, model.captureDraft == nil { Text(error).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
                if model.protectedDraft { Text("A saved edit uses an unreadable or unsupported format. Its file is kept; editing is blocked.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
                switch section {
                case .tasks:
                    Text(title(destination, in: snapshot.workspace)).font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    taskDestination(snapshot.workspace)
                case .calendar:
                    if let preferenceNotice {
                        Text(preferenceNotice).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("calendarPreferenceNotice").padding(.horizontal, 16)
                    }
                    PhoneCalendarFeedback(model: model).padding(.horizontal, 16)
                    calendarBody(data: snapshot.workspace)
                case .search:
                    PhoneSearchView(model: model, criteria: $search, data: snapshot.workspace,
                                    open: { destination = $0; section = .tasks }) { tasks, query in
                        taskList(tasks, data: snapshot.workspace, searchQuery: query)
                    }
                }
            }.padding(.top, 4)
            VStack {
                Spacer()
                if showsCaptureButton {
                    HStack { Spacer(); Button(action: addCapture) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .medium)).frame(width: 48, height: 48)
                            .background(PhoneStyle.accent, in: Circle()).foregroundStyle(.white)
                    }.disabled(!model.canBeginCapture).accessibilityLabel("Add").accessibilityIdentifier("openCapture") }
                }
            }.padding(.trailing, 20).padding(.bottom, 82)
            HStack(spacing: 8) {
                ForEach(PhoneSection.allCases, id: \.self) { item in
                    Button { section = item } label: {
                        Image(systemName: item.symbol).font(.system(size: 23, weight: .medium))
                            .foregroundStyle(section == item ? PhoneStyle.accent : .primary)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(section == item ? Color.primary.opacity(0.06) : .clear, in: Capsule())
                    }.accessibilityLabel(item.rawValue).accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }.buttonStyle(.plain).padding(5).background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(0.10), lineWidth: 0.5))
                .padding(.horizontal, 20).padding(.bottom, 8)
        }.tint(PhoneStyle.accent)
        .sheet(isPresented: $drawer) {
            navigation(model.document?.snapshot ?? snapshot).presentationDetents([.large])
        }
        .onChange(of: visibility, initial: true) { prior, current in
            if !current.shows(destination), prior.shows(destination) || destination.smartKey != nil {
                destination = current.fallback
            }
        }
        .onChange(of: snapshot.workspace.lists.map(\.id)) { _, ids in
            if case .list(let id) = destination, !ids.contains(id) { destination = .inbox }
        }
        .onChange(of: snapshot.workspace.folders.map(\.id)) { _, ids in
            if case .folder(let id) = destination, !ids.contains(id) { destination = visibility.fallback }
        }
        .onChange(of: snapshot.workspace.filters.map(\.id)) { _, ids in
            if case .filter(let id) = destination, !ids.contains(id) { destination = visibility.fallback }
        }
        .onChange(of: snapshot.workspace.tags.map(\.id)) { _, ids in
            if case .tag(let id) = destination, !ids.contains(id) { destination = visibility.fallback }
        }
        .sheet(item: $selectedTask) { route in PhoneTaskSheet(model: model, route: route, close: { selectedTask = nil }) }
        .sheet(item: $calendarPreferenceRoute) { route in
            PhoneCalendarPreferences(model: model, route: route)
        }
        .sheet(isPresented: $jumpDatePresented) {
            PhoneCalendarDateJump(date: focus, calendar: calendar) { date in focus = date }
        }
        .sheet(isPresented: $showArrange) { PhoneCalendarArrangeSheet(model: model, focus: focus, options: options) }
        .confirmationDialog("Apply schedule change to", isPresented: Binding(get: { occurrenceChange != nil },
            set: { if !$0 { occurrenceChange = nil } }), titleVisibility: .visible, presenting: occurrenceChange) { change in
            Button("This occurrence") { saveCalendarGesture(change, scope: .currentOccurrence) }
            Button("Series") { saveCalendarGesture(change, scope: .series) }
            Button("Cancel") { occurrenceChange = nil }
        }
        .sheet(item: $calendarEdit) { PhoneCalendarEditSheet(model: model, request: $0) }
        .sheet(isPresented: $capturePresented, onDismiss: {
            if model.captureDraft != nil { model.requestCloseCapture() }
            else if let id = model.createdTaskID { selectedTask = PhoneTaskRoute(id: id) }
        }) { PhoneCaptureSheet(model: model).presentationDetents([.large]).presentationDragIndicator(.visible) }
    }
    private func circle(_ name: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 20)).frame(width: 44, height: 44).background(.regularMaterial, in: Circle()) }
            .buttonStyle(.plain).foregroundStyle(.primary).accessibilityLabel(name)
    }
    private func title(_ value: TaskDestination, in data: WorkspaceData) -> String {
        switch value {
        case .all: "All"; case .today: "Today"; case .tomorrow: "Tomorrow"; case .week: "Next 7 Days"; case .inbox: "Inbox"
        case .completed: "Completed"; case .wontDo: "Won't Do"; case .trash: "Trash"
        case .summary: "Summary"
        case .list(let id): data.lists.first { $0.id == id }?.name ?? "List unavailable"
        case .folder(let id): data.folders.first { $0.id == id }?.name ?? "Folder unavailable"
        case .tag(let id): data.tags.first { $0.id == id }?.name ?? "Tag unavailable"
        case .filter(let id): data.filters.first { $0.id == id }?.name ?? "Filter unavailable"
        default: "Tasks"
        }
    }
    private func showsTaskSort(in data: WorkspaceData) -> Bool {
        if alternateModes[destination] != nil { return false }
        if case .list(let id) = destination, let list = data.lists.first(where: { $0.id == id }) {
            return list.viewMode == .list || (list.isArchived && list.viewMode == .timeline)
        }
        return destination != .summary
    }

    private var taskSortMenu: some View {
        Button { showTaskSort = true } label: {
            Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44)
        }.accessibilityLabel("Sort tasks")
            .accessibilityValue(model.taskTimestampSort?.title ?? "Default Order")
            .accessibilityIdentifier("taskSortMenu")
            .popover(isPresented: $showTaskSort, arrowEdge: .top) {
                VStack(spacing: 0) {
                    taskSortChoice(nil)
                    ForEach(TaskTimestampSort.allCases, id: \.self) { taskSortChoice($0) }
                }.padding(8).frame(width: 245).presentationCompactAdaptation(.popover)
            }
    }

    private func taskSortChoice(_ choice: TaskTimestampSort?) -> some View {
        let selected = model.taskTimestampSort == choice
        return Button {
            showTaskSort = false
            model.setTaskTimestampSort(choice)
        } label: {
            HStack {
                Text(choice?.title ?? "Default Order")
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }.frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func taskDestinationRows(_ data: WorkspaceData) -> some View {
        let tasks = destination.matchingTasks(in: data, now: model.now, calendar: calendar)
        let ordered = model.taskTimestampSort.map { tasks.sorted(by: $0.precedes) } ?? tasks
        return taskList(ordered, data: data)
    }

    @ViewBuilder private func taskDestination(_ data: WorkspaceData) -> some View {
        let scope = TaskTimelineScope(destination: destination, data: data)
        if destination == .summary {
            PhoneSummaryView(model: model)
        } else if case .list(let id) = destination, let list = data.lists.first(where: { $0.id == id }) {
            PhoneListModeControl(model: model, list: list).id("list-mode-" + id.uuidString)
            if let scope, list.viewMode == .timeline {
                taskTimeline(scope, data: data)
            } else if !list.sections.isEmpty {
                if list.viewMode == .board {
                    PhoneSectionBoard(model: model, list: list, data: data,
                                      openTask: { selectedTask = PhoneTaskRoute(id: $0) },
                                      addTask: { addSectionTask(listID: id, sectionID: $0) }).id(id)
                } else {
                    sectionedPhoneRows(list, data: data).id(id)
                }
            } else if list.viewMode == .board {
                PhoneTaskBoard(model: model, list: list, data: data) { selectedTask = PhoneTaskRoute(id: $0) }.id(id)
            } else {
                taskDestinationRows(data)
            }
        } else if scope != nil || ScopedBoardProjection.supports(destination, in: data) {
            let supportsBoard = ScopedBoardProjection.supports(destination, in: data)
            Picker("Tasks view", selection: Binding(get: { alternateModes[destination] ?? .list }, set: { mode in
                alternateModes[destination] = mode == .list ? nil : mode
            })) {
                Text("List").tag(TaskListViewMode.list)
                if supportsBoard { Text("Board").tag(TaskListViewMode.board) }
                if scope != nil { Text("Timeline").tag(TaskListViewMode.timeline) }
            }.pickerStyle(.segmented).padding(.horizontal, 16)
                .accessibilityIdentifier("taskDestinationViewMode")
            switch alternateModes[destination] {
            case .timeline:
                if let scope { taskTimeline(scope, data: data) }
            case .board:
                PhoneScopedTaskBoard(model: model, destination: destination, data: data,
                                     open: { selectedTask = PhoneTaskRoute(id: $0) },
                                     schedule: scheduleFromScopedBoard).id(destination)
            default:
                taskDestinationRows(data)
            }
        } else {
            taskDestinationRows(data)
        }
    }

    private func taskTimeline(_ scope: TaskTimelineScope, data: WorkspaceData) -> some View {
        let arrangement = model.canBeginEditing ? model.document.flatMap { document in
            (try? JSONEncoder().encode(document.revision)).map {
                TaskTimelineArrangeControls(revision: $0, drop: arrangeTimelineByDrop)
            }
        } : nil
        return VStack(spacing: 0) {
            PhoneCalendarFeedback(model: model).padding(.horizontal, 16)
            TaskTimelineView(scope: scope, data: data, now: model.now, calendar: calendar, color: PhoneEntityColor.read,
                             open: { selectedTask = PhoneTaskRoute(id: $0) },
                             arrange: model.canBeginEditing ? editTimelineSchedule : nil,
                             capture: model.canBeginCapture ? captureTimelineTask : nil,
                             beginAdjustment: model.canBeginEditing ? beginTimelineAdjustment : nil,
                             arrangement: arrangement)
        }.id(scope)
    }

    private func scheduleFromScopedBoard(_ taskID: UUID, _ operation: CalendarScheduleOperation,
                                         _ revision: WorkspaceRevision) -> Bool {
        stageCalendarGesture(operation, payload: PhoneCalendarDrag(taskID: taskID, session: calendarDragSession, revision: revision))
    }

    private func captureTimelineTask(_ destination: TaskDestination, _ date: Date) {
        Task {
            await model.beginCapture(destination: destination, calendarDate: date, useExactDate: true)
            capturePresented = model.captureDraft != nil
        }
    }

    private func arrangeTimelineByDrop(_ drag: TaskTimelineArrangeDrag, _ operation: CalendarScheduleOperation) -> Bool {
        guard let document = model.document, let revision = drag.revision,
              let expected = try? JSONDecoder().decode(WorkspaceRevision.self, from: revision),
              document.revision == expected,
              let task = document.snapshot.workspace.tasks.first(where: { $0.id == drag.taskID }),
              task.updatedAt == drag.updatedAt, task.dueDate == nil,
              task.completedAt == nil, task.wontDoAt == nil else { return false }
        return stageCalendarGesture(operation, payload: PhoneCalendarDrag(taskID: task.id, session: calendarDragSession, revision: expected))
    }

    private func beginTimelineAdjustment(_ id: UUID) -> ((CalendarScheduleOperation) -> Void)? {
        guard model.canBeginEditing, let revision = model.document?.revision else { return nil }
        let payload = PhoneCalendarDrag(taskID: id, session: calendarDragSession, revision: revision)
        return { _ = stageCalendarGesture($0, payload: payload) }
    }

    private func editTimelineSchedule(_ id: UUID, at date: Date) {
        guard model.canBeginEditing, let document = model.document,
              let task = document.snapshot.workspace.tasks.first(where: { $0.id == id }) else { return }
        calendarEdit = PhoneCalendarEditRequest(task: task, expected: document.revision, focus: date,
                                                hourly: false, calendar: calendar, mode: .schedule)
    }

    private func sectionedPhoneRows(_ list: TaskList, data: WorkspaceData) -> some View {
        let tasks = destination.matchingTasks(in: data, now: model.now, calendar: calendar)
        let ordered = model.taskTimestampSort.map { tasks.sorted(by: $0.precedes) } ?? tasks
        let rows = PinnedGrouping.partition(ordered)
        let editable = !list.isArchived && model.canBeginEditing
        return ScrollView {
            if let sectionMoveNotice {
                Text(sectionMoveNotice).font(.footnote).foregroundStyle(.secondary)
            }
            if !rows.pinned.isEmpty {
                Text(PinnedGrouping.pinnedGroupTitle).font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                taskRows(rows.pinned, lists: data.lists, searchQuery: nil, sectionList: list)
            }
            ForEach(TaskSectionGroup.project(rows.rest, for: list, in: data)) { group in
                HStack {
                    Text(group.title).font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let section = group.section, editable && model.canBeginCapture {
                        Button { addSectionTask(listID: list.id, sectionID: section.id) } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Add task to " + section.name)
                    }
                }.frame(minHeight: 44).padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .dropDestination(for: PhoneBoardDrag.self) { payloads, _ in
                        guard editable, payloads.count == 1, let drag = payloads.first,
                              drag.session == sectionListDragSession, drag.listID == list.id else { return false }
                        movePhoneSectionTask(drag.taskID, to: group.id, listID: list.id)
                        return true
                    }
                taskRows(group.tasks, lists: data.lists, searchQuery: nil, sectionList: list)
            }
            Color.clear.frame(height: 90)
        }
    }

    private func movePhoneSectionTask(_ id: UUID, to sectionID: UUID?, listID: UUID) {
        Task {
            sectionMoveNotice = await model.saveSection(.init(listID: listID, operation: .assign(taskID: id, sectionID: sectionID)))
        }
    }

    private func taskList(_ tasks: [TaskItem], data: WorkspaceData, searchQuery: String? = nil) -> some View {
        let groups = PinnedGrouping.partition(tasks)
        let separateHistory = searchQuery != nil || ![.completed, .wontDo, .trash].contains(destination)
        let completed = separateHistory ? groups.rest.filter { $0.deletedAt == nil && $0.completedAt != nil } : []
        let abandoned = separateHistory ? groups.rest.filter { $0.deletedAt == nil && $0.completedAt == nil && $0.wontDoAt != nil } : []
        let ordinary = separateHistory
            ? groups.rest.filter { $0.deletedAt != nil || ($0.completedAt == nil && $0.wontDoAt == nil) }
            : groups.rest
        return ScrollView {
            if tasks.isEmpty { ContentUnavailableView("No matching tasks", systemImage: "checkmark.square", description: Text(searchQuery == nil ? "Add a task or choose another view." : "Change the search or its filters.")) }
            taskGroup(PinnedGrouping.pinnedGroupTitle, tasks: groups.pinned, lists: data.lists, searchQuery: searchQuery)
            taskRows(ordinary, lists: data.lists, searchQuery: searchQuery)
            taskGroup("Completed", tasks: completed, lists: data.lists, searchQuery: searchQuery)
            taskGroup("Won't Do", tasks: abandoned, lists: data.lists, searchQuery: searchQuery)
            Color.clear.frame(height: 90)
        }
    }
    @ViewBuilder private func taskGroup(_ title: String, tasks: [TaskItem], lists: [TaskList], searchQuery: String?) -> some View {
        if !tasks.isEmpty {
            Text(title).font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
            taskRows(tasks, lists: lists, searchQuery: searchQuery)
        }
    }
    private func taskRows(_ tasks: [TaskItem], lists: [TaskList], searchQuery: String?, sectionList: TaskList? = nil) -> some View {
        let ordered = TaskHierarchy.displayOrder(tasks)
        return LazyVStack(spacing: 0) {
            ForEach(ordered, id: \.task.id) { task, depth in
                HStack(spacing: 0) {
                    PhoneCompletionButton(model: model, task: task, lists: lists)
                    let titleButton = Button {
                        if let searchQuery { model.rememberSearch(searchQuery) }
                        selectedTask = PhoneTaskRoute(id: task.id)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.body).lineLimit(2)
                                    .foregroundStyle(task.completedAt != nil || task.wontDoAt != nil ? .secondary : .primary)
                                if let searchQuery {
                                    PhoneSearchResultContext(task: task, lists: lists, query: searchQuery)
                                }
                                if let due = task.dueDate {
                                    Text(due.formatted(.dateTime.month(.abbreviated).day())).font(.caption)
                                        .foregroundStyle(due < calendar.startOfDay(for: model.now) ? .red : .secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if task.richBody != nil {
                                Image(systemName: "textformat").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 48).padding(.trailing, 18).padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(task.title)
                    if let list = sectionList, !list.isArchived, model.canBeginEditing, task.parentID == nil {
                        titleButton
                            .contextMenu {
                                TaskSectionMoveMenu(sections: list.sections, current: task.sectionID) {
                                    movePhoneSectionTask(task.id, to: $0, listID: list.id)
                                }
                            }
                        PhoneSectionTaskGrip(task: task, session: sectionListDragSession, listID: list.id)
                    } else { titleButton }
                }.padding(.leading, 2 + CGFloat(min(depth, 4)) * 14)
                if task.id != ordered.last?.task.id { Divider().padding(.leading, 46) }
            }
        }.background(PhoneStyle.card, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 16)
    }
    private func navigation(_ snapshot: ReadOnlyWorkspaceSnapshot) -> some View {
        let data = snapshot.workspace
        let visibility = PhoneSmartDrawer(settings: snapshot.settings, data: data, now: model.now, calendar: calendar)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Taskovsky").font(.largeTitle.bold()).padding(.vertical, 20)
                    Text("Local preview").font(.caption).opacity(0.7)
                    ForEach(visibility.top, id: \.self) { item in navRow(item, data: data) }
                    organizationNavigation(data: data)
                    if visibility.filters {
                        Text("Filters").font(.headline).padding(.top, 20)
                        ForEach(data.filters) { filter in navRow(.filter(filter.id), data: data) }
                    }
                    if visibility.tags {
                        Text("Tags").font(.headline).padding(.top, 20)
                        tagDrawerRows(TagHierarchy.roots(in: data.tags), data: data, depth: 0)
                    }
                    if let tagDrawerError {
                        Text(tagDrawerError).font(.footnote).accessibilityIdentifier("tagDrawerError")
                    }
                    if !visibility.bottom.isEmpty {
                        Divider().overlay(.white.opacity(0.16)).padding(.top, 12)
                        ForEach(visibility.bottom, id: \.self) { item in navRow(item, data: data) }
                    }
                    Button { manageTemplates = true } label: {
                        Label("Manage Templates", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain).padding(.top, 16).accessibilityIdentifier("manageTemplates")
                    Text("Create tasks or notes locally. Styled descriptions are protected. Further settings are still in development.")
                        .font(.footnote).opacity(0.8).padding(.top, 24)
                }.padding(20)
            }.background(PhoneStyle.indigo).foregroundStyle(.white)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            guard let document = model.document else { return }
                            localSettingsRequest = PhoneLocalSettingsRequest(settings: document.snapshot.settings,
                                                                             revision: document.revision)
                        } label: {
                            Image(systemName: "gearshape")
                        }.tint(.white).accessibilityLabel("Settings").accessibilityIdentifier("openLocalSettings")
                        Button {
                            guard let document = model.document else { return }
                            smartListRequest = PhoneSmartListRequest(settings: document.snapshot.settings, revision: document.revision)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }.tint(.white).accessibilityLabel("Smart Lists").accessibilityIdentifier("openSmartLists")
                        Button { manageFilters = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }.tint(.white).accessibilityLabel("Manage Filters").accessibilityIdentifier("manageFilters")
                        Button { manageTags = true } label: {
                            Image(systemName: "tag")
                        }.tint(.white).accessibilityLabel("Manage Tags").accessibilityIdentifier("manageTags")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { drawer = false }.tint(.white).accessibilityIdentifier("drawerDone")
                    }
                }
        }
        .sheet(isPresented: $manageLists) { PhoneListOrganization(model: model) }
        .sheet(item: $smartListRequest) { request in PhoneSmartListSettings(model: model, request: request) }
        .sheet(isPresented: $manageFilters) { PhoneSavedFilters(model: model) }
        .sheet(isPresented: $manageTags) { PhoneTagManagement(model: model) }
        .sheet(isPresented: $manageTemplates) { PhoneTemplateManager(model: model) }
        .sheet(item: $localSettingsRequest) { request in PhoneLocalSettings(model: model, request: request) }
    }

    @ViewBuilder private func organizationNavigation(data: WorkspaceData) -> some View {
        let active = data.lists.filter { !$0.isArchived }
        let pinned = active.filter(\.isPinned)
        let pinnedFolders = data.folders.filter(\.isPinned)
        let pinnedFilters = data.filters.filter(\.isPinned)
        let pinnedTags = data.tags.filter(\.isPinned)
        let archived = data.lists.filter(\.isArchived)
        if !pinned.isEmpty || !pinnedFolders.isEmpty || !pinnedFilters.isEmpty || !pinnedTags.isEmpty {
            Text("Pinned").font(.headline).padding(.top, 20)
            ForEach(pinned) { list in navRow(.list(list.id), data: data, shortcut: true) }
            ForEach(pinnedFolders) { folder in folderRows(folder, lists: active, data: data, shortcut: true) }
            ForEach(pinnedFilters) { filter in navRow(.filter(filter.id), data: data, shortcut: true) }
            ForEach(pinnedTags) { tag in navRow(.tag(tag.id), data: data, shortcut: true) }
        }
        HStack {
            Text("Lists").font(.headline)
            Spacer()
            Button { manageLists = true } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Manage Lists").accessibilityIdentifier("manageLists")
        }.padding(.top, 12)
        ForEach(active.filter { ListPlacement($0) == .aboveFolders }) { list in navRow(.list(list.id), data: data) }
        ForEach(data.folders) { folder in folderRows(folder, lists: active, data: data) }
        ForEach(active.filter { ListPlacement($0) == .belowFolders }) { list in navRow(.list(list.id), data: data) }
        if !archived.isEmpty {
            Text("Archived Lists").font(.headline).padding(.top, 20)
            ForEach(archived) { list in navRow(.list(list.id), data: data) }
        }
    }

    private func tagDrawerRows(_ tags: [TaskTag], data: WorkspaceData, depth: Int) -> AnyView {
        AnyView(ForEach(tags) { tag in
            let children = TagHierarchy.children(of: tag.id, in: data.tags)
            HStack(spacing: 0) {
                navRow(.tag(tag.id), data: data)
                if !children.isEmpty {
                    Button {
                        guard let revision = model.document?.revision else { return }
                        Task { tagDrawerError = await model.saveTag(.setCollapsed(tag.id, !tag.isCollapsed), expected: revision) }
                    } label: {
                        Image(systemName: tag.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption).frame(width: 44, height: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!model.canBeginEditing)
                        .accessibilityLabel((tag.isCollapsed ? "Expand " : "Collapse ") + tag.name)
                        .accessibilityIdentifier("drawerTagDisclosure-" + tag.id.uuidString)
                }
            }.padding(.leading, CGFloat(min(depth, 4)) * 12)
            if !tag.isCollapsed { tagDrawerRows(children, data: data, depth: depth + 1) }
        })
    }

    @ViewBuilder private func folderRows(_ folder: ListFolder, lists: [TaskList], data: WorkspaceData, shortcut: Bool = false) -> some View {
        let members = lists.filter { $0.folderID == folder.id }
        let collapsed = collapsedFolders.contains(folder.id)
        HStack(spacing: 0) {
            Button {
                if collapsed { collapsedFolders.remove(folder.id) } else { collapsedFolders.insert(folder.id) }
            } label: {
                HStack {
                    Label(shortcut ? "Pinned " + folder.name : folder.name, systemImage: "folder")
                    Spacer()
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.caption)
                }.padding(.horizontal, 12).frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
                .accessibilityIdentifier((shortcut ? "pinnedFolder-" : "drawerFolder-") + folder.id.uuidString)
            Button {
                destination = .folder(folder.id)
                section = .tasks
                drawer = false
            } label: {
                Image(systemName: "arrow.right.circle").frame(width: 44, height: 44)
            }.buttonStyle(.plain)
                .accessibilityLabel("Open " + (shortcut ? "pinned " : "") + folder.name)
                .accessibilityIdentifier((shortcut ? "openPinnedFolder-" : "openFolder-") + folder.id.uuidString)
        }
        if !collapsed {
            ForEach(members) { list in navRow(.list(list.id), data: data, shortcut: shortcut).padding(.leading, 12) }
        }
    }

    private func navRow(_ item: TaskDestination, data: WorkspaceData, shortcut: Bool = false) -> some View {
        let count = item.matchingTasks(in: data, showHistory: false, now: model.now, calendar: calendar).count
        let label = title(item, in: data)
        let identifier: String
        if case .tag(let id) = item { identifier = (shortcut ? "pinnedTag-" : "drawerTag-") + id.uuidString }
        else { identifier = item.smartKey.map { "smartDrawer-" + $0.rawValue } ?? "" }
        return Button { destination = item; section = .tasks; drawer = false } label: {
            HStack {
                if case .list(let id) = item, let list = data.lists.first(where: { $0.id == id }) {
                    Image(systemName: list.symbol ?? (list.kind == .note ? "doc.text" : "list.bullet"))
                        .foregroundStyle(list.phoneListColor).accessibilityHidden(true)
                }
                if case .tag(let id) = item, let tag = data.tags.first(where: { $0.id == id }) {
                    Image(systemName: "tag").foregroundStyle(PhoneEntityColor.read(tag.color)).accessibilityHidden(true)
                }
                Text(label)
                Spacer()
                Text("\(count)").opacity(0.65)
            }
                .padding(.horizontal, 12).frame(minHeight: 44).background(destination == item ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(shortcut ? "Pinned " + label : label)
            .accessibilityValue(String(count))
            .accessibilityIdentifier(identifier)
    }
    private func calendarBody(data: WorkspaceData) -> some View {
        let revision = model.document?.revision
        let controls = PhoneCalendarControls(
            drag: { entry in
                guard entry.canSchedule, model.canBeginEditing, let revision = model.document?.revision else { return nil }
                return PhoneCalendarDrag(taskID: entry.taskID, session: calendarDragSession, revision: revision)
            },
            edit: { entry, mode in
                guard entry.canSchedule, model.canBeginEditing, let document = model.document,
                      let task = document.snapshot.workspace.tasks.first(where: { $0.id == entry.taskID }) else { return }
                calendarEdit = PhoneCalendarEditRequest(task: task, expected: document.revision, focus: focus,
                                                        hourly: options.mode.isHourly, calendar: calendar, mode: mode)
            },
            drop: acceptCalendarDrop,
            resize: { payload, operation in
                _ = stageCalendarGesture(operation, payload: payload)
            },
            saveFoldedHours: { cutoffs in saveCalendarFoldedHours(cutoffs, expected: revision) },
            createRange: model.canBeginCapture ? { dates in
                Task {
                    await model.beginCapture(destination: .all, calendarDate: dates.upperBound, calendarRange: dates)
                    capturePresented = model.captureDraft != nil
                }
            } : nil
        )
        return MobileCalendarPreview(data: data, calendar: calendar, today: model.now, focus: $focus,
                                     options: options, controls: controls,
                                     select: selectCalendarMode) { id in selectedTask = PhoneTaskRoute(id: id) }

    }

    private func acceptCalendarDrop(_ payload: PhoneCalendarDrag, _ target: PhoneCalendarDropTarget) -> Bool {
        guard let task = model.document?.snapshot.workspace.tasks.first(where: { $0.id == payload.taskID }) else { return false }
        let operation: CalendarScheduleOperation = switch target {
        case .allDay(let day): .move(start: day, allDay: true)
        case .hour(let date): .move(start: date, allDay: false)
        case .day(let day): CalendarScheduling.moveOnDay(task, day: day, forceAllDay: false, calendar: calendar)
        }
        return stageCalendarGesture(operation, payload: payload)
    }

    private func stageCalendarGesture(_ operation: CalendarScheduleOperation, payload: PhoneCalendarDrag) -> Bool {
        guard occurrenceChange == nil, payload.session == calendarDragSession, model.canBeginEditing,
              let document = model.document, document.revision == payload.revision,
              let task = document.snapshot.workspace.tasks.first(where: { $0.id == payload.taskID }),
              task.deletedAt == nil, !SmartListEligibility.isArchived(task, lists: document.snapshot.workspace.lists) else { return false }
        let change = PhoneOccurrenceChange(drag: payload, operation: operation)
        if CalendarScheduling.canRescheduleCurrentOccurrence(task, in: document.snapshot.workspace.tasks) { occurrenceChange = change }
        else { saveCalendarGesture(change, scope: .series) }
        return true
    }

    private func saveCalendarGesture(_ change: PhoneOccurrenceChange, scope: CalendarScheduleScope) {
        Task {
            await model.dropCalendarTask(change.operation, taskID: change.drag.taskID, expected: change.drag.revision, scope: scope)
        }
    }

    private func saveCalendarFoldedHours(_ cutoffs: CalendarFoldedHours, expected: WorkspaceRevision?) {
        guard let expected, let document = model.document else { return }
        guard document.revision == expected else {
            preferenceNotice = "Saved Calendar preferences changed. Try the adjustment again."
            return
        }
        var draft = document.snapshot.settings.calendarOptions
        guard draft.foldedHours != cutoffs else { return }
        draft.foldedHours = cutoffs
        Task { preferenceNotice = await model.saveCalendarOptions(draft, expected: expected) }
    }

    private func selectCalendarMode(_ mode: TaskCalendarMode, at date: Date) {
        guard !model.isBusy, let document = model.document else { return }
        var draft = document.snapshot.settings.calendarOptions
        if mode == draft.mode {
            sessionCalendarMode = nil
            preferenceNotice = nil
            focus = date
            return
        }
        draft.mode = mode
        Task {
            if let error = await model.saveCalendarOptions(draft, expected: document.revision) {
                sessionCalendarMode = mode
                preferenceNotice = "View changed for this session. " + error
            } else {
                sessionCalendarMode = nil
                preferenceNotice = nil
            }
            focus = date
        }
    }

    private func openCalendarPreferences(_ kind: PhoneCalendarPreferenceKind) {
        guard let document = model.document else { return }
        calendarPreferenceRoute = PhoneCalendarPreferenceRoute(kind: kind, options: document.snapshot.settings.calendarOptions,
                                                               expected: document.revision)
    }

    private func calendarAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            showCalendarActions = false
            action()
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
