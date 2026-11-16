import XCTest
@testable import TaskovskyDomain

final class TaskDisplayProjectionTests: XCTestCase {
    func testCompletedPartitionPreservesPinsOrderAndFailedTasksWithoutWrites() throws {
        var active = TaskItem(title: "Active"); active.isPinned = true
        var done = TaskItem(title: "Done"); done.completedAt = Date(); done.isPinned = true
        var failed = TaskItem(title: "Failed"); failed.wontDoAt = Date()
        let tasks = [done, active, failed]
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(tasks)
        let shown = TaskDisplayProjection(tasks, showCompleted: true)
        XCTAssertEqual(shown.ordinary.map(\.id), [active.id, failed.id])
        XCTAssertEqual(shown.completed.map(\.id), [done.id])
        XCTAssertEqual(shown.visible(completedExpanded: false).map(\.id), [active.id, failed.id])
        XCTAssertEqual(shown.visible(completedExpanded: true).map(\.id), [active.id, failed.id, done.id])
        XCTAssertTrue(TaskDisplayProjection(tasks, showCompleted: false).completed.isEmpty)
        XCTAssertEqual(try encoder.encode(tasks), before)
    }
    func testProjectionCannotBroadenDestinationMembershipOrActiveCount() {
        let list = TaskList(name: "One", color: "#123456")
        var included = TaskItem(title: "Included", listID: list.id); included.completedAt = Date()
        var excluded = TaskItem(title: "Excluded"); excluded.completedAt = Date()
        let active = TaskItem(title: "Active", listID: list.id)
        let data = WorkspaceData(tasks: [included, excluded, active], lists: [list])
        let destination = TaskDestination.list(list.id)
        let matched = destination.matchingTasks(in: data)
        XCTAssertEqual(TaskDisplayProjection(matched, showCompleted: true).completed.map(\.id), [included.id])
        XCTAssertEqual(destination.matchingTasks(in: data, showHistory: false).map(\.id), [active.id])
        XCTAssertEqual(TaskDisplayProjection(matched, showCompleted: false).ordinary.map(\.id), [active.id])
    }
}
