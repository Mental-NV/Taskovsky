import XCTest
import TaskovskyCore
@testable import Taskovsky

final class TaskRowScheduleTargetTests: XCTestCase {
    func testResolvesCurrentTargetRatherThanOtherSelectedRecord() {
        var task = TaskItem(title: "Target")
        let other = TaskItem(title: "Elsewhere")
        var data = WorkspaceData(tasks: [task, other])
        XCTAssertEqual(TaskRowScheduleTarget.resolve(task.id, in: data), task)
        task.title = "Updated"; task.dueDate = Date(); task.hasDueTime = true
        data.tasks[0] = task
        XCTAssertEqual(TaskRowScheduleTarget.resolve(task.id, in: data), task)
        XCTAssertEqual(data.tasks[1], other)
        XCTAssertNil(TaskRowScheduleTarget.resolve(UUID(), in: data))
        data.tasks.append(task)
        XCTAssertNil(TaskRowScheduleTarget.resolve(task.id, in: data))
    }
    func testNotesHistoryTrashAndArchivedRowsHaveNoEntry() {
        let original = TaskItem(title: "Target")
        var task = original; task.kind = .note
        XCTAssertNil(TaskRowScheduleTarget.resolve(task.id, in: WorkspaceData(tasks: [task])))
        task = original; task.deletedAt = Date()
        XCTAssertNil(TaskRowScheduleTarget.resolve(task.id, in: WorkspaceData(tasks: [task])))
        task = original; task.completedAt = Date()
        XCTAssertNil(TaskRowScheduleTarget.resolve(task.id, in: WorkspaceData(tasks: [task])))
        task = original; task.wontDoAt = Date()
        XCTAssertNil(TaskRowScheduleTarget.resolve(task.id, in: WorkspaceData(tasks: [task])))
        let list = TaskList(name: "Archive", color: "#000000", isArchived: true)
        task = original; task.listID = list.id
        XCTAssertNil(TaskRowScheduleTarget.resolve(task.id, in: WorkspaceData(tasks: [task], lists: [list])))
    }
}
