import XCTest
@testable import TaskovskyCore

final class HierarchyPersistenceTests: XCTestCase {
    @MainActor func testFailedChildCreationAndCrossListReparentDoNotPublish() throws {
        for creating in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("workspace.json")
            let list = TaskList(name: "Target", color: "#123456")
            let parent = TaskItem(title: "Parent", listID: list.id)
            let child = TaskItem(title: "Child")
            let grandchild = TaskItem(title: "Grandchild", parentID: child.id)
            let initial = WorkspaceData(tasks: [parent, child, grandchild], lists: [list])
            try JSONEncoder().encode(initial).write(to: file)
            let store = TaskStore(fileURL: file, seed: false)
            try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            if creating { XCTAssertNil(store.addSubtask(to: parent.id, title: "Keep my child draft")) }
            else { XCTAssertFalse(store.setTaskParent(id: child.id, parentID: parent.id)) }
            XCTAssertEqual(store.data, initial)
            XCTAssertNotNil(store.storageError)
        }
    }
    @MainActor func testRetryPersistsChildOnceWithPlacementAndSubtreeMove() throws {
        for position in [TaskPosition.top, .bottom] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("workspace.json"), list = TaskList(name: "Target", color: "#123456")
            let parent = TaskItem(title: "Parent", listID: list.id), child = TaskItem(title: "Child")
            let grandchild = TaskItem(title: "Grandchild", parentID: child.id)
            let initial = WorkspaceData(tasks: [parent, child, grandchild], lists: [list])
            let bytes = try JSONEncoder().encode(initial); try bytes.write(to: file)
            let store = TaskStore(fileURL: file, seed: false); store.settings.defaultAddTo = position
            try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            XCTAssertNil(store.addSubtask(to: parent.id, title: "  Keep title  "))
            try FileManager.default.removeItem(at: file); try bytes.write(to: file)
            let id = try XCTUnwrap(store.addSubtask(to: parent.id, title: "  Keep title  "))
            XCTAssertEqual(store.data.tasks.count, 4)
            XCTAssertEqual(position == .top ? store.data.tasks.first?.id : store.data.tasks.last?.id, id)
            let created = try XCTUnwrap(store.data.tasks.first { $0.id == id })
            XCTAssertEqual(created.title, "Keep title"); XCTAssertEqual(created.parentID, parent.id); XCTAssertEqual(created.listID, list.id)
            XCTAssertNil(created.dueDate); XCTAssertNil(created.completedAt)
            XCTAssertTrue(store.setTaskParent(id: child.id, parentID: parent.id))
            XCTAssertEqual(store.data.tasks.first { $0.id == grandchild.id }?.listID, list.id)
            XCTAssertEqual(TaskStore(fileURL: file, seed: false).data, store.data)
            let saved = try Data(contentsOf: file)
            XCTAssertTrue(store.setTaskParent(id: child.id, parentID: parent.id)); XCTAssertEqual(try Data(contentsOf: file), saved)
            XCTAssertFalse(store.setTaskParent(id: parent.id, parentID: grandchild.id)); XCTAssertEqual(try Data(contentsOf: file), saved)
        }
    }
    @MainActor func testExistingNoteAndArchivedDetachBehaviorIsPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json")
        var archived = TaskList(name: "Archived", color: "#123456"); archived.isArchived = true
        let parent = TaskItem(title: "Parent")
        let note = TaskItem(title: "Note", kind: .note)
        var child = TaskItem(title: "Archived child", listID: archived.id, parentID: parent.id); child.deletedAt = Date()
        let initial = WorkspaceData(tasks: [parent, note, child], lists: [archived])
        try JSONEncoder().encode(initial).write(to: file)
        let store = TaskStore(fileURL: file, seed: false)
        XCTAssertTrue(store.setTaskParent(id: note.id, parentID: parent.id))
        XCTAssertTrue(store.setTaskParent(id: child.id, parentID: nil))
        XCTAssertNil(store.data.tasks.first { $0.id == child.id }?.parentID)
        XCTAssertEqual(store.data.tasks.first { $0.id == note.id }?.parentID, parent.id)
        XCTAssertEqual(TaskStore(fileURL: file, seed: false).data, store.data)
    }
    @MainActor func testStaleDiskRefusesWithoutOverwritingOtherWork() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), parent = TaskItem(title: "Parent"), child = TaskItem(title: "Child")
        let initial = WorkspaceData(tasks: [parent, child]); try JSONEncoder().encode(initial).write(to: file)
        let store = TaskStore(fileURL: file, seed: false)
        var changed = initial; changed.tasks[0].title = "Other writer"
        let bytes = try JSONEncoder().encode(changed); try bytes.write(to: file)
        XCTAssertNil(store.addSubtask(to: parent.id, title: "Retain draft"))
        XCTAssertFalse(store.setTaskParent(id: child.id, parentID: parent.id))
        XCTAssertEqual(store.data, initial); XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

}
