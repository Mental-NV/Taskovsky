import XCTest
@testable import TaskovskyCore

final class ListEditorPersistenceTests: XCTestCase {
    @MainActor func testFailedListCreateAndEditDoNotPublish() throws {
        for creating in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("workspace.json")
            let list = TaskList(name: "Original", color: "#123456")
            let initial = WorkspaceData(tasks: [TaskItem(title: "Keep task", listID: list.id)], lists: [list])
            try JSONEncoder().encode(initial).write(to: file)
            let store = TaskStore(fileURL: file, seed: false)
            try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            if creating { XCTAssertFalse(store.saveListEditor(TaskList(name: "Keep draft", color: "#ABCDEF"), expected: nil)) }
            else { var edited = list; edited.name = "Keep edit"; XCTAssertFalse(store.saveListEditor(edited, expected: list)) }
            XCTAssertEqual(store.data, initial)
            XCTAssertNotNil(store.storageError)
        }
    }
    @MainActor func testRetryCreatesWholeListOnceAndPreservesEditedFields() throws {
        for mode in [TaskListViewMode.list, .board, .timeline] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("workspace.json"), folder = ListFolder(name: "Folder")
            let initial = WorkspaceData(folders: [folder]); let bytes = try JSONEncoder().encode(initial); try bytes.write(to: file)
            let store = TaskStore(fileURL: file, seed: false)
            let draft = TaskList(name: "  Draft  ", color: "#ABCDEF", kind: .note, symbol: "book", viewMode: mode, folderID: folder.id, showsInSmartLists: false)
            try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            XCTAssertFalse(store.saveListEditor(draft, expected: nil))
            try FileManager.default.removeItem(at: file); try bytes.write(to: file)
            XCTAssertTrue(store.saveListEditor(draft, expected: nil))
            XCTAssertEqual(store.data.lists.count, 1)
            var expected = draft; expected.name = "Draft"
            XCTAssertEqual(store.data.lists[0], expected)
            XCTAssertEqual(TaskStore(fileURL: file, seed: false).data, store.data)
            XCTAssertFalse(store.saveListEditor(draft, expected: nil))
            let saved = try Data(contentsOf: file)
            XCTAssertTrue(store.saveListEditor(expected, expected: expected)); XCTAssertEqual(try Data(contentsOf: file), saved)
        }
    }
    @MainActor func testStaleEditorAndDiskRefuseWithoutOverwrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), list = TaskList(name: "Original", color: "#123456")
        let initial = WorkspaceData(lists: [list]); try JSONEncoder().encode(initial).write(to: file)
        let store = TaskStore(fileURL: file, seed: false)
        XCTAssertTrue(store.setListPinned(id: list.id, pinned: true))
        var edit = list; edit.name = "Stale edit"
        let pinned = store.data; let bytes = try Data(contentsOf: file)
        XCTAssertFalse(store.saveListEditor(edit, expected: list)); XCTAssertEqual(store.data, pinned); XCTAssertEqual(try Data(contentsOf: file), bytes)
        var external = pinned; external.lists[0].color = "#654321"; let externalBytes = try JSONEncoder().encode(external); try externalBytes.write(to: file)
        XCTAssertFalse(store.saveListEditor(edit, expected: pinned.lists[0])); XCTAssertEqual(store.data, pinned); XCTAssertEqual(try Data(contentsOf: file), externalBytes)
    }
    @MainActor func testEditPreservesSectionsFlagsAndNormalizesRemovedFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json")
        var list = TaskList(name: "Original", color: "#123456", belowFolders: true, isArchived: true, isPinned: true)
        list.sections = [TaskSection(name: "Section")]
        let initial = WorkspaceData(lists: [list]); try JSONEncoder().encode(initial).write(to: file)
        let store = TaskStore(fileURL: file, seed: false)
        var edit = list; edit.name = "Edited"; edit.color = "#ABCDEF"; edit.folderID = UUID(); edit.sections = []; edit.isPinned = false; edit.isArchived = false
        XCTAssertTrue(store.saveListEditor(edit, expected: list))
        let saved = store.data.lists[0]; XCTAssertEqual(saved.sections, list.sections); XCTAssertTrue(saved.isPinned); XCTAssertTrue(saved.isArchived)
        XCTAssertNil(saved.folderID); XCTAssertFalse(saved.belowFolders); XCTAssertEqual(saved.name, "Edited")
        var blank = saved; blank.name = "   "
        XCTAssertFalse(store.saveListEditor(blank, expected: saved)); XCTAssertEqual(store.data.lists[0], saved)
    }

}
