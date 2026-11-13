import XCTest
import TaskovskyCore
@testable import Taskovsky

final class TaskRowConversionTests: XCTestCase {
    func testUsesCurrentContextTargetAndPreservesExistingConversionPayload() {
        var target = TaskItem(title: "Target")
        target.body = "Current body"; target.tagIDs = [UUID()]
        target.parentID = UUID(); target.dueDate = Date(timeIntervalSince1970: 1800000000)
        target.hasDueTime = true; target.priority = .high; target.isPinned = true
        let other = TaskItem(title: "Selected elsewhere")
        var data = WorkspaceData(tasks: [other, target])
        target.title = "Latest title"; data.tasks[1] = target
        let result = TaskRowConversion.toNote(taskID: target.id, in: data)
        XCTAssertEqual(result, target.converted(to: .note))
        XCTAssertEqual(result?.body, target.body)
        XCTAssertEqual(result?.parentID, target.parentID)
        XCTAssertEqual(data.tasks[0], other)
        XCTAssertNil(TaskRowConversion.toNote(taskID: UUID(), in: data))
        data.tasks.append(target)
        XCTAssertNil(TaskRowConversion.toNote(taskID: target.id, in: data))
    }
    @MainActor func testStorePersistsPopulatedPayloadAndExistingReverseConversion() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("workspace.json")
        var target = TaskItem(title: "Populated", body: "Styled body")
        target.richBody = RichBody(text: target.body, runs: [.init(location: 0, length: 6, bold: true)])
        target.checklist = [.init(title: "Keep step", isCompleted: true)]
        target.tagIDs = [UUID()]; target.priority = .high
        target.dueDate = Date(timeIntervalSince1970: 1900000000); target.hasDueTime = true
        target.scheduledDuration = .init(start: target.dueDate!.addingTimeInterval(-3600), end: target.dueDate!)
        let other = TaskItem(title: "Untouched")
        try JSONEncoder().encode(WorkspaceData(tasks: [target, other])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        store.updateTask(try XCTUnwrap(TaskRowConversion.toNote(taskID: target.id, in: store.data)))
        let saved = try XCTUnwrap(store.data.tasks.first { $0.id == target.id })
        XCTAssertEqual(saved.kind, .note)
        XCTAssertEqual(saved.body, target.body); XCTAssertEqual(saved.richBody, target.richBody)
        XCTAssertEqual(saved.checklist, target.checklist); XCTAssertEqual(saved.tagIDs, target.tagIDs)
        XCTAssertEqual(saved.dueDate, target.dueDate); XCTAssertEqual(saved.scheduledDuration, target.scheduledDuration)
        XCTAssertEqual(store.data.tasks.first { $0.id == other.id }, other)
        let reloaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(reloaded.data.tasks.first { $0.id == target.id }, saved)
        // Existing detail conversion back is available, not a new Undo command.
        store.updateTask(try XCTUnwrap(saved.converted(to: .task)))
        XCTAssertEqual(store.data.tasks.first { $0.id == target.id }?.richBody, target.richBody)
        XCTAssertEqual(store.data.tasks.first { $0.id == target.id }?.kind, .task)
    }
    func testRejectsNotesHistoryTrashAndArchivedTargets() {
        let original = TaskItem(title: "Target")
        var target = original; target.kind = .note
        XCTAssertNil(TaskRowConversion.toNote(taskID: target.id, in: WorkspaceData(tasks: [target])))
        target = original; target.completedAt = Date()
        XCTAssertNil(TaskRowConversion.toNote(taskID: target.id, in: WorkspaceData(tasks: [target])))
        target = original; target.wontDoAt = Date()
        XCTAssertNil(TaskRowConversion.toNote(taskID: target.id, in: WorkspaceData(tasks: [target])))
        target = original; target.deletedAt = Date()
        XCTAssertNil(TaskRowConversion.toNote(taskID: target.id, in: WorkspaceData(tasks: [target])))
        let list = TaskList(name: "Archive", color: "#000000", isArchived: true)
        target = original; target.listID = list.id
        XCTAssertNil(TaskRowConversion.toNote(taskID: target.id, in: WorkspaceData(tasks: [target], lists: [list])))
    }
}
