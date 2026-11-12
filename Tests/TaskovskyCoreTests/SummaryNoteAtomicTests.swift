import XCTest
@testable import TaskovskyCore

final class SummaryNoteAtomicTests: XCTestCase {
    @MainActor func testFailedSummarySavePublishesNothingAndRetryPersistsCleanNote() throws {
        for position in TaskPosition.allCases {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("workspace.json")
            let list = TaskList(name: "Owned", color: "#123456")
            let tag = TaskTag(name: "Owned", color: "#123456")
            let initial = WorkspaceData(tasks: [TaskItem(title: "Existing")], lists: [list], tags: [tag])
            let bytes = try JSONEncoder().encode(initial); try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            store.settings.defaultAddTo = position
            store.settings.defaultListID = list.id; store.settings.defaultTagID = tag.id
            store.settings.defaultDate = .tomorrow; store.settings.defaultPriority = .high
            store.settings.urlParsing = false
            let body = "Edited report\n#not-a-tag tomorrow at 14:00\nExact text."
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            XCTAssertNil(store.createSummaryNote(title: "Summary owned range", body: body))
            XCTAssertEqual(store.data, initial)
            XCTAssertNotNil(store.storageError)
            try FileManager.default.removeItem(at: url); try bytes.write(to: url)
            let id = try XCTUnwrap(store.createSummaryNote(title: "Summary owned range", body: body))
            XCTAssertEqual(store.data.tasks.count, 2)
            let note = try XCTUnwrap(store.data.tasks.first { $0.id == id })
            XCTAssertEqual(note.title, "Summary owned range"); XCTAssertEqual(note.body, body)
            XCTAssertEqual(note.kind, .note); XCTAssertNil(note.listID); XCTAssertNil(note.dueDate)
            XCTAssertFalse(note.hasDueTime); XCTAssertNil(note.scheduledDuration)
            XCTAssertTrue(note.reminderDates.isEmpty); XCTAssertEqual(note.reminderFollowsSchedule, false)
            XCTAssertTrue(note.tagIDs.isEmpty); XCTAssertEqual(note.priority, .none)
            XCTAssertEqual(position == .top ? store.data.tasks.first?.id : store.data.tasks.last?.id, id)
            XCTAssertEqual(store.data.tags, initial.tags)
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
        }
    }
}
