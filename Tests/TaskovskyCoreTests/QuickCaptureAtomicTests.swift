import XCTest
@testable import TaskovskyCore

final class QuickCaptureAtomicTests: XCTestCase {
    @MainActor func testFailedQuickCaptureKeepsWorkspaceAndRetryCreatesOnce() throws {
        for position in TaskPosition.allCases {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("workspace.json")
            let list = TaskList(name: "Owned", color: "#123456")
            let workspace = WorkspaceData(tasks: [TaskItem(title: "Existing")], lists: [list])
            let bytes = try JSONEncoder().encode(workspace)
            try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            store.settings.defaultAddTo = position
            store.settings.defaultListID = list.id
            store.settings.removeTagText = true
            store.settings.urlParsing = false
            let body = "Owned capture body"
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            XCTAssertNil(store.createQuickEntryTask(title: "Owned capture #NewOwnedTag", recognizeDates: false, body: body))
            XCTAssertEqual(store.data, workspace)
            XCTAssertNotNil(store.storageError)
            try FileManager.default.removeItem(at: url)
            try bytes.write(to: url)
            let id = try XCTUnwrap(store.createQuickEntryTask(title: "Owned capture #NewOwnedTag", recognizeDates: false, body: body))
            XCTAssertEqual(store.data.tasks.count, 2)
            XCTAssertEqual(store.data.tags.count, 1)
            let task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
            XCTAssertEqual(task.title, "Owned capture")
            XCTAssertEqual(task.body, body)
            XCTAssertEqual(task.listID, list.id)
            XCTAssertEqual(task.tagIDs, store.data.tags.map(\.id))
            XCTAssertEqual(position == .top ? store.data.tasks.first?.id : store.data.tasks.last?.id, id)
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
        }
    }
    @MainActor func testSuccessfulQuickCapturePreservesConstructionDefaultsAndContext() throws {
        for kind in [TaskKind.task, .note] {
            for recognizeDates in [false, true] {
                for useDefaultList in [false, true] {
                    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    defer { try? FileManager.default.removeItem(at: directory) }
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let url = directory.appendingPathComponent("workspace.json")
                    let list = TaskList(name: "Default", color: "#123456")
                    let tag = TaskTag(name: "Existing", color: "#234567")
                    let workspace = WorkspaceData(lists: [list], tags: [tag])
                    try JSONEncoder().encode(workspace).write(to: url)
                    let store = TaskStore(fileURL: url, seed: false)
                    store.settings.defaultListID = list.id
                    store.settings.defaultTagID = tag.id
                    store.settings.defaultDate = .today
                    store.settings.defaultDurationMinutes = 45
                    store.settings.urlParsing = false
                    let context = store.settings.calendar.startOfDay(for: Date())
                    let title = "Capture tomorrow at 14:30 #Existing"
                    let id = try XCTUnwrap(store.createQuickEntryTask(title: title, kind: kind, dueDate: context,
                        useDefaultList: useDefaultList, preferRecognizedDate: true, recognizeDates: recognizeDates, body: "Exact body"))
                    let actual = try XCTUnwrap(store.data.tasks.first { $0.id == id })
                    let expected = TaskCreation.make(workspace: workspace, settings: store.settings, title: title,
                        kind: kind, dueDate: context, useDefaultList: useDefaultList, preferRecognizedDate: true,
                        recognizeDates: recognizeDates, body: "Exact body", now: actual.createdAt, id: actual.id)
                    XCTAssertEqual(actual, expected.task)
                    XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
                }
            }
        }
    }

}
