import Foundation
import XCTest
import TaskovskyCore
@testable import Taskovsky

final class InboxPinnedHierarchyTests: XCTestCase {
    func testPinnedUndatedSubtreeNestsAndUnpinKeepsEachRecord() {
        var parent = TaskItem(title: "Parent")
        parent.isPinned = true
        var first = TaskItem(title: "First"); first.parentID = parent.id
        var second = TaskItem(title: "Second"); second.parentID = parent.id
        var grandchild = TaskItem(title: "Grandchild"); grandchild.parentID = first.id
        let unrelated = TaskItem(title: "Other")
        let grouped = InboxPinnedHierarchy.partition([first, unrelated, parent, second, grandchild])
        XCTAssertEqual(grouped.pinned.map(\.id), [first.id, parent.id, second.id, grandchild.id])
        XCTAssertEqual(grouped.rest.map(\.id), [unrelated.id])
        let rendered = TaskHierarchy.listRows(grouped.pinned, collapsed: [])
        XCTAssertEqual(rendered.map { $0.task.id }, [parent.id, first.id, grandchild.id, second.id])
        XCTAssertEqual(rendered.map(\.depth), [0, 1, 2, 1])
        XCTAssertTrue(rendered[0].hasChildren)
        XCTAssertEqual(TaskHierarchy.listRows(grouped.pinned, collapsed: [parent.id]).map { $0.task.id }, [parent.id])
        XCTAssertTrue(rendered.dropFirst().allSatisfy { !$0.task.isPinned })

        parent.isPinned = false
        let unpinned = InboxPinnedHierarchy.partition([first, unrelated, parent, second, grandchild])
        XCTAssertTrue(unpinned.pinned.isEmpty)
        XCTAssertEqual(unpinned.rest.map(\.id), [first.id, unrelated.id, parent.id, second.id, grandchild.id])
    }

    func testDoesNotPullInIneligibleOrHiddenBranches() {
        var root = TaskItem(title: "Pinned Inbox"); root.isPinned = true
        var dated = TaskItem(title: "Dated", dueDate: Date()); dated.parentID = root.id
        var belowDated = TaskItem(title: "Below dated"); belowDated.parentID = dated.id
        var done = TaskItem(title: "Done"); done.parentID = root.id; done.completedAt = Date()
        var abandoned = TaskItem(title: "Abandoned"); abandoned.parentID = root.id; abandoned.wontDoAt = Date()
        var deleted = TaskItem(title: "Deleted"); deleted.parentID = root.id; deleted.deletedAt = Date()
        var anotherList = TaskItem(title: "Other list", listID: UUID()); anotherList.parentID = root.id
        var note = TaskItem(title: "Note", kind: .note); note.parentID = root.id
        var invisibleParent = TaskItem(title: "Filtered parent"); invisibleParent.parentID = root.id
        var visible = TaskItem(title: "Below filtered parent"); visible.parentID = invisibleParent.id
        let excluded = [dated, belowDated, done, abandoned, deleted, anotherList, note, visible]
        let grouped = InboxPinnedHierarchy.partition([root] + excluded)
        XCTAssertEqual(grouped.pinned.map(\.id), [root.id])
        XCTAssertEqual(grouped.rest.map(\.id), excluded.map(\.id))
    }
}
