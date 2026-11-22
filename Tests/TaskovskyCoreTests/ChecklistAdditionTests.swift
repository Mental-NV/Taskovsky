import Foundation
import XCTest
@testable import TaskovskyCore

final class ChecklistAdditionTests: XCTestCase {
    @MainActor
    func testWriteFailureDoesNotPublishChecklistAndRetryAppendsExactlyOnce() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let workspaceURL = folder.appendingPathComponent("workspace.json")
        let store = TaskStore(fileURL: workspaceURL, seed: false)
        let taskID = store.createTask(title: "Synthetic active task")
        let siblingID = store.createTask(title: "Synthetic sibling")
        XCTAssertTrue(store.addChecklistItem(taskID: taskID, title: "Existing item"))
        let originalState = store.data
        let originalBytes = try Data(contentsOf: workspaceURL)
        let originalURL = folder.appendingPathComponent("original.json")

        // A nonempty directory occupying the destination makes an atomic file
        // replacement fail without depending on the runner's permissions.
        try FileManager.default.moveItem(at: workspaceURL, to: originalURL)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: false)
        try Data("sentinel".utf8).write(to: workspaceURL.appendingPathComponent("keep.txt"))

        XCTAssertFalse(store.addChecklistItem(taskID: taskID, title: "  Retry me  "))
        XCTAssertEqual(store.data, originalState)
        XCTAssertNotNil(store.storageError)
        XCTAssertEqual(try Data(contentsOf: originalURL), originalBytes)

        try FileManager.default.removeItem(at: workspaceURL)
        try FileManager.default.moveItem(at: originalURL, to: workspaceURL)
        XCTAssertTrue(store.addChecklistItem(taskID: taskID, title: "  Retry me  "))
        XCTAssertNil(store.storageError)
        let reloaded = TaskStore(fileURL: workspaceURL, seed: false)
        let items = try XCTUnwrap(reloaded.data.tasks.first { $0.id == taskID }).checklist
        XCTAssertEqual(items.map(\.title), ["Existing item", "Retry me"])
        XCTAssertFalse(items[1].isCompleted)
        XCTAssertEqual(reloaded.data.tasks.first { $0.id == siblingID },
                       originalState.tasks.first { $0.id == siblingID })
    }

    @MainActor
    func testBlankMissingAndNoteDoNotWrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let workspaceURL = folder.appendingPathComponent("workspace.json")
        let store = TaskStore(fileURL: workspaceURL, seed: false)
        let taskID = store.createTask(title: "Synthetic task")
        let noteID = store.createTask(title: "Synthetic note", kind: .note)
        let before = try Data(contentsOf: workspaceURL)

        XCTAssertFalse(store.addChecklistItem(taskID: taskID, title: " \n "))
        XCTAssertFalse(store.addChecklistItem(taskID: UUID(), title: "Missing"))
        XCTAssertFalse(store.addChecklistItem(taskID: noteID, title: "Note"))
        XCTAssertEqual(try Data(contentsOf: workspaceURL), before)
    }
}
