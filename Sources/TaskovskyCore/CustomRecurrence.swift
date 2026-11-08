import Foundation

/// Standalone custom-recurrence Foundation model and engine.
///
/// Guided by the TickTick scheduling controls observed in
/// `docs/ticktick-spec/scheduling.md` (custom editor: By Due Dates /
/// By Completion Date / By Specific Dates, Every N Day|Week|Month|Year,
/// weekday pickers, Each / On the / Workday month segments, Each / On the
/// year segments, Skip Weekends, Endlessly / End by date / End by count).
///
/// This is an INDEPENDENT engine: TickTick's downstream execution (exact
/// generation, reminder shifting, holiday handling, completion semantics)
/// was not verified, so every policy below documents the choice made here.
/// Do NOT claim TickTick equivalence for this file.
///
/// Chosen policies (all documented at the relevant declaration too):
/// - Time-of-day is preserved as wall-clock time using the caller's
///   `Calendar`. DST uses `Calendar`'s default resolution (nonexistent wall
///   times shift forward, ambiguous times resolve deterministically); the
///   engine never invents its own DST workaround.
/// - Short months clamp: a day-of-month larger than the target month's
///   length lands on that month's last day (Jan 31 -> Feb 28/29). Without an
///   explicit `anchorDayOfMonth`, the clamped day becomes the new basis, so
///   Feb 28 -> Mar 28. Set `anchorDayOfMonth = 31` (and `anchorMonth` for
///   yearly series) at series creation to retain the original day across
///   short months / leap years, mirroring `TaskItem.recurrenceAnchorDay`.
/// - A 5th ordinal weekday that does not exist in a target month produces
///   no occurrence that month; the engine advances to the next interval
///   month instead of clamping to the 4th.
/// - First workday = day 1, or the following Monday when day 1 is Sat/Sun.
///   Last workday = last calendar day, or the preceding Friday when it is
///   Sat/Sun. Holidays are NOT considered (no holiday calendar input).
/// - `skipWeekends` rolls any Sat/Sun candidate forward to Monday,
///   preserving wall-clock time. The roll can push a candidate past `endDate`
///   (then there is no next occurrence).
/// - `endDate` is INCLUSIVE at day precision: a candidate whose calendar day
///   is on or before the end day is kept.
/// - `maxOccurrences` counts occurrences starting at 1 for the series start
///   (`scheduledDate` passed with `occurrenceIndex == 1`). When
///   `occurrenceIndex >= maxOccurrences`, `nextOccurrence` returns nil.
/// - Candidates are always strictly after the base instant (due date, or
///   completion date for the completion anchor), so outputs never duplicate
///   or go backward.
/// - Malformed rules (non-positive interval, interval above
///   `maximumInterval`, empty/out-of-range weekday or day selections,
///   non-positive count) are rejected: `isValid == false` and every query
///   returns nil / empty. Queries never throw, loop unboundedly, trap on
///   integer overflow, or crash; traversal is bounded (see
///   `traversalLimit` and `maximumInterval`).
/// - Specific-dates mode takes precedence when `specificDates` is non-empty:
///   cadence fields are ignored and the stored instants are returned
///   VERBATIM (each keeps its own time-of-day), sorted ascending with
///   exact-instant duplicates removed. Distinct times on the same day are
///   distinct occurrences. Comparisons against a query instant (`through`,
///   `scheduledDate`) are instant-precision; comparisons against `endDate`
///   stay day-precision inclusive (see `occurrences`).
/// - Completion-date anchor: the cadence DATE is measured from `completedAt`
///   when provided, otherwise from `scheduledDate`; the wall-clock
///   TIME-OF-DAY always comes from `scheduledDate`, uniformly for every
///   unit (daily/weekly/monthly/yearly). Series preview generation assumes
///   on-time completion (each occurrence completes at its scheduled time)
///   because future completion instants are unknowable.
/// - Initial anchor policy: the series start (`scheduledDate` with
///   `occurrenceIndex == 1`) anchors the interval phase. The first computed
///   occurrence is the first pattern date strictly after the start, even
///   inside the start's own month (monthly) or year (yearly with an explicit
///   month). Active months/years are always start-month/year + k*interval,
///   so same-month leftovers (multiple `monthDays`) never shift the phase.
///   Each later call re-anchors at the previous occurrence, which preserves
///   the phase because consecutive occurrences differ by exactly `interval`
///   periods (plus same-period leftovers, which keep the period).

// MARK: - Small composable pieces

/// What the recurrence cadence is anchored to.
public enum RecurrenceAnchor: String, Codable, CaseIterable, Equatable, Sendable {
    /// Cadence measured from the previous due date (TickTick "By Due Dates").
    case dueDate
    /// Cadence measured from the completion instant (TickTick "By Completion Date").
    case completionDate
}

/// Cadence unit for the `Every N <unit>` control.
public enum RecurrenceUnit: String, Codable, CaseIterable, Equatable, Sendable {
    case days, weeks, months, years
}

/// Nth (1...5) or last (-1) weekday of a month/year-month.
public struct OrdinalWeekday: Codable, Equatable, Sendable {
    /// 1...5 for nth, -1 for last. Any other value is malformed.
    public var ordinal: Int
    /// Calendar weekday number, Sunday == 1 ... Saturday == 7.
    public var weekday: Int

    public init(ordinal: Int, weekday: Int) {
        self.ordinal = ordinal
        self.weekday = weekday
    }

    public static let lastFriday = OrdinalWeekday(ordinal: -1, weekday: 6)

    public var isValid: Bool {
        (ordinal == -1 || (1...5).contains(ordinal)) && (1...7).contains(weekday)
    }

    private enum CodingKeys: String, CodingKey { case ordinal, weekday }

    /// Lenient: missing parts default to the first weekday, and malformed
    /// values still decode with `isValid == false` (fail-closed).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ordinal = try c.decodeIfPresent(Int.self, forKey: .ordinal) ?? 1
        weekday = try c.decodeIfPresent(Int.self, forKey: .weekday) ?? 1
    }
}

/// First / last workday (Mon-Fri) of a month.
public enum WorkdayPosition: String, Codable, CaseIterable, Equatable, Sendable {
    case first, last
}

// MARK: - Pattern

/// Independent custom-recurrence value. Safe: Codable, Equatable, Sendable,
/// no dynamic evaluation, no reference to `TaskItem` or legacy `RepeatRule`.
public struct CustomRecurrence: Codable, Equatable, Sendable {
    public typealias Pattern = CustomRecurrence

    public var anchor: RecurrenceAnchor
    /// Must be >= 1. Values <= 0 make the rule malformed (`isValid == false`).
    public var interval: Int
    public var unit: RecurrenceUnit

    /// Weekly only: selected weekday numbers (Sunday == 1 ... Saturday == 7).
    /// Empty or missing for `.weeks` is malformed.
    public var weekdays: [Int]?
    /// Monthly "Each" day numbers, 1...31. Sorted/deduped on use.
    public var monthDays: [Int]?
    /// Monthly "Each" Last Day checkbox.
    public var includesLastDayOfMonth: Bool
    /// Monthly "On the" / yearly "On the" ordinal weekday.
    public var ordinalWeekday: OrdinalWeekday?
    /// Monthly "Workday" segment. Applies to monthly cadence only.
    public var workday: WorkdayPosition?
    /// Yearly "Each"/"On the" month, 1...12. Nil means the scheduled month.
    public var yearMonth: Int?
    /// Yearly "Each" day-of-month, 1...31. Clamped for short months.
    public var yearMonthDay: Int?
    /// Original day-of-month retained across short months (e.g. 31).
    public var anchorDayOfMonth: Int?
    /// Original month retained across leap years for yearly series (1...12).
    public var anchorMonth: Int?
    /// Skip-weekends checkbox: Sat/Sun candidates roll forward to Monday.
    public var skipWeekends: Bool
    /// TickTick "By Specific Dates": explicit occurrences, returned verbatim
    /// with their stored times, sorted ascending with exact-instant
    /// duplicates removed (distinct same-day times are kept). Non-empty
    /// takes precedence over all cadence fields.
    public var specificDates: [Date]?
    /// TickTick "End by date": inclusive last day. Nil means endless.
    public var endDate: Date?
    /// TickTick "End by count": total occurrences including the series start.
    /// Must be >= 1 when set.
    public var maxOccurrences: Int?

    public init(
        anchor: RecurrenceAnchor = .dueDate,
        interval: Int = 1,
        unit: RecurrenceUnit = .days,
        weekdays: [Int]? = nil,
        monthDays: [Int]? = nil,
        includesLastDayOfMonth: Bool = false,
        ordinalWeekday: OrdinalWeekday? = nil,
        workday: WorkdayPosition? = nil,
        yearMonth: Int? = nil,
        yearMonthDay: Int? = nil,
        anchorDayOfMonth: Int? = nil,
        anchorMonth: Int? = nil,
        skipWeekends: Bool = false,
        specificDates: [Date]? = nil,
        endDate: Date? = nil,
        maxOccurrences: Int? = nil
    ) {
        self.anchor = anchor
        self.interval = interval
        self.unit = unit
        self.weekdays = weekdays
        self.monthDays = monthDays
        self.includesLastDayOfMonth = includesLastDayOfMonth
        self.ordinalWeekday = ordinalWeekday
        self.workday = workday
        self.yearMonth = yearMonth
        self.yearMonthDay = yearMonthDay
        self.anchorDayOfMonth = anchorDayOfMonth
        self.anchorMonth = anchorMonth
        self.skipWeekends = skipWeekends
        self.specificDates = specificDates
        self.endDate = endDate
        self.maxOccurrences = maxOccurrences
    }

    private enum CodingKeys: String, CodingKey {
        case anchor, interval, unit, weekdays, monthDays, includesLastDayOfMonth,
             ordinalWeekday, workday, yearMonth, yearMonthDay, anchorDayOfMonth,
             anchorMonth, skipWeekends, specificDates, endDate, maxOccurrences
    }

    /// Lenient decoding per the repo's legacy contract: missing keys fall
    /// back to the memberwise defaults, so partial rule objects (fixtures,
    /// older files) decode instead of voiding the whole workspace. Malformed
    /// values still decode and report `isValid == false` (fail-closed).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        anchor = try c.decodeIfPresent(RecurrenceAnchor.self, forKey: .anchor) ?? .dueDate
        interval = try c.decodeIfPresent(Int.self, forKey: .interval) ?? 1
        unit = try c.decodeIfPresent(RecurrenceUnit.self, forKey: .unit) ?? .days
        weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays)
        monthDays = try c.decodeIfPresent([Int].self, forKey: .monthDays)
        includesLastDayOfMonth = try c.decodeIfPresent(Bool.self, forKey: .includesLastDayOfMonth) ?? false
        ordinalWeekday = try c.decodeIfPresent(OrdinalWeekday.self, forKey: .ordinalWeekday)
        workday = try c.decodeIfPresent(WorkdayPosition.self, forKey: .workday)
        yearMonth = try c.decodeIfPresent(Int.self, forKey: .yearMonth)
        yearMonthDay = try c.decodeIfPresent(Int.self, forKey: .yearMonthDay)
        anchorDayOfMonth = try c.decodeIfPresent(Int.self, forKey: .anchorDayOfMonth)
        anchorMonth = try c.decodeIfPresent(Int.self, forKey: .anchorMonth)
        skipWeekends = try c.decodeIfPresent(Bool.self, forKey: .skipWeekends) ?? false
        specificDates = try c.decodeIfPresent([Date].self, forKey: .specificDates)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        maxOccurrences = try c.decodeIfPresent(Int.self, forKey: .maxOccurrences)
    }

    // MARK: Validation

    /// False for any malformed rule; queries on such rules return nil/empty.
    /// `isValid` matches what the engine can execute: intervals above
    /// `maximumInterval` are rejected because `interval * 7` (weekly scan
    /// bound) and `step * interval` (monthly/yearly probes) could otherwise
    /// trap on overflow for decoded extremes such as `Int.max`.
    public var isValid: Bool {
        guard interval >= 1, interval <= Self.maximumInterval else { return false }
        if let max = maxOccurrences, max < 1 { return false }
        if let days = monthDays, days.contains(where: { !(1...31).contains($0) }) { return false }
        if let m = yearMonth, !(1...12).contains(m) { return false }
        if let d = yearMonthDay, !(1...31).contains(d) { return false }
        if let a = anchorDayOfMonth, !(1...31).contains(a) { return false }
        if let a = anchorMonth, !(1...12).contains(a) { return false }
        if let o = ordinalWeekday, !o.isValid { return false }
        if let w = weekdays, w.contains(where: { !(1...7).contains($0) }) { return false }
        // Specific-dates mode needs no cadence fields; anything goes with it.
        if hasSpecificDates { return true }
        switch unit {
        case .days: return true
        case .weeks:
            guard let w = weekdays, !w.isEmpty else { return false }
            return true
        case .months:
            // Bare monthly (no selectors) falls back to the scheduled day.
            return true
        case .years:
            return true
        }
    }

    private var hasSpecificDates: Bool {
        guard let dates = specificDates else { return false }
        return !dates.isEmpty
    }

    /// Hard cap on generated candidates per query; guarantees termination.
    public static let traversalLimit = 5_000

    /// Largest supported `interval` (documented practical bound: covers
    /// multi-millennium daily cadences and century-scale weekly ones while
    /// keeping `interval * 7 + 7` and `step * interval` far from overflow).
    /// Larger decoded values make `isValid` false.
    public static let maximumInterval = 10_000

    // MARK: Legacy conversion

    /// Best-effort mapping from the legacy `RepeatRule`. Exact legacy cases
    /// only; `.none` maps to nil. Weekday/time retention follows the legacy
    /// engine (weekly = same weekday, monthly/yearly = same day via anchor).
    /// `RepeatRule` itself is NOT imported here to keep this file independent
    /// of Models.swift; pass `legacyRawValue` (e.g. `RepeatRule.daily.rawValue`).
    /// - Returns: nil for "none" or unrecognized raw values.
    public init?(legacyRawValue: String) {
        switch legacyRawValue {
        case "daily":
            self.init(anchor: .dueDate, interval: 1, unit: .days)
        case "weekdays":
            self.init(anchor: .dueDate, interval: 1, unit: .days, skipWeekends: true)
        case "weekly":
            // Weekday intentionally left unset: the integration worker fills
            // in the scheduled weekday so this stays independent of Calendar.
            self.init(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [])
        case "monthly":
            self.init(anchor: .dueDate, interval: 1, unit: .months)
        case "yearly":
            self.init(anchor: .dueDate, interval: 1, unit: .years)
        default:
            return nil
        }
    }

    /// Approximate legacy raw value for this pattern, for migration UI only.
    public var legacyRawValueApproximation: String? {
        if hasSpecificDates || anchor == .completionDate { return nil }
        if skipWeekends, unit == .days, interval == 1,
           monthDays == nil, ordinalWeekday == nil, workday == nil {
            return "weekdays"
        }
        if skipWeekends || monthDays != nil || includesLastDayOfMonth
            || ordinalWeekday != nil || workday != nil
            || yearMonth != nil || yearMonthDay != nil
            || anchorDayOfMonth != nil || anchorMonth != nil
            || endDate != nil || maxOccurrences != nil {
            // Carries data the legacy enum cannot represent... except the
            // plain cadences below, which fall through.
            if interval != 1 { return nil }
        }
        switch unit {
        case .days: return interval == 1 ? "daily" : nil
        case .weeks: return nil // weekday sets have no legacy equivalent
        case .months: return interval == 1 ? "monthly" : nil
        case .years: return interval == 1 ? "yearly" : nil
        }
    }

    // MARK: Queries

    /// Computes the next occurrence strictly after the base instant.
    ///
    /// Time policy (uniform across units): the wall-clock time-of-day always
    /// comes from `scheduledDate`. For `.completionDate`, `completedAt` only
    /// moves the cadence date; it never changes the occurrence time.
    ///
    /// - Parameters:
    ///   - scheduledDate: the previous occurrence (series start when
    ///     `occurrenceIndex == 1`). Anchors the interval phase and supplies
    ///     the wall-clock time.
    ///   - completedAt: completion instant; only used when
    ///     `anchor == .completionDate` (falls back to `scheduledDate`
    ///     when nil). The candidate is strictly after this instant.
    ///   - calendar: provides timezone, locale week data, and DST policy.
    ///   - occurrenceIndex: 1-based index of `scheduledDate` in the series;
    ///     enforces `maxOccurrences` (`nil` when already at the count, or
    ///     when the candidate passes the inclusive `endDate`). Values < 1
    ///     yield nil.
    /// - Returns: the next occurrence, or nil when the series ends or the
    ///   rule is malformed. Never duplicates or goes backward.
    public func nextOccurrence(
        after scheduledDate: Date,
        completedAt: Date? = nil,
        calendar: Calendar = .current,
        occurrenceIndex: Int = 1
    ) -> Date? {
        guard isValid else { return nil }
        guard occurrenceIndex >= 1 else { return nil }
        if let max = maxOccurrences, occurrenceIndex >= max { return nil }
        let base: Date = (anchor == .completionDate ? (completedAt ?? scheduledDate) : scheduledDate)
        let candidate: Date?
        if hasSpecificDates {
            candidate = nextSpecificDate(after: base)
        } else {
            switch unit {
            case .days:
                candidate = nextDaily(after: base, scheduledTimeFrom: scheduledDate, calendar: calendar)
            case .weeks:
                candidate = nextWeekly(after: base, scheduledTimeFrom: scheduledDate, calendar: calendar)
            case .months:
                candidate = nextMonthly(after: base, scheduledTimeFrom: scheduledDate, calendar: calendar)
            case .years:
                candidate = nextYearly(after: base, scheduledTimeFrom: scheduledDate, calendar: calendar)
            }
        }
        // The sole forward-progress invariant is against the anchor base
        // (scheduled date, or completion instant for the completion anchor):
        // candidates are built strictly after it, so outputs never duplicate
        // or go backward. For the completion anchor the candidate may
        // legitimately precede `scheduledDate` when completion came early.
        guard let next = candidate, next > base else { return nil }
        if let end = endDate,
           calendar.startOfDay(for: next) > calendar.startOfDay(for: end) {
            return nil
        }
        return next
    }

    /// Preview: the occurrences of the series starting at `start` (included
    /// as the first element when it satisfies the end/count constraints),
    /// up to `limit` items or `through`, whichever comes first.
    /// Completion-anchored series assume on-time completion.
    /// Bounded by `traversalLimit`; never hangs.
    ///
    /// Window semantics: `start` and `through` are INSTANT bounds — `through`
    /// is an inclusive upper instant, and an empty window (`start > through`)
    /// yields []. Explicit dates are returned verbatim (own stored times).
    /// `endDate` is instead an inclusive DAY-precision bound, so an explicit
    /// 14:00 occurrence still counts on its end day. For explicit lists,
    /// `maxOccurrences` caps the returned window (exact per-series count
    /// enforcement for explicit lists belongs to `nextOccurrence` via
    /// `occurrenceIndex`).
    public func occurrences(
        from start: Date,
        through: Date? = nil,
        limit: Int = 100,
        calendar: Calendar = .current
    ) -> [Date] {
        guard isValid, limit > 0 else { return [] }
        if let through, start > through { return [] }
        let capped = min(limit, Self.traversalLimit)
        var result: [Date] = []
        if hasSpecificDates {
            var kept = sortedSpecificInstants().filter { $0 >= start }
            if let through {
                kept = kept.filter { $0 <= through }
            }
            if let end = endDate {
                let endDay = calendar.startOfDay(for: end)
                kept = kept.filter { calendar.startOfDay(for: $0) <= endDay }
            }
            if let max = maxOccurrences {
                kept = Array(kept.prefix(max))
            }
            return Array(kept.prefix(capped))
        }
        var current = start
        var index = 1
        var iterations = 0
        // Include the start itself when it does not already violate end/count.
        if isWithinEnd(current, calendar: calendar) {
            result.append(current)
        }
        while result.count < capped, iterations < Self.traversalLimit {
            iterations += 1
            // Completion anchor preview: assume each occurrence completes
            // exactly at its scheduled time.
            let completedAt = anchor == .completionDate ? current : nil
            guard let next = nextOccurrence(after: current, completedAt: completedAt, calendar: calendar, occurrenceIndex: index) else { break }
            if let through, next > through { break }
            result.append(next)
            current = next
            index += 1
        }
        return result
    }

    /// True when `date` falls on the same calendar day as any occurrence of
    /// the series starting at `seriesStart` (which counts as occurrence #1).
    ///
    /// Membership is decided by walking the occurrence chain directly — never
    /// by a fixed-size preview — so distant members (e.g. day 150 of a daily
    /// series) report true. The walk is still bounded: at most
    /// `traversalLimit` chain steps, after which the answer is false
    /// (documented horizon: 5,000 occurrences — ~13 years daily, ~96 years
    /// weekly, ~416 years monthly). Completion-anchored series assume
    /// on-time completion, matching `occurrences`.
    public func isOccurrence(
        on date: Date,
        seriesStart: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isValid else { return false }
        let targetDay = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: seriesStart)
        if targetDay < startDay { return false }
        if let end = endDate, targetDay > calendar.startOfDay(for: end) { return false }
        if hasSpecificDates {
            return sortedSpecificInstants().contains { calendar.isDate($0, inSameDayAs: targetDay) }
        }
        var current = seriesStart
        var index = 1
        for _ in 0..<Self.traversalLimit {
            if calendar.isDate(current, inSameDayAs: targetDay) { return true }
            if calendar.startOfDay(for: current) > targetDay { return false }
            // Completion anchor preview: each occurrence completes exactly at
            // its scheduled time.
            let completedAt = anchor == .completionDate ? current : nil
            guard let next = nextOccurrence(after: current, completedAt: completedAt, calendar: calendar, occurrenceIndex: index) else { return false }
            current = next
            index += 1
        }
        return false
    }

    private func isWithinEnd(_ date: Date, calendar: Calendar) -> Bool {
        guard let end = endDate else { return true }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: end)
    }

    // MARK: Daily / weekly

    private func nextDaily(after base: Date, scheduledTimeFrom: Date, calendar: Calendar) -> Date? {
        // Day arithmetic on the day boundary, then the scheduled wall-clock
        // time is applied — so a completion-anchored cadence keeps the
        // scheduled time. The target day is strictly after the base day, so
        // the merged candidate is strictly after the base instant.
        let baseDay = calendar.startOfDay(for: base)
        guard let targetDay = calendar.date(byAdding: .day, value: interval, to: baseDay),
              let candidate = merge(timeOf: scheduledTimeFrom, ontoDayOf: targetDay, calendar: calendar) else { return nil }
        return rolledPastWeekend(candidate, calendar: calendar)
    }

    private func nextWeekly(after base: Date, scheduledTimeFrom: Date, calendar: Calendar) -> Date? {
        let wanted = Set(weekdays ?? [])
        guard !wanted.isEmpty else { return nil }
        // Interval weeks are anchored to the calendar week containing the
        // base (per `calendar.firstWeekday`, honoring the calendar's
        // `minimumDaysInFirstWeek` via `dateInterval`): candidates must fall
        // in a week whose distance from the base week is a multiple of
        // `interval`. Week starts are compared by day arithmetic, so years
        // with 52 or 53 weeks need no weekOfYear wraparound handling.
        guard let baseWeekStart = calendar.dateInterval(of: .weekOfYear, for: base)?.start else { return nil }
        let baseWeekDay = calendar.startOfDay(for: baseWeekStart)
        // Day-by-day scan; a match always exists within interval*7 + 7 days.
        // `interval <= maximumInterval`, so this bound cannot overflow.
        let bound = interval * 7 + 7
        for offset in 1...bound {
            guard let day = calendar.date(byAdding: .day, value: offset, to: base),
                  let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start else { return nil }
            let weekday = calendar.component(.weekday, from: day)
            guard wanted.contains(weekday) else { continue }
            let weekDistance = (calendar.dateComponents([.day], from: baseWeekDay, to: calendar.startOfDay(for: weekStart)).day ?? 0) / 7
            if weekDistance >= 0, weekDistance % interval == 0 {
                // Scheduled wall-clock time, uniform with daily/monthly/
                // yearly: completion only moves the cadence date. The day is
                // strictly after the base day, so the merged candidate is
                // strictly after the base instant.
                guard let candidate = merge(timeOf: scheduledTimeFrom, ontoDayOf: day, calendar: calendar) else { return nil }
                return rolledPastWeekend(candidate, calendar: calendar)
            }
        }
        return nil
    }

    // MARK: Monthly

    private func nextMonthly(after base: Date, scheduledTimeFrom: Date, calendar: Calendar) -> Date? {
        // Candidate months: base month + interval*k for k = 0, 1, ... bounded.
        // k = 0 covers days later in the base month itself (e.g. the 15th when
        // the base is the 2nd); the `occurrence > base` filter below skips
        // days at or before the base instant. `interval <= maximumInterval`
        // and `step <= traversalLimit`, so `step * interval` cannot overflow.
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: scheduledTimeFrom)
        for step in 0...Self.traversalLimit {
            guard let probe = calendar.date(byAdding: .month, value: step * interval, to: base) else { return nil }
            let days = monthCandidateDays(year: calendar.component(.year, from: probe),
                                          month: calendar.component(.month, from: probe),
                                          fallbackDay: anchorDayOfMonth ?? calendar.component(.day, from: scheduledTimeFrom),
                                          calendar: calendar)
            for day in days.sorted() {
                if let occurrence = occurrenceOn(day: day, probe: probe, time: time, calendar: calendar),
                   occurrence > base {
                    return rolledPastWeekend(occurrence, calendar: calendar)
                }
            }
            // A month whose selectors yield nothing (e.g. nonexistent 5th
            // ordinal) is skipped by advancing to the next interval month.
        }
        return nil
    }

    private func monthCandidateDays(year: Int, month: Int, fallbackDay: Int, calendar: Calendar) -> [Int] {
        guard let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        let length = range.count
        if ordinalWeekday != nil || workday != nil {
            if let o = ordinalWeekday, o.isValid,
               let day = ordinalWeekdayDay(year: year, month: month, rule: o, calendar: calendar) {
                return [day]
            }
            if let w = workday {
                return [workdayDay(year: year, month: month, position: w, length: length, calendar: calendar)]
            }
            return []
        }
        var days = (monthDays ?? []).filter { (1...31).contains($0) }.map { min($0, length) }
        if includesLastDayOfMonth { days.append(length) }
        if days.isEmpty { days = [min(max(fallbackDay, 1), length)] }
        return Array(Set(days))
    }

    // MARK: Yearly

    private func nextYearly(after base: Date, scheduledTimeFrom: Date, calendar: Calendar) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: scheduledTimeFrom)
        // Without an explicit yearMonth/anchorMonth the probe (base + N
        // years) already carries the scheduled month forward. Leap-day
        // retention (Feb 29) works through `anchorDayOfMonth`.
        let scheduledDay = anchorDayOfMonth ?? yearMonthDay ?? calendar.component(.day, from: scheduledTimeFrom)
        // k = 0 covers a series start that precedes this year's occurrence
        // (e.g. created in January with a December pattern); the
        // `occurrence > base` filter skips elapsed candidates.
        // `interval <= maximumInterval`, so `step * interval` cannot overflow.
        for step in 0...Self.traversalLimit {
            guard let probe = calendar.date(byAdding: .year, value: step * interval, to: base) else { return nil }
            let targetYear = calendar.component(.year, from: probe)
            let month = yearMonth ?? anchorMonth ?? calendar.component(.month, from: probe)
            let days: [Int]
            if let o = ordinalWeekday, o.isValid {
                guard let day = ordinalWeekdayDay(year: targetYear, month: month, rule: o, calendar: calendar) else { continue }
                days = [day]
            } else if let day = yearMonthDay ?? anchorDayOfMonth {
                guard let monthDate = calendar.date(from: DateComponents(year: targetYear, month: month, day: 1)),
                      let range = calendar.range(of: .day, in: .month, for: monthDate) else { continue }
                days = [min(max(day, 1), range.count)]
            } else {
                guard let monthDate = calendar.date(from: DateComponents(year: targetYear, month: month, day: 1)),
                      let range = calendar.range(of: .day, in: .month, for: monthDate) else { continue }
                days = [min(max(scheduledDay, 1), range.count)]
            }
            for day in days.sorted() {
                if let occurrence = occurrenceOn(year: targetYear, month: month, day: day, time: time, calendar: calendar),
                   occurrence > base {
                    return rolledPastWeekend(occurrence, calendar: calendar)
                }
            }
        }
        return nil
    }

    // MARK: Specific dates

    /// Explicit instants, sorted ascending with exact-instant duplicates
    /// removed. Distinct times on the same day are kept as distinct
    /// occurrences; every instant carries its own stored time and is
    /// returned verbatim by all queries.
    private func sortedSpecificInstants() -> [Date] {
        Array(Set(specificDates ?? [])).sorted()
    }

    /// First stored instant strictly after `base` (the completion instant
    /// for the completion anchor, else the scheduled date), verbatim.
    private func nextSpecificDate(after base: Date) -> Date? {
        sortedSpecificInstants().first { $0 > base }
    }

    // MARK: Shared builders

    private func occurrenceOn(day: Int, probe: Date, time: DateComponents, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month], from: probe)
        components.day = day
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        return calendar.date(from: components)
    }

    private func occurrenceOn(year: Int, month: Int, day: Int, time: DateComponents, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        return calendar.date(from: components)
    }

    private func merge(timeOf timeSource: Date, ontoDayOf day: Date, calendar: Calendar) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: timeSource)
        var components = calendar.dateComponents([.era, .year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        return calendar.date(from: components)
    }

    private func rolledPastWeekend(_ date: Date, calendar: Calendar) -> Date? {
        guard skipWeekends else { return date }
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 { return calendar.date(byAdding: .day, value: 1, to: date) } // Sunday -> Monday
        if weekday == 7 { return calendar.date(byAdding: .day, value: 2, to: date) } // Saturday -> Monday
        return date
    }

    // MARK: Display

    /// Compact human label for badges and editor summaries ("Every 2 weeks",
    /// "Monthly · 3rd Fri", "Specific dates"). Malformed rules report
    /// "Invalid rule"; specific dates always report "Specific dates".
    /// Day/month names follow `calendar` (short symbols, Sunday == 1).
    public func shortLabel(calendar: Calendar = .current) -> String {
        guard isValid else { return "Invalid rule" }
        if hasSpecificDates {
            let count = sortedSpecificInstants().count
            return count == 1 ? "1 specific date" : "\(count) specific dates"
        }
        var parts: [String] = [Self.cadenceLabel(unit: unit, interval: interval)]
        switch unit {
        case .days:
            break
        case .weeks:
            let names = (weekdays ?? []).sorted().map { Self.shortWeekdayName($0, calendar: calendar) }
            if !names.isEmpty { parts.append(names.joined(separator: ", ")) }
        case .months:
            parts.append(contentsOf: Self.monthDetail(self, calendar: calendar))
        case .years:
            if let month = yearMonth, (1...12).contains(month) {
                var name = calendar.shortMonthSymbols[month - 1]
                if let day = yearMonthDay { name += " \(day)" }
                parts.append(name)
            } else if let day = yearMonthDay {
                parts.append("day \(day)")
            }
            if let ordinal = ordinalWeekday, ordinal.isValid {
                parts.append(Self.ordinalLabel(ordinal, calendar: calendar))
            }
        }
        if skipWeekends, unit != .days { parts.append("skips weekends") }
        return parts.joined(separator: " · ")
    }

    private static func cadenceLabel(unit: RecurrenceUnit, interval: Int) -> String {
        switch unit {
        case .days: return interval == 1 ? "Daily" : "Every \(interval) days"
        case .weeks: return interval == 1 ? "Weekly" : "Every \(interval) weeks"
        case .months: return interval == 1 ? "Monthly" : "Every \(interval) months"
        case .years: return interval == 1 ? "Yearly" : "Every \(interval) years"
        }
    }

    private static func monthDetail(_ rule: CustomRecurrence, calendar: Calendar) -> [String] {
        var out: [String] = []
        let days = (rule.monthDays ?? []).filter { (1...31).contains($0) }.sorted()
        if !days.isEmpty { out.append(days.map { ordinalDay($0) }.joined(separator: ", ")) }
        if rule.includesLastDayOfMonth { out.append("last day") }
        if let ordinal = rule.ordinalWeekday, ordinal.isValid {
            out.append(ordinalLabel(ordinal, calendar: calendar))
        }
        if let workday = rule.workday {
            out.append(workday == .first ? "first workday" : "last workday")
        }
        return out
    }

    private static func shortWeekdayName(_ weekday: Int, calendar: Calendar) -> String {
        guard (1...7).contains(weekday), calendar.shortWeekdaySymbols.count == 7 else { return "day \(weekday)" }
        return calendar.shortWeekdaySymbols[weekday - 1]
    }

    private static func ordinalLabel(_ ordinal: OrdinalWeekday, calendar: Calendar) -> String {
        let day = shortWeekdayName(ordinal.weekday, calendar: calendar)
        if ordinal.ordinal == -1 { return "last \(day)" }
        return "\(ordinalDay(ordinal.ordinal)) \(day)"
    }

    private static func ordinalDay(_ day: Int) -> String {
        switch day {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(day)th"
        }
    }

    // MARK: Calendar math helpers ( leap years via Calendar ranges )

    /// Day-of-month for the nth/last `weekday` in a month, or nil when the
    /// nth occurrence does not exist (e.g. a 5th Monday in a 4-Monday month).
    func ordinalWeekdayDay(year: Int, month: Int, rule: OrdinalWeekday, calendar: Calendar) -> Int? {
        guard rule.isValid,
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first) else { return nil }
        let length = range.count
        let firstWeekday = calendar.component(.weekday, from: first)
        if rule.ordinal == -1 {
            let last = calendar.date(from: DateComponents(year: year, month: month, day: length))!
            let lastWeekday = calendar.component(.weekday, from: last)
            return length - ((lastWeekday - rule.weekday + 7) % 7)
        }
        let day = 1 + ((rule.weekday - firstWeekday + 7) % 7) + (rule.ordinal - 1) * 7
        return day <= length ? day : nil
    }

    /// Day-of-month for the first/last Mon-Fri workday.
    func workdayDay(year: Int, month: Int, position: WorkdayPosition, length: Int, calendar: Calendar) -> Int {
        switch position {
        case .first:
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 1 }
            switch calendar.component(.weekday, from: first) {
            case 1: return min(2, length) // Sunday -> Monday
            case 7: return min(3, length) // Saturday -> Monday
            default: return 1
            }
        case .last:
            guard let last = calendar.date(from: DateComponents(year: year, month: month, day: length)) else { return length }
            switch calendar.component(.weekday, from: last) {
            case 1: return max(length - 2, 1) // Sunday -> Friday
            case 7: return max(length - 1, 1) // Saturday -> Friday
            default: return length
            }
        }
    }
}

// MARK: - Duration validation helper

/// How a validated duration moves to a new occurrence day.
public enum DurationShift: String, Codable, CaseIterable, Equatable, Sendable {
    /// Keep the original wall-clock start time-of-day on the new day and
    /// preserve the exact elapsed seconds. Across a DST transition the end
    /// wall time may therefore shift by the transition delta; this is the
    /// documented choice (elapsed duration wins over end wall time).
    case wallClockPreservingElapsed
    /// Keep whole-calendar-day span for all-day durations (start/end rounded
    /// to day boundaries); timed durations behave as
    /// `wallClockPreservingElapsed`.
    case calendarDays
}

/// Minimal scheduled start/end validation. Does NOT change `TaskItem`; the
/// integration worker will add stored fields and UI separately.
public struct TaskDurationRange: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var isAllDay: Bool

    public init(start: Date, end: Date, isAllDay: Bool = false) {
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }

    /// Elapsed seconds; negative when invalid (end before start).
    public var elapsed: TimeInterval { end.timeIntervalSince(start) }

    /// Validates and normalizes using `calendar`:
    /// - Timed: requires `end >= start`, returned unchanged.
    /// - All-day: both bounds rounded DOWN to `startOfDay` (deterministic
    ///   date-only normalization); requires normalized `end >= start`.
    /// - Returns nil when invalid (end before start).
    public func validated(in calendar: Calendar = .current) -> TaskDurationRange? {
        if isAllDay {
            let s = calendar.startOfDay(for: start)
            let e = calendar.startOfDay(for: end)
            guard e >= s else { return nil }
            return TaskDurationRange(start: s, end: e, isAllDay: true)
        }
        guard end >= start else { return nil }
        return self
    }

    /// Re-anchors the range so its END lands on `date`, preserving shape:
    /// timed ranges keep exact elapsed seconds (`start = date - elapsed`);
    /// all-day ranges keep their whole-day span day-for-day. This is the
    /// recurrence/template anchoring the store uses, because the scheduling
    /// policy is `dueDate == scheduledDuration.end`: anchoring the start
    /// (as `moved(to:)` does) would strand the end away from the due date.
    /// Call on a validated range; negative elapsed yields an invalid range.
    public func anchoredEnd(at date: Date, calendar: Calendar = .current) -> TaskDurationRange {
        if isAllDay {
            let end = calendar.startOfDay(for: date)
            // The span comes from the ORIGINAL window (start to its own
            // end), never from the anchor: measuring against the new end
            // would stretch the span by the recurrence jump.
            let spanDays = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: self.end)).day ?? 0)
            let newStart = calendar.date(byAdding: .day, value: -spanDays, to: end) ?? end
            return TaskDurationRange(start: newStart, end: end, isAllDay: true)
        }
        return TaskDurationRange(start: date.addingTimeInterval(-elapsed), end: date, isAllDay: false)
    }

    /// Moves the duration to the calendar day of `date`, preserving the
    /// original wall-clock start time-of-day (timed) and the exact elapsed
    /// seconds. All-day ranges keep their whole-day span day-for-day, so
    /// DST transitions do not stretch or shrink them.
    ///
    /// NOTE: this anchors the START, so the end generally does NOT equal
    /// `date`. The store never uses it for recurrence/template anchoring
    /// (see `anchoredEnd(at:)`); it remains for wall-clock day moves.
    public func moved(to date: Date, shifting: DurationShift = .wallClockPreservingElapsed, calendar: Calendar = .current) -> TaskDurationRange {
        if isAllDay {
            let day = calendar.startOfDay(for: date)
            let spanDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
            let newEnd = calendar.date(byAdding: .day, value: spanDays, to: day) ?? day
            _ = shifting // both shifts coincide for day-normalized ranges
            return TaskDurationRange(start: day, end: newEnd, isAllDay: true)
        }
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: start)
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        let newStart = calendar.date(from: components) ?? date
        let newEnd = newStart.addingTimeInterval(elapsed)
        return TaskDurationRange(start: newStart, end: newEnd, isAllDay: false)
    }
}
