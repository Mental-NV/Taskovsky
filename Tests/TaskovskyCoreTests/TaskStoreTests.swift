import XCTest
@testable import TaskovskyCore

final class TaskStoreTests: XCTestCase {
    @MainActor func testAppRenameMovesWorkspaceAndSettingsWithoutChangingData() throws {
        let base = temporaryURL().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = base.appendingPathComponent(AppMigration.legacyName)
        let store = TaskStore(fileURL: legacy.appendingPathComponent("workspace.json"), seed: false)
        let id = store.createTask(title: "Keep my task")
        store.settings.defaultPriority = .high
        let workspace = try Data(contentsOf: store.fileURL)
        let settings = try Data(contentsOf: store.settingsURL)
        let backup = legacy.appendingPathComponent("recovery.bak")
        try workspace.write(to: backup)
        let migrated = try AppMigration.workspaceURL(in: base)
        XCTAssertEqual(migrated.deletingLastPathComponent().lastPathComponent, "Taskovsky")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(try Data(contentsOf: migrated), workspace)
        XCTAssertEqual(try Data(contentsOf: migrated.deletingLastPathComponent().appendingPathComponent("settings.json")), settings)
        XCTAssertEqual(try Data(contentsOf: migrated.deletingLastPathComponent().appendingPathComponent("recovery.bak")), workspace)
        let loaded = TaskStore(fileURL: migrated, seed: false)
        XCTAssertEqual(loaded.data.tasks.first?.id, id)
        XCTAssertEqual(loaded.settings.defaultPriority, .high)
        // A second launch and a leftover old directory cannot replace the renamed data.
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("old data".utf8).write(to: legacy.appendingPathComponent("workspace.json"))
        XCTAssertEqual(try AppMigration.workspaceURL(in: base), migrated)
        XCTAssertEqual(try Data(contentsOf: migrated), workspace)
    }

    func testAppRenamePreservesPreferencesAndDoesNotRestoreClearedHistory() throws {
        let suite = "TaskovskyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let legacy = suite + ".legacy"
        defer { defaults.removePersistentDomain(forName: suite); defaults.removePersistentDomain(forName: legacy) }
        defaults.setPersistentDomain([
            "\(AppMigration.legacyName).sidebarWidth": 240.0,
            "\(AppMigration.legacyName).sidebarCollapsed": true,
            "\(AppMigration.legacyName).taskPaneFraction": 0.6,
            "\(AppMigration.legacyName).recentSearches": ["Keep history"]
        ], forName: legacy)
        defaults.setPersistentDomain(["Taskovsky.sidebarWidth": 260.0], forName: suite)
        AppMigration.migratePreferences(defaults: defaults, destinationDomain: suite, legacyDomain: legacy)
        XCTAssertEqual(defaults.double(forKey: "Taskovsky.sidebarWidth"), 260)
        XCTAssertTrue(defaults.bool(forKey: "Taskovsky.sidebarCollapsed"))
        XCTAssertEqual(defaults.double(forKey: "Taskovsky.taskPaneFraction"), 0.6)
        XCTAssertEqual(defaults.stringArray(forKey: "Taskovsky.recentSearches"), ["Keep history"])
        defaults.removeObject(forKey: "Taskovsky.recentSearches")
        AppMigration.migratePreferences(defaults: defaults, destinationDomain: suite, legacyDomain: legacy)
        XCTAssertNil(defaults.object(forKey: "Taskovsky.recentSearches"))
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
    }

    @MainActor func testSettingsTemplatesFiltersAndLegacyWorkspace() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"tasks\":[],\"lists\":[],\"tags\":[]}".utf8).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(store.data.templates.count, 3)
        store.settings.defaultPriority = .high
        let id = store.createTask(title: "Draft tomorrow")
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.priority, .high); XCTAssertNotNil(task.dueDate)
        let templateID = try XCTUnwrap(store.saveTemplate(from: id))
        let filter = TaskFilter(name: "High", priority: .high)
        store.createFilter(filter)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.settings.defaultPriority, .high)
        XCTAssertTrue(loaded.data.templates.contains { $0.id == templateID })
        XCTAssertTrue(try XCTUnwrap(loaded.data.filters.first).matches(task))
        XCTAssertNotNil(loaded.createTaskFromTemplate(id: templateID))
    }

    @MainActor func testUndoRecurringCompletionPreservesEditedSuccessor() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Repeat", dueDate: Date())
        var original = try XCTUnwrap(store.data.tasks.first)
        original.recurrence = .daily; store.updateTask(original)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        store.undoCompletion(id: id)
        XCTAssertFalse(store.data.tasks.contains { $0.id == successor.id })
        store.toggleComplete(id: id)
        var edited = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        edited.title = "Edited"; store.updateTask(edited)
        store.undoCompletion(id: id)
        XCTAssertTrue(store.data.tasks.contains { $0.id == edited.id && $0.title == "Edited" })
        store.markWontDo(id: id)
        XCTAssertNotNil(store.data.tasks.first { $0.id == id }?.wontDoAt)
        store.reopenTask(id: id)
        XCTAssertNil(store.data.tasks.first { $0.id == id }?.wontDoAt)
    }

    func testLegacyTaskDecodesWithoutRecurrenceEnd() throws {
        let task = TaskItem(title: "Legacy", recurrence: .daily)
        let encoded = try JSONEncoder().encode(task)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "recurrenceEndDate")
        let decoded = try JSONDecoder().decode(TaskItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.recurrenceEndDate)
        XCTAssertEqual(decoded.recurrence, .daily)
    }

    @MainActor func testRecurrenceEndIsInclusiveInTaskTimeZoneAndUndoSafe() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let due = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let id = store.createTask(title: "Daily", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.hasDueTime = true; task.timeZoneID = calendar.timeZone.identifier
        task.recurrence = .daily; task.recurrenceEndDate = end; store.updateTask(task)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(successor.dueDate)), 8)
        XCTAssertEqual(calendar.component(.hour, from: try XCTUnwrap(successor.dueDate)), 23)
        store.undoCompletion(id: id)
        XCTAssertFalse(store.data.tasks.contains { $0.id == successor.id })
        store.toggleComplete(id: id)
        let final = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        store.toggleComplete(id: final.id)
        XCTAssertFalse(store.data.tasks.contains { $0.recurrenceSourceID == final.id })
        store.undoCompletion(id: final.id)
        XCTAssertNil(store.data.tasks.first { $0.id == final.id }?.completedAt)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == final.id }?.recurrenceEndDate, end)
    }

    @MainActor func testRecognitionAndSettings() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        store.settings.removeDateText = true
        store.settings.defaultReminder = .fifteenMinutesBefore
        store.settings.enableTimeZone = true
        let id = store.createTask(title: "Meet tomorrow 9am #Planning")
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.title, "Meet"); XCTAssertTrue(task.hasDueTime)
        XCTAssertEqual(try XCTUnwrap(task.dueDate).timeIntervalSince(try XCTUnwrap(task.reminderDate)), 900, accuracy: 0.1)
        XCTAssertEqual(task.timeZoneID, Calendar.current.timeZone.identifier)
        XCTAssertEqual(store.data.tags.first?.name, "Planning")
        XCTAssertEqual(task.tagIDs, store.data.tags.map(\.id))
        let contextual = Calendar.current.startOfDay(for: Date())
        let parsedID = store.createTask(title: "Report tomorrow at 14:30", dueDate: contextual, preferRecognizedDate: true)
        let parsed = try XCTUnwrap(store.data.tasks.first { $0.id == parsedID })
        let parsedDate = try XCTUnwrap(parsed.dueDate)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(parsedDate))
        XCTAssertEqual(Calendar.current.component(.hour, from: parsedDate), 14)
        XCTAssertEqual(Calendar.current.component(.minute, from: parsedDate), 30)
        XCTAssertTrue(parsed.hasDueTime)
        let explicitID = store.createTask(title: "Report tomorrow", dueDate: contextual)
        XCTAssertEqual(store.data.tasks.first { $0.id == explicitID }?.dueDate, contextual)
        for (phrase, hour, minute) in [("Meeting at 9 tomorrow", 9, 0), ("Meeting 14:30 tomorrow", 14, 30), ("Meeting 9am tomorrow", 9, 0)] {
            let id = store.createTask(title: phrase)
            let recognized = try XCTUnwrap(store.data.tasks.first { $0.id == id })
            let due = try XCTUnwrap(recognized.dueDate)
            XCTAssertEqual(recognized.title, "Meeting")
            XCTAssertTrue(recognized.hasDueTime)
            XCTAssertTrue(Calendar.current.isDateInTomorrow(due))
            XCTAssertEqual(Calendar.current.component(.hour, from: due), hour)
            XCTAssertEqual(Calendar.current.component(.minute, from: due), minute)
        }
        store.settings.urlParsing = false
        let urlID = store.createTask(title: "https://example.com/#section")
        let urlTask = try XCTUnwrap(store.data.tasks.first { $0.id == urlID })
        XCTAssertEqual(urlTask.title, "https://example.com/#section")
        XCTAssertFalse(store.data.tags.contains { $0.name == "section" })
        store.settings.dateRecognition = false; store.settings.removeTagText = false
        let plainID = store.createTask(title: "Call tomorrow #Planning")
        let plain = try XCTUnwrap(store.data.tasks.first { $0.id == plainID })
        XCTAssertNil(plain.dueDate); XCTAssertEqual(plain.title, "Call tomorrow #Planning")
    }

    @MainActor func testBuiltInTemplateMigrationRunsOnce() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(WorkspaceData()).write(to: url)
        let migrated = TaskStore(fileURL: url, seed: true)
        XCTAssertEqual(migrated.data.templates.count, 3)
        XCTAssertTrue(migrated.settings.hasInstalledBuiltInTemplates)
        for template in migrated.data.templates { migrated.deleteTemplate(id: template.id) }
        let reloaded = TaskStore(fileURL: url, seed: true)
        XCTAssertTrue(reloaded.data.templates.isEmpty)
    }

    @MainActor func testRecurringTaskKeepsWallTimeAcrossDST() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 9)))
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Daily", dueDate: date)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.hasDueTime = true; task.timeZoneID = calendar.timeZone.identifier; task.recurrence = .daily
        store.updateTask(task)
        store.toggleComplete(id: id)
        let next = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id }?.dueDate)
        XCTAssertEqual(calendar.component(.day, from: next), 8)
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
        XCTAssertEqual(next.timeIntervalSince(date), 23 * 3600, accuracy: 0.1)
    }

    @MainActor func testPersistenceAndCleanup() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let list = store.createList(name: "Work", color: "blue")
        let tag = store.createTag(name: "Focus", color: "red")
        let id = store.createTask(title: "Write", listID: list)
        var task = try XCTUnwrap(store.data.tasks.first)
        task.tagIDs = [tag]; store.updateTask(task)
        store.trashTask(id: id)
        XCTAssertNotNil(store.data.tasks.first?.deletedAt)
        store.restoreTask(id: id)
        store.deleteList(id: list); store.deleteTag(id: tag)
        let loaded = TaskStore(fileURL: url, seed: false)
        let saved = try XCTUnwrap(loaded.data.tasks.first)
        XCTAssertNil(saved.deletedAt); XCTAssertNil(saved.listID); XCTAssertTrue(saved.tagIDs.isEmpty)
        XCTAssertNil(loaded.storageError)
    }

    @MainActor func testUnreadableWorkspaceIsPreservedUntilExplicitRecovery() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("{not valid json".utf8)
        try corrupt.write(to: url)
        let store = TaskStore(fileURL: url, seed: true)
        XCTAssertTrue(store.data.tasks.isEmpty)
        XCTAssertNotNil(store.storageError)
        store.createTask(title: "Unsaved edit")
        store.save()
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        XCTAssertTrue(store.storageError?.contains("not being saved") == true)
        let backup = try XCTUnwrap(store.recoverUnreadableWorkspace())
        XCTAssertEqual(try Data(contentsOf: backup), corrupt)
        XCTAssertNil(store.storageError)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data.tasks.first?.title, "Unsaved edit")
    }

    @MainActor func testRecurringCompletionPreservesHistoryAndAvoidsDuplicates() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Monthly", dueDate: Date(timeIntervalSince1970: 1_706_709_600))
        var task = try XCTUnwrap(store.data.tasks.first)
        task.recurrence = .monthly; task.reminderDate = task.dueDate!.addingTimeInterval(-3600); task.checklist = [ChecklistItem(title: "One", isCompleted: true)]
        store.updateTask(task); store.toggleComplete(id: id)
        XCTAssertEqual(store.data.tasks.count, 2)
        let next = try XCTUnwrap(store.data.tasks.first { $0.id != id })
        XCTAssertNil(next.completedAt); XCTAssertEqual(next.reminderDate, next.dueDate?.addingTimeInterval(-3600)); XCTAssertFalse(next.checklist[0].isCompleted)
        let reloaded = TaskStore(fileURL: url, seed: false)
        reloaded.toggleComplete(id: id); reloaded.toggleComplete(id: id)
        XCTAssertEqual(reloaded.data.tasks.count, 2)
    }

    @MainActor func testStarterDataAndNormalizedNames() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url)
        let plan = try XCTUnwrap(store.data.tasks.first { $0.title == "Plan your week" })
        XCTAssertTrue(Calendar.current.isDateInToday(try XCTUnwrap(plan.dueDate)))
        XCTAssertEqual(plan.checklist.count, 2)
        XCTAssertTrue(store.data.tasks.contains { $0.listID == nil && $0.kind == .task })
        XCTAssertTrue(store.data.tasks.contains { $0.kind == .note })
        let tag = store.createTag(name: "  # Focus  ", color: "red")
        XCTAssertEqual(tag, store.createTag(name: "focus", color: "blue"))
        XCTAssertEqual(store.data.tags.filter { $0.name.lowercased() == "focus" }.count, 1)
        let taskID = store.createTask(title: "  Example  ")
        XCTAssertEqual(store.data.tasks.first { $0.id == taskID }?.title, "Example")
    }

    func testCalendarRecurrenceAcrossWeekendsAndShortMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
        }
        let monday = try XCTUnwrap(TaskStore.nextDate(after: date(2024, 3, 1), rule: .weekdays, calendar: calendar))
        XCTAssertEqual(monday, date(2024, 3, 4))
        let february = try XCTUnwrap(TaskStore.nextDate(after: date(2024, 1, 31), rule: .monthly, calendar: calendar))
        XCTAssertEqual(february, date(2024, 2, 29))
        let march = try XCTUnwrap(TaskStore.nextDate(after: february, rule: .monthly, anchorDay: 31, calendar: calendar))
        XCTAssertEqual(march, date(2024, 3, 31))
        let nextYear = try XCTUnwrap(TaskStore.nextDate(after: date(2024, 2, 29), rule: .yearly, calendar: calendar))
        XCTAssertEqual(nextYear, date(2025, 2, 28))
    }
}
