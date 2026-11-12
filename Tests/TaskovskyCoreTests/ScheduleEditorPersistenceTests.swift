import XCTest
@testable import TaskovskyCore

final class ScheduleEditorPersistenceTests: XCTestCase {
    @MainActor func testFailedScheduleSaveAndClearDoNotPublish() throws {
        for clear in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("workspace.json")
            var task = TaskItem(title: "Owned scheduled", dueDate: Date(timeIntervalSince1970: 1_794_528_000))
            task.hasDueTime = true; task.recurrence = .daily; task.reminderDates = [task.dueDate!.addingTimeInterval(-300)]
            let initial = WorkspaceData(tasks: [task])
            let bytes = try JSONEncoder().encode(initial); try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            var draft = task
            draft.dueDate = clear ? nil : task.dueDate!.addingTimeInterval(7200)
            draft.hasDueTime = !clear
            draft.reminderDates = clear ? [] : [draft.dueDate!.addingTimeInterval(-300)]
            if clear { draft.recurrence = .none }
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            XCTAssertFalse(store.saveSchedule(draft, expected: task))
            XCTAssertEqual(store.data, initial)
            XCTAssertNotNil(store.storageError)
            try FileManager.default.removeItem(at: url); try bytes.write(to: url)
            XCTAssertTrue(store.saveSchedule(draft, expected: task))
            XCTAssertEqual(store.data.tasks.first?.dueDate, draft.dueDate)
            XCTAssertEqual(store.data.tasks.first?.reminderDates, draft.reminderDates)
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
        }
    }
    @MainActor func testScheduleOnlyPatchPreservesConcurrentContentAndRejectsStaleSchedule() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("workspace.json")
        let task = TaskItem(title: "Original", dueDate: Date(timeIntervalSince1970: 1_794_528_000))
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
        let loaded = TaskStore(fileURL: url, seed: false)
        var concurrent = task; concurrent.title = "New title"; concurrent.body = "New body"; concurrent.priority = .high; concurrent.tagIDs = [UUID()]; concurrent.checklist = [ChecklistItem(title: "Keep step")]
        XCTAssertTrue(loaded.setTaskProgress(taskID: task.id, percent: 40, expected: nil))
        loaded.updateTask(concurrent)
        var candidate = task; candidate.dueDate = task.dueDate!.addingTimeInterval(86400)
        XCTAssertTrue(loaded.saveSchedule(candidate, expected: task))
        let saved = try XCTUnwrap(loaded.data.tasks.first)
        XCTAssertEqual(saved.title, "New title"); XCTAssertEqual(saved.body, "New body")
        XCTAssertEqual(saved.dueDate, candidate.dueDate)
        XCTAssertEqual(saved.manualProgress, 40); XCTAssertEqual(saved.priority, .high)
        XCTAssertEqual(saved.tagIDs, concurrent.tagIDs); XCTAssertEqual(saved.checklist, concurrent.checklist)
        let bytes = try Data(contentsOf: url)
        XCTAssertFalse(loaded.saveSchedule(task, expected: task))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertEqual(loaded.data.tasks.first, saved)
    }

    @MainActor func testSchedulePatchMatchesExistingNormalizationWithoutOverwritingContent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for zone in [nil, "America/New_York"] as [String?] {
            let url = root.appendingPathComponent(UUID().uuidString)
            var task = TaskItem(title: "Owned", dueDate: Date(timeIntervalSince1970: 1_794_528_000))
            task.hasDueTime = true; task.timeZoneID = zone; task.recurrence = .monthly
            task.recurrenceAnchorDay = 31
            try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            let legacyURL = root.appendingPathComponent(UUID().uuidString)
            try Data(contentsOf: url).write(to: legacyURL)
            let legacy = TaskStore(fileURL: legacyURL, seed: false)
            var candidate = task
            let due = task.dueDate!.addingTimeInterval(71.25)
            candidate.dueDate = due
            candidate.scheduledDuration = TaskDurationRange(start: due.addingTimeInterval(-0.5), end: due, isAllDay: false)
            candidate.reminderDates = [due.addingTimeInterval(-60)]; candidate.reminderFollowsSchedule = false
            legacy.updateTask(candidate, applyDefaultReminders: false)
            XCTAssertTrue(store.saveSchedule(candidate, expected: task))
            XCTAssertEqual(CalendarScheduleSnapshot(try XCTUnwrap(store.data.tasks.first)), CalendarScheduleSnapshot(try XCTUnwrap(legacy.data.tasks.first)))
            XCTAssertEqual(store.data.tasks.first?.timeZoneID, zone)
        }
    }

    @MainActor func testChangedStatusKindArchiveAndMissingTaskRefuseSchedule() throws {
        for condition in ["completed", "wontDo", "deleted", "kind", "archive", "missing"] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("workspace.json")
            var list = TaskList(name: "Owned", color: "#123456")
            let expected = TaskItem(title: "Owned", listID: list.id, dueDate: Date())
            var current = expected
            switch condition {
            case "completed": current.completedAt = Date()
            case "wontDo": current.wontDoAt = Date()
            case "deleted": current.deletedAt = Date()
            case "kind": current.kind = .note
            case "archive": list.isArchived = true
            default: break
            }
            let data = WorkspaceData(tasks: condition == "missing" ? [] : [current], lists: [list])
            let bytes = try JSONEncoder().encode(data); try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            XCTAssertFalse(store.saveSchedule(expected, expected: expected), condition)
            XCTAssertEqual(store.data, data); XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    @MainActor func testOccurrenceBaselineSurvivesUnchangedSaveAndClearRemovesWholeSchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let due = ISO8601DateFormatter().date(from: "2026-11-01T06:30:00Z")!
        var original = TaskItem(title: "Owned recurring", dueDate: due, hasDueTime: true,
                                reminderDate: due - 600, recurrence: .daily,
                                reminderFollowsSchedule: false, scheduledDuration: .init(start: due - 1800, end: due))
        original.endReminderEnabled = true
        let moved = try XCTUnwrap(CalendarScheduling.prepared(.move(start: due + 86400 - 1800, allDay: false),
            to: original, displayCalendar: calendar, settings: .init(), policyCalendar: calendar, scope: .currentOccurrence))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("workspace.json")
        try JSONEncoder().encode(WorkspaceData(tasks: [moved])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(store.saveSchedule(moved, expected: moved))
        let saved = try XCTUnwrap(store.data.tasks.first)
        XCTAssertEqual(CalendarScheduleSnapshot(saved), CalendarScheduleSnapshot(moved))
        var cleared = saved
        cleared.dueDate = nil; cleared.hasDueTime = false; cleared.reminderDates = []
        cleared.reminderFollowsSchedule = nil; cleared.endReminderEnabled = false
        cleared.recurrence = .none; cleared.customRecurrence = nil; cleared.recurrenceEndDate = nil
        cleared.recurrenceAnchorDay = nil; cleared.recurrenceAnchorMonth = nil
        cleared.scheduledDuration = nil; cleared.timeZoneID = nil; cleared.occurrenceIndex = 1
        XCTAssertTrue(store.saveSchedule(cleared, expected: saved))
        let result = try XCTUnwrap(store.data.tasks.first)
        XCTAssertNil(result.dueDate); XCTAssertNil(result.scheduledDuration)
        XCTAssertNil(result.originalOccurrenceSchedule); XCTAssertNil(result.recurrenceNominalDate)
        XCTAssertEqual(result.recurrence, .none); XCTAssertTrue(result.reminderDates.isEmpty)
        XCTAssertFalse(result.endReminderEnabled)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
    }

}
