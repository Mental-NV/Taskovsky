import XCTest
@testable import TaskovskyCore

/// Task-hierarchy lifecycle: completion/trash cascades with reload-safe
/// ledgers, subtree duplication, graph-aware moves, parent-link validation,
/// archive read-only guards, and reorder/link invariants.
final class HierarchyLifecycleTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor private func reload(_ url: URL) -> TaskStore {
        TaskStore(fileURL: url, seed: false)
    }

    // MARK: - Completion cascade

    @MainActor func testCompleteParentCascadesToActiveDescendants() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let open = try XCTUnwrap(store.addSubtask(to: parent, title: "Open"))
        let grand = try XCTUnwrap(store.addSubtask(to: open, title: "Grand"))
        let done = try XCTUnwrap(store.addSubtask(to: parent, title: "Done"))
        store.toggleComplete(id: done)
        let doneStamp = try XCTUnwrap(store.data.tasks.first { $0.id == done }?.completedAt)
        let wont = try XCTUnwrap(store.addSubtask(to: parent, title: "Wont"))
        store.markWontDo(id: wont)
        store.toggleComplete(id: parent)
        // Active descendants complete; already-done and Won't Do are untouched.
        XCTAssertNotNil(store.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertNotNil(store.data.tasks.first { $0.id == open }?.completedAt)
        XCTAssertNotNil(store.data.tasks.first { $0.id == grand }?.completedAt)
        XCTAssertEqual(store.data.tasks.first { $0.id == done }?.completedAt, doneStamp)
        XCTAssertNotNil(store.data.tasks.first { $0.id == wont }?.wontDoAt)
    }

    @MainActor func testUndoReopensOnlyCascadedDescendants() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let prior = try XCTUnwrap(store.addSubtask(to: parent, title: "Prior"))
        store.toggleComplete(id: prior)
        let priorStamp = try XCTUnwrap(store.data.tasks.first { $0.id == prior }?.completedAt)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Child"))
        store.toggleComplete(id: parent)
        XCTAssertNotNil(store.data.tasks.first { $0.id == child }?.completedAt)
        // Later user change: reopen the cascaded child, then complete it again.
        store.reopenTask(id: child)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.completedAt)
        store.toggleComplete(id: child)
        let laterStamp = try XCTUnwrap(store.data.tasks.first { $0.id == child }?.completedAt)
        // Undoing the parent reopens the parent but neither the prior
        // completion (different stamp) nor the later user change.
        store.undoCompletion(id: parent)
        XCTAssertNil(store.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.completedAt, laterStamp)
        XCTAssertEqual(store.data.tasks.first { $0.id == prior }?.completedAt, priorStamp)
    }

    @MainActor func testCascadeSurvivesReload() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Child"))
        store.toggleComplete(id: parent)
        XCTAssertNotNil(store.data.tasks.first { $0.id == child }?.completedAt)
        let reloaded = reload(dir.appendingPathComponent("workspace.json"))
        reloaded.undoCompletion(id: parent)
        XCTAssertNil(reloaded.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertNil(reloaded.data.tasks.first { $0.id == child }?.completedAt)
    }

    @MainActor func testRecurringParentClonesSubtreeOnce() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let due = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        let parent = store.createTask(title: "Repeat parent", dueDate: due)
        var updated = try XCTUnwrap(store.data.tasks.first { $0.id == parent })
        updated.recurrence = .daily
        store.updateTask(updated)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Repeat child"))
        var updatedChild = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        updatedChild.recurrence = .daily
        updatedChild.dueDate = due
        store.updateTask(updatedChild)
        store.toggleComplete(id: parent)
        // Exactly one successor for the parent, and exactly one clone of the
        // child under it — no per-child successor off the old parent.
        let successors = store.data.tasks.filter { $0.recurrenceSourceID == parent }
        XCTAssertEqual(successors.count, 1)
        let successor = try XCTUnwrap(successors.first)
        XCTAssertNil(successor.completedAt)
        let clones = store.data.tasks.filter { $0.recurrenceSourceID == child }
        XCTAssertEqual(clones.count, 1)
        let clone = try XCTUnwrap(clones.first)
        XCTAssertEqual(clone.parentID, successor.id)
        XCTAssertNil(clone.completedAt)
        // Old child completed by the cascade.
        XCTAssertNotNil(store.data.tasks.first { $0.id == child }?.completedAt)
        // Undo removes the pristine spawned subtree and reopens the cascade.
        store.undoCompletion(id: parent)
        XCTAssertNil(store.data.tasks.first { $0.id == successor.id })
        XCTAssertNil(store.data.tasks.first { $0.id == clone.id })
        XCTAssertNil(store.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.completedAt)
    }

    // MARK: - Trash / restore / purge

    @MainActor func testTrashRestoreCascadePreservesSeparateTrash() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Child"))
        let separate = try XCTUnwrap(store.addSubtask(to: parent, title: "Separate"))
        store.trashTask(id: separate)
        XCTAssertNotNil(store.data.tasks.first { $0.id == separate }?.deletedAt)
        store.trashTask(id: parent)
        XCTAssertNotNil(store.data.tasks.first { $0.id == child }?.deletedAt)
        store.restoreTask(id: parent)
        XCTAssertNil(store.data.tasks.first { $0.id == parent }?.deletedAt)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.deletedAt)
        // Separately trashed before the cascade: stays in Trash.
        XCTAssertNotNil(store.data.tasks.first { $0.id == separate }?.deletedAt)
    }

    @MainActor func testTrashCascadeSurvivesReload() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Child"))
        store.trashTask(id: parent)
        let reloaded = reload(dir.appendingPathComponent("workspace.json"))
        reloaded.restoreTask(id: parent)
        XCTAssertNil(reloaded.data.tasks.first { $0.id == child }?.deletedAt)
    }

    @MainActor func testPurgeDetachesSurvivingChildren() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "Parent")
        let cascaded = try XCTUnwrap(store.addSubtask(to: parent, title: "Cascaded"))
        let separate = try XCTUnwrap(store.addSubtask(to: parent, title: "Separate"))
        store.trashTask(id: separate)
        store.trashTask(id: parent)
        // Restore the cascaded child while the parent stays trashed: an
        // active child of a trashed parent.
        store.restoreTask(id: cascaded)
        XCTAssertTrue(store.purgeTask(id: parent))
        // No dangling links: both surviving children are detached roots.
        XCTAssertNil(store.data.tasks.first { $0.id == cascaded }?.parentID)
        XCTAssertNil(store.data.tasks.first { $0.id == separate }?.parentID)
        XCTAssertEqual(store.data.tasks.first { $0.id == cascaded }?.deletedAt, nil)
        XCTAssertNotNil(store.data.tasks.first { $0.id == separate }?.deletedAt)
        // Nothing references the purged ID.
        XCTAssertFalse(store.data.tasks.contains { $0.parentID == parent })
    }

    // MARK: - Duplication

    @MainActor func testDuplicateTaskDuplicatesWholeSubtree() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "P", body: "plain")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        let grand = try XCTUnwrap(store.addSubtask(to: child, title: "G"))
        store.toggleComplete(id: child)
        let copyID = try XCTUnwrap(store.duplicateTask(id: parent))
        XCTAssertNotEqual(copyID, parent)
        let copyKids = store.data.tasks.filter { $0.parentID == copyID }
        XCTAssertEqual(copyKids.count, 1)
        let copyChild = try XCTUnwrap(copyKids.first)
        XCTAssertNotEqual(copyChild.id, child)
        // Status preserved on descendants; links remapped into the copy.
        XCTAssertNotNil(copyChild.completedAt)
        XCTAssertNil(copyChild.recurrenceSourceID)
        let copyGrandKids = store.data.tasks.filter { $0.parentID == copyChild.id }
        XCTAssertEqual(copyGrandKids.count, 1)
        XCTAssertEqual(copyGrandKids.first?.title, "G")
        XCTAssertNotEqual(copyGrandKids.first?.id, grand)
        // Original tree untouched.
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.parentID, parent)
    }

    @MainActor func testDuplicateListRemapsChildrenIntoCopy() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "L", color: "#000000")
        let parent = store.createTask(title: "P", listID: list)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        let copyID = try XCTUnwrap(store.duplicateList(id: list))
        let copiedParent = try XCTUnwrap(store.data.tasks.first { $0.listID == copyID && $0.parentID == nil })
        XCTAssertNotEqual(copiedParent.id, parent)
        let copiedKids = store.data.tasks.filter { $0.parentID == copiedParent.id }
        XCTAssertEqual(copiedKids.count, 1)
        XCTAssertEqual(copiedKids.first?.listID, copyID)
        // No copied child points back at the original list's records.
        XCTAssertTrue(store.data.tasks.filter { $0.listID == copyID }.allSatisfy { $0.parentID != parent && $0.parentID != child })
        // View mode travels with the duplicate.
        var listed = try XCTUnwrap(store.data.lists.first { $0.id == list })
        listed.viewMode = .board
        store.updateList(listed)
        let copyID2 = try XCTUnwrap(store.duplicateList(id: list))
        XCTAssertEqual(store.data.lists.first { $0.id == copyID2 }?.viewMode, .board)
    }

    // MARK: - Moves

    @MainActor func testMoveParentCarriesDescendants() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createList(name: "A", color: "#000000")
        let b = store.createList(name: "B", color: "#111111")
        let parent = store.createTask(title: "P", listID: a)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        XCTAssertTrue(store.moveTasksToList(ids: [parent], listID: b))
        XCTAssertEqual(store.data.tasks.first { $0.id == parent }?.listID, b)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.listID, b)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.parentID, parent)
    }

    @MainActor func testMoveChildDetachesFromUnmovedParent() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createList(name: "A", color: "#000000")
        let b = store.createList(name: "B", color: "#111111")
        let parent = store.createTask(title: "P", listID: a)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        XCTAssertTrue(store.moveTasksToList(ids: [child], listID: b))
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.listID, b)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.parentID)
        XCTAssertEqual(store.data.tasks.first { $0.id == parent }?.listID, a)
    }

    @MainActor func testUpdateTaskListEditIsGraphAware() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createList(name: "A", color: "#000000")
        let b = store.createList(name: "B", color: "#111111")
        let parent = store.createTask(title: "P", listID: a)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        // Moving the parent through a direct record edit carries the child.
        var moved = try XCTUnwrap(store.data.tasks.first { $0.id == parent })
        moved.listID = b
        store.updateTask(moved)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.listID, b)
        // Moving the child out through a direct record edit detaches it.
        var movedChild = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        movedChild.listID = a
        store.updateTask(movedChild)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.parentID)
        // Archived lists still refuse the move (the child sits in A now).
        XCTAssertTrue(store.setListArchived(id: b, archived: true))
        var blocked = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        blocked.listID = b
        store.updateTask(blocked)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.listID, a)
    }

    // MARK: - Parent linking

    @MainActor func testSetTaskParentRejectsNotesAndArchived() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "L", color: "#000000")
        let note = store.createTask(title: "N", listID: list, kind: .note)
        let task = store.createTask(title: "T", listID: list)
        XCTAssertFalse(store.setTaskParent(id: task, parentID: note))
        XCTAssertNil(store.data.tasks.first { $0.id == task }?.parentID)
        let archived = store.createList(name: "Old", color: "#111111")
        let old = store.createTask(title: "O", listID: archived)
        // Created before the archive so it stays inside it (creation into
        // an archived list falls back to Inbox instead).
        let trapped = store.createTask(title: "Trap", listID: archived)
        XCTAssertTrue(store.setListArchived(id: archived, archived: true))
        XCTAssertFalse(store.setTaskParent(id: task, parentID: old))
        // A child sitting in an archived list cannot be relinked either.
        XCTAssertFalse(store.setTaskParent(id: trapped, parentID: task))
        // Archived parents refuse new subtasks too.
        XCTAssertNil(store.addSubtask(to: old, title: "Late"))
        XCTAssertNil(store.addSubtask(to: note, title: "Note child"))
    }

    @MainActor func testSetTaskParentNormalizesCrossListSubtree() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = store.createList(name: "A", color: "#000000")
        let b = store.createList(name: "B", color: "#111111")
        let parent = store.createTask(title: "P", listID: b)
        let child = store.createTask(title: "C", listID: a)
        let grand = try XCTUnwrap(store.addSubtask(to: child, title: "G"))
        XCTAssertTrue(store.setTaskParent(id: child, parentID: parent))
        // The moved subtree adopts the parent's list; nothing spans lists.
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.listID, b)
        XCTAssertEqual(store.data.tasks.first { $0.id == grand }?.listID, b)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.parentID, parent)
    }

    @MainActor func testAddSubtaskRejectsArchivedOrNoteParents() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "L", color: "#000000")
        let note = store.createTask(title: "N", listID: list, kind: .note)
        XCTAssertNil(store.addSubtask(to: note, title: "X"))
        let old = store.createTask(title: "O", listID: list)
        XCTAssertTrue(store.setListArchived(id: list, archived: true))
        XCTAssertNil(store.addSubtask(to: old, title: "Y"))
    }

    // MARK: - Archive read-only at the store layer

    @MainActor func testArchivedTasksFreezeButMoveOutWorks() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let archived = store.createList(name: "Old", color: "#000000")
        let other = store.createList(name: "New", color: "#111111")
        let task = store.createTask(title: "T", listID: archived)
        XCTAssertTrue(store.setListArchived(id: archived, archived: true))
        // Completion, title, schedule, and tag edits are refused.
        store.toggleComplete(id: task)
        XCTAssertNil(store.data.tasks.first { $0.id == task }?.completedAt)
        var edited = try XCTUnwrap(store.data.tasks.first { $0.id == task })
        edited.title = "Changed"
        edited.priority = .high
        edited.dueDate = Date()
        store.updateTask(edited)
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.title, "T")
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.priority, TaskPriority.none)
        XCTAssertNil(store.data.tasks.first { $0.id == task }?.dueDate)
        store.markWontDo(id: task)
        XCTAssertNil(store.data.tasks.first { $0.id == task }?.wontDoAt)
        // Moving out to an active list is allowed and lifts the freeze.
        var moved = try XCTUnwrap(store.data.tasks.first { $0.id == task })
        moved.listID = other
        moved.title = "Moved"
        store.updateTask(moved)
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.listID, other)
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.title, "Moved")
        store.toggleComplete(id: task)
        XCTAssertNotNil(store.data.tasks.first { $0.id == task }?.completedAt)
    }

    // MARK: - Display / reorder invariants

    @MainActor func testReorderNeverReparents() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "P")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        XCTAssertTrue(store.reorderTasks(moving: [child], before: parent))
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.parentID, parent)
        let order = TaskHierarchy.displayOrder(store.data.tasks.filter { $0.deletedAt == nil })
        XCTAssertEqual(order.map { $0.task.id }, [parent, child])
        XCTAssertEqual(order.map(\.depth), [0, 1])
    }

    func testFilteredChildRendersOnceAsRoot() {
        var parent = TaskItem(title: "P", dueDate: Date())
        var child = TaskItem(title: "C"); child.parentID = parent.id
        // Parent filtered out: the child renders exactly once, at top level.
        let order = TaskHierarchy.displayOrder([child])
        XCTAssertEqual(order.count, 1)
        XCTAssertEqual(order.first?.depth, 0)
        // Together with a pinned partition, no record appears twice.
        parent.isPinned = true
        let (pinned, rest) = PinnedGrouping.partition([parent, child])
        XCTAssertEqual(pinned.map(\.id), [parent.id])
        XCTAssertEqual(rest.map(\.id), [child.id])
        XCTAssertTrue(Set(pinned.map(\.id)).isDisjoint(with: Set(rest.map(\.id))))
    }

    @MainActor func testUndoParentCleansChildSpawns() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 9))!
        let parent = store.createTask(title: "Parent", dueDate: due)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Repeating child"))
        var updatedChild = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        updatedChild.recurrence = .daily
        updatedChild.dueDate = due
        updatedChild.hasDueTime = true
        store.updateTask(updatedChild)
        // Non-repeating parent, repeating child: the cascade completes the
        // child and the child spawns exactly one successor of its own.
        store.toggleComplete(id: parent)
        XCTAssertNotNil(store.data.tasks.first { $0.id == child }?.completedAt)
        let spawn = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        // Undoing the parent reopens the child AND removes the child's
        // pristine spawn: no duplicate occurrence is left behind, and the
        // child can start its series again from a later completion.
        store.undoCompletion(id: parent)
        XCTAssertNil(store.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertNil(store.data.tasks.first { $0.id == child }?.completedAt)
        XCTAssertNil(store.data.tasks.first { $0.id == spawn.id })
        XCTAssertTrue(store.data.tasks.filter { $0.recurrenceSourceID == child }.isEmpty)
        store.toggleComplete(id: child)
        XCTAssertEqual(store.data.tasks.filter { $0.recurrenceSourceID == child }.count, 1)
    }

    @MainActor func testChildSpawnRetainedAcrossReload() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 9))!
        let parent = store.createTask(title: "Parent", dueDate: due)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Repeating child"))
        var updatedChild = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        updatedChild.recurrence = .daily
        updatedChild.dueDate = due
        updatedChild.hasDueTime = true
        store.updateTask(updatedChild)
        store.toggleComplete(id: parent)
        let spawnID = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child }).id
        // Reload drops the in-memory snapshots: post-reload undo can no
        // longer prove the spawn pristine, so the conservative policy keeps
        // it while still reopening the cascaded child by ledger stamp.
        let reloaded = reload(dir.appendingPathComponent("workspace.json"))
        reloaded.undoCompletion(id: parent)
        XCTAssertNil(reloaded.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertNil(reloaded.data.tasks.first { $0.id == child }?.completedAt)
        XCTAssertNotNil(reloaded.data.tasks.first { $0.id == spawnID })
        XCTAssertEqual(reloaded.data.tasks.filter { $0.recurrenceSourceID == child }.count, 1)
        // No dangling links anywhere.
        let ids = Set(reloaded.data.tasks.map(\.id))
        XCTAssertTrue(reloaded.data.tasks.allSatisfy { $0.parentID == nil || ids.contains($0.parentID!) })
    }

    @MainActor func testUndoRetainsAnchorForEditedClone() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 9))!
        let parent = store.createTask(title: "Parent", dueDate: due)
        var updated = try XCTUnwrap(store.data.tasks.first { $0.id == parent })
        updated.recurrence = .daily
        updated.hasDueTime = true
        store.updateTask(updated)
        let kept = try XCTUnwrap(store.addSubtask(to: parent, title: "Kept"))
        let dropped = try XCTUnwrap(store.addSubtask(to: parent, title: "Dropped"))
        var keptChild = try XCTUnwrap(store.data.tasks.first { $0.id == kept })
        keptChild.dueDate = due
        store.updateTask(keptChild)
        store.toggleComplete(id: parent)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == parent })
        let keptClone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == kept })
        let droppedClone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == dropped })
        // The user edits one clone: it (and its required ancestors) must
        // survive the parent undo; the pristine sibling clone still leaves.
        var edited = keptClone
        edited.title = "Kept, edited by user"
        store.updateTask(edited)
        store.undoCompletion(id: parent)
        XCTAssertNil(store.data.tasks.first { $0.id == parent }?.completedAt)
        XCTAssertNil(store.data.tasks.first { $0.id == kept }?.completedAt)
        // Edited clone survives with its title; the pristine successor is
        // retained as its required ancestor (never a dangling parentID).
        let survivor = try XCTUnwrap(store.data.tasks.first { $0.id == keptClone.id })
        XCTAssertEqual(survivor.title, "Kept, edited by user")
        XCTAssertEqual(survivor.parentID, successor.id)
        XCTAssertNotNil(store.data.tasks.first { $0.id == successor.id })
        XCTAssertNil(store.data.tasks.first { $0.id == droppedClone.id })
        let ids = Set(store.data.tasks.map(\.id))
        XCTAssertTrue(store.data.tasks.allSatisfy { $0.parentID == nil || ids.contains($0.parentID!) })
        // Edited descendants keep their shifted dates through the undo.
        XCTAssertNotNil(survivor.dueDate)
    }

    @MainActor func testTemplateApplyPreservesHierarchy() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let parent = store.createTask(title: "P")
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        let templateID = try XCTUnwrap(store.saveTemplate(from: parent))
        var edited = try XCTUnwrap(store.data.tasks.first { $0.id == parent })
        edited.title = "Renamed"
        store.updateTask(edited)
        // Applying the saved template restores content but keeps identity,
        // the parent link of the child, and the list slot.
        let template = try XCTUnwrap(store.data.templates.first { $0.id == templateID })
        edited = try XCTUnwrap(store.data.tasks.first { $0.id == parent })
        edited.title = template.title
        edited.body = template.body
        store.updateTask(edited)
        XCTAssertEqual(store.data.tasks.first { $0.id == child }?.parentID, parent)
    }
}
