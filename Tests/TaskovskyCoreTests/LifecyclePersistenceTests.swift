import XCTest
@testable import TaskovskyCore

final class LifecyclePersistenceTests: XCTestCase {
    @MainActor func testFailedRecurringCompletionAndUndoKeepPublishedState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("workspace.json")
        var task = TaskItem(title: "Owned recurring", dueDate: Date(timeIntervalSince1970: 1_794_528_000))
        task.recurrence = .daily
        let initial = WorkspaceData(tasks: [task])
        let bytes = try JSONEncoder().encode(initial); try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertFalse(store.toggleComplete(id: task.id))
        XCTAssertEqual(store.data, initial)
        XCTAssertNotNil(store.storageError)
        try FileManager.default.removeItem(at: url); try bytes.write(to: url)
        store.toggleComplete(id: task.id)
        XCTAssertNotNil(store.data.tasks.first { $0.id == task.id }?.completedAt)
        XCTAssertEqual(store.data.tasks.filter { $0.recurrenceSourceID == task.id }.count, 1)
        let completed = store.data
        let completedBytes = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertFalse(store.undoCompletion(id: task.id))
        XCTAssertEqual(store.data, completed)
        try FileManager.default.removeItem(at: url); try completedBytes.write(to: url)
        store.undoCompletion(id: task.id)
        XCTAssertNil(store.data.tasks.first { $0.id == task.id }?.completedAt)
        XCTAssertFalse(store.data.tasks.contains { $0.recurrenceSourceID == task.id })
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
    }

    @MainActor func testRefusedLifecycleCommandsReturnFalseWithoutWriting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("workspace.json")
        var list = TaskList(name: "Owned archive", color: "#123456"); list.isArchived = true
        let task = TaskItem(title: "Archived", listID: list.id)
        let data = WorkspaceData(tasks: [task], lists: [list])
        let bytes = try JSONEncoder().encode(data); try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        for id in [UUID(), task.id] {
            XCTAssertFalse(store.toggleComplete(id: id))
            XCTAssertFalse(store.undoCompletion(id: id))
            XCTAssertFalse(store.markWontDo(id: id))
            XCTAssertFalse(store.reopenTask(id: id))
            if id != task.id { XCTAssertFalse(store.trashTask(id: id)) }
            XCTAssertFalse(store.restoreTask(id: id))
        }
        XCTAssertEqual(store.data, data)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    @MainActor func testFailedTrashRestoreDuplicateAndMoveDoNotPublish() throws {
        for action in ["trash", "restore", "duplicate", "move"] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("workspace.json")
            let list = TaskList(name: "Owned destination", color: "#123456")
            var task = TaskItem(title: "Owned task")
            if action == "restore" { task.deletedAt = Date() }
            let initial = WorkspaceData(tasks: [task], lists: [list])
            let bytes = try JSONEncoder().encode(initial); try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            switch action {
            case "trash": XCTAssertFalse(store.trashTask(id: task.id))
            case "restore": XCTAssertFalse(store.restoreTask(id: task.id))
            case "duplicate": XCTAssertNil(store.duplicateTask(id: task.id))
            default: XCTAssertFalse(store.moveTasksToList(ids: [task.id], listID: list.id))
            }
            XCTAssertEqual(store.data, initial, action)
            XCTAssertNotNil(store.storageError, action)
            try FileManager.default.removeItem(at: url); try bytes.write(to: url)
            switch action {
            case "trash":
                XCTAssertTrue(store.trashTask(id: task.id)); XCTAssertNotNil(store.data.tasks.first?.deletedAt)
            case "restore":
                XCTAssertTrue(store.restoreTask(id: task.id)); XCTAssertNil(store.data.tasks.first?.deletedAt)
            case "duplicate":
                XCTAssertNotNil(store.duplicateTask(id: task.id)); XCTAssertEqual(store.data.tasks.count, 2)
            default:
                XCTAssertTrue(store.moveTasksToList(ids: [task.id], listID: list.id)); XCTAssertEqual(store.data.tasks.first?.listID, list.id)
            }
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data, action)
        }
    }
}
