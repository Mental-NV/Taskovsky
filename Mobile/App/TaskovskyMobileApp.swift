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

private struct PhoneOccurrenceScopeDialog: ViewModifier {
    @Binding var change: PhoneOccurrenceChange?
    var enabled = true
    let save: (PhoneOccurrenceChange, CalendarScheduleScope) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog("Apply schedule change to", isPresented: Binding(
            get: { enabled && change != nil },
            set: { if enabled && !$0 { change = nil } }
        ), titleVisibility: .visible, presenting: enabled ? change : nil) { change in
            Button("This occurrence") { save(change, .currentOccurrence) }
            Button("Series") { save(change, .series) }
            Button("Cancel") { self.change = nil }
        }
    }
}
private struct PhoneBatchRequest: Identifiable {
    let id = UUID()
    let scope: String
    let tasks: [TaskItem]
    let document: WorkspaceDocument
    var onlyAction: TaskBatchEdit.Kind? = nil
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
    @State private var collapsedSubtasks: Set<UUID> = []
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
    @State private var revealedTaskSwipe: PhoneTaskSwipeSelection?
    @State private var countdownRows: Set<UUID> = []
    @State private var taskRowEditor: PhoneTaskRowEditor?
    @State private var search = TaskFilter(name: "", status: .all)
    @State private var focus = MobilePreviewFixture.day
    @State private var sessionCalendarMode: TaskCalendarMode?
    @State private var calendarPreferenceRoute: PhoneCalendarPreferenceRoute?
    @State private var preferenceNotice: String?
    @State private var calendarChecklistError: String?
    @State private var viewPicker = false
    @State private var jumpDatePresented = false
    @State private var showTaskSort = false
    @State private var showTaskActions = false
    @State private var showTextBatch = false
    @State private var batchRequest: PhoneBatchRequest?
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
            .onChange(of: model.taskCountdownEnabled) { _, enabled in
                if !enabled { countdownRows.removeAll() }
            }
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
    @State private var taskListDragSession = UUID()
    @State private var sectionMoveNotice: String?
    @State private var taskOrderNotice: String?

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
                                    let candidates = TaskBatchEdit.calendarPostponeCandidates(in: snapshot.workspace, options: options)
                                    calendarAction("Postpone Tasks", symbol: "clock.arrow.circlepath") {
                                        guard let document = model.document else { return }
                                        model.clearBatchNotice()
                                        batchRequest = PhoneBatchRequest(scope: "Calendar sources", tasks: candidates,
                                                                         document: document, onlyAction: .postpone)
                                    }.disabled(!model.canBeginEditing || candidates.isEmpty)
                                }.padding(8).frame(width: 220).presentationCompactAdaptation(.popover)
                            }
                    } else {
                        Text("Taskovsky").font(.subheadline).foregroundStyle(.secondary)
                        if section == .tasks {
                            let showsSort = showsTaskSort(in: snapshot.workspace)
                            if showsSort { taskSortMenu }
                            if destination != .trash && (showsSort || TaskTextBatch.isAvailable(in: destination, workspace: snapshot.workspace)) {
                                taskActions(snapshot.workspace, showsSelection: showsSort)
                            }
                        }
                    }
                }.padding(.horizontal, 16)
                Text(model.isQA ? "Sample workspace · Local editing" : "Local workspace · Early development").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("previewNotice")
                if model.recoveredDraft != nil || model.activeDraft != nil {
                    Button(model.activeDraft != nil ? "Continue your edit" : "Resume saved edit", action: resumeEdit).frame(minHeight: 44)
                }
                if let notice = model.creationNotice { Text(notice).font(.caption).accessibilityIdentifier("captureSuccess") }
                if selectedTask == nil {
                    PhoneLifecycleFeedback(model: model).padding(.horizontal, 16)
                    if section == .tasks { PhoneScheduleFeedback(model: model, surface: .tasks).padding(.horizontal, 16) }
                }
                if model.recoveredCapture != nil || model.captureDraft != nil {
                    Button("Resume new task", action: resumeCapture).frame(minHeight: 44).disabled(model.activeDraft != nil)
                }
                if model.protectedCapture { Text("A saved capture is unreadable or unsupported. Its file is kept; editing is blocked.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
                if let error = model.captureError, model.captureDraft == nil { Text(error).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
                if model.protectedDraft { Text("A saved edit uses an unreadable or unsupported format. Its file is kept; editing is blocked.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
                switch section {
                case .tasks:
                    Text(title(destination, in: snapshot.workspace)).font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    if let batchNotice = model.batchNotice {
                        Text(batchNotice).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("batchNotice")
                    }
                    if let taskOrderNotice {
                        Text(taskOrderNotice).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("taskOrderNotice")
                    }
                    taskDestination(snapshot.workspace)
                case .calendar:
                    if let batchNotice = model.batchNotice {
                        Text(batchNotice).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("batchNotice")
                    }
                    if let preferenceNotice {
                        Text(preferenceNotice).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("calendarPreferenceNotice").padding(.horizontal, 16)
                    }
                    if let calendarChecklistError {
                        Text(calendarChecklistError).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("calendarChecklistError").padding(.horizontal, 16)
                    }
                    if !showArrange {
                        PhoneScheduleFeedback(model: model, surface: .calendar).padding(.horizontal, 16)
                    }
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
        .sheet(item: $taskRowEditor) { editor in
            switch editor {
            case .schedule(let request): PhoneScheduleSheet(model: model, request: request)
            case .priority(let request): PhoneTaskMetadataSheet(model: model, request: request)
            case .move(let request): PhoneTaskMoveSheet(model: model, request: request)
            }
        }
        .sheet(isPresented: $showTextBatch) { textBatchSheet.presentationDetents([.large]) }
        .sheet(item: $batchRequest) { request in taskBatchSheet(request).presentationDetents([.large]) }
        .onChange(of: destination) { _, _ in
            model.clearBatchNotice()
            revealedTaskSwipe = nil
            taskOrderNotice = nil
            taskListDragSession = UUID()
        }
        .onChange(of: section) { _, _ in model.clearBatchNotice(); revealedTaskSwipe = nil }
        .sheet(item: $calendarPreferenceRoute) { route in
            PhoneCalendarPreferences(model: model, route: route)
        }
        .sheet(isPresented: $jumpDatePresented) {
            PhoneCalendarDateJump(date: focus, calendar: calendar) { date in focus = date }
        }
        .sheet(isPresented: $showArrange) {
            let allowsDrag = options.mode.isHourly || options.mode == .month || options.mode == .multiWeek
            PhoneCalendarArrangeSheet(model: model, focus: focus, options: options,
                                      drag: allowsDrag ? calendarDrag : nil)
                .modifier(PhoneOccurrenceScopeDialog(change: $occurrenceChange, save: saveCalendarGesture))
        }
        .modifier(PhoneOccurrenceScopeDialog(change: $occurrenceChange, enabled: !showArrange, save: saveCalendarGesture))
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
            .accessibilityValue(model.taskSort?.title ?? "Default Order")
            .accessibilityIdentifier("taskSortMenu")
            .popover(isPresented: $showTaskSort, arrowEdge: .top) {
                VStack(spacing: 0) {
                    taskSortChoice(nil)
                    ForEach(PhoneTaskSort.choices, id: \.self) { taskSortChoice($0) }
                    if destination.supportsTaskDateGrouping {
                        Divider()
                        groupingChoice(.creationDate)
                        groupingChoice(.dueDate)
                    }
                }.padding(8).frame(width: 245).presentationCompactAdaptation(.popover)
            }
    }

    private func taskSortChoice(_ choice: PhoneTaskSort?) -> some View {
        let selected = model.taskSort == choice
        return Button {
            showTaskSort = false
            taskOrderNotice = nil
            taskListDragSession = UUID()
            model.setTaskSort(choice)
        } label: {
            HStack {
                Text(choice?.title ?? "Default Order")
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }.frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func taskActions(_ data: WorkspaceData, showsSelection: Bool) -> some View {
        let tasks = destination.matchingTasks(in: data, now: model.now, calendar: calendar)
        return circle("Tasks actions", symbol: "ellipsis") { showTaskActions = true }
            .accessibilityIdentifier("taskListActions")
            .popover(isPresented: $showTaskActions, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    if showsSelection {
                        Button {
                            guard let document = model.document else { return }
                            showTaskActions = false
                            model.clearBatchNotice()
                            let ordered = model.taskSort.map { tasks.sorted(by: $0.precedes) } ?? tasks
                            batchRequest = PhoneBatchRequest(scope: title(destination, in: data), tasks: ordered, document: document)
                        } label: {
                            Label("Select Tasks", systemImage: "checklist")
                                .frame(minHeight: 44, alignment: .leading)
                        }.disabled(!model.canBeginEditing || tasks.isEmpty)
                            .accessibilityIdentifier("batchOpen")
                    }
                    if TaskTextBatch.isAvailable(in: destination, workspace: data) {
                        Button {
                            showTaskActions = false
                            showTextBatch = true
                        } label: {
                            Label("Add Multiple Tasks", systemImage: "plus.rectangle.on.rectangle")
                                .frame(minHeight: 44, alignment: .leading)
                        }.disabled(!model.canBeginEditing)
                            .accessibilityIdentifier("batchCaptureOpen")
                    }
                }.buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 6)
                    .presentationCompactAdaptation(.popover)
            }
    }

    private var textBatchSheet: some View {
        TaskTextBatchSheet { text, recognizesDetails in
            guard let document = model.document else { throw TaskTextBatchValidation.unavailableDestination }
            let snapshot = document.snapshot
            let batch = try TaskTextBatch(text: text, destination: destination, workspace: snapshot.workspace,
                                          settings: snapshot.settings, now: model.now, calendar: calendar,
                                          recognizesDetails: recognizesDetails)
            return TaskTextBatchReview(batch: batch, calendar: calendar, tags: snapshot.workspace.tags) {
                await model.saveTextBatch(batch, expected: document.revision)
            }
        }
    }

    private func taskBatchSheet(_ request: PhoneBatchRequest) -> some View {
        let data = request.document.snapshot.workspace
        return TaskBatchSheet(scope: request.scope, tasks: request.tasks, data: data,
                              calendar: calendar, today: model.now, onlyAction: request.onlyAction) { edit in
            let error = await model.saveBatch(edit, expected: request.document.revision)
            if error == nil { model.showBatchNotice(edit.action.kind.completionMessage) }
            return error
        }
    }

    private func groupingChoice(_ grouping: TaskListGrouping) -> some View {
        let selected = model.taskGrouping == grouping
        return Button {
            showTaskSort = false
            taskOrderNotice = nil
            taskListDragSession = UUID()
            model.setTaskGrouping(selected ? .standard : grouping)
        } label: {
            HStack {
                Text(grouping.title)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }.frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func taskDestinationRows(_ data: WorkspaceData) -> some View {
        let tasks = destination.matchingTasks(in: data, now: model.now, calendar: calendar)
        let ordered = model.taskSort.map { tasks.sorted(by: $0.precedes) } ?? tasks
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
            } else if !list.sections.isEmpty && (list.viewMode == .board || model.taskGrouping == .standard) {
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
            PhoneScheduleFeedback(model: model, surface: .calendar).padding(.horizontal, 16)
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
        let ordered = model.taskSort.map { tasks.sorted(by: $0.precedes) } ?? tasks
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
                              drag.session == taskListDragSession, drag.listID == list.id,
                              drag.revision == model.document?.revision else { return false }
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
            if searchQuery == nil && destination.supportsTaskDateGrouping && model.taskGrouping == .creationDate {
                ForEach(TaskCreationDayGroup.group(ordinary, calendar: calendar, sort: model.taskSort?.timestamp)) { group in
                    taskGroup(group.title(calendar: calendar), tasks: group.tasks, lists: data.lists, searchQuery: nil)
                }
            } else if searchQuery == nil && destination.supportsTaskDateGrouping && model.taskGrouping == .dueDate {
                let settings = model.document?.snapshot.settings ?? AppSettings()
                ForEach(TaskDueDateGroup.group(ordinary, now: model.now, calendar: calendar,
                                             overduePosition: settings.overduePosition)) { group in
                    taskGroup(group.title(now: model.now, calendar: calendar), tasks: group.tasks, lists: data.lists, searchQuery: nil)
                }
            } else {
                taskRows(ordinary, lists: data.lists, searchQuery: searchQuery)
            }
            taskGroup("Completed", tasks: completed, lists: data.lists, searchQuery: searchQuery)
            taskGroup("Won't Do", tasks: abandoned, lists: data.lists, searchQuery: searchQuery)
            Color.clear.frame(height: 90)
        }
    }
    @ViewBuilder private func taskGroup(_ title: String, tasks: [TaskItem], lists: [TaskList], searchQuery: String?) -> some View {
        if !tasks.isEmpty {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
            taskRows(tasks, lists: lists, searchQuery: searchQuery)
        }
    }
    private func taskRows(_ tasks: [TaskItem], lists: [TaskList], searchQuery: String?, sectionList: TaskList? = nil) -> some View {
        let showsDisclosure = searchQuery == nil
        let ordered = TaskHierarchy.listRows(tasks, collapsed: showsDisclosure ? collapsedSubtasks : [])
        let revision = model.canBeginEditing ? model.document?.revision : nil
        let manual = searchQuery == nil && model.taskSort == nil &&
            !(destination.supportsTaskDateGrouping && model.taskGrouping != .standard)
        let displayCalendar = searchQuery == nil && destination.supportsTaskDateGrouping && model.taskGrouping == .dueDate
            ? calendar : nil
        let peers = manual && revision != nil
            ? Dictionary(grouping: tasks.filter {
                $0.deletedAt == nil && $0.completedAt == nil && $0.wontDoAt == nil &&
                    !SmartListEligibility.isArchived($0, lists: lists)
            }, by: \.parentID).mapValues { $0.map(\.id) }
            : [:]
        return LazyVStack(spacing: 0) {
            ForEach(ordered, id: \.task.id) { row in
                let task = row.task
                let due = displayCalendar.flatMap { TaskDueDateGroup.displayDue(for: task, calendar: $0) } ?? task.dueDate
                let actions = searchQuery == nil ? taskSwipeActions(for: task, lists: lists) : ([], [])
                let siblings = peers[task.parentID] ?? []
                let canReorder = siblings.count > 1 && siblings.contains(task.id)
                let sectionDrag = sectionList.map { !$0.isArchived && task.parentID == nil } ?? false
                PhoneTaskSwipeRow(taskID: task.id, leading: actions.0, trailing: actions.1, selection: $revealedTaskSwipe) { gesture in
                    HStack(spacing: 0) {
                        PhoneCompletionButton(model: model, task: task, lists: lists)
                        let switchesDate = searchQuery == nil && model.taskCountdownEnabled &&
                            TaskDueCountdown.label(for: task, now: model.now, calendar: calendar) != nil
                        let titleButton = Button {
                            if let searchQuery { model.rememberSearch(searchQuery) }
                            revealedTaskSwipe = nil
                            selectedTask = PhoneTaskRoute(id: task.id)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title).font(.body).lineLimit(2)
                                        .foregroundStyle(task.completedAt != nil || task.wontDoAt != nil ? .secondary : .primary)
                                    if let searchQuery {
                                        PhoneSearchResultContext(task: task, lists: lists, query: searchQuery)
                                    }
                                    if !switchesDate, let due {
                                        taskDateText(due, displayCalendar: displayCalendar)
                                    }
                                }
                                Spacer(minLength: 0)
                                if task.richBody != nil {
                                    Image(systemName: "textformat").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(minHeight: switchesDate ? 24 : 48).padding(.trailing, 18).padding(.vertical, 3)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(task.title)
                            .accessibilityValue(displayCalendar.flatMap { display in due.map { taskDateCaption($0, displayCalendar: display) } } ?? "")
                            .background {
                                if !actions.0.isEmpty || !actions.1.isEmpty { gesture }
                            }
                            .accessibilityActions {
                                ForEach(actions.0 + actions.1) { action in
                                    Button(action.title) {
                                        revealedTaskSwipe = nil
                                        action.run()
                                    }
                                }
                                if canReorder, let revision, let index = siblings.firstIndex(of: task.id) {
                                    if index > 0 {
                                        Button("Move earlier") {
                                            reorderPhoneTask(task.id, relativeTo: siblings[index - 1], after: false, expected: revision)
                                        }
                                    }
                                    if index + 1 < siblings.count {
                                        Button("Move later") {
                                            reorderPhoneTask(task.id, relativeTo: siblings[index + 1], after: true, expected: revision)
                                        }
                                    }
                                }
                            }
                        let rowContent = VStack(alignment: .leading, spacing: 0) {
                            titleButton
                            if switchesDate, let due { taskCountdownButton(task, due: due, displayCalendar: displayCalendar) }
                        }
                        if let list = sectionList, sectionDrag, revision != nil {
                            rowContent
                                .contextMenu {
                                    TaskSectionMoveMenu(sections: list.sections, current: task.sectionID) {
                                        movePhoneSectionTask(task.id, to: $0, listID: list.id)
                                    }
                                }
                        } else { rowContent }
                        if showsDisclosure && row.hasChildren {
                            taskSubtreeDisclosure(task)
                        }
                        if let revision, canReorder || sectionDrag {
                            PhoneTaskRowGrip(task: task, payload: PhoneBoardDrag(session: taskListDragSession,
                                listID: task.listID, taskID: task.id, revision: revision))
                        }
                    }.padding(.leading, 2 + CGFloat(min(row.depth, 4)) * 14)
                }
                .modifier(PhoneTaskRowOrderDrop(accept: canReorder ? { drag, after in
                    guard drag.session == taskListDragSession, let revision, drag.revision == revision,
                          drag.taskID != task.id, siblings.contains(drag.taskID) else { return false }
                    reorderPhoneTask(drag.taskID, relativeTo: task.id, after: after, expected: revision)
                    return true
                } : nil))
                if task.id != ordered.last?.task.id { Divider().padding(.leading, 46) }
            }
        }.background(PhoneStyle.card, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 16)
    }

    private func taskSubtreeDisclosure(_ task: TaskItem) -> some View {
        let expanded = !collapsedSubtasks.contains(task.id)
        return Button {
            revealedTaskSwipe = nil
            if expanded { collapsedSubtasks.insert(task.id) } else { collapsedSubtasks.remove(task.id) }
        } label: {
            Image(systemName: expanded ? "chevron.down" : "chevron.forward")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel((expanded ? "Hide subtasks of " : "Show subtasks of ") + task.title)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("taskSubtreeDisclosure-" + task.id.uuidString)
    }

    private func reorderPhoneTask(_ id: UUID, relativeTo target: UUID, after: Bool, expected: WorkspaceRevision) {
        revealedTaskSwipe = nil
        Task {
            taskOrderNotice = await model.saveTaskOrder(id, relativeTo: target, after: after, expected: expected)
        }
    }

    private func taskDateCaption(_ due: Date, displayCalendar: Calendar?) -> String {
        guard let displayCalendar else { return due.formatted(.dateTime.month(.abbreviated).day()) }
        return due.formatted(Date.FormatStyle(calendar: displayCalendar, timeZone: displayCalendar.timeZone).month(.abbreviated).day())
    }

    private func taskDateText(_ due: Date, displayCalendar: Calendar?) -> some View {
        Text(taskDateCaption(due, displayCalendar: displayCalendar)).font(.caption)
            .foregroundStyle(due < calendar.startOfDay(for: model.now) ? .red : .secondary)
    }

    private func taskCountdownButton(_ task: TaskItem, due: Date, displayCalendar: Calendar?) -> some View {
        Button {
            if !countdownRows.insert(task.id).inserted { countdownRows.remove(task.id) }
            revealedTaskSwipe = nil
        } label: {
            Group {
                if countdownRows.contains(task.id) {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let now = model.isQA ? model.now : context.date
                        if let label = TaskDueCountdown.label(for: task, now: now, calendar: calendar) {
                            Text(label).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        } else { taskDateText(due, displayCalendar: displayCalendar) }
                    }
                } else { taskDateText(due, displayCalendar: displayCalendar) }
            }
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityHint("Switches between the due date and countdown")
            .accessibilityIdentifier("taskCountdown-" + task.id.uuidString)
    }

    private func taskSwipeActions(for task: TaskItem, lists: [TaskList]) -> ([PhoneTaskSwipeAction], [PhoneTaskSwipeAction]) {
        guard model.canBeginEditing, let document = model.document else { return ([], []) }
        func lifecycle(_ kind: PhoneTaskSwipeAction.Kind, _ command: TaskLifecycleCommand) -> PhoneTaskSwipeAction? {
            guard TaskLifecycle.refusal(for: command, task: task, lists: lists) == nil else { return nil }
            return PhoneTaskSwipeAction(id: kind) {
                Task { await model.performLifecycle(command, taskID: task.id, expected: document.revision) }
            }
        }
        let leading = [lifecycle(.complete, .complete), lifecycle(.reopen, .reopen), lifecycle(.restore, .restore)].compactMap { $0 }
        var trailing: [PhoneTaskSwipeAction] = []
        if task.deletedAt == nil && !SmartListEligibility.isArchived(task, lists: lists) {
            if task.kind == .task {
                trailing.append(PhoneTaskSwipeAction(id: .schedule) {
                    taskRowEditor = .schedule(PhoneScheduleRequest(task: task, document: document, calendar: calendar, now: model.now))
                })
            }
            trailing.append(PhoneTaskSwipeAction(id: .priority) {
                taskRowEditor = .priority(PhoneTaskMetadataRequest(task: task, revision: document.revision, kind: .priority))
            })
        }
        if TaskLifecycle.refusal(for: .move(nil), task: task, lists: lists) == nil {
            trailing.append(PhoneTaskSwipeAction(id: .move) {
                taskRowEditor = .move(PhoneTaskMoveRequest(task: task, revision: document.revision))
            })
        }
        if let trash = lifecycle(.trash, .trash) { trailing.append(trash) }
        return (leading, trailing)
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
                                                                             revision: document.revision,
                                                                             taskCountdownEnabled: model.taskCountdownEnabled)
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
                    PhoneListIcon(symbol: list.symbol, fallback: list.kind == .note ? "doc.text" : "list.bullet")
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
                guard entry.canSchedule, let revision else { return nil }
                return calendarDrag(for: entry.taskID, revision: revision)
            },
            edit: { entry, mode in
                guard entry.canSchedule, model.canBeginEditing, let document = model.document,
                      let task = document.snapshot.workspace.tasks.first(where: { $0.id == entry.taskID }) else { return }
                calendarEdit = PhoneCalendarEditRequest(task: task, expected: document.revision, focus: focus,
                                                        hourly: options.mode.isHourly, calendar: calendar, mode: mode)
            },
            complete: model.canBeginEditing ? { entry in
                changeCalendarCompletion(entry, expected: revision)
            } : nil,
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
        let holdsMonthPosition = model.isBusy || calendarEdit != nil || occurrenceChange != nil
            || capturePresented || model.captureDraft != nil || selectedTask != nil || batchRequest != nil
        return MobileCalendarPreview(data: data, calendar: calendar, today: model.now, focus: $focus,
                                     options: options, monthInteractionActive: holdsMonthPosition, controls: controls,
                                     select: selectCalendarMode) { id in selectedTask = PhoneTaskRoute(id: id) }

    }

    private func changeCalendarCompletion(_ entry: CalendarEntry, expected: WorkspaceRevision?) {
        guard entry.canChangeCompletion, let expected else { return }
        calendarChecklistError = nil
        Task {
            if let itemID = entry.checklistID {
                let change = TaskMetadataChange.setChecklistCompleted(id: itemID, completed: !entry.isCompleted)
                calendarChecklistError = await model.saveTaskMetadata(change, taskID: entry.taskID, expected: expected)
            } else {
                await model.performLifecycle(entry.isCompleted ? .reopen : .complete,
                                             taskID: entry.taskID, expected: expected)
            }
        }
    }

    private func calendarDrag(for taskID: UUID, revision: WorkspaceRevision) -> PhoneCalendarDrag? {
        guard model.canBeginEditing, model.document?.revision == revision else { return nil }
        return PhoneCalendarDrag(taskID: taskID, session: calendarDragSession, revision: revision)
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
