import XCTest
import TaskovskyCore
@testable import Taskovsky

final class TaskRowRenamePolicyTests: XCTestCase {
    func testOnlyMatchingSelectedRequestBeginsEditing() {
        let task = TaskItem(title: "New subtask")
        XCTAssertTrue(TaskRowRenamePolicy.shouldBegin(requestedID: task.id, task: task, selection: task.id, readOnly: false))
        XCTAssertFalse(TaskRowRenamePolicy.shouldBegin(requestedID: nil, task: task, selection: task.id, readOnly: false))
        XCTAssertFalse(TaskRowRenamePolicy.shouldBegin(requestedID: UUID(), task: task, selection: task.id, readOnly: false))
        XCTAssertFalse(TaskRowRenamePolicy.shouldBegin(requestedID: task.id, task: task, selection: UUID(), readOnly: false))
        XCTAssertFalse(TaskRowRenamePolicy.shouldBegin(requestedID: task.id, task: task, selection: nil, readOnly: false))
    }
    func testChildOfPinnedParentRevealsInheritedSectionNotNoSection() {
        let section = TaskSection(name: "Work")
        var list = TaskList(name: "Project", color: "#000000")
        list.sections = [section]
        var parent = TaskItem(title: "Pinned parent", listID: list.id, isPinned: true)
        parent.sectionID = section.id
        let child = TaskItem(title: "New subtask", listID: list.id, parentID: parent.id)
        let data = WorkspaceData(tasks: [parent, child], lists: [list])
        XCTAssertEqual(TaskRowRenamePolicy.sectionKey(for: child.id, visible: data.tasks, list: list, data: data), "section-\(list.id)-\(section.id)")
        XCTAssertEqual(TaskRowRenamePolicy.sectionKey(for: parent.id, visible: data.tasks, list: list, data: data), "pinned-\(list.id)")
        XCTAssertNil(TaskRowRenamePolicy.sectionKey(for: child.id, visible: [parent], list: list, data: data))
    }
    func testUnassignedChildRevealsNoSection() {
        let list = TaskList(name: "Project", color: "#000000")
        let child = TaskItem(title: "Child", listID: list.id)
        let data = WorkspaceData(tasks: [child], lists: [list])
        XCTAssertEqual(TaskRowRenamePolicy.sectionKey(for: child.id, visible: [child], list: list, data: data), "section-\(list.id)-none")
    }
    func testLockedAndDeletedRowsCannotClaimFocus() {
        var task = TaskItem(title: "New subtask")
        XCTAssertFalse(TaskRowRenamePolicy.shouldBegin(requestedID: task.id, task: task, selection: task.id, readOnly: true))
        task.deletedAt = Date()
        XCTAssertFalse(TaskRowRenamePolicy.shouldBegin(requestedID: task.id, task: task, selection: task.id, readOnly: false))
    }
}
