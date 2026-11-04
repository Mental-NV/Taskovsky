import XCTest
@testable import TaskovskyCore

final class TrashTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
    }

    @MainActor private func makeRichTask(_ store: TaskStore, listID: UUID?, tagIDs: [UUID]) -> UUID {
        let id = store.createTask(title: "Probe", listID: listID, dueDate: Date().addingTimeInterval(3600))
        var task = store.data.tasks.first { $0.id == id }!
        task.body = "Body text"
        task.tagIDs = tagIDs
        task.kind = .task
        task.hasDueTime = true
        task.reminderDate = task.dueDate
        task.priority = .high
        task.recurrence = .daily
        task.checklist = [ChecklistItem(title: "Step", isCompleted: true)]
        task.completedAt = Date()
        task.timeZoneID = "Asia/Tokyo"
        store.updateTask(task)
        return id
    }

    private func assertPreserved(_ restored: TaskItem, _ original: TaskItem, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(restored.title, original.title, file: file, line: line)
        XCTAssertEqual(restored.body, original.body, file: file, line: line)
        XCTAssertEqual(restored.listID, original.listID, file: file, line: line)
        XCTAssertEqual(restored.tagIDs, original.tagIDs, file: file, line: line)
        XCTAssertEqual(restored.kind, original.kind, file: file, line: line)
        XCTAssertEqual(restored.dueDate, original.dueDate, file: file, line: line)
        XCTAssertEqual(restored.hasDueTime, original.hasDueTime, file: file, line: line)
        XCTAssertEqual(restored.reminderDate, original.reminderDate, file: file, line: line)
        XCTAssertEqual(restored.priority, original.priority, file: file, line: line)
        XCTAssertEqual(restored.recurrence, original.recurrence, file: file, line: line)
        XCTAssertEqual(restored.checklist, original.checklist, file: file, line: line)
        XCTAssertEqual(restored.completedAt, original.completedAt, file: file, line: line)
        XCTAssertEqual(restored.wontDoAt, original.wontDoAt, file: file, line: line)
        XCTAssertEqual(restored.timeZoneID, original.timeZoneID, file: file, line: line)
        XCTAssertEqual(restored.recurrenceSourceID, original.recurrenceSourceID, file: file, line: line)
        XCTAssertNil(restored.deletedAt, file: file, line: line)
    }

    @MainActor func testTrashRestorePreservesEveryField() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let listID = store.createList(name: "Work", color: "#FF0000")
        let tagID = store.createTag(name: "Focus", color: "#00FF00")
        let id = makeRichTask(store, listID: listID, tagIDs: [tagID])
        let original = try XCTUnwrap(store.data.tasks.first { $0.id == id })

        store.trashTask(id: id)
        XCTAssertNotNil(store.data.tasks.first { $0.id == id }?.deletedAt)
        store.restoreTask(id: id)
        let restored = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        assertPreserved(restored, original)
    }

    @MainActor func testRestoreKeepsCompletedWontDoNoteAndMissingList() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let missingList = UUID()
        let completedID = store.createTask(title: "Done", listID: missingList)
        var done = store.data.tasks.first { $0.id == completedID }!
        done.completedAt = Date(); store.updateTask(done)
        let wontDoID = store.createTask(title: "Skip")
        var wont = store.data.tasks.first { $0.id == wontDoID }!
        wont.wontDoAt = Date(); store.updateTask(wont)
        let noteID = store.createTask(title: "Note", kind: .note, body: "Keep me")

        for id in [completedID, wontDoID, noteID] {
            store.trashTask(id: id)
            store.restoreTask(id: id)
        }
        let doneRestored = try XCTUnwrap(store.data.tasks.first { $0.id == completedID })
        XCTAssertNotNil(doneRestored.completedAt)
        XCTAssertEqual(doneRestored.listID, missingList)
        XCTAssertNotNil(store.data.tasks.first { $0.id == wontDoID }?.wontDoAt)
        let noteRestored = try XCTUnwrap(store.data.tasks.first { $0.id == noteID })
        XCTAssertEqual(noteRestored.kind, .note)
        XCTAssertEqual(noteRestored.body, "Keep me")
    }

    @MainActor func testPurgeGuardsMissingActiveAndOnlyTarget() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let listID = store.createList(name: "Keep", color: "#0000FF")
        let tagID = store.createTag(name: "Keep", color: "#00FF00")
        let seedID = store.createTask(title: "Seed")
        _ = store.saveTemplate(from: seedID)
        let activeID = store.createTask(title: "Active")
        let trashedID = store.createTask(title: "Gone", listID: listID)
        store.trashTask(id: trashedID)
        let counts = store.data.tasks.count

        XCTAssertFalse(store.purgeTask(id: UUID()))
        XCTAssertFalse(store.purgeTask(id: activeID))
        XCTAssertEqual(store.data.tasks.count, counts)
        XCTAssertTrue(store.purgeTask(id: trashedID))
        XCTAssertNil(store.data.tasks.first { $0.id == trashedID })
        XCTAssertNotNil(store.data.tasks.first { $0.id == activeID })
        XCTAssertNotNil(store.data.lists.first { $0.id == listID })
        XCTAssertNotNil(store.data.tags.first { $0.id == tagID })
        XCTAssertFalse(store.data.templates.isEmpty)
    }

    @MainActor func testRestoringRecurrentTaskSpawnsNothingAndKeepsSibling() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Daily", dueDate: Date().addingTimeInterval(-7200))
        var task = store.data.tasks.first { $0.id == id }!
        task.recurrence = .daily; store.updateTask(task)
        store.toggleComplete(id: id)
        let sibling = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        let countAfterSpawn = store.data.tasks.count

        store.trashTask(id: id)
        store.restoreTask(id: id)
        XCTAssertEqual(store.data.tasks.count, countAfterSpawn)
        XCTAssertNil(store.data.tasks.first { $0.id == id }?.deletedAt)
        XCTAssertEqual(store.data.tasks.first { $0.id == sibling.id }?.recurrenceSourceID, id)
        XCTAssertNil(store.data.tasks.first { $0.id == sibling.id }?.deletedAt)
    }

    func testTrashClaimConsumesOnce() {
        let coordinator = UndoCoordinator()
        let id = UUID()
        let claim = coordinator.record(taskID: id, kind: .trash)
        XCTAssertEqual(coordinator.consume(token: claim.token)?.taskID, id)
        XCTAssertNil(coordinator.consume(token: claim.token))
    }
}
