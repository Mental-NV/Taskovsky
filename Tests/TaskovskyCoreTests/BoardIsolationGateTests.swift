import XCTest
@testable import TaskovskyCore

/// Per-list view mode: each list remembers List vs Board independently
/// across edit, duplicate, and reload. Legacy files decode as List.
final class BoardModeTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor func testViewModeIsPerListAndSurvivesReload() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createList(name: "A", color: "#000000")
        let b = store.createList(name: "B", color: "#111111")
        var listed = try XCTUnwrap(store.data.lists.first { $0.id == a })
        listed.viewMode = .board
        store.updateList(listed)
        XCTAssertEqual(store.data.lists.first { $0.id == a }?.viewMode, .board)
        XCTAssertEqual(store.data.lists.first { $0.id == b }?.viewMode, .list)
        // Rename/edit preserves the mode (the record carries it).
        listed = try XCTUnwrap(store.data.lists.first { $0.id == a })
        listed.name = "A renamed"
        store.updateList(listed)
        XCTAssertEqual(store.data.lists.first { $0.id == a }?.viewMode, .board)
        // Reload preserves each list independently.
        let reloaded = TaskStore(fileURL: dir.appendingPathComponent("workspace.json"), seed: false)
        XCTAssertEqual(reloaded.data.lists.first { $0.id == a }?.viewMode, .board)
        XCTAssertEqual(reloaded.data.lists.first { $0.id == b }?.viewMode, .list)
    }

    func testLegacyListDecodesAsList() throws {
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TaskList(name: "L", color: "#000000"))) as? [String: Any])
        legacy.removeValue(forKey: "viewMode")
        let list = try JSONDecoder().decode(TaskList.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(list.viewMode, .list)
    }
}

/// `--workspace` isolation: flag presence alone isolates; only absolute file
/// paths count as explicit values; a missing/invalid value still isolates via
/// fallback instead of touching real storage.
final class IsolationTests: XCTestCase {
    func testBareFlagIsolatesWithoutValue() {
        let resolution = IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace"])
        XCTAssertTrue(resolution.isIsolated)
        XCTAssertNil(resolution.workspace)
        XCTAssertTrue(resolution.workspaceValueInvalid)
    }

    func testNextFlagIsNotSwallowedAsValue() {
        let resolution = IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "--settings", "/tmp/s.json"])
        XCTAssertTrue(resolution.isIsolated)
        XCTAssertNil(resolution.workspace)
        XCTAssertTrue(resolution.workspaceValueInvalid)
    }

    func testExplicitAbsoluteFileResolves() {
        let resolution = IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "/tmp/qa/workspace.json"])
        XCTAssertTrue(resolution.isIsolated)
        XCTAssertEqual(resolution.workspace?.path, "/tmp/qa/workspace.json")
        XCTAssertFalse(resolution.workspaceValueInvalid)
    }

    func testRelativePathsAndDirectoriesReject() {
        XCTAssertNil(IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "relative/path.json"]).workspace)
        XCTAssertNil(IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "/tmp"]).workspace)
        XCTAssertTrue(IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "relative/path.json"]).isIsolated)
        XCTAssertTrue(IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "/tmp"]).isIsolated)
    }

    func testNoFlagMeansNoIsolation() {
        let resolution = IsolatedLaunch.resolve(arguments: ["Taskovsky"])
        XCTAssertFalse(resolution.isIsolated)
        XCTAssertNil(resolution.workspace)
        XCTAssertFalse(resolution.workspaceValueInvalid)
    }

    func testSettingsResolvesIndependently() {
        let resolution = IsolatedLaunch.resolve(arguments: ["Taskovsky", "--workspace", "/tmp/qa/w.json", "--settings", "/tmp/qa/s.json"])
        XCTAssertEqual(resolution.settings?.path, "/tmp/qa/s.json")
        let missing = IsolatedLaunch.resolve(arguments: ["Taskovsky", "--settings"])
        XCTAssertNil(missing.settings)
        XCTAssertFalse(missing.isIsolated)
    }
}

/// Document-scoped editor undo: switching documents always resets, even when
/// bodies and styles are identical; staying on one document resets only on
/// model change.
final class DocumentUndoGateTests: XCTestCase {
    func testDifferentDocumentAlwaysResets() {
        let a = UUID(), b = UUID()
        XCTAssertTrue(EditorDocumentGate.shouldReset(
            lastDocumentID: a, lastBody: "same", lastRich: nil, documentID: b, body: "same", rich: nil))
        // Identical styles too — still resets.
        let rich = RichBody(text: "same")
        XCTAssertTrue(EditorDocumentGate.shouldReset(
            lastDocumentID: a, lastBody: "same", lastRich: rich, documentID: b, body: "same", rich: rich))
    }

    func testSameDocumentResetsOnlyOnChange() {
        let id = UUID()
        XCTAssertFalse(EditorDocumentGate.shouldReset(
            lastDocumentID: id, lastBody: "same", lastRich: nil, documentID: id, body: "same", rich: nil))
        XCTAssertTrue(EditorDocumentGate.shouldReset(
            lastDocumentID: id, lastBody: "same", lastRich: nil, documentID: id, body: "changed", rich: nil))
        let rich = RichBody(text: "same")
        XCTAssertTrue(EditorDocumentGate.shouldReset(
            lastDocumentID: id, lastBody: "same", lastRich: nil, documentID: id, body: "same", rich: rich))
    }

    func testFirstLoadNeverResets() {
        XCTAssertFalse(EditorDocumentGate.shouldReset(
            lastDocumentID: nil, lastBody: nil, lastRich: nil, documentID: UUID(), body: "x", rich: nil))
    }
}
