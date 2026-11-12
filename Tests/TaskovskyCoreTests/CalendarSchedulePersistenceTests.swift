import XCTest
@testable import TaskovskyCore

final class CalendarSchedulePersistenceTests: XCTestCase {
    @MainActor func testCalendarMoveMustNotOverwriteOtherStoreTitle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Original", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true)
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        let stale = TaskStore(fileURL: url, seed: false)
        let other = TaskStore(fileURL: url, seed: false)
        var edited = other.data.tasks[0]
        edited.title = "Saved independently"
        other.updateTask(edited)
        XCTAssertNil(other.storageError)
        let saved = try Data(contentsOf: url)
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: saved).tasks[0].title, "Saved independently")
        let token = stale.scheduleOnCalendar(id: task.id, operation: .move(start: Date(timeIntervalSince1970: 2_000_003_600), allDay: false))
        // Conservative safe-refusal contract; rebasing could be a separately designed alternative.
        XCTAssertNil(token)
        XCTAssertEqual(try Data(contentsOf: url), saved)
        XCTAssertEqual(stale.data.tasks[0], task)
    }

    @MainActor func testCalendarMoveMustPreserveUnknownTaskData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Owned fixture", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [task]))) as? [String: Any])
        var tasks = try XCTUnwrap(raw["tasks"] as? [[String: Any]])
        tasks[0]["futureOwnedFixtureField"] = ["mustSurvive": true]
        raw["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: raw).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertFalse(store.needsRecovery)
        let token = store.scheduleOnCalendar(id: task.id, operation: .move(start: Date(timeIntervalSince1970: 2_000_003_600), allDay: false))
        XCTAssertNotNil(token, "Control: the current implementation accepts this move")
        XCTAssertNotEqual(store.data.tasks[0].dueDate, task.dueDate)
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let afterTasks = try XCTUnwrap(after["tasks"] as? [[String: Any]])
        XCTAssertEqual((afterTasks[0]["futureOwnedFixtureField"] as? [String: Bool])?["mustSurvive"], true)
        XCTAssertTrue(store.undoCalendarSchedule(try XCTUnwrap(token)))
        let restored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let restoredTasks = try XCTUnwrap(restored["tasks"] as? [[String: Any]])
        XCTAssertEqual((restoredTasks[0]["futureOwnedFixtureField"] as? [String: Bool])?["mustSurvive"], true)
    }
}

extension CalendarSchedulePersistenceTests {
    @MainActor private func fixture(_ body: (TaskStore, URL, TaskItem) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Owned", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true)
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        try body(TaskStore(fileURL: url, seed: false), url, task)
    }
    @MainActor func testUndoRefusesSeparateWriterAndPreservesSavedBytes() throws {
        try fixture { store, url, task in
            let token = try XCTUnwrap(store.scheduleOnCalendar(id: task.id, operation: .move(start: task.dueDate!.addingTimeInterval(3600), allDay: false)))
            let other = TaskStore(fileURL: url, seed: false)
            var edit = other.data.tasks[0]; edit.title = "Independent edit"; other.updateTask(edit)
            let bytes = try Data(contentsOf: url), before = store.data
            XCTAssertFalse(store.undoCalendarSchedule(token))
            XCTAssertEqual(store.data, before); XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    @MainActor func testExplicitSaveRefusesSeparateWriter() throws {
        try fixture { store, url, task in
            let other = TaskStore(fileURL: url, seed: false)
            var edit = other.data.tasks[0]; edit.title = "Independent edit"; other.updateTask(edit)
            var candidate = task; candidate.dueDate = task.dueDate!.addingTimeInterval(3600)
            let bytes = try Data(contentsOf: url)
            XCTAssertFalse(store.saveSchedule(candidate, expected: task))
            XCTAssertEqual(try Data(contentsOf: url), bytes); XCTAssertEqual(store.data.tasks[0], task)
        }
    }
    @MainActor func testExactUnicodeExternalEditRefusesCalendarWrite() throws {
        try fixture { _, url, task in
            var original = task; original.title = "\u{00E9}"
            try JSONEncoder().encode(WorkspaceData(tasks: [original])).write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            var changed = original; changed.title = "e\u{0301}"
            XCTAssertEqual(original.title, changed.title)
            try JSONEncoder().encode(WorkspaceData(tasks: [changed])).write(to: url)
            let bytes = try Data(contentsOf: url)
            XCTAssertNil(store.scheduleOnCalendar(id: task.id, operation: .move(start: task.dueDate!.addingTimeInterval(3600), allDay: false)))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    @MainActor func testExplicitUnchangedSavePreservesBytesAndActualSavePreservesUnknown() throws {
        try fixture { _, url, task in
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            object["ownedFutureRoot"] = ["retain": true]
            try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]).write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            let bytes = try Data(contentsOf: url)
            XCTAssertTrue(store.saveSchedule(task, expected: task))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            var candidate = task; candidate.dueDate = task.dueDate!.addingTimeInterval(3600)
            XCTAssertTrue(store.saveSchedule(candidate, expected: task))
            let after = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            XCTAssertEqual((after["ownedFutureRoot"] as? [String: Bool])?["retain"], true)
        }
    }
    @MainActor func testFailedWriteDoesNotPublishAndCanRetry() throws {
        try fixture { store, url, task in
            let bytes = try Data(contentsOf: url)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            XCTAssertNil(store.scheduleOnCalendar(id: task.id, operation: .move(start: task.dueDate!.addingTimeInterval(3600), allDay: false)))
            XCTAssertEqual(store.data.tasks[0], task)
            try FileManager.default.removeItem(at: url); try bytes.write(to: url)
            XCTAssertNotNil(store.scheduleOnCalendar(id: task.id, operation: .move(start: task.dueDate!.addingTimeInterval(3600), allDay: false)))
            XCTAssertNil(store.storageError)
        }
    }
}

extension CalendarSchedulePersistenceTests {
    @MainActor func testExplicitSaveFailureThenRetry() throws {
        try fixture { store, url, task in
            var candidate = task; candidate.dueDate = task.dueDate!.addingTimeInterval(3600)
            let bytes = try Data(contentsOf: url)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            XCTAssertFalse(store.saveSchedule(candidate, expected: task))
            XCTAssertEqual(store.data.tasks[0], task)
            try FileManager.default.removeItem(at: url); try bytes.write(to: url)
            XCTAssertTrue(store.saveSchedule(candidate, expected: task))
            XCTAssertEqual(store.data.tasks[0].dueDate, candidate.dueDate)
            XCTAssertNil(store.storageError)
        }
    }
    @MainActor func testProtectedUpgradeWithUnknownDataRefusesWithoutLoss() throws {
        try fixture { _, url, task in
            var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            root["ownedFuture"] = true
            let bytes = try JSONSerialization.data(withJSONObject: root)
            try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            var candidate = task
            candidate.scheduledDuration = .init(start: task.dueDate!.addingTimeInterval(-3600), end: task.dueDate!)
            candidate.endReminderEnabled = true
            XCTAssertFalse(store.saveSchedule(candidate, expected: task))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(store.data.tasks[0], task)
        }
    }
}
