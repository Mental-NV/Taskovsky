import XCTest
@testable import TaskovskyCore

final class FilterSaveAtomicTests: XCTestCase {
    @MainActor func testFailedCreateAndEditDoNotPublishPhantomFilters() throws {
        for creating in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("workspace.json")
            let original = TaskFilter(name: "Owned filter", listIDs: [UUID()], isPinned: true,
                                      ruleRoot: .and([.condition(FilterCondition(kind: .tag, tagID: UUID()))]))
            var workspace = WorkspaceData(); workspace.filters = creating ? [] : [original]
            try JSONEncoder().encode(workspace).write(to: file)
            let store = TaskStore(fileURL: file, seed: false)
            try FileManager.default.removeItem(at: file)
            try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
            var replacement = original; replacement.name = "Retained draft"
            if creating { _ = store.createFilter(replacement) } else { store.updateFilter(replacement) }
            XCTAssertEqual(store.data, workspace, "Failed write must not publish a saved filter")
            XCTAssertNotNil(store.storageError)
        }
    }
    @MainActor func testRetryPersistsOnceAndStaleEditDoesNotOverwriteSavedFilter() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), bytes = try JSONEncoder().encode(WorkspaceData())
        try bytes.write(to: file)
        let store = TaskStore(fileURL: file, seed: false), draft = TaskFilter(name: "Draft", tagIDs: [UUID()], isPinned: true)
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertNil(store.createFilter(draft)); XCTAssertTrue(store.data.filters.isEmpty)
        try FileManager.default.removeItem(at: file); try bytes.write(to: file)
        XCTAssertEqual(store.createFilter(draft), draft.id); XCTAssertNil(store.createFilter(draft))
        XCTAssertEqual(store.data.filters, [draft]); XCTAssertEqual(TaskStore(fileURL: file, seed: false).data.filters, [draft])
        var edited = draft; edited.name = "Edited"
        XCTAssertTrue(store.updateFilter(edited, expected: draft))
        let saved = try Data(contentsOf: file)
        var stale = draft; stale.keyword = "stale"
        XCTAssertFalse(store.updateFilter(stale, expected: draft)); XCTAssertEqual(try Data(contentsOf: file), saved)
        XCTAssertEqual(store.data.filters, [edited])
        XCTAssertTrue(store.updateFilter(edited, expected: edited)); XCTAssertEqual(try Data(contentsOf: file), saved)
    }
    @MainActor func testChangedDiskAndMissingOriginalAreRefusedWithoutWrites() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), original = TaskFilter(name: "Original")
        var initial = WorkspaceData(); initial.filters = [original]
        try JSONEncoder().encode(initial).write(to: file)
        let store = TaskStore(fileURL: file, seed: false)
        var different = initial; different.tasks.append(TaskItem(title: "Other saved work"))
        let bytes = try JSONEncoder().encode(different); try bytes.write(to: file)
        var edited = original; edited.name = "Edited"
        XCTAssertFalse(store.updateFilter(edited, expected: original)); XCTAssertEqual(try Data(contentsOf: file), bytes)
        XCTAssertEqual(store.data, initial)
        XCTAssertFalse(store.updateFilter(TaskFilter(name: "Deleted"), expected: original))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    @MainActor func testStorePreservesUnknownRawDataAndRejectsConcurrentPinChange() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json")
        let unknown = "\"future\": { \"precision\": 123456789012345678901 }"
        let raw = "{\"tasks\":[],\"lists\":[],\"tags\":[],\"filters\":[],\"templates\":[]," + unknown + "}"
        try Data(raw.utf8).write(to: file)
        let store = TaskStore(fileURL: file, seed: false), original = TaskFilter(name: "Owned")
        XCTAssertEqual(store.createFilter(original), original.id)
        XCTAssertTrue(String(decoding: try Data(contentsOf: file), as: UTF8.self).contains(unknown))
        var pinned = original; pinned.isPinned = true
        XCTAssertTrue(store.updateFilter(pinned, expected: original))
        let saved = try Data(contentsOf: file)
        XCTAssertTrue(String(decoding: saved, as: UTF8.self).contains(unknown))
        var stale = original; stale.name = "Stale title"
        XCTAssertFalse(store.updateFilter(stale, expected: original))
        XCTAssertEqual(try Data(contentsOf: file), saved); XCTAssertEqual(store.data.filters, [pinned])
    }

}
