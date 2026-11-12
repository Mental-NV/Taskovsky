import XCTest
@testable import TaskovskyCore

final class CalendarCreationAtomicTests: XCTestCase {
    @MainActor func testFailedCalendarCreationDoesNotPublishTaskOrTagAndRetryPreservesShape() throws {
        for allDay in [false, true] {
            for position in TaskPosition.allCases {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: directory) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("workspace.json")
                let list = TaskList(name: "Owned", color: "#123456")
                let workspace = WorkspaceData(tasks: [TaskItem(title: "Existing")], lists: [list])
                let bytes = try JSONEncoder().encode(workspace)
                try bytes.write(to: url)
                let store = TaskStore(fileURL: url, seed: false)
                store.settings.defaultAddTo = position
                store.settings.defaultListID = list.id
                store.settings.urlParsing = false
                store.settings.removeTagText = true
                let calendar = store.settings.calendar
                let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15))!
                let start = allDay ? day : day.addingTimeInterval(36_000.25)
                let end = allDay ? calendar.date(byAdding: .day, value: 2, to: start)! : start.addingTimeInterval(300)
                let range = TaskDurationRange(start: start, end: end, isAllDay: allDay)
                let listID = allDay ? list.id : nil
                try FileManager.default.removeItem(at: url)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                XCTAssertNil(store.createCalendarTask(title: "Owned Calendar #OwnedNewTag", listID: listID, duration: range))
                XCTAssertEqual(store.data, workspace)
                XCTAssertNotNil(store.storageError)
                XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
                try FileManager.default.removeItem(at: url)
                try bytes.write(to: url)
                let id = try XCTUnwrap(store.createCalendarTask(title: "Owned Calendar #OwnedNewTag", listID: listID, duration: range))
                XCTAssertEqual(store.data.tasks.count, 2)
                XCTAssertEqual(store.data.tags.count, 1)
                XCTAssertEqual(position == .top ? store.data.tasks.first?.id : store.data.tasks.last?.id, id)
                let created = try XCTUnwrap(store.data.tasks.first { $0.id == id })
                XCTAssertEqual(created.title, "Owned Calendar")
                XCTAssertEqual(created.listID, listID)
                XCTAssertEqual(created.scheduledDuration, range)
                XCTAssertEqual(created.dueDate, end)
                XCTAssertEqual(created.hasDueTime, !allDay)
                XCTAssertEqual(created.tagIDs, store.data.tags.map(\.id))
                XCTAssertEqual(created.reminderDates, TaskSchedulePolicy.defaultReminderDates(due: end, hasTime: !allDay, settings: store.settings, calendar: calendar))
                XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
            }
        }
    }

    @MainActor func testInvalidAndRecoveryBlockedCalendarCreationLeavesBytesUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("workspace.json")
        let bytes = try JSONEncoder().encode(WorkspaceData())
        try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let range = TaskDurationRange(start: now, end: now.addingTimeInterval(300))
        XCTAssertNil(store.createCalendarTask(title: "  ", listID: nil, duration: range))
        XCTAssertNil(store.createCalendarTask(title: "Invalid", listID: nil, duration: .init(start: now, end: now.addingTimeInterval(-60))))
        XCTAssertNil(store.createCalendarTask(title: "Invalid", listID: nil, duration: .init(start: Date(timeIntervalSinceReferenceDate: .nan), end: now, isAllDay: true)))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertTrue(store.data.tasks.isEmpty)
        let corrupt = Data("{unreadable owned workspace".utf8)
        try corrupt.write(to: url)
        let blocked = TaskStore(fileURL: url, seed: false)
        let original = blocked.data
        XCTAssertTrue(blocked.needsRecovery)
        XCTAssertNil(blocked.createCalendarTask(title: "Never publish #New", listID: nil, duration: range))
        XCTAssertEqual(blocked.data, original)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
}
