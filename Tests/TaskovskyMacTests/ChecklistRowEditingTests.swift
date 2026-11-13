import XCTest
import TaskovskyCore
@testable import Taskovsky

final class ChecklistRowEditingTests: XCTestCase {
    func testTrashAndArchivedRowsAreLocked() {
        var task = TaskItem(title: "Task", checklist: [ChecklistItem(title: "Step")])
        XCTAssertTrue(ChecklistRowEditing.canEdit(task, readOnly: false))
        XCTAssertFalse(ChecklistRowEditing.canEdit(task, readOnly: true))
        task.deletedAt = Date()
        XCTAssertFalse(ChecklistRowEditing.canEdit(task, readOnly: false))
        XCTAssertFalse(ChecklistRowEditing.canEdit(task, readOnly: true))
        task.deletedAt = nil
        XCTAssertTrue(ChecklistRowEditing.canEdit(task, readOnly: false))
        XCTAssertFalse(task.checklist[0].isCompleted)
    }
}
