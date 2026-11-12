import XCTest
@testable import TaskovskyCore

/// ScheduleDraft coherence: the duration end IS the due date, day/time/zone
/// edits move the whole interval with the documented shape, and the custom
/// recurrence preview shows only the REMAINING count.
final class ScheduleDraftTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func timedDraft() -> ScheduleDraft {
        ScheduleDraft(
            due: date(2026, 11, 4, 10, 30),
            hasTime: true,
            duration: TaskDurationRange(start: date(2026, 11, 4, 9, 0), end: date(2026, 11, 4, 10, 30)))
    }

    func testZoneSelectionPreservesOptionalIdentityAndOpeningFallback() {
        var implicit = ScheduleZoneSelection(storedIdentifier: nil, fallbackIdentifier: "America/New_York")
        XCTAssertEqual(implicit.identifier, "America/New_York")
        XCTAssertNil(implicit.storedIdentifier)
        implicit.identifier = "Asia/Tokyo"
        XCTAssertEqual(implicit.storedIdentifier, "Asia/Tokyo")
        implicit.identifier = "America/New_York"
        XCTAssertNil(implicit.storedIdentifier)
        for identifier in ["UTC", "US/Eastern", "Europe/Moscow"] {
            var explicit = ScheduleZoneSelection(storedIdentifier: identifier, fallbackIdentifier: "Asia/Tokyo")
            XCTAssertEqual(explicit.storedIdentifier, identifier)
            explicit.identifier = "Europe/Paris"
            XCTAssertEqual(explicit.storedIdentifier, "Europe/Paris")
            explicit.identifier = identifier
            XCTAssertEqual(explicit.storedIdentifier, identifier)
        }
    }

    @MainActor func testUntouchedImplicitZoneKeepsCurrentSecondRepeatedHour() throws {
        let due = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T06:30:00Z"))
        let task = TaskItem(title: "Repeated-hour fixture", dueDate: due, hasDueTime: true,
            reminderDate: due - 600, reminderFollowsSchedule: false,
            scheduledDuration: .init(start: due - 900, end: due))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("workspace.json")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        var submitted = task
        submitted.timeZoneID = ScheduleZoneSelection(storedIdentifier: nil, fallbackIdentifier: "America/New_York").storedIdentifier
        store.updateTask(submitted)
        let saved = try XCTUnwrap(TaskStore(fileURL: url, seed: false).data.tasks.first)
        XCTAssertNil(saved.timeZoneID)
        XCTAssertEqual(saved.dueDate, due)
        XCTAssertEqual(saved.scheduledDuration, task.scheduledDuration)
        XCTAssertEqual(saved.reminderDates, task.reminderDates)
    }

    @MainActor func testUnchangedImplicitZoneSavePreservesOccurrenceAndRepeatedHour() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let due = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T06:30:00Z")) // second 01:30
        let task = TaskItem(title: "Owned recurring fixture", dueDate: due, hasDueTime: true,
            reminderDate: due - 600, recurrence: .daily, reminderFollowsSchedule: false,
            scheduledDuration: .init(start: due - 1800, end: due))
        let moved = try XCTUnwrap(CalendarScheduling.prepared(.move(start: due + 86400 - 1800, allDay: false),
            to: task, displayCalendar: local, settings: .init(), policyCalendar: local, scope: .currentOccurrence))
        XCTAssertNotNil(moved.originalOccurrenceSchedule)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("workspace.json")
        try JSONEncoder().encode(WorkspaceData(tasks: [moved])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let selection = ScheduleZoneSelection(storedIdentifier: moved.timeZoneID, fallbackIdentifier: local.timeZone.identifier)
        var submitted = moved
        submitted.timeZoneID = selection.storedIdentifier
        store.updateTask(submitted)
        let saved = try XCTUnwrap(TaskStore(fileURL: url, seed: false).data.tasks.first)
        XCTAssertNil(saved.timeZoneID)
        XCTAssertEqual(saved.originalOccurrenceSchedule, moved.originalOccurrenceSchedule)
        XCTAssertEqual(saved.dueDate, moved.dueDate)
        XCTAssertEqual(saved.scheduledDuration, moved.scheduledDuration)
        XCTAssertEqual(saved.originalOccurrenceSchedule?.due, due)
        var explicit = selection
        explicit.identifier = "Asia/Tokyo"
        submitted = saved
        submitted.timeZoneID = explicit.storedIdentifier
        store.updateTask(submitted)
        let changed = try XCTUnwrap(TaskStore(fileURL: url, seed: false).data.tasks.first)
        XCTAssertEqual(changed.timeZoneID, "Asia/Tokyo")
        XCTAssertNil(changed.originalOccurrenceSchedule)
    }

    // MARK: - Effective values

    func testEffectiveDueAndHasTime() {
        var draft = timedDraft()
        XCTAssertEqual(draft.effectiveDue, date(2026, 11, 4, 10, 30))
        XCTAssertTrue(draft.effectiveHasTime)
        draft.duration?.isAllDay = true
        XCTAssertFalse(draft.effectiveHasTime)
        draft.duration = nil
        XCTAssertEqual(draft.effectiveDue, draft.due)
        XCTAssertTrue(draft.effectiveHasTime)
    }

    // MARK: - setDue day/time routing

    func testSetDueNewDayTranslatesTimedPreservingElapsed() {
        var draft = timedDraft()
        draft.setDue(date(2026, 11, 6, 0, 0), calendar: calendar) // grid day, time ignored
        XCTAssertEqual(draft.duration?.end, date(2026, 11, 6, 10, 30))
        XCTAssertEqual(draft.duration?.start, date(2026, 11, 6, 9, 0))
        XCTAssertEqual(draft.due, date(2026, 11, 6, 10, 30))
        XCTAssertEqual(draft.duration?.elapsed ?? -1, 5400, accuracy: 0.5)
    }

    func testSetDueSameDayAdjustsOnlyEndTime() {
        var draft = timedDraft()
        draft.setDue(date(2026, 11, 4, 12, 0), calendar: calendar)
        XCTAssertEqual(draft.duration?.end, date(2026, 11, 4, 12, 0))
        XCTAssertEqual(draft.duration?.start, date(2026, 11, 4, 9, 0))
        XCTAssertEqual(draft.due, date(2026, 11, 4, 12, 0))
    }

    func testSetDueAllDayPreservesDaySpan() {
        func midnight(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.startOfDay(for: date(y, m, d))
        }
        var draft = ScheduleDraft(
            due: midnight(2026, 11, 4),
            duration: TaskDurationRange(start: midnight(2026, 11, 2), end: midnight(2026, 11, 4), isAllDay: true))
        draft.setDue(date(2026, 11, 10), calendar: calendar)
        XCTAssertEqual(draft.duration?.start, midnight(2026, 11, 8))
        XCTAssertEqual(draft.duration?.end, midnight(2026, 11, 10))
        XCTAssertEqual(draft.due, midnight(2026, 11, 10))
    }

    func testSetDueWithoutDurationSetsDue() {
        var draft = ScheduleDraft(due: date(2026, 11, 4), hasTime: true)
        draft.setDue(date(2026, 11, 6, 18, 0), calendar: calendar)
        XCTAssertEqual(draft.due, date(2026, 11, 6, 18, 0))
        XCTAssertNil(draft.duration)
    }

    // MARK: - Endpoint edits

    func testSetRangeEndMovesDue() {
        var draft = timedDraft()
        draft.setRangeEnd(date(2026, 11, 4, 11, 0), calendar: calendar)
        XCTAssertEqual(draft.due, date(2026, 11, 4, 11, 0))
        XCTAssertEqual(draft.duration?.start, date(2026, 11, 4, 9, 0))
    }

    func testSetRangeStartKeepsEnd() {
        var draft = timedDraft()
        draft.setRangeStart(date(2026, 11, 4, 8, 0), calendar: calendar)
        XCTAssertEqual(draft.duration?.start, date(2026, 11, 4, 8, 0))
        XCTAssertEqual(draft.due, date(2026, 11, 4, 10, 30))
    }

    // MARK: - All-day transitions

    func testTimedToAllDayNormalizesToDays() {
        var draft = timedDraft()
        draft.setAllDay(true, calendar: calendar)
        XCTAssertEqual(draft.duration?.start, calendar.startOfDay(for: date(2026, 11, 4)))
        XCTAssertEqual(draft.duration?.end, calendar.startOfDay(for: date(2026, 11, 4)))
        XCTAssertFalse(draft.effectiveHasTime)
    }

    func testAllDayToTimedRestoresNineAM() {
        var draft = ScheduleDraft(
            due: date(2026, 11, 4),
            duration: TaskDurationRange(start: date(2026, 11, 2), end: date(2026, 11, 4), isAllDay: true))
        draft.setAllDay(false, calendar: calendar)
        XCTAssertEqual(draft.duration?.start, date(2026, 11, 2, 9, 0))
        XCTAssertEqual(draft.duration?.end, date(2026, 11, 4, 9, 0))
        XCTAssertTrue(draft.effectiveHasTime)
    }

    func testAllDaySpanSurvivesDSTFallback() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        func laDate(_ m: Int, _ d: Int) -> Date {
            la.date(from: DateComponents(year: 2026, month: m, day: d))!
        }
        var draft = ScheduleDraft(
            due: laDate(11, 2),
            duration: TaskDurationRange(start: laDate(10, 31), end: laDate(11, 2), isAllDay: true))
        draft.setDue(laDate(11, 3), calendar: la)
        XCTAssertEqual(draft.duration?.start, laDate(11, 1))
        XCTAssertEqual(draft.duration?.end, laDate(11, 3))
    }

    // MARK: - Enable / remove / rezone

    func testEnableSeedsWindowEndingAtDue() {
        var draft = ScheduleDraft(due: date(2026, 11, 4, 10, 0), hasTime: true)
        draft.enableDuration(defaultMinutes: 60, calendar: calendar)
        XCTAssertEqual(draft.duration?.start, date(2026, 11, 4, 9, 0))
        XCTAssertEqual(draft.duration?.end, date(2026, 11, 4, 10, 0))
    }

    func testRemoveDurationKeepsCoherentDue() {
        var draft = timedDraft()
        draft.removeDuration()
        XCTAssertNil(draft.duration)
        XCTAssertEqual(draft.due, date(2026, 11, 4, 10, 30))
    }

    func testRezoneTranslatesWholeIntervalWallClock() {
        var draft = timedDraft()
        draft.rezone(from: "GMT", to: "America/Los_Angeles", calendar: calendar)
        // Same wall numbers, new zone.
        var la = calendar
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(la.component(.hour, from: draft.due), 10)
        XCTAssertEqual(la.component(.hour, from: draft.duration!.start), 9)
        XCTAssertEqual(la.component(.day, from: draft.duration!.start), 4)
        XCTAssertEqual(draft.timeZoneID, "America/Los_Angeles")
    }

    // MARK: - Remaining occurrences

    func testRemainingCountShowsCurrentPlusOneOnly() {
        let rule = CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 5)
        let start = date(2026, 11, 1)
        let upcoming = remainingOccurrences(rule: rule, current: start, index: 4, calendar: calendar)
        XCTAssertEqual(upcoming, [date(2026, 11, 2)])
    }

    func testRemainingCountEmptyAtMax() {
        let rule = CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 5)
        XCTAssertTrue(remainingOccurrences(rule: rule, current: date(2026, 11, 5), index: 5, calendar: calendar).isEmpty)
    }

    func testRemainingWithoutCountShowsNextFew() {
        let rule = CustomRecurrence(interval: 1, unit: .days)
        XCTAssertEqual(
            remainingOccurrences(rule: rule, current: date(2026, 11, 1), index: 3, calendar: calendar),
            [date(2026, 11, 2), date(2026, 11, 3), date(2026, 11, 4), date(2026, 11, 5), date(2026, 11, 6)])
    }

    func testMonthDayListRejectsBogusTokens() {
        XCTAssertEqual(parseMonthDayList("1,15"), [1, 15])
        XCTAssertEqual(parseMonthDayList(" 3 , 7 "), [3, 7])
        XCTAssertEqual(parseMonthDayList(""), [])
        XCTAssertEqual(parseMonthDayList("   "), [])
        XCTAssertNil(parseMonthDayList("1,bogus,15"))
        XCTAssertNil(parseMonthDayList("0"))
        XCTAssertNil(parseMonthDayList("32"))
        XCTAssertNil(parseMonthDayList("-3"))
        XCTAssertNil(parseMonthDayList("1,,15"))
        XCTAssertNil(parseMonthDayList("1,"))
        XCTAssertNil(parseMonthDayList("1.5"))
    }

    func testRemainingRejectsInvalid() {
        let bad = CustomRecurrence(interval: 0, unit: .days)
        XCTAssertTrue(remainingOccurrences(rule: bad, current: date(2026, 11, 1), index: 1, calendar: calendar).isEmpty)
        let good = CustomRecurrence(interval: 1, unit: .days)
        XCTAssertTrue(remainingOccurrences(rule: good, current: date(2026, 11, 1), index: 0, calendar: calendar).isEmpty)
    }
}
