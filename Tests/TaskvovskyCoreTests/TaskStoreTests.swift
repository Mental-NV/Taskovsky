import XCTest
@testable import TaskvovskyCore

final class TaskStoreTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
    }

    @MainActor func testPersistenceAndCleanup() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "blue")
        let tag = store.createTag(name: "Focus", color: "red")
        let id = store.createTask(title: "Write", listID: list)
        var task = try XCTUnwrap(store.data.tasks.first)
        task.tagIDs = [tag]; store.updateTask(task)
        store.trashTask(id: id)
        XCTAssertNotNil(store.data.tasks.first?.deletedAt)
        store.restoreTask(id: id)
        store.deleteList(id: list); store.deleteTag(id: tag)
        let loaded = TaskStore(fileURL: url, seed: false)
        let saved = try XCTUnwrap(loaded.data.tasks.first)
        XCTAssertNil(saved.deletedAt); XCTAssertNil(saved.listID); XCTAssertTrue(saved.tagIDs.isEmpty)
        XCTAssertNil(loaded.storageError)
    }

    @MainActor func testUnreadableWorkspaceIsPreservedUntilExplicitRecovery() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("{not valid json".utf8)
        try corrupt.write(to: url)
        let store = TaskStore(fileURL: url, seed: true)
        XCTAssertTrue(store.data.tasks.isEmpty)
        XCTAssertNotNil(store.storageError)
        store.createTask(title: "Unsaved edit")
        store.save()
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        XCTAssertTrue(store.storageError?.contains("not being saved") == true)
        let backup = try XCTUnwrap(store.recoverUnreadableWorkspace())
        XCTAssertEqual(try Data(contentsOf: backup), corrupt)
        XCTAssertNil(store.storageError)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data.tasks.first?.title, "Unsaved edit")
    }

    @MainActor func testRecurringCompletionPreservesHistoryAndAvoidsDuplicates() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Monthly", dueDate: Date(timeIntervalSince1970: 1_706_709_600))
        var task = try XCTUnwrap(store.data.tasks.first)
        task.recurrence = .monthly; task.reminderDate = task.dueDate!.addingTimeInterval(-3600); task.checklist = [ChecklistItem(title: "One", isCompleted: true)]
        store.updateTask(task); store.toggleComplete(id: id)
        XCTAssertEqual(store.data.tasks.count, 2)
        let next = try XCTUnwrap(store.data.tasks.first { $0.id != id })
        XCTAssertNil(next.completedAt); XCTAssertEqual(next.reminderDate, next.dueDate?.addingTimeInterval(-3600)); XCTAssertFalse(next.checklist[0].isCompleted)
        let reloaded = TaskStore(fileURL: url, seed: false)
        reloaded.toggleComplete(id: id); reloaded.toggleComplete(id: id)
        XCTAssertEqual(reloaded.data.tasks.count, 2)
    }

    @MainActor func testStarterDataAndNormalizedNames() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url)
        let plan = try XCTUnwrap(store.data.tasks.first { $0.title == "Plan your week" })
        XCTAssertTrue(Calendar.current.isDateInToday(try XCTUnwrap(plan.dueDate)))
        XCTAssertEqual(plan.checklist.count, 2)
        XCTAssertTrue(store.data.tasks.contains { $0.listID == nil && $0.kind == .task })
        XCTAssertTrue(store.data.tasks.contains { $0.kind == .note })
        let tag = store.createTag(name: "  # Focus  ", color: "red")
        XCTAssertEqual(tag, store.createTag(name: "focus", color: "blue"))
        XCTAssertEqual(store.data.tags.filter { $0.name.lowercased() == "focus" }.count, 1)
        let taskID = store.createTask(title: "  Example  ")
        XCTAssertEqual(store.data.tasks.first { $0.id == taskID }?.title, "Example")
    }

    func testCalendarRecurrenceAcrossWeekendsAndShortMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
        }
        let monday = try XCTUnwrap(TaskStore.nextDate(after: date(2024, 3, 1), rule: .weekdays, calendar: calendar))
        XCTAssertEqual(monday, date(2024, 3, 4))
        let february = try XCTUnwrap(TaskStore.nextDate(after: date(2024, 1, 31), rule: .monthly, calendar: calendar))
        XCTAssertEqual(february, date(2024, 2, 29))
        let march = try XCTUnwrap(TaskStore.nextDate(after: february, rule: .monthly, anchorDay: 31, calendar: calendar))
        XCTAssertEqual(march, date(2024, 3, 31))
        let nextYear = try XCTUnwrap(TaskStore.nextDate(after: date(2024, 2, 29), rule: .yearly, calendar: calendar))
        XCTAssertEqual(nextYear, date(2025, 2, 28))
    }
}
