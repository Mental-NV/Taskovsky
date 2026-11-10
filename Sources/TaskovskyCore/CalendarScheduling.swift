import Foundation

public enum CalendarScheduleOperation: Sendable {
    case move(start: Date, allDay: Bool)
    case resizeEnd(Date)
    case setRange(TaskDurationRange)
    case setPoint(date: Date, allDay: Bool)
    case unschedule
}

public enum CalendarScheduling {
    /// Prepare the exact schedule both stores persist, including reminder
    /// provenance and recurring series position. Invalid commands return nil.
    public static func prepared(_ operation: CalendarScheduleOperation, to original: TaskItem,
                                displayCalendar: Calendar, settings: AppSettings, policyCalendar: Calendar) -> TaskItem? {
        let minutes = settings.defaultDurationMinutes > 0 ? settings.defaultDurationMinutes : 30
        guard var task = applying(operation, to: original, displayCalendar: displayCalendar, defaultMinutes: minutes) else { return nil }
        guard CalendarScheduleSnapshot(task) != CalendarScheduleSnapshot(original) else { return original }
        let calendar = TaskCalendarProjection.taskCalendar(task, fallback: policyCalendar)
        let shape = TaskSchedulePolicy.coherentSchedule(dueDate: task.dueDate, hasDueTime: task.hasDueTime,
                                                        window: task.scheduledDuration, calendar: calendar)
        task.dueDate = shape.dueDate
        task.hasDueTime = shape.hasDueTime
        task.scheduledDuration = shape.window
        if TaskSchedulePolicy.usesDefaultReminder(original, settings: settings, calendar: policyCalendar) {
            task.reminderDates = original.reminderDates
            task.reminderFollowsSchedule = true
        }
        TaskSchedulePolicy.reconcileReminders(of: &task, from: original, settings: settings, calendar: policyCalendar)
        TaskSchedulePolicy.reconcileSeries(of: &task, from: original)
        return task
    }

    public static func moveOnDay(_ task: TaskItem, day: Date, forceAllDay: Bool, calendar: Calendar) -> CalendarScheduleOperation {
        if !forceAllDay, task.hasDueTime, let due = task.dueDate {
            let start = task.scheduledDuration?.start ?? due
            if calendar.isDate(start, inSameDayAs: day) { return .move(start: start, allDay: false) }
            let clock = calendar.dateComponents([.hour, .minute, .second], from: start)
            let interval = start.timeIntervalSinceReferenceDate
            let wholeSecond = calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0,
                                            second: clock.second ?? 0, of: day, matchingPolicy: .nextTime,
                                            repeatedTimePolicy: .first, direction: .forward) ?? day
            return .move(start: wholeSecond.addingTimeInterval(interval - floor(interval)), allDay: false)
        }
        return .move(start: day, allDay: true)
    }

    /// Local Calendar policy: 15-minute grid snapping, 30-minute new timed
    /// blocks unless a task already has a duration. These are independent
    /// design choices, not recovered TickTick gesture algorithms.
    /// Manual reminders move with the due date; automatic reminders are
    /// recomputed by the store. All-day dates stay in the task's civil zone.
    public static func applying(_ operation: CalendarScheduleOperation, to original: TaskItem,
                                displayCalendar: Calendar, defaultMinutes: Int = 30) -> TaskItem? {
        var task = original
        let local = TaskCalendarProjection.taskCalendar(original, fallback: displayCalendar)
        let oldWindow = original.scheduledDuration?.validated(in: local)
        let duration = Double(min(10_080, max(15, defaultMinutes))) * 60
        switch operation {
        case .unschedule:
            task.dueDate = nil; task.hasDueTime = false; task.scheduledDuration = nil; task.reminderDates = []
            task.recurrence = .none; task.customRecurrence = nil; task.recurrenceEndDate = nil
            task.recurrenceAnchorDay = nil; task.recurrenceAnchorMonth = nil
            task.recurrenceNominalDate = nil; task.occurrenceIndex = 1
            return task
        case let .move(target, allDay):
            guard target.timeIntervalSinceReferenceDate.isFinite else { return nil }
            if allDay {
                let start = CalendarDates.civilDay(target, from: displayCalendar, to: local)
                let span = oldWindow.map {
                    max(0, local.dateComponents([.day], from: local.startOfDay(for: $0.start), to: local.startOfDay(for: $0.end)).day ?? 0)
                } ?? 0
                let end = local.date(byAdding: .day, value: span, to: start) ?? start
                task.dueDate = end; task.hasDueTime = false
                task.scheduledDuration = oldWindow == nil ? nil : TaskDurationRange(start: start, end: end, isAllDay: true)
            } else if original.hasDueTime, original.dueDate != nil, oldWindow == nil {
                task.dueDate = target; task.hasDueTime = true; task.scheduledDuration = nil
            } else {
                let end: Date
                if let oldWindow, !oldWindow.isAllDay {
                    end = target.addingTimeInterval(oldWindow.end.timeIntervalSince(oldWindow.start))
                } else if let oldWindow {
                    let span = local.dateComponents([.day], from: oldWindow.start, to: oldWindow.end).day ?? 0
                    end = span > 0 ? (local.date(byAdding: .day, value: span, to: target) ?? target.addingTimeInterval(duration)) : target.addingTimeInterval(duration)
                } else { end = target.addingTimeInterval(duration) }
                task.scheduledDuration = TaskDurationRange(start: target, end: end)
                task.dueDate = end; task.hasDueTime = true
            }
        case let .setPoint(date, allDay):
            guard date.timeIntervalSinceReferenceDate.isFinite else { return nil }
            task.dueDate = allDay ? CalendarDates.civilDay(date, from: displayCalendar, to: local) : date
            task.hasDueTime = !allDay; task.scheduledDuration = nil
        case .setRange(let range):
            var range = range
            if range.isAllDay {
                range = TaskDurationRange(start: CalendarDates.civilDay(range.start, from: displayCalendar, to: local),
                                          end: CalendarDates.civilDay(range.end, from: displayCalendar, to: local), isAllDay: true)
            }
            guard let valid = range.validated(in: local) else { return nil }
            task.scheduledDuration = valid; task.dueDate = valid.end; task.hasDueTime = !valid.isAllDay
        case .resizeEnd(let target):
            guard let due = original.dueDate, target.timeIntervalSinceReferenceDate.isFinite else { return nil }
            let start = oldWindow?.start ?? due
            if oldWindow?.isAllDay ?? !original.hasDueTime {
                let end = max(local.startOfDay(for: start), CalendarDates.civilDay(target, from: displayCalendar, to: local))
                task.scheduledDuration = TaskDurationRange(start: local.startOfDay(for: start), end: end, isAllDay: true)
                task.dueDate = end; task.hasDueTime = false
            } else {
                let end = max(start.addingTimeInterval(900), target)
                task.scheduledDuration = TaskDurationRange(start: start, end: end)
                task.dueDate = end; task.hasDueTime = true
            }
        }
        if let oldDue = original.dueDate, let newDue = task.dueDate {
            if original.hasDueTime && task.hasDueTime {
                task.reminderDates = original.reminderDates.map { $0.addingTimeInterval(newDue.timeIntervalSince(oldDue)) }
            } else {
                let days = local.dateComponents([.day], from: local.startOfDay(for: oldDue), to: local.startOfDay(for: newDue)).day ?? 0
                task.reminderDates = original.reminderDates.map { local.date(byAdding: .day, value: days, to: $0) ?? $0 }
            }
        }
        return task
    }
}

/// Undo restores only scheduling fields. Text/tag/list edits survive, and a
/// later schedule/rule/status change invalidates the token instead of being
/// overwritten. The pre-move nominal and recurrence anchors restore exactly.
public struct CalendarScheduleSnapshot: Equatable, Sendable {
    public var due: Date?
    public var timed: Bool
    public var window: TaskDurationRange?
    public var reminders: [Date]
    public var follows: Bool?
    public var zone: String?
    public var rule: RepeatRule
    public var custom: CustomRecurrence?
    public var index: Int
    public var nominal: Date?
    public var anchorDay: Int?
    public var anchorMonth: Int?
    public var end: Date?
    public init(_ task: TaskItem) {
        due = task.dueDate; timed = task.hasDueTime; window = task.scheduledDuration
        reminders = task.reminderDates; follows = task.reminderFollowsSchedule; zone = task.timeZoneID
        rule = task.recurrence; custom = task.customRecurrence; index = task.occurrenceIndex
        nominal = task.recurrenceNominalDate; anchorDay = task.recurrenceAnchorDay
        anchorMonth = task.recurrenceAnchorMonth; end = task.recurrenceEndDate
    }
    public func restoring(on task: TaskItem) -> TaskItem {
        var task = task
        task.dueDate = due; task.hasDueTime = timed; task.scheduledDuration = window
        task.reminderDates = reminders; task.reminderFollowsSchedule = follows; task.timeZoneID = zone
        task.recurrence = rule; task.customRecurrence = custom; task.occurrenceIndex = index
        task.recurrenceNominalDate = nominal; task.recurrenceAnchorDay = anchorDay
        task.recurrenceAnchorMonth = anchorMonth; task.recurrenceEndDate = end
        return task
    }
}
public struct CalendarScheduleUndo: Sendable {
    public var taskID: UUID
    public var before: CalendarScheduleSnapshot
    public var after: CalendarScheduleSnapshot
    public var completedAt: Date?
    public var wontDoAt: Date?
    public init(taskID: UUID, before: CalendarScheduleSnapshot, after: CalendarScheduleSnapshot,
                completedAt: Date? = nil, wontDoAt: Date? = nil) {
        self.taskID = taskID; self.before = before; self.after = after
        self.completedAt = completedAt; self.wontDoAt = wontDoAt
    }

    public func canRestore(_ task: TaskItem, lists: [TaskList]) -> Bool {
        task.id == taskID && task.deletedAt == nil && !SmartListEligibility.isArchived(task, lists: lists) &&
            task.completedAt == completedAt && task.wontDoAt == wontDoAt && CalendarScheduleSnapshot(task) == after
    }

    public func restoring(on task: TaskItem, lists: [TaskList]) -> TaskItem? {
        guard canRestore(task, lists: lists) else { return nil }
        return before.restoring(on: task)
    }

}
