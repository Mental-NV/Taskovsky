import SwiftUI
import AppKit
import TaskvovskyCore

@main
struct TaskvovskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore()
    var body: some Scene {
        WindowGroup("Taskvovsky") { WorkspaceView(store: store).frame(minWidth: 1000, minHeight: 650) }
            .defaultSize(width: 1280, height: 820)
            .windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("New Task") { NotificationCenter.default.post(name: .newTask, object: nil) }.keyboardShortcut("n")
                    Button("New Note") { NotificationCenter.default.post(name: .newNote, object: nil) }.keyboardShortcut("n", modifiers: [.command, .shift])
                    Divider()
                    Button("New List") { NotificationCenter.default.post(name: .newList, object: nil) }.keyboardShortcut("l", modifiers: [.command, .shift])
                }
            }
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

enum Destination: Hashable {
    case all, today, tomorrow, week, inbox, notes, reminders, completed, trash, list(UUID), tag(UUID)
    var symbol: String {
        switch self {
        case .all: "tray.full"; case .today: "calendar"; case .tomorrow: "sun.horizon"; case .week: "calendar.badge.clock"
        case .inbox: "tray"; case .notes: "doc.text"; case .reminders: "bell"; case .completed: "checkmark.circle"
        case .trash: "trash"; case .list: "line.3.horizontal"; case .tag: "number"
        }
    }
    func title(_ data: WorkspaceData) -> String {
        switch self {
        case .all: "All Tasks"; case .today: "Today"; case .tomorrow: "Tomorrow"; case .week: "Next 7 Days"
        case .inbox: "Inbox"; case .notes: "Notes"; case .reminders: "Reminders"; case .completed: "Completed"; case .trash: "Trash"
        case .list(let id): data.lists.first { $0.id == id }?.name ?? "List"
        case .tag(let id): data.tags.first { $0.id == id }?.name ?? "Tag"
        }
    }
    func includes(_ task: TaskItem, now: Date = Date()) -> Bool {
        if self == .trash { return task.deletedAt != nil }
        guard task.deletedAt == nil else { return false }
        if self == .completed { return task.completedAt != nil }
        guard task.completedAt == nil else { return false }
        let cal = Calendar.current
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
        case .completed, .trash: return false
        }
    }
}

struct WorkspaceView: View {
    @ObservedObject var store: TaskStore
    @State private var destination: Destination = .today
    @State private var selection: UUID?
    @State private var quickTitle = ""
    @State private var quickKind: TaskKind = .task
    @State private var sort = "Date"
    @State private var showCompleted = false
    @State private var collapsed: Set<String> = []
    @State private var editor: EntityEditor?
    @State private var trashed: UUID?
    @State private var recoveryAlert = false
    @FocusState private var quickFocused: Bool

    var selectedTask: TaskItem? { store.data.tasks.first { $0.id == selection } }
    var activeList: TaskList? {
        if case .list(let id) = destination { return store.data.lists.first { $0.id == id } }; return nil
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            HStack(spacing: 0) {
                rail
                HSplitView {
                    sidebar(now: timeline.date).frame(minWidth: 190, idealWidth: 220, maxWidth: 280)
                    taskPane(now: timeline.date).frame(minWidth: 330, idealWidth: 440)
                    Group {
                        if let task = selectedTask {
                            TaskDetail(store: store, id: task.id, onTrash: { trash(task.id) }).id(task.id)
                        } else { DetailPlaceholder() }
                    }.frame(minWidth: 330, idealWidth: 450)
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
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in quickKind = .task; if destination == .trash || destination == .completed || destination == .notes { destination = .inbox }; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in destination = .notes; quickKind = .note; quickFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .newList)) { _ in editor = EntityEditor(isTag: false) }
        .onChange(of: destination) { _, _ in
            if let task = selectedTask, !destination.includes(task) { selection = nil }
            quickKind = destination == .notes || activeList?.kind == .note ? .note : .task
        }
        .onChange(of: store.data.tasks) { _, tasks in
            if let id = trashed, tasks.first(where: { $0.id == id })?.deletedAt == nil { trashed = nil }
        }
    }

    private var rail: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 25)
            ZStack { RoundedRectangle(cornerRadius: 10).fill(accent); Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundStyle(.white) }.frame(width: 34, height: 34).help("Taskvovsky")
            Divider().padding(.horizontal, 12)
            railButton("checkmark.square.fill", title: "Tasks", active: destination != .notes) { destination = .today }
            railButton("doc.text", title: "Notes", active: destination == .notes) { destination = .notes }
            Spacer()
            Image(systemName: "internaldrive").font(.system(size: 18)).foregroundStyle(.tertiary).help("Saved on this Mac")
            Spacer().frame(height: 18)
        }.frame(width: 58).background(Color(nsColor: .controlBackgroundColor))
    }
    private func railButton(_ symbol: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 22)).frame(width: 38, height: 38).foregroundStyle(active ? accent : .secondary).background(active ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    private func sidebar(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Taskvovsky").font(.system(size: 16, weight: .semibold)); Spacer() }.padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 22)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach([Destination.all, .today, .tomorrow, .week, .inbox, .notes, .reminders], id: \.self) { dest in navRow(dest, now: now) }
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
                    sectionHeading("Tags") { editor = EntityEditor(isTag: true) }.padding(.top, 20)
                    ForEach(store.data.tags) { tag in
                        navRow(.tag(tag.id), color: Color(hex: tag.color), now: now)
                            .contextMenu {
                                Button("Edit Tag…") { editor = EntityEditor(tag: tag) }
                                Button("Delete Tag", role: .destructive) { store.deleteTag(id: tag.id); if destination == .tag(tag.id) { destination = .all } }
                            }
                    }
                    Divider().padding(.vertical, 16).padding(.horizontal, 8)
                    navRow(.completed, now: now)
                    navRow(.trash, now: now)
                }.padding(.horizontal, 10)
            }
            HStack(spacing: 6) { Image(systemName: "internaldrive"); Text("On this Mac") }.font(.system(size: 11)).foregroundStyle(.tertiary).padding(20)
        }.background(Color(nsColor: .windowBackgroundColor))
    }
    private func sectionHeading(_ text: String, action: @escaping () -> Void) -> some View {
        HStack { Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary); Spacer(); Button(action: action) { Image(systemName: "plus").font(.system(size: 12)) }.buttonStyle(.plain).help("Add \(text == "Tags" ? "tag" : "list")") }.padding(.horizontal, 10).padding(.bottom, 6)
    }
    private func navRow(_ dest: Destination, color: Color? = nil, now: Date) -> some View {
        let count = store.data.tasks.filter { dest.includes($0, now: now) }.count
        return Button { destination = dest } label: {
            HStack(spacing: 11) {
                Image(systemName: dest.symbol).font(.system(size: 16)).foregroundStyle(color ?? (destination == dest ? accent : .secondary)).frame(width: 20)
                Text(dest.title(store.data)).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 2)
                if count > 0 { Text("\(count)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit() }
            }.padding(.horizontal, 10).padding(.vertical, 9).contentShape(Rectangle())
                .background(destination == dest ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 7))
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
                Text(destination.title(store.data)).font(.system(size: 24, weight: .bold)).lineLimit(1)
                Spacer()
                Menu {
                    Picker("Sort by", selection: $sort) { ForEach(["Date", "Priority", "Title", "Created"], id: \.self) { Text($0) } }
                    if destination != .completed && destination != .trash { Toggle("Show completed", isOn: $showCompleted) }
                } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 16)) }.menuStyle(.borderlessButton).fixedSize().help("Sort and display")
            }.padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 20)
            if destination == .today { Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.top, -12).padding(.bottom, 18) }
            if destination != .trash && destination != .completed {
                HStack(spacing: 10) {
                    Menu { Button("Task") { quickKind = .task }; Button("Note") { quickKind = .note } } label: { Image(systemName: quickKind == .task ? "plus" : "doc.text").font(.system(size: 16)).foregroundStyle(accent) }.menuStyle(.borderlessButton).fixedSize().help("Choose task or note")
                    TextField(quickKind == .task ? "Add a task" : "Add a note", text: $quickTitle).textFieldStyle(.plain).font(.system(size: 13)).focused($quickFocused).onSubmit(addTask)
                    if !quickTitle.isEmpty { Button(action: addTask) { Image(systemName: "arrow.up.circle.fill").foregroundStyle(accent) }.buttonStyle(.plain).help("Add") }
                }.padding(13).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 24).padding(.bottom, 20)
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
                                TaskRow(task: task, listName: store.data.lists.first { $0.id == task.listID }?.name, tags: store.data.tags.filter { task.tagIDs.contains($0.id) }, selected: selection == task.id, now: now, toggle: { store.toggleComplete(id: task.id) })
                                    .contentShape(Rectangle()).onTapGesture { selection = task.id }
                                    .draggable(task.id.uuidString)
                                    .contextMenu { taskMenu(task) }
                            } }
                        }
                    }.padding(.horizontal, 18).padding(.bottom, 24)
                }
            }
            Divider()
            HStack { Text("\(tasks.count) \(destination == .notes ? "notes" : "items")"); Spacer(); if destination != .trash && destination != .completed { Button { quickFocused = true } label: { Image(systemName: "plus") }.buttonStyle(.plain).help("New task · ⌘N") } }.font(.system(size: 11)).foregroundStyle(.tertiary).padding(.horizontal, 24).padding(.vertical, 13)
        }
    }
    @ViewBuilder private func taskMenu(_ task: TaskItem) -> some View {
        if task.deletedAt != nil { Button("Restore") { store.restoreTask(id: task.id) } }
        else {
            if task.kind == .task { Button(task.completedAt == nil ? "Complete" : "Mark incomplete") { store.toggleComplete(id: task.id) } }
            Menu("Priority") { ForEach(TaskPriority.allCases, id: \.self) { value in Button(value.label) { var t = task; t.priority = value; store.updateTask(t) } } }
            Menu("Move to") { Button("Inbox") { var t = task; t.listID = nil; store.updateTask(t) }; ForEach(store.data.lists) { list in Button(list.name) { var t = task; t.listID = list.id; store.updateTask(t) } } }
            Button("Duplicate") { selection = store.duplicateTask(id: task.id) }
            Divider(); Button("Move to Trash", role: .destructive) { trash(task.id) }
        }
    }
    private func filteredTasks(now: Date) -> [TaskItem] {
        store.data.tasks.filter { task in
            if destination.includes(task, now: now) { return true }
            if showCompleted && destination != .completed && destination != .trash && task.completedAt != nil && task.deletedAt == nil { var copy = task; copy.completedAt = nil; return destination.includes(copy, now: now) }
            return false
        }.sorted { a, b in
            if (a.completedAt == nil) != (b.completedAt == nil) { return a.completedAt == nil }
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
            return a.createdAt < b.createdAt
        }
    }
    private func grouped(_ tasks: [TaskItem], now: Date) -> [(String, [TaskItem])] {
        var keys: [String] = []; var values: [String: [TaskItem]] = [:]
        for task in tasks {
            let title: String
            if destination == .trash { title = "Deleted" }
            else if task.completedAt != nil { title = "Completed" }
            else if destination == .reminders { title = task.reminderDate! <= now ? "Due reminders" : "Upcoming reminders" }
            else if task.kind == .note { title = "Notes" }
            else if sort == "Priority" { title = task.priority.label }
            else if let due = task.dueDate {
                if due < Calendar.current.startOfDay(for: now) { title = "Overdue" }
                else if Calendar.current.isDate(due, inSameDayAs: now) { title = "Today" }
                else if Calendar.current.isDateInTomorrow(due) { title = "Tomorrow" }
                else { title = due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
            } else { title = "No Date" }
            if values[title] == nil { keys.append(title) }; values[title, default: []].append(task)
        }
        return keys.map { ($0, values[$0]!) }
    }
    private func addTask() {
        let title = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }
        let due: Date? = destination == .today || destination == .week ? Calendar.current.startOfDay(for: Date()) : destination == .tomorrow ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) : destination == .reminders ? Date().addingTimeInterval(3600) : nil
        let id = store.createTask(title: title, listID: activeList?.id, kind: quickKind, dueDate: quickKind == .task ? due : nil)
        if case .tag(let tagID) = destination, var task = store.data.tasks.first(where: { $0.id == id }) { task.tagIDs = [tagID]; store.updateTask(task) }
        if destination == .reminders, var task = store.data.tasks.first(where: { $0.id == id }) { task.reminderDate = due; task.hasDueTime = quickKind == .task; store.updateTask(task) }
        if quickKind == .note && (destination == .today || destination == .tomorrow || destination == .week || destination == .all) { destination = .notes }
        selection = id; quickTitle = ""; quickFocused = true
    }
    private func trash(_ id: UUID) { store.trashTask(id: id); trashed = id; if selection == id { selection = nil } }
}

struct TaskRow: View {
    let task: TaskItem
    let listName: String?
    let tags: [TaskTag]
    let selected: Bool
    let now: Date
    let toggle: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if task.kind == .note { Image(systemName: "doc.text").foregroundStyle(.secondary).frame(width: 18, height: 20) }
            else { Button(action: toggle) { Image(systemName: task.completedAt == nil ? "square" : "checkmark.square.fill").font(.system(size: 18, weight: .light)).foregroundStyle(task.completedAt == nil ? task.priority.color : .secondary) }.buttonStyle(.plain).disabled(task.deletedAt != nil).help(task.completedAt == nil ? "Complete task" : "Mark incomplete").accessibilityLabel(task.completedAt == nil ? "Complete \(task.title)" : "Reopen \(task.title)") }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(task.title.isEmpty ? "Untitled" : task.title).font(.system(size: 13)).strikethrough(task.completedAt != nil).foregroundStyle(task.completedAt == nil ? .primary : .secondary).lineLimit(2)
                    Spacer(minLength: 4)
                    if task.recurrence != .none { Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(.tertiary) }
                    if task.reminderDate != nil { Image(systemName: "bell").font(.system(size: 10)).foregroundStyle(task.reminderDate! <= now ? .orange : .secondary) }
                    if let due = task.dueDate { Text(dueText(due)).font(.system(size: 10)).foregroundStyle(due < Calendar.current.startOfDay(for: now) ? .red : accent).fixedSize() }
                }
                if listName != nil || !tags.isEmpty || !task.checklist.isEmpty {
                    HStack(spacing: 8) {
                        if let listName { Text(listName).lineLimit(1) }
                        ForEach(tags.prefix(2)) { tag in Text("#" + tag.name).foregroundStyle(Color(hex: tag.color)).lineLimit(1) }
                        if !task.checklist.isEmpty { Label("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)", systemImage: "checklist") }
                    }.font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }.padding(.horizontal, 12).padding(.vertical, 12).background(selected ? accent.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 1).padding(.leading, 41).padding(.trailing, 12) }
    }
    private func dueText(_ due: Date) -> String {
        let text = Calendar.current.isDate(due, inSameDayAs: now) ? "Today" : Calendar.current.isDateInTomorrow(due) ? "Tomorrow" : due.formatted(.dateTime.day().month(.abbreviated))
        return text + (task.hasDueTime ? " " + due.formatted(date: .omitted, time: .shortened) : "")
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
