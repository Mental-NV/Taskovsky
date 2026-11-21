import XCTest
@testable import TaskovskyDomain

final class ReminderPresetTests: XCTestCase {
    func calendar(_ zone: String = "UTC") -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; return c
    }
    func date(_ c: Calendar, _ month: Int = 3, _ day: Int = 9, _ hour: Int = 0) -> Date {
        c.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    func testCivilDaysAtNineAcrossDSTAndNonDeviceZone() throws {
        let c = calendar("America/New_York"), due = date(calendar("America/New_York"))
        var task = TaskItem(title: "Neutral", dueDate: due); task.timeZoneID = c.timeZone.identifier
        let edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar(), now: due)
        for (preset, day) in [(AllDayReminder.onDay9, 9), (.dayBefore9, 8), (.twoDaysBefore9, 7), (.threeDaysBefore9, 6), (.weekBefore9, 2)] {
            let value = try XCTUnwrap(edit.reminderPresetDate(preset))
            XCTAssertEqual(value, date(c, 3, day, 9))
            XCTAssertEqual(c.component(.minute, from: value), 0)
        }
    }
    func testIndependentTogglesPreserveUnrelatedAndSaveExactDates() throws {
        let c = calendar(), due = date(c), custom = due.addingTimeInterval(12345)
        var task = TaskItem(title: "Neutral", dueDate: due)
        task.reminderDates = [custom]; task.reminderFollowsSchedule = false
        let settings = AppSettings()
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: c, now: due)
        edit.toggleReminderPreset(.onDay9, settings: settings)
        edit.toggleReminderPreset(.weekBefore9, settings: settings)
        XCTAssertTrue(edit.isReminderPresetSelected(.onDay9, settings: settings))
        XCTAssertTrue(edit.isReminderPresetSelected(.weekBefore9, settings: settings))
        edit.toggleReminderPreset(.onDay9, settings: settings)
        XCTAssertFalse(edit.isReminderPresetSelected(.onDay9, settings: settings))
        XCTAssertEqual(edit.manualReminders, [date(c, 3, 2, 9), custom])
        let saved = try edit.applying(to: task, settings: settings)
        XCTAssertEqual(saved.reminderDates, edit.manualReminders)
        XCTAssertEqual(saved.dueDate, task.dueDate)
        XCTAssertEqual(task.reminderDates, [custom]) // staging did not mutate original
        let reopened = TaskScheduleEdit(task: saved, settings: settings, calendar: c, now: due)
        XCTAssertTrue(reopened.isReminderPresetSelected(.weekBefore9, settings: settings))
    }
    func testAutomaticMaterializationUsesStagedDateAndZone() throws {
        let c = calendar(), due = date(c)
        var settings = AppSettings(); settings.allDayReminderDefaults = [.onDay9, .dayBefore9]
        let task = TaskItem(title: "Neutral", dueDate: due)
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: c, now: due)
        edit.chooseDay(date(c, 12, 1)); edit.setZone("Pacific/Kiritimati")
        let defaults = edit.automaticReminders(settings: settings)
        let added = try XCTUnwrap(edit.reminderPresetDate(.weekBefore9))
        edit.toggleReminderPreset(.weekBefore9, settings: settings)
        XCTAssertFalse(edit.usesAutomaticReminders)
        XCTAssertEqual(edit.manualReminders, (defaults + [added]).sorted())
        edit.toggleReminderPreset(.onDay9, settings: settings)
        XCTAssertEqual(edit.manualReminders, (defaults.filter { $0 != edit.reminderPresetDate(.onDay9) } + [added]).sorted())
    }
    func testNoneClearsDefaultsManualAndLatentEndWithoutMovingDate() throws {
        let c = calendar(), due = date(c)
        var settings = AppSettings(); settings.allDayReminderDefaults = [.onDay9]
        let task = TaskItem(title: "Neutral", dueDate: due)
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: c, now: due)
        edit.remindsAtEnd = true
        edit.toggleReminderPreset(.none, settings: settings)
        XCTAssertFalse(edit.usesAutomaticReminders); XCTAssertFalse(edit.remindsAtEnd)
        XCTAssertTrue(edit.manualReminders.isEmpty)
        XCTAssertTrue(edit.isReminderPresetSelected(.none, settings: settings))
        let saved = try edit.applying(to: task, settings: settings)
        XCTAssertEqual(saved.dueDate, due); XCTAssertEqual(saved.reminderFollowsSchedule, false)
        XCTAssertTrue(saved.reminderDates.isEmpty)
    }
    func testExcludedModesAreNoOpAndReadingDoesNotNormalize() throws {
        let c = calendar(), due = date(c)
        var task = TaskItem(title: "Neutral", dueDate: due)
        task.reminderDates = [due, due]; task.reminderFollowsSchedule = false
        let settings = AppSettings()
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: c, now: due)
        edit.manualReminders = [due, due] // exercise a raw staged draft, TaskItem normalizes its setter
        _ = edit.isReminderPresetSelected(.onDay9, settings: settings)
        XCTAssertEqual(edit.manualReminders, [due, due])
        for mode in 0...2 {
            var excluded = edit
            if mode == 0 { excluded.hasDate = false }
            if mode == 1 { excluded.setTime(true) }
            if mode == 2 { excluded.setDuration(true, defaultMinutes: 30) }
            XCTAssertFalse(excluded.supportsAllDayReminderPresets)
            excluded.toggleReminderPreset(.none, settings: settings)
            XCTAssertEqual(excluded.manualReminders, [due, due])
        }
        task.timeZoneID = "Invalid/Unknown"
        edit = TaskScheduleEdit(task: task, settings: settings, calendar: c, now: due)
        edit.manualReminders = [due, due]
        XCTAssertNil(edit.reminderPresetDate(.onDay9))
        edit.toggleReminderPreset(.none, settings: settings)
        XCTAssertEqual(edit.manualReminders, [due, due])
    }
}
