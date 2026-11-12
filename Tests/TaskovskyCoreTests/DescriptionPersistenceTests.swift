import XCTest
@testable import TaskovskyCore
import TaskovskyWorkspace

final class DescriptionPersistenceTests: XCTestCase {
    @MainActor func testFailedSaveRetainsSavedModelAndExplicitRetryWorks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Task", body: "old")
        let initial = WorkspaceData(tasks: [task]), old = DescriptionSnapshot(body: "old", rich: nil)!, new = DescriptionSnapshot(body: "new", rich: RichBody(text: "new"))!
        let bytes = try JSONEncoder().encode(initial); try bytes.write(to: file)
        let store = TaskStore(fileURL: file, seed: false)
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertFalse(store.saveDescription(taskID: task.id, content: new, expected: old)); XCTAssertEqual(store.data, initial)
        try FileManager.default.removeItem(at: file); try bytes.write(to: file)
        XCTAssertTrue(store.saveDescription(taskID: task.id, content: new, expected: old))
        XCTAssertEqual(DescriptionSnapshot(body: store.data.tasks[0].body, rich: store.data.tasks[0].richBody), new)
        XCTAssertEqual(TaskStore(fileURL: file, seed: false).data, store.data)
    }
    @MainActor func testUnrelatedEditsSurviveAndChangedBodyRefuses() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Task", body: "old")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: file)
        let store = TaskStore(fileURL: file, seed: false), old = DescriptionSnapshot(body: "old", rich: nil)!, new = DescriptionSnapshot(body: "new", rich: nil)!
        var current = task; current.title = "Concurrent title"; current.dueDate = Date(timeIntervalSince1970: 1_900_000_000); current.hasDueTime = true; store.updateTask(current)
        XCTAssertTrue(store.saveDescription(taskID: task.id, content: new, expected: old))
        XCTAssertEqual(store.data.tasks[0].title, current.title); XCTAssertEqual(store.data.tasks[0].dueDate, current.dueDate)
        let bytes = try Data(contentsOf: file)
        XCTAssertFalse(store.saveDescription(taskID: task.id, content: old, expected: old)); XCTAssertEqual(try Data(contentsOf:file),bytes)
    }
}
