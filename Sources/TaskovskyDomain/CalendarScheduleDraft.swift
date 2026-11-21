import Foundation

/// The Calendar editor's staged schedule. Existing points and precise ranges
/// retain their shape; defaults apply only to unscheduled/new tasks or an
/// explicit conversion. An unchanged editor emits no mutation at all.
public struct CalendarScheduleDraft: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var allDay: Bool
    public private(set) var hasDuration: Bool
    private var original: Shape?

    private struct Shape: Equatable, Sendable {
        var start: Date
        var end: Date
        var allDay: Bool
        var hasDuration: Bool
    }
    private var shape: Shape {
        Shape(start: start, end: hasDuration ? end : start, allDay: allDay, hasDuration: hasDuration)
    }
    public init(start: Date, end: Date, allDay: Bool) {
        self.start = start; self.end = end; self.allDay = allDay; hasDuration = true
    }
    public init(task: TaskItem, focus: Date, hourly: Bool, calendar: Calendar) {
        guard let due = task.dueDate else {
            let start = hourly ? CalendarDates.instant(on: focus, minute: 540, calendar: calendar) : calendar.startOfDay(for: focus)
            self.init(start: start, end: hourly ? start.addingTimeInterval(1_800) : start, allDay: !hourly)
            return
        }
        let local = TaskCalendarProjection.taskCalendar(task, fallback: calendar)
        let window = task.scheduledDuration?.validated(in: local)
        let allDay = window?.isAllDay ?? !task.hasDueTime
        let rawStart = window?.start ?? due, rawEnd = window?.end ?? due
        self.init(start: allDay ? CalendarDates.civilDay(rawStart, from: local, to: calendar) : rawStart,
                  end: allDay ? CalendarDates.civilDay(rawEnd, from: local, to: calendar) : rawEnd, allDay: allDay)
        hasDuration = window != nil
        original = shape
    }
    public var isValid: Bool {
        start.timeIntervalSinceReferenceDate.isFinite &&
            (!hasDuration || (end.timeIntervalSinceReferenceDate.isFinite && end >= start))
    }
    public var operation: CalendarScheduleOperation? {
        guard isValid, original != shape else { return nil }
        return hasDuration ? .setRange(TaskDurationRange(start: start, end: end, isAllDay: allDay)) : .setPoint(date: start, allDay: allDay)
    }
    public mutating func setDuration(_ enabled: Bool) {
        guard enabled != hasDuration else { return }
        if enabled { end = allDay ? start : start.addingTimeInterval(1_800) }
        else { start = end } // Turning a range into a point retains its due date.
        hasDuration = enabled
    }
    public mutating func setAllDay(_ enabled: Bool, calendar: Calendar) {
        guard enabled != allDay else { return }
        allDay = enabled
        if enabled {
            start = calendar.startOfDay(for: start)
            end = max(start, calendar.startOfDay(for: end))
        } else {
            start = CalendarDates.instant(on: start, minute: 540, calendar: calendar)
            end = hasDuration ? max(start.addingTimeInterval(1_800), CalendarDates.instant(on: end, minute: 570, calendar: calendar)) : start
        }
    }
}
