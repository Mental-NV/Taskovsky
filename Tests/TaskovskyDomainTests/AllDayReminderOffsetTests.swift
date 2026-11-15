import XCTest
@testable import TaskovskyDomain

final class AllDayReminderOffsetTests: XCTestCase {
    func calendar(_ zone: String) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; return c }
    func date(_ c: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date { c.date(from: DateComponents(year: y, month: m, day: d))! }
    func testDayAndWeekOffsetsUseCivilDays() throws {
        let c = calendar("America/New_York"), due = date(calendar("America/New_York"), 2026, 3, 9)
        let result = try XCTUnwrap(AllDayReminderOffset.date(due: due, weeks: false, offset: 1, hour: 9, minute: 15, calendar: c))
        let p = c.dateComponents([.day, .hour, .minute], from: result)
        XCTAssertEqual(p.day, 8); XCTAssertEqual(p.hour, 9); XCTAssertEqual(p.minute, 15)
        let week = try XCTUnwrap(AllDayReminderOffset.date(due: due, weeks: true, offset: 1, hour: 9, minute: 15, calendar: c))
        XCTAssertEqual(c.component(.day, from: week), 2)
    }
    func testNonexistentTimeRejectedAndRepeatedTimeUsesFirst() throws {
        let c = calendar("America/New_York")
        XCTAssertNil(AllDayReminderOffset.date(due: date(c, 2026, 3, 8), weeks: false, offset: 0, hour: 2, minute: 30, calendar: c))
        let repeated = try XCTUnwrap(AllDayReminderOffset.date(due: date(c, 2026, 11, 1), weeks: false, offset: 0, hour: 1, minute: 30, calendar: c))
        XCTAssertEqual(c.timeZone.secondsFromGMT(for: repeated), -14400)
    }
    func testLeapBoundaryAndInvalidInputs() throws {
        let c = calendar("Pacific/Kiritimati")
        let value = try XCTUnwrap(AllDayReminderOffset.date(due: date(c, 2028, 3, 1), weeks: false, offset: 1, hour: 0, minute: 5, calendar: c))
        XCTAssertEqual(c.component(.day, from: value), 29)
        for offset in [-1, 53] { XCTAssertNil(AllDayReminderOffset.date(due: value, weeks: false, offset: offset, hour: 9, minute: 0, calendar: c)) }
        XCTAssertNil(AllDayReminderOffset.date(due: value, weeks: true, offset: 53, hour: 9, minute: 0, calendar: c))
        XCTAssertNil(AllDayReminderOffset.date(due: value, weeks: false, offset: 0, hour: 24, minute: 0, calendar: c))
    }
    func testUnitSwitchKeepsCommonOffsetWithoutClamping() throws {
        let c = calendar("UTC"), due = date(calendar("UTC"), 2028, 6, 1)
        for weeks in [false, true, false] {
            let value = try XCTUnwrap(AllDayReminderOffset.date(due: due, weeks: weeks, offset: 52, hour: 9, minute: 0, calendar: c))
            XCTAssertEqual(c.dateComponents([.day], from: c.startOfDay(for: value), to: due).day, weeks ? 364 : 52)
        }
    }
    func testCustomAddPreservesStagedDateAndZoneDefaultsThenDeduplicates() throws {
        let c = calendar("UTC"), originalDue = date(calendar("UTC"), 2026, 11, 9)
        var settings = AppSettings(); settings.allDayReminderDefaults = [.onDay9, .dayBefore9]
        let task = TaskItem(title: "Neutral", dueDate: originalDue)
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: c, now: originalDue)
        let originalDefaults = edit.automaticReminders(settings: settings)
        edit.chooseDay(date(c, 2026, 12, 1)); edit.setZone("Pacific/Kiritimati")
        let stagedDefaults = edit.automaticReminders(settings: settings)
        XCTAssertNotEqual(stagedDefaults, originalDefaults)
        let custom = try XCTUnwrap(AllDayReminderOffset.date(due: edit.schedule.effectiveDue, weeks: false, offset: 2, hour: 10, minute: 35, calendar: edit.calendar))
        edit.addManualReminder(custom, settings: settings)
        edit.addManualReminder(custom, settings: settings)
        XCTAssertFalse(edit.usesAutomaticReminders)
        XCTAssertEqual(edit.manualReminders, (stagedDefaults + [custom]).sorted())
        let saved = try edit.applying(to: task, settings: settings)
        XCTAssertEqual(saved.reminderDates, edit.manualReminders)
        XCTAssertEqual(saved.reminderFollowsSchedule, false)
        XCTAssertEqual(saved.timeZoneID, "Pacific/Kiritimati")
        XCTAssertEqual(task.dueDate, originalDue)
    }

}
