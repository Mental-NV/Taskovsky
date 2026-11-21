import Foundation

/// Status-board dataset shared by the Kanban UI and its tests.
///
/// A board shows every non-deleted task in its list — all statuses — so a
/// drop into Completed/Won't Do always lands somewhere visible. The list
/// view's Show Completed toggle affects rows only, never the board: hiding
/// history must not make a completed drop vanish, and a list holding only
/// completed tasks still renders its Completed column instead of an
/// "All clear" empty state. Archived lists keep their tasks (the UI renders
/// them read-only). Notes stay in Open; terminal-column drops arriving from
/// the UI refuse them with a message.
public enum BoardProjection {
    public enum Column: String, CaseIterable, Sendable {
        case open, completed, wontDo

        public var title: String {
            switch self {
            case .open: "Open"
            case .completed: "Completed"
            case .wontDo: "Won't Do"
            }
        }
    }

    public static func column(for task: TaskItem) -> Column {
        if task.completedAt != nil { return .completed }
        if task.wontDoAt != nil { return .wontDo }
        return .open
    }

    /// Maps a change of board column to one local lifecycle transaction.
    public static func move(_ task: TaskItem, to target: Column) -> TaskLifecycleCommand? {
        let source = column(for: task)
        guard task.kind == .task, task.deletedAt == nil, source != target else { return nil }
        switch target {
        case .open: return .reopen
        case .completed: return source == .wontDo ? .completeFromWontDo : .complete
        case .wontDo: return .wontDo
        }
    }

    /// Every non-deleted task in `listID` (nil = Inbox), in stored order.
    public static func tasks(forList listID: UUID?, in data: WorkspaceData) -> [TaskItem] {
        data.tasks.filter { $0.deletedAt == nil && $0.listID == listID }
    }

    /// Each record appears exactly once according to its saved status.
    /// Notes created and edited through the app stay in Open.
    public static func split(_ tasks: [TaskItem]) -> (open: [TaskItem], completed: [TaskItem], wontDo: [TaskItem]) {
        var open: [TaskItem] = []
        var completed: [TaskItem] = []
        var wont: [TaskItem] = []
        for task in tasks {
            switch column(for: task) {
            case .open: open.append(task)
            case .completed: completed.append(task)
            case .wontDo: wont.append(task)
            }
        }
        return (open, completed, wont)
    }
}

public enum ScopedBoardGrouping: String, CaseIterable, Sendable {
    case date, list
    public var title: String { rawValue.capitalized }
}

public struct ScopedBoardColumn: Identifiable, Sendable {
    public enum ID: Hashable, Sendable {
        case date(Date), overdue, undated, list(UUID?), unavailable
    }

    public let id: ID
    public let title: String
    public let tasks: [TaskItem]
}

public struct ScopedBoardProjection: Sendable {
    public enum Move: Sendable {
        case schedule(CalendarScheduleOperation)
        case list(UUID?)
    }

    public let destination: TaskDestination
    public let grouping: ScopedBoardGrouping
    public let columns: [ScopedBoardColumn]
    private let calendar: Calendar

    public static func supports(_ destination: TaskDestination, in data: WorkspaceData) -> Bool {
        switch destination {
        case .all, .today, .tomorrow, .week, .inbox: true
        case .folder(let id): data.folders.contains { $0.id == id }
        case .tag(let id): data.tags.contains { $0.id == id }
        default: false
        }
    }

    public static func defaultGrouping(for destination: TaskDestination) -> ScopedBoardGrouping {
        destination == .week || destination == .tomorrow || destination == .inbox ? .date : .list
    }

    public init(destination: TaskDestination, grouping: ScopedBoardGrouping, in data: WorkspaceData,
                now: Date, calendar: Calendar) {
        self.destination = destination
        self.grouping = grouping
        self.calendar = calendar
        guard Self.supports(destination, in: data) else { columns = []; return }
        let tasks = destination.matchingTasks(in: data, now: now, calendar: calendar)
            .filter { !SmartListEligibility.isArchived($0, lists: data.lists) }
        switch grouping {
        case .date:
            columns = Self.dateColumns(tasks: tasks, destination: destination, now: now, calendar: calendar)
        case .list:
            columns = Self.listColumns(tasks: tasks, destination: destination, data: data)
        }
    }

    public func move(_ id: UUID, to target: ScopedBoardColumn.ID) -> Move? {
        guard columns.contains(where: { $0.id == target }),
              let source = columns.first(where: { $0.tasks.contains { $0.id == id } }),
              source.id != target, let task = source.tasks.first(where: { $0.id == id }) else { return nil }
        switch target {
        case .date(let day):
            guard task.kind == .task, task.completedAt == nil, task.wontDoAt == nil,
                  let operation = schedule(task, on: day) else { return nil }
            return .schedule(operation)
        case .list(let listID):
            return .list(listID)
        case .overdue, .undated, .unavailable:
            return nil
        }
    }

    private func schedule(_ task: TaskItem, on day: Date) -> CalendarScheduleOperation? {
        guard let due = task.dueDate else { return .setPoint(date: day, allDay: true) }
        let local = TaskCalendarProjection.taskCalendar(task, fallback: calendar)
        let duration = task.scheduledDuration?.validated(in: local)
        if !task.hasDueTime {
            let span = duration.flatMap { local.dateComponents([.day], from: local.startOfDay(for: $0.start),
                                                                 to: local.startOfDay(for: due)).day } ?? 0
            guard let start = calendar.date(byAdding: .day, value: -span, to: day) else { return nil }
            return .move(start: start, allDay: true)
        }
        var point = task
        point.scheduledDuration = nil
        guard case .move(let targetDue, _) = CalendarScheduling.moveOnDay(point, day: day, forceAllDay: false, calendar: calendar),
              calendar.isDate(targetDue, inSameDayAs: day) else { return nil }
        let length = duration.map { $0.end.timeIntervalSince($0.start) } ?? 0
        return .move(start: targetDue.addingTimeInterval(-length), allDay: false)
    }

    private static func dateColumns(tasks: [TaskItem], destination: TaskDestination, now: Date,
                                    calendar: Calendar) -> [ScopedBoardColumn] {
        typealias ID = ScopedBoardColumn.ID
        let today = calendar.startOfDay(for: now)
        let separatesOverdue = destination == .today || destination == .week
        let groups = Dictionary(grouping: tasks) { task -> ID in
            guard let due = task.dueDate else { return .undated }
            let day = task.hasDueTime ? calendar.startOfDay(for: due) :
                CalendarDates.civilDay(due, from: TaskCalendarProjection.taskCalendar(task, fallback: calendar), to: calendar)
            return separatesOverdue && day < today ? .overdue : .date(day)
        }
        var days = Set(groups.keys.compactMap { id -> Date? in
            guard case .date(let day) = id else { return nil }
            return day
        })
        if destination == .week {
            days.formUnion((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) })
        } else if destination == .tomorrow {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) { days.insert(tomorrow) }
        } else {
            days.insert(today)
        }
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated).month(.abbreviated).day()
        var columns = days.sorted().map {
            ScopedBoardColumn(id: .date($0), title: $0 == today ? "Today" : $0.formatted(style), tasks: groups[.date($0)] ?? [])
        }
        if let overdue = groups[.overdue] { columns.insert(.init(id: .overdue, title: "Overdue", tasks: overdue), at: 0) }
        if let undated = groups[.undated] { columns.append(.init(id: .undated, title: "No Date", tasks: undated)) }
        return columns
    }

    private static func listColumns(tasks: [TaskItem], destination: TaskDestination, data: WorkspaceData) -> [ScopedBoardColumn] {
        let groups = Dictionary(grouping: tasks, by: \.listID)
        let eligible = data.lists.filter { list in
            guard !list.isArchived else { return false }
            switch destination {
            case .folder(let id): return list.folderID == id
            case .all, .today, .tomorrow, .week: return list.showsInSmartLists
            case .inbox: return false
            default: return true
            }
        }
        var columns = eligible.map { ScopedBoardColumn(id: .list($0.id), title: $0.name, tasks: groups[$0.id] ?? []) }
        switch destination {
        case .folder: break
        default: columns.insert(.init(id: .list(nil), title: "Inbox", tasks: groups[nil] ?? []), at: 0)
        }
        let shown = Set(eligible.map(\.id))
        let unavailable = tasks.filter { $0.listID.map { !shown.contains($0) } ?? false }
        if !unavailable.isEmpty { columns.append(.init(id: .unavailable, title: "Unavailable List", tasks: unavailable)) }
        return columns
    }
}

/// Read-only priority partition for a scoped board. It intentionally exposes no move operation.
/// Uses existing Taskovsky priority rank, not an inferred reference-app ordering contract.
public struct PriorityBoardProjection: Sendable {
    public struct Column: Identifiable, Sendable {
        public let id: TaskPriority
        public let tasks: [TaskItem]
        public var title: String { id == .none ? "No Priority" : id.rawValue.capitalized + " Priority" }
    }
    public let columns: [Column]

    public init(destination: TaskDestination, in data: WorkspaceData, now: Date, calendar: Calendar) {
        guard ScopedBoardProjection.supports(destination, in: data) else { columns = []; return }
        let tasks = destination.matchingTasks(in: data, now: now, calendar: calendar)
            .filter { !SmartListEligibility.isArchived($0, lists: data.lists) }
        let groups = Dictionary(grouping: tasks, by: \.priority)
        columns = TaskPriority.allCases.sorted { $0.rank < $1.rank }.compactMap { priority in
            groups[priority].map { Column(id: priority, tasks: $0) }
        }
    }
}


/// Display-only mobile board lanes. These reuse Taskovsky's List grouping policies;
/// multi-tag duplication and the reference app's creation buckets are not certified.
public struct TaskMetadataBoardProjection: Sendable {
    public enum Grouping: Sendable { case createdTime, tag }
    public struct Column: Identifiable, Sendable {
        public enum ID: Hashable, Sendable { case createdDay(Date), tag(TaskOrganizationGroup.ID) }
        public let id: ID
        public let title: String
        public let tasks: [TaskItem]
    }
    public let columns: [Column]

    public init(destination: TaskDestination, grouping: Grouping, in data: WorkspaceData,
                now: Date, calendar: Calendar) {
        guard ScopedBoardProjection.supports(destination, in: data) else { columns = []; return }
        let tasks = destination.matchingTasks(in: data, now: now, calendar: calendar)
            .filter { !SmartListEligibility.isArchived($0, lists: data.lists) }
        switch grouping {
        case .createdTime:
            columns = TaskCreationDayGroup.group(tasks, calendar: calendar, sort: nil).map {
                Column(id: .createdDay($0.day), title: $0.title(calendar: calendar), tasks: $0.tasks)
            }
        case .tag:
            columns = TaskOrganizationGroup.byTag(tasks, in: data).map {
                Column(id: .tag($0.id), title: $0.title, tasks: $0.tasks)
            }
        }
    }

    /// No pin repartition: retain the board's existing incoming order for equal keys.
    public static func ordered(_ tasks: [TaskItem], title: TaskTitleSort?) -> [TaskItem] {
        guard let title else { return tasks }
        return tasks.enumerated().sorted { lhs, rhs in
            if title.precedes(lhs.element, rhs.element) { return true }
            if title.precedes(rhs.element, lhs.element) { return false }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}


/// Session presentation policies for mobile Kanban; no task mutation or schema.
public enum TaskBoardSortKind: String, CaseIterable, Sendable {
    case date, createdTime, modifiedTime, title, tag, priority
    public var title: String {
        switch self {
        case .date: "Date"
        case .createdTime: "Created Time"
        case .modifiedTime: "Modified Time"
        case .title: "Title"
        case .tag: "Tag"
        case .priority: "Priority"
        }
    }
}

public enum TaskBoardOrdering {
    public static func ordered(_ tasks: [TaskItem], kind: TaskBoardSortKind?, ascending: Bool,
                               in data: WorkspaceData, calendar: Calendar) -> [TaskItem] {
        guard let kind, kind != .tag else { return tasks }
        func precedes(_ a: TaskItem, _ b: TaskItem) -> Bool {
            switch kind {
            case .date: (ascending ? TaskMetadataSort.dateAscending : .dateDescending).precedes(a, b, in: data, calendar: calendar)
            case .createdTime: (ascending ? TaskTimestampSort.createdOldest : .createdNewest).precedes(a, b)
            case .modifiedTime: (ascending ? TaskTimestampSort.modifiedOldest : .modifiedNewest).precedes(a, b)
            case .title: (ascending ? TaskTitleSort.ascending : .descending).precedes(a, b)
            case .priority: ascending ? a.priority.rank < b.priority.rank : a.priority.rank > b.priority.rank
            case .tag: false
            }
        }
        return tasks.enumerated().sorted {
            if precedes($0.element, $1.element) { return true }
            if precedes($1.element, $0.element) { return false }
            return $0.offset < $1.offset
        }.map(\.element)
    }

    /// Real within-lane sections, not a flat tag comparator. Primary known tag
    /// and unchanged secondary row order are qualified Taskovsky policies.
    public static func tagSections(_ tasks: [TaskItem], in data: WorkspaceData, ascending: Bool) -> [TaskOrganizationGroup] {
        TaskOrganizationGroup.byTag(tasks, in: data).enumerated().sorted { a, b in
            if a.element.id == .untagged { return false }
            if b.element.id == .untagged { return true }
            let order = a.element.title.compare(b.element.title, options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: Locale(identifier: "en_US_POSIX"))
            if order == .orderedSame { return a.offset < b.offset }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }.map(\.element)
    }
}
