import XCTest
@testable import TaskovskyCore

final class CustomRecurrenceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1 // Sunday-start weeks, pinned for determinism
        return calendar
    }

    private var mondayFirstCalendar: Calendar {
        var calendar = calendar
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func laCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    // MARK: Anchors

    func testDueDateAnchorAddsInterval() throws {
        let rule = CustomRecurrence(anchor: .dueDate, interval: 3, unit: .days)
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 4))
    }

    func testCompletionAnchorMeasuresFromCompletion() throws {
        // Cadence date from completion, wall-clock time from the schedule.
        let rule = CustomRecurrence(anchor: .completionDate, interval: 2, unit: .days)
        let scheduled = date(2026, 11, 1)
        let completed = date(2026, 11, 5, 15, 30)
        let next = try XCTUnwrap(rule.nextOccurrence(after: scheduled, completedAt: completed, calendar: calendar))
        XCTAssertEqual(next, date(2026, 11, 7))
    }

    // MARK: Completion anchor keeps scheduled time (all units)

    func testCompletionAnchorKeepsScheduledTimeDaily() throws {
        let rule = CustomRecurrence(anchor: .completionDate, interval: 1, unit: .days)
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 11, 1), completedAt: date(2026, 11, 1, 14, 0), calendar: calendar),
            date(2026, 11, 2)
        )
    }

    func testCompletionAnchorKeepsScheduledTimeWeekly() throws {
        let rule = CustomRecurrence(anchor: .completionDate, interval: 1, unit: .weeks, weekdays: [2])
        // Due Mon Nov 2 09:00, completed 14:00 -> next Mon Nov 9 09:00.
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 11, 2), completedAt: date(2026, 11, 2, 14, 0), calendar: calendar),
            date(2026, 11, 9)
        )
    }

    func testCompletionAnchorKeepsScheduledTimeMonthly() throws {
        let rule = CustomRecurrence(anchor: .completionDate, interval: 1, unit: .months)
        // Due Nov 1 09:00, completed late Dec 20 14:00 -> Jan 1 09:00.
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 11, 1), completedAt: date(2026, 12, 20, 14, 0), calendar: calendar),
            date(2027, 1, 1)
        )
    }

    func testCompletionAnchorKeepsScheduledTimeYearly() throws {
        let rule = CustomRecurrence(anchor: .completionDate, interval: 1, unit: .years)
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 6, 15), completedAt: date(2026, 6, 15, 14, 0), calendar: calendar),
            date(2027, 6, 15)
        )
    }

    func testCompletionAnchorKeepsScheduledTimeAcrossDST() throws {
        let calendar = laCalendar()
        func la(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
        }
        let rule = CustomRecurrence(anchor: .completionDate, interval: 1, unit: .days)
        // Due Mar 7 09:00 PST, completed 14:00 -> Mar 8 09:00 PDT.
        let next = try XCTUnwrap(rule.nextOccurrence(after: la(2026, 3, 7), completedAt: la(2026, 3, 7, 14), calendar: calendar))
        XCTAssertEqual(next, la(2026, 3, 8))
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
    }

    func testCompletionAnchorFallsBackToScheduledWhenNotCompleted() throws {
        let rule = CustomRecurrence(anchor: .completionDate, interval: 1, unit: .days)
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 11, 1), completedAt: nil, calendar: calendar),
            date(2026, 11, 2)
        )
    }

    // MARK: Weekly

    func testMultiWeekWeekdaysEveryTwoWeeks() throws {
        // Mon + Wed + Fri, every 2 weeks, starting Mon Nov 2 2026.
        let rule = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .weeks, weekdays: [2, 4, 6])
        let monday = date(2026, 11, 2)
        XCTAssertEqual(rule.nextOccurrence(after: monday, calendar: calendar), date(2026, 11, 4)) // Wed same week
        let friday = date(2026, 11, 6)
        // Next interval week skips Nov 9/11/13, lands Mon Nov 16.
        XCTAssertEqual(rule.nextOccurrence(after: friday, calendar: calendar), date(2026, 11, 16))
    }

    func testWeeklySingleDay() throws {
        let rule = CustomRecurrence(unit: .weeks, weekdays: [3]) // Tuesdays
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 11, 2), calendar: calendar), // a Monday
            date(2026, 11, 3)
        )
    }

    func testBiweeklyMondayAcrossYearBoundary() throws {
        // Mon Dec 28 2026; Sunday-start weeks: Dec 27-Jan 2 is the base week.
        // Jan 4 (week Jan 3-9, distance 1) is skipped; Jan 11 (distance 2) hits.
        let rule = CustomRecurrence(interval: 2, unit: .weeks, weekdays: [2])
        let first = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 12, 28), calendar: calendar))
        XCTAssertEqual(first, date(2027, 1, 11))
        XCTAssertEqual(rule.nextOccurrence(after: first, calendar: calendar), date(2027, 1, 25))
    }

    func testWeekStartDayChangesIntervalPhase() throws {
        // Sun Jan 3 2027, biweekly Mondays. Sunday-start: Jan 3 opens the base
        // week, so Mon Jan 4 (distance 0) hits. Monday-start: Jan 3 belongs to
        // the Dec 28-Jan 3 week, so Jan 4 (distance 1) is skipped for Jan 11.
        let rule = CustomRecurrence(interval: 2, unit: .weeks, weekdays: [2])
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2027, 1, 3), calendar: calendar),
            date(2027, 1, 4)
        )
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2027, 1, 3), calendar: mondayFirstCalendar),
            date(2027, 1, 11)
        )
    }

    // MARK: End date and count

    func testInclusiveEndDateKeepsBoundaryDay() throws {
        let rule = CustomRecurrence(interval: 1, unit: .days, endDate: date(2026, 11, 3, 23, 59))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 2), calendar: calendar), date(2026, 11, 3))
        XCTAssertNil(rule.nextOccurrence(after: date(2026, 11, 3), calendar: calendar))
    }

    func testOccurrenceCountIncludesSeriesStart() throws {
        let rule = CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 2)
        XCTAssertNotNil(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar, occurrenceIndex: 1))
        XCTAssertNil(rule.nextOccurrence(after: date(2026, 11, 2), calendar: calendar, occurrenceIndex: 2))
    }

    // MARK: Monthly clamping and leap years

    func testMonthDay31ClampsShortMonthWithoutAnchor() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, monthDays: [31])
        // Jan 31 clamps to Feb 28 in non-leap 2026.
        XCTAssertEqual(
            rule.nextOccurrence(after: date(2026, 1, 31), calendar: calendar),
            date(2026, 2, 28)
        )
    }

    func testAnchorDayRetains31AcrossShortMonth() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, anchorDayOfMonth: 31)
        let feb = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 1, 31), calendar: calendar))
        XCTAssertEqual(feb, date(2026, 2, 28))
        XCTAssertEqual(rule.nextOccurrence(after: feb, calendar: calendar), date(2026, 3, 31))
    }

    func testAnnualLeapDayClampsAndReturns() throws {
        let rule = CustomRecurrence(interval: 1, unit: .years, yearMonth: 2, yearMonthDay: 29, anchorDayOfMonth: 29, anchorMonth: 2)
        let afterLeap = try XCTUnwrap(rule.nextOccurrence(after: date(2024, 2, 29), calendar: calendar))
        XCTAssertEqual(afterLeap, date(2025, 2, 28))
        let preview = rule.occurrences(from: date(2024, 2, 29), limit: 5, calendar: calendar)
        XCTAssertTrue(preview.contains(date(2028, 2, 29)), "Feb 29 must reappear in 2028, got \(preview)")
    }

    func testMultipleMonthDays() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, monthDays: [1, 15])
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 2), calendar: calendar), date(2026, 11, 15))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 15), calendar: calendar), date(2026, 12, 1))
    }

    func testMonthlyMultipleDaysFullSequence() throws {
        // Series start anchors the phase: Jan 1 -> Jan 15 -> Feb 1 -> Feb 15.
        let rule = CustomRecurrence(interval: 1, unit: .months, monthDays: [15, 1])
        let jan15 = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 1, 1), calendar: calendar))
        XCTAssertEqual(jan15, date(2026, 1, 15))
        let feb1 = try XCTUnwrap(rule.nextOccurrence(after: jan15, calendar: calendar))
        XCTAssertEqual(feb1, date(2026, 2, 1))
        XCTAssertEqual(rule.nextOccurrence(after: feb1, calendar: calendar), date(2026, 2, 15))
    }

    func testMonthlyIntervalKeepsActiveMonthPhase() throws {
        // Every 2 months: active months are Jan, Mar, May... Same-month
        // leftovers must not shift the phase.
        let rule = CustomRecurrence(interval: 2, unit: .months, monthDays: [1, 15])
        let jan15 = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 1, 1), calendar: calendar))
        XCTAssertEqual(jan15, date(2026, 1, 15))
        let mar1 = try XCTUnwrap(rule.nextOccurrence(after: jan15, calendar: calendar))
        XCTAssertEqual(mar1, date(2026, 3, 1))
        XCTAssertEqual(rule.nextOccurrence(after: mar1, calendar: calendar), date(2026, 3, 15))
    }

    func testMonthlyLastDayWithInterval() throws {
        let rule = CustomRecurrence(interval: 2, unit: .months, includesLastDayOfMonth: true)
        let mar = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 1, 31), calendar: calendar))
        XCTAssertEqual(mar, date(2026, 3, 31))
        XCTAssertEqual(rule.nextOccurrence(after: mar, calendar: calendar), date(2026, 5, 31))
    }

    func testYearlyExplicitMonthFromSeriesStart() throws {
        // Series start in January precedes this year's December occurrence.
        let rule = CustomRecurrence(interval: 1, unit: .years, yearMonth: 12, yearMonthDay: 25)
        let first = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 1, 10), calendar: calendar))
        XCTAssertEqual(first, date(2026, 12, 25))
        XCTAssertEqual(rule.nextOccurrence(after: first, calendar: calendar), date(2027, 12, 25))
    }

    func testLastDayOfMonth() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, includesLastDayOfMonth: true)
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 1, 31), calendar: calendar), date(2026, 2, 28))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 2, 28), calendar: calendar), date(2026, 3, 31))
    }

    // MARK: Ordinal and workdays

    func testMonthlySecondTuesday() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, ordinalWeekday: OrdinalWeekday(ordinal: 2, weekday: 3))
        // Nov 2026: Tuesdays are 3/10/17/24, second Tuesday is Nov 10.
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 10))
        // Next: second Tuesday of December (Dec 8).
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 10), calendar: calendar), date(2026, 12, 8))
    }

    func testMonthlyLastFriday() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, ordinalWeekday: OrdinalWeekday(ordinal: -1, weekday: 6))
        // Last Friday of Nov 2026 is Nov 27.
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 27))
    }

    func testNonexistentFifthOrdinalSkipsMonth() throws {
        // Feb 2026 has only 4 Mondays; 5th Monday must skip to Mar 30.
        let rule = CustomRecurrence(interval: 1, unit: .months, ordinalWeekday: OrdinalWeekday(ordinal: 5, weekday: 2))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 1, 15), calendar: calendar), date(2026, 3, 30))
    }

    func testFirstAndLastWorkday() throws {
        // Nov 1 2026 is a Sunday, so first workday is Mon Nov 2.
        let first = CustomRecurrence(interval: 1, unit: .months, workday: .first)
        XCTAssertEqual(first.nextOccurrence(after: date(2026, 10, 15), calendar: calendar), date(2026, 11, 2))
        // Jan 31 2026 is a Saturday, so last workday of Jan is Fri Jan 30.
        let last = CustomRecurrence(interval: 1, unit: .months, workday: .last)
        XCTAssertEqual(last.nextOccurrence(after: date(2026, 1, 1), calendar: calendar), date(2026, 1, 30))
    }

    // MARK: Specific dates

    func testSpecificDatesOutOfOrderDeduped() throws {
        let rule = CustomRecurrence(specificDates: [date(2026, 12, 25), date(2026, 11, 10), date(2026, 11, 10, 9, 0), date(2026, 12, 1)])
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 10))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 10), calendar: calendar), date(2026, 12, 1))
        XCTAssertNil(rule.nextOccurrence(after: date(2026, 12, 25), calendar: calendar))
    }

    func testSpecificDatesKeepDistinctSameDayTimesVerbatim() throws {
        // Distinct times on one day are distinct occurrences with own times.
        let rule = CustomRecurrence(specificDates: [date(2026, 11, 10, 14, 0), date(2026, 11, 10, 9, 0), date(2026, 11, 12)])
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 10, 9, 0))
        // Same-day later time is strictly after the 09:00 base instant.
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 10, 9, 0), calendar: calendar), date(2026, 11, 10, 14, 0))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 10, 14, 0), calendar: calendar), date(2026, 11, 12))
    }

    func testOccurrencesThroughIsInstantInclusive() throws {
        let rule = CustomRecurrence(specificDates: [date(2026, 11, 3, 9, 0), date(2026, 11, 3, 14, 0), date(2026, 11, 4)])
        let both = rule.occurrences(from: date(2026, 11, 1), through: date(2026, 11, 3, 14, 0), calendar: calendar)
        XCTAssertEqual(both, [date(2026, 11, 3, 9, 0), date(2026, 11, 3, 14, 0)])
        let morning = rule.occurrences(from: date(2026, 11, 1), through: date(2026, 11, 3, 9, 0), calendar: calendar)
        XCTAssertEqual(morning, [date(2026, 11, 3, 9, 0)])
    }

    func testOccurrencesStartAfterThroughIsEmpty() throws {
        let daily = CustomRecurrence(interval: 1, unit: .days)
        XCTAssertTrue(daily.occurrences(from: date(2026, 11, 5), through: date(2026, 11, 3), calendar: calendar).isEmpty)
        let explicit = CustomRecurrence(specificDates: [date(2026, 11, 10)])
        XCTAssertTrue(explicit.occurrences(from: date(2026, 11, 11), through: date(2026, 11, 12), calendar: calendar).isEmpty)
    }

    func testSpecificDateCountsOnEndDayDespiteTime() throws {
        // endDate is day-precision inclusive: a 14:00 occurrence counts on
        // its end day even though the stored end instant is midnight.
        let rule = CustomRecurrence(specificDates: [date(2026, 11, 10, 14, 0)], endDate: calendar.startOfDay(for: date(2026, 11, 10)))
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar), date(2026, 11, 10, 14, 0))
        XCTAssertEqual(rule.occurrences(from: date(2026, 11, 1), calendar: calendar), [date(2026, 11, 10, 14, 0)])
    }

    // MARK: Weekends, DST, time preservation

    func testSkipWeekendsRollsToMonday() throws {
        let rule = CustomRecurrence(interval: 1, unit: .days, skipWeekends: true)
        // Fri Nov 6 + 1 day = Sat Nov 7 -> rolls to Mon Nov 9.
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 11, 6), calendar: calendar), date(2026, 11, 9))
    }

    func testWallClockPreservedAcrossSpringForward() throws {
        let calendar = laCalendar()
        func la(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9, minute: 0))!
        }
        let rule = CustomRecurrence(interval: 1, unit: .days)
        // Spring forward Mar 8 2026 in America/Los_Angeles.
        let next = try XCTUnwrap(rule.nextOccurrence(after: la(2026, 3, 7), calendar: calendar))
        XCTAssertEqual(next, la(2026, 3, 8))
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
    }

    func testWallClockPreservedAcrossFallBack() throws {
        let calendar = laCalendar()
        func la(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9, minute: 0))!
        }
        let rule = CustomRecurrence(interval: 1, unit: .days)
        // Fall back Nov 1 2026 in America/Los_Angeles.
        let next = try XCTUnwrap(rule.nextOccurrence(after: la(2026, 10, 31), calendar: calendar))
        XCTAssertEqual(next, la(2026, 11, 1))
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
    }

    // MARK: Invalid rules

    func testInvalidRulesReturnNilWithoutHanging() throws {
        XCTAssertFalse(CustomRecurrence(interval: 0, unit: .days).isValid)
        XCTAssertNil(CustomRecurrence(interval: 0, unit: .days).nextOccurrence(after: date(2026, 11, 1), calendar: calendar))
        XCTAssertFalse(CustomRecurrence(interval: 1, unit: .weeks, weekdays: []).isValid)
        XCTAssertNil(CustomRecurrence(interval: 1, unit: .weeks, weekdays: []).nextOccurrence(after: date(2026, 11, 1), calendar: calendar))
        XCTAssertFalse(CustomRecurrence(interval: 1, unit: .weeks, weekdays: [9]).isValid)
        XCTAssertFalse(CustomRecurrence(interval: 1, unit: .months, monthDays: [32]).isValid)
        XCTAssertFalse(CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 0).isValid)
        XCTAssertNil(CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 0).nextOccurrence(after: date(2026, 11, 1), calendar: calendar))
        XCTAssertNil(CustomRecurrence(interval: 1, unit: .days).nextOccurrence(after: date(2026, 11, 1), calendar: calendar, occurrenceIndex: 0))
        XCTAssertTrue(CustomRecurrence(interval: 1, unit: .days).occurrences(from: date(2026, 11, 1), limit: 0, calendar: calendar).isEmpty)
    }

    func testEndBeforeStartYieldsNoOccurrence() throws {
        let rule = CustomRecurrence(interval: 1, unit: .days, endDate: date(2026, 10, 1))
        XCTAssertNil(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar))
    }

    // MARK: Overflow safety and practical bounds

    func testExtremeIntervalsAreRejectedWithoutTrapping() throws {
        for unit in [RecurrenceUnit.days, .weeks, .months, .years] {
            for extreme in [Int.max, Int.min, CustomRecurrence.maximumInterval + 1] {
                let rule = CustomRecurrence(interval: extreme, unit: unit, weekdays: [2])
                XCTAssertFalse(rule.isValid, "interval \(extreme) \(unit) must be invalid")
                XCTAssertNil(rule.nextOccurrence(after: date(2026, 11, 1), calendar: calendar))
                XCTAssertTrue(rule.occurrences(from: date(2026, 11, 1), limit: 5, calendar: calendar).isEmpty)
                XCTAssertFalse(rule.isOccurrence(on: date(2026, 11, 2), seriesStart: date(2026, 11, 1), calendar: calendar))
            }
        }
        XCTAssertTrue(CustomRecurrence(interval: CustomRecurrence.maximumInterval, unit: .days).isValid)
    }

    func testExtremeCountsAndLimitsAreBounded() throws {
        let hugeCount = CustomRecurrence(interval: 1, unit: .days, maxOccurrences: Int.max)
        XCTAssertTrue(hugeCount.isValid)
        XCTAssertEqual(hugeCount.occurrences(from: date(2026, 11, 1), limit: 3, calendar: calendar).count, 3)
        // Unlimited limit is capped by traversalLimit, never hangs.
        let capped = CustomRecurrence(interval: 1, unit: .days).occurrences(from: date(2026, 11, 1), limit: Int.max, calendar: calendar)
        XCTAssertEqual(capped.count, CustomRecurrence.traversalLimit)
        XCTAssertEqual(capped.first, date(2026, 11, 1))
        XCTAssertNil(CustomRecurrence(interval: 1, unit: .days).nextOccurrence(after: date(2026, 11, 1), calendar: calendar, occurrenceIndex: Int.min))
        XCTAssertTrue(CustomRecurrence(interval: 1, unit: .days).occurrences(from: date(2026, 11, 1), limit: -1, calendar: calendar).isEmpty)
    }

    // MARK: Distant membership (beyond any fixed preview)

    func testIsOccurrenceFindsMembersBeyondOldPreviewLimit() throws {
        // Every 3 days from Nov 1 2026: offsets must be multiples of 3.
        // Mar 31 2027 is offset 150 (30+31+31+28+30), Feb 2 2027 is offset 93.
        let daily = CustomRecurrence(interval: 3, unit: .days)
        let start = date(2026, 11, 1)
        XCTAssertTrue(daily.isOccurrence(on: date(2027, 3, 31), seriesStart: start, calendar: calendar))
        XCTAssertTrue(daily.isOccurrence(on: date(2027, 2, 2), seriesStart: start, calendar: calendar))
        XCTAssertFalse(daily.isOccurrence(on: date(2027, 4, 1), seriesStart: start, calendar: calendar)) // offset 151
        XCTAssertFalse(daily.isOccurrence(on: date(2026, 11, 2), seriesStart: start, calendar: calendar)) // offset 1
    }

    func testIsOccurrenceHonorsStartEndAndValidity() throws {
        let rule = CustomRecurrence(interval: 1, unit: .months, monthDays: [1], endDate: date(2038, 6, 1))
        let start = date(2026, 1, 1)
        // Month 120 (Dec 2035) is a member far beyond a 100-item preview.
        XCTAssertTrue(rule.isOccurrence(on: date(2035, 12, 1), seriesStart: start, calendar: calendar))
        XCTAssertFalse(rule.isOccurrence(on: date(2030, 6, 15), seriesStart: start, calendar: calendar))
        XCTAssertFalse(rule.isOccurrence(on: date(2025, 12, 1), seriesStart: start, calendar: calendar))
        XCTAssertFalse(rule.isOccurrence(on: date(2038, 7, 1), seriesStart: start, calendar: calendar))
        XCTAssertFalse(CustomRecurrence(interval: 0, unit: .days).isOccurrence(on: start, seriesStart: start, calendar: calendar))
    }

    // MARK: Preview

    func testOccurrencesPreviewAndIsOccurrence() throws {
        let rule = CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 3)
        let preview = rule.occurrences(from: date(2026, 11, 1), limit: 10, calendar: calendar)
        XCTAssertEqual(preview, [date(2026, 11, 1), date(2026, 11, 2), date(2026, 11, 3)])
        XCTAssertTrue(rule.isOccurrence(on: date(2026, 11, 2), seriesStart: date(2026, 11, 1), calendar: calendar))
        XCTAssertFalse(rule.isOccurrence(on: date(2026, 11, 4), seriesStart: date(2026, 11, 1), calendar: calendar))
    }

    func testOccurrencesRespectsThroughAndLimit() throws {
        let rule = CustomRecurrence(interval: 1, unit: .days)
        let preview = rule.occurrences(from: date(2026, 11, 1), through: date(2026, 11, 3), limit: 100, calendar: calendar)
        XCTAssertEqual(preview, [date(2026, 11, 1), date(2026, 11, 2), date(2026, 11, 3)])
    }

    // MARK: Codable and legacy

    func testCodableRoundTrip() throws {
        let rule = CustomRecurrence(
            anchor: .completionDate, interval: 2, unit: .weeks, weekdays: [2, 4],
            skipWeekends: true, endDate: date(2027, 1, 1), maxOccurrences: 10
        )
        let decoded = try JSONDecoder().decode(CustomRecurrence.self, from: JSONEncoder().encode(rule))
        XCTAssertEqual(decoded, rule)
    }

    func testLegacyConversion() throws {
        XCTAssertNil(CustomRecurrence(legacyRawValue: "none"))
        XCTAssertNil(CustomRecurrence(legacyRawValue: "bogus"))
        XCTAssertEqual(CustomRecurrence(legacyRawValue: "daily"), CustomRecurrence(interval: 1, unit: .days))
        let weekdays = try XCTUnwrap(CustomRecurrence(legacyRawValue: "weekdays"))
        XCTAssertTrue(weekdays.skipWeekends)
        XCTAssertEqual(CustomRecurrence(legacyRawValue: "monthly")?.legacyRawValueApproximation, "monthly")
        let custom = CustomRecurrence(interval: 2, unit: .days)
        XCTAssertNil(custom.legacyRawValueApproximation)
    }

    // MARK: Duration helper

    func testDurationRejectsEndBeforeStart() throws {
        XCTAssertNil(TaskDurationRange(start: date(2026, 11, 2), end: date(2026, 11, 1)).validated(in: calendar))
    }

    func testDurationAllDayNormalization() throws {
        let range = TaskDurationRange(start: date(2026, 11, 2, 15, 45), end: date(2026, 11, 3, 2, 10), isAllDay: true)
        let normalized = try XCTUnwrap(range.validated(in: calendar))
        XCTAssertEqual(normalized.start, calendar.startOfDay(for: date(2026, 11, 2)))
        XCTAssertEqual(normalized.end, calendar.startOfDay(for: date(2026, 11, 3)))
    }

    func testDurationMovePreservesElapsed() throws {
        let range = TaskDurationRange(start: date(2026, 11, 2, 9, 0), end: date(2026, 11, 2, 10, 30))
        let moved = range.moved(to: date(2026, 11, 9), calendar: calendar)
        XCTAssertEqual(moved.start, date(2026, 11, 9, 9, 0))
        XCTAssertEqual(moved.end, date(2026, 11, 9, 10, 30))
        XCTAssertEqual(moved.elapsed, 5400, accuracy: 0.5)
    }

    func testDurationAllDayMoveKeepsDaySpan() throws {
        let range = TaskDurationRange(
            start: calendar.startOfDay(for: date(2026, 11, 2)),
            end: calendar.startOfDay(for: date(2026, 11, 4)),
            isAllDay: true
        )
        let moved = range.moved(to: date(2026, 12, 1), calendar: calendar)
        XCTAssertEqual(moved.start, calendar.startOfDay(for: date(2026, 12, 1)))
        XCTAssertEqual(moved.end, calendar.startOfDay(for: date(2026, 12, 3)))
    }
}

