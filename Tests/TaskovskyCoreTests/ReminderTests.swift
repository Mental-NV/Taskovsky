import XCTest
@testable import TaskovskyCore

final class ReminderTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
    }

    @MainActor func testDefaultReminderFollowsScheduleAndManualReminderDoesNot() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        store.settings.allDayReminder = .onDay9
        let calendar = store.settings.calendar
        let due = calendar.startOfDay(for: Date())
        let id = store.createTask(title: "Default", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.reminderFollowsSchedule, true)
        task.dueDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: due))
        store.updateTask(task)
        task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.reminderDate, calendar.date(bySettingHour: 9, minute: 0, second: 0, of: try XCTUnwrap(task.dueDate)))
        let custom = try XCTUnwrap(task.reminderDate).addingTimeInterval(3600)
        task.reminderDate = custom; store.updateTask(task)
        task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.reminderFollowsSchedule, false)
        task.dueDate = calendar.date(byAdding: .day, value: 1, to: try XCTUnwrap(task.dueDate))
        store.updateTask(task)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == id }?.reminderDate, custom)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == id }?.reminderFollowsSchedule, false)
    }

    func testLegacyReminderInferenceAndDecoding() throws {
        var settings = AppSettings(); settings.allDayReminder = .onDay9
        let due = settings.calendar.startOfDay(for: Date())
        let expected = try XCTUnwrap(TaskStore.defaultReminderDate(due: due, hasTime: false, settings: settings, calendar: settings.calendar))
        let task = TaskItem(title: "Legacy", dueDate: due, reminderDate: expected)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(task)) as? [String: Any])
        object.removeValue(forKey: "reminderFollowsSchedule")
        var decoded = try JSONDecoder().decode(TaskItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.reminderFollowsSchedule)
        XCTAssertTrue(TaskStore.usesDefaultReminder(decoded, settings: settings))
        decoded.reminderDate = expected.addingTimeInterval(60)
        XCTAssertFalse(TaskStore.usesDefaultReminder(decoded, settings: settings))
        decoded.reminderFollowsSchedule = false; decoded.reminderDate = expected
        XCTAssertFalse(TaskStore.usesDefaultReminder(decoded, settings: settings))
    }

    @MainActor func testAllDayRecurringReminderKeepsWallTimeAcrossDST() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let due = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7)))
        let reminder = try XCTUnwrap(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due))
        let id = store.createTask(title: "Daily", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.timeZoneID = calendar.timeZone.identifier; task.recurrence = .daily; task.reminderDate = reminder
        store.updateTask(task); store.toggleComplete(id: id)
        let next = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(next.reminderDate)), 8)
        XCTAssertEqual(calendar.component(.hour, from: try XCTUnwrap(next.reminderDate)), 9)
    }
    func testLegacyAndMultipleDefaults() throws {
        var settings = AppSettings()
        settings.defaultReminder = .fiveMinutesBefore
        let oldSettings = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(oldSettings.effectiveTimedReminderDefaults, [.fiveMinutesBefore])
        settings.timedReminderDefaults = [.onTime, .oneHourBefore, .fiveMinutesBefore]
        let due = Date(timeIntervalSince1970: 2_000_000_000)
        let dates = TaskStore.defaultReminderDates(due: due, hasTime: true, settings: settings, calendar: settings.calendar)
        XCTAssertEqual(dates, [due.addingTimeInterval(-3600), due.addingTimeInterval(-300), due])
        var task = TaskItem(title: "Legacy", dueDate: due, reminderDate: due)
        XCTAssertEqual(task.reminderDates, [due])
        task.reminderDates = [due, dates[0], due]
        XCTAssertEqual(task.reminderDate, dates[0])
        XCTAssertEqual(task.additionalReminderDates, [due])
        let decoded = try JSONDecoder().decode(TaskItem.self, from: JSONEncoder().encode(task))
        XCTAssertEqual(decoded.reminderDates, [dates[0], due])
        task.reminderDates = []
        XCTAssertNil(task.reminderDate); XCTAssertNil(task.additionalReminderDates)
    }

    @MainActor func testMultipleAllDayDefaultsAcrossDSTAndUndo() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        store.settings.allDayReminderDefaults = [.onDay9, .dayBefore9, .twoDaysBefore9]
        let due = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7)))
        let id = store.createTask(title: "Daily", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.timeZoneID = calendar.timeZone.identifier; task.recurrence = .daily
        task.reminderDates = TaskStore.defaultReminderDates(due: due, hasTime: false, settings: store.settings, calendar: calendar)
        task.reminderFollowsSchedule = true
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let next = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(next.reminderDates.count, 3)
        XCTAssertEqual(next.reminderDates.map { calendar.component(.day, from: $0) }, [6, 7, 8])
        XCTAssertEqual(next.reminderDates.map { calendar.component(.hour, from: $0) }, [9, 9, 9])
        store.undoCompletion(id: id)
        XCTAssertFalse(store.data.tasks.contains { $0.id == next.id })
        XCTAssertEqual(store.data.tasks.first { $0.id == id }?.reminderDates, task.reminderDates)
    }
}
