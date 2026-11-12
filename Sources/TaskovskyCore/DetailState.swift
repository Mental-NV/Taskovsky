import TaskovskyDomain
import Foundation

/// Day-relative classification of a due date against now, computed on
/// calendar day boundaries in the task's own time zone.
public enum DueDay: Equatable {
    case yesterday
    case today
    case tomorrow
    case past(daysOverdue: Int)
    case future
}

public enum DueLabels {
    public static func day(for due: Date, now: Date, calendar: Calendar) -> DueDay {
        let startDue = calendar.startOfDay(for: due)
        let startNow = calendar.startOfDay(for: now)
        let diff = calendar.dateComponents([.day], from: startNow, to: startDue).day ?? 0
        switch diff {
        case -1: return .yesterday
        case 0: return .today
        case 1: return .tomorrow
        case ..<(-1): return .past(daysOverdue: -diff)
        default: return .future
        }
    }

    public static func isOverdue(due: Date, now: Date, calendar: Calendar) -> Bool {
        due < calendar.startOfDay(for: now)
    }

    /// Row metadata text. A timed task due today shows only its time
    /// ("00:01"); other days show the day label with the time appended.
    /// Same-day lateness never turns the row red; only past days do.
    public static func rowLabel(for day: DueDay, dayText: String, timeText: String?) -> String {
        if day == .today, let timeText { return timeText }
        if let timeText { return dayText + " " + timeText }
        return dayText
    }

    /// Validate the schedule in the task calendar and optionally format its
    /// endpoints in the calendar that owns the visible group.
    public static func expandedRowLabel(for task: TaskItem, calendar: Calendar, displayCalendar: Calendar? = nil,
                                        dayText: (Date) -> String, timeText: (Date) -> String) -> String? {
        guard let due = task.dueDate else { return nil }
        func endpoint(_ date: Date, timed: Bool) -> String {
            timed ? dayText(date) + " " + timeText(date) : dayText(date)
        }
        guard let window = task.scheduledDuration?.validated(in: calendar) else {
            let date = displayCalendar.flatMap { TaskDueDateGroup.displayDue(for: task, calendar: $0) } ?? due
            return endpoint(date, timed: task.hasDueTime)
        }
        var start = window.start
        var end = window.end
        if window.isAllDay, let displayCalendar {
            start = CalendarDates.civilDay(start, from: calendar, to: displayCalendar)
            end = CalendarDates.civilDay(end, from: calendar, to: displayCalendar)
        }
        let first = endpoint(start, timed: !window.isAllDay)
        if start == end { return first }
        if (displayCalendar ?? calendar).isDate(start, inSameDayAs: end) {
            return window.isAllDay ? first : first + " – " + timeText(end)
        }
        return first + " – " + endpoint(end, timed: !window.isAllDay)
    }

    /// Detail header text with day-relative prefixes and overdue counts.
    public static func detailLabel(for day: DueDay, dayText: String, timedSuffix: String) -> String {
        switch day {
        case .yesterday: return "Yesterday, " + dayText + timedSuffix
        case .today: return "Today, " + dayText + timedSuffix
        case .tomorrow: return "Tomorrow, " + dayText + timedSuffix
        case .past(let days): return dayText + timedSuffix + ", \(days)d overdue"
        case .future: return dayText + timedSuffix
        }
    }
}

/// Single-slot Undo state shared by every surface (main, dock, drawer, popup,
/// search). Exactly one completion can be undone at a time; consuming or
/// expiring a claim clears it everywhere, so Undo can never apply twice.
public enum UndoKind: Equatable { case complete, wontDo, trash, restore }

public final class UndoCoordinator {
    public struct Claim: Equatable {
        public let token: UUID
        public let taskID: UUID
        public let kind: UndoKind
    }

    private var active: Claim?

    public init() {}

    @discardableResult
    public func record(taskID: UUID, kind: UndoKind) -> Claim {
        let claim = Claim(token: UUID(), taskID: taskID, kind: kind)
        active = claim
        return claim
    }

    /// Inspect without consuming; failed persistence must not lose an Undo claim.
    public func claim(token: UUID) -> Claim? {
        guard let active, active.token == token else { return nil }
        return active
    }

    /// Returns the claim only if its token is still active, clearing it.
    public func consume(token: UUID) -> Claim? {
        guard let active, active.token == token else { return nil }
        self.active = nil
        return active
    }

    public func expire(token: UUID) {
        if active?.token == token { active = nil }
    }

    public var hasActive: Bool { active != nil }
}

/// Compact overlay-drawer selection policy.
///
/// `selection` survives every transition; `drawerOpen` is transient.
/// Shrinking to overlay, navigating, or explicitly closing only dismisses the
/// drawer — the kept selection re-docks when width grows back.
public struct DetailSelectionState: Equatable {
    public var selection: UUID?
    public var drawerOpen: Bool

    public init(selection: UUID? = nil, drawerOpen: Bool = false) {
        self.selection = selection
        self.drawerOpen = drawerOpen
    }

    /// Select a task, opening the drawer only for overlay presentation.
    public mutating func select(_ id: UUID, overlay: Bool) {
        selection = id
        if overlay { drawerOpen = true }
    }

    /// Reopen the drawer for the kept selection (e.g. clicking it again).
    public mutating func reopen() {
        if selection != nil { drawerOpen = true }
    }

    public mutating func close() { drawerOpen = false }

    /// Narrowing into overlay dismisses a visible drawer but keeps the task.
    public mutating func shrinkToOverlay() { drawerOpen = false }

    /// Sidebar navigation dismisses the drawer; destination filtering decides
    /// whether the selection itself survives.
    public mutating func navigate() { drawerOpen = false }

    public mutating func clear() {
        selection = nil
        drawerOpen = false
    }
}
