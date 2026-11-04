import SwiftUI
import AppKit
import TaskovskyCore

@main
struct TaskovskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore()
    @StateObject private var drafts = DetailDrafts()
    @StateObject private var actions = TaskActionCenter()
    init() { AppMigration.migratePreferences() }
    var body: some Scene {
        WindowGroup("Taskovsky") { WorkspaceView(store: store, drafts: drafts, actions: actions).frame(minWidth: 780, minHeight: 500).ignoresSafeArea(.container, edges: .top) }
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
                    #if DEBUG
                    Button("Toggle Minimum Window Size (Debug)") { DebugWindowSizing.toggle() }.keyboardShortcut("0", modifiers: [.command, .option])
                    Button("Set Width 1060 (Debug)") { DebugWindowSizing.setContent(width: 1060, height: 700) }.keyboardShortcut("2", modifiers: [.command, .option])
                    Button("Set Width 961 (Debug)") { DebugWindowSizing.setContent(width: 961, height: 700) }
                    Button("Set Width 780 Minimum (Debug)") { DebugWindowSizing.setContent(width: 780, height: 500) }.keyboardShortcut("1", modifiers: [.command, .option])
                    #endif
                }
            }
        Settings { SettingsView(store: store) }.defaultSize(width: 800, height: 680).windowStyle(.hiddenTitleBar)
        WindowGroup("Task Details", for: UUID.self) { $id in
            if let id { TaskDetailWindow(store: store, drafts: drafts, actions: actions, id: id) }
        }.defaultSize(width: 464, height: 630)
    }
}

#if DEBUG
@MainActor private enum DebugWindowSizing {
    static var originalFrame: NSRect?
    static func toggle() {
        guard let window = NSApp.mainWindow else { return }
        if let originalFrame { window.setFrame(originalFrame, display: true); self.originalFrame = nil }
        else { originalFrame = window.frame; window.setContentSize(NSSize(width: 780, height: 500)) }
    }
    static func setContent(width: CGFloat, height: CGFloat) {
        guard let window = NSApp.mainWindow else { return }
        if originalFrame == nil { originalFrame = window.frame }
        window.setContentSize(NSSize(width: width, height: height))
    }
}
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension Notification.Name {
    static let newTask = Notification.Name("Taskovsky.newTask")
    static let newNote = Notification.Name("Taskovsky.newNote")
    static let newList = Notification.Name("Taskovsky.newList")
    static let openSearch = Notification.Name("Taskovsky.openSearch")
    static let toggleSidebar = Notification.Name("Taskovsky.toggleSidebar")
    static let trashTask = Notification.Name("Taskovsky.trashTask")
    static let popupClosed = Notification.Name("Taskovsky.popupClosed")
    static let requestPurge = Notification.Name("Taskovsky.requestPurge")
    static let revealRestoredTask = Notification.Name("Taskovsky.revealRestoredTask")
}

/// Measured TickTick blue accent (#5171F2, sampled from solid glyph runs).
let accent = Color(hex: "#5171F2")
let palette = ["#526BF5", "#EC6574", "#E7A548", "#58A58B", "#9C7BD5", "#5BA7CC", "#8A8F98"]
extension Color {
    init(hex: String) {
        let n = UInt32(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x526BF5
        self.init(red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255)
    }
}
extension TaskPriority {
    var label: String { self == .none ? "No priority" : rawValue.capitalized + " priority" }
    var color: Color { switch self { case .high: .red; case .medium: Color(hex: "#F59E0B"); case .low: accent; case .none: .secondary } }
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
        case .inbox: "tray"; case .notes: "doc.text"; case .reminders: "bell"; case .completed: "checkmark.square"
        case .trash: "trash"; case .list: "line.3.horizontal"; case .tag: "tag"; case .wontDo: "xmark.square"; case .summary: "doc.plaintext"; case .search: "magnifyingglass"; case .filter: "line.3.horizontal.decrease"
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
        case .all: return true
        case .today: return task.dueDate.map { $0 < cal.date(byAdding: .day, value: 1, to: day)! } == true
        case .tomorrow: return task.dueDate.map { cal.isDate($0, inSameDayAs: cal.date(byAdding: .day, value: 1, to: day)!) } == true
        case .week: return task.dueDate.map { $0 < cal.date(byAdding: .day, value: 7, to: day)! } == true
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
    @ObservedObject var drafts: DetailDrafts
    @ObservedObject var actions: TaskActionCenter
    @State private var destination: Destination = .today
    @State private var quickTitle = ""
    @State private var quickKind: TaskKind = .task
    @State private var sort = "Date"
    @State private var showCompleted = true
    @State private var collapsed: Set<String> = []
    @State private var editor: EntityEditor?
    private var isPurgeAlertPresented: Binding<Bool> { Binding(get: { purgeCandidate != nil }, set: { if !$0 { purgeCandidate = nil } }) }
    @State private var recoveryAlert = false
    @State private var searchDialog = false
    @State private var searchQuery = ""
    @State private var filterEditor: TaskFilter?
    @State private var creatingFilter = false
    @State private var templatePicker = false
    @State private var purgeCandidate: UUID?
    @AppStorage("Taskovsky.collapsedSidebarSections") private var collapsedSidebarSections = ""
    @AppStorage("Taskovsky.sidebarWidth") private var sidebarWidth = 215.0
    @AppStorage("Taskovsky.sidebarCollapsed") private var sidebarCollapsed = false
    @AppStorage("Taskovsky.taskPaneFraction") private var taskPaneFraction = 0.45
    @State private var sidebarDragStart: Double?
    @State private var paneDragStart: Double?
    @State private var nextCreationKind: TaskKind?
    @State private var quickFocused = false
    @State private var detailState = DetailSelectionState()
    @State private var viewOptions = false
    @State private var openPopups = Set<UUID>()
    @State private var listContentHeight: CGFloat = 0
    @State private var listViewportHeight: CGFloat = 0
    private var listFillerHeight: CGFloat { max(0, listViewportHeight - listContentHeight) }
    @AppStorage("Taskovsky.showDetailsPreview") private var showDetailsPreview = false
    @AppStorage("Taskovsky.showChecklistItems") private var showChecklistItems = false
    @AppStorage("Taskovsky.detailLayout") private var detailLayout = "sidePeek"
    @AppStorage("Taskovsky.taskPaneCustomized") private var taskPaneCustomized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    var selectedTask: TaskItem? { store.data.tasks.first { $0.id == detailState.selection } }
    private var sidePeekMode: Bool { detailLayout != "popup" }
    var activeList: TaskList? {
        if case .list(let id) = destination { return store.data.lists.first { $0.id == id } }; return nil
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            GeometryReader { geometry in
                // Responsive policy (see ResponsiveLayout): the sidebar only hides via
                // the manual toggle; responsive pressure goes to the right detail pane.
                // Docked detail needs center 300 + divider + detail 280; otherwise the
                // center keeps its width and detail becomes a 300pt overlay drawer.
                // With the default 215pt sidebar this docks at ~860pt total, which is
                // consistent with the reference transition bracketed between 757pt
                // (overlay) and 961pt (docked). The exact TickTick threshold is unknown,
                // so this derived rule is documented as an approximation.
                let expandedNavWidth = min(ResponsiveLayout.sidebarMax, max(ResponsiveLayout.sidebarMin, sidebarWidth))
                let showSidebar = !sidebarCollapsed && destination != .search
                let navWidth = showSidebar ? expandedNavWidth : 0
                let available = geometry.size.width - ResponsiveLayout.railWidth - navWidth - (showSidebar ? ResponsiveLayout.dividerWidth : 0)
                let dockDetail = ResponsiveLayout.shouldDockDetail(totalWidth: geometry.size.width, sidebarWidth: sidebarWidth, collapsed: sidebarCollapsed || destination == .search)
                // Pristine installs default to a 300pt detail with the remaining width
                // for the center; existing stored fractions are never overwritten. The
                // preference is only written once the user drags the divider.
                let pristineDetail = UserDefaults.standard.object(forKey: "Taskovsky.taskPaneFraction") == nil && !taskPaneCustomized
                let listWidth: Double = {
                    if pristineDetail { return max(ResponsiveLayout.listMin, available - ResponsiveLayout.dividerWidth - ResponsiveLayout.drawerWidth) }
                    return ResponsiveLayout.dockedListWidth(available: available, fraction: taskPaneFraction)
                }()
                HStack(spacing: 0) {
                    rail
                    // Keep the contents at their expanded size while the panel slides
                    // behind the rail. Reflowing the sidebar at every frame makes its
                    // labels wrap and jump during the transition.
                    HStack(spacing: 0) {
                        sidebar(now: timeline.date).frame(width: expandedNavWidth)
                        PanelDivider(drag: onSidebarDrag)
                            .onTapGesture(count: 2, perform: toggleSidebar)
                    }
                    .offset(x: showSidebar ? 0 : -(expandedNavWidth + 1))
                    .frame(width: showSidebar ? expandedNavWidth + 1 : 0, alignment: .leading)
                    .clipped()
                    .allowsHitTesting(showSidebar)
                    .accessibilityHidden(!showSidebar)
                    if destination == .summary {
                        SummaryView(store: store).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if dockDetail {
                        // Full search keeps its query/filter/results here; selecting a
                        // result docks its detail beside them. Closing the detail
                        // leaves the results untouched.
                        Group {
                            if destination == .search {
                                SearchPane(store: store, initialQuery: searchQuery, onSelectTask: selectSearchTask, onSelectList: { destination = .list($0) }, onSelectFilter: { destination = .filter($0) }, onSelectTag: { destination = .tag($0) }, onComplete: complete, onClose: { destination = .inbox }).id(searchQuery)
                            } else { taskPane(now: timeline.date, overlay: false) }
                        }.frame(width: listWidth)
                        PanelDivider { delta, ended in onPaneDrag(delta: delta, ended: ended, listWidth: listWidth, available: available) }
                        detailDock.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ZStack(alignment: .trailing) {
                            Group {
                                if destination == .search {
                                    SearchPane(store: store, initialQuery: searchQuery, onSelectTask: selectSearchTask, onSelectList: { destination = .list($0) }, onSelectFilter: { destination = .filter($0) }, onSelectTag: { destination = .tag($0) }, onComplete: complete, onClose: { destination = .inbox }).id(searchQuery)
                                } else { taskPane(now: timeline.date, overlay: true) }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            // Overlay drawer: right-aligned, fixed 300pt, no scrim, soft
                            // shadow on its leading edge. It never reflows the list.
                            // Only rendered while open, so a closed drawer leaves no
                            // invisible focusable or hittable content behind.
                            if let task = selectedTask, detailState.drawerOpen { drawer(task: task) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            .animation(reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.22), value: detailState.drawerOpen)
                    }
                }
                .animation(reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.22), value: sidebarCollapsed)
                // Shrinking into overlay dismisses the drawer but keeps the selection,
                // so growing back docks the same task. Never auto-opens on shrink.
                // An open schedule popover is cancelled rather than reopened blank:
                // only the visibility flag is retained, unsaved schedule edits are not.
                .onChange(of: dockDetail) { _, docked in
                    if !docked { detailState.shrinkToOverlay() }
                    if let sel = detailState.selection { drafts.scheduling[sel] = false }
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
                }
            }
            .overlay(alignment: .bottom) {
                FeedbackToast(actions: actions, store: store) { listID, _ in
                    destination = listID.map(Destination.list) ?? .inbox
                    detailState.navigate()
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: actions.feedback?.id)
        }
        .alert("Recover workspace?", isPresented: $recoveryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Back up and recover") { store.recoverUnreadableWorkspace() }
        } message: { Text("The unreadable file will be copied to a backup beside workspace.json. Your current in-memory items will then be saved as the new workspace.") }
        .sheet(item: $editor) { item in
            EntitySheet(editor: item) { name, color, kind, symbol in
                if item.isTag {
                    if let id = item.entityID { store.updateTag(TaskTag(id: id, name: name, color: color)) }
                    else { _ = store.createTag(name: name, color: color) }
                } else {
                    if let id = item.entityID { store.updateList(TaskList(id: id, name: name, color: color, kind: kind, symbol: symbol)) }
                    else { destination = .list(store.createList(name: name, color: color, kind: kind, symbol: symbol)) }
                }
            }
        }
        .sheet(isPresented: $searchDialog) {
            SearchDialog(store: store, onSearch: { searchQuery = $0; destination = .search; detailState.clear(); searchDialog = false }, onSelectTask: { selectSearchTask($0); searchDialog = false }, onSelectList: { destination = .list($0); detailState.navigate(); searchDialog = false }, onSelectFilter: { destination = .filter($0); detailState.navigate(); searchDialog = false }, onSelectTag: { destination = .tag($0); detailState.navigate(); searchDialog = false }, onComplete: complete)
        }
        .sheet(item: $filterEditor) { FilterEditorView(store: store, filter: $0) }
        .sheet(isPresented: $creatingFilter) { FilterEditorView(store: store) }
        .sheet(isPresented: $viewOptions) { ViewOptionsView(layout: $detailLayout) }
        .sheet(isPresented: $templatePicker) {
            TemplatePicker(store: store) { template in
                if let id = store.createTaskFromTemplate(id: template.id, listID: activeList?.id, dueDate: contextualDate, useDefaultList: destination != .inbox && activeList == nil) { selectTask(id) }
                templatePicker = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in quickKind = .task; if destination == .trash || destination == .completed || destination == .wontDo || destination == .search || destination == .summary { nextCreationKind = .task; destination = .inbox }; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in if destination != .inbox && activeList == nil { nextCreationKind = .note; destination = .inbox }; quickKind = .note; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newList)) { _ in editor = EntityEditor(isTag: false) }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in searchDialog = true }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in toggleSidebar() }
        .onReceive(NotificationCenter.default.publisher(for: .trashTask)) { note in if let id = note.object as? UUID { trash(id) } }
        .onReceive(NotificationCenter.default.publisher(for: .popupClosed)) { note in if let id = note.object as? UUID { openPopups.remove(id) } }
        .onReceive(NotificationCenter.default.publisher(for: .requestPurge)) { note in if let id = note.object as? UUID { purgeCandidate = id } }
        .onReceive(NotificationCenter.default.publisher(for: .revealRestoredTask)) { note in
            if let id = note.object as? UUID, let task = store.data.tasks.first(where: { $0.id == id }) {
                destination = task.listID.map(Destination.list) ?? .inbox
                detailState.navigate()
            }
        }
        .onChange(of: destination) { _, _ in
            if let task = selectedTask, !destination.includes(task) { detailState.clear() }
            quickKind = nextCreationKind ?? (activeList?.kind == .note ? .note : .task); nextCreationKind = nil
        }
        .alert("Delete Forever?", isPresented: isPurgeAlertPresented, presenting: purgeCandidate) { id in
            Button("Delete Forever", role: .destructive) { _ = store.purgeTask(id: id); purgeCandidate = nil }
            Button("Cancel", role: .cancel) { purgeCandidate = nil }
        } message: { id in
            Text("This permanently deletes \"\(store.data.tasks.first { $0.id == id }?.title ?? "this item")\" and cannot be undone.")
        }
    }

    private func toggleSidebar() { sidebarCollapsed.toggle() }
    private func onSidebarDrag(delta: Double, ended: Bool) {
        if sidebarDragStart == nil { sidebarDragStart = sidebarWidth }
        let start = sidebarDragStart ?? sidebarWidth
        let proposed = start + delta
        sidebarWidth = min(ResponsiveLayout.sidebarMax, max(ResponsiveLayout.sidebarMin, proposed))
        if ended {
            if proposed < 135 { sidebarWidth = start; sidebarCollapsed = true }
            sidebarDragStart = nil
        }
    }
    private func onPaneDrag(delta: Double, ended: Bool, listWidth: Double, available: Double) {
        if paneDragStart == nil { paneDragStart = listWidth }
        let start = paneDragStart ?? listWidth
        let limit = max(ResponsiveLayout.listMin, available - ResponsiveLayout.dividerWidth - ResponsiveLayout.detailMin)
        taskPaneFraction = min(limit, max(ResponsiveLayout.listMin, start + delta)) / available
        taskPaneCustomized = true
        if ended { paneDragStart = nil }
    }
    private var detailDock: some View {
        Group {
            if let task = selectedTask {
                TaskDetail(store: store, drafts: drafts, id: task.id, onTrash: { trash(task.id) }, onComplete: { complete(task.id) }, onWontDo: { abandon(task.id) }, onClose: nil, onRestore: { restoreExplicit(task.id) }, onPurge: { purgeCandidate = task.id }).id(task.id)
            } else { DetailPlaceholder() }
        }
    }
    private func drawer(task: TaskItem) -> some View {
        TaskDetail(store: store, drafts: drafts, id: task.id, onTrash: { trash(task.id); closeDrawer() }, onComplete: { complete(task.id) }, onWontDo: { abandon(task.id) }, onClose: closeDrawer, compact: true, onRestore: { restoreExplicit(task.id) }, onPurge: { purgeCandidate = task.id }).id(task.id)
            .frame(width: ResponsiveLayout.drawerWidth).frame(maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
            .shadow(color: .black.opacity(0.18), radius: 12, x: -4, y: 0)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .zIndex(20)
    }

    private func selectTask(_ id: UUID) {
        // Side peek opens the overlay drawer; pop-up mode only selects (a double
        // click opens a separate window) and docked mode shows the detail anyway.
        withAnimation(reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.22)) { detailState.select(id, overlay: sidePeekMode) }
    }
    private func closeDrawer() {
        withAnimation(reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.22)) { detailState.close() }
    }
    private func openPopup(_ id: UUID) {
        detailState.select(id, overlay: false)
        openPopups.insert(id)
        openWindow(value: id)
    }

    private var railBackground: Color {
        colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(red: 0.961, green: 0.961, blue: 0.961)
    }
    private var rail: some View {
        VStack(spacing: 26) {
            Spacer().frame(height: 12)
            RailButton(title: "Tasks", active: destination != .search, symbol: "checkmark", selectedTile: true) { destination = .today; closeDrawer() }
            RailButton(title: "Search", active: destination == .search, symbol: "magnifyingglass", selectedTile: false) { searchDialog = true }
            Spacer()
            SettingsLink { HoverIcon { Image(systemName: "gearshape").font(.system(size: 22)).foregroundStyle(.secondary).padding(8) } }.buttonStyle(.plain).help("Settings · ⌘,").accessibilityLabel("Settings")
            Spacer().frame(height: 18)
        }.frame(width: ResponsiveLayout.railWidth).background(railBackground)
    }
    private func sidebar(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach([Destination.all, .today, .tomorrow, .week, .inbox, .summary].filter { visible($0, now: now) }, id: \.self) { dest in navRow(dest, now: now) }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    sectionHeading("Lists") { editor = EntityEditor(isTag: false) }
                    if sectionExpanded("Lists").wrappedValue {
                    ForEach(store.data.lists) { list in
                        navRow(.list(list.id), color: Color(hex: list.color), now: now)
                            .contextMenu {
                                Button("Edit List…") { editor = EntityEditor(list: list) }
                                Button("Delete List", role: .destructive) { store.deleteList(id: list.id); if destination == .list(list.id) { destination = .inbox } }
                                Text("Tasks are moved to Inbox")
                            }
                    }
                    }
                    if sectionVisible(.filters, count: store.data.filters.count) {
                        sectionHeading("Filters") { creatingFilter = true }.padding(.top, 20)
                        if sectionExpanded("Filters").wrappedValue {
                        ForEach(store.data.filters) { filter in
                            navRow(.filter(filter.id), now: now).contextMenu { Button("Edit Filter…") { filterEditor = filter }; Button("Delete Filter", role: .destructive) { store.deleteFilter(id: filter.id); if destination == .filter(filter.id) { destination = .inbox } } }
                        }
                        if store.data.filters.isEmpty { Text("Display tasks filtered by list, date, priority, tag, and more").font(.system(size: 12)).foregroundStyle(.secondary).padding(10).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8)) }
                    }
                    }
                    if sectionVisible(.tags, count: store.data.tags.count) {
                    sectionHeading("Tags") { editor = EntityEditor(isTag: true) }.padding(.top, 20)
                    if sectionExpanded("Tags").wrappedValue {
                    ForEach(store.data.tags) { tag in
                        navRow(.tag(tag.id), color: Color(hex: tag.color), now: now)
                            .contextMenu {
                                Button("Edit Tag…") { editor = EntityEditor(tag: tag) }
                                Button("Delete Tag", role: .destructive) { store.deleteTag(id: tag.id); if destination == .tag(tag.id) { destination = .all } }
                            }
                    }
                    }
                    }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    ForEach([Destination.completed, .wontDo, .trash].filter { visible($0, now: now) }, id: \.self) { navRow($0, now: now) }
                }.padding(.horizontal, 8).padding(.top, 12)
            }
        }.background(Color(nsColor: .textBackgroundColor))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: collapsedSidebarSections)
    }
    private func sectionHeading(_ text: String, action: @escaping () -> Void) -> some View {
        SidebarHeading(title: text, expanded: sectionExpanded(text), onAdd: action)
    }
    private func sectionExpanded(_ title: String) -> Binding<Bool> {
        Binding(get: { !collapsedSidebarSections.split(separator: "|").contains(Substring(title)) }, set: { expanded in
            var values = Set(collapsedSidebarSections.split(separator: "|").map(String.init))
            if expanded { values.remove(title) } else { values.insert(title) }
            collapsedSidebarSections = values.sorted().joined(separator: "|")
        })
    }

    private func navRow(_ dest: Destination, color: Color? = nil, now: Date) -> some View {
        let count = store.data.tasks.filter { task in
            if case .filter(let id) = dest { return store.data.filters.first { $0.id == id }?.matches(task, now: now, calendar: store.settings.calendar) ?? false }
            return dest.includes(task, now: now)
        }.count
        return SidebarRow(selected: destination == dest, action: { destination = dest; closeDrawer() }) {
            HStack(spacing: 10) {
                Group {
                    if case .list(let id) = dest { ListSymbol(symbol: store.data.lists.first { $0.id == id }?.symbol) }
                    else if dest == .today { CalendarSymbol(text: String(Calendar.current.component(.day, from: now))) }
                    else if dest == .week { CalendarSymbol(text: String(Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: now) - 1].prefix(2))) }
                    else { Image(systemName: dest.symbol).font(.system(size: 16)).frame(width: 20) }
                }.foregroundStyle(.primary).frame(width: 20)
                Text(dest.title(store.data)).font(.system(size: 14)).lineLimit(1)
                if let color { Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true) }
                Spacer(minLength: 2)
                if count > 0 && dest != .summary { Text("\(count)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit() }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            if dest == .inbox { return move(items, to: nil) }
            if case .list(let id) = dest { return move(items, to: id) }
            return false
        }
    }
    private func move(_ items: [String], to listID: UUID?) -> Bool {
        for item in items {
            guard let id = UUID(uuidString: item), var task = store.data.tasks.first(where: { $0.id == id }), task.deletedAt == nil else { return false }
            task.listID = listID; store.updateTask(task)
        }
        return true
    }
    private func listContext(for task: TaskItem) -> String? {
        if destination == .inbox { return nil }
        if case .list(let id) = destination, task.listID == id { return nil }
        if let listID = task.listID { return store.data.lists.first { $0.id == listID }?.name }
        return "Inbox"
    }
    private func taskPane(now: Date, overlay: Bool) -> some View {
        let tasks = filteredTasks(now: now)
        let groups = grouped(tasks, now: now)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Button(action: toggleSidebar) {
                    HoverIcon {
                        HStack(spacing: 1) {
                            Image(systemName: "line.3.horizontal").font(.system(size: 12))
                            Image(systemName: "chevron.left").font(.system(size: 8, weight: .bold))
                        }.foregroundStyle(.secondary).padding(3)
                    }
                }.buttonStyle(.plain).help("Toggle sidebar").accessibilityLabel("Toggle sidebar")
                Text(destination.title(store.data)).font(.system(size: 20, weight: .bold)).lineLimit(1)
                Spacer(minLength: 8)
                    .contentShape(Rectangle())
                    .onTapGesture { closeDrawer() }
                Menu {
                    Picker("Sort by", selection: $sort) { ForEach(["Date", "Priority", "Title", "Created"], id: \.self) { Text($0) } }
                    if destination != .completed && destination != .trash && destination != .wontDo { Toggle("Show Completed & Won't Do", isOn: $showCompleted) }
                } label: { HoverIcon { Image(systemName: "arrow.up.arrow.down").font(.system(size: 15)).foregroundStyle(.secondary).padding(6) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().help("Sort and display")
                Menu {
                    if destination != .completed && destination != .trash && destination != .wontDo && destination != .summary {
                        Button(showCompleted ? "Hide Completed" : "Show Completed") { showCompleted.toggle() }
                        Divider()
                    }
                    Button(showDetailsPreview ? "Hide Details" : "Show Details") { showDetailsPreview.toggle() }
                    Button(showChecklistItems ? "Hide Checklist Items" : "Show Checklist Items") { toggleChecklistItems(now: now) }
                    Divider()
                    Button("View Options…") { viewOptions = true }
                } label: { HoverIcon { Image(systemName: "ellipsis").font(.system(size: 15)).foregroundStyle(.secondary).padding(6) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().help("More actions")
            }.padding(.horizontal, 20).frame(height: 58)
            if destination == .summary { Text("Updated in the last 7 days").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 12) }
            if destination != .trash && destination != .completed && destination != .wontDo && destination != .summary {
                QuickEntry(store: store, title: $quickTitle, kind: $quickKind, focused: $quickFocused, onTemplate: { templatePicker = true }) { body, recognizeDates in
                    addTask(body: body, recognizeDates: recognizeDates)
                }.padding(.horizontal, 20).padding(.bottom, 16)
            }
            if destination == .reminders { Text("Check due and upcoming reminders here. New items are set for one hour from now.").font(.caption).foregroundStyle(Palette.explanatory(colorScheme)).padding(.horizontal, 24).padding(.bottom, 16) }
            if destination == .trash { Text("Deleted items stay here until you restore them.").font(.caption).foregroundStyle(Palette.explanatory(colorScheme)).padding(.horizontal, 24).padding(.bottom, 16) }
            if tasks.isEmpty {
                VStack(spacing: 12) { Spacer(); Image(systemName: destination == .trash ? "trash" : "checkmark.circle").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(accent.opacity(0.5)); Text(destination == .trash ? "Trash is empty" : "All clear").font(.system(size: 17, weight: .medium)); Text(destination == .today ? "Enjoy the space. Add something for today." : "Your \(destination == .notes ? "notes" : "tasks") will appear here.").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { closeDrawer() }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups, id: \.0) { title, items in
                            Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { if collapsed.contains(title) { collapsed.remove(title) } else { collapsed.insert(title) } } } label: {
                                HStack(spacing: 7) { Image(systemName: collapsed.contains(title) ? "chevron.right" : "chevron.down").font(.system(size: 9, weight: .semibold)); Text(title).font(.system(size: 12, weight: .semibold)); Text("\(items.count)").font(.system(size: 11)).foregroundStyle(.tertiary); Spacer() }.foregroundStyle(title == "Overdue" || title == "Due reminders" ? .red : .secondary).padding(.vertical, 10)
                            }.buttonStyle(.plain)
                            if !collapsed.contains(title) { ForEach(items) { task in
                                TaskRow(store: store, id: task.id, selected: detailState.selection == task.id, now: now, listContext: listContext(for: task), showPreview: showDetailsPreview, showSteps: showChecklistItems, allowRename: sidePeekMode || !overlay, toggle: { complete(task.id) }, onSelect: { selectTask(task.id) }, onTitleDoubleClick: { if !sidePeekMode && overlay { openPopup(task.id) } }, onRowDoubleClick: { if !sidePeekMode && overlay { openPopup(task.id) } })
                                    .modifier(RowDrag(id: task.id, active: task.deletedAt == nil))
                                    .contextMenu { taskMenu(task) }
                            } }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tasks.map { $0.id })
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: ListContentHeightKey.self, value: geometry.size.height)
                        })
                    // Filler claims every remaining blank point of the viewport so a
                    // blank tap dismisses the drawer at any window height. It sits
                    // below the rows, so row/button/editor taps never reach it.
                    Color.clear
                        .frame(height: listFillerHeight)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { closeDrawer() }
                }
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ListViewportHeightKey.self, value: geometry.size.height)
                })
                .onPreferenceChange(ListContentHeightKey.self) { listContentHeight = $0 }
                .onPreferenceChange(ListViewportHeightKey.self) { listViewportHeight = $0 }
            }
        }
    }
    @ViewBuilder private func taskMenu(_ task: TaskItem) -> some View {
        if task.deletedAt != nil {
            Button("Restore") { restoreExplicit(task.id) }
            Button("Delete Forever", role: .destructive) { purgeCandidate = task.id }
        }
        else {
            if task.kind == .task { Button(task.completedAt == nil && task.wontDoAt == nil ? "Complete" : "Mark incomplete") { complete(task.id) }; if task.wontDoAt == nil { Button("Won't Do") { abandon(task.id) } } }
            Menu("Priority") { ForEach(TaskPriority.allCases, id: \.self) { value in Button(value.label) { var t = task; t.priority = value; store.updateTask(t) } } }
            Menu("Move to") { Button("Inbox") { var t = task; t.listID = nil; store.updateTask(t) }; ForEach(store.data.lists) { list in Button(list.name) { var t = task; t.listID = list.id; store.updateTask(t) } } }
            Button("Duplicate") { if let id = store.duplicateTask(id: task.id) { selectTask(id) } }
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
                title = destination == .completed ? "Completed" : destination == .wontDo ? "Won't Do" : tasks.contains(where: { $0.wontDoAt != nil }) ? "Completed & Won't Do" : "Completed"
            }
            else if destination == .reminders { title = task.reminderDate! <= now ? "Due reminders" : "Upcoming reminders" }
            else if task.kind == .note && sort == "Date" { title = "Note" }
            else if sort == "Priority" { title = task.priority.label }
            else if let due = task.dueDate {
                if due < task.scheduleCalendar.startOfDay(for: now) { title = "Overdue" }
                else if task.scheduleCalendar.isDate(due, inSameDayAs: now) { title = "Today" }
                else if task.scheduleCalendar.isDate(due, inSameDayAs: task.scheduleCalendar.date(byAdding: .day, value: 1, to: now)!) { title = "Tomorrow" }
                else { title = due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
            } else { title = "No Date" }
            if values[title] == nil { keys.append(title) }; values[title, default: []].append(task)
        }
        if let i = keys.firstIndex(of: "Note") { keys.remove(at: i); keys.insert("Note", at: keys.firstIndex(of: "Completed & Won't Do") ?? keys.firstIndex(of: "Completed") ?? keys.endIndex) }
        if store.settings.overduePosition == .bottom, let i = keys.firstIndex(of: "Overdue") { keys.remove(at: i); keys.insert("Overdue", at: keys.firstIndex(of: "Note") ?? keys.firstIndex(of: "Completed & Won't Do") ?? keys.firstIndex(of: "Completed") ?? keys.endIndex) }
        return keys.map { ($0, values[$0]!) }
    }
    private func addTask(body: String = "", recognizeDates: Bool = true) {
        let title = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        let due = contextualDate
        let id = store.createTask(title: title, listID: activeList?.id, kind: quickKind, dueDate: quickKind == .task ? due : nil, useDefaultList: destination != .inbox && activeList == nil, preferRecognizedDate: true, recognizeDates: recognizeDates, body: body)
        if case .tag(let tagID) = destination, var task = store.data.tasks.first(where: { $0.id == id }), !task.tagIDs.contains(tagID) { task.tagIDs.append(tagID); store.updateTask(task) }
        if destination == .reminders, var task = store.data.tasks.first(where: { $0.id == id }) { task.reminderDates = due.map { [$0] } ?? []; task.hasDueTime = quickKind == .task; store.updateTask(task) }
        if quickKind == .note && (destination == .today || destination == .tomorrow || destination == .week || destination == .all) { destination = .inbox }
        if let created = store.data.tasks.first(where: { $0.id == id }), !destination.includes(created), destination != .search {
            if case .filter = destination { } else if case .tag = destination { } else { destination = created.listID.map(Destination.list) ?? .inbox }
        }
        selectTask(id); quickTitle = ""; quickFocused = true
    }
    private func trash(_ id: UUID) { actions.trash(store: store, id: id); if detailState.selection == id { detailState.clear() } }
    private func restoreExplicit(_ id: UUID) {
        actions.restore(store: store, id: id)
        if let task = store.data.tasks.first(where: { $0.id == id }), !destination.includes(task) { detailState.clear() }
    }
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
        selectTask(id)
    }
    private func toggleChecklistItems(now: Date) {
        if !showChecklistItems {
            showChecklistItems = true
            if !filteredTasks(now: now).contains(where: { !$0.checklist.isEmpty }) {
                actions.notice("No matching checklist item.")
            }
        } else {
            showChecklistItems = false
        }
    }
    private func complete(_ id: UUID) { actions.complete(store: store, id: id) }
    private func abandon(_ id: UUID) { actions.abandon(store: store, id: id) }
}


/// Measured list heights so a filler can claim exactly the blank viewport area.
struct ListContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
struct ListViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Drag support only for non-deleted rows; deleted items can never be dragged
/// into another list (the sidebar drop target also refuses them).
struct RowDrag: ViewModifier {
    let id: UUID
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.draggable(id.uuidString) } else { content }
    }
}

/// Shared neutral hover treatment for icon buttons and menus.
struct HoverIcon<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var hovering = false
    var body: some View {
        content()
            .background(hovering ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .onHover { hovering = $0 }
    }
}

/// Rail navigation button with hover feedback. The Tasks entry uses a 20pt blue
/// rounded tile with a white tick when active; inactive entries stay neutral
/// gray and only highlight on hover.
struct RailButton: View {
    let title: String
    let active: Bool
    let symbol: String
    let selectedTile: Bool
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: selectedTile ? 4.5 : 8)
                    .fill(selectedTile && active ? accent : active ? accent.opacity(0.12) : hovering ? Color.primary.opacity(0.07) : .clear)
                    .frame(width: selectedTile ? 20 : 34, height: selectedTile ? 20 : 34)
                Image(systemName: symbol)
                    .font(.system(size: selectedTile ? 14 : 22, weight: selectedTile ? .bold : .regular))
                    .foregroundStyle(selectedTile && active ? .white : active ? accent : .secondary)
            }.frame(width: 38, height: 38)
        }.buttonStyle(.plain).onHover { hovering = $0 }.help(title).accessibilityLabel(title)
    }
}

/// Sidebar row with a neutral selected background, a lighter hover highlight
/// for unselected rows, and a full-row hit area.
struct SidebarRow<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 10).frame(height: 38).contentShape(Rectangle())
                .background((selected ? Color.primary.opacity(0.055) : hovering ? Color.primary.opacity(0.032) : .clear), in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).onHover { hovering = $0 }
    }
}

/// Task Detail Layout choice from More > View Options. Independently drawn
/// preview silhouettes: side peek docks the detail at the list's right edge,
/// pop-up floats it as a separate window.
struct ViewOptionsView: View {
    @Binding var layout: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("View Options").font(.system(size: 17, weight: .semibold))
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Detail Layout").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.bodyText(colorScheme))
                HStack(alignment: .top, spacing: 24) {
                    layoutOption(value: "sidePeek", title: "Side peek") {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).stroke(Palette.values(colorScheme).opacity(0.6), lineWidth: 1)
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2).fill(Palette.values(colorScheme).opacity(0.35)).frame(width: 10, height: 70)
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(Palette.values(colorScheme).opacity(0.3)).frame(width: 56, height: 7) }
                                }
                                RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.25)).frame(width: 34, height: 86)
                            }.padding(12)
                        }.frame(width: 140, height: 114)
                    }
                    layoutOption(value: "popup", title: "Pop-up") {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).stroke(Palette.values(colorScheme).opacity(0.6), lineWidth: 1)
                                .frame(width: 140, height: 114)
                            HStack(spacing: 5) {
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(Palette.values(colorScheme).opacity(0.3)).frame(width: 44, height: 7) }
                                }
                            }.offset(x: -28, y: -12)
                            RoundedRectangle(cornerRadius: 5).fill(Palette.card(colorScheme))
                                .frame(width: 64, height: 78)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 2)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.values(colorScheme).opacity(0.5), lineWidth: 1))
                                .offset(x: 26, y: 8)
                        }.frame(width: 140, height: 114)
                    }
                }
                Text("If the window is too narrow, the task details will appear according to your choice.")
                    .font(.system(size: 12)).foregroundStyle(Palette.explanatory(colorScheme)).fixedSize(horizontal: false, vertical: true)
            }.padding(16).background(Palette.card(colorScheme), in: RoundedRectangle(cornerRadius: 8))
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 472)
    }
    private func layoutOption<Preview: View>(value: String, title: String, @ViewBuilder preview: () -> Preview) -> some View {
        Button { layout = value } label: {
            VStack(spacing: 8) {
                preview()
                HStack(spacing: 6) {
                    Image(systemName: layout == value ? "largecircle.fill" : "circle")
                        .font(.system(size: 14)).foregroundStyle(layout == value ? accent : Palette.values(colorScheme))
                    Text(title).font(.system(size: 13)).foregroundStyle(Palette.bodyText(colorScheme))
                }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}

/// Standalone detail window for Pop-up layout at compact widths. Reuses the
/// same TaskDetail (and drafts) so editing behavior stays consistent. Actions
/// route through the workspace so completion sound, Undo feedback, and trash
/// behave exactly like the docked detail. Closing it never touches the main
/// window or the stored selection.
struct TaskDetailWindow: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var drafts: DetailDrafts
    @ObservedObject var actions: TaskActionCenter
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if store.data.tasks.contains(where: { $0.id == id }) {
                TaskDetail(store: store, drafts: drafts, id: id, onTrash: { NotificationCenter.default.post(name: .trashTask, object: id); dismiss() }, onComplete: { actions.complete(store: store, id: id) }, onWontDo: { actions.abandon(store: store, id: id) }, onClose: nil, compact: true, standalonePopup: true, onRestore: { actions.restore(store: store, id: id) }, onPurge: { NotificationCenter.default.post(name: .requestPurge, object: id) }).id(id)
            } else {
                Text("This item is no longer available.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .background(WindowChrome().frame(width: 0, height: 0))
        .overlay(alignment: .bottom) {
            FeedbackToast(actions: actions, store: store) { _, taskID in
                NotificationCenter.default.post(name: .revealRestoredTask, object: taskID)
                dismiss()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: actions.feedback?.id)
        .onDisappear { NotificationCenter.default.post(name: .popupClosed, object: id) }
    }
}

struct DetailPlaceholder: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: min(260, geometry.size.width * 0.6), weight: .ultraLight))
                    .rotationEffect(.degrees(-16)).foregroundStyle(Color.primary.opacity(0.035))
                    .offset(x: 20, y: 15).padding(24)
            }.clipped().accessibilityLabel("Select a task or note to see its details")
        }
    }
}
