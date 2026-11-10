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
private enum PhoneStyle {
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
    @State private var capturePresented = false
    @State private var drawer = false
    @State private var selectedTask: PhoneTaskRoute?
    @State private var search = ""
    @State private var focus = MobilePreviewFixture.day
    @State private var options = TaskCalendarOptions()
    @State private var filterSheet = false
    @State private var viewPicker = false
    private var calendar: Calendar { model.calendar }
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
                if !initialized, let document = model.document {
                    initialized = true; options = document.snapshot.settings.calendarOptions; focus = model.now
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
    private func addCapture() {
        Task {
            await model.beginCapture(destination: section == .tasks ? destination : .all, calendarDate: section == .calendar ? focus : nil)
            capturePresented = model.captureDraft != nil
        }
    }
    private func resumeEdit() {
        guard let draft = model.activeDraft ?? model.recoveredDraft else { return }
        if model.activeDraft == nil { model.resumeRecovery() }
        selectedTask = PhoneTaskRoute(id: draft.taskID, preferEditor: true)
    }
    private func shell(_ snapshot: ReadOnlyWorkspaceSnapshot) -> some View {
        ZStack(alignment: .bottom) {
            PhoneStyle.page.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    circle("Open navigation", symbol: "line.3.horizontal") { drawer = true }
                    Spacer()
                    if section == .calendar {
                        Text(focus.formatted(.dateTime.month(.wide))).font(.headline)
                        Spacer()
                        Button { viewPicker = true } label: {
                            Image(systemName: "calendar").frame(width: 44, height: 44)
                        }.accessibilityLabel("Calendar view")
                            .popover(isPresented: $viewPicker, arrowEdge: .top) {
                                VStack(spacing: 0) {
                                    ForEach(TaskCalendarMode.allCases, id: \.self) { mode in
                                        Button { options.mode = mode; viewPicker = false } label: {
                                            HStack { Text(mode.title); Spacer(); if options.mode == mode { Image(systemName: "checkmark") } }
                                                .frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                    }
                                }.padding(8).frame(width: 220).presentationCompactAdaptation(.popover)
                            }
                        circle("Calendar filters", symbol: "line.3.horizontal.decrease") { filterSheet = true }
                    } else { Text("Taskovsky").font(.subheadline).foregroundStyle(.secondary) }
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
                    taskList(destination.matchingTasks(in: snapshot.workspace, now: model.now, calendar: calendar), data: snapshot.workspace)
                case .calendar:
                    calendarBody(data: snapshot.workspace)
                case .search:
                    searchBody(data: snapshot.workspace)
                }
            }.padding(.top, 4)
            VStack {
                Spacer()
                HStack { Spacer(); Button(action: addCapture) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .medium)).frame(width: 48, height: 48)
                        .background(PhoneStyle.accent, in: Circle()).foregroundStyle(.white)
                }.disabled(!model.canBeginCapture).accessibilityLabel("Add").accessibilityIdentifier("openCapture") }
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
        .sheet(isPresented: $drawer) { navigation(data: snapshot.workspace).presentationDetents([.large]) }
        .sheet(item: $selectedTask) { route in PhoneTaskSheet(model: model, route: route, close: { selectedTask = nil }) }
        .sheet(isPresented: $filterSheet) { calendarFilters(data: snapshot.workspace) }
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
        case .list(let id): data.lists.first { $0.id == id }?.name ?? "List unavailable"
        case .tag(let id): data.tags.first { $0.id == id }?.name ?? "Tag unavailable"
        case .filter(let id): data.filters.first { $0.id == id }?.name ?? "Filter unavailable"
        default: "Tasks"
        }
    }
    private func taskList(_ tasks: [TaskItem], data: WorkspaceData) -> some View {
        let groups = PinnedGrouping.partition(tasks)
        let separateHistory = section == .search || ![.completed, .wontDo, .trash].contains(destination)
        let completed = separateHistory ? groups.rest.filter { $0.deletedAt == nil && $0.completedAt != nil } : []
        let abandoned = separateHistory ? groups.rest.filter { $0.deletedAt == nil && $0.completedAt == nil && $0.wontDoAt != nil } : []
        let ordinary = separateHistory
            ? groups.rest.filter { $0.deletedAt != nil || ($0.completedAt == nil && $0.wontDoAt == nil) }
            : groups.rest
        return ScrollView {
            if tasks.isEmpty { ContentUnavailableView("No matching tasks", systemImage: "checkmark.square", description: Text("Add a task or choose another view.")) }
            taskGroup(PinnedGrouping.pinnedGroupTitle, tasks: groups.pinned, lists: data.lists)
            taskRows(ordinary, lists: data.lists)
            taskGroup("Completed", tasks: completed, lists: data.lists)
            taskGroup("Won't Do", tasks: abandoned, lists: data.lists)
            Color.clear.frame(height: 90)
        }
    }
    @ViewBuilder private func taskGroup(_ title: String, tasks: [TaskItem], lists: [TaskList]) -> some View {
        if !tasks.isEmpty {
            Text(title).font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
            taskRows(tasks, lists: lists)
        }
    }
    private func taskRows(_ tasks: [TaskItem], lists: [TaskList]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(tasks) { task in
                HStack(spacing: 0) {
                    PhoneCompletionButton(model: model, task: task, lists: lists)
                    Button { selectedTask = PhoneTaskRoute(id: task.id) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.body).lineLimit(2)
                                    .foregroundStyle(task.completedAt != nil || task.wontDoAt != nil ? .secondary : .primary)
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
                }.padding(.leading, 2)
                if task.id != tasks.last?.id { Divider().padding(.leading, 46) }
            }
        }.background(PhoneStyle.card, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 16)
    }
    private func navigation(data: WorkspaceData) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Taskovsky").font(.largeTitle.bold()).padding(.vertical, 20)
                    Text("Local preview").font(.caption).opacity(0.7)
                    ForEach([TaskDestination.all, .today, .tomorrow, .week, .inbox, .completed, .wontDo, .trash], id: \.self) { item in navRow(item, data: data) }
                    Text("Lists").font(.headline).padding(.top, 20)
                    ForEach(data.lists) { list in navRow(.list(list.id), data: data) }
                    Text("Tags").font(.headline).padding(.top, 20)
                    ForEach(data.tags) { tag in navRow(.tag(tag.id), data: data) }
                    Text("Filters").font(.headline).padding(.top, 20)
                    ForEach(data.filters) { filter in navRow(.filter(filter.id), data: data) }
                    Text("Create tasks or notes locally. Styled descriptions are protected; Board, Summary and further settings are still in development.")
                        .font(.footnote).opacity(0.8).padding(.top, 24)
                }.padding(20)
            }.background(PhoneStyle.indigo).foregroundStyle(.white)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { drawer = false }.tint(.white) } }
        }
    }
    private func navRow(_ item: TaskDestination, data: WorkspaceData) -> some View {
        let count = item.matchingTasks(in: data, showHistory: false, now: model.now, calendar: calendar).count
        return Button { destination = item; section = .tasks; drawer = false } label: {
            HStack { Text(title(item, in: data)); Spacer(); Text("\(count)").opacity(0.65) }
                .padding(.horizontal, 12).frame(minHeight: 44).background(destination == item ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title(item, in: data))
            .accessibilityValue(String(count))
    }
    private func searchBody(data: WorkspaceData) -> some View {
        VStack(spacing: 16) {
            TextField("Search tasks, lists, tags or filters", text: $search).textFieldStyle(.roundedBorder).padding(.horizontal, 16).submitLabel(.search).accessibilityIdentifier("workspaceSearch")
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ContentUnavailableView("Search your preview", systemImage: "magnifyingglass") }
            else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(data.lists.filter { $0.name.localizedCaseInsensitiveContains(search) }) { item in Button(item.name) { destination = .list(item.id); section = .tasks }.buttonStyle(.bordered) }
                        ForEach(data.tags.filter { $0.name.localizedCaseInsensitiveContains(search) }) { item in Button("#" + item.name) { destination = .tag(item.id); section = .tasks }.buttonStyle(.bordered) }
                        ForEach(data.filters.filter { $0.name.localizedCaseInsensitiveContains(search) }) { item in Button(item.name) { destination = .filter(item.id); section = .tasks }.buttonStyle(.bordered) }
                    }.padding(.horizontal, 16)
                }
                taskList(data.tasks.filter { TaskFilter(name: "Search", keyword: search).matches($0, lists: data.lists, now: model.now, calendar: calendar) }, data: data)
            }
            Spacer(minLength: 0)
        }
    }
    private func calendarBody(data: WorkspaceData) -> some View {
        MobileCalendarPreview(data: data, calendar: calendar, today: model.now, focus: $focus, options: $options) { id in selectedTask = PhoneTaskRoute(id: id) }
    }
    private func calendarFilters(data: WorkspaceData) -> some View {
        NavigationStack {
            List {
                Section { Button { options.selectAllSources() } label: { Label("All", systemImage: options.isAllSources ? "checkmark.circle.fill" : "circle") } }
                Section("Lists") {
                    sourceRow("Inbox", selected: options.isInboxSelected) { options.setInboxSelected(!options.isInboxSelected, data: data) }
                    ForEach(data.lists.filter { !$0.isArchived }) { list in
                        sourceRow(list.name, selected: options.selectedListIDs(in: data).contains(list.id)) { options.setListSelected(list.id, !options.selectedListIDs(in: data).contains(list.id), data: data) }
                    }
                }
                Section("Tags") { ForEach(data.tags) { tag in
                    sourceRow(tag.name, selected: options.tagIDs.contains(tag.id)) { options.setTagSelected(tag.id, !options.tagIDs.contains(tag.id), data: data) }
                } }
                Section { Text("These preview choices last until the app closes. Saved task data stays unchanged.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Calendar filters").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { filterSheet = false } } }
        }
    }
    private func sourceRow(_ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(name); Spacer(); Image(systemName: selected ? "checkmark.square.fill" : "square") }
                .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(name)
            .accessibilityValue(selected ? "Selected" : "Not selected")
    }

}
