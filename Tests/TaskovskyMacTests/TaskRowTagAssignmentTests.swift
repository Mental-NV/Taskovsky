import XCTest
import TaskovskyCore
@testable import Taskovsky

final class TaskRowTagAssignmentTests: XCTestCase {
    func testTargetsSpecifiedTaskAndPreservesUnknownTagsAndOtherFields() throws {
        let tag = TaskTag(name: "Work", color: "#000000")
        let retained = UUID()
        var target = TaskItem(title: "Current title", body: "Body", tagIDs: [retained])
        target.priority = .high
        let other = TaskItem(title: "Selected elsewhere")
        let data = WorkspaceData(tasks: [target, other], tags: [tag])
        let updated = try XCTUnwrap(TaskRowTagAssignment.updating(taskID: target.id, tagID: tag.id, enabled: true, in: data))
        var expected = target; expected.tagIDs.append(tag.id)
        XCTAssertEqual(updated, expected)
        XCTAssertEqual(data.tasks[1], other)
        var assigned = data; assigned.tasks[0] = updated
        XCTAssertNil(TaskRowTagAssignment.updating(taskID: target.id, tagID: tag.id, enabled: true, in: assigned))
        XCTAssertEqual(TaskRowTagAssignment.updating(taskID: target.id, tagID: tag.id, enabled: false, in: assigned), target)
    }
    func testRejectsMissingTagDeletedArchivedAndAmbiguousTargets() {
        let tag = TaskTag(name: "Work", color: "#000000")
        let list = TaskList(name: "Archive", color: "#000000", isArchived: true)
        var task = TaskItem(title: "Task")
        var data = WorkspaceData(tasks: [task], tags: [tag])
        XCTAssertNil(TaskRowTagAssignment.updating(taskID: task.id, tagID: UUID(), enabled: true, in: data))
        XCTAssertNil(TaskRowTagAssignment.updating(taskID: UUID(), tagID: tag.id, enabled: true, in: data))
        task.deletedAt = Date(); data.tasks = [task]
        XCTAssertNil(TaskRowTagAssignment.updating(taskID: task.id, tagID: tag.id, enabled: true, in: data))
        task.deletedAt = nil; task.listID = list.id; data.tasks = [task]; data.lists = [list]
        XCTAssertNil(TaskRowTagAssignment.updating(taskID: task.id, tagID: tag.id, enabled: true, in: data))
        task.listID = nil; data.tasks = [task, task]
        XCTAssertNil(TaskRowTagAssignment.updating(taskID: task.id, tagID: tag.id, enabled: true, in: data))
    }
    func testNestedLabelsAndIndependentParentAssignment() throws {
        let parent = TaskTag(name: "Work", color: "#000000")
        var child = TaskTag(name: "Project", color: "#000000"); child.parentID = parent.id
        let task = TaskItem(title: "Note", tagIDs: [parent.id], kind: .note)
        let data = WorkspaceData(tasks: [task], tags: [parent, child])
        XCTAssertEqual(TaskRowTagAssignment.label(for: child, in: data.tags), "#Work / #Project")
        let updated = try XCTUnwrap(TaskRowTagAssignment.updating(taskID: task.id, tagID: child.id, enabled: true, in: data))
        XCTAssertEqual(updated.tagIDs, [parent.id, child.id])
        XCTAssertEqual(updated.kind, .note)
    }
}
