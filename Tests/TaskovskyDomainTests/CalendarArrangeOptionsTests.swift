import XCTest
import TaskovskyDomain

final class CalendarArrangeOptionsTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))! }

    func testAllVisibilityCombinationsPreserveOrderDefaultsAndData() throws {
        let past = calendar.date(byAdding: .day, value: -1, to: now)!
        let future = calendar.date(byAdding: .day, value: 1, to: now)!
        var undatedNote = TaskItem(title: "Undated note"); undatedNote.kind = .note
        var overdueNote = TaskItem(title: "Overdue note", dueDate: past); overdueNote.kind = .note
        var completed = TaskItem(title: "Completed"); completed.completedAt = now
        var rejected = TaskItem(title: "Won't do"); rejected.wontDoAt = now
        var deleted = TaskItem(title: "Trash"); deleted.deletedAt = now
        var archived = TaskList(name: "Archive", color: "#123456"); archived.isArchived = true
        let data = WorkspaceData(tasks: [TaskItem(title: "Undated task"), undatedNote,
            TaskItem(title: "Overdue task", dueDate: past), overdueNote,
            TaskItem(title: "Today", dueDate: now), TaskItem(title: "Future", dueDate: future),
            completed, rejected, deleted, TaskItem(title: "Archived", listID: archived.id)], lists: [archived])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(data)
        for overdue in [false, true] {
            let legacy = TaskCalendarProjection.arrangementTasks(data: data, options: .init(), overdue: overdue, now: now, calendar: calendar)
            XCTAssertEqual(legacy.map(\.title), overdue ? ["Undated task", "Undated note", "Overdue task", "Overdue note"] : ["Undated task", "Undated note"])
            for undated in [false, true] {
                for notes in [false, true] {
                    let result = TaskCalendarProjection.arrangementTasks(data: data, options: .init(), overdue: overdue, now: now, calendar: calendar, undated: undated, showNotes: notes)
                    let expected = legacy.filter { (undated || $0.dueDate != nil) && (notes || $0.kind != .note) }
                    XCTAssertEqual(result.map(\.id), expected.map(\.id))
                }
            }
        }
        XCTAssertEqual(try encoder.encode(data), before)
    }

    func testVisibilityOptionsComposeWithExplicitSourcesAndCalendarTagConstraint() {
        let list = TaskList(name: "Work", color: "#123456")
        let tag = TaskTag(name: "Planning", color: "#654321")
        var task = TaskItem(title: "Tagged task", listID: list.id); task.tagIDs = [tag.id]
        var note = TaskItem(title: "Tagged note", listID: list.id); note.tagIDs = [tag.id]; note.kind = .note
        var inbox = TaskItem(title: "Tagged Inbox"); inbox.tagIDs = [tag.id]
        let plain = TaskItem(title: "Plain task", listID: list.id)
        let data = WorkspaceData(tasks: [task, note, inbox, plain], lists: [list], tags: [tag])
        var options = TaskCalendarOptions(); options.tagIDs = [tag.id]
        XCTAssertEqual(TaskCalendarProjection.arrangementTasks(data: data, options: options, calendar: calendar, selection: .list(list.id), showNotes: false).map(\.id), [task.id])
        XCTAssertEqual(TaskCalendarProjection.arrangementTasks(data: data, options: options, calendar: calendar, selection: .inbox, showNotes: false).map(\.id), [inbox.id])
        XCTAssertTrue(TaskCalendarProjection.arrangementTasks(data: data, options: options, calendar: calendar, selection: .sources(listIDs: [list.id], inbox: false), undated: false).isEmpty)
    }
}
