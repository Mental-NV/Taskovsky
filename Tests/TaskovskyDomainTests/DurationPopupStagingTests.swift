import XCTest
@testable import TaskovskyDomain

final class DurationPopupStagingTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }
    private func fixture() -> TaskItem {
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 4, minute: 15, second: 37))!
        var task = TaskItem(title: "Range", dueDate: end, hasDueTime: true)
        task.scheduledDuration = TaskDurationRange(start: end.addingTimeInterval(-3659), end: end)
        task.timeZoneID = calendar.timeZone.identifier
        task.reminderDates = [end.addingTimeInterval(-900)]
        task.reminderFollowsSchedule = false
        task.endReminderEnabled = true
        return task
    }
    func testNoOpCopyRetainsExactSecondsZoneAndOriginalTask() throws {
        let task = fixture()
        let outer = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: task.dueDate!)
        let nested = outer
        XCTAssertEqual(try nested.applying(to: task, settings: AppSettings()), task)
        XCTAssertEqual(nested.schedule, outer.schedule)
    }
    func testNestedEndpointChangesCancelAndInvalidCorrection() throws {
        let task = fixture()
        let outer = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: task.dueDate!)
        var nested = outer
        nested.setStart(task.dueDate!.addingTimeInterval(60))
        XCTAssertNil(nested.schedule.duration?.validated(in: nested.calendar))
        XCTAssertEqual(outer.schedule.duration, task.scheduledDuration)
        nested.setEnd(task.dueDate!.addingTimeInterval(120))
        XCTAssertNotNil(nested.schedule.duration?.validated(in: nested.calendar))
        let saved = try nested.applying(to: task, settings: AppSettings())
        XCTAssertEqual(saved.scheduledDuration?.start, task.dueDate!.addingTimeInterval(60))
        XCTAssertEqual(saved.dueDate, task.dueDate!.addingTimeInterval(120))
    }
    func testMoveAndAllDayUseExistingRangeSemanticsAcrossDST() {
        let task = fixture()
        var nested = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: task.dueDate!)
        nested.chooseDay(calendar.date(byAdding: .day, value: 1, to: task.dueDate!)!)
        XCTAssertEqual(nested.schedule.duration?.elapsed, task.scheduledDuration?.elapsed)
        XCTAssertEqual(calendar.component(.second, from: nested.schedule.effectiveDue), 37)
        nested.setTime(false)
        XCTAssertTrue(nested.schedule.duration!.isAllDay)
        XCTAssertEqual(nested.schedule.duration?.start, calendar.startOfDay(for: nested.schedule.duration!.start))
        nested.setTime(true)
        XCTAssertFalse(nested.schedule.duration!.isAllDay)
        XCTAssertEqual(calendar.component(.hour, from: nested.schedule.duration!.start), 9)
    }
}
