import XCTest
import TaskovskyCore
@testable import Taskovsky

@MainActor final class DesktopNoticeTests: XCTestCase {
    func testSuccessExpiresAutomatically() async throws {
        let feedback = DesktopNotice(duration: .milliseconds(20))
        feedback.show("Schedule updated")
        XCTAssertEqual(feedback.event?.message, "Schedule updated")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(feedback.event)
    }

    func testIdenticalMessageIsANewEventAndStaleExpiryCannotClearIt() {
        let feedback = DesktopNotice()
        feedback.show("Schedule updated")
        let first = feedback.event!.id
        feedback.show("Schedule updated")
        let second = feedback.event!.id
        XCTAssertNotEqual(first, second)
        feedback.expire(id: first)
        XCTAssertEqual(feedback.event?.id, second)
        feedback.expire(id: second)
        XCTAssertNil(feedback.event)
    }

    func testCancelledTimerDoesNotClearNewPersistentError() async throws {
        let feedback = DesktopNotice(duration: .milliseconds(20))
        feedback.show("Schedule updated")
        let success = feedback.event!.id
        feedback.show("Could not save. Retry.", persistent: true)
        feedback.expire(id: success)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(feedback.event?.message, "Could not save. Retry.")
        feedback.dismiss()
        XCTAssertNil(feedback.event)
    }

    func testDismissAndReplacementAreIndependentPerSurface() {
        let calendar = DesktopNotice(), timeline = DesktopNotice()
        calendar.show("Schedule updated")
        timeline.show("Schedule updated")
        let previous = calendar.event!.id
        calendar.dismiss()
        calendar.show("Schedule restored")
        calendar.expire(id: previous)
        XCTAssertEqual(calendar.event?.message, "Schedule restored")
        XCTAssertNotNil(timeline.event)
        calendar.dismiss(); timeline.dismiss()
    }

    func testUndoOpportunityExpiresWithoutMutatingSavedTask() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Schedule")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id,
            operation: .setPoint(date: Date(timeIntervalSince1970: 1_900_000_000), allDay: false)))
        let saved = try Data(contentsOf: url)
        let feedback = DesktopNotice()
        feedback.show("Schedule updated", undo: token)
        XCTAssertEqual(feedback.event?.undo?.taskID, task.id)
        feedback.expire(id: feedback.event!.id)
        feedback.undo(in: store)
        XCTAssertEqual(try Data(contentsOf: url), saved)
        // Expiry consumes only this presentation, not the store's guarded operation.
        XCTAssertTrue(store.undoCalendarSchedule(token))
    }

    func testUndoBeforeExpiryRestoresOnceAndStartsNewNotice() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Schedule")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id,
            operation: .setPoint(date: Date(timeIntervalSince1970: 1_900_000_000), allDay: false)))
        let feedback = DesktopNotice()
        feedback.show("Schedule updated", undo: token)
        let oldID = feedback.event!.id
        feedback.undo(in: store)
        XCTAssertNil(store.data.tasks.first?.dueDate)
        XCTAssertEqual(feedback.event?.message, "Schedule restored")
        XCTAssertNil(feedback.event?.undo)
        feedback.expire(id: oldID)
        XCTAssertNotNil(feedback.event)
        feedback.undo(in: store)
        XCTAssertNil(store.data.tasks.first?.dueDate)
        feedback.dismiss()
    }
}
