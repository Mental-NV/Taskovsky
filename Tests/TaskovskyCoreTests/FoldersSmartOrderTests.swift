import XCTest
import Foundation
@testable import TaskovskyCore

/// Regression tests for folders, smart-list order, drag-payload decoding,
/// and the sorted-reorder policy.
///
/// Every mutating API validates before committing: unknown, deleted, mixed,
/// duplicate, self, or cross-group batches abort with no mutation and (for
/// stores) no save beyond the setup writes.
final class FoldersSmartOrderTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
    }

    // MARK: - Legacy tolerance

    @MainActor func testLegacyWorkspaceDecodesWithoutFoldersOrSmartOrder() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let seed = TaskStore(fileURL: url, seed: false)
        let list = seed.createList(name: "Work", color: "#526BF5")
        XCTAssertTrue(seed.data.folders.isEmpty)
        XCTAssertNil(seed.settings.smartListOrder)
        XCTAssertEqual(seed.settings.effectiveSmartListOrder, AppSettings.defaultSmartListOrder)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json.removeValue(forKey: "folders")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(loaded.data.folders.isEmpty)
        XCTAssertEqual(loaded.data.lists.first { $0.id == list }?.folderID, nil)
        XCTAssertNil(loaded.settings.smartListOrder)
        XCTAssertEqual(loaded.settings.effectiveSmartListOrder, AppSettings.defaultSmartListOrder)
    }

    @MainActor func testLegacyListWithoutBelowFoldersDecodesAsTopRoot() throws {
        // Files written before trailing placement existed carry no
        // `belowFolders` key: those lists must decode as top root, preserving
        // the prior above-folders order.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let seed = TaskStore(fileURL: url, seed: false)
        let list = seed.createList(name: "Work", color: "#526BF5")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var lists = try XCTUnwrap(json["lists"] as? [[String: Any]])
        XCTAssertNotNil(lists[0]["belowFolders"])
        lists[0].removeValue(forKey: "belowFolders")
        json["lists"] = lists
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.lists.first { $0.id == list }?.belowFolders, false)
    }

    @MainActor func testUnknownFolderMembershipClearsButKeepsListAndTasks() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let seed = TaskStore(fileURL: url, seed: false)
        let list = seed.createList(name: "Work", color: "#526BF5")
        let task = seed.createTask(title: "T", listID: list)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var lists = try XCTUnwrap(json["lists"] as? [[String: Any]])
        lists[0]["folderID"] = UUID().uuidString
        json["lists"] = lists
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertNil(loaded.data.lists.first { $0.id == list }?.folderID)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == task }?.listID, list)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == task }?.title, "T")
    }

    // MARK: - Folders

    @MainActor func testFolderCreateRenameUngroupPreservesListsAndTasks() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertNil(store.createFolder(name: "   "))
        guard let folder = store.createFolder(name: "  Home  ") else { return XCTFail("expected folder") }
        XCTAssertEqual(store.data.folders.first { $0.id == folder }?.name, "Home")
        XCTAssertFalse(store.renameFolder(id: folder, name: "  "))
        XCTAssertFalse(store.renameFolder(id: UUID(), name: "Nope"))
        XCTAssertTrue(store.renameFolder(id: folder, name: " House "))
        XCTAssertEqual(store.data.folders.first { $0.id == folder }?.name, "House")
        let list = store.createList(name: "Chores", color: "#526BF5", folderID: folder)
        let task = store.createTask(title: "Dishes", listID: list)
        XCTAssertEqual(store.data.lists.first { $0.id == list }?.folderID, folder)
        // Unknown folder on create clears to root; unknown on update clears too.
        let stray = store.createList(name: "Stray", color: "#fff", folderID: UUID())
        XCTAssertNil(store.data.lists.first { $0.id == stray }?.folderID)
        XCTAssertTrue(store.ungroupFolder(id: folder))
        XCTAssertFalse(store.data.folders.contains { $0.id == folder })
        XCTAssertNil(store.data.lists.first { $0.id == list }?.folderID)
        XCTAssertEqual(store.data.lists.first { $0.id == list }?.id, list)
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.listID, list)
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.title, "Dishes")
        XCTAssertFalse(store.ungroupFolder(id: folder))
        // Persisted across reload.
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(loaded.data.folders.isEmpty)
        XCTAssertNil(loaded.data.lists.first { $0.id == list }?.folderID)
    }

    @MainActor func testListFolderMovesAndReorders() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        guard let home = store.createFolder(name: "Home"), let work = store.createFolder(name: "Work") else { return XCTFail() }
        let a = store.createList(name: "A", color: "#111")
        let b = store.createList(name: "B", color: "#222")
        // Assign onto folder appends to that folder's segment.
        XCTAssertTrue(store.moveListToFolder(listID: a, folderID: home))
        XCTAssertEqual(store.data.lists.first { $0.id == a }?.folderID, home)
        XCTAssertTrue(store.moveListToFolder(listID: b, folderID: home))
        XCTAssertEqual(store.data.lists.map(\.name), ["A", "B"])
        // No-op succeeds without disturbing order.
        let before = store.data.lists
        XCTAssertTrue(store.moveListToFolder(listID: a, folderID: home))
        XCTAssertEqual(store.data.lists, before)
        // Reorder above/below adopts the target's folder (cross-folder and root).
        XCTAssertTrue(store.reorderLists(moving: b, before: a))
        XCTAssertEqual(store.data.lists.map(\.name), ["B", "A"])
        let c = store.createList(name: "C", color: "#333", folderID: work)
        XCTAssertTrue(store.reorderLists(moving: a, before: c))
        XCTAssertEqual(store.data.lists.first { $0.id == a }?.folderID, work)
        XCTAssertTrue(store.moveListToFolder(listID: a, folderID: nil))
        XCTAssertNil(store.data.lists.first { $0.id == a }?.folderID)
        // Invalid paths abort without mutation.
        let snapshot = store.data.lists
        XCTAssertFalse(store.moveListToFolder(listID: UUID(), folderID: home))
        XCTAssertFalse(store.moveListToFolder(listID: a, folderID: UUID()))
        XCTAssertFalse(store.reorderLists(moving: a, before: a))
        XCTAssertFalse(store.reorderLists(moving: UUID(), before: b))
        XCTAssertFalse(store.reorderFolders(moving: home, before: home))
        XCTAssertFalse(store.reorderFolders(moving: UUID(), before: work))
        XCTAssertEqual(store.data.lists, snapshot)
        // Folder reorder persists.
        XCTAssertTrue(store.reorderFolders(moving: work, before: home))
        XCTAssertEqual(store.data.folders.map(\.id), [work, home])
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.lists.first { $0.id == a }?.folderID, nil)
        XCTAssertEqual(loaded.data.folders.map(\.id), [work, home])
    }

    // MARK: - Smart order

    @MainActor func testSmartOrderNormalizationAndGroupedReorder() throws {
        var settings = AppSettings()
        // Legacy nil decodes to the default order.
        XCTAssertEqual(settings.effectiveSmartListOrder, AppSettings.defaultSmartListOrder)
        // Duplicates collapse; missing keys append in default order.
        settings.smartListOrder = [.today, .today, .inbox]
        XCTAssertEqual(settings.effectiveSmartListOrder.first, .today)
        XCTAssertEqual(settings.effectiveSmartListOrder.filter { $0 == .today }.count, 1)
        XCTAssertEqual(Set(settings.effectiveSmartListOrder), Set(SmartListKey.allCases))
        // Within-group reorder works and persists adoption order.
        var grouped = AppSettings()
        XCTAssertTrue(grouped.reorderSmartList(moving: .inbox, before: .today))
        let order = grouped.effectiveSmartListOrder
        XCTAssertLessThan(order.firstIndex(of: .inbox)!, order.firstIndex(of: .today)!)
        // Hidden keys keep their slots: reordering visible rows never drops them.
        grouped.smartListVisibility[.week] = .hidden
        XCTAssertTrue(grouped.reorderSmartList(moving: .inbox, before: .today))
        XCTAssertTrue(grouped.effectiveSmartListOrder.contains(.week))
        // Cross-group, self, and section-key (tags/filters) moves abort.
        let snapshot = grouped.effectiveSmartListOrder
        XCTAssertFalse(grouped.reorderSmartList(moving: .today, before: .trash))
        XCTAssertFalse(grouped.reorderSmartList(moving: .today, before: .today))
        XCTAssertFalse(grouped.reorderSmartList(moving: .tags, before: .filters))
        XCTAssertFalse(grouped.reorderSmartList(moving: .today, before: .tags))
        XCTAssertEqual(grouped.effectiveSmartListOrder, snapshot)
        // Reload keeps the persisted order.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        store.settings.smartListVisibility[.week] = .hidden
        XCTAssertTrue(store.settings.reorderSmartList(moving: .inbox, before: .today))
        let reloaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(reloaded.settings.effectiveSmartListOrder, store.settings.effectiveSmartListOrder)
        XCTAssertEqual(reloaded.settings.smartListVisibility[.week], .hidden)
    }

    // MARK: - Strict folder decode

    @MainActor func testMalformedFolderRecordFailsClosedPreservingFile() throws {
        // ListFolder.id/name are required: a folder missing either fails the
        // whole decode and the existing protection preserves the original
        // file instead of minting a random UUID/placeholder and dropping
        // memberships.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let broken = "{\"tasks\":[],\"lists\":[],\"tags\":[],\"folders\":[{\"id\":\"\(UUID().uuidString)\"}]}"
        try Data(broken.utf8).write(to: url)
        XCTAssertThrowsError(try JSONDecoder().decode(WorkspaceData.self, from: Data(contentsOf: url)))
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(store.needsRecovery)
        XCTAssertNotNil(store.storageError)
        store.createTask(title: "Unsaved edit")
        store.save()
        XCTAssertEqual(String(data: try Data(contentsOf: url), encoding: .utf8), broken)
    }

    // MARK: - Manual grouping policy

    func testManualGroupPolicyBuckets() {
        // Active tasks share one bucket regardless of dates or priorities.
        XCTAssertEqual(ManualGroupPolicy.bucket(completedAt: nil, wontDoAt: nil, deletedAt: nil), .active)
        XCTAssertEqual(ManualGroupPolicy.bucket(completedAt: Date(), wontDoAt: nil, deletedAt: nil), .history)
        XCTAssertEqual(ManualGroupPolicy.bucket(completedAt: nil, wontDoAt: Date(), deletedAt: nil), .history)
        XCTAssertEqual(ManualGroupPolicy.bucket(completedAt: nil, wontDoAt: nil, deletedAt: Date()), .deleted)
        XCTAssertEqual(ManualGroupPolicy.bucket(completedAt: Date(), wontDoAt: nil, deletedAt: Date()), .deleted)
        XCTAssertEqual(ManualGroupPolicy.activeGroupTitle, "Tasks")
    }

    @MainActor func testManualReorderAcrossDatesPreservesFields() throws {
        // None/manual is one sequence: dated, undated, and differently
        // prioritized tasks reorder freely with every other field untouched.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "#526BF5")
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let a = store.createTask(title: "Undated", listID: list)
        let b = store.createTask(title: "Today high", listID: list, dueDate: today)
        let c = store.createTask(title: "Tomorrow low", listID: list, dueDate: tomorrow)
        var tb = try XCTUnwrap(store.data.tasks.first { $0.id == b })
        tb.priority = .high; store.updateTask(tb)
        var tc = try XCTUnwrap(store.data.tasks.first { $0.id == c })
        tc.priority = .low; store.updateTask(tc)
        // Cross-date reorder commits; dates, priorities, list stay identical.
        XCTAssertTrue(store.reorderTasks(moving: [c], before: a))
        XCTAssertEqual(store.data.tasks.first { $0.id == c }?.dueDate, tomorrow)
        XCTAssertEqual(store.data.tasks.first { $0.id == c }?.priority, .low)
        XCTAssertEqual(store.data.tasks.first { $0.id == c }?.listID, list)
        XCTAssertEqual(store.data.tasks.first { $0.id == b }?.dueDate, today)
        XCTAssertEqual(store.data.tasks.first { $0.id == b }?.priority, .high)
        let titles = store.data.tasks.map(\.title)
        XCTAssertEqual(titles.firstIndex(of: "Tomorrow low")!, titles.firstIndex(of: "Undated")! - 1)
        // Duplicate keeps the list (folder follows the list).
        let dup = try XCTUnwrap(store.duplicateTask(id: a))
        XCTAssertEqual(store.data.tasks.first { $0.id == dup }?.listID, list)
        // Persisted across reload.
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.tasks.map(\.title), titles + ["Undated"])
        XCTAssertEqual(loaded.data.tasks.first { $0.id == c }?.dueDate, tomorrow)
    }

    // MARK: - Smart visibility modes

    @MainActor func testSummaryVisibilityModePersists() throws {
        // Summary supports the same three modes as every other smart list;
        // a stored Show-if-not-empty must reload as-is, never as None.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        store.settings.smartListVisibility[.summary] = .showIfNotEmpty
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.settings.smartListVisibility[.summary], .showIfNotEmpty)
    }

    // MARK: - Payloads and sort policy

    func testFolderAndSmartPayloadBatchValidation() throws {
        let folder = UUID()
        let folderData = try JSONEncoder().encode(FolderDragPayload(id: folder))
        XCTAssertEqual(DragBatch.singleFolderID(from: [folderData]), folder)
        XCTAssertNil(DragBatch.singleFolderID(from: []))
        XCTAssertNil(DragBatch.singleFolderID(from: [folderData, folderData]))
        XCTAssertNil(DragBatch.singleFolderID(from: [Data("nope".utf8)]))
        // List and folder payloads share the {"id":...} JSON shape by design;
        // they are never confused because drops travel on distinct UTTypes
        // (.taskovskyList vs .taskovskyFolder) and delegates reject foreign
        // and mixed batches before decoding. Smart keys use {"key":...} and
        // never cross-decode with either ID shape.
        let listData = try JSONEncoder().encode(ListDragPayload(id: UUID()))
        let smartData = try JSONEncoder().encode(SmartDragPayload(key: .today))
        XCTAssertNil(DragBatch.singleSmartKey(from: [listData]))
        XCTAssertNil(DragBatch.singleSmartKey(from: [folderData]))
        XCTAssertNil(DragBatch.singleListID(from: [smartData]))
        XCTAssertNil(DragBatch.singleFolderID(from: [smartData]))
        XCTAssertEqual(DragBatch.singleSmartKey(from: [smartData]), .today)
        XCTAssertNil(DragBatch.singleSmartKey(from: []))
        XCTAssertNil(DragBatch.singleSmartKey(from: [smartData, smartData]))
        // Task batches still reject foreign payload bytes.
        let taskData = try JSONEncoder().encode(TaskDragPayload(ids: [UUID()]))
        XCTAssertNil(DragBatch.combinedTaskIDs(from: [taskData, listData]))
    }

    // MARK: - Tags

    @MainActor func testTagReorderPreservesMetadataAndAssociations() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let a = store.createTag(name: "Alpha", color: "#111111")
        let b = store.createTag(name: "Beta", color: "#222222")
        let c = store.createTag(name: "Gamma", color: "#333333")
        let task = store.createTask(title: "T")
        var withTags = try XCTUnwrap(store.data.tasks.first { $0.id == task })
        withTags.tagIDs = [a, c]
        store.updateTask(withTags)
        // Reorder above/below commits with one save and keeps everything else.
        XCTAssertTrue(store.reorderTags(moving: c, before: a))
        XCTAssertEqual(store.data.tags.map(\.id), [c, a, b])
        XCTAssertEqual(store.data.tags.first { $0.id == c }?.name, "Gamma")
        XCTAssertEqual(store.data.tags.first { $0.id == c }?.color, "#333333")
        XCTAssertEqual(store.data.tags.first { $0.id == a }?.name, "Alpha")
        XCTAssertEqual(store.data.tasks.first { $0.id == task }?.tagIDs, [a, c])
        // Reload on the nontrivial changed order: the move above persisted.
        let changed = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(changed.data.tags.map(\.id), [c, a, b])
        XCTAssertEqual(changed.data.tasks.first { $0.id == task }?.tagIDs, [a, c])
        XCTAssertTrue(store.reorderTags(moving: c, before: b, afterTarget: true))
        XCTAssertEqual(store.data.tags.map(\.id), [a, b, c])
        // Positional no-ops succeed without mutating the store.
        let snapshot = store.data.tags
        XCTAssertTrue(store.reorderTags(moving: b, before: c))
        XCTAssertEqual(store.data.tags, snapshot)
        XCTAssertTrue(store.reorderTags(moving: b, before: a, afterTarget: true))
        XCTAssertEqual(store.data.tags, snapshot)
        // Self, unknown, and missing targets abort with no mutation.
        XCTAssertFalse(store.reorderTags(moving: a, before: a))
        XCTAssertFalse(store.reorderTags(moving: UUID(), before: b))
        XCTAssertFalse(store.reorderTags(moving: a, before: UUID()))
        XCTAssertEqual(store.data.tags, snapshot)
        // Persisted across reload with associations intact.
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.tags.map(\.id), [a, b, c])
        XCTAssertEqual(loaded.data.tasks.first { $0.id == task }?.tagIDs, [a, c])
    }

    func testTagPayloadBatchValidation() throws {
        let tag = UUID()
        let tagData = try JSONEncoder().encode(TagDragPayload(tagID: tag))
        XCTAssertEqual(DragBatch.singleTagID(from: [tagData]), tag)
        XCTAssertNil(DragBatch.singleTagID(from: []))
        XCTAssertNil(DragBatch.singleTagID(from: [tagData, tagData]))
        XCTAssertNil(DragBatch.singleTagID(from: [Data("nope".utf8)]))
        // Tags encode under a distinct `tagID` field, so raw cross-type
        // decoding rejects list/folder/smart bytes even before the distinct
        // `.taskovskyTag` transport type separates them in delegates.
        let listData = try JSONEncoder().encode(ListDragPayload(id: UUID()))
        let folderData = try JSONEncoder().encode(FolderDragPayload(id: UUID()))
        let smartData = try JSONEncoder().encode(SmartDragPayload(key: .today))
        XCTAssertNil(DragBatch.singleTagID(from: [listData]))
        XCTAssertNil(DragBatch.singleTagID(from: [folderData]))
        XCTAssertNil(DragBatch.singleTagID(from: [smartData]))
        XCTAssertNil(DragBatch.singleListID(from: [tagData]))
        XCTAssertNil(DragBatch.singleFolderID(from: [tagData]))
        XCTAssertNil(DragBatch.singleSmartKey(from: [tagData]))
    }

    func testSortPolicyLegacyManualMapsToNone() {
        XCTAssertTrue(TaskSortPolicy.isManual("None"))
        XCTAssertTrue(TaskSortPolicy.isManual("Manual"))
        XCTAssertFalse(TaskSortPolicy.isManual("Date"))
        XCTAssertTrue(TaskSortPolicy.canReorder("Manual"))
        XCTAssertFalse(TaskSortPolicy.canReorder("Title"))
        XCTAssertEqual(TaskSortPolicy.normalized("Manual"), "None")
        XCTAssertEqual(TaskSortPolicy.normalized("Date"), "Date")
        XCTAssertFalse(TaskSortPolicy.reorderDisabledMessage.isEmpty)
    }
}
