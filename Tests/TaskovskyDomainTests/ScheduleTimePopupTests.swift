import XCTest
@testable import TaskovskyDomain

/// D09 Time popup staging: Date-mode time is staged through the existing
/// `TaskScheduleEdit.setTime/setEnd/setZone` semantics. Opening stages a time,
/// closing the popup retains it, inline remove clears it, and outer Cancel
/// discards the whole draft. Duration conversions are unchanged.
final class ScheduleTimePopupTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!
        return value
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func wall(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    func testOpeningStagesNineAMThroughExistingSetTimeDefault() {
        let task = TaskItem(title: "Outline", dueDate: day(2026, 11, 9))
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: day(2026, 11, 9))
        XCTAssertFalse(edit.schedule.effectiveHasTime)
        // Popup open stages a time; the 09:00 default is the existing
        // TaskScheduleEdit policy, not a TickTick reference value.
        edit.setTime(true)
        XCTAssertTrue(edit.schedule.effectiveHasTime)
        XCTAssertNil(edit.schedule.duration)
        XCTAssertEqual(wall(edit.schedule.effectiveDue).hour, 9)
        XCTAssertEqual(wall(edit.schedule.effectiveDue).minute, 0)
        XCTAssertEqual(calendar.startOfDay(for: edit.schedule.effectiveDue),
                       calendar.startOfDay(for: day(2026, 11, 9)))
    }

    func testPopupCloseRetainsStagedTimeAndOuterCancelDiscards() throws {
        let task = TaskItem(title: "Outline", dueDate: day(2026, 11, 9))
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: day(2026, 11, 9))
        edit.setTime(true)
        // Closing the popup keeps the staged value: saving applies a timed date.
        let saved = try edit.applying(to: task, settings: AppSettings())
        XCTAssertTrue(saved.hasDueTime)
        XCTAssertEqual(wall(saved.dueDate!).hour, 9)
        // Outer Cancel discards the draft: the original task is untouched.
        XCTAssertFalse(task.hasDueTime)
        XCTAssertEqual(task.dueDate, day(2026, 11, 9))
    }

    func testSelectedTimeSavesAndReopens() throws {
        let task = TaskItem(title: "Outline", dueDate: day(2026, 11, 9))
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: day(2026, 11, 9))
        edit.setTime(true)
        let picked = calendar.date(bySettingHour: 14, minute: 30, second: 37, of: day(2026, 11, 9))!
        edit.setEnd(picked)
        let saved = try edit.applying(to: task, settings: AppSettings())
        XCTAssertTrue(saved.hasDueTime)
        XCTAssertEqual(saved.dueDate, picked)
        // Reopening shows the saved time; an untouched save writes nothing.
        let reopened = TaskScheduleEdit(task: saved, settings: AppSettings(), calendar: calendar, now: day(2026, 11, 10))
        XCTAssertTrue(reopened.schedule.effectiveHasTime)
        XCTAssertEqual(reopened.schedule.effectiveDue, picked)
        var untouched = reopened
        let same = try untouched.applying(to: saved, settings: AppSettings())
        XCTAssertEqual(same, saved)
    }

    func testInlineRemoveClearsTimeBeforeSave() throws {
        let task = TaskItem(title: "Timed", dueDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day(2026, 11, 9))!,
                            hasDueTime: true)
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: day(2026, 11, 9))
        XCTAssertTrue(edit.schedule.effectiveHasTime)
        edit.setTime(false)
        XCTAssertFalse(edit.schedule.effectiveHasTime)
        let saved = try edit.applying(to: task, settings: AppSettings())
        XCTAssertFalse(saved.hasDueTime)
        XCTAssertEqual(saved.dueDate, day(2026, 11, 9))
    }

    func testZoneChangePreservesWallClock() throws {
        var zoneCalendar = calendar
        zoneCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let due = zoneCalendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 14, minute: 30))!
        let task = TaskItem(title: "Timed", dueDate: due, hasDueTime: true)
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: zoneCalendar, now: due)
        edit.setZone("America/Los_Angeles")
        let saved = try edit.applying(to: task, settings: AppSettings())
        XCTAssertEqual(saved.timeZoneID, "America/Los_Angeles")
        var losAngeles = calendar
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let moved = losAngeles.dateComponents([.hour, .minute], from: saved.dueDate!)
        XCTAssertEqual(moved.hour, 14)
        XCTAssertEqual(moved.minute, 30)
    }

    func testDurationToggleAndEndpointsUnchanged() throws {
        let due = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: day(2026, 11, 9))!
        let task = TaskItem(title: "Workshop", dueDate: due, hasDueTime: true)
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: day(2026, 11, 9))
        edit.setDuration(true, defaultMinutes: 60)
        XCTAssertNotNil(edit.schedule.duration)
        XCTAssertEqual(edit.schedule.duration!.end, due)
        XCTAssertEqual(edit.schedule.duration!.end.timeIntervalSince(edit.schedule.duration!.start), 3600)
        let later = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: day(2026, 11, 9))!
        edit.setEnd(later)
        XCTAssertEqual(edit.schedule.duration!.end, later)
        // Duration off keeps the range end as a coherent timed due date.
        edit.setDuration(false, defaultMinutes: 60)
        XCTAssertNil(edit.schedule.duration)
        let saved = try edit.applying(to: task, settings: AppSettings())
        XCTAssertTrue(saved.hasDueTime)
        XCTAssertEqual(saved.dueDate, later)
    }
}
