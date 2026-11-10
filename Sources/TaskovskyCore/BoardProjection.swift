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
