import XCTest
import TaskovskyCore

final class FilterAllResetTests: XCTestCase {
    func testEmptyPriorityResetBroadensOnlyPriority() {
        let list = UUID()
        let low = TaskItem(title: "Low", listID: list, priority: .low)
        let otherList = TaskItem(title: "Other", priority: .high)
        var filter = TaskFilter(name: "", listIDs: [list], priorities: [.high, .medium], status: .all)
        XCTAssertFalse(filter.matches(low, lists: []))
        filter.priorities.removeAll()
        XCTAssertTrue(filter.matches(low, lists: []))
        XCTAssertFalse(filter.matches(otherList, lists: []))
    }
    func testEmptyTypeResetAdmitsNotesWithoutChangingKeyword() {
        var note = TaskItem(title: "Included")
        note.kind = .note
        var filter = TaskFilter(name: "", status: .all, keyword: "Included", kinds: [.task])
        XCTAssertFalse(filter.matches(note, lists: []))
        filter.kinds.removeAll()
        XCTAssertTrue(filter.matches(note, lists: []))
        note.title = "Excluded"
        XCTAssertFalse(filter.matches(note, lists: []))
    }
}
