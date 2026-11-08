import XCTest
@testable import TaskovskyCore

/// Subtask hierarchy: cycle-safe parenting, display nesting, progress,
/// candidates, decoder sanitation, and interplay with trash/archive/counts.
final class TaskHierarchyTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor func testSetParentGuardsAndUnparents() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")
        XCTAssertTrue(store.setTaskParent(id: b, parentID: a))
        // No-op re-parent reports success without a save.
        XCTAssertTrue(store.setTaskParent(id: b, parentID: a))
        XCTAssertEqual(store.data.tasks.first { $0.id == b }?.parentID, a)
        // Self-parenting and descendants (cycles) refuse.
        XCTAssertFalse(store.setTaskParent(id: a, parentID: b))
        XCTAssertFalse(store.setTaskParent(id: a, parentID: a))
        XCTAssertFalse(store.setTaskParent(id: UUID(), parentID: a))
        XCTAssertFalse(store.setTaskParent(id: b, parentID: UUID()))
        // Unparenting restores top level.
        XCTAssertTrue(store.setTaskParent(id: b, parentID: nil))
        XCTAssertNil(store.data.tasks.first { $0.id == b }?.parentID)
    }

    @MainActor func testDeepCycleRefused() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createTask(title: "A")
        let b = store.createTask(title: "B")
        let c = store.createTask(title: "C")
        XCTAssertTrue(store.setTaskParent(id: b, parentID: a))
        XCTAssertTrue(store.setTaskParent(id: c, parentID: b))
        // Closing the loop (A under C) would cycle: refused, link untouched.
        XCTAssertFalse(store.setTaskParent(id: a, parentID: c))
        XCTAssertNil(store.data.tasks.first { $0.id == a }?.parentID)
        // Trashed parents refuse; trashed children keep their link.
        store.trashTask(id: a)
        XCTAssertFalse(store.setTaskParent(id: c, parentID: a))
        XCTAssertEqual(store.data.tasks.first { $0.id == c }?.parentID, b)
    }

    @MainActor func testAddSubtaskInheritsList() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "Work", color: "#000000")
        let parent = store.createTask(title: "Parent", listID: list)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "  Child  "))
        let saved = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        XCTAssertEqual(saved.parentID, parent)
        XCTAssertEqual(saved.listID, list)
        XCTAssertEqual(saved.title, "Child")
        XCTAssertNil(store.addSubtask(to: parent, title: "   "))
        XCTAssertNil(store.addSubtask(to: UUID(), title: "Orphan"))
        store.trashTask(id: parent)
        XCTAssertNil(store.addSubtask(to: parent, title: "Late"))
    }

    func testDisplayOrderNestsAndOrphans() {
        let p = TaskItem(title: "P")
        var c1 = TaskItem(title: "C1"); c1.parentID = p.id
        var c2 = TaskItem(title: "C2"); c2.parentID = p.id
        var g1 = TaskItem(title: "G1"); g1.parentID = c1.id
        var orphan = TaskItem(title: "Orphan"); orphan.parentID = UUID()
        // Incoming order is scrambled: nesting still groups subtrees.
        let order = TaskHierarchy.displayOrder([c1, p, orphan, g1, c2])
        XCTAssertEqual(order.map { $0.task.title }, ["P", "C1", "G1", "C2", "Orphan"])
        XCTAssertEqual(order.map(\.depth), [0, 1, 2, 1, 0])
        // A stored cycle renders every member instead of vanishing.
        var x = TaskItem(title: "X"); var y = TaskItem(title: "Y")
        x.parentID = y.id; y.parentID = x.id
        let cycled = TaskHierarchy.displayOrder([x, y])
        XCTAssertEqual(cycled.count, 2)
    }

    func testProgressAndCandidates() {
        var p = TaskItem(title: "P")
        XCTAssertNil(TaskHierarchy.progress(of: p.id, in: [p]))
        var done = TaskItem(title: "D"); done.parentID = p.id; done.completedAt = Date()
        var open = TaskItem(title: "O"); open.parentID = p.id
        var wont = TaskItem(title: "W"); wont.parentID = p.id; wont.wontDoAt = Date()
        p.listID = nil
        let all = [p, done, open, wont]
        XCTAssertEqual(TaskHierarchy.progress(of: p.id, in: all)?.done, 2)
        XCTAssertEqual(TaskHierarchy.progress(of: p.id, in: all)?.total, 3)
        // Candidates: same list, active, never self or a descendant.
        let cands = TaskHierarchy.parentCandidates(for: open, in: all)
        XCTAssertEqual(cands.map(\.id), [p.id])
        XCTAssertTrue(TaskHierarchy.parentCandidates(for: p, in: all).isEmpty)
    }

    func testDecoderSanitizesTaskParents() throws {
        let p = TaskItem(title: "P")
        var child = TaskItem(title: "C"); child.parentID = p.id
        var dangling = TaskItem(title: "D"); dangling.parentID = UUID()
        var selfed = TaskItem(title: "S"); selfed.parentID = selfed.id
        var x = TaskItem(title: "X"); var y = TaskItem(title: "Y")
        x.parentID = y.id; y.parentID = x.id
        let data = WorkspaceData(tasks: [p, child, dangling, selfed, x, y])
        let decoded = try JSONDecoder().decode(WorkspaceData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded.tasks.first { $0.title == "C" }?.parentID, p.id)
        XCTAssertNil(decoded.tasks.first { $0.title == "D" }?.parentID)
        XCTAssertNil(decoded.tasks.first { $0.title == "S" }?.parentID)
        // The cycle breaks without dropping either record.
        let broken = decoded.tasks.filter { $0.title == "X" || $0.title == "Y" }
        XCTAssertEqual(broken.count, 2)
        XCTAssertFalse(broken[0].parentID != nil && broken[1].parentID != nil
            && broken[0].parentID == broken[1].id && broken[1].parentID == broken[0].id)
        // Legacy files without the key decode as roots.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TaskItem(title: "L"))) as? [String: Any])
        legacy.removeValue(forKey: "parentID")
        let task = try JSONDecoder().decode(TaskItem.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(task.parentID)
    }

    @MainActor func testTrashCascadesThenRestoreRevives() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Child"))
        store.trashTask(id: parent)
        // Cascade: the child trashes with the same stamp and hides too.
        let parentStamp = try XCTUnwrap(store.data.tasks.first { $0.id == parent }?.deletedAt)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.deletedAt, parentStamp)
        XCTAssertTrue(store.data.tasks.filter { $0.deletedAt == nil }.isEmpty)
        store.restoreTask(id: parent)
        // Restore revives both with the link intact, nested again.
        XCTAssertNil(store.data.tasks.first { $0.id == parent }?.deletedAt)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.deletedAt)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.parentID, parent)
        let order = TaskHierarchy.displayOrder(store.data.tasks.filter { $0.deletedAt == nil })
        XCTAssertEqual(order.map { $0.task.id }, [parent, child])
        XCTAssertEqual(order.map(\.depth), [0, 1])
    }

    @MainActor func testArchivedListHidesWholeSubtree() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "Old", color: "#000000")
        let parent = store.createTask(title: "Parent", listID: list)
        _ = store.addSubtask(to: parent, title: "Child")
        XCTAssertTrue(store.setListArchived(id: list, archived: true))
        let visible = store.data.tasks.filter { !SmartListEligibility.isExcludedFromSmart($0, lists: store.data.lists) }
        XCTAssertTrue(visible.isEmpty)
        // Every task still counts exactly once in its list.
        XCTAssertEqual(store.data.tasks.filter { $0.listID == list }.count, 2)
    }
}
