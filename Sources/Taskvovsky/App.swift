import SwiftUI
import AppKit
import TaskvovskyCore

@main
struct TaskvovskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore()
    var body: some Scene {
        WindowGroup("Taskvovsky") { WorkspaceView(store: store).frame(minWidth: 780, minHeight: 500) }
            .defaultSize(width: 1280, height: 740)
            .windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("New Task") { NotificationCenter.default.post(name: .newTask, object: nil) }.keyboardShortcut("n")
                    Button("New Note") { NotificationCenter.default.post(name: .newNote, object: nil) }.keyboardShortcut("n", modifiers: [.command, .shift])
                    Divider()
                    Button("New List") { NotificationCenter.default.post(name: .newList, object: nil) }.keyboardShortcut("l", modifiers: [.command, .shift])
                }
                CommandGroup(after: .newItem) {
                    Button("Search") { NotificationCenter.default.post(name: .openSearch, object: nil) }.keyboardShortcut("f")
                    Button("Toggle Sidebar") { NotificationCenter.default.post(name: .toggleSidebar, object: nil) }.keyboardShortcut("s", modifiers: [.command, .option])
                }
            }
        Settings { SettingsView(store: store) }.defaultSize(width: 800, height: 680).windowStyle(.hiddenTitleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension Notification.Name {
    static let newTask = Notification.Name("Taskvovsky.newTask")
    static let newNote = Notification.Name("Taskvovsky.newNote")
    static let newList = Notification.Name("Taskvovsky.newList")
    static let openSearch = Notification.Name("Taskvovsky.openSearch")
    static let toggleSidebar = Notification.Name("Taskvovsky.toggleSidebar")
}

let accent = Color(red: 0.30, green: 0.42, blue: 0.96)
let palette = ["#526BF5", "#EC6574", "#E7A548", "#58A58B", "#9C7BD5", "#5BA7CC", "#8A8F98"]
extension Color {
    init(hex: String) {
        let n = UInt32(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x526BF5
        self.init(red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255)
    }
}
extension TaskPriority {
    var label: String { self == .none ? "No priority" : rawValue.capitalized + " priority" }
    var color: Color { switch self { case .high: .red; case .medium: .orange; case .low: accent; case .none: .secondary } }
    var rank: Int { switch self { case .high: 0; case .medium: 1; case .low: 2; case .none: 3 } }
}
extension RepeatRule { var label: String { self == .none ? "Does not repeat" : rawValue.capitalized } }
extension TaskItem {
    var scheduleCalendar: Calendar { var cal = Calendar.current; if let timeZoneID, let zone = TimeZone(identifier: timeZoneID) { cal.timeZone = zone }; return cal }
    func dayText(_ date: Date) -> String { let formatter = DateFormatter(); formatter.timeZone = scheduleCalendar.timeZone; formatter.setLocalizedDateFormatFromTemplate("d MMM"); return formatter.string(from: date) }
    func timeText(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.timeZone = scheduleCalendar.timeZone; formatter.timeStyle = .short
        let zone = scheduleCalendar.timeZone
        return formatter.string(from: date) + (zone.identifier != TimeZone.current.identifier ? " " + (zone.abbreviation(for: date) ?? zone.identifier) : "")
    }
}

enum Destination: Hashable {
    case all, today, tomorrow, week, inbox, notes, reminders, completed, wontDo, summary, search, trash, list(UUID), tag(UUID), filter(UUID)
    var symbol: String {
        switch self {
        case .all: "tray.full"; case .today: "calendar"; case .tomorrow: "sun.horizon"; case .week: "calendar.badge.clock"
        case .inbox: "tray"; case .notes: "doc.text"; case .reminders: "bell"; case .completed: "checkmark.circle"
        case .trash: "trash"; case .list: "line.3.horizontal"; case .tag: "number"; case .wontDo: "xmark.square"; case .summary: "doc.plaintext"; case .search: "magnifyingglass"; case .filter: "line.3.horizontal.decrease"
        }
    }
    func title(_ data: WorkspaceData) -> String {
        switch self {
        case .all: "All"; case .today: "Today"; case .tomorrow: "Tomorrow"; case .week: "Next 7 Days"
        case .inbox: "Inbox"; case .notes: "Notes"; case .reminders: "Reminders"; case .completed: "Completed"; case .trash: "Trash"
        case .list(let id): data.lists.first { $0.id == id }?.name ?? "List"
        case .tag(let id): data.tags.first { $0.id == id }?.name ?? "Tag"
        case .filter(let id): data.filters.first { $0.id == id }?.name ?? "Filter"
        case .wontDo: "Won't Do"; case .summary: "Summary"; case .search: "Search"
        }
    }
    func includes(_ task: TaskItem, now: Date = Date()) -> Bool {
        if self == .trash { return task.deletedAt != nil }
        guard task.deletedAt == nil else { return false }
        if self == .wontDo { return task.wontDoAt != nil }
        if self == .summary { return task.updatedAt >= Calendar.current.date(byAdding: .day, value: -7, to: now)! }
        if self == .completed { return task.completedAt != nil }
        guard task.completedAt == nil && task.wontDoAt == nil else { return false }
        let cal = task.scheduleCalendar
        let day = cal.startOfDay(for: now)
        switch self {
        case .all: return task.kind == .task
        case .today: return task.kind == .task && task.dueDate.map { $0 < cal.date(byAdding: .day, value: 1, to: day)! } == true
        case .tomorrow: return task.kind == .task && task.dueDate.map { cal.isDate($0, inSameDayAs: cal.date(byAdding: .day, value: 1, to: day)!) } == true
        case .week: return task.kind == .task && task.dueDate.map { $0 < cal.date(byAdding: .day, value: 7, to: day)! } == true
        case .inbox: return task.listID == nil
        case .notes: return task.kind == .note
        case .reminders: return task.reminderDate != nil
        case .list(let id): return task.listID == id
        case .tag(let id): return task.tagIDs.contains(id)
        case .completed, .trash, .wontDo, .summary, .search, .filter: return false
        }
    }
    var smartKey: SmartListKey? {
        switch self { case .all: .all; case .today: .today; case .tomorrow: .tomorrow; case .week: .week; case .inbox: .inbox; case .summary: .summary; case .completed: .completed; case .wontDo: .wontDo; case .trash: .trash; default: nil }
    }
}

struct WorkspaceView: View {
    @ObservedObject var store: TaskStore
    @State private var destination: Destination = .today
    @State private var selection: UUID?
    @State private var quickTitle = ""
    @State private var quickKind: TaskKind = .task
    @State private var sort = "Date"
    @State private var showCompleted = true
    @State private var collapsed: Set<String> = []
    @State private var editor: EntityEditor?
    @State private var trashed: UUID?
    @State private var recoveryAlert = false
    @State private var searchDialog = false
    @State private var searchQuery = ""
    @State private var filterEditor: TaskFilter?
    @State private var creatingFilter = false
    @State private var templatePicker = false
    @State private var feedback: TaskFeedback?
    @AppStorage("Taskvovsky.sidebarWidth") private var sidebarWidth = 215.0
    @AppStorage("Taskvovsky.sidebarCollapsed") private var sidebarCollapsed = false
    @AppStorage("Taskvovsky.taskPaneFraction") private var taskPaneFraction = 0.45
    @State private var sidebarDragStart: Double?
    @State private var paneDragStart: Double?
    @State private var nextCreationKind: TaskKind?
    @FocusState private var quickFocused: Bool

    var selectedTask: TaskItem? { store.data.tasks.first { $0.id == selection } }
    var activeList: TaskList? {
        if case .list(let id) = destination { return store.data.lists.first { $0.id == id } }; return nil
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            GeometryReader { geometry in
                let showSidebar = !sidebarCollapsed && destination != .search && geometry.size.width >= 860
                let navWidth = showSidebar ? min(320, max(160, sidebarWidth)) : 0
                let available = geometry.size.width - 62 - navWidth - (showSidebar ? 1 : 0)
                let listWidth = min(available - 280, max(300, available * taskPaneFraction))
                HStack(spacing: 0) {
                    rail
                    if showSidebar {
                        sidebar(now: timeline.date).frame(width: navWidth)
                        PanelDivider { delta, ended in
                            if sidebarDragStart == nil { sidebarDragStart = sidebarWidth }
                            let proposed = sidebarDragStart! + delta
                            sidebarWidth = min(320, max(160, proposed))
                            if ended { if proposed < 135 { sidebarWidth = sidebarDragStart!; sidebarCollapsed = true }; sidebarDragStart = nil }
                        }.onTapGesture(count: 2) { sidebarCollapsed.toggle() }
                    }
                    Group {
                        if destination == .search {
                            SearchPane(store: store, initialQuery: searchQuery, onSelectTask: selectSearchTask, onSelectList: { destination = .list($0) }, onSelectFilter: { destination = .filter($0) }, onSelectTag: { destination = .tag($0) }, onClose: { destination = .inbox }).id(searchQuery)
                        } else { taskPane(now: timeline.date) }
                    }.frame(width: listWidth)
                    PanelDivider { delta, ended in
                        if paneDragStart == nil { paneDragStart = listWidth }
                        taskPaneFraction = min(available - 280, max(300, paneDragStart! + delta)) / available
                        if ended { paneDragStart = nil }
                    }
                    Group {
                        if let task = selectedTask {
                            TaskDetail(store: store, id: task.id, onTrash: { trash(task.id) }, onComplete: { complete(task.id) }, onWontDo: { abandon(task.id) }).id(task.id)
                        } else { DetailPlaceholder() }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .tint(accent)
            .overlay(alignment: .bottom) {
                if let error = store.storageError {
                    HStack {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                        if store.needsRecovery { Button("Recover…") { recoveryAlert = true } }
                        else { Button("Retry") { store.save() } }
                    }.font(.caption).padding(12).background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10)).padding()
                } else if let trashed {
                    HStack { Text("Moved to Trash"); Button("Undo") { store.restoreTask(id: trashed); self.trashed = nil }; Button { self.trashed = nil } label: { Image(systemName: "xmark") } }
                        .font(.callout).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).shadow(radius: 5).padding(20)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let feedback {
                    HStack(spacing: 14) {
                        Text(feedback.message).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                        Button { undo(feedback) } label: { Image(systemName: "arrow.uturn.backward").font(.system(size: 16, weight: .semibold)).foregroundStyle(.orange) }.buttonStyle(.plain).help("Undo").accessibilityLabel("Undo \(feedback.message)")
                    }.padding(.horizontal, 16).padding(.vertical, 12).background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 9)).shadow(color: .black.opacity(0.2), radius: 12, y: 4).padding(24)
                }
            }
        }
        .alert("Recover workspace?", isPresented: $recoveryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Back up and recover") { store.recoverUnreadableWorkspace() }
        } message: { Text("The unreadable file will be copied to a backup beside workspace.json. Your current in-memory items will then be saved as the new workspace.") }
        .sheet(item: $editor) { item in
            EntitySheet(editor: item) { name, color, kind in
                if item.isTag {
                    if let id = item.entityID { store.updateTag(TaskTag(id: id, name: name, color: color)) }
                    else { _ = store.createTag(name: name, color: color) }
                } else {
                    if let id = item.entityID { store.updateList(TaskList(id: id, name: name, color: color, kind: kind)) }
                    else { destination = .list(store.createList(name: name, color: color, kind: kind)) }
                }
            }
        }
        .sheet(isPresented: $searchDialog) {
            SearchDialog(store: store, onSearch: { searchQuery = $0; destination = .search; selection = nil; searchDialog = false }, onSelectTask: { selectSearchTask($0); searchDialog = false }, onSelectList: { destination = .list($0); searchDialog = false }, onSelectFilter: { destination = .filter($0); searchDialog = false }, onSelectTag: { destination = .tag($0); searchDialog = false })
        }
        .sheet(item: $filterEditor) { FilterEditorView(store: store, filter: $0) }
        .sheet(isPresented: $creatingFilter) { FilterEditorView(store: store) }
        .sheet(isPresented: $templatePicker) {
            TemplatePicker(store: store) { template in
                selection = store.createTaskFromTemplate(id: template.id, listID: activeList?.id, dueDate: contextualDate, useDefaultList: destination != .inbox && activeList == nil)
                templatePicker = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in quickKind = .task; if destination == .trash || destination == .completed || destination == .wontDo || destination == .search || destination == .summary { nextCreationKind = .task; destination = .inbox }; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in if destination != .inbox && activeList == nil { nextCreationKind = .note; destination = .inbox }; quickKind = .note; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newList)) { _ in editor = EntityEditor(isTag: false) }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in searchDialog = true }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in sidebarCollapsed.toggle() }
        .onChange(of: destination) { _, _ in
            if let task = selectedTask, !destination.includes(task) { selection = nil }
            quickKind = nextCreationKind ?? (activeList?.kind == .note ? .note : .task); nextCreationKind = nil
        }
        .onChange(of: store.data.tasks) { _, tasks in
            if let id = trashed, tasks.first(where: { $0.id == id })?.deletedAt == nil { trashed = nil }
        }
    }

    private var rail: some View {
        VStack(spacing: 26) {
            Spacer().frame(height: 12)
            ZStack { RoundedRectangle(cornerRadius: 10).fill(accent); Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundStyle(.white) }.frame(width: 34, height: 34).help("Taskvovsky")
            railButton("checkmark.square.fill", title: "Tasks", active: destination != .search) { destination = .today }
            railButton("magnifyingglass", title: "Search", active: destination == .search) { searchDialog = true }
            Spacer()
            SettingsLink { Image(systemName: "gearshape").font(.system(size: 22)).foregroundStyle(.secondary) }.buttonStyle(.plain).help("Settings · ⌘,").accessibilityLabel("Settings")
            Spacer().frame(height: 18)
        }.frame(width: 62).background(Color(nsColor: .controlBackgroundColor))
    }
    private func railButton(_ symbol: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 22)).frame(width: 38, height: 38).foregroundStyle(active ? accent : .secondary).background(active ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    private func sidebar(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach([Destination.all, .today, .tomorrow, .week, .inbox, .summary].filter { visible($0, now: now) }, id: \.self) { dest in navRow(dest, now: now) }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    sectionHeading("Lists") { editor = EntityEditor(isTag: false) }
                    ForEach(store.data.lists) { list in
                        navRow(.list(list.id), color: Color(hex: list.color), now: now)
                            .contextMenu {
                                Button("Edit List…") { editor = EntityEditor(list: list) }
                                Button("Delete List", role: .destructive) { store.deleteList(id: list.id); if destination == .list(list.id) { destination = .inbox } }
                                Text("Tasks are moved to Inbox")
                            }
                    }
                    if sectionVisible(.filters, count: store.data.filters.count) {
                        sectionHeading("Filters") { creatingFilter = true }.padding(.top, 20)
                        ForEach(store.data.filters) { filter in
                            navRow(.filter(filter.id), now: now).contextMenu { Button("Edit Filter…") { filterEditor = filter }; Button("Delete Filter", role: .destructive) { store.deleteFilter(id: filter.id); if destination == .filter(filter.id) { destination = .inbox } } }
                        }
                        if store.data.filters.isEmpty { Text("Display tasks filtered by list, date, priority, tag, and more").font(.system(size: 12)).foregroundStyle(.secondary).padding(10).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8)) }
                    }
                    if sectionVisible(.tags, count: store.data.tags.count) {
                    sectionHeading("Tags") { editor = EntityEditor(isTag: true) }.padding(.top, 20)
                    ForEach(store.data.tags) { tag in
                        navRow(.tag(tag.id), color: Color(hex: tag.color), now: now)
                            .contextMenu {
                                Button("Edit Tag…") { editor = EntityEditor(tag: tag) }
                                Button("Delete Tag", role: .destructive) { store.deleteTag(id: tag.id); if destination == .tag(tag.id) { destination = .all } }
                            }
                    }
                    }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    ForEach([Destination.completed, .wontDo, .trash].filter { visible($0, now: now) }, id: \.self) { navRow($0, now: now) }
                }.padding(.horizontal, 8).padding(.top, 12)
            }
        }.background(Color(nsColor: .textBackgroundColor))
    }
    private func sectionHeading(_ text: String, action: @escaping () -> Void) -> some View {
        HStack { Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary); Spacer(); Button(action: action) { Image(systemName: "plus").font(.system(size: 12)) }.buttonStyle(.plain).help("Add \(text == "Tags" ? "tag" : text == "Filters" ? "filter" : "list")") }.padding(.horizontal, 10).padding(.bottom, 6)
    }
    private func navRow(_ dest: Destination, color: Color? = nil, now: Date) -> some View {
        let count = store.data.tasks.filter { task in
            if case .filter(let id) = dest { return store.data.filters.first { $0.id == id }?.matches(task, now: now, calendar: store.settings.calendar) ?? false }
            return dest.includes(task, now: now)
        }.count
        return Button { destination = dest } label: {
            HStack(spacing: 11) {
                Image(systemName: dest.symbol).font(.system(size: 16)).foregroundStyle(color ?? (destination == dest ? accent : .secondary)).frame(width: 20)
                Text(dest.title(store.data)).font(.system(size: 16)).lineLimit(1)
                Spacer(minLength: 2)
                if count > 0 { Text("\(count)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit() }
            }.padding(.horizontal, 10).frame(height: 38).contentShape(Rectangle())
                .background(destination == dest ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            if dest == .inbox { return move(items, to: nil) }
            if case .list(let id) = dest { return move(items, to: id) }
            return false
        }
    }
    private func move(_ items: [String], to listID: UUID?) -> Bool {
        for item in items { if let id = UUID(uuidString: item), var task = store.data.tasks.first(where: { $0.id == id }) { task.listID = listID; store.updateTask(task) } }
        return true
    }
    private func taskPane(now: Date) -> some View {
        let tasks = filteredTasks(now: now)
        let groups = grouped(tasks, now: now)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Button { sidebarCollapsed.toggle() } label: { Image(systemName: "sidebar.left").font(.system(size: 16)) }.buttonStyle(.plain).help("Toggle sidebar").accessibilityLabel("Toggle sidebar")
                Text(destination.title(store.data)).font(.system(size: 20, weight: .bold)).lineLimit(1)
                Spacer()
                Menu {
                    Picker("Sort by", selection: $sort) { ForEach(["Date", "Priority", "Title", "Created"], id: \.self) { Text($0) } }
                    if destination != .completed && destination != .trash && destination != .wontDo { Toggle("Show Completed & Won't Do", isOn: $showCompleted) }
                } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 16)) }.menuStyle(.borderlessButton).fixedSize().help("Sort and display")
            }.padding(.horizontal, 20).frame(height: 58)
            if destination == .summary { Text("Updated in the last 7 days").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 12) }
            if destination != .trash && destination != .completed && destination != .wontDo && destination != .summary {
                HStack(spacing: 10) {
                    Menu {
                        Button("Task") { quickKind = .task }; Button("Note") { quickKind = .note }
                        Divider()
                        Button("Add from Template…") { templatePicker = true }
                    } label: { Image(systemName: quickKind == .task ? "plus" : "doc.text").font(.system(size: 16)).foregroundStyle(.secondary) }.menuStyle(.borderlessButton).fixedSize().help("Choose task, note, or template")
                    TextField(quickKind == .task ? "Add task" : "Add note", text: $quickTitle).textFieldStyle(.plain).font(.system(size: 16)).focused($quickFocused).onSubmit(addTask)
                    if !quickTitle.isEmpty { Button(action: addTask) { Image(systemName: "arrow.up.circle.fill").foregroundStyle(accent) }.buttonStyle(.plain).help("Add") }
                }.padding(.horizontal, 13).frame(height: 38).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 20).padding(.bottom, 16)
            }
            if destination == .reminders { Text("Check due and upcoming reminders here. New items are set for one hour from now.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 16) }
            if destination == .trash { Text("Deleted items stay here until you restore them.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 16) }
            if tasks.isEmpty {
                VStack(spacing: 12) { Spacer(); Image(systemName: destination == .trash ? "trash" : "checkmark.circle").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(accent.opacity(0.5)); Text(destination == .trash ? "Trash is empty" : "All clear").font(.system(size: 17, weight: .medium)); Text(destination == .today ? "Enjoy the space. Add something for today." : "Your \(destination == .notes ? "notes" : "tasks") will appear here.").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Spacer() }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.0) { title, items in
                            Button { if collapsed.contains(title) { collapsed.remove(title) } else { collapsed.insert(title) } } label: {
                                HStack(spacing: 7) { Image(systemName: collapsed.contains(title) ? "chevron.right" : "chevron.down").font(.system(size: 9, weight: .semibold)); Text(title).font(.system(size: 12, weight: .semibold)); Text("\(items.count)").font(.system(size: 11)).foregroundStyle(.tertiary); Spacer() }.foregroundStyle(title == "Overdue" || title == "Due reminders" ? .red : .secondary).padding(.vertical, 10)
                            }.buttonStyle(.plain)
                            if !collapsed.contains(title) { ForEach(items) { task in
                                TaskRow(store: store, id: task.id, selected: selection == task.id, now: now, toggle: { complete(task.id) })
                                    .contentShape(Rectangle()).onTapGesture { selection = task.id }
                                    .draggable(task.id.uuidString)
                                    .contextMenu { taskMenu(task) }
                            } }
                        }
                    }.padding(.horizontal, 18).padding(.bottom, 24)
                }
            }
        }
    }
    @ViewBuilder private func taskMenu(_ task: TaskItem) -> some View {
        if task.deletedAt != nil { Button("Restore") { store.restoreTask(id: task.id) } }
        else {
            if task.kind == .task { Button(task.completedAt == nil && task.wontDoAt == nil ? "Complete" : "Mark incomplete") { complete(task.id) }; if task.wontDoAt == nil { Button("Won't Do") { abandon(task.id) } } }
            Menu("Priority") { ForEach(TaskPriority.allCases, id: \.self) { value in Button(value.label) { var t = task; t.priority = value; store.updateTask(t) } } }
            Menu("Move to") { Button("Inbox") { var t = task; t.listID = nil; store.updateTask(t) }; ForEach(store.data.lists) { list in Button(list.name) { var t = task; t.listID = list.id; store.updateTask(t) } } }
            Button("Duplicate") { selection = store.duplicateTask(id: task.id) }
            Button("Save as Template") { _ = store.saveTemplate(from: task.id) }
            Divider(); Button("Move to Trash", role: .destructive) { trash(task.id) }
        }
    }
    private func filteredTasks(now: Date) -> [TaskItem] {
        store.data.tasks.filter { task in
            if case .filter(let id) = destination { return store.data.filters.first { $0.id == id }?.matches(task, now: now, calendar: store.settings.calendar) ?? false }
            if destination.includes(task, now: now) { return true }
            if showCompleted && destination != .completed && destination != .trash && destination != .wontDo && (task.completedAt != nil || task.wontDoAt != nil) && task.deletedAt == nil { var copy = task; copy.completedAt = nil; copy.wontDoAt = nil; return destination.includes(copy, now: now) }
            return false
        }.sorted { a, b in
            let aActive = a.completedAt == nil && a.wontDoAt == nil
            let bActive = b.completedAt == nil && b.wontDoAt == nil
            if aActive != bActive { return aActive }
            switch sort {
            case "Priority": if a.priority != b.priority { return a.priority.rank < b.priority.rank }
            case "Title": return a.title.localizedStandardCompare(b.title) == .orderedAscending
            case "Created": return a.createdAt > b.createdAt
            default: break
            }
            let ad = destination == .reminders ? a.reminderDate : a.dueDate
            let bd = destination == .reminders ? b.reminderDate : b.dueDate
            if ad != bd { return (ad ?? .distantFuture) < (bd ?? .distantFuture) }
            if a.priority != b.priority { return a.priority.rank < b.priority.rank }
            return store.settings.defaultAddTo == .top ? a.createdAt > b.createdAt : a.createdAt < b.createdAt
        }
    }
    private func grouped(_ tasks: [TaskItem], now: Date) -> [(String, [TaskItem])] {
        var keys: [String] = []; var values: [String: [TaskItem]] = [:]
        for task in tasks {
            let title: String
            if destination == .trash { title = "Deleted" }
            else if task.completedAt != nil || task.wontDoAt != nil {
                title = destination == .completed ? "Completed" : destination == .wontDo ? "Won't Do" : "Completed & Won't Do"
            }
            else if destination == .reminders { title = task.reminderDate! <= now ? "Due reminders" : "Upcoming reminders" }
            else if task.kind == .note { title = "Notes" }
            else if sort == "Priority" { title = task.priority.label }
            else if let due = task.dueDate {
                if due < task.scheduleCalendar.startOfDay(for: now) { title = "Overdue" }
                else if task.scheduleCalendar.isDate(due, inSameDayAs: now) { title = "Today" }
                else if task.scheduleCalendar.isDate(due, inSameDayAs: task.scheduleCalendar.date(byAdding: .day, value: 1, to: now)!) { title = "Tomorrow" }
                else { title = due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
            } else { title = "No Date" }
            if values[title] == nil { keys.append(title) }; values[title, default: []].append(task)
        }
        if store.settings.overduePosition == .bottom, let i = keys.firstIndex(of: "Overdue") { keys.remove(at: i); keys.insert("Overdue", at: keys.firstIndex(of: "Completed & Won't Do") ?? keys.firstIndex(of: "Completed") ?? keys.endIndex) }
        return keys.map { ($0, values[$0]!) }
    }
    private func addTask() {
        let title = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        let due = contextualDate
        let id = store.createTask(title: title, listID: activeList?.id, kind: quickKind, dueDate: quickKind == .task ? due : nil, useDefaultList: destination != .inbox && activeList == nil, preferRecognizedDate: true)
        if case .tag(let tagID) = destination, var task = store.data.tasks.first(where: { $0.id == id }), !task.tagIDs.contains(tagID) { task.tagIDs.append(tagID); store.updateTask(task) }
        if destination == .reminders, var task = store.data.tasks.first(where: { $0.id == id }) { task.reminderDate = due; task.hasDueTime = quickKind == .task; store.updateTask(task) }
        if quickKind == .note && (destination == .today || destination == .tomorrow || destination == .week || destination == .all) { destination = .inbox }
        if let created = store.data.tasks.first(where: { $0.id == id }), !destination.includes(created), destination != .search {
            if case .filter = destination { } else if case .tag = destination { } else { destination = created.listID.map(Destination.list) ?? .inbox }
        }
        selection = id; quickTitle = ""; quickFocused = true
    }
    private func trash(_ id: UUID) { store.trashTask(id: id); trashed = id; if selection == id { selection = nil } }
    private var contextualDate: Date? {
        let cal = store.settings.calendar
        return destination == .today || destination == .week ? cal.startOfDay(for: Date()) : destination == .tomorrow ? cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) : nil
    }
    private func sectionVisible(_ key: SmartListKey, count: Int) -> Bool {
        switch store.settings.smartListVisibility[key] ?? .show { case .show: true; case .hidden: false; case .showIfNotEmpty: count > 0 }
    }
    private func visible(_ dest: Destination, now: Date) -> Bool {
        guard let key = dest.smartKey else { return true }
        return sectionVisible(key, count: store.data.tasks.filter { dest.includes($0, now: now) }.count)
    }
    private func selectSearchTask(_ id: UUID) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        if destination != .search { destination = task.deletedAt != nil ? .trash : task.wontDoAt != nil ? .wontDo : task.completedAt != nil ? .completed : task.listID.map(Destination.list) ?? .inbox }
        selection = id
    }
    private func complete(_ id: UUID) {
        guard let task = store.data.tasks.first(where: { $0.id == id }) else { return }
        if task.wontDoAt != nil { store.reopenTask(id: id); return }
        let wasComplete = task.completedAt != nil
        store.toggleComplete(id: id)
        if !wasComplete {
            if store.settings.completionSound { CompletionSound.play() }
            showFeedback(TaskFeedback(taskID: id, kind: .complete, message: "Task completed"))
        }
    }
    private func abandon(_ id: UUID) { store.markWontDo(id: id); showFeedback(TaskFeedback(taskID: id, kind: .wontDo, message: "Task abandoned")) }
    private func showFeedback(_ value: TaskFeedback) {
        feedback = value
        Task { try? await Task.sleep(for: .seconds(5)); if feedback?.id == value.id { feedback = nil } }
    }
    private func undo(_ value: TaskFeedback) { if value.kind == .complete { store.undoCompletion(id: value.taskID) } else { store.reopenTask(id: value.taskID) }; feedback = nil }
}

struct TaskRow: View {
    @ObservedObject var store: TaskStore
    let id: UUID
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var listName: String? { store.data.lists.first { $0.id == task.listID }?.name }
    private var tags: [TaskTag] { store.data.tags.filter { task.tagIDs.contains($0.id) } }
    let selected: Bool
    let now: Date
    let toggle: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            if task.kind == .note { Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 18, height: 20) }
            else { Button(action: toggle) { Image(systemName: task.wontDoAt != nil ? "xmark.square.fill" : task.completedAt == nil ? "square" : "checkmark.square.fill").font(.system(size: 16, weight: .light)).foregroundStyle(task.completedAt == nil && task.wontDoAt == nil ? task.priority.color : .secondary) }.buttonStyle(.plain).disabled(task.deletedAt != nil).help(task.completedAt == nil && task.wontDoAt == nil ? "Complete task" : "Mark incomplete").accessibilityLabel(task.completedAt == nil && task.wontDoAt == nil ? "Complete \(task.title)" : "Reopen \(task.title)") }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(task.title.isEmpty ? "Untitled" : task.title).font(.system(size: 16)).foregroundStyle(task.completedAt == nil && task.wontDoAt == nil ? .primary : .secondary).lineLimit(1).layoutPriority(1)
                    Spacer(minLength: 4)
                    if !task.body.isEmpty { Image(systemName: "doc.plaintext").font(.system(size: 10)).foregroundStyle(.tertiary) }
                    if !task.checklist.isEmpty { Text("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)").font(.system(size: 10)).foregroundStyle(.tertiary) }
                    if let tag = tags.first { Text("#" + tag.name).font(.system(size: 11)).foregroundStyle(Color(hex: tag.color)).lineLimit(1) }
                    if task.recurrence != .none { Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(.tertiary) }
                    if task.reminderDate != nil { Image(systemName: "bell").font(.system(size: 10)).foregroundStyle(task.reminderDate! <= now ? .orange : .secondary) }
                    if let due = task.dueDate { Text(dueText(due)).font(.system(size: 12)).foregroundStyle(due < task.scheduleCalendar.startOfDay(for: now) ? .red : accent).fixedSize() }
                    else if let listName { Text(listName).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1) }
                }
        }.padding(.horizontal, 12).frame(height: 40).background(selected ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 1).padding(.leading, 41).padding(.trailing, 12) }
    }
    private func dueText(_ due: Date) -> String {
        let cal = task.scheduleCalendar
        let text = cal.isDate(due, inSameDayAs: now) ? "Today" : cal.isDate(due, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now)!) ? "Tomorrow" : task.dayText(due)
        return text + (task.hasDueTime ? " " + task.timeText(due) : "")
    }
}

struct DetailPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack { RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.08), lineWidth: 1).frame(width: 124, height: 144).rotationEffect(.degrees(-9)); Image(systemName: "checklist").font(.system(size: 62, weight: .ultraLight)).foregroundStyle(accent.opacity(0.2)) }
            Text("A little clarity, a little focus.").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            Text("Select a task or note to see its details.").font(.system(size: 12)).foregroundStyle(.tertiary)
            Spacer(); Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
