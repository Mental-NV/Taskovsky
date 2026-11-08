import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TaskovskyCore

/// Preference suite routing: normal launches share the user's defaults; an
/// isolated `--workspace` QA launch uses a throwaway suite so visual QA
/// never reads or writes real preferences (they persist separately per
/// machine, keeping repeat QA runs stable without touching real state).
enum IsolatedDefaults {
    static var store: UserDefaults {
        guard LaunchIsolation.isIsolated else { return .standard }
        return UserDefaults(suiteName: "Taskovsky.isolated-qa") ?? .standard
    }
}

/// Isolated visual-QA launch: `--workspace <absolute-path>` (plus adjacent
/// `--settings <absolute-path>`) points storage at an explicit file such as a
/// seeded /tmp fixture. Preference migration is skipped in that mode so the
/// real workspace is never touched; normal launch behavior is unchanged.
/// Policy lives in `IsolatedLaunch` (unit-tested): flag presence alone
/// isolates — even a bare `--workspace` with no value — and only absolute
/// file paths (never directories, never another flag) count as explicit
/// values. A missing/invalid value falls back to a fresh temp workspace,
/// never to the real one, with a stderr warning.
enum LaunchIsolation {
    private static var resolution: IsolatedLaunchResolution {
        IsolatedLaunch.resolve(arguments: CommandLine.arguments)
    }
    static var workspaceOverride: URL? { resolution.workspace }
    static var settingsOverride: URL? { resolution.settings }
    static var isIsolated: Bool { resolution.isIsolated }
    /// Temp fallback for a missing/invalid `--workspace` value: a fresh
    /// per-process workspace that keeps QA off the user's real data.
    static var fallbackWorkspace: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Taskovsky-isolated-\(ProcessInfo.processInfo.processIdentifier)")
            .appendingPathComponent("workspace.json")
    }
    static func warnIfNeeded() {
        if resolution.isIsolated && resolution.workspaceValueInvalid {
            fputs("Taskovsky: --workspace needs an absolute file path; using a fresh temp workspace instead.\n", stderr)
        }
    }
}

@main
struct TaskovskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: TaskStore
    @StateObject private var drafts = DetailDrafts()
    @StateObject private var actions = TaskActionCenter()
    init() {
        if LaunchIsolation.isIsolated {
            // Explicit file, no migration side effects on real storage. A
            // missing/invalid flag value still isolates (fresh temp
            // workspace, never the real one).
            LaunchIsolation.warnIfNeeded()
            let workspace = LaunchIsolation.workspaceOverride ?? LaunchIsolation.fallbackWorkspace
            if !FileManager.default.fileExists(atPath: workspace.path) {
                try? FileManager.default.createDirectory(at: workspace.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? Data("{\"tasks\":[],\"lists\":[],\"tags\":[],\"filters\":[]}".utf8).write(to: workspace)
            }
            _store = StateObject(wrappedValue: TaskStore(fileURL: workspace, settingsURL: LaunchIsolation.settingsOverride, seed: false))
        } else {
            AppMigration.migratePreferences()
            _store = StateObject(wrappedValue: TaskStore())
        }
    }
    var body: some Scene {
        // Content floor for the measured compact reference (rail 62 + center
        // 320): 382 wide with 552 height = 580 total reference minus the
        // ~28pt hidden-titlebar chrome. A 580 content value here landed a 608
        // frame. The exact 580 total-window floor is enforced from measured
        // chrome by WindowFloorBridge in the workspace root.
        WindowGroup("Taskovsky") { WorkspaceView(store: store, drafts: drafts, actions: actions).frame(minWidth: CGFloat(ResponsiveLayout.minWindowWidth), minHeight: 552).ignoresSafeArea(.container, edges: .top) }
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
    static let newFolder = Notification.Name("Taskovsky.newFolder")
    static let openSearch = Notification.Name("Taskovsky.openSearch")
    static let openSmartLists = Notification.Name("Taskovsky.openSmartLists")
    static let toggleSidebar = Notification.Name("Taskovsky.toggleSidebar")
    static let trashTask = Notification.Name("Taskovsky.trashTask")
    static let popupClosed = Notification.Name("Taskovsky.popupClosed")
    static let requestPurge = Notification.Name("Taskovsky.requestPurge")
    static let revealRestoredTask = Notification.Name("Taskovsky.revealRestoredTask")
}

/// UserDefaults key for a consumed-once pending Settings section. The
/// notification alone can miss a fresh Settings launch (the view does not
/// exist yet when it is posted), so the section is also parked here and
/// consumed by SettingsView.onAppear. Already-open windows retarget live via
/// the notification; fresh windows consume the parked value on appear.
let pendingSettingsSectionKey = "Taskovsky.pendingSettingsSection"

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
    func includes(_ task: TaskItem, data: WorkspaceData, now: Date = Date()) -> Bool {
        if self == .trash { return task.deletedAt != nil }
        guard task.deletedAt == nil else { return false }
        if self == .wontDo { return task.wontDoAt != nil }
        if self == .summary {
            // Summary is a history view, but archived or opted-out lists stay
            // hidden there like in every other smart destination.
            guard !SmartListEligibility.isExcludedFromSmart(task, lists: data.lists) else { return false }
            return task.updatedAt >= Calendar.current.date(byAdding: .day, value: -7, to: now)!
        }
        if self == .completed { return task.completedAt != nil }
        guard task.completedAt == nil && task.wontDoAt == nil else { return false }
        let cal = task.scheduleCalendar
        let day = cal.startOfDay(for: now)
        switch self {
        case .all, .today, .tomorrow, .week, .notes:
            guard !SmartListEligibility.isExcludedFromSmart(task, lists: data.lists) else { return false }
        case .reminders:
            guard !SmartListEligibility.isArchived(task, lists: data.lists) else { return false }
        case .inbox, .list, .tag, .completed, .trash, .wontDo, .summary, .search, .filter:
            break
        }
        switch self {
        case .all: return true
        case .today: return task.dueDate.map { $0 < cal.date(byAdding: .day, value: 1, to: day)! } == true
        case .tomorrow: return task.dueDate.map { cal.isDate($0, inSameDayAs: cal.date(byAdding: .day, value: 1, to: day)!) } == true
        case .week: return task.dueDate.map { $0 < cal.date(byAdding: .day, value: 7, to: day)! } == true
        case .inbox: return task.listID == nil
        case .notes: return task.kind == .note
        case .reminders: return task.reminderDate != nil
        case .list(let id): return task.listID == id
        case .tag(let id):
            return SmartListEligibility.taskMatchesTag(task, tagID: id, tags: data.tags)
        case .completed, .trash, .wontDo, .summary, .search, .filter: return false
        }
    }
    var smartKey: SmartListKey? {
        switch self { case .all: .all; case .today: .today; case .tomorrow: .tomorrow; case .week: .week; case .inbox: .inbox; case .summary: .summary; case .completed: .completed; case .wontDo: .wontDo; case .trash: .trash; default: nil }
    }
    init(smartKey: SmartListKey, lists: [TaskList]) {
        switch smartKey {
        case .all: self = .all
        case .today: self = .today
        case .tomorrow: self = .tomorrow
        case .week: self = .week
        case .inbox: self = .inbox
        case .summary: self = .summary
        case .completed: self = .completed
        case .wontDo: self = .wontDo
        case .trash: self = .trash
        case .tags, .filters: self = .all
        }
        _ = lists
    }
}

struct FolderSheetDraft: Identifiable {
    let id = UUID()
    var folderID: UUID?
    var initialName: String
}

/// Pending tag merge: the source tag is selected by the caller, the target in
/// the sheet below. Merging rewrites task/template/filter refs and reparents
/// the source's children, then deletes the source.
struct TagMergeDraft: Identifiable {
    let id = UUID()
    var sourceID: UUID
}

struct WorkspaceView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var drafts: DetailDrafts
    @ObservedObject var actions: TaskActionCenter
    // Shared in-app sidebar drag session for smart lists, lists, folders, and
    // tags (see SidebarDragCoordinator). One instance covers the docked
    // sidebar and the compact popover, which share the same sidebar view.
    @StateObject private var sidebarDrag = SidebarDragCoordinator()
    @State private var destination: Destination = .today
    @State private var quickTitle = ""
    @State private var quickKind: TaskKind = .task
    // Persisted: a Manual order would otherwise appear lost whenever the app
    // relaunched onto the default Date sort. Legacy "Manual" reads as "None";
    // both mean stored-array order and enable drag reordering.
    @AppStorage("Taskovsky.taskSort", store: IsolatedDefaults.store) private var sort = "Date"
    private var isManualSort: Bool { TaskSortPolicy.isManual(sort) }
    @State private var showCompleted = true
    @State private var collapsed: Set<String> = []
    @State private var editor: EntityEditor?
    @State private var folderDraft: FolderSheetDraft?
    @AppStorage("Taskovsky.collapsedFolders", store: IsolatedDefaults.store) private var collapsedFolders = ""
    private var collapsedFolderIDs: Set<UUID> {
        get { Set(collapsedFolders.split(separator: "|").compactMap { UUID(uuidString: String($0)) }) }
        nonmutating set { collapsedFolders = newValue.map(\.uuidString).sorted().joined(separator: "|") }
    }
    private var isPurgeAlertPresented: Binding<Bool> { Binding(get: { purgeCandidate != nil }, set: { if !$0 { purgeCandidate = nil } }) }
    @State private var recoveryAlert = false
    /// Per-list center view, stored on the list record itself (List default)
    /// so each list remembers its own mode across rename, edit, duplicate,
    /// and reload. The segmented control below reads and writes the current
    /// list; every other destination always renders rows. The board is a
    /// status-column Kanban (Open / Completed / Won't Do) over the same
    /// filtered tasks — no custom sections or column editing.
    private var listViewBinding: Binding<Bool> {
        Binding(get: {
            if case .list(let id) = destination, let list = store.data.lists.first(where: { $0.id == id }) { return list.viewMode == .board }
            return false
        }, set: { board in
            if case .list(let id) = destination, var list = store.data.lists.first(where: { $0.id == id }) {
                list.viewMode = board ? .board : .list
                store.updateList(list)
            }
        })
    }
    /// True when the current destination renders a Kanban board.
    private var isBoardDestination: Bool { if case .list = destination { return true }; return false }
    /// The board's list scope. Separate from `activeList` (which resolves to
    /// nil for dangling destinations): a missing list must not silently fall
    /// back to Inbox scope.
    private var boardListID: UUID? { if case .list(let id) = destination { return id }; return nil }
    @State private var searchDialog = false
    @State private var searchQuery = ""
    @State private var filterEditor: TaskFilter?
    @State private var mergeDraft: TagMergeDraft?
    @State private var creatingFilter = false
    @State private var templatePicker = false
    @State private var purgeCandidate: UUID?
    @AppStorage("Taskovsky.collapsedSidebarSections", store: IsolatedDefaults.store) private var collapsedSidebarSections = ""
    @AppStorage("Taskovsky.sidebarWidth", store: IsolatedDefaults.store) private var sidebarWidth = 215.0
    @AppStorage("Taskovsky.sidebarCollapsed", store: IsolatedDefaults.store) private var sidebarCollapsed = false
    @AppStorage("Taskovsky.taskPaneFraction", store: IsolatedDefaults.store) private var taskPaneFraction = 0.45
    // Stable divider dragging: gestures report absolute global x; the start
    // position and start size are captured on the first event and every frame
    // derives from those, so local translation can never accumulate jitter.
    // Live sizes stay in transient State and reach AppStorage only on release.
    @State private var sidebarDragStart: Double?
    @State private var paneDragStart: Double?
    @State private var sidebarStartX: Double?
    @State private var paneStartX: Double?
    @State private var sidebarLive: Double?
    @State private var paneLive: Double?
    @State private var panelDragging = false
    // Frozen dock/auto-collapse decisions captured at drag start, so a
    // divider drag can never flap the detail or sidebar across a snapping
    // boundary mid-gesture.
    @State private var frozenShowSidebar: Bool?
    @State private var frozenDockDetail: Bool?
    // Narrow-width navigation popover: manual reveal without touching the
    // remembered collapse preference. Closes on navigation, outside tap,
    // Escape, expand, or toggle.
    @State private var sidebarPopoverOpen = false
    // Scoped Escape dismissal for the nav overlay (native popover behavior
    // had to be reimplemented with the in-window overlay). Installed only
    // while the overlay is open, removed on dismiss.
    @State private var escapeMonitor: Any?
    // Last measured content width, so the toggle behaves correctly even
    // before any resize (e.g. a window restored narrow). Refreshed on appear
    // and on every width change.
    @State private var lastTotalWidth = 1280.0
    @State private var nextCreationKind: TaskKind?
    @State private var quickFocused = false
    @State private var detailState = DetailSelectionState()
    @State private var viewOptions = false
    @State private var openPopups = Set<UUID>()
    @State private var listContentHeight: CGFloat = 0
    @State private var listViewportHeight: CGFloat = 0
    private var listFillerHeight: CGFloat { max(0, listViewportHeight - listContentHeight) }
    @AppStorage("Taskovsky.showDetailsPreview", store: IsolatedDefaults.store) private var showDetailsPreview = false
    @AppStorage("Taskovsky.calendarActive", store: IsolatedDefaults.store) private var calendarActive = false
    @AppStorage("Taskovsky.showChecklistItems", store: IsolatedDefaults.store) private var showChecklistItems = false
    @AppStorage("Taskovsky.detailLayout", store: IsolatedDefaults.store) private var detailLayout = "sidePeek"
    @AppStorage("Taskovsky.taskPaneCustomized", store: IsolatedDefaults.store) private var taskPaneCustomized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var selectedTask: TaskItem? { store.data.tasks.first { $0.id == detailState.selection } }
    private var sidePeekMode: Bool { detailLayout != "popup" }
    var activeList: TaskList? {
        if case .list(let id) = destination { return store.data.lists.first { $0.id == id } }; return nil
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            GeometryReader { geometry in
                // Responsive policy (see ResponsiveLayout): responsive pressure
                // goes to the right detail pane first, then to the sidebar.
                // Docked detail needs center 300 + divider + detail 280 (859pt
                // total with the default sidebar); below that the center keeps
                // its width and detail becomes a 300pt overlay drawer. Below
                // ~578pt the sidebar auto-hides too, while the manual
                // preference is remembered and restored on expand. The exact
                // TickTick thresholds are unknown, so these derived rules are
                // documented approximations; the 382pt minimum (rail 62 +
                // center 320, nav/detail hidden) is a measured reference.
                let liveSidebarWidth = sidebarLive ?? sidebarWidth
                let expandedNavWidth = min(ResponsiveLayout.sidebarMax, max(ResponsiveLayout.sidebarMin, liveSidebarWidth))
                // Single resolved layout. The dock decision keys off the manual
                // collapse preference (or full search): an auto-collapsed
                // sidebar must NOT free room for a docked detail, or shrinking
                // from 683 to 682 at custom sidebar 320 would dock the detail
                // while shrinking and undock it again at 642 — non-monotonic
                // jumps violating detail-first collapse. The available width
                // still uses the effective (auto-collapsed) visibility.
                let computedShowSidebar = ResponsiveLayout.isSidebarDocked(totalWidth: geometry.size.width, sidebarWidth: sidebarWidth, manualCollapsed: sidebarCollapsed, searchActive: destination == .search)
                let computedDockDetail = ResponsiveLayout.shouldDockDetail(totalWidth: geometry.size.width, sidebarWidth: sidebarWidth, collapsed: sidebarCollapsed || destination == .search)
                // Frozen during divider drags so the gesture can never flap
                // either pane across a snapping boundary mid-drag.
                let showSidebar = frozenShowSidebar ?? computedShowSidebar
                let dockDetail = frozenDockDetail ?? computedDockDetail
                let autoCollapsed = ResponsiveLayout.shouldAutoCollapseSidebar(totalWidth: geometry.size.width, sidebarWidth: sidebarWidth)
                let navWidth = showSidebar ? expandedNavWidth : 0
                let available = geometry.size.width - ResponsiveLayout.railWidth - navWidth - (showSidebar ? ResponsiveLayout.dividerWidth : 0)
                // Pristine installs default to a 300pt detail with the remaining width
                // for the center; existing stored fractions are never overwritten. The
                // preference is only written once the user drags the divider.
                let pristineDetail = UserDefaults.standard.object(forKey: "Taskovsky.taskPaneFraction") == nil && !taskPaneCustomized
                let storedListWidth: Double = {
                    if pristineDetail { return max(ResponsiveLayout.listMin, available - ResponsiveLayout.dividerWidth - ResponsiveLayout.drawerWidth) }
                    return ResponsiveLayout.dockedListWidth(available: available, fraction: taskPaneFraction)
                }()
                // Transient drag size; committed to AppStorage only on release.
                let listWidth = paneLive ?? storedListWidth
                HStack(spacing: 0) {
                    rail
                    if calendarActive {
                        TaskCalendarWorkspace(store: store, onOpenTask: openPopup, onComplete: complete)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Keep the contents at their expanded size while the panel slides
                        // behind the rail. Reflowing the sidebar at every frame makes its
                        // labels wrap and jump during the transition.
                        HStack(spacing: 0) {
                            sidebar(now: timeline.date, registrationActive: showSidebar).frame(width: expandedNavWidth)
                            PanelDivider { x, ended in onSidebarDrag(x: x, ended: ended, totalWidth: geometry.size.width, showSidebar: computedShowSidebar, dockDetail: computedDockDetail) }
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
                                } else { taskPane(now: timeline.date, overlay: false, paneWidth: CGFloat(listWidth)) }
                            }.frame(width: listWidth)
                            PanelDivider { x, ended in onPaneDrag(x: x, ended: ended, listWidth: storedListWidth, available: available) }
                            detailDock.frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ZStack(alignment: .trailing) {
                                Group {
                                    if destination == .search {
                                        SearchPane(store: store, initialQuery: searchQuery, onSelectTask: selectSearchTask, onSelectList: { destination = .list($0) }, onSelectFilter: { destination = .filter($0) }, onSelectTag: { destination = .tag($0) }, onComplete: complete, onClose: { destination = .inbox }).id(searchQuery)
                                    } else { taskPane(now: timeline.date, overlay: true, paneWidth: CGFloat(available)) }
                                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                                // Overlay drawer: right-aligned, fixed 300pt, no scrim, soft
                                // shadow on its leading edge. It never reflows the list.
                                // Only rendered while open, so a closed drawer leaves no
                                // invisible focusable or hittable content behind.
                                if let task = selectedTask, detailState.drawerOpen { drawer(task: task) }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                                .animation(panelDragging || reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.22), value: detailState.drawerOpen)
                        }
                    }
                }
                .onAppear { lastTotalWidth = geometry.size.width; sidebarDrag.bind(store: store) }
                .animation(panelDragging || reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.22), value: sidebarCollapsed)
                // Shrinking into overlay dismisses the drawer but keeps the selection,
                // so growing back docks the same task. Never auto-opens on shrink.
                // An open schedule popover is cancelled rather than reopened blank:
                // only the visibility flag is retained, unsaved schedule edits are not.
                .onChange(of: dockDetail) { _, docked in
                    if !docked { detailState.shrinkToOverlay() }
                    if let sel = detailState.selection { drafts.scheduling[sel] = false }
                }
                .onChange(of: geometry.size.width) { _, width in
                    lastTotalWidth = width
                    // Expanding back to a docked sidebar retires the popover
                    // and restores the remembered manual preference in reverse.
                    if !ResponsiveLayout.shouldAutoCollapseSidebar(totalWidth: width, sidebarWidth: sidebarWidth) { sidebarPopoverOpen = false }
                }
                // Main-window-only floor bridge (zero-size, no layout effect).
                .background(WindowFloorBridge().frame(width: 0, height: 0))
                // Compact navigation overlay: replaces the native popover,
                // which centered its 220pt content on the tiny toggle and
                // clipped outside the window. This stays entirely in-window at
                // x77 (rail 62 + 15), top 56 under the header toggle, 220pt
                // wide with rounded background and soft shadow — a floating
                // popover appearance, not a full-height drawer. Rendered only
                // while compact and open: a clear full-area layer underneath
                // catches outside taps (never covering the popover, above it
                // in z-order), and nothing intercepts clicks when closed.
                .overlay(alignment: .topLeading) {
                    if sidebarPopoverOpen && autoCollapsed && destination != .search {
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { sidebarPopoverOpen = false }
                            navPopover(now: timeline.date, maxHeight: max(200, geometry.size.height - 56 - 12))
                                .offset(x: 77, y: 56)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear { installEscapeMonitor() }
                        .onDisappear { removeEscapeMonitor() }
                    }
                }
                // Shared in-app sidebar drag scope, placed AFTER the compact
                // popover overlay so docked AND compact rows resolve the same
                // coordinate space, receive the coordinator, and contribute
                // frames and viewport rects. The floating preview renders
                // above both sidebars at the workspace-reported pointer.
                // Rendered once here (not per row), purely visual: hit testing
                // is off. These modifiers only read geometry and publish
                // pointer/hover state; they never write layout, so there is no
                // per-mouse-move layout feedback loop.
                .overlay(alignment: .topLeading) {
                    if sidebarDrag.dragging, let preview = sidebarDrag.preview {
                        SidebarFloatingPreview(preview: preview, width: sidebarDrag.previewWidth)
                            .position(
                                x: sidebarDrag.pointer.x + CGFloat(SidebarPreviewSpec.pointerOffsetX),
                                y: sidebarDrag.pointer.y + CGFloat(SidebarPreviewSpec.pointerOffsetY)
                            )
                    }
                }
                .coordinateSpace(name: "taskovskySidebar")
                .environmentObject(sidebarDrag)
                .onPreferenceChange(SidebarDropFramesKey.self) { sidebarDrag.frames = $0 }
                .onPreferenceChange(SidebarViewportKey.self) { sidebarDrag.viewport = $0 }
                .onKeyPress(.escape) {
                    if sidebarDrag.isActive { sidebarDrag.cancel(); return .handled }
                    return .ignored
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                    sidebarDrag.cancel()
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
            EntitySheet(editor: item, folders: store.data.folders, tags: store.data.tags) { name, color, kind, symbol, folderID, belowFolders, parentTagID, showsInSmartLists, viewMode in
                if item.isTag {
                    if let id = item.entityID {
                        let stored = store.data.tags.first { $0.id == id }
                        store.updateTag(TaskTag(id: id, name: name, color: color, parentID: stored?.parentID, isCollapsed: stored?.isCollapsed ?? false, isPinned: stored?.isPinned ?? false))
                        // Parent changes route through cycle-safe validation.
                        _ = store.setTagParent(id: id, parentID: parentTagID)
                    }
                    else { _ = store.createTag(name: name, color: color, parentID: parentTagID) }
                } else {
                    if let id = item.entityID {
                        // Preserve folder membership, trailing placement,
                        // archive/pin flags, and smart-list inclusion on
                        // unrelated edits: the editor carries the stored
                        // values, so saving them back keeps them.
                        let stored = store.data.lists.first { $0.id == id }
                        store.updateList(TaskList(id: id, name: name, color: color, kind: kind, symbol: symbol, viewMode: viewMode, folderID: folderID, belowFolders: belowFolders, isArchived: stored?.isArchived ?? false, showsInSmartLists: showsInSmartLists, isPinned: stored?.isPinned ?? false))
                    } else {
                        let id = store.createList(name: name, color: color, kind: kind, symbol: symbol, folderID: folderID, showsInSmartLists: showsInSmartLists)
                        if viewMode == .board, var list = store.data.lists.first(where: { $0.id == id }) {
                            list.viewMode = .board
                            store.updateList(list)
                        }
                        destination = .list(id)
                    }
                }
            }
        }
        .sheet(item: $folderDraft) { draft in
            FolderSheet(title: draft.folderID == nil ? "New Folder" : "Rename Folder", initialName: draft.initialName) { name in
                if let id = draft.folderID { _ = store.renameFolder(id: id, name: name) }
                else { _ = store.createFolder(name: name) }
            }
        }
        .sheet(isPresented: $searchDialog) {
            SearchDialog(store: store, onSearch: { searchQuery = $0; destination = .search; detailState.clear(); searchDialog = false }, onSelectTask: { selectSearchTask($0); searchDialog = false }, onSelectList: { destination = .list($0); detailState.navigate(); searchDialog = false }, onSelectFilter: { destination = .filter($0); detailState.navigate(); searchDialog = false }, onSelectTag: { destination = .tag($0); detailState.navigate(); searchDialog = false }, onComplete: complete)
        }
        .sheet(item: $filterEditor) { FilterEditorView(store: store, filter: $0) }
        .sheet(item: $mergeDraft) { draft in
            MergeTagsSheet(store: store, sourceID: draft.sourceID) { targetID in
                if store.mergeTags(source: draft.sourceID, target: targetID) {
                    if destination == .tag(draft.sourceID) { destination = .tag(targetID); detailState.navigate() }
                }
            }
        }
        .sheet(isPresented: $creatingFilter) { FilterEditorView(store: store) }
        .sheet(isPresented: $viewOptions) { ViewOptionsView(layout: $detailLayout) }
        .sheet(isPresented: $templatePicker) {
            TemplatePicker(store: store) { template in
                if let id = store.createTaskFromTemplate(id: template.id, listID: activeList?.id, dueDate: contextualDate, useDefaultList: destination != .inbox && activeList == nil) { selectTask(id) }
                templatePicker = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in guard !calendarActive else { return }; quickKind = .task; if destination == .trash || destination == .completed || destination == .wontDo || destination == .search || destination == .summary { nextCreationKind = .task; destination = .inbox }; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in calendarActive = false; if destination != .inbox && activeList == nil { nextCreationKind = .note; destination = .inbox }; quickKind = .note; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newList)) { _ in editor = EntityEditor(isTag: false) }
        .onReceive(NotificationCenter.default.publisher(for: .newFolder)) { _ in folderDraft = FolderSheetDraft(folderID: nil, initialName: "") }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in calendarActive = false; searchDialog = true }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in if !calendarActive { toggleSidebar() } }
        .onReceive(NotificationCenter.default.publisher(for: .trashTask)) { note in if let id = note.object as? UUID { trash(id) } }
        .onReceive(NotificationCenter.default.publisher(for: .popupClosed)) { note in if let id = note.object as? UUID { openPopups.remove(id) } }
        .onReceive(NotificationCenter.default.publisher(for: .requestPurge)) { note in if let id = note.object as? UUID { purgeCandidate = id } }
        .onReceive(NotificationCenter.default.publisher(for: .revealRestoredTask)) { note in
            if let id = note.object as? UUID, let task = store.data.tasks.first(where: { $0.id == id }) {
                calendarActive = false
                destination = task.listID.map(Destination.list) ?? .inbox
                detailState.navigate()
            }
        }
        .onChange(of: destination) { _, _ in
            if let task = selectedTask, !destination.includes(task, data: store.data) { detailState.clear() }
            quickKind = nextCreationKind ?? (activeList?.kind == .note ? .note : .task); nextCreationKind = nil
        }
        .alert("Delete Forever?", isPresented: isPurgeAlertPresented, presenting: purgeCandidate) { id in
            Button("Delete Forever", role: .destructive) { _ = store.purgeTask(id: id); purgeCandidate = nil }
            Button("Cancel", role: .cancel) { purgeCandidate = nil }
        } message: { id in
            Text("This permanently deletes \"\(store.data.tasks.first { $0.id == id }?.title ?? "this item")\" and cannot be undone.")
        }
    }

    private func toggleSidebar() {
        // At a docked width this flips the remembered manual preference.
        // Auto-collapsed at narrow width, it reveals the navigation popover
        // instead and never touches the preference.
        let auto = ResponsiveLayout.shouldAutoCollapseSidebar(totalWidth: lastTotalWidth, sidebarWidth: sidebarWidth)
        if destination == .search || !auto {
            sidebarCollapsed.toggle()
            sidebarPopoverOpen = false
        } else {
            sidebarPopoverOpen.toggle()
        }
    }
    private func onSidebarDrag(x: Double, ended: Bool, totalWidth: Double, showSidebar: Bool, dockDetail: Bool) {
        if sidebarStartX == nil {
            sidebarStartX = x
            sidebarDragStart = sidebarLive ?? sidebarWidth
            panelDragging = true
            frozenShowSidebar = showSidebar
            frozenDockDetail = dockDetail
        }
        let delta = x - (sidebarStartX ?? x)
        let start = sidebarDragStart ?? sidebarWidth
        // Transient only; AppStorage is written once, on release. While the
        // detail stays docked the live width additionally clamps to the
        // dock-safe maximum, so widening the sidebar can never squeeze the
        // center below its minimum or steal the detail's minimum mid-gesture.
        let dockMax = dockDetail ? PanelDrag.dockedSidebarMax(totalWidth: totalWidth) : nil
        sidebarLive = PanelDrag.clampedSidebarWidth(start: start, delta: delta, maxWidth: dockMax)
        if ended {
            if PanelDrag.shouldCollapseSidebar(start: start, delta: delta) { sidebarCollapsed = true }
            else { sidebarWidth = sidebarLive ?? start }
            sidebarLive = nil
            sidebarDragStart = nil
            sidebarStartX = nil
            panelDragging = false
            frozenShowSidebar = nil
            frozenDockDetail = nil
        }
    }
    private func onPaneDrag(x: Double, ended: Bool, listWidth: Double, available: Double) {
        if paneStartX == nil {
            paneStartX = x
            paneDragStart = paneLive ?? listWidth
            panelDragging = true
        }
        let delta = x - (paneStartX ?? x)
        let start = paneDragStart ?? listWidth
        // Transient only; the persisted fraction is written once, on release.
        paneLive = min(max(ResponsiveLayout.listMin, available - ResponsiveLayout.dividerWidth - ResponsiveLayout.detailMin), max(ResponsiveLayout.listMin, start + delta))
        if ended {
            taskPaneFraction = PanelDrag.paneFraction(startListWidth: start, delta: delta, available: available)
            taskPaneCustomized = true
            paneLive = nil
            paneDragStart = nil
            paneStartX = nil
            panelDragging = false
        }
    }
    /// Floating navigation panel for compact widths: the sidebar content in
    /// a 220pt rounded, shadowed card that scrolls within the visible window
    /// below the header. The collapsed docked sidebar stays hidden from
    /// accessibility while this open overlay carries the navigation.
    private func navPopover(now: Date, maxHeight: CGFloat) -> some View {
        sidebar(now: now)
            .frame(width: CGFloat(ResponsiveLayout.sidebarPopoverWidth))
            .frame(maxHeight: maxHeight)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 14, y: 4)
    }
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        // Captured binding (reference-like) rather than struct self, which
        // an escaping monitor closure cannot mutate.
        let popover = $sidebarPopoverOpen
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                popover.wrappedValue = false
                return nil
            }
            return event
        }
    }
    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor { NSEvent.removeMonitor(monitor); escapeMonitor = nil }
    }
    private var detailDock: some View {
        Group {
            if let task = selectedTask {
                TaskDetail(store: store, drafts: drafts, id: task.id, onTrash: { trash(task.id) }, onComplete: { complete(task.id) }, onWontDo: { abandon(task.id) }, onClose: nil, onRestore: { restoreExplicit(task.id) }, onPurge: { purgeCandidate = task.id }, onNavigateToTask: { selectTask($0) }).id(task.id)
            } else { DetailPlaceholder() }
        }
    }
    private func drawer(task: TaskItem) -> some View {
        TaskDetail(store: store, drafts: drafts, id: task.id, onTrash: { trash(task.id); closeDrawer() }, onComplete: { complete(task.id) }, onWontDo: { abandon(task.id) }, onClose: closeDrawer, compact: true, onRestore: { restoreExplicit(task.id) }, onPurge: { purgeCandidate = task.id }, onNavigateToTask: { selectTask($0) }).id(task.id)
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
            RailButton(title: "Tasks", active: !calendarActive && destination != .search, symbol: "checkmark", selectedTile: true) { calendarActive = false; destination = .today; closeDrawer() }
            RailButton(title: "Calendar", active: calendarActive, symbol: "calendar", selectedTile: true) { calendarActive = true; sidebarPopoverOpen = false; closeDrawer() }
            RailButton(title: "Search", active: !calendarActive && destination == .search, symbol: "magnifyingglass", selectedTile: false) { calendarActive = false; searchDialog = true }
            Spacer()
            SettingsLink { HoverIcon { Image(systemName: "gearshape").font(.system(size: 22)).foregroundStyle(.secondary).padding(8) } }.buttonStyle(.plain).help("Settings · ⌘,").accessibilityLabel("Settings")
            Spacer().frame(height: 18)
        }.frame(width: ResponsiveLayout.railWidth).background(railBackground)
    }
    private func sidebar(now: Date, registrationActive: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Top smart destinations reorder within their group (group
                    // boundary below stays fixed). Hidden keys keep their order
                    // while hidden; only visible rows participate in drags.
                    ForEach(topSmartDestinations(now: now), id: \.self) { dest in smartNavRow(dest, now: now, registrationActive: registrationActive) }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    if hasPinnedShortcuts {
                        pinnedSection(now: now, registrationActive: registrationActive)
                    }
                    listsSection(now: now, registrationActive: registrationActive)
                    archivedListsSection(now: now, registrationActive: registrationActive)
                    if sectionVisible(.filters, count: store.data.filters.count) {
                        sectionHeading("Filters") { creatingFilter = true }.padding(.top, 20)
                        if sectionExpanded("Filters").wrappedValue {
                        ForEach(store.data.filters) { filter in
                            navRow(.filter(filter.id), now: now).contextMenu { filterMenu(filter) }
                        }
                        if store.data.filters.isEmpty { Text("Display tasks filtered by list, date, priority, tag, and more").font(.system(size: 12)).foregroundStyle(.secondary).padding(10).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8)) }
                    }
                    }
                    if sectionVisible(.tags, count: store.data.tags.count) {
                    sectionHeading("Tags") { editor = EntityEditor(isTag: true) }.padding(.top, 20)
                    if sectionExpanded("Tags").wrappedValue {
                        tagTreeRows(TagHierarchy.roots(in: store.data.tags), now: now, depth: 0, registrationActive: registrationActive)
                    }
                    }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    ForEach(bottomSmartDestinations(now: now), id: \.self) { dest in smartNavRow(dest, now: now, registrationActive: registrationActive) }
                }.padding(.horizontal, 8).padding(.top, 12)
            }
            // Visible scroll-viewport frame for the drag engine's hit-test
            // gate, reported in the shared sidebar coordinate space. A
            // background reader never affects layout, so marker and label
            // overlays stay zero-layout with no measurement feedback loop.
            .sidebarViewportFrame(active: registrationActive)
        }.background(Color(nsColor: .textBackgroundColor))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: collapsedSidebarSections)
    }
    private func sectionHeading(_ text: String, action: @escaping () -> Void) -> some View {
        SidebarHeading(title: text, expanded: sectionExpanded(text), onAdd: action)
    }
    /// A heading row without an add action (Pinned, Archived Lists).
    private func plainSectionHeading(_ text: String) -> some View {
        let expanded = sectionExpanded(text)
        return Button { expanded.wrappedValue.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right").rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0)).font(.system(size: 8, weight: .medium))
                Text(text).font(.system(size: 12, weight: .medium)); Spacer(minLength: 0)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.leading, 5).padding(.trailing, 10).padding(.bottom, 6)
            .accessibilityLabel((expanded.wrappedValue ? "Collapse " : "Expand ") + text)
    }
    /// Pinned shortcuts for lists, folders, tags, and saved filters. Rendered
    /// only when at least one pin exists; normal sections keep their order.
    /// A pinned folder expands inline (a folder is not a task destination).
    private var hasPinnedShortcuts: Bool {
        store.data.lists.contains { $0.isPinned && !$0.isArchived } || store.data.folders.contains { $0.isPinned } || store.data.tags.contains { $0.isPinned } || store.data.filters.contains { $0.isPinned }
    }
    private func pinnedSection(now: Date, registrationActive: Bool = true) -> some View {
        VStack(spacing: 0) {
            plainSectionHeading("Pinned")
            if sectionExpanded("Pinned").wrappedValue {
                let lists = store.data.lists.filter { $0.isPinned && !$0.isArchived }
                if !lists.isEmpty {
                    pinnedCaption("Lists")
                    ForEach(lists) { list in
                        navRow(.list(list.id), color: Color(hex: list.color), now: now, registrationActive: registrationActive)
                            .contextMenu { listMenu(list) }
                    }
                }
                let folders = store.data.folders.filter(\.isPinned)
                if !folders.isEmpty {
                    pinnedCaption("Folders")
                    ForEach(folders) { folder in pinnedFolderRow(folder, now: now, registrationActive: registrationActive) }
                }
                let tags = store.data.tags.filter(\.isPinned)
                if !tags.isEmpty {
                    pinnedCaption("Tags")
                    ForEach(tags) { tag in
                        navRow(.tag(tag.id), color: Color(hex: tag.color), now: now, registrationActive: registrationActive)
                            .contextMenu { tagMenu(tag) }
                    }
                }
                let filters = store.data.filters.filter(\.isPinned)
                if !filters.isEmpty {
                    pinnedCaption("Filters")
                    ForEach(filters) { filter in
                        navRow(.filter(filter.id), now: now).contextMenu { filterMenu(filter) }
                    }
                }
            }
        }.padding(.bottom, 6)
    }
    private func pinnedCaption(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10).padding(.top, 4).padding(.bottom, 2)
    }
    private func pinnedFolderRow(_ folder: ListFolder, now: Date, registrationActive: Bool = true) -> some View {
        let isCollapsed = collapsedFolderIDs.contains(folder.id)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { var next = collapsedFolderIDs; if next.contains(folder.id) { next.remove(folder.id) } else { next.insert(folder.id) }; collapsedFolderIDs = next } label: {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(isCollapsed ? 0 : 90)).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).accessibilityLabel((isCollapsed ? "Expand " : "Collapse ") + folder.name)
                Image(systemName: "folder").font(.system(size: 14)).foregroundStyle(.secondary)
                Text(folder.name).font(.system(size: 14)).lineLimit(1)
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 10).frame(height: 38).contentShape(Rectangle())
            .onTapGesture {
                var next = collapsedFolderIDs
                if next.contains(folder.id) { next.remove(folder.id) } else { next.insert(folder.id) }
                collapsedFolderIDs = next
            }
            .contextMenu { folderMenu(folder) }
            if !isCollapsed {
                ForEach(store.data.lists.filter { $0.folderID == folder.id && !$0.isArchived }) { list in
                    navRow(.list(list.id), color: Color(hex: list.color), now: now, indentation: 16, registrationActive: registrationActive)
                        .contextMenu { listMenu(list) }
                }
            }
        }
    }
    /// Archived lists keep their stored order and folder slots; only active
    /// lists render in the normal Lists section. Rows navigate to a read-only
    /// list view and never accept drops.
    private func archivedListsSection(now: Date, registrationActive: Bool = true) -> some View {
        let archived = store.data.lists.filter(\.isArchived)
        return Group {
            if !archived.isEmpty {
                VStack(spacing: 0) {
                    plainSectionHeading("Archived Lists").padding(.top, 20)
                    if sectionExpanded("Archived Lists").wrappedValue {
                        ForEach(archived) { list in
                            navRow(.list(list.id), color: Color(hex: list.color), now: now, allowDrop: false, dimmed: true, registrationActive: registrationActive)
                                .contextMenu { listMenu(list) }
                        }
                        Text("Archived lists are read-only. Unarchive to edit again.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }
                }
            }
        }
    }
    /// Recursive tag tree. Counts include descendants (see `includes`); the
    /// collapse state persists on the tag. `AnyView` breaks the recursion for
    /// the opaque return type.
    private func tagTreeRows(_ tags: [TaskTag], now: Date, depth: Int, registrationActive: Bool) -> AnyView {
        AnyView(ForEach(tags) { tag in
            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    if TagHierarchy.children(of: tag.id, in: store.data.tags).isEmpty {
                        Color.clear.frame(width: 16, height: 20)
                    } else {
                        Button { _ = store.setTagCollapsed(id: tag.id, collapsed: !tag.isCollapsed) } label: {
                            Image(systemName: "chevron.right").rotationEffect(.degrees(tag.isCollapsed ? 0 : 90)).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary).frame(width: 16, height: 20).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel((tag.isCollapsed ? "Expand " : "Collapse ") + tag.name)
                    }
                    navRow(.tag(tag.id), color: Color(hex: tag.color), now: now, registrationActive: registrationActive)
                        .contextMenu { tagMenu(tag) }
                }.padding(.leading, CGFloat(depth) * 12)
                if !tag.isCollapsed {
                    tagTreeRows(TagHierarchy.children(of: tag.id, in: store.data.tags), now: now, depth: depth + 1, registrationActive: registrationActive)
                }
            }
        })
    }
    @ViewBuilder private func tagMenu(_ tag: TaskTag) -> some View {
        Button(tag.isPinned ? "Unpin" : "Pin") { _ = store.setTagPinned(id: tag.id, pinned: !tag.isPinned) }
        Button("Edit Tag…") { editor = EntityEditor(tag: tag) }
        Button("Add Sub-tag") { editor = EntityEditor(isTag: true, parentTagID: tag.id) }
        Button("Merge Tags…") { mergeDraft = TagMergeDraft(sourceID: tag.id) }
        Button("Delete Tag", role: .destructive) {
            store.deleteTag(id: tag.id)
            if destination == .tag(tag.id) { destination = .all }
        }
    }
    @ViewBuilder private func filterMenu(_ filter: TaskFilter) -> some View {
        Button(filter.isPinned ? "Unpin" : "Pin") { _ = store.setFilterPinned(id: filter.id, pinned: !filter.isPinned) }
        Button("Edit Filter…") { filterEditor = filter }
        Button("Delete Filter", role: .destructive) { store.deleteFilter(id: filter.id); if destination == .filter(filter.id) { destination = .inbox } }
    }
    @ViewBuilder private func folderMenu(_ folder: ListFolder) -> some View {
        Button(folder.isPinned ? "Unpin" : "Pin") { _ = store.setFolderPinned(id: folder.id, pinned: !folder.isPinned) }
        Button("Add List") { editor = EntityEditor(isTag: false, folderID: folder.id) }
        Button("Rename…") { folderDraft = FolderSheetDraft(folderID: folder.id, initialName: folder.name) }
        Button("Ungroup") { _ = store.ungroupFolder(id: folder.id) }
        Text("Lists and tasks are kept")
    }
    /// Lists section with folders. The heading offers New List / New Folder
    /// and accepts list drops as the top-root affordance (always visible,
    /// never a zero-sized target). Folder rows offer Add List / Rename /
    /// Ungroup, collapse via disclosure, and accept drops even when collapsed.
    /// List rows reorder within/across folders and adopt the target's folder
    /// and root segment; dropping onto a folder assigns/appends. The unlabeled
    /// end strip drops to trailing root below all folders.
    private func listsSection(now: Date, registrationActive: Bool = true) -> some View {
        // In-app highlight for list drags over the heading root affordance.
        // The only native drop here was the dead list source path; tasks
        // never target the heading.
        let rootHover = sidebarDrag.isHovered(.root)
        return VStack(spacing: 0) {
            // Disclosure fills the remainder while the Menu is pinned to the
            // trailing content edge (fixedSize keeps the borderless Menu from
            // accepting extra width and drifting the plus left of the row
            // counts). The plus reveals on hover anywhere over the heading but
            // reserves its slot via opacity, so alignment never shifts.
            HStack(spacing: 5) {
                Button { sectionExpanded("Lists").wrappedValue.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right").rotationEffect(.degrees(sectionExpanded("Lists").wrappedValue ? 90 : 0)).font(.system(size: 8, weight: .medium))
                        Text("Lists").font(.system(size: 12, weight: .medium)); Spacer(minLength: 0)
                    }.contentShape(Rectangle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityLabel((sectionExpanded("Lists").wrappedValue ? "Collapse " : "Expand ") + "Lists")
                Menu {
                    Button("New List") { editor = EntityEditor(isTag: false) }
                    Button("New Folder") { folderDraft = FolderSheetDraft(folderID: nil, initialName: "") }
                } label: { Image(systemName: "plus").font(.system(size: 12)).frame(width: 16, height: 16).contentShape(Rectangle()) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .fixedSize()
                    .opacity(listsHeadingHovered ? 1 : 0)
                    .help("Add list or folder").accessibilityLabel("Add list or folder")
            }
            .foregroundStyle(.secondary).padding(.leading, 5).padding(.trailing, 10).padding(.bottom, 6)
            .contentShape(Rectangle())
            .onHover { listsHeadingHovered = $0 }
            .background(rootHover ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .sidebarDropTargetFrame(.root, active: registrationActive)
            .contextMenu {
                Button("New List") { editor = EntityEditor(isTag: false) }
                Button("New Folder") { folderDraft = FolderSheetDraft(folderID: nil, initialName: "") }
            }
            if sectionExpanded("Lists").wrappedValue {
                // Top root lists in persisted order, then folders with their
                // children, then trailing root lists in persisted order.
                ForEach(store.data.lists.filter { $0.folderID == nil && !$0.belowFolders && !$0.isArchived }) { list in
                    navRow(.list(list.id), color: Color(hex: list.color), now: now, registrationActive: registrationActive)
                        .contextMenu { listMenu(list) }
                }
                ForEach(store.data.folders) { folder in folderSection(folder, now: now, registrationActive: registrationActive) }
                ForEach(store.data.lists.filter { $0.folderID == nil && $0.belowFolders && !$0.isArchived }) { list in
                    navRow(.list(list.id), color: Color(hex: list.color), now: now, registrationActive: registrationActive)
                        .contextMenu { listMenu(list) }
                }
                // Unlabeled end strip: always available while Lists is expanded
                // (even with no visible rows), so a list can always drop to the
                // absolute bottom as trailing root. Constant height, no idle
                // visual; hover shows a root-level insertion line with a
                // shallower leading inset than nested row markers.
                let endHover = sidebarDrag.isHovered(.rootEnd)
                ZStack(alignment: .center) {
                    Color.clear.frame(height: 14)
                    if endHover { SidebarInsertionLine(leadingInset: 10) }
                }
                .contentShape(Rectangle())
                .sidebarDropTargetFrame(.rootEnd, active: registrationActive)
                .accessibilityHidden(true)
            }
        }
    }
    @State private var listsHeadingHovered = false
    private func folderSection(_ folder: ListFolder, now: Date, registrationActive: Bool = true) -> some View {
        let isCollapsed = collapsedFolderIDs.contains(folder.id)
        let memberCount = store.data.lists.filter { $0.folderID == folder.id && !$0.isArchived }.count
        let preview = SidebarDragPreview(title: folder.name, leading: .folder, count: memberCount, showsDisclosure: true)
        return VStack(spacing: 0) {
            FolderDropRow(folderID: folder.id, preview: preview, framesActive: registrationActive) {
                // Tap (not Button) disclosure so the row's drag gesture can win
                // mouse arbitration once the pointer moves; keyboard and
                // context menus are preserved explicitly below.
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(isCollapsed ? 0 : 90)).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
                    Image(systemName: "folder").font(.system(size: 14)).foregroundStyle(.secondary)
                    Text(folder.name).font(.system(size: 14)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(memberCount)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.horizontal, 10).frame(height: 38).contentShape(Rectangle())
                // Folders are disclosure containers, not navigable
                // destinations, so rows never carry selection styling.
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 9))
                .onTapGesture {
                    var next = collapsedFolderIDs
                    if next.contains(folder.id) { next.remove(folder.id) } else { next.insert(folder.id) }
                    collapsedFolderIDs = next
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel((isCollapsed ? "Expand " : "Collapse ") + folder.name)
                .accessibilityHint("Folder containing lists")
                .accessibilityAction {
                    var next = collapsedFolderIDs
                    if next.contains(folder.id) { next.remove(folder.id) } else { next.insert(folder.id) }
                    collapsedFolderIDs = next
                }
                .focusable().focusEffectDisabled()
                .onKeyPress(.return) {
                    var next = collapsedFolderIDs
                    if next.contains(folder.id) { next.remove(folder.id) } else { next.insert(folder.id) }
                    collapsedFolderIDs = next
                    return .handled
                }
                .onKeyPress(.space) {
                    var next = collapsedFolderIDs
                    if next.contains(folder.id) { next.remove(folder.id) } else { next.insert(folder.id) }
                    collapsedFolderIDs = next
                    return .handled
                }
                .contextMenu { folderMenu(folder) }
            }
            if !isCollapsed {
                ForEach(store.data.lists.filter { $0.folderID == folder.id && !$0.isArchived }) { list in
                    navRow(.list(list.id), color: Color(hex: list.color), now: now, indentation: 16, registrationActive: registrationActive)
                        .contextMenu { listMenu(list) }
                }
            }
        }
    }
    @ViewBuilder private func listMenu(_ list: TaskList) -> some View {
        Button(list.isPinned ? "Unpin" : "Pin") { _ = store.setListPinned(id: list.id, pinned: !list.isPinned) }
        Button("Edit List…") { editor = EntityEditor(list: list) }
        Button("Duplicate List") {
            if let id = store.duplicateList(id: list.id) { destination = .list(id); detailState.navigate() }
        }
        Menu("Move to Folder") {
            Button("No folder") { _ = store.moveListToFolder(listID: list.id, folderID: nil) }
            ForEach(store.data.folders) { folder in Button(folder.name) { _ = store.moveListToFolder(listID: list.id, folderID: folder.id) } }
        }
        Button(list.showsInSmartLists ? "Hide from Smart Lists" : "Show in Smart Lists") {
            _ = store.setListSmartInclusion(id: list.id, shows: !list.showsInSmartLists)
        }
        Divider()
        if list.isArchived {
            Button("Unarchive List") { _ = store.setListArchived(id: list.id, archived: false) }
        } else {
            Button("Archive List") {
                if store.setListArchived(id: list.id, archived: true), destination == .list(list.id) {
                    destination = .inbox; detailState.navigate()
                }
            }
        }
        Button("Delete List", role: .destructive) {
            store.deleteList(id: list.id)
            if destination == .list(list.id) { destination = .inbox }
        }
        Text("Tasks are moved to Inbox")
    }
    private func sectionExpanded(_ title: String) -> Binding<Bool> {
        Binding(get: { !collapsedSidebarSections.split(separator: "|").contains(Substring(title)) }, set: { expanded in
            var values = Set(collapsedSidebarSections.split(separator: "|").map(String.init))
            if expanded { values.remove(title) } else { values.insert(title) }
            collapsedSidebarSections = values.sorted().joined(separator: "|")
        })
    }

    /// Ordered visible top/bottom smart destinations from persisted order.
    /// Hidden keys keep their slots in settings; filtered drags never resave
    /// a scrambled hidden order.
    private func topSmartDestinations(now: Date) -> [Destination] {
        store.settings.effectiveSmartListOrder.compactMap { key -> Destination? in
            guard AppSettings.topSmartGroup.contains(key) else { return nil }
            let dest = Destination(smartKey: key, lists: store.data.lists)
            // tags/filters keys map to .all above but are never draggable rows;
            // skip them here so section headings aren't advertised as targets.
            if key == .tags || key == .filters { return nil }
            return visible(dest, now: now) ? dest : nil
        }
    }
    private func bottomSmartDestinations(now: Date) -> [Destination] {
        store.settings.effectiveSmartListOrder.compactMap { key -> Destination? in
            guard AppSettings.bottomSmartGroup.contains(key) else { return nil }
            let dest = Destination(smartKey: key, lists: store.data.lists)
            return visible(dest, now: now) ? dest : nil
        }
    }
    /// Smart row with reorder drag-out/drop halves plus Edit / Show if not
    /// empty / Hide (TickTick reference). Edit opens Settings=>Smart Lists
    /// even when Settings is already open elsewhere.
    private func smartNavRow(_ dest: Destination, now: Date, registrationActive: Bool = true) -> some View {
        guard let key = dest.smartKey else { return AnyView(navRow(dest, now: now, registrationActive: registrationActive)) }
        // Preview mirrors the row label: calendar glyphs for Today/Next 7
        // Days (day number / weekday letters), SF symbol otherwise.
        let leading: SidebarDragPreview.Leading
        if dest == .today {
            leading = .calendarText(String(Calendar.current.component(.day, from: now)))
        } else if dest == .week {
            leading = .calendarText(String(Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: now) - 1].prefix(2)))
        } else {
            leading = .systemImage(dest.symbol)
        }
        let count = store.data.tasks.filter { dest.includes($0, data: store.data, now: now) }.count
        let preview = SidebarDragPreview(title: dest.title(store.data), leading: leading, count: dest == .summary ? nil : count)
        let row = navRow(dest, now: now, registrationActive: registrationActive)
        return AnyView(SmartDropRow(key: key, preview: preview, framesActive: registrationActive) { row }
            .contextMenu {
                // Exactly the reference actions: Edit, Show if not empty,
                // Hide. The current mode carries a checkmark instead of a
                // fourth status row.
                Button("Edit") { openSmartLists() }
                Button { store.settings.smartListVisibility[key] = .showIfNotEmpty } label: {
                    if store.settings.smartListVisibility[key] == .showIfNotEmpty {
                        Label("Show if not empty", systemImage: "checkmark")
                    } else {
                        Text("Show if not empty")
                    }
                }
                Button { hideSmart(key: key, dest: dest) } label: {
                    if store.settings.smartListVisibility[key] == .hidden {
                        Label("Hide", systemImage: "checkmark")
                    } else {
                        Text("Hide")
                    }
                }
            })
    }
    /// Opens Settings on the Smart Lists section. Live notification retargets
    /// an already-open window (even from About/another pane); the parked
    /// pending section covers a fresh launch, where the notification alone
    /// would fire before the view exists. Uses the modern openSettings
    /// action, not the deprecated showSettingsWindow: selector.
    private func openSmartLists() {
        UserDefaults.standard.set("smartLists", forKey: pendingSettingsSectionKey)
        NotificationCenter.default.post(name: .openSmartLists, object: nil)
        openSettings()
    }
    /// Hides a smart list. If the hidden row is the active destination,
    /// navigates to the first visible top destination (else Inbox) so the
    /// center never shows a blank/stale screen.
    private func hideSmart(key: SmartListKey, dest: Destination) {
        store.settings.smartListVisibility[key] = .hidden
        if destination == dest {
            let now = Date()
            if let fallback = (topSmartDestinations(now: now) + bottomSmartDestinations(now: now)).first {
                destination = fallback
            } else {
                destination = .inbox
            }
            detailState.navigate()
        }
    }
    private func navRow(_ dest: Destination, color: Color? = nil, now: Date, indentation: CGFloat = 0, allowDrop: Bool = true, dimmed: Bool = false, registrationActive: Bool = true) -> some View {
        let count = store.data.tasks.filter { task in
            if case .filter(let id) = dest { return store.data.filters.first { $0.id == id }?.matches(task, lists: store.data.lists, now: now, calendar: store.settings.calendar) ?? false }
            return dest.includes(task, data: store.data, now: now)
        }.count
        let row = SidebarRow(selected: destination == dest, action: { destination = dest; sidebarPopoverOpen = false; closeDrawer() }) {
            HStack(spacing: 10) {
                Group {
                    if case .list(let id) = dest { ListSymbol(symbol: store.data.lists.first { $0.id == id }?.symbol) }
                    else if dest == .today { CalendarSymbol(text: String(Calendar.current.component(.day, from: now))) }
                    else if dest == .week { CalendarSymbol(text: String(Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: now) - 1].prefix(2))) }
                    else { Image(systemName: dest.symbol).font(.system(size: 16)).frame(width: 20) }
                }.foregroundStyle(.primary).frame(width: 20)
                Text(dest.title(store.data)).font(.system(size: 14)).lineLimit(1)
                if let color { Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true) }
                if dimmed { Image(systemName: "archivebox").font(.system(size: 11)).foregroundStyle(.tertiary).accessibilityHidden(true) }
                Spacer(minLength: 2)
                if count > 0 && dest != .summary { Text("\(count)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit() }
            }
        }.opacity(dimmed ? 0.75 : 1)
        // Typed native drops: Inbox and lists accept task payloads (with hover
        // highlighting and atomic move semantics). Sidebar-to-sidebar moves
        // (list/smart/folder/tag reorder, folder/root assignment) run through
        // the shared in-app SidebarDragCoordinator instead of native .onDrag,
        // whose source never starts inside a Button. Each delegate or frame
        // modifier sits on the row itself, never a covering overlay, so taps,
        // right-clicks, drag initiation, and context menus keep working.
        // Filter rows have no drop target and reject untouched. All five
        // payload types are distinct.
        switch dest {
        case .inbox:
            return AnyView(SidebarDropRow(listID: nil, preview: nil, onDropTasks: { moveTasks($0, to: nil) }) { row })
        case .list(let id):
            // Archived rows never accept drops; the store refuses archived
            // targets, so no highlight-or-reject flash is shown at all.
            if !allowDrop {
                if indentation > 0 {
                    return AnyView(row.padding(.leading, indentation))
                }
                return AnyView(row)
            }
            let list = store.data.lists.first { $0.id == id }
            let preview = SidebarDragPreview(
                title: list?.name ?? dest.title(store.data),
                leading: .listSymbol(list?.symbol),
                colorHex: list?.color,
                count: dest == .summary ? nil : count
            )
            let wrapped = SidebarDropRow(listID: id, preview: preview, framesActive: registrationActive, onDropTasks: { moveTasks($0, to: id) }) { row }
            if indentation > 0 {
                return AnyView(wrapped.padding(.leading, indentation))
            }
            return AnyView(wrapped)
        case .tag(let id):
            let tag = store.data.tags.first { $0.id == id }
            let preview = SidebarDragPreview(
                title: tag?.name ?? dest.title(store.data),
                leading: .systemImage(dest.symbol),
                colorHex: tag?.color,
                count: dest == .summary ? nil : count
            )
            return AnyView(TagDropRow(tagID: id, preview: preview, framesActive: registrationActive) { row })
        default:
            return AnyView(row)
        }
    }
    /// Atomically moves dragged tasks to a list (nil = Inbox). The store
    /// validates every ID first; any unknown, deleted, or duplicate record,
    /// or an unknown target list, aborts with no mutation.
    private func moveTasks(_ ids: [UUID], to listID: UUID?) -> Bool {
        store.moveTasksToList(ids: ids, listID: listID)
    }
    private func listContext(for task: TaskItem) -> String? {
        if destination == .inbox { return nil }
        if case .list(let id) = destination, task.listID == id { return nil }
        if let listID = task.listID { return store.data.lists.first { $0.id == listID }?.name }
        return "Inbox"
    }
    /// Center pane. `paneWidth` is the content width rows fill (docked list
    /// width, or available width in overlay); it flows statelessly into each
    /// row's metadata budget — never measured back out of layout.
    /// True when the center shows an archived list: QuickEntry hides, rows
    /// and detail lock, and only deliberate moves (row menu) stay available.
    private var isArchivedView: Bool {
        if case .list(let id) = destination { return store.data.lists.first { $0.id == id }?.isArchived == true }
        return false
    }
    /// True when a task sits in an archived list (row-level variant).
    private func isInArchivedList(_ task: TaskItem) -> Bool {
        task.listID.flatMap { id in store.data.lists.first { $0.id == id } }?.isArchived ?? false
    }
    private func taskPane(now: Date, overlay: Bool, paneWidth: CGFloat) -> some View {
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
                    Picker("Sort by", selection: Binding(get: { TaskSortPolicy.normalized(sort) }, set: { sort = $0 })) { ForEach(["None", "Date", "Priority", "Title", "Created"], id: \.self) { Text($0) } }
                    Text("None follows your drags and is saved.").font(.caption)
                    if destination != .completed && destination != .trash && destination != .wontDo { Toggle("Show Completed & Won't Do", isOn: $showCompleted) }
                } label: { HoverIcon { Image(systemName: "arrow.up.arrow.down").font(.system(size: 15)).foregroundStyle(.secondary).padding(6) } }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(Color(nsColor: .secondaryLabelColor)).fixedSize().help("Sort and display (None enables drag reordering)")
                if isBoardDestination {
                    Picker("View", selection: listViewBinding) { Text("List").tag(false); Text("Board").tag(true) }.pickerStyle(.segmented).frame(width: 130).help("List or Kanban board").accessibilityLabel("List or board view")
                }
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
            if destination != .trash && destination != .completed && destination != .wontDo && destination != .summary && !isArchivedView {
                QuickEntry(store: store, title: $quickTitle, kind: $quickKind, focused: $quickFocused, onTemplate: { templatePicker = true }) { body, recognizeDates in
                    addTask(body: body, recognizeDates: recognizeDates)
                }.padding(.horizontal, 20).padding(.bottom, 16)
            }
            if destination == .reminders { Text("Check due and upcoming reminders here. New items are set for one hour from now.").font(.caption).foregroundStyle(Palette.explanatory(colorScheme)).padding(.horizontal, 24).padding(.bottom, 16) }
            if destination == .trash { Text("Deleted items stay here until you restore them.").font(.caption).foregroundStyle(Palette.explanatory(colorScheme)).padding(.horizontal, 24).padding(.bottom, 16) }
            if isArchivedView { Text("Archived lists are read-only. Unarchive the list from the sidebar to edit, or use a row's Move to for a deliberate move.").font(.caption).foregroundStyle(Palette.explanatory(colorScheme)).padding(.horizontal, 24).padding(.bottom, 16) }
            if listViewBinding.wrappedValue && isBoardDestination, let boardListID {
                // Status board: every non-deleted status in this list (see
                // BoardProjection), independent of the rows' Show Completed
                // toggle — a completed drop stays visible and an
                // all-completed list still renders its columns. Drops change
                // status (completing a recurring task spawns its successor
                // like the row checkbox); notes refuse status columns with a
                // message. Hierarchy renders flat here.
                kanbanBoard(tasks: BoardProjection.tasks(forList: boardListID, in: store.data), overlay: overlay, now: now)
            } else if tasks.isEmpty {
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
                            // None (manual) is one group: reorder by dropping on
                            // the top or bottom half of a row, with an
                            // insertion line and a move proposal. No permanent
                            // spacing is added. Every other sort keeps its own
                            // groups and rejects reorder attempts with a
                            // message: order there is computed, and reordering
                            // must never silently rewrite dates, priorities,
                            // or status. Ordinary list moves still work.
                            if !collapsed.contains(title) {
                                let groupIDs = items.map(\.id)
                                // Subtasks nest directly under their parent when
                                // the parent is in the same group; orphans
                                // (parent filtered out) render as top-level
                                // rows so nothing vanishes.
                                ForEach(TaskHierarchy.displayOrder(items), id: \.task.id) { entry in
                                    taskRow(entry.task, groupIDs: groupIDs, overlay: overlay, now: now, paneWidth: paneWidth, depth: entry.depth)
                                }
                            }
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
        else if isInArchivedList(task) {
            // Archived rows keep one deliberate escape hatch: Move to an
            // active list. Archived lists never accept moves (store refuses).
            Menu("Move to") { Button("Inbox") { var t = task; t.listID = nil; store.updateTask(t) }; ForEach(store.data.lists.filter { !$0.isArchived }) { list in Button(list.name) { var t = task; t.listID = list.id; store.updateTask(t) } } }
            Text("Archived — read-only")
        }
        else {
            if task.kind == .task { Button(task.completedAt == nil && task.wontDoAt == nil ? "Complete" : "Mark incomplete") { complete(task.id) }; if task.wontDoAt == nil { Button("Won't Do") { abandon(task.id) } } }
            if task.completedAt == nil && task.wontDoAt == nil { Button(task.isPinned ? "Unpin" : "Pin") { _ = store.setPinned(id: task.id, pinned: !task.isPinned) } }
            Menu("Priority") { ForEach(TaskPriority.allCases, id: \.self) { value in Button(value.label) { var t = task; t.priority = value; store.updateTask(t) } } }
            Menu("Move to") { Button("Inbox") { var t = task; t.listID = nil; store.updateTask(t) }; ForEach(store.data.lists.filter { !$0.isArchived }) { list in Button(list.name) { var t = task; t.listID = list.id; store.updateTask(t) } } }
            Button("Duplicate") { if let id = store.duplicateTask(id: task.id) { selectTask(id) } }
            Button("Save as Template") { _ = store.saveTemplate(from: task.id) }
            if task.kind == .task {
                Button("Add Subtask") { if let id = store.addSubtask(to: task.id, title: "New subtask") { selectTask(id) } }
                if task.parentID != nil {
                    Button("Move to Top Level") { _ = store.setTaskParent(id: task.id, parentID: nil) }
                }
                let candidates = subtaskParentCandidates(for: task)
                if !candidates.isEmpty {
                    Menu("Make Subtask Of") {
                        ForEach(candidates) { parent in
                            Button(parent.title.isEmpty ? "Untitled" : parent.title) { _ = store.setTaskParent(id: task.id, parentID: parent.id) }
                        }
                    }
                }
            }
            Divider(); Button("Move to Trash", role: .destructive) { trash(task.id) }
        }
    }
    /// Candidate parents for "Make Subtask Of", shared with the detail view
    /// through the Core policy (same list, active, never a descendant).
    private func subtaskParentCandidates(for task: TaskItem) -> [TaskItem] {
        TaskHierarchy.parentCandidates(for: task, in: store.data.tasks)
    }
    /// None (manual) order follows the stored array order, so drag reordering
    /// is the sort: positions persist across reload and match what every
    /// surface shows. Legacy "Manual" reads as None. All other sorts compute
    /// their order and reject reorder attempts without mutation (with a
    /// user-facing message); ordinary list moves still work under any sort.
    private func filteredTasks(now: Date) -> [TaskItem] {
        // Last-wins on duplicate IDs (a malformed file must never trap the
        // whole list the way uniqueKeysWithValues would).
        var order: [UUID: Int] = [:]
        for (offset, task) in store.data.tasks.enumerated() { order[task.id] = offset }
        let normalizedSort = TaskSortPolicy.normalized(sort)
        return store.data.tasks.filter { task in
            if case .filter(let id) = destination { return store.data.filters.first { $0.id == id }?.matches(task, lists: store.data.lists, now: now, calendar: store.settings.calendar) ?? false }
            if destination.includes(task, data: store.data, now: now) { return true }
            if showCompleted && destination != .completed && destination != .trash && destination != .wontDo && (task.completedAt != nil || task.wontDoAt != nil) && task.deletedAt == nil { var copy = task; copy.completedAt = nil; copy.wontDoAt = nil; return destination.includes(copy, data: store.data, now: now) }
            return false
        }.sorted { a, b in
            let aActive = a.completedAt == nil && a.wontDoAt == nil
            let bActive = b.completedAt == nil && b.wontDoAt == nil
            if aActive != bActive { return aActive }
            switch normalizedSort {
            case "None": return (order[a.id] ?? 0) < (order[b.id] ?? 0)
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
        // None (manual) is a real sequence: one group for all active
        // tasks/notes — no date/priority partitions — so items with different
        // dates reorder freely without rewriting those fields. History stays
        // separate; Reminders keeps its semantic split; Trash is untouched.
        if TaskSortPolicy.isManual(sort) && destination != .trash && destination != .reminders {
            var active: [TaskItem] = []; var history: [TaskItem] = []
            for task in tasks {
                switch ManualGroupPolicy.bucket(completedAt: task.completedAt, wontDoAt: task.wontDoAt, deletedAt: task.deletedAt) {
                case .active: active.append(task)
                case .history, .deleted: history.append(task)
                }
            }
            var result: [(String, [TaskItem])] = []
            // Pinned active rows group above the normal manual sequence; each
            // side keeps stored-array order and stays its own reorder group,
            // so the None drag policy needs no exception.
            let (pinned, rest) = PinnedGrouping.partition(active)
            if !pinned.isEmpty { result.append((PinnedGrouping.pinnedGroupTitle, pinned)) }
            if !rest.isEmpty { result.append((ManualGroupPolicy.activeGroupTitle, rest)) }
            if !history.isEmpty {
                let title = destination == .completed ? "Completed" : destination == .wontDo ? "Won't Do" : tasks.contains(where: { $0.wontDoAt != nil }) ? "Completed & Won't Do" : "Completed"
                result.append((title, history))
            }
            return result
        }
        var keys: [String] = []; var values: [String: [TaskItem]] = [:]
        // Pinned active rows lift out of their computed groups into one Pinned
        // group above everything else (Trash, Completed, and Won't Do never
        // contain pinned rows by construction).
        let (pinned, unpinned) = PinnedGrouping.partition(tasks)
        for task in unpinned {
            let title: String
            if destination == .trash { title = "Deleted" }
            else if task.completedAt != nil || task.wontDoAt != nil {
                title = destination == .completed ? "Completed" : destination == .wontDo ? "Won't Do" : tasks.contains(where: { $0.wontDoAt != nil }) ? "Completed & Won't Do" : "Completed"
            }
            else if destination == .reminders { title = task.reminderDate! <= now ? "Due reminders" : "Upcoming reminders" }
            else if task.kind == .note && TaskSortPolicy.normalized(sort) == "Date" { title = "Note" }
            else if TaskSortPolicy.normalized(sort) == "Priority" { title = task.priority.label }
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
        var result = keys.map { ($0, values[$0]!) }
        if !pinned.isEmpty { result.insert((PinnedGrouping.pinnedGroupTitle, pinned), at: 0) }
        return result
    }
    private func addTask(body: String = "", recognizeDates: Bool = true) {
        let title = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        let due = contextualDate
        let id = store.createTask(title: title, listID: activeList?.id, kind: quickKind, dueDate: quickKind == .task ? due : nil, useDefaultList: destination != .inbox && activeList == nil, preferRecognizedDate: true, recognizeDates: recognizeDates, body: body)
        if case .tag(let tagID) = destination, var task = store.data.tasks.first(where: { $0.id == id }), !task.tagIDs.contains(tagID) { task.tagIDs.append(tagID); store.updateTask(task) }
        if destination == .reminders, var task = store.data.tasks.first(where: { $0.id == id }) { task.reminderDates = due.map { [$0] } ?? []; task.hasDueTime = quickKind == .task; store.updateTask(task) }
        if quickKind == .note && (destination == .today || destination == .tomorrow || destination == .week || destination == .all) { destination = .inbox }
        if let created = store.data.tasks.first(where: { $0.id == id }), !destination.includes(created, data: store.data), destination != .search {
            if case .filter = destination { } else if case .tag = destination { } else { destination = created.listID.map(Destination.list) ?? .inbox }
        }
        selectTask(id); quickTitle = ""; quickFocused = true
    }
    private func trash(_ id: UUID) { actions.trash(store: store, id: id); if detailState.selection == id { detailState.clear() } }
    private func restoreExplicit(_ id: UUID) {
        actions.restore(store: store, id: id)
        if let task = store.data.tasks.first(where: { $0.id == id }), !destination.includes(task, data: store.data) { detailState.clear() }
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
        return sectionVisible(key, count: store.data.tasks.filter { dest.includes($0, data: store.data, now: now) }.count)
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

/// Tag merge picker: chooses a distinct target tag for the source. The store
/// repoints task, template, and filter refs (deduped), follows the default
/// tag, and reparents surviving children without cycles.
struct MergeTagsSheet: View {
    @ObservedObject var store: TaskStore
    let sourceID: UUID
    let onMerge: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var targetID: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge Tags").font(.system(size: 18, weight: .bold))
            if let source = store.data.tags.first(where: { $0.id == sourceID }) {
                Text("Merge “\(source.name)” into:").foregroundStyle(.secondary)
            }
            Picker("Target tag", selection: $targetID) {
                Text("Choose target").tag(Optional<UUID>(nil))
                ForEach(store.data.tags.filter { $0.id != sourceID }) { tag in
                    Text(indent(tag) + tag.name).tag(Optional(tag.id))
                }
            }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            Text("Tasks, templates, filters, and the default tag move to the target. The source's sub-tags reparent without cycles, then the source is deleted.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Merge") { if let targetID { onMerge(targetID) }; dismiss() }.keyboardShortcut(.defaultAction).disabled(targetID == nil) }
        }.padding(24).frame(width: 420).tint(accent)
    }
    /// Indented display name so nesting survives in a flat picker.
    private func indent(_ tag: TaskTag) -> String {
        String(repeating: "  ", count: TagHierarchy.ancestors(of: tag.id, in: store.data.tags).count)
    }
}

/// One center-list row: detail selection, grip-only drag-out with a compact
/// preview, None-sort drop halves with an insertion line, and the row menu.
/// Non-None sorts reject reorder attempts without mutation and show the
/// sorted-mode message (no per-frame spam); ordinary list moves still work.
/// The drop halves commit atomically on drop only; anything invalid leaves
/// the saved order untouched.
private extension WorkspaceView {
    func taskRow(_ task: TaskItem, groupIDs: [UUID], overlay: Bool, now: Date, paneWidth: CGFloat, depth: Int = 0) -> some View {
        let isActive = task.deletedAt == nil
        let readOnly = isInArchivedList(task)
        let interactive = isActive && !readOnly
        // Grip visibility is resolved inside TaskRow from whole-row hover or
        // selection; the drag source lives on the grip only. Tapping the grip
        // selects in manual mode and reports the sorted-mode notice otherwise.
        return TaskRow(store: store, id: task.id, selection: $detailState.selection, now: now, listContext: listContext(for: task), paneWidth: paneWidth, showPreview: showDetailsPreview, showSteps: showChecklistItems, allowRename: sidePeekMode || !overlay, readOnly: readOnly, depth: depth, gripActive: interactive, onGripActivate: interactive ? {
            if isManualSort { selectTask(task.id) }
            else { actions.notice(TaskSortPolicy.reorderDisabledMessage) }
        } : nil, toggle: { complete(task.id) }, onSelect: { selectTask(task.id) }, onTitleDoubleClick: { if !sidePeekMode && overlay { openPopup(task.id) } }, onRowDoubleClick: { if !sidePeekMode && overlay { openPopup(task.id) } })
            .modifier(TaskRowDragDrop(id: task.id, title: task.title, active: interactive, onReorder: { ids, target, after in _ = acceptTaskReorder(ids, before: target, after: after, group: groupIDs) }))
            .contextMenu { taskMenu(task) }
    }
    /// Validates and commits an in-group task reorder. Non-None sorts are
    /// rejected without mutation and surface the sorted-mode message once per
    /// drop (callers must not toast per-frame). Cross-group drags, self-drops,
    /// and empty payloads also abort without mutating. The store re-validates
    /// records and saves once.
    func acceptTaskReorder(_ ids: [UUID], before target: UUID, after: Bool, group: [UUID]) -> Bool {
        guard !isArchivedView else { actions.notice("Archived lists are read-only."); return false }
        guard isManualSort else { actions.notice(TaskSortPolicy.reorderDisabledMessage); return false }
        guard !ids.isEmpty, !ids.contains(target),
              Set(ids).isSubset(of: Set(group)), group.contains(target) else {
            // Pinned boundary crossings explain themselves; every other
            // invalid drop stays silent as before.
            var byID: [UUID: TaskItem] = [:]
            for task in store.data.tasks { byID[task.id] = task }
            if PinnedGrouping.crossesPinnedBoundary(draggedIDs: ids, targetID: target, in: byID) {
                actions.notice("Pinned tasks reorder only within the Pinned group.")
            }
            return false
        }
        return store.reorderTasks(moving: ids, before: target, afterTarget: after)
    }

    /// Status columns for the per-list board, in fixed order. Uses the
    /// shared `BoardProjection.split` so the UI and its tests agree on the
    /// bucketing (notes always land in Open).
    func kanbanColumns(_ tasks: [TaskItem]) -> [(KanbanColumn, [TaskItem])] {
        let split = BoardProjection.split(tasks)
        return [(.open, split.open), (.completed, split.completed), (.wontDo, split.wontDo)]
    }

    /// Per-list Kanban: three status columns over the same filtered tasks.
    /// Archived lists render read-only (select only, no drag, drops refuse).
    func kanbanBoard(tasks: [TaskItem], overlay: Bool, now: Date) -> some View {
        let readOnly = isArchivedView
        let boardIDs = Set(tasks.map(\.id))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(kanbanColumns(tasks), id: \.0) { column, items in
                    kanbanColumn(column, items: items, boardIDs: boardIDs, overlay: overlay, now: now, readOnly: readOnly)
                }
            }.padding(.horizontal, 16).padding(.bottom, 24)
        }
    }

    private func kanbanColumn(_ column: KanbanColumn, items: [TaskItem], boardIDs: Set<UUID>, overlay: Bool, now: Date, readOnly: Bool) -> some View {
        KanbanColumnView(
            column: column, items: items, readOnly: readOnly,
            store: store, selection: $detailState.selection, now: now,
            onSelect: { selectTask($0) },
            onToggle: { complete($0) },
            onDrop: { ids in applyKanbanDrop(ids, to: column, boardIDs: boardIDs) }
        )
    }

    /// Commits a board drop as a status change. Drops from outside this board
    /// are ignored; notes refuse status columns with a message instead of
    /// silently doing nothing.
    func applyKanbanDrop(_ ids: [UUID], to column: KanbanColumn, boardIDs: Set<UUID>) {
        guard isBoardDestination else { return }
        guard !isArchivedView else { actions.notice("Archived lists are read-only."); return }
        for id in ids {
            guard boardIDs.contains(id),
                  let task = store.data.tasks.first(where: { $0.id == id }),
                  task.deletedAt == nil else { continue }
            switch column {
            case .open:
                if task.completedAt != nil || task.wontDoAt != nil { store.reopenTask(id: id) }
            case .completed:
                guard task.kind == .task else { actions.notice("Notes can't be completed."); continue }
                if task.completedAt == nil { actions.complete(store: store, id: id) }
            case .wontDo:
                guard task.kind == .task else { actions.notice("Notes can't be marked Won't Do."); continue }
                if task.wontDoAt == nil { store.markWontDo(id: id) }
            }
        }
    }
}

/// One Kanban status column; drops decode through the shared batch helper so
/// one malformed provider voids the whole drop, never half-applies it.
enum KanbanColumn: Hashable {
    case open, completed, wontDo
    var title: String {
        switch self { case .open: return "Open"; case .completed: return "Completed"; case .wontDo: return "Won't Do" }
    }
}

private struct KanbanColumnView: View {
    let column: KanbanColumn
    let items: [TaskItem]
    let readOnly: Bool
    @ObservedObject var store: TaskStore
    @Binding var selection: UUID?
    let now: Date
    let onSelect: (UUID) -> Void
    let onToggle: (UUID) -> Void
    let onDrop: ([UUID]) -> Void
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(column.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Text("\(items.count)").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
            }.padding(.vertical, 6)
            ForEach(items) { task in
                KanbanCard(store: store, id: task.id, selected: selection == task.id, now: now, readOnly: readOnly, onSelect: { onSelect(task.id) }, onToggle: { onToggle(task.id) })
            }
        }
        .padding(8)
        .frame(width: 250, alignment: .top)
        .background(targeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        .overlay { if targeted { RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.4), lineWidth: 1) } }
        .onDrop(of: [.taskovskyTask], delegate: KanbanColumnDropDelegate(
            enabled: !readOnly,
            onHover: { targeted = $0 },
            onDrop: onDrop
        ))
    }
}

private struct KanbanColumnDropDelegate: DropDelegate {
    let enabled: Bool
    let onHover: (Bool) -> Void
    let onDrop: ([UUID]) -> Void
    private var taskType: UTType { .taskovskyTask }

    func validateDrop(info: DropInfo) -> Bool {
        // Same type hygiene as row drops: task payloads only, never mixed
        // with list/folder/tag/smart drops; the commit handler explains
        // policy rejections with a user message.
        enabled
            && info.hasItemsConforming(to: [taskType])
            && !info.hasItemsConforming(to: [.taskovskyList])
            && !info.hasItemsConforming(to: [.taskovskySmart])
            && !info.hasItemsConforming(to: [.taskovskyFolder])
            && !info.hasItemsConforming(to: [.taskovskyTag])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        onHover(true)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { return nil }
        onHover(true)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { onHover(false) }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { onHover(false); return false }
        let providers = info.itemProviders(for: [taskType]).filter { $0.hasItemConformingToTypeIdentifier(taskType.identifier) }
        guard !providers.isEmpty else { onHover(false); return false }
        onHover(false)
        loadBatch(providers, type: taskType) { datas in
            guard let datas, let ids = DragBatch.combinedTaskIDs(from: datas) else { return }
            Task { @MainActor in onDrop(ids) }
        }
        return true
    }
}

/// Compact board card: checkbox (task status toggle), title, due line.
/// Whole-card drag reuses the row payload so board and sidebar drops agree.
private struct KanbanCard: View {
    @ObservedObject var store: TaskStore
    let id: UUID
    let selected: Bool
    let now: Date
    var readOnly = false
    let onSelect: () -> Void
    let onToggle: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var task: TaskItem { store.data.tasks.first { $0.id == id } ?? TaskItem(id: id, title: "") }
    private var finished: Bool { task.completedAt != nil || task.wontDoAt != nil }

    var body: some View {
        Group {
            if readOnly {
                cardContent.onTapGesture(perform: onSelect)
            } else {
                cardContent.onTapGesture(perform: onSelect)
                    .onDrag { DragProviders.task(TaskDragPayload(ids: [id])) } preview: {
                        CompactDragPreview(title: task.title, count: 1)
                    }
            }
        }
        .accessibilityElement(children: .combine).accessibilityLabel(task.title.isEmpty ? "Untitled" : task.title)
        .accessibilityAddTraits(.isButton).accessibilityAction { onSelect() }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                if task.kind == .note {
                    Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 16)
                } else {
                    Button(action: onToggle) { TaskCheckbox(state: task.wontDoAt != nil ? .wontDo : task.completedAt != nil ? .completed : .open, color: .secondary).frame(width: 16, height: 16).contentShape(Rectangle()) }
                        .buttonStyle(.plain).disabled(readOnly || task.deletedAt != nil)
                        .help(finished ? "Mark incomplete" : "Complete task")
                        .accessibilityLabel((finished ? "Reopen " : "Complete ") + task.title)
                }
                Text(task.title.isEmpty ? "Untitled" : task.title).font(.system(size: 13)).lineLimit(3)
                    .foregroundStyle(finished ? (colorScheme == .dark ? Color(nsColor: .tertiaryLabelColor) : Color(hex: "#A0A0A0")) : Color.primary)
            }
            HStack(spacing: 6) {
                if let due = task.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if task.isRepeating {
                    Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(.secondary).help(task.repeatLabel())
                }
            }
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.primary.opacity(0.055) : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.09), lineWidth: 1) }
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
/// for unselected rows, and a full-row hit area. Selection is a tap gesture
/// (plus keyboard activation), not a Button, so the row's drag gesture can win
/// mouse arbitration once the pointer moves: a plain Button swallows the
/// mouse-down and its `.onDrag` source never starts.
struct SidebarRow<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false
    var body: some View {
        content()
            .padding(.horizontal, 10).frame(height: 38).contentShape(Rectangle())
            .background((selected ? Color.primary.opacity(0.055) : hovering ? Color.primary.opacity(0.032) : .clear), in: RoundedRectangle(cornerRadius: 9))
            .onTapGesture(perform: action)
            .onHover { hovering = $0 }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .focusable().focusEffectDisabled()
            .onKeyPress(.return) { action(); return .handled }
            .onKeyPress(.space) { action(); return .handled }
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
    /// Task shown in this window; child/parent navigation swaps it in place.
    @State private var currentID: UUID
    init(store: TaskStore, drafts: DetailDrafts, actions: TaskActionCenter, id: UUID) {
        self.store = store; self.drafts = drafts; self.actions = actions
        _currentID = State(initialValue: id)
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if store.data.tasks.contains(where: { $0.id == currentID }) {
                TaskDetail(store: store, drafts: drafts, id: currentID, onTrash: { NotificationCenter.default.post(name: .trashTask, object: currentID); dismiss() }, onComplete: { actions.complete(store: store, id: currentID) }, onWontDo: { actions.abandon(store: store, id: currentID) }, onClose: nil, compact: true, standalonePopup: true, onRestore: { actions.restore(store: store, id: currentID) }, onPurge: { NotificationCenter.default.post(name: .requestPurge, object: currentID) }, onNavigateToTask: { currentID = $0 }).id(currentID)
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
        .onDisappear { NotificationCenter.default.post(name: .popupClosed, object: currentID) }
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
