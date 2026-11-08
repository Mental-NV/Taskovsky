import Foundation

/// Staged scheduling values with the coherence rules the duration UI needs.
///
/// Single source of truth while the ScheduleEditor popover is open: when a
/// duration window exists, its END is the due date and its timed/all-day
/// shape decides `hasDueTime`. Grid days, shortcuts, and zone changes move
/// the whole interval (never just one endpoint); the End picker moves the
/// end (which is the due date); the Start picker moves only the start. All
/// changes stay staged here until the host applies them — nothing here
/// touches `TaskItem` or the store.
///
/// Documented policies:
/// - Timed day moves preserve the exact elapsed seconds (`start += delta`);
///   wall times are preserved day-for-day, so a DST transition may shift the
///   elapsed-vs-wall accounting by the transition delta (calendar-day shape
///   wins, matching `TaskDurationRange.moved`).
/// - All-day moves shift whole calendar days, preserving the day span across
///   DST without stretching.
/// - Timed -> all-day collapses both bounds to `startOfDay` (a partial-day
///   span becomes whole days). All-day -> timed restores 09:00 wall times on
///   the same days (end pushed to start + 1h when the span collapses).
/// - End edits never move the start; explicit elapsed changes are the point
///   of the End picker. Range validity (`end >= start`, day-normalized for
///   all-day) is left to `TaskDurationRange.validated`; mutators never trap.
public struct ScheduleDraft: Equatable, Sendable {
    /// Staged due instant. Invariant: equals `duration.end` whenever a
    /// duration window is staged (maintained by every mutator below).
    public var due: Date
    /// Staged time toggle. Ignored while a duration window is staged: timed
    /// windows imply `true`, all-day windows imply `false`.
    public var hasTime: Bool
    /// Staged duration window, or nil when duration is off.
    public var duration: TaskDurationRange?
    public var timeZoneID: String

    public init(due: Date, hasTime: Bool = false, duration: TaskDurationRange? = nil, timeZoneID: String = TimeZone.current.identifier) {
        self.due = due
        self.hasTime = hasTime
        self.duration = duration
        self.timeZoneID = timeZoneID
    }

    /// The instant reminders and recurrence previews anchor to.
    public var effectiveDue: Date { duration?.end ?? due }
    /// Timed windows and plain timed dates carry a time; all-day windows and
    /// dateless drafts do not.
    public var effectiveHasTime: Bool { duration.map { !$0.isAllDay } ?? hasTime }

    /// Grid days, shortcut buttons, and the Time row funnel through here.
    /// Same-day writes adjust only the end time (elapsed changes); new days
    /// translate the whole interval, preserving elapsed (timed) or day span
    /// (all-day). Without a duration this just sets the due instant.
    public mutating func setDue(_ new: Date, calendar: Calendar) {
        guard var window = duration else { due = new; return }
        if window.isAllDay {
            let delta = calendar.dateComponents([.day],
                from: calendar.startOfDay(for: window.end),
                to: calendar.startOfDay(for: new)).day ?? 0
            let start = calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: window.start))
                ?? calendar.startOfDay(for: window.start)
            let end = calendar.startOfDay(for: new)
            window = TaskDurationRange(start: start, end: end, isAllDay: true)
        } else if calendar.isDate(window.end, inSameDayAs: new) {
            window = TaskDurationRange(start: window.start, end: new, isAllDay: false)
        } else {
            let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: window.end)
            var parts = calendar.dateComponents([.era, .year, .month, .day], from: new)
            parts.hour = time.hour; parts.minute = time.minute
            parts.second = time.second; parts.nanosecond = time.nanosecond
            let newEnd = calendar.date(from: parts) ?? new
            let shift = newEnd.timeIntervalSince(window.end)
            window = TaskDurationRange(start: window.start.addingTimeInterval(shift), end: newEnd, isAllDay: false)
        }
        duration = window
        due = window.end
    }

    /// Start picker: moves only the start. Validity is the caller's check
    /// (`TaskDurationRange.validated`); the stored value is kept verbatim so
    /// the UI can show the invalid state with OK disabled.
    public mutating func setRangeStart(_ start: Date, calendar: Calendar) {
        guard var window = duration else { return }
        if window.isAllDay {
            window = TaskDurationRange(start: calendar.startOfDay(for: start), end: window.end, isAllDay: true)
        } else {
            window = TaskDurationRange(start: start, end: window.end, isAllDay: false)
        }
        duration = window
    }

    /// End picker: moves the end, which IS the due date.
    public mutating func setRangeEnd(_ end: Date, calendar: Calendar) {
        guard var window = duration else { due = end; return }
        if window.isAllDay {
            window = TaskDurationRange(start: window.start, end: calendar.startOfDay(for: end), isAllDay: true)
        } else {
            window = TaskDurationRange(start: window.start, end: end, isAllDay: false)
        }
        duration = window
        due = window.end
    }

    /// All-day toggle with the documented normalization. Turning duration
    /// off is `removeDuration`, not this method.
    public mutating func setAllDay(_ allDay: Bool, calendar: Calendar, defaultHour: Int = 9) {
        guard var window = duration else { return }
        if allDay {
            window = TaskDurationRange(
                start: calendar.startOfDay(for: window.start),
                end: calendar.startOfDay(for: window.end),
                isAllDay: true)
        } else {
            let startDay = calendar.startOfDay(for: window.start)
            let endDay = calendar.startOfDay(for: window.end)
            let start = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: startDay) ?? startDay
            var end = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: endDay) ?? endDay
            if end <= start { end = start.addingTimeInterval(3600) }
            window = TaskDurationRange(start: start, end: end, isAllDay: false)
        }
        duration = window
        due = window.end
    }

    /// Seeds a duration window ending at the current due instant.
    public mutating func enableDuration(defaultMinutes: Int, calendar: Calendar) {
        let minutes = max(0, defaultMinutes)
        let end = duration?.end ?? due
        let start = calendar.date(byAdding: .minute, value: -minutes, to: end) ?? end
        duration = TaskDurationRange(start: start, end: end, isAllDay: false)
        due = end
    }

    /// Removes the window, keeping the range end as a coherent due date.
    public mutating func removeDuration() {
        if let window = duration { due = window.end }
        duration = nil
    }

    /// Wall-clock-preserving zone translation of the due instant and both
    /// duration endpoints (same wall numbers, new zone).
    public mutating func rezone(from oldID: String, to newID: String, calendar: Calendar) {
        var old = calendar; old.timeZone = TimeZone(identifier: oldID) ?? .current
        var new = calendar; new.timeZone = TimeZone(identifier: newID) ?? .current
        func move(_ date: Date) -> Date {
            let parts = old.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
            return new.date(from: parts) ?? date
        }
        due = move(due)
        if let window = duration {
            duration = TaskDurationRange(start: move(window.start), end: move(window.end), isAllDay: window.isAllDay)
        }
        timeZoneID = newID
    }
}

/// Strict month-day list parse for the custom repeat editor: every
/// comma-separated token must be an integer day 1...31 — bogus tokens like
/// "bogus" invalidate the whole field (nil) instead of being silently
/// dropped. Blank/whitespace-only text means the scheduled day (valid `[]`).
public func parseMonthDayList(_ text: String) -> [Int]? {
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    var out: [Int] = []
    for token in text.split(separator: ",", omittingEmptySubsequences: false) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), (1...31).contains(value) else { return nil }
        out.append(value)
    }
    return out
}

/// Occurrences still ahead of `current` for a custom rule: with an end count,
/// exactly the `max - index` following occurrences (index4/max5 yields just
/// the current + 1); without one, the next `extraLimit` occurrences.
/// Completion-anchored series assume on-time completion.
public func remainingOccurrences(
    rule: CustomRecurrence,
    current: Date,
    index: Int,
    calendar: Calendar,
    extraLimit: Int = 5
) -> [Date] {
    guard rule.isValid, index >= 1, extraLimit > 0 else { return [] }
    if let max = rule.maxOccurrences {
        guard index < max else { return [] }
        var out: [Date] = []
        var cursor = current
        var cursorIndex = index
        while cursorIndex < max, out.count < extraLimit {
            let completedAt = rule.anchor == .completionDate ? cursor : nil
            guard let next = rule.nextOccurrence(after: cursor, completedAt: completedAt, calendar: calendar, occurrenceIndex: cursorIndex) else { break }
            out.append(next)
            cursor = next
            cursorIndex += 1
        }
        return out
    }
    return Array(rule.occurrences(from: current, limit: extraLimit + 1, calendar: calendar).dropFirst())
}
