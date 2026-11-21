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

/// Outer repeat-draft policy for the Custom recurrence sheet. Opening the
/// sheet stages a seed WITHOUT touching the committed draft: only an
/// explicit Done (including intentional Clear Rule) commits. Cancel and
/// sheet dismissal drop the staged value and preserve the previous
/// complete recurrence state, both no-rule and existing simple/custom
/// rule. The ScheduleEditor routes its Custom… / Edit Custom… buttons and
/// the sheet callbacks through this so the transitions stay tested.
public struct RepeatDraft: Equatable, Sendable {
    public var repeatRule: RepeatRule
    public var customRule: CustomRecurrence?
    /// Seed captured when the sheet opens; nil while the sheet is closed
    /// and after any commit or cancel. Never read as recurrence state.
    public var stagedCustom: CustomRecurrence?

    public init(repeatRule: RepeatRule = .none, customRule: CustomRecurrence? = nil) {
        self.repeatRule = repeatRule; self.customRule = customRule; self.stagedCustom = nil
    }

    /// Opens the sheet: stages the committed rule, or the caller-supplied
    /// seed for a task with no custom rule yet. The committed draft is
    /// untouched, so Cancel/dismissal cannot leak a rule into the outer OK.
    public mutating func openCustomSheet(seed: CustomRecurrence) {
        stagedCustom = customRule ?? seed
    }

    /// Explicit Done commits a rule (a valid rule clears the legacy enum);
    /// Clear Rule commits nil and keeps the caller's legacy pick. Either
    /// way the sheet state drops.
    public mutating func commitCustom(_ rule: CustomRecurrence?) {
        customRule = rule
        if rule != nil { repeatRule = .none }
        stagedCustom = nil
    }

    /// Cancel and dismissal paths: the staged value drops and the committed
    /// draft stays exactly as it was before the sheet opened.
    public mutating func cancelCustom() {
        stagedCustom = nil
    }

    /// "Use Simple": drops the custom rule and keeps the legacy pick.
    public mutating func dropCustom() {
        customRule = nil; stagedCustom = nil
    }
}

/// Effective nominal for a recurrence preview/membership walk given staged
/// draft values and the saved task: when the staged rule differs (a rule
/// change restarts the series) or the staged due differs (a manual
/// reschedule rebases it), the staged due IS the series position —
/// mirroring the store's restart/rebase policy — otherwise the stored
/// nominal (possibly nil for legacy records). The editor passes this (not
/// the raw stored nominal) so previews agree with what saving the draft
/// and completing will actually produce.
public func stagedNominal(draftDue: Date, draftRule: CustomRecurrence?, task: TaskItem) -> Date? {
    if draftRule != task.customRecurrence { return draftDue }
    if task.dueDate.map({ $0 != draftDue }) ?? true { return draftDue }
    return task.recurrenceNominalDate
}

/// Occurrences still ahead of `current` for a custom rule: with an end count,
/// exactly the `max - index` following occurrences (index4/max5 yields just
/// the current + 1); without one, the next `extraLimit` occurrences.
/// Completion-anchored series assume on-time completion.
///
/// - Parameter nominal: the unadjusted nominal occurrence corresponding to
///   `current` (the displayed, possibly rolled due date). Monthly/yearly
///   weekend-rolling previews advance from the nominal so the preview
///   matches what completing the task will actually produce; nil previews
///   from `current` (legacy behavior for upgraded records).
public func remainingOccurrences(
    rule: CustomRecurrence,
    current: Date,
    index: Int,
    calendar: Calendar,
    extraLimit: Int = 5,
    nominal: Date? = nil
) -> [Date] {
    guard rule.isValid, index >= 1, extraLimit > 0 else { return [] }
    if let max = rule.maxOccurrences, index >= max { return [] }
    // One bounded walk for counted and uncounted previews alike, stepping
    // from the actual current display date, nominal, and index — never a
    // fresh index-1 walk from the nominal, which would reset the remaining
    // count for a rolled current occurrence. Completion anchor assumes
    // on-time completion; due-date shapes share the production stepping
    // policy (nominal chaining where needed, adjusted end check,
    // no-duplicate progress) with the store, so previews match completion
    // exactly. Each step strictly advances the displayed date (or ends the
    // series), so the loop terminates with at most `extraLimit` dates.
    var out: [Date] = []
    var cursor = current
    var cursorNominal: Date? = nominal ?? current
    var cursorIndex = index
    while out.count < extraLimit {
        if let max = rule.maxOccurrences, cursorIndex >= max { break }
        if rule.anchor == .completionDate {
            guard let next = rule.nextOccurrence(after: cursor, completedAt: cursor, calendar: calendar, occurrenceIndex: cursorIndex) else { break }
            out.append(next)
            cursor = next
        } else {
            guard let step = rule.nextDueDateStep(after: cursor, nominalBase: cursorNominal, calendar: calendar, occurrenceIndex: cursorIndex) else { break }
            out.append(step.adjusted)
            cursor = step.adjusted
            cursorNominal = step.nominal
        }
        cursorIndex += 1
    }
    return out
}

/// Separates a picker's effective display zone from the optional stored zone.
/// Merely displaying the host fallback must not make an implicit zone explicit.
public struct ScheduleZoneSelection: Equatable, Sendable {
    public var identifier: String
    private let originalIdentifier: String?
    private let initialDisplayIdentifier: String

    public init(storedIdentifier: String?, fallbackIdentifier: String) {
        originalIdentifier = storedIdentifier
        initialDisplayIdentifier = storedIdentifier ?? fallbackIdentifier
        identifier = initialDisplayIdentifier
    }

    public var storedIdentifier: String? {
        identifier == initialDisplayIdentifier ? originalIdentifier : identifier
    }
}
