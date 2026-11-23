import XCTest
@testable import TaskovskyCore

final class TagEditorPersistenceTests: XCTestCase {
    @MainActor func testNewTagFailureDoesNotPublishAndExplicitRetrySavesOnce() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("workspace.json")
        let backup = root.appendingPathComponent("original.json")
        let parent = TaskTag(name: "Parent", color: "#123456")
        let workspace = WorkspaceData(tasks: [TaskItem(title: "Existing")], tags: [parent])
        var original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as? [String: Any])
        original["unrelatedFixtureField"] = ["preserve": true]
        let bytes = try JSONSerialization.data(withJSONObject: original)
        try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)

        try FileManager.default.moveItem(at: url, to: backup)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertFalse(store.saveNewTagEditor(name: "  Child  ", color: "#EC6574", parentID: parent.id))
        XCTAssertEqual(store.data, workspace)
        XCTAssertNotNil(store.storageError)
        XCTAssertEqual(try Data(contentsOf: backup), bytes)

        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: backup, to: url)
        XCTAssertTrue(store.saveNewTagEditor(name: "  Child  ", color: "#EC6574", parentID: parent.id))
        XCTAssertEqual(store.data.tags.count, 2)
        XCTAssertEqual(store.data.tags.last?.name, "Child")
        XCTAssertEqual(store.data.tags.last?.color, "#EC6574")
        XCTAssertEqual(store.data.tags.last?.parentID, parent.id)
        XCTAssertEqual(store.data.tasks, workspace.tasks)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
        let saved = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertEqual((json["unrelatedFixtureField"] as? [String: Bool])?["preserve"], true)
        XCTAssertTrue(store.saveNewTagEditor(name: " chILD ", color: "#000000", parentID: nil))
        XCTAssertEqual(try Data(contentsOf: url), saved)
    }
}
