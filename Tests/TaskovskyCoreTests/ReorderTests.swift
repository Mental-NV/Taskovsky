import XCTest
@testable import TaskovskyCore

/// Regression tests for atomic task moves and task/list reordering.
///
/// Every mutating API validates the whole batch before touching anything:
/// a single bad ID aborts with no partial mutation and no save. Order is the
/// stored array order, so reordering needs no schema change and legacy files
/// (which simply lack newer keys) keep working.
final class ReorderTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
    }

    @MainActor private func titles(_ store: TaskStore) -> [String] {
        store.data.tasks.map(\.title)
    }

    @MainActor func testMoveTasksToListMovesBatchAtomically() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "#526BF5")
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")

        XCTAssertTrue(store.moveTasksToList(ids: [a, b], listID: list))
        XCTAssertEqual(store.data.tasks.first { $0.id == a }?.listID, list)
        XCTAssertEqual(store.data.tasks.first { $0.id == b }?.listID, list)

        // Other fields are untouched by a move.
        XCTAssertEqual(store.data.tasks.first { $0.id == a }?.title, "A")
        XCTAssertNil(store.data.tasks.first { $0.id == a }?.completedAt)

        // Persisted across reload.
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == a }?.listID, list)
    }

    @MainActor func testMoveTasksToListRejectsBadBatchWithoutMutation() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "#526BF5")
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")
        let missing = UUID()

        XCTAssertFalse(store.moveTasksToList(ids: [a, missing], listID: list))
        XCTAssertNil(store.data.tasks.first { $0.id == a }?.listID)
        XCTAssertNil(store.data.tasks.first { $0.id == b }?.listID)

        // Duplicate IDs in one batch abort as well.
        XCTAssertFalse(store.moveTasksToList(ids: [a, a], listID: list))
        XCTAssertNil(store.data.tasks.first { $0.id == a }?.listID)

        // Unknown target list aborts; empty batches are rejected.
        XCTAssertFalse(store.moveTasksToList(ids: [a], listID: UUID()))
        XCTAssertFalse(store.moveTasksToList(ids: [], listID: list))
        XCTAssertNil(store.data.tasks.first { $0.id == a }?.listID)

        // Deleted tasks refuse to move.
        store.trashTask(id: a)
        XCTAssertFalse(store.moveTasksToList(ids: [a], listID: list))
        XCTAssertNil(store.data.tasks.first { $0.id == a }?.listID)

        // Moving to the current list is a successful no-op.
        XCTAssertTrue(store.moveTasksToList(ids: [b], listID: nil))
    }

    @MainActor func testSameListMovePreservesTimestampsExactly() throws {
        // A same-list move succeeds but leaves every record byte-identical:
        // no updatedAt bumps, no save side effects on untouched tasks.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "#526BF5")
        let a = store.createTask(title: "A")
        XCTAssertTrue(store.moveTasksToList(ids: [a], listID: list))
        let before = store.data.tasks
        XCTAssertTrue(store.moveTasksToList(ids: [a], listID: list))
        XCTAssertEqual(store.data.tasks, before)

        // Mixed batches only touch the tasks that actually move.
        let b = store.createTask(title: "B")
        let mixedBefore = store.data.tasks
        XCTAssertTrue(store.moveTasksToList(ids: [a, b], listID: list))
        XCTAssertEqual(store.data.tasks.first { $0.id == a }, mixedBefore.first { $0.id == a })
        XCTAssertEqual(store.data.tasks.first { $0.id == b }?.listID, list)
    }

    @MainActor func testRejectedBatchesLeaveStoreExactlyUntouched() throws {
        // Every rejection path aborts with no mutation at all, not just no
        // visible move: the record array compares exactly equal.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "#526BF5")
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")
        let before = store.data.tasks
        let missing = UUID()
        XCTAssertFalse(store.moveTasksToList(ids: [a, missing], listID: list))
        XCTAssertFalse(store.moveTasksToList(ids: [a, a], listID: list))
        XCTAssertFalse(store.moveTasksToList(ids: [a], listID: UUID()))
        store.trashTask(id: a)
        let trashed = store.data.tasks
        XCTAssertFalse(store.moveTasksToList(ids: [a], listID: list))
        XCTAssertFalse(store.reorderTasks(moving: [b, b], before: a))
        XCTAssertFalse(store.reorderTasks(moving: [b], before: missing))
        XCTAssertEqual(store.data.tasks, trashed)
        XCTAssertEqual(store.data.tasks.filter { $0.id == b }, before.filter { $0.id == b })
    }

    @MainActor func testReorderTasksBeforeAndAfter() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        // Default insertion is at the top, so creation order A,B,C stores
        // as [C, B, A]; the moves below are relative to stored order.
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")
        let c = store.createTask(title: "C")
        XCTAssertEqual(titles(store), ["C", "B", "A"])

        XCTAssertTrue(store.reorderTasks(moving: [a], before: c))
        XCTAssertEqual(titles(store), ["A", "C", "B"])

        XCTAssertTrue(store.reorderTasks(moving: [c], before: b, afterTarget: true))
        XCTAssertEqual(titles(store), ["A", "B", "C"])

        // Multi-move keeps the given relative order.
        XCTAssertTrue(store.reorderTasks(moving: [b, a], before: c))
        XCTAssertEqual(titles(store), ["B", "A", "C"])

        // Only order changed: every other field is identical.
        let reloaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(reloaded.data.tasks.map(\.title), ["B", "A", "C"])
        for task in reloaded.data.tasks {
            XCTAssertNil(task.completedAt)
            XCTAssertNil(task.deletedAt)
            XCTAssertNil(task.dueDate)
        }
    }

    @MainActor func testReorderTasksRejectsBadBatchWithoutMutation() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")
        let before = titles(store)

        // Self-drop, unknown IDs, duplicates, and unknown/deleted targets abort.
        XCTAssertFalse(store.reorderTasks(moving: [a], before: a))
        XCTAssertFalse(store.reorderTasks(moving: [UUID()], before: b))
        XCTAssertFalse(store.reorderTasks(moving: [a, a], before: b))
        XCTAssertFalse(store.reorderTasks(moving: [a], before: UUID()))
        XCTAssertFalse(store.reorderTasks(moving: [], before: b))
        store.trashTask(id: b)
        XCTAssertFalse(store.reorderTasks(moving: [a], before: b))
        XCTAssertFalse(store.reorderTasks(moving: [b], before: a))
        XCTAssertEqual(titles(store).sorted(), before.sorted())
        // Trashed B stays exactly where the array had it; A never moved.
        XCTAssertEqual(store.data.tasks.firstIndex { $0.id == a }, before.firstIndex(of: "A"))
    }

    func testOrderRefusesDuplicateStoredIDsWithoutDroppingRecords() {
        let original = TaskItem(title: "One")
        var duplicate = original
        duplicate.title = "Duplicate record"
        let other = TaskItem(title: "Two")
        let records = [original, other, duplicate]
        var data = WorkspaceData(tasks: records)
        XCTAssertFalse(data.reorderTasks(moving: [original.id], before: other.id))
        XCTAssertFalse(data.reorderTasks(moving: [other.id], before: original.id))
        XCTAssertEqual(data.tasks, records)
    }

    @MainActor func testReorderListsPersistsAcrossReload() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let one = store.createList(name: "One", color: "#526BF5")
        let two = store.createList(name: "Two", color: "#EC6574")
        let three = store.createList(name: "Three", color: "#E7A548")
        XCTAssertEqual(store.data.lists.map(\.name), ["One", "Two", "Three"])

        XCTAssertTrue(store.reorderLists(moving: three, before: one))
        XCTAssertEqual(store.data.lists.map(\.name), ["Three", "One", "Two"])
        XCTAssertTrue(store.reorderLists(moving: one, before: two, afterTarget: true))
        XCTAssertEqual(store.data.lists.map(\.name), ["Three", "Two", "One"])

        // Self-drops, unknown IDs, and unknown targets abort with no mutation.
        XCTAssertFalse(store.reorderLists(moving: one, before: one))
        XCTAssertFalse(store.reorderLists(moving: UUID(), before: two))
        XCTAssertFalse(store.reorderLists(moving: one, before: UUID()))
        XCTAssertEqual(store.data.lists.map(\.name), ["Three", "Two", "One"])

        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.lists.map(\.id), [three, two, one])
    }

    @MainActor func testLegacyWorkspaceWithoutNewKeysReorders() throws {
        // Order lives in the arrays themselves, so files written before these
        // APIs existed decode and reorder with no migration: strip the newer
        // top-level keys and the old file still loads and reorders.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let seed = TaskStore(fileURL: url, seed: false)
        seed.createTask(title: "First")
        seed.createTask(title: "Second")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json.removeValue(forKey: "filters")
        json.removeValue(forKey: "templates")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        // Default insertion is at the top: Second is stored first.
        XCTAssertEqual(titles(store), ["Second", "First"])
        let top = try XCTUnwrap(store.data.tasks.first?.id)
        let bottom = try XCTUnwrap(store.data.tasks.last?.id)
        XCTAssertTrue(store.reorderTasks(moving: [bottom], before: top))
        XCTAssertEqual(titles(TaskStore(fileURL: url, seed: false)), ["First", "Second"])
    }
}
