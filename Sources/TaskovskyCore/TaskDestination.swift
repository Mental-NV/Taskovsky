import Foundation

/// Shared destination membership. Defaults retain the macOS behavior; tests and
/// other clients supply a frozen clock and fallback calendar explicitly.
public enum TaskDestination: Hashable, Sendable {
    case all, today, tomorrow, week, inbox, notes, reminders, completed, wontDo, summary, search, trash, list(UUID), folder(UUID), tag(UUID), filter(UUID)

    public var supportsCreatedDateGrouping: Bool {
        switch self {
        case .all, .today, .tomorrow, .week, .inbox, .notes, .list, .folder, .tag, .filter: true
        case .reminders, .completed, .wontDo, .summary, .search, .trash: false
        }
    }

    public var smartKey: SmartListKey? {
        switch self {
        case .all: .all
        case .today: .today
        case .tomorrow: .tomorrow
        case .week: .week
        case .inbox: .inbox
        case .summary: .summary
        case .completed: .completed
        case .wontDo: .wontDo
        case .trash: .trash
        default: nil
        }
    }

    public init?(smartKey: SmartListKey) {
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
        case .tags, .filters: return nil
        }
    }
    public func includes(_ task: TaskItem, data: WorkspaceData, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if self == .trash { return task.deletedAt != nil }
        guard task.deletedAt == nil else { return false }
        if self == .wontDo { return task.wontDoAt != nil }
        if self == .summary {
            // Summary is a history view, but archived or opted-out lists stay
            // hidden there like in every other smart destination.
            guard !SmartListEligibility.isExcludedFromSmart(task, lists: data.lists) else { return false }
            return task.updatedAt >= calendar.date(byAdding: .day, value: -7, to: now)!
        }
        if self == .completed { return task.completedAt != nil }
        guard task.completedAt == nil && task.wontDoAt == nil else { return false }
        let cal = TaskCalendarProjection.taskCalendar(task, fallback: calendar)
        let day = cal.startOfDay(for: now)
        switch self {
        case .all, .today, .tomorrow, .week, .notes:
            guard !SmartListEligibility.isExcludedFromSmart(task, lists: data.lists) else { return false }
        case .reminders:
            guard !SmartListEligibility.isArchived(task, lists: data.lists) else { return false }
        case .inbox, .list, .folder, .tag, .completed, .trash, .wontDo, .summary, .search, .filter:
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
        case .folder(let id):
            return data.folders.contains { $0.id == id } && data.lists.contains {
                $0.id == task.listID && $0.folderID == id && !$0.isArchived
            }
        case .tag(let id):
            return SmartListEligibility.taskMatchesTag(task, tagID: id, tags: data.tags)
        case .completed, .trash, .wontDo, .summary, .search, .filter: return false
        }
    }
    /// Stored-order task membership, including the desktop history-expansion
    /// and saved-filter paths. Sorting and presentation grouping are separate.
    public func matchingTasks(in data: WorkspaceData, showHistory: Bool = true,
                              now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        data.tasks.filter { task in
            if case .filter(let id) = self {
                return data.filters.first { $0.id == id }?.matches(task, lists: data.lists, now: now, calendar: calendar) ?? false
            }
            if includes(task, data: data, now: now, calendar: calendar) { return true }
            if showHistory && self != .completed && self != .trash && self != .wontDo &&
                (task.completedAt != nil || task.wontDoAt != nil) && task.deletedAt == nil {
                var copy = task; copy.completedAt = nil; copy.wontDoAt = nil
                return includes(copy, data: data, now: now, calendar: calendar)
            }
            return false
        }
    }
}
