import XCTest
@testable import TaskovskyCore

final class TaskCalendarTests: XCTestCase {
    private func cal(_ zone: String = "UTC", first: Int = 2) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: zone)!
        value.firstWeekday = first
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, zone: String = "UTC") -> Date {
        cal(zone).date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
    private func timed(_ title: String, start: Date, end: Date) -> TaskItem {
        var task = TaskItem(title: title, dueDate: end, hasDueTime: true)
        task.timeZoneID = "UTC"
        task.scheduledDuration = TaskDurationRange(start: start, end: end)
        return task
    }
    private func project(_ tasks: [TaskItem], options: TaskCalendarOptions = .init(),
                         start: Date? = nil, end: Date? = nil, calendar: Calendar? = nil) -> CalendarProjectionResult {
        TaskCalendarProjection.project(data: WorkspaceData(tasks: tasks),
            range: DateInterval(start: start ?? date(2026, 11, 8), end: end ?? date(2026, 11, 15)),
            options: options, calendar: calendar ?? cal())
    }

    func testSevenViewRangesAndWeekStart() {
        var options = TaskCalendarOptions()
        let focus = date(2026, 11, 8) // Sunday
        let expected: [TaskCalendarMode: Int] = [.day: 1, .week: 7, .month: 42, .year: 365, .agenda: 30, .multiDay: 5, .multiWeek: 14]
        for mode in TaskCalendarMode.allCases {
            let days = CalendarDates.visibleDays(focus: focus, mode: mode, options: options, calendar: cal())
            XCTAssertEqual(days.count, expected[mode])
            XCTAssertEqual(Set(days).count, days.count)
        }
        XCTAssertEqual(CalendarDates.weekStart(focus, calendar: cal()), date(2026, 11, 2))
        XCTAssertEqual(CalendarDates.weekStart(focus, calendar: cal(first: 1)), focus)
        options.multiDayCount = 500; options.multiWeekCount = -10
        XCTAssertEqual(CalendarDates.visibleDays(focus: focus, mode: .multiDay, options: options, calendar: cal()).count, 14)
        XCTAssertEqual(CalendarDates.visibleDays(focus: focus, mode: .multiWeek, options: options, calendar: cal()).count, 14)
    }

    func testMonthNavigationDoesNotClampThroughFebruary() {
        let options = TaskCalendarOptions()
        let feb = CalendarDates.navigate(date(2026, 1, 31), direction: 1, mode: .month, options: options, calendar: cal())
        let march = CalendarDates.navigate(feb, direction: 1, mode: .month, options: options, calendar: cal())
        XCTAssertEqual(feb, date(2026, 2, 1)); XCTAssertEqual(march, date(2026, 3, 1))
        let leap = CalendarDates.visibleDays(focus: date(2028, 6, 1), mode: .year, options: options, calendar: cal())
        XCTAssertEqual(leap.count, 366)
    }

    func testCalendarOptionsAreBackwardCompatibleAndPersist() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(old.calendarOptions, TaskCalendarOptions())
        var settings = old
        settings.calendarOptions.mode = .multiWeek
        settings.calendarOptions.listIDs = []
        settings.calendarOptions.includeInbox = false
        settings.calendarOptions.additionalTimeZoneID = "America/New_York"
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)), settings)
        let bounded = try JSONDecoder().decode(TaskCalendarOptions.self, from: Data(#"{"mode":"future-mode","multiDayCount":999,"multiWeekCount":0,"additionalTimeZoneID":"invalid"}"#.utf8))
        XCTAssertEqual(bounded.mode, .week); XCTAssertEqual(bounded.multiDayCount, 14)
        XCTAssertEqual(bounded.multiWeekCount, 2); XCTAssertNil(bounded.additionalTimeZoneID)
    }

    func testScopeArchiveExclusionAndDescendantTags() {
        var archive = TaskList(name: "Archived", color: "#000000"); archive.isArchived = true
        var excluded = TaskList(name: "Excluded from smart lists", color: "#123456"); excluded.showsInSmartLists = false
        let parent = TaskTag(name: "Area", color: "#FF0000")
        let child = TaskTag(name: "Website", color: "#00FF00", parentID: parent.id)
        var task = TaskItem(title: "Included", listID: excluded.id, tagIDs: [child.id], dueDate: date(2026, 11, 8))
        var data = WorkspaceData(tasks: [task], lists: [excluded, archive], tags: [parent, child])
        var options = TaskCalendarOptions(); options.tagIDs = [parent.id]
        XCTAssertEqual(TaskCalendarProjection.project(data: data, range: DateInterval(start: date(2026, 11, 8), end: date(2026, 11, 9)), options: options, calendar: cal()).entries.count, 1)
        task.listID = archive.id; data.tasks = [task]
        XCTAssertFalse(options.includes(task, data: data))
        task.listID = excluded.id; options.listIDs = []
        XCTAssertTrue(options.includes(task, data: data)) // Selected tags are independent Calendar sources.
        options.tagIDs = []
        XCTAssertFalse(options.includes(task, data: data))
        options.listIDs = [UUID()] // stale list selection never broadens to All
        XCTAssertFalse(options.includes(task, data: data))
    }

    func testAllDayCivilDateAndInclusiveDurationAcrossZones() {
        var task = TaskItem(title: "Three days", dueDate: date(2026, 11, 10, zone: "Pacific/Auckland"))
        task.timeZoneID = "Pacific/Auckland"
        task.scheduledDuration = TaskDurationRange(start: date(2026, 11, 8, zone: "Pacific/Auckland"), end: task.dueDate!, isAllDay: true)
        let entries = project([task]).entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].start, date(2026, 11, 8))
        XCTAssertEqual(entries[0].end, date(2026, 11, 11))
        XCTAssertTrue(entries[0].overlaps(DateInterval(start: date(2026, 11, 10), end: date(2026, 11, 11))))
        XCTAssertFalse(entries[0].overlaps(DateInterval(start: date(2026, 11, 11), end: date(2026, 11, 12))))
    }

    func testRepeatsRetainNominalCadenceAndRemainingCount() {
        var task = TaskItem(title: "Bimonthly", dueDate: date(2026, 6, 1))
        task.timeZoneID = "UTC"
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .months, includesLastDayOfMonth: true, skipWeekends: true, maxOccurrences: 3)
        task.occurrenceIndex = 2; task.recurrenceNominalDate = date(2026, 5, 31)
        let result = project([task], start: date(2026, 6, 1), end: date(2026, 12, 1))
        XCTAssertEqual(result.entries.map(\.due), [date(2026, 6, 1), date(2026, 7, 31)])
        XCTAssertFalse(result.entries[0].isProjected)
        XCTAssertTrue(result.entries[1].isProjected)
        XCTAssertFalse(result.entries[1].canSchedule)
        task.occurrenceIndex = 3
        XCTAssertEqual(project([task], start: date(2026, 6, 1), end: date(2026, 12, 1)).entries.count, 1)
    }

    func testRepeatToggleHistoryAndChecklistVisibility() {
        var task = TaskItem(title: "Daily", dueDate: date(2026, 11, 8), recurrence: .daily,
                            checklist: [ChecklistItem(title: "Open"), ChecklistItem(title: "Done", isCompleted: true)])
        var options = TaskCalendarOptions(); options.showRepeatCycles = false; options.showChecklistItems = true
        options.showCompleted = false
        var entries = project([task], options: options).entries
        XCTAssertEqual(entries.count, 2)
        XCTAssertFalse(entries.last!.canSchedule)
        task.completedAt = date(2026, 11, 8, 9)
        XCTAssertTrue(project([task], options: options).entries.isEmpty)
        options.showCompleted = true; options.showRepeatCycles = true
        entries = project([task], options: options).entries
        XCTAssertEqual(entries.count, 3); XCTAssertFalse(entries.contains(where: \.isProjected))
    }

    func testRepeatTraversalLimitIsReported() {
        let task = TaskItem(title: "Old daily", dueDate: date(2020, 1, 1), recurrence: .daily)
        let result = TaskCalendarProjection.project(data: WorkspaceData(tasks: [task]),
            range: DateInterval(start: date(2026, 11, 8), end: date(2026, 11, 9)),
            options: TaskCalendarOptions(), calendar: cal(), traversalLimit: 10)
        XCTAssertTrue(result.entries.isEmpty); XCTAssertEqual(result.truncatedTaskIDs, [task.id])
    }

    func testTimedOverlapColumnsAndExclusiveMidnight() {
        let tasks = [timed("A", start: date(2026, 11, 8, 9), end: date(2026, 11, 8, 11)),
                     timed("B", start: date(2026, 11, 8, 10), end: date(2026, 11, 8, 12)),
                     timed("C", start: date(2026, 11, 8, 12), end: date(2026, 11, 8, 13)),
                     timed("Night", start: date(2026, 11, 7, 23), end: date(2026, 11, 8))]
        let entries = project(tasks).entries
        let positions = CalendarTimedLayout.placements(entries: entries, day: date(2026, 11, 8), calendar: cal())
        XCTAssertEqual(positions.map(\.entry.title), ["A", "B", "C"])
        XCTAssertEqual(positions.map(\.columnCount), [2, 2, 1])
        XCTAssertNotEqual(positions[0].column, positions[1].column)
        XCTAssertEqual(positions[0].startMinute, 540)
    }

    func testGridUsesCivilHoursOnDSTDays() {
        let calendar = cal("America/New_York")
        let day = date(2026, 3, 8, zone: "America/New_York")
        let nine = CalendarDates.instant(on: day, minute: 540, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: nine), 9)
        XCTAssertEqual(nine.timeIntervalSince(day), 8 * 3_600)
        let gap = CalendarDates.instant(on: day, minute: 150, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: gap), 3)
        XCTAssertEqual(CalendarDates.snappedMinute(67), 60)
        XCTAssertEqual(CalendarDates.snappedMinute(68), 75)
        XCTAssertEqual(CalendarDates.snappedMinute(.infinity), 0)
        XCTAssertEqual(CalendarDates.snappedMinute(5_000), 1_440)
    }

    func testLatePointDoesNotLeakIntoNextDayButDurationDoes() {
        let point = TaskItem(title: "Point", dueDate: date(2026, 11, 8, 23, 55), hasDueTime: true, timeZoneID: "UTC")
        let duration = timed("Night", start: date(2026, 11, 8, 23, 55), end: date(2026, 11, 9, 0, 10))
        let entries = project([point, duration]).entries
        let nextDay = DateInterval(start: date(2026, 11, 9), end: date(2026, 11, 10))
        XCTAssertEqual(entries.filter { $0.overlaps(nextDay) }.map(\.title), ["Night"])
        XCTAssertFalse(entries.first { $0.title == "Point" }!.hasDuration)
        XCTAssertTrue(entries.first { $0.title == "Night" }!.hasDuration)
    }

    @MainActor func testEditorRangeMapsFloatingDatesAndUndoRestoresRecurrence() throws {
        var task = TaskItem(title: "Range", dueDate: date(2026, 11, 8, zone: "Pacific/Auckland"), timeZoneID: "Pacific/Auckland")
        task.customRecurrence = CustomRecurrence(interval: 1, unit: .days, maxOccurrences: 4)
        task.reminderDates = [date(2026, 11, 8, 9, zone: "Pacific/Auckland")]
        task.reminderFollowsSchedule = false
        let (store, dir) = try store(tasks: [task]); defer { try? FileManager.default.removeItem(at: dir) }
        let range = TaskDurationRange(start: date(2026, 11, 10), end: date(2026, 11, 12), isAllDay: true)
        let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .setRange(range), calendar: cal()))
        XCTAssertEqual(store.data.tasks.first?.scheduledDuration?.start, date(2026, 11, 10, zone: "Pacific/Auckland"))
        XCTAssertEqual(store.data.tasks.first?.dueDate, date(2026, 11, 12, zone: "Pacific/Auckland"))
        XCTAssertTrue(store.undoCalendarSchedule(token))
        let removed = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .unschedule, calendar: cal()))
        XCTAssertNil(store.data.tasks.first?.customRecurrence)
        XCTAssertTrue(store.data.tasks.first!.reminderDates.isEmpty)
        XCTAssertTrue(store.undoCalendarSchedule(removed))
        XCTAssertEqual(CalendarScheduleSnapshot(store.data.tasks.first!), CalendarScheduleSnapshot(task))
        XCTAssertNil(store.scheduleOnCalendar(id: task.id, operation: .setRange(.init(start: date(2026, 11, 12), end: date(2026, 11, 10))), calendar: cal()))
    }

    @MainActor private func store(tasks: [TaskItem] = [], lists: [TaskList] = []) throws -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("workspace.json")
        try JSONEncoder().encode(WorkspaceData(tasks: tasks, lists: lists)).write(to: url)
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor func testCalendarChecklistCompletionWritesOnlyTheSelectedItemAndRollsBackOnSaveFailure() throws {
        var task = timed("Plan", start: date(2026, 11, 8, 9), end: date(2026, 11, 8, 10))
        task.recurrence = .daily
        task.reminderDates = [date(2026, 11, 8, 8, 45)]
        task.checklist = [.init(title: "First"), .init(title: "Second")]
        let item = task.checklist[0]
        let (store, dir) = try store(tasks: [task])
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("workspace.json")

        store.setChecklistItemCompleted(taskID: task.id, itemID: item.id, completed: true)
        let saved = try XCTUnwrap(TaskStore(fileURL: url, seed: false).data.tasks.first)
        XCTAssertEqual(saved.checklist.map(\.isCompleted), [true, false])
        XCTAssertEqual(saved.checklist.map(\.id), task.checklist.map(\.id))
        XCTAssertNil(saved.completedAt)
        XCTAssertEqual(CalendarScheduleSnapshot(saved), CalendarScheduleSnapshot(task))
        let bytes = try Data(contentsOf: url)
        store.setChecklistItemCompleted(taskID: task.id, itemID: item.id, completed: true)
        XCTAssertEqual(try Data(contentsOf: url), bytes)

        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        store.setChecklistItemCompleted(taskID: task.id, itemID: item.id, completed: false)
        XCTAssertEqual(store.data.tasks.first?.checklist.map(\.isCompleted), [true, false])
        XCTAssertNotNil(store.storageError)
    }

    @MainActor func testStoreMoveKeepsDurationAndManualReminderThenReloads() throws {
        var task = timed("Meeting", start: date(2026, 11, 8, 9), end: date(2026, 11, 8, 10))
        task.reminderDates = [date(2026, 11, 8, 8, 45), date(2026, 11, 7, 17)]
        task.reminderFollowsSchedule = false
        let (store, dir) = try store(tasks: [task]); defer { try? FileManager.default.removeItem(at: dir) }
        let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .move(start: date(2026, 11, 9, 14), allDay: false), calendar: cal()))
        let saved = try XCTUnwrap(store.data.tasks.first)
        XCTAssertEqual(saved.scheduledDuration?.start, date(2026, 11, 9, 14))
        XCTAssertEqual(saved.dueDate, date(2026, 11, 9, 15))
        XCTAssertEqual(saved.reminderDates.last, date(2026, 11, 9, 13, 45))
        let reloaded = TaskStore(fileURL: dir.appendingPathComponent("workspace.json"), seed: false)
        XCTAssertEqual(reloaded.data.tasks.first?.scheduledDuration, saved.scheduledDuration)
        XCTAssertTrue(reloaded.undoCalendarSchedule(token))
        XCTAssertEqual(reloaded.data.tasks.first?.dueDate, task.dueDate)
    }

    @MainActor func testAllDayMovePreservesWallReminderAcrossDSTInTaskZone() throws {
        let zone = "America/New_York"
        var task = TaskItem(title: "All day", dueDate: date(2026, 3, 6, zone: zone), timeZoneID: zone)
        task.reminderDates = [date(2026, 3, 6, 9, zone: zone), date(2026, 3, 5, 17, zone: zone)]
        task.reminderFollowsSchedule = false
        let (store, dir) = try store(tasks: [task]); defer { try? FileManager.default.removeItem(at: dir) }
        _ = store.scheduleOnCalendar(id: task.id, operation: .move(start: date(2026, 3, 13), allDay: true), calendar: cal())
        let moved = try XCTUnwrap(store.data.tasks.first)
        XCTAssertEqual(moved.dueDate, date(2026, 3, 13, zone: zone))
        XCTAssertEqual(moved.reminderDates, [date(2026, 3, 12, 17, zone: zone), date(2026, 3, 13, 9, zone: zone)])
    }

    @MainActor func testDefaultReminderReanchorsOnTimedToAllDayConversion() throws {
        var task = timed("Automatic", start: date(2026, 11, 8, 9), end: date(2026, 11, 8, 10))
        task.reminderDates = [task.dueDate!]; task.reminderFollowsSchedule = true
        let (store, dir) = try store(tasks: [task]); defer { try? FileManager.default.removeItem(at: dir) }
        store.settings.allDayReminder = .onDay9
        _ = store.scheduleOnCalendar(id: task.id, operation: .move(start: date(2026, 11, 9), allDay: true), calendar: cal())
        XCTAssertEqual(store.data.tasks.first?.reminderDates, [date(2026, 11, 9, 9)])
        XCTAssertEqual(store.data.tasks.first?.reminderFollowsSchedule, true)
    }

    @MainActor func testCalendarUndoPreservesTextAndRestoresRolledNominalExactly() throws {
        var task = TaskItem(title: "Rolled", dueDate: date(2026, 6, 1), timeZoneID: "UTC")
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .months, includesLastDayOfMonth: true, skipWeekends: true)
        task.occurrenceIndex = 2; task.recurrenceNominalDate = date(2026, 5, 31)
        let (store, dir) = try store(tasks: [task]); defer { try? FileManager.default.removeItem(at: dir) }
        let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .move(start: date(2026, 8, 1), allDay: true), calendar: cal()))
        XCTAssertEqual(store.data.tasks.first?.occurrenceIndex, 2)
        XCTAssertEqual(store.data.tasks.first?.recurrenceNominalDate, date(2026, 8, 1))
        var renamed = try XCTUnwrap(store.data.tasks.first); renamed.title = "Edited text"; store.updateTask(renamed)
        XCTAssertTrue(store.undoCalendarSchedule(token))
        XCTAssertEqual(store.data.tasks.first?.title, "Edited text")
        XCTAssertEqual(store.data.tasks.first?.recurrenceNominalDate, date(2026, 5, 31))
        XCTAssertFalse(store.undoCalendarSchedule(token))
    }

    @MainActor func testResizeMinimumUnscheduleAndStaleUndoGuards() throws {
        let task = TaskItem(title: "Point", dueDate: date(2026, 11, 8, 9), hasDueTime: true, recurrence: .weekly, timeZoneID: "UTC")
        let (store, dir) = try store(tasks: [task]); defer { try? FileManager.default.removeItem(at: dir) }
        let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .resizeEnd(date(2026, 11, 8, 8)), calendar: cal()))
        XCTAssertEqual(store.data.tasks.first?.dueDate, date(2026, 11, 8, 9, 15))
        _ = store.scheduleOnCalendar(id: task.id, operation: .unschedule, calendar: cal())
        XCTAssertNil(store.data.tasks.first?.dueDate); XCTAssertNil(store.data.tasks.first?.scheduledDuration)
        XCTAssertEqual(store.data.tasks.first?.recurrence, RepeatRule.none)
        XCTAssertFalse(store.undoCalendarSchedule(token))
    }

    @MainActor func testArchivedAndTrashedTasksRefuseCalendarWrites() throws {
        var list = TaskList(name: "Archive", color: "#123456"); list.isArchived = true
        let archived = TaskItem(title: "Read only", listID: list.id, dueDate: date(2026, 11, 8))
        var trashed = TaskItem(title: "Trash", dueDate: date(2026, 11, 8)); trashed.deletedAt = Date()
        let (store, dir) = try store(tasks: [archived, trashed], lists: [list]); defer { try? FileManager.default.removeItem(at: dir) }
        for task in [archived, trashed] {
            XCTAssertNil(store.scheduleOnCalendar(id: task.id, operation: .move(start: date(2026, 11, 9), allDay: false), calendar: cal()))
        }
        XCTAssertEqual(store.data.tasks, [archived, trashed])
    }
}
