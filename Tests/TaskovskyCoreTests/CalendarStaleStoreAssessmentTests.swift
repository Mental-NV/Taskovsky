import XCTest
@testable import TaskovskyCore

// Assessment only: expected failures document a candidate defect. No product changes.
final class CalendarStaleStoreAssessmentTests: XCTestCase {
    @MainActor func testCalendarMoveMustNotOverwriteOtherStoreTitle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Original", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true)
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        let stale = TaskStore(fileURL: url, seed: false)
        let other = TaskStore(fileURL: url, seed: false)
        var edited = other.data.tasks[0]
        edited.title = "Saved independently"
        other.updateTask(edited)
        XCTAssertNil(other.storageError)
        let saved = try Data(contentsOf: url)
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: saved).tasks[0].title, "Saved independently")
        let token = stale.scheduleOnCalendar(id: task.id, operation: .move(start: Date(timeIntervalSince1970: 2_000_003_600), allDay: false))
        // Conservative safe-refusal contract; rebasing could be a separately designed alternative.
        XCTAssertNil(token)
        XCTAssertEqual(try Data(contentsOf: url), saved)
        XCTAssertEqual(stale.data.tasks[0], task)
    }

    @MainActor func testCalendarMoveMustPreserveUnknownTaskData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Owned fixture", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [task]))) as? [String: Any])
        var tasks = try XCTUnwrap(raw["tasks"] as? [[String: Any]])
        tasks[0]["futureOwnedFixtureField"] = ["mustSurvive": true]
        raw["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: raw).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertFalse(store.needsRecovery)
        let token = store.scheduleOnCalendar(id: task.id, operation: .move(start: Date(timeIntervalSince1970: 2_000_003_600), allDay: false))
        XCTAssertNotNil(token, "Control: the current implementation accepts this move")
        XCTAssertNotEqual(store.data.tasks[0].dueDate, task.dueDate)
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let afterTasks = try XCTUnwrap(after["tasks"] as? [[String: Any]])
        XCTAssertEqual((afterTasks[0]["futureOwnedFixtureField"] as? [String: Bool])?["mustSurvive"], true)
    }
}
