import Foundation

public enum TaskScheduleValidation: Error, Equatable, Sendable {
    case changedTask, invalidDuration, invalidTimeZone, invalidRepeat
}

extension TaskSchedulePolicy {
    public static func usesDefaultReminder(_ task: TaskItem, settings: AppSettings, calendar: Calendar) -> Bool {
        if let follows = task.reminderFollowsSchedule { return follows }
        guard !task.reminderDates.isEmpty else { return true }
        guard let due = task.dueDate else { return false }
        var calendar = calendar
        if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { calendar.timeZone = zone }
        let expected = defaultReminderDates(due: due, hasTime: task.hasDueTime, settings: settings, calendar: calendar)
        return expected.count == task.reminderDates.count &&
            zip(expected, task.reminderDates).allSatisfy { abs($0.timeIntervalSince($1)) < 1 }
    }

    public static func reconcileReminders(of task: inout TaskItem, from original: TaskItem,
                                   settings: AppSettings, calendar: Calendar) {
        if task.reminderDates != original.reminderDates, task.reminderFollowsSchedule == original.reminderFollowsSchedule {
            task.reminderFollowsSchedule = false
        }
        guard task.reminderDates == original.reminderDates,
              original.dueDate != task.dueDate || original.hasDueTime != task.hasDueTime || original.timeZoneID != task.timeZoneID,
              usesDefaultReminder(original, settings: settings, calendar: calendar),
              task.reminderFollowsSchedule != false else { return }
        var calendar = calendar
        if let id = task.timeZoneID, let zone = TimeZone(identifier: id) { calendar.timeZone = zone }
        task.reminderDates = task.dueDate.map { defaultReminderDates(due: $0, hasTime: task.hasDueTime, settings: settings, calendar: calendar) } ?? []
        task.reminderFollowsSchedule = true
    }

    public static func reconcileSeries(of task: inout TaskItem, from original: TaskItem) {
        let changesSeries = task.dueDate != original.dueDate || task.hasDueTime != original.hasDueTime ||
            task.scheduledDuration != original.scheduledDuration || task.timeZoneID != original.timeZoneID ||
            task.kind != original.kind || task.recurrence != original.recurrence ||
            task.customRecurrence != original.customRecurrence || task.recurrenceEndDate != original.recurrenceEndDate
        if changesSeries { task.originalOccurrenceSchedule = nil }
        else { task.originalOccurrenceSchedule = original.originalOccurrenceSchedule }
        let series = changesSeries ? original.recurrenceSchedule : original
        if series.dueDate != task.dueDate || series.recurrence != task.recurrence {
            task.recurrenceAnchorDay = nil
            task.recurrenceAnchorMonth = nil
        }
        task.normalizeSeriesPosition(old: series)
    }
}

/// A detail edit owns only schedule fields. Calendar move and resize are
/// separate commands with different manual reminder behavior.
public struct TaskScheduleEdit: Sendable {
    public let taskID: UUID
    private let original: CalendarScheduleSnapshot
    private let baseCalendar: Calendar
    private let initiallyAutomatic: Bool
    public var hasDate: Bool
    public private(set) var schedule: ScheduleDraft
    public private(set) var zoneID: String?
    public var usesAutomaticReminders: Bool
    public var manualReminders: [Date]
    public private(set) var repeatRule: RepeatRule
    public private(set) var customRule: CustomRecurrence?
    public var repeatEnd: Date?

    public init(task: TaskItem, settings: AppSettings, calendar: Calendar, now: Date) {
        taskID = task.id
        original = CalendarScheduleSnapshot(task)
        baseCalendar = calendar
        initiallyAutomatic = TaskSchedulePolicy.usesDefaultReminder(task, settings: settings, calendar: calendar)
        usesAutomaticReminders = initiallyAutomatic
        manualReminders = task.reminderDates
        repeatRule = task.recurrence
        customRule = task.customRecurrence
        repeatEnd = task.recurrenceEndDate
        zoneID = task.timeZoneID
        hasDate = task.dueDate != nil
        schedule = ScheduleDraft(due: task.dueDate ?? calendar.startOfDay(for: now), hasTime: task.hasDueTime,
                                 duration: task.scheduledDuration, timeZoneID: task.timeZoneID ?? calendar.timeZone.identifier)
    }

    public var calendar: Calendar {
        var value = baseCalendar
        if let zoneID, let zone = TimeZone(identifier: zoneID) { value.timeZone = zone }
        return value
    }

    public var hasKnownZone: Bool { zoneID.map { TimeZone(identifier: $0) != nil } ?? true }

    public mutating func chooseDay(_ day: Date) {
        let calendar = calendar
        if calendar.isDate(day, inSameDayAs: schedule.effectiveDue) {
            hasDate = true
            return
        }
        let due = schedule.effectiveHasTime ? Self.replacingDay(of: schedule.effectiveDue, with: day, calendar: calendar) : calendar.startOfDay(for: day)
        schedule.setDue(due, calendar: calendar)
        hasDate = true
    }

    public mutating func setTime(_ enabled: Bool) {
        guard enabled != schedule.effectiveHasTime else { return }
        let calendar = calendar
        if schedule.duration != nil {
            schedule.setAllDay(!enabled, calendar: calendar)
        } else {
            let day = calendar.startOfDay(for: schedule.due)
            schedule.due = enabled ? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day : day
        }
        schedule.hasTime = enabled
    }

    public mutating func setDuration(_ enabled: Bool, defaultMinutes: Int) {
        guard enabled != (schedule.duration != nil) else { return }
        if enabled {
            if schedule.effectiveHasTime {
                schedule.enableDuration(defaultMinutes: defaultMinutes, calendar: calendar)
            } else {
                let day = calendar.startOfDay(for: schedule.due)
                schedule.setRangeEnd(day, calendar: calendar)
                schedule.duration = TaskDurationRange(start: day, end: day, isAllDay: true)
            }
        } else {
            schedule.hasTime = schedule.effectiveHasTime
            schedule.removeDuration()
        }
    }

    public mutating func setStart(_ date: Date) {
        schedule.setRangeStart(date, calendar: calendar)
    }

    public mutating func setEnd(_ date: Date) {
        schedule.setRangeEnd(date, calendar: calendar)
    }

    public mutating func setZone(_ id: String?) {
        guard id != zoneID, id.map({ TimeZone(identifier: $0) != nil }) ?? true else { return }
        let old = calendar
        zoneID = id
        let new = calendar
        guard old.timeZone != new.timeZone else { return }
        schedule.rezone(from: old.timeZone.identifier, to: new.timeZone.identifier, calendar: baseCalendar)
        if let end = repeatEnd {
            let day = old.dateComponents([.era, .year, .month, .day], from: end)
            repeatEnd = new.date(from: day) ?? end
        }
    }

    public mutating func selectSimpleRepeat(_ rule: RepeatRule) {
        guard rule != repeatRule || customRule != nil else { return }
        customRule = nil
        repeatRule = rule
        if rule == .none { repeatEnd = nil }
    }

    public mutating func selectCustomRepeat(_ rule: CustomRecurrence) {
        guard rule != customRule else { return }
        customRule = rule
        repeatRule = .none
        repeatEnd = nil
    }

    public func automaticReminders(settings: AppSettings) -> [Date] {
        TaskSchedulePolicy.defaultReminderDates(due: schedule.effectiveDue, hasTime: schedule.effectiveHasTime,
                                                settings: settings, calendar: calendar)
    }

    public func applying(to task: TaskItem, settings: AppSettings) throws -> TaskItem {
        guard task.id == taskID, CalendarScheduleSnapshot(task) == original else { throw TaskScheduleValidation.changedTask }
        if !hasDate {
            guard original.due != nil else { return task }
            var cleared = task
            cleared.dueDate = nil
            cleared.hasDueTime = false
            cleared.scheduledDuration = nil
            cleared.timeZoneID = nil
            cleared.reminderDates = []
            cleared.reminderFollowsSchedule = nil
            cleared.recurrence = .none
            cleared.customRecurrence = nil
            cleared.recurrenceEndDate = nil
            cleared.recurrenceAnchorDay = nil
            cleared.recurrenceAnchorMonth = nil
            cleared.recurrenceNominalDate = nil
            cleared.originalOccurrenceSchedule = nil
            cleared.occurrenceIndex = 1
            return cleared
        }

        let shapeChanged = schedule.effectiveDue != (original.window?.end ?? original.due) ||
            schedule.effectiveHasTime != (original.window.map { !$0.isAllDay } ?? original.timed) ||
            schedule.duration != original.window || zoneID != original.zone
        let repeatChanged = repeatRule != original.rule || customRule != original.custom || repeatEnd != original.end
        let remindersChanged = usesAutomaticReminders != initiallyAutomatic ||
            (!usesAutomaticReminders && manualReminders != original.reminders)
        guard shapeChanged || repeatChanged || remindersChanged else { return task }
        guard hasKnownZone else { throw TaskScheduleValidation.invalidTimeZone }
        guard customRule?.isValid != false else { throw TaskScheduleValidation.invalidRepeat }
        var updated = task
        if shapeChanged {
            if let range = schedule.duration {
                guard let valid = range.validated(in: calendar) else { throw TaskScheduleValidation.invalidDuration }
                updated.scheduledDuration = valid
                updated.dueDate = valid.end
            } else {
                updated.scheduledDuration = nil
                updated.dueDate = schedule.effectiveHasTime ? schedule.effectiveDue : calendar.startOfDay(for: schedule.effectiveDue)
            }
            updated.hasDueTime = schedule.effectiveHasTime
            updated.timeZoneID = zoneID
        }
        if repeatChanged {
            updated.recurrence = repeatRule
            updated.customRecurrence = customRule
            updated.recurrenceEndDate = repeatEnd
        }
        let reminderAnchorChanged = updated.dueDate != task.dueDate || updated.hasDueTime != task.hasDueTime ||
            updated.timeZoneID != task.timeZoneID
        if usesAutomaticReminders && (reminderAnchorChanged || remindersChanged), let due = updated.dueDate {
            updated.reminderDates = TaskSchedulePolicy.defaultReminderDates(due: due, hasTime: updated.hasDueTime,
                                                                           settings: settings, calendar: calendar)
            updated.reminderFollowsSchedule = true
        } else if remindersChanged {
            updated.reminderDates = manualReminders
            updated.reminderFollowsSchedule = false
        }
        TaskSchedulePolicy.reconcileSeries(of: &updated, from: task)
        return updated
    }

    private static func replacingDay(of date: Date, with day: Date, calendar: Calendar) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        var parts = calendar.dateComponents([.era, .year, .month, .day], from: day)
        parts.hour = time.hour
        parts.minute = time.minute
        parts.second = time.second
        parts.nanosecond = time.nanosecond
        return calendar.date(from: parts) ?? date
    }
}
