import XCTest
import Foundation
@testable import TaskovskyCore

/// Focused regression for the in-app sidebar drag path shared by smart
/// lists, lists, folders, and tags (SidebarDragPolicy).
///
/// The native `.onDrag` sources never started (mouse arbitration inside
/// plain Buttons), so sidebar reordering moved to a coordinator that gates
/// hover markers through `allowsHover`/`hoverStyle` and commits exactly once
/// at release through `commit`. These tests pin that contract: hover appears
/// only where a commit could succeed, edges follow the row midpoint, invalid
/// targets and cancels never mutate, and each allowed combination commits
/// through the store exactly once.
final class SidebarDragPolicyTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
    }

    @MainActor
    private func store() -> (TaskStore, URL) {
        let url = tempURL()
        let store = TaskStore(fileURL: url, seed: false)
        return (store, url)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Hover gating

    func testSmartHoverRequiresSameGroupAndNonSelf() {
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .smart(.today), target: .smart(.week)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .smart(.today), target: .smart(.today)))
        // Cross-group smart moves never show a marker.
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .smart(.today), target: .smart(.completed)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .smart(.trash), target: .smart(.inbox)))
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .smart(.completed), target: .smart(.trash)))
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .smart(.completed), target: .smart(.wontDo)))
    }

    func testCrossTypeHoversRejected() {
        let list = UUID()
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .list(list), target: .smart(.today)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .list(list), target: .tag(UUID())))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .tag(UUID()), target: .list(list)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .folder(UUID()), target: .list(list)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .smart(.today), target: .folder(UUID())))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .smart(.today), target: .root))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .tag(UUID()), target: .root))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .folder(UUID()), target: .root))
    }

    func testSelfDropsRejectedForAllTypes() {
        let id = UUID()
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .list(id), target: .list(id)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .folder(id), target: .folder(id)))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .tag(id), target: .tag(id)))
    }

    func testListAssignTargetsAllowed() {
        let moving = UUID()
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .list(moving), target: .folder(UUID())))
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .list(moving), target: .root))
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .list(moving), target: .rootEnd))
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .list(moving), target: .list(UUID())))
    }

    func testRootEndAcceptsListsOnly() {
        let list = UUID()
        XCTAssertTrue(SidebarDragPolicy.allowsHover(source: .list(list), target: .rootEnd))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .smart(.today), target: .rootEnd))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .folder(UUID()), target: .rootEnd))
        XCTAssertFalse(SidebarDragPolicy.allowsHover(source: .tag(UUID()), target: .rootEnd))
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .list(list), target: .rootEnd, pointerY: 7, rowHeight: 14),
            .highlight
        )
        XCTAssertNil(SidebarDragPolicy.hoverStyle(source: .tag(UUID()), target: .rootEnd, pointerY: 7, rowHeight: 14))
    }

    // MARK: - Marker geometry

    func testReorderEdgeFollowsRowMidpoint() {
        // 38pt rows split exactly in halves.
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .list(UUID()), target: .list(UUID()), pointerY: 10, rowHeight: 38),
            .marker(.above)
        )
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .list(UUID()), target: .list(UUID()), pointerY: 28, rowHeight: 38),
            .marker(.below)
        )
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .tag(UUID()), target: .tag(UUID()), pointerY: 0, rowHeight: 38),
            .marker(.above)
        )
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .smart(.today), target: .smart(.week), pointerY: 30, rowHeight: 38),
            .marker(.below)
        )
    }

    func testAssignTargetsHighlightInsteadOfMarker() {
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .list(UUID()), target: .folder(UUID()), pointerY: 5, rowHeight: 38),
            .highlight
        )
        XCTAssertEqual(
            SidebarDragPolicy.hoverStyle(source: .list(UUID()), target: .root, pointerY: 30, rowHeight: 38),
            .highlight
        )
    }

    func testInvalidHoverHasNoStyle() {
        XCTAssertNil(SidebarDragPolicy.hoverStyle(source: .list(UUID()), target: .smart(.today), pointerY: 5, rowHeight: 38))
        let id = UUID()
        XCTAssertNil(SidebarDragPolicy.hoverStyle(source: .tag(id), target: .tag(id), pointerY: 5, rowHeight: 38))
    }

    // MARK: - Commit routing

    @MainActor func testCommitListReorderAdoptsTargetFolder() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let folder = store.createFolder(name: "F")!
        let a = store.createList(name: "A", color: "#526BF5")
        let b = store.createList(name: "B", color: "#526BF5")
        XCTAssertTrue(store.moveListToFolder(listID: b, folderID: folder))
        // Drop A above B: A adopts B's folder and lands before it.
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(a), target: .list(b), after: false, store: store))
        XCTAssertEqual(store.data.lists.first { $0.id == a }?.folderID, folder)
        XCTAssertEqual(store.data.lists.filter { $0.folderID == folder }.map(\.id), [a, b])
    }

    @MainActor func testCommitListOntoFolderAssignsAndAppends() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let folder = store.createFolder(name: "F")!
        let a = store.createList(name: "A", color: "#526BF5")
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(a), target: .folder(folder), after: false, store: store))
        XCTAssertEqual(store.data.lists.first { $0.id == a }?.folderID, folder)
    }

    @MainActor func testCommitListOntoRootUngroups() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let folder = store.createFolder(name: "F")!
        let a = store.createList(name: "A", color: "#526BF5")
        XCTAssertTrue(store.moveListToFolder(listID: a, folderID: folder))
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(a), target: .root, after: false, store: store))
        XCTAssertNil(store.data.lists.first { $0.id == a }?.folderID)
    }

    // MARK: - Absolute-end trailing placement

    @MainActor func testCommitRootEndMovesTopRootListToTrailingEnd() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let a = store.createList(name: "A", color: "#111111")
        let b = store.createList(name: "B", color: "#222222")
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(a), target: .rootEnd, after: false, store: store))
        let first = try? XCTUnwrap(store.data.lists.first { $0.id == a })
        XCTAssertNil(first?.folderID)
        XCTAssertEqual(first?.belowFolders, true)
        // A lands after the existing trailing order (B stays a top root).
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && !$0.belowFolders }.map(\.id), [b])
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && $0.belowFolders }.map(\.id), [a])
        // Repeat drop at the end is a no-op success preserving order.
        let before = store.data.lists
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(a), target: .rootEnd, after: false, store: store))
        XCTAssertEqual(store.data.lists, before)
    }

    @MainActor func testCommitRootEndMovesFolderMemberOut() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let folder = store.createFolder(name: "F")!
        let a = store.createList(name: "A", color: "#111111")
        let b = store.createList(name: "B", color: "#222222", folderID: folder)
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(b), target: .rootEnd, after: false, store: store))
        let moved = try? XCTUnwrap(store.data.lists.first { $0.id == b })
        XCTAssertNil(moved?.folderID)
        XCTAssertEqual(moved?.belowFolders, true)
        // The top root, the folder child order aside, and IDs stay intact.
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && !$0.belowFolders }.map(\.id), [a])
        XCTAssertTrue(store.data.lists.contains { $0.id == b })
        // A second member appends after the first trailing list.
        let c = store.createList(name: "C", color: "#333333", folderID: folder)
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(c), target: .rootEnd, after: false, store: store))
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && $0.belowFolders }.map(\.id), [b, c])
    }

    @MainActor func testRootEndRejectsUnknownAndNonLists() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let before = store.data.lists
        XCTAssertFalse(SidebarDragPolicy.commit(source: .list(UUID()), target: .rootEnd, after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .tag(UUID()), target: .rootEnd, after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .smart(.today), target: .rootEnd, after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .folder(UUID()), target: .rootEnd, after: false, store: store))
        XCTAssertEqual(store.data.lists, before)
    }

    @MainActor func testReorderAdoptsTargetRootSegment() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let folder = store.createFolder(name: "F")!
        let top = store.createList(name: "Top", color: "#111111")
        let f = store.createList(name: "In", color: "#222222", folderID: folder)
        XCTAssertTrue(store.moveListToRootEnd(listID: top))
        // Reordering a folder child below a trailing row adopts trailing root.
        XCTAssertTrue(store.reorderLists(moving: f, before: top, afterTarget: true))
        let moved = try? XCTUnwrap(store.data.lists.first { $0.id == f })
        XCTAssertNil(moved?.folderID)
        XCTAssertEqual(moved?.belowFolders, true)
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && $0.belowFolders }.map(\.id), [top, f])
        // Reordering a trailing row above a top root returns it to the top.
        let top2 = store.createList(name: "Top2", color: "#444444")
        XCTAssertTrue(store.reorderLists(moving: f, before: top2))
        XCTAssertNil(store.data.lists.first { $0.id == f }?.folderID)
        XCTAssertEqual(store.data.lists.first { $0.id == f }?.belowFolders, false)
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && !$0.belowFolders }.map(\.id), [f, top2])
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && $0.belowFolders }.map(\.id), [top])
    }

    @MainActor func testHeadingRootDropKeepsLegacyTopOrder() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let folder = store.createFolder(name: "F")!
        let top = store.createList(name: "Top", color: "#111111")
        let tail = store.createList(name: "Tail", color: "#222222")
        XCTAssertTrue(store.moveListToRootEnd(listID: tail))
        let member = store.createList(name: "M", color: "#333333", folderID: folder)
        // The heading drop ungroups to the TOP segment, never disturbing
        // trailing rows.
        XCTAssertTrue(SidebarDragPolicy.commit(source: .list(member), target: .root, after: false, store: store))
        XCTAssertNil(store.data.lists.first { $0.id == member }?.folderID)
        XCTAssertEqual(store.data.lists.first { $0.id == member }?.belowFolders, false)
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && !$0.belowFolders }.map(\.id), [top, member])
        XCTAssertEqual(store.data.lists.filter { $0.folderID == nil && $0.belowFolders }.map(\.id), [tail])
    }

    @MainActor func testTrailingPlacementPersistsAndSurvivesEdits() {
        let url = tempURL()
        defer { cleanup(url) }
        let store = TaskStore(fileURL: url, seed: false)
        let folder = store.createFolder(name: "F")!
        let top = store.createList(name: "Top", color: "#111111")
        let tail = store.createList(name: "Tail", color: "#222222", folderID: folder)
        let task = store.createTask(title: "T", listID: tail)
        XCTAssertTrue(store.moveListToRootEnd(listID: tail))
        // An unrelated rename carries the record (as EntityEditor(list:) does)
        // and must not reset placement or membership.
        guard var renamed = store.data.lists.first(where: { $0.id == tail }) else {
            return XCTFail("expected trailing list")
        }
        renamed.name = "Tail renamed"
        store.updateList(renamed)
        XCTAssertEqual(store.data.lists.first { $0.id == tail }?.belowFolders, true)
        XCTAssertNil(store.data.lists.first { $0.id == tail }?.folderID)
        // Normal folder drops still assign and append.
        let other = store.createList(name: "Other", color: "#333333")
        XCTAssertTrue(store.moveListToFolder(listID: other, folderID: folder))
        XCTAssertEqual(store.data.lists.first { $0.id == other }?.folderID, folder)
        XCTAssertEqual(store.data.lists.filter { $0.folderID == folder }.map(\.id), [other])
        // Persisted across reload with IDs, tasks, and segments intact.
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.lists.filter { $0.folderID == nil && !$0.belowFolders }.map(\.id), [top])
        XCTAssertEqual(loaded.data.lists.filter { $0.folderID == nil && $0.belowFolders }.map(\.name), ["Tail renamed"])
        XCTAssertEqual(loaded.data.lists.filter { $0.folderID == folder }.map(\.id), [other])
        XCTAssertEqual(loaded.data.tasks.first { $0.id == task }?.listID, tail)
    }

    @MainActor func testCommitSmartReorderSameGroupOnly() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let before = store.settings.effectiveSmartListOrder
        XCTAssertTrue(SidebarDragPolicy.commit(source: .smart(.today), target: .smart(.week), after: false, store: store))
        XCTAssertNotEqual(store.settings.effectiveSmartListOrder, before)
        // Cross-group commits fail without mutating.
        let order = store.settings.effectiveSmartListOrder
        XCTAssertFalse(SidebarDragPolicy.commit(source: .smart(.today), target: .smart(.trash), after: false, store: store))
        XCTAssertEqual(store.settings.effectiveSmartListOrder, order)
    }

    @MainActor func testCommitFolderAndTagReorder() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let f1 = store.createFolder(name: "F1")!
        let f2 = store.createFolder(name: "F2")!
        XCTAssertTrue(SidebarDragPolicy.commit(source: .folder(f2), target: .folder(f1), after: false, store: store))
        XCTAssertEqual(store.data.folders.map(\.id), [f2, f1])
        let t1 = store.createTag(name: "T1", color: "#526BF5")
        let t2 = store.createTag(name: "T2", color: "#526BF5")
        XCTAssertTrue(SidebarDragPolicy.commit(source: .tag(t2), target: .tag(t1), after: false, store: store))
        XCTAssertEqual(store.data.tags.map(\.id), [t2, t1])
    }

    @MainActor func testCommitInvalidCombinationsNeverMutate() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        let a = store.createList(name: "A", color: "#526BF5")
        let snapshot = store.data.lists
        XCTAssertFalse(SidebarDragPolicy.commit(source: .list(a), target: .smart(.today), after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .list(a), target: .tag(UUID()), after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .smart(.today), target: .root, after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .list(a), target: .list(a), after: false, store: store))
        XCTAssertFalse(SidebarDragPolicy.commit(source: .list(UUID()), target: .root, after: false, store: store))
        XCTAssertEqual(store.data.lists.map(\.id), snapshot.map(\.id))
    }

    // MARK: - Preview content

    func testPreviewModelCoversAllFourRowTypes() {
        // The floating card renders from this model (never an AnyView proxy),
        // so every row type must carry its presentation faithfully.
        let list = SidebarDragPreview(title: "Groceries", leading: .listSymbol("cart"), colorHex: "#526BF5", count: 3)
        XCTAssertEqual(list.title, "Groceries")
        XCTAssertEqual(list.leading, .listSymbol("cart"))
        XCTAssertEqual(list.colorHex, "#526BF5")
        XCTAssertEqual(list.count, 3)
        XCTAssertFalse(list.showsDisclosure)
        let smart = SidebarDragPreview(title: "Today", leading: .calendarText("6"), count: 2)
        XCTAssertEqual(smart.leading, .calendarText("6"))
        let folder = SidebarDragPreview(title: "Home", leading: .folder, count: 4, showsDisclosure: true)
        XCTAssertTrue(folder.showsDisclosure)
        let tag = SidebarDragPreview(title: "Urgent", leading: .systemImage("tag"), colorHex: "#FF0000", count: 1)
        XCTAssertEqual(tag.leading, .systemImage("tag"))
    }

    func testPreviewCardSpecIsVisibleAndOffset() {
        // The card is explicit width/38pt height with one assembled opacity in
        // the 0.65-0.75 band, offset a small distance off the pointer.
        XCTAssertEqual(SidebarPreviewSpec.height, 38)
        XCTAssertEqual(SidebarPreviewSpec.minWidth, 80)
        XCTAssertGreaterThanOrEqual(SidebarPreviewSpec.opacity, 0.65)
        XCTAssertLessThanOrEqual(SidebarPreviewSpec.opacity, 0.75)
        XCTAssertNotEqual(SidebarPreviewSpec.pointerOffsetX, 0)
        XCTAssertNotEqual(SidebarPreviewSpec.pointerOffsetY, 0)
    }

    @MainActor func testHoverAloneNeverMutates() {
        let (store, url) = self.store()
        defer { cleanup(url) }
        _ = store.createList(name: "A", color: "#526BF5")
        let listsBefore = store.data.lists.map(\.id)
        let orderBefore = store.settings.effectiveSmartListOrder
        // Hover gating is store-free by construction; exercising it changes nothing.
        for _ in 0..<5 {
            _ = SidebarDragPolicy.allowsHover(source: .smart(.today), target: .smart(.week))
            _ = SidebarDragPolicy.hoverStyle(source: .list(UUID()), target: .root, pointerY: 5, rowHeight: 38)
        }
        XCTAssertEqual(store.data.lists.map(\.id), listsBefore)
        XCTAssertEqual(store.settings.effectiveSmartListOrder, orderBefore)
    }
}
