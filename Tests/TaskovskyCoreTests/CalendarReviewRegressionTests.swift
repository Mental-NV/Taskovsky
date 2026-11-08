import XCTest
@testable import TaskovskyCore

final class CalendarReviewRegressionTests: XCTestCase {
    private func calendar(_ zone: String = "UTC") -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: zone)!
        return result
    }
    private func date(_ month: Int = 11, _ day: Int = 8, _ hour: Int = 0, _ minute: Int = 0, zone: String = "UTC") -> Date {
        calendar(zone).date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    @MainActor private func store(_ tasks: [TaskItem]) throws -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("workspace.json")
        try JSONEncoder().encode(WorkspaceData(tasks: tasks)).write(to: file)
        return (TaskStore(fileURL: file, seed: false), dir)
    }
    @MainActor private func save(_ draft: CalendarScheduleDraft, for id: UUID, in store: TaskStore) -> CalendarScheduleUndo? {
        draft.operation.flatMap { store.scheduleOnCalendar(id: id, operation: $0, calendar: calendar()) }
    }

    @MainActor func testUnchangedRepeatingPointSavePreservesSnapshotAndFile() throws {
        var point = TaskItem(title: "Point", dueDate: date(6, 1, 10), hasDueTime: true, timeZoneID: "UTC")
        point.customRecurrence = CustomRecurrence(interval: 2, unit: .months, includesLastDayOfMonth: true, skipWeekends: true, maxOccurrences: 5)
        point.occurrenceIndex = 2; point.recurrenceNominalDate = date(5, 31, 10)
        point.reminderDates = [date(6, 1, 9, 45), date(5, 31, 17)]
        point.reminderFollowsSchedule = false
        let (store, dir) = try store([point]); defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("workspace.json"), bytes = try Data(contentsOf: file)
        let draft = CalendarScheduleDraft(task: point, focus: date(), hourly: true, calendar: calendar())
        XCTAssertEqual(draft.start, point.dueDate); XCTAssertEqual(draft.end, point.dueDate)
        XCTAssertFalse(draft.hasDuration); XCTAssertTrue(draft.isValid)
        XCTAssertNil(draft.operation); XCTAssertNil(save(draft, for: point.id, in: store))
        XCTAssertEqual(CalendarScheduleSnapshot(store.data.tasks[0]), CalendarScheduleSnapshot(point))
        XCTAssertEqual(store.data.tasks[0].updatedAt, point.updatedAt)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    @MainActor func testUnchangedPreciseAndZeroLengthRangesKeepExactEndpoints() throws {
        for seconds: TimeInterval in [0, 300, 600] {
            var task = TaskItem(title: "Precise", dueDate: date().addingTimeInterval(seconds), hasDueTime: true, timeZoneID: "UTC")
            task.scheduledDuration = .init(start: date(), end: task.dueDate!)
            let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
            let draft = CalendarScheduleDraft(task: task, focus: date(), hourly: true, calendar: calendar())
            XCTAssertTrue(draft.hasDuration); XCTAssertTrue(draft.isValid)
            XCTAssertEqual(draft.start, task.scheduledDuration?.start)
            XCTAssertEqual(draft.end, task.scheduledDuration?.end)
            XCTAssertNil(save(draft, for: task.id, in: store))
            XCTAssertEqual(CalendarScheduleSnapshot(store.data.tasks[0]), CalendarScheduleSnapshot(task))
        }
    }

    @MainActor func testUnchangedAllDayPointKeepsItsOriginalZoneAndShape() throws {
        let task = TaskItem(title: "Floating", dueDate: date(zone: "Asia/Tokyo"), timeZoneID: "Asia/Tokyo")
        let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
        let draft = CalendarScheduleDraft(task: task, focus: date(), hourly: false, calendar: calendar())
        XCTAssertEqual(draft.start, date()); XCTAssertFalse(draft.hasDuration)
        XCTAssertNil(save(draft, for: task.id, in: store))
        XCTAssertEqual(CalendarScheduleSnapshot(store.data.tasks[0]), CalendarScheduleSnapshot(task))
    }

    @MainActor func testPointDateEditRetainsPointShapeAndMovesManualReminder() throws {
        var task = TaskItem(title: "Point", dueDate: date(11, 8, 10), hasDueTime: true, timeZoneID: "UTC")
        task.reminderDates = [date(11, 8, 9, 45)]; task.reminderFollowsSchedule = false
        let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
        var draft = CalendarScheduleDraft(task: task, focus: date(), hourly: true, calendar: calendar())
        draft.start = date(11, 9, 14)
        let token = try XCTUnwrap(save(draft, for: task.id, in: store))
        XCTAssertNil(store.data.tasks[0].scheduledDuration)
        XCTAssertEqual(store.data.tasks[0].dueDate, draft.start)
        XCTAssertEqual(store.data.tasks[0].reminderDates, [date(11, 9, 13, 45)])
        XCTAssertTrue(store.undoCalendarSchedule(token))
        XCTAssertEqual(CalendarScheduleSnapshot(store.data.tasks[0]), CalendarScheduleSnapshot(task))
    }

    @MainActor func testPointToRangeConversionRequiresExplicitDurationChange() throws {
        let task = TaskItem(title: "Point", dueDate: date(11, 8, 10), hasDueTime: true, timeZoneID: "UTC")
        let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
        var draft = CalendarScheduleDraft(task: task, focus: date(), hourly: true, calendar: calendar())
        XCTAssertNil(draft.operation)
        draft.setDuration(true)
        XCTAssertEqual(draft.end, date(11, 8, 10, 30))
        let token = try XCTUnwrap(save(draft, for: task.id, in: store))
        XCTAssertEqual(store.data.tasks[0].scheduledDuration, .init(start: date(11, 8, 10), end: date(11, 8, 10, 30)))
        var range = CalendarScheduleDraft(task: store.data.tasks[0], focus: date(), hourly: true, calendar: calendar())
        range.setDuration(false)
        XCTAssertEqual(range.start, date(11, 8, 10, 30)) // retain the range's due date
        XCTAssertFalse(range.hasDuration)
        XCTAssertTrue(store.undoCalendarSchedule(token))
    }

    func testNewAndUndatedDraftsKeepNewBlockDefaults() {
        let point = TaskItem(title: "Arrange")
        let timed = CalendarScheduleDraft(task: point, focus: date(), hourly: true, calendar: calendar())
        XCTAssertEqual(timed.start, date(11, 8, 9)); XCTAssertEqual(timed.end, date(11, 8, 9, 30))
        XCTAssertTrue(timed.hasDuration); XCTAssertFalse(timed.allDay); XCTAssertNotNil(timed.operation)
        let allDay = CalendarScheduleDraft(task: point, focus: date(), hourly: false, calendar: calendar())
        XCTAssertEqual(allDay.start, date()); XCTAssertEqual(allDay.end, date())
        XCTAssertTrue(allDay.isValid); XCTAssertTrue(allDay.allDay); XCTAssertNotNil(allDay.operation)
        let new = CalendarScheduleDraft(start: date(11, 8, 14), end: date(11, 8, 14, 30), allDay: false)
        XCTAssertTrue(new.hasDuration); XCTAssertNotNil(new.operation)
    }

    @MainActor func testStoreScheduleNoOpDoesNotRewriteLegacyAutomaticReminderPolicy() throws {
        var task = TaskItem(title: "Legacy", dueDate: date(11, 8, 10), hasDueTime: true, timeZoneID: "UTC")
        task.reminderDates = [task.dueDate!]; task.reminderFollowsSchedule = nil
        let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
        let before = store.data.tasks[0]
        XCTAssertNil(store.scheduleOnCalendar(id: task.id, operation: .setPoint(date: task.dueDate!, allDay: false), calendar: calendar()))
        XCTAssertEqual(store.data.tasks[0], before)
    }

    @MainActor func testMovesKeepExactExistingDurationsRemindersReloadAndUndo() throws {
        for seconds: TimeInterval in [0, 300, 600, 5_400, 321.25] {
            let start = date(11, 8, 10), target = date(11, 9, 14), due = start.addingTimeInterval(seconds)
            var task = TaskItem(title: "Short", dueDate: due, hasDueTime: true, timeZoneID: "UTC")
            task.scheduledDuration = .init(start: start, end: due)
            task.reminderDates = [due.addingTimeInterval(-600), due.addingTimeInterval(-86_400)]
            task.reminderFollowsSchedule = false
            let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
            let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .move(start: target, allDay: false), calendar: calendar()))
            let moved = store.data.tasks[0]
            XCTAssertEqual(moved.scheduledDuration?.start, target)
            XCTAssertEqual(moved.scheduledDuration?.elapsed, seconds)
            XCTAssertEqual(moved.dueDate, target.addingTimeInterval(seconds))
            XCTAssertEqual(moved.reminderDates.map { $0.timeIntervalSince(moved.dueDate!) }, [-86_400, -600])
            let reloaded = TaskStore(fileURL: dir.appendingPathComponent("workspace.json"), seed: false)
            XCTAssertEqual(CalendarScheduleSnapshot(reloaded.data.tasks[0]), CalendarScheduleSnapshot(moved))
            XCTAssertTrue(reloaded.undoCalendarSchedule(token))
            XCTAssertEqual(CalendarScheduleSnapshot(reloaded.data.tasks[0]), CalendarScheduleSnapshot(task))
        }
    }

    @MainActor func testPointMoveDoesNotInventADuration() throws {
        let task = TaskItem(title: "Point", dueDate: date(11, 8, 10), hasDueTime: true)
        let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertNotNil(store.scheduleOnCalendar(id: task.id, operation: .move(start: date(11, 9, 14), allDay: false), calendar: calendar()))
        XCTAssertNil(store.data.tasks[0].scheduledDuration)
        XCTAssertEqual(store.data.tasks[0].dueDate, date(11, 9, 14))
    }

    @MainActor func testFutureChecklistStateMatchesTheRealSuccessorWithBothVisibilitySettings() throws {
        let task = TaskItem(title: "Daily", dueDate: date(), recurrence: .daily,
                            checklist: [.init(title: "Checked today", isCompleted: true), .init(title: "Open today")], timeZoneID: "UTC")
        let (store, dir) = try store([task]); defer { try? FileManager.default.removeItem(at: dir) }
        let before = store.data
        for showCompleted in [true, false] {
            var options = TaskCalendarOptions(); options.showCompleted = showCompleted; options.showChecklistItems = true
            let entries = TaskCalendarProjection.project(data: store.data, range: DateInterval(start: date(), end: date(11, 10)), options: options, calendar: calendar()).entries
            let current = entries.filter { !$0.isProjected && $0.checklistID != nil }
            XCTAssertEqual(current.count, showCompleted ? 2 : 1)
            XCTAssertEqual(current.filter(\.isCompleted).count, showCompleted ? 1 : 0)
            let future = entries.filter { $0.isProjected && $0.checklistID != nil }
            XCTAssertEqual(future.count, 2); XCTAssertTrue(future.allSatisfy { !$0.isCompleted && !$0.canSchedule })
            XCTAssertEqual(Set(future.map(\.title)), Set(task.checklist.map(\.title)))
        }
        XCTAssertEqual(store.data, before) // projections create no records or writes
        store.toggleComplete(id: task.id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == task.id })
        XCTAssertEqual(successor.checklist.map(\.isCompleted), [false, false])
        XCTAssertEqual(successor.checklist.map(\.title), task.checklist.map(\.title))
    }

    func testArrangeOverdueUsesCivilEndDateAcrossOppositeZones() {
        for (taskZone, displayZone) in [("Asia/Tokyo", "UTC"), ("Pacific/Auckland", "America/Los_Angeles")] {
            let display = calendar(displayZone), today = date(zone: displayZone), now = date(11, 8, 12, zone: displayZone)
            var tasks: [TaskItem] = []
            for day in 7...9 {
                let due = date(11, day, zone: taskZone)
                tasks.append(TaskItem(title: "Point \(day)", dueDate: due, timeZoneID: taskZone))
                var range = TaskItem(title: "Range \(day)", dueDate: due, timeZoneID: taskZone)
                range.scheduledDuration = .init(start: date(11, day - 1, zone: taskZone), end: due, isAllDay: true)
                tasks.append(range)
            }
            let data = WorkspaceData(tasks: tasks)
            let overdue = TaskCalendarProjection.arrangementTasks(data: data, options: .init(), overdue: true, now: now, calendar: display)
            XCTAssertEqual(Set(overdue.map(\.title)), ["Point 7", "Range 7"])
            XCTAssertTrue(TaskCalendarProjection.arrangementTasks(data: data, options: .init(), now: now, calendar: display).isEmpty)
            let projected = TaskCalendarProjection.project(data: data, range: DateInterval(start: today, end: date(11, 9, zone: displayZone)), options: .init(), calendar: display).entries
            XCTAssertTrue(projected.contains { $0.title == "Point 8" && $0.start == today })
            XCTAssertTrue(projected.contains { $0.title == "Range 8" && $0.end == date(11, 9, zone: displayZone) })
            let timed = TaskItem(title: "Absolute", dueDate: date(zone: taskZone), hasDueTime: true, timeZoneID: taskZone)
            XCTAssertEqual(TaskCalendarProjection.arrangementTasks(data: .init(tasks: [timed]), options: .init(), overdue: true, now: now, calendar: display).count, 1)
        }
    }
}
