import XCTest
import TaskovskyDomain

final class MobileContractTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!; value.firstWeekday = 2
        return value
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private var now: Date { date("2026-11-09T12:00:00Z") }
    private func ids(_ tasks: [TaskItem]) -> [UUID] { tasks.map(\.id) }

    func testTodayAndWeekIncludeOverdueWhileSavedDatesStayBounded() {
        let overdue = TaskItem(title: "Overdue", dueDate: date("2026-11-01T10:00:00Z"))
        let today = TaskItem(title: "Today", dueDate: date("2026-11-09T10:00:00Z"))
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: date("2026-11-10T10:00:00Z"))
        let boundary = TaskItem(title: "Outside week", dueDate: date("2026-11-16T00:00:00Z"))
        let data = WorkspaceData(tasks: [overdue, today, tomorrow, boundary])
        XCTAssertEqual(ids(TaskDestination.today.matchingTasks(in: data, now: now, calendar: calendar)), [overdue.id, today.id])
        XCTAssertEqual(ids(TaskDestination.week.matchingTasks(in: data, now: now, calendar: calendar)), [overdue.id, today.id, tomorrow.id])
        let filter = TaskFilter(name: "Today", dateRule: .today)
        XCTAssertFalse(filter.matches(overdue, lists: [], now: now, calendar: calendar))
        XCTAssertTrue(filter.matches(today, lists: [], now: now, calendar: calendar))
    }

    func testHistoryAndArchiveExceptionsArePreserved() {
        let archived = TaskList(name: "Archived", color: "#000000", isArchived: true)
        let excluded = TaskList(name: "Excluded", color: "#000000", showsInSmartLists: false)
        let hidden = TaskItem(title: "Hidden", listID: excluded.id)
        var history = TaskItem(title: "Archived history", listID: archived.id); history.completedAt = now
        var trashed = TaskItem(title: "Trashed"); trashed.deletedAt = now
        let data = WorkspaceData(tasks: [hidden, history, trashed], lists: [archived, excluded])
        XCTAssertTrue(TaskDestination.all.matchingTasks(in: data, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.completed.matchingTasks(in: data, now: now, calendar: calendar)), [history.id])
        XCTAssertEqual(ids(TaskDestination.list(archived.id).matchingTasks(in: data, showHistory: true, now: now, calendar: calendar)), [history.id])
        XCTAssertTrue(TaskDestination.list(archived.id).matchingTasks(in: data, showHistory: false, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.trash.matchingTasks(in: data, now: now, calendar: calendar)), [trashed.id])
    }

    func testParentTagNavigationDiffersFromSelectedTagFilter() {
        let parent = TaskTag(name: "Parent", color: "#000000")
        let child = TaskTag(name: "Child", color: "#000000", parentID: parent.id)
        var task = TaskItem(title: "Child tagged"); task.tagIDs = [child.id]
        let data = WorkspaceData(tasks: [task], tags: [parent, child])
        XCTAssertEqual(ids(TaskDestination.tag(parent.id).matchingTasks(in: data, now: now, calendar: calendar)), [task.id])
        XCTAssertFalse(TaskFilter(name: "Direct tag", tagIDs: [parent.id]).matches(task, lists: [], now: now, calendar: calendar))
    }

    func testMissingFilterRemainsEmptyAndExistingFilterUsesOwnStatus() {
        var task = TaskItem(title: "History"); task.completedAt = now
        let filter = TaskFilter(name: "Completed", status: .completed)
        let data = WorkspaceData(tasks: [task], filters: [filter])
        XCTAssertTrue(TaskDestination.filter(UUID()).matchingTasks(in: data, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.filter(filter.id).matchingTasks(in: data, showHistory: false, now: now, calendar: calendar)), [task.id])
    }

    func testTaskZoneDefinesRelativeDateMembership() {
        var task = TaskItem(title: "Tokyo tomorrow", dueDate: date("2026-11-09T16:00:00Z"))
        task.timeZoneID = "Asia/Tokyo"
        let data = WorkspaceData(tasks: [task])
        XCTAssertFalse(TaskDestination.today.includes(task, data: data, now: now, calendar: calendar))
        XCTAssertTrue(TaskDestination.tomorrow.includes(task, data: data, now: now, calendar: calendar))
    }

    func testLegacyMonthAndLeapAnchorsSurvivePureExtraction() {
        let feb = LegacyRecurrence.nextDate(after: date("2026-01-31T10:00:00Z"), rule: .monthly, anchorDay: 31, calendar: calendar)!
        XCTAssertEqual(feb, date("2026-02-28T10:00:00Z"))
        XCTAssertEqual(LegacyRecurrence.nextDate(after: feb, rule: .monthly, anchorDay: 31, calendar: calendar), date("2026-03-31T10:00:00Z"))
        XCTAssertEqual(LegacyRecurrence.nextDate(after: date("2024-02-29T10:00:00Z"), rule: .yearly, anchorDay: 29, anchorMonth: 2, calendar: calendar), date("2025-02-28T10:00:00Z"))
    }

    func testLegacyDailyKeepsWallClockAcrossDST() {
        var local = calendar; local.timeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(LegacyRecurrence.nextDate(after: date("2026-03-07T14:00:00Z"), rule: .daily, calendar: local), date("2026-03-08T13:00:00Z"))
    }

    func testPlainRichIdentityAndPreciseScheduleRemainPortable() {
        let composed = "é", decomposed = "e\u{301}"
        XCTAssertNil(RichBody(text: composed).valid(for: decomposed))
        var task = TaskItem(title: "Precise", dueDate: now)
        task.hasDueTime = true
        task.scheduledDuration = TaskDurationRange(start: now.addingTimeInterval(-301.125), end: now, isAllDay: false)
        let draft = CalendarScheduleDraft(task: task, focus: now, hourly: true, calendar: calendar)
        XCTAssertNil(draft.operation)
        XCTAssertEqual(draft.start, task.scheduledDuration?.start)
    }
}
