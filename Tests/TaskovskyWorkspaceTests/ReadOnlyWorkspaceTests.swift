import XCTest
import TaskovskyDomain
import TaskovskyWorkspace

final class ReadOnlyWorkspaceTests: XCTestCase {
    func testUnknownPayloadElsewhereAndMalformedRichDataRemainInOriginalBytes() throws {
        var task = TaskItem(title: "Styled", body: "e\u{301} 🧩")
        task.richBody = RichBody(text: "different", runs: [.init(location: Int.max, length: Int.max, bold: true)])
        let other = TaskItem(title: "Unrelated")
        let data = try JSONEncoder().encode(WorkspaceData(tasks: [task, other]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        tasks[1]["futurePayload"] = ["version": 999, "opaque": ["do not erase", "🧩"]]
        object["tasks"] = tasks; object["futureWorkspaceField"] = ["enabled": true]
        let original = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let settings = try JSONEncoder().encode(AppSettings())
        let snapshot = try ReadOnlyWorkspaceSnapshot(workspaceBytes: original, settingsBytes: settings)
        XCTAssertEqual(snapshot.workspaceBytes, original)
        XCTAssertEqual(snapshot.settingsBytes, settings)
        XCTAssertTrue(snapshot.workspace.tasks[0].body.utf16.elementsEqual(task.body.utf16))
        XCTAssertEqual(snapshot.workspace.tasks[0].richBody, task.richBody)
        XCTAssertNil(snapshot.workspace.tasks[0].richBody?.valid(for: task.body))
        _ = TaskDestination.inbox.matchingTasks(in: snapshot.workspace)
        XCTAssertEqual(snapshot.workspaceBytes, original)
    }

    func testUnreadableWorkspaceOrUnknownEnumFailsWithoutEmptyFallback() throws {
        let settings = try JSONEncoder().encode(AppSettings())
        XCTAssertThrowsError(try ReadOnlyWorkspaceSnapshot(workspaceBytes: Data("broken".utf8), settingsBytes: settings))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [TaskItem(title: "Future")])) ) as? [String: Any])
        var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        tasks[0]["kind"] = "future-kind"; object["tasks"] = tasks
        let original = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ReadOnlyWorkspaceSnapshot(workspaceBytes: original, settingsBytes: settings))
    }

    func testCorruptSettingsBlocksSessionRatherThanUsingDefaults() throws {
        let workspace = try JSONEncoder().encode(WorkspaceData())
        XCTAssertThrowsError(try ReadOnlyWorkspaceSnapshot(workspaceBytes: workspace, settingsBytes: Data("broken".utf8)))
    }
}

private enum FixtureWriteError: Error { case denied }

extension ReadOnlyWorkspaceTests {
    func testTaskOrderPreservesRecordsAndSettingsAndRefusesStaleOrOutOfGroupMoves() async throws {
        let a = TaskItem(title: "First")
        var b = TaskItem(title: "Second", body: "Body 🧩", dueDate: Date(timeIntervalSinceReferenceDate: 500))
        b.richBody = RichBody(text: b.body, runs: [.init(location: 0, length: 4, bold: true)])
        let hidden = TaskItem(title: "Other row")
        var pinned = TaskItem(title: "Pinned")
        pinned.isPinned = true
        var child = TaskItem(title: "Child")
        child.parentID = a.id
        var done = TaskItem(title: "Completed")
        done.completedAt = Date(timeIntervalSinceReferenceDate: 100)
        let files = try fixture(WorkspaceData(tasks: [a, hidden, b, pinned, child, done]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        for target in [b.id, pinned.id, child.id, done.id] {
            let id = target == b.id ? b.id : a.id
            guard case .refused = await repo.reorderTask(id, relativeTo: target, after: false, expected: initial.revision)
            else { return XCTFail("Expected an invalid move to be refused.") }
        }
        let before = try await repo.load()
        XCTAssertEqual(before.snapshot.workspaceBytes, initial.snapshot.workspaceBytes)
        guard case .saved(let moved) = await repo.reorderTask(b.id, relativeTo: a.id, after: false, expected: initial.revision)
        else { return XCTFail("Expected a saved reorder.") }
        XCTAssertEqual(moved.snapshot.workspace.tasks, [b, a, hidden, pinned, child, done])
        XCTAssertEqual(moved.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        guard case .unchanged = await repo.reorderTask(b.id, relativeTo: a.id, after: false, expected: moved.revision),
              case .refused(.stale) = await repo.reorderTask(a.id, relativeTo: b.id, after: false, expected: initial.revision)
        else { return XCTFail("Expected an unchanged move and stale refusal.") }
        let reopened = try await repository(files).load()
        XCTAssertEqual(reopened.snapshot.workspaceBytes, moved.snapshot.workspaceBytes)
        XCTAssertEqual(reopened.snapshot.settingsBytes, initial.snapshot.settingsBytes)
    }

    func testCurrentOccurrenceFileProtectsItsBaselineFromOlderWritersAndUndoPreservesTitle() async throws {
        struct LegacyTaskCollection: Decodable { let tasks: [TaskItem] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let due = Date(timeIntervalSinceReferenceDate: 816_080_400)
        let task = TaskItem(title: "Weekly", dueDate: due, hasDueTime: true, recurrence: .weekly)
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(LegacyTaskCollection.self, from: initial.snapshot.workspaceBytes).tasks, [task])

        let newDate = due.addingTimeInterval(3600)
        guard case .saved(let moved, let undo?) = await repo.apply(.setPoint(date: newDate, allDay: false), to: task.id,
            expected: initial.revision, calendar: calendar, scope: .currentOccurrence) else { return XCTFail("Expected an occurrence exception") }
        XCTAssertThrowsError(try decoder.decode(LegacyTaskCollection.self, from: moved.snapshot.workspaceBytes))
        XCTAssertEqual(moved.snapshot.workspace.tasks[0].dueDate, newDate)
        XCTAssertEqual(moved.snapshot.workspace.tasks[0].originalOccurrenceSchedule?.due, due)
        let reloaded = try await repository(files).load()
        XCTAssertTrue(reloaded.allowsKnownFieldWrites)
        XCTAssertEqual(reloaded.snapshot.workspace, moved.snapshot.workspace)
        XCTAssertEqual(reloaded.snapshot.settingsBytes, initial.snapshot.settingsBytes)

        guard case .saved = await repo.apply(.title("Renamed"), to: task.id, expected: moved.revision)
        else { return XCTFail("Expected an unrelated title edit") }
        guard case .saved(let restored, _) = await repo.undo(undo) else { return XCTFail("Expected scoped Undo") }
        let legacy = try decoder.decode(LegacyTaskCollection.self, from: restored.snapshot.workspaceBytes).tasks
        XCTAssertEqual(legacy.first?.title, "Renamed")
        XCTAssertEqual(legacy.first?.dueDate, due)
        XCTAssertNil(legacy.first?.originalOccurrenceSchedule)
        XCTAssertEqual(restored.snapshot.settingsBytes, initial.snapshot.settingsBytes)

        guard case .saved(let again, _) = await repo.apply(.setPoint(date: newDate, allDay: false), to: task.id,
            expected: restored.revision, calendar: calendar, scope: .currentOccurrence),
            case .saved(let explicit, _) = await repo.apply(.restoreOccurrence, to: task.id, expected: again.revision,
                                                            calendar: calendar)
        else { return XCTFail("Expected explicit restoration after reopening the protected file") }
        let restoredLegacy = try decoder.decode(LegacyTaskCollection.self, from: explicit.snapshot.workspaceBytes).tasks
        XCTAssertEqual(restoredLegacy.first?.dueDate, due)
        XCTAssertEqual(restoredLegacy.first?.title, "Renamed")
        XCTAssertNil(restoredLegacy.first?.originalOccurrenceSchedule)
    }

    func testRichBodyTransactionCommitsThePairAndRefusesAPartialEdit() async throws {
        var task = TaskItem(title: "Keep title", body: "Keep e\u{301} 🧩")
        task.richBody = RichBody(text: task.body, runs: [.init(location: 0, length: 4, bold: true)])
        let other = TaskItem(title: "Unrelated")
        let files = try fixture(WorkspaceData(tasks: [task, other]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        let valid = RichBodyEdit.replace(NSRange(location: 5, length: 2), with: "a", style: .plain)
        let invalid = RichBodyEdit.toggle(.bold, NSRange(location: Int.max, length: 1))
        assertRefused(await repo.apply(.richBody([valid, invalid]), to: task.id, expected: initial.revision),
                      .richBody(.invalidRange))
        XCTAssertEqual(try Data(contentsOf: files.workspace), initial.snapshot.workspaceBytes)
        let stamp = Date(timeIntervalSinceReferenceDate: 815_907_600)
        guard case .saved(let saved) = await repo.apply(.richBody([valid]), to: task.id, expected: initial.revision, now: stamp)
        else { return XCTFail("Expected a saved paired body edit") }
        task.body = "Keep a 🧩"
        task.richBody = RichBody(text: task.body, runs: [.init(location: 0, length: 4, bold: true)])
        task.updatedAt = stamp
        XCTAssertEqual(saved.snapshot.workspace.tasks, [task, other])
        XCTAssertEqual(saved.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        assertRefused(await repo.apply(.richBody([valid]), to: task.id, expected: initial.revision), .stale)
        guard case .unchanged = await repo.apply(.richBody([]), to: task.id, expected: saved.revision)
        else { return XCTFail("An empty transaction must preserve the original record bytes") }
    }

    func testRichDraftRecoveryRetainsFormattingAndRejectsOldCallbacksAfterUndo() async throws {
        let text = "e\u{301} 🧩"
        let rich = RichBody(text: text, runs: [.init(location: 0, length: 2, italic: true)])
        let task = TaskItem(title: "Task", body: text, richBody: rich)
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let workspace = try await repo.load()
        var draft = TaskFieldDraft(taskID: task.id, field: .richBody, baseRevision: workspace.revision,
                                   text: text, richBody: rich)
        let url = files.directory.appendingPathComponent("field-draft.json")
        let store = FieldDraftStore(fileURL: url)
        let began = await store.begin(draft)
        XCTAssertEqual(began, .saved)
        try draft.applyRichEdit(.toggle(.bold, NSRange(location: 0, length: 2)))
        let staged = await store.save(draft)
        XCTAssertEqual(staged, .saved)
        let reopened = FieldDraftStore(fileURL: url)
        guard case .available(var recovered) = await reopened.load() else { return XCTFail("Expected a rich recovery draft") }
        XCTAssertTrue(recovered.isRecoverable)
        XCTAssertTrue(recovered.hasChanges)
        XCTAssertTrue(RichBody.sameCodeUnits(recovered.text, text))
        XCTAssertEqual(recovered.richState?.content.runs, [.init(location: 0, length: 2, bold: true, italic: true)])
        XCTAssertEqual(try Data(contentsOf: files.workspace), workspace.snapshot.workspaceBytes)
        try recovered.replaceRichEdits([])
        XCTAssertFalse(recovered.hasChanges)
        let undone = await reopened.save(recovered)
        let delayed = await reopened.save(draft)
        XCTAssertEqual(undone, .saved)
        XCTAssertEqual(delayed, .refused)
        let closed = await reopened.close(id: recovered.id)
        XCTAssertEqual(closed, .saved)
        XCTAssertEqual(try Data(contentsOf: files.workspace), workspace.snapshot.workspaceBytes)
    }

    func testTemplateSearchAndOrderPreserveStoredRecords() async throws {
        let body = "Résumé details"
        let first = TaskTemplate(name: "Plan", title: "Café follow-up", body: body,
                                 richBody: RichBody(text: body, runs: [.init(location: 0, length: 6, bold: true)]))
        let second = TaskTemplate(name: "Travel", title: "Pack", checklist: [ChecklistItem(title: "Passport")])
        let templates = [first, second]
        XCTAssertEqual(TaskTemplate.matching("  CAFE ", in: templates), [first])
        XCTAssertEqual(TaskTemplate.matching("resume", in: templates), [first])
        XCTAssertEqual(TaskTemplate.matching("passport", in: templates), [second])
        XCTAssertEqual(TaskTemplate.matching("PLAN", in: templates), [first])
        XCTAssertEqual(TaskTemplate.matching(" ", in: templates), templates)
        XCTAssertTrue(TaskTemplate.matching("unavailable", in: templates).isEmpty)

        let task = TaskItem(title: "Existing")
        let files = try fixture(WorkspaceData(tasks: [task], templates: templates))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        let ids = templates.map(\.id)
        guard case .refused = await repo.apply(.reorder(ids: [first.id, first.id], expectedOrder: ids), expected: initial.revision),
              case .unchanged = await repo.apply(.reorder(ids: ids, expectedOrder: ids), expected: initial.revision)
        else { return XCTFail("Expected duplicate refusal and unchanged order.") }
        let order = Array(ids.reversed())
        guard case .saved(let moved) = await repo.apply(.reorder(ids: order, expectedOrder: ids), expected: initial.revision),
              case .refused(.stale) = await repo.apply(.reorder(ids: ids, expectedOrder: order), expected: initial.revision),
              case .refused = await repo.apply(.reorder(ids: ids, expectedOrder: ids), expected: moved.revision)
        else { return XCTFail("Expected a saved reorder and stale-order refusals.") }
        let reloaded = try await repository(files).load()
        XCTAssertEqual(reloaded.snapshot.workspace.templates, [second, first])
        XCTAssertEqual(reloaded.snapshot.workspace.tasks, [task])
        XCTAssertEqual(reloaded.snapshot.workspaceBytes, moved.snapshot.workspaceBytes)
        XCTAssertEqual(reloaded.snapshot.settingsBytes, initial.snapshot.settingsBytes)
    }

    func testTemplateReducedEditPreservesRichContentAndUnownedFields() async throws {
        let body = "e\u{301} 🧩"
        let rich = RichBody(text: body, runs: [.init(location: 0, length: 2, bold: true)])
        let checked = ChecklistItem(title: "Preserved step", isCompleted: true)
        let tag = TaskTag(name: "Planning", color: "#123456")
        let due = Date(timeIntervalSinceReferenceDate: 815_907_600)
        let template = TaskTemplate(name: "Plan", title: "Task", body: body, checklist: [checked],
                                    tagIDs: [tag.id], kind: .note, richBody: rich,
                                    customRecurrence: CustomRecurrence(),
                                    scheduledDuration: .init(start: due.addingTimeInterval(-3_600), end: due))
        let data = WorkspaceData(tags: [tag], templates: [template])
        let files = try fixture(data)
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        var draft = TaskTemplateFields(template: template)
        guard case .unchanged(let untouched) = await repo.apply(
            TaskTemplateChange.update(id: template.id, fields: draft), expected: initial.revision
        ) else { return XCTFail("Unchanged Done must preserve the source bytes") }
        XCTAssertEqual(untouched.snapshot.workspaceBytes, initial.snapshot.workspaceBytes)
        draft.name = " Revised "
        draft.priority = .high
        guard case .saved(let saved) = await repo.apply(
            TaskTemplateChange.update(id: template.id, fields: draft), expected: initial.revision
        ) else { return XCTFail("Expected a template-only edit") }
        var expected = template
        expected.name = "Revised"
        expected.priority = .high
        let updated = try XCTUnwrap(saved.snapshot.workspace.templates.first)
        XCTAssertEqual(updated, expected)
        XCTAssertTrue(RichBody.sameCodeUnits(updated.body, body))
        XCTAssertTrue(RichBody.sameCodeUnits(updated.richBody?.text ?? "", body))
        XCTAssertEqual(saved.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        draft.body = "é 🧩"
        assertRefused(await repo.apply(TaskTemplateChange.update(id: template.id, fields: draft),
                                       expected: saved.revision), .missing)
        XCTAssertEqual(try Data(contentsOf: files.workspace), saved.snapshot.workspaceBytes)
        let desktopEdit = try XCTUnwrap(draft.updated(id: template.id, original: updated, allowsReplacingStyledBody: true))
        XCTAssertTrue(RichBody.sameCodeUnits(desktopEdit.body, draft.body))
        XCTAssertNil(desktopEdit.richBody)
        XCTAssertEqual(desktopEdit.checklist, expected.checklist)
        XCTAssertEqual(desktopEdit.scheduledDuration, expected.scheduledDuration)
        XCTAssertEqual(desktopEdit.customRecurrence, expected.customRecurrence)
    }

    func testTemplateApplicationKeepsLinksAndCopiesPairedBodyAndSchedule() async throws {
        let list = TaskList(name: "Work", color: "#123456")
        let archive = TaskList(name: "Archive", color: "#654321", isArchived: true)
        let start = Date(timeIntervalSinceReferenceDate: 815_907_600)
        let end = start.addingTimeInterval(3_600)
        let oldDue = start.addingTimeInterval(-3_600)
        let manualReminder = oldDue.addingTimeInterval(-600)
        let tag = TaskTag(name: "Planning", color: "#123456")
        var task = TaskItem(title: "Original", listID: list.id, dueDate: oldDue, hasDueTime: true)
        task.timeZoneID = "America/New_York"
        task.reminderDates = [manualReminder]
        task.reminderFollowsSchedule = false
        task.occurrenceIndex = 5
        let child = TaskItem(title: "Child", listID: list.id, parentID: task.id)
        let archived = TaskItem(title: "Archived", listID: archive.id)
        let rich = RichBody(text: "Read 🧩", runs: [.init(location: 0, length: 4, bold: true)])
        let step = ChecklistItem(title: "One step", isCompleted: true)
        let template = TaskTemplate(name: "Template", title: "Updated", body: rich.text, checklist: [step],
                                    priority: .high, tagIDs: [tag.id, UUID()], richBody: rich,
                                    customRecurrence: CustomRecurrence(), scheduledDuration: .init(start: start, end: end))
        let files = try fixture(WorkspaceData(tasks: [task, child, archived], lists: [list, archive],
                                             tags: [tag], templates: [template]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        let apply = TaskTemplateChange.applyToTask(templateID: template.id, taskID: task.id)
        guard case .saved(let saved) = await repo.apply(apply, expected: initial.revision, now: start)
        else { return XCTFail("Expected a saved template application") }
        let result = saved.snapshot.workspace.tasks[0]
        XCTAssertEqual(result.id, task.id)
        XCTAssertEqual(result.listID, list.id)
        XCTAssertEqual(Array(saved.snapshot.workspace.tasks.dropFirst()), [child, archived])
        XCTAssertEqual(result.richBody, rich)
        XCTAssertTrue(RichBody.sameCodeUnits(result.body, rich.text))
        XCTAssertEqual(result.tagIDs, [tag.id])
        XCTAssertEqual(result.checklist.map(\.title), [step.title])
        XCTAssertEqual(result.checklist.map(\.isCompleted), [true])
        XCTAssertNotEqual(result.checklist.first?.id, step.id)
        XCTAssertEqual(result.scheduledDuration, template.scheduledDuration)
        XCTAssertEqual(result.dueDate, end)
        XCTAssertEqual(result.occurrenceIndex, 1)
        XCTAssertEqual(result.recurrenceNominalDate, end)
        XCTAssertEqual(result.reminderDates, [manualReminder])
        XCTAssertEqual(result.timeZoneID, task.timeZoneID)
        XCTAssertEqual(saved.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        assertRefused(await repo.apply(apply, expected: initial.revision), .stale)
        assertRefused(await repo.apply(TaskTemplateChange.applyToTask(templateID: template.id, taskID: archived.id),
                                       expected: saved.revision), .missing)
    }

    func testBoardModeOwnsOnlyTheActiveListViewValue() async throws {
        let work = TaskList(name: "Work", color: "#123456", isPinned: true)
        let archive = TaskList(name: "Archive", color: "#654321", viewMode: .board, isArchived: true)
        let task = TaskItem(title: "Review", listID: work.id)
        let data = WorkspaceData(tasks: [task], lists: [work, archive])
        let files = try fixture(data)
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        let change = ListOrganizationCommand.setListViewMode(work.id, .board)
        guard case .saved(let saved) = await repo.apply(change, expected: initial.revision)
        else { return XCTFail("Expected one list-mode write") }
        var expected = data
        expected.lists[0].viewMode = .board
        XCTAssertEqual(saved.snapshot.workspace, expected)
        XCTAssertEqual(saved.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        guard case .unchanged(let unchanged) = await repo.apply(change, expected: saved.revision)
        else { return XCTFail("Repeated mode selection must preserve its bytes") }
        XCTAssertEqual(unchanged.revision, saved.revision)
        assertRefused(await repo.apply(ListOrganizationCommand.setListViewMode(archive.id, .list), expected: saved.revision), .missing)
        assertRefused(await repo.apply(change, expected: initial.revision), .stale)
        XCTAssertEqual(try Data(contentsOf: files.workspace), saved.snapshot.workspaceBytes)
    }

    func testBoardCompletionFromWontDoAndUndoShareRecurringLifecycle() async throws {
        let now = Date(timeIntervalSinceReferenceDate: 815_907_600)
        let stamp = now.addingTimeInterval(-1_800)
        let list = TaskList(name: "Work", color: "#123456", viewMode: .board)
        var task = TaskItem(title: "Recurring", listID: list.id, dueDate: now)
        task.recurrence = .daily
        task.wontDoAt = stamp
        let note = TaskItem(title: "Note", listID: list.id, kind: .note)
        let files = try fixture(WorkspaceData(tasks: [task, note], lists: [list]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let initial = try await repo.load()
        XCTAssertNil(BoardProjection.move(note, to: .completed))
        XCTAssertNil(BoardProjection.move(task, to: .wontDo))
        let command = try XCTUnwrap(BoardProjection.move(task, to: .completed))
        guard case .saved(let saved, let undo?) = await repo.apply(command, to: task.id, expected: initial.revision, now: now)
        else { return XCTFail("Expected atomic completion and an Undo token") }
        XCTAssertEqual(saved.snapshot.workspace.tasks[0].completedAt, now)
        XCTAssertNil(saved.snapshot.workspace.tasks[0].wontDoAt)
        XCTAssertEqual(saved.snapshot.workspace.tasks[1], note)
        XCTAssertEqual(saved.snapshot.workspace.tasks.count, 3)
        XCTAssertEqual(saved.snapshot.workspace.tasks.last?.recurrenceSourceID, task.id)
        guard case .saved(let undone, nil) = await repo.undo(undo, now: now.addingTimeInterval(5))
        else { return XCTFail("Expected Board Undo") }
        XCTAssertEqual(undone.snapshot.workspace.tasks.count, 2)
        XCTAssertNil(undone.snapshot.workspace.tasks[0].completedAt)
        XCTAssertEqual(undone.snapshot.workspace.tasks[0].wontDoAt, stamp)
        XCTAssertEqual(undone.snapshot.settingsBytes, initial.snapshot.settingsBytes)
    }

    func testTagMergeResumesAnInterruptedDefaultTagChange() async throws {
        let source = TaskTag(name: "Planning", color: "#123456")
        let ancestor = TaskTag(name: "Weekly", color: "#123456", parentID: source.id)
        let target = TaskTag(name: "Sprint", color: "#123456", parentID: ancestor.id)
        let sibling = TaskTag(name: "Review", color: "#123456", parentID: source.id)
        let task = TaskItem(title: "Task", tagIDs: [source.id, target.id])
        let template = TaskTemplate(name: "Template", title: "Template task", tagIDs: [source.id, target.id])
        let sourceRule = FilterRule.condition(.init(kind: .tag, tagID: source.id))
        let targetRule = FilterRule.condition(.init(kind: .tag, tagID: target.id))
        let filter = TaskFilter(name: "Filter", tagIDs: [source.id, target.id], ruleRoot: .and([sourceRule, targetRule]))
        let files = try fixture(WorkspaceData(tasks: [task], tags: [source, ancestor, target, sibling],
                                             filters: [filter], templates: [template]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        var settings = AppSettings()
        settings.defaultTagID = source.id
        settings.defaultDurationMinutes = 37
        let settingsBefore = try JSONEncoder().encode(settings)
        try settingsBefore.write(to: files.settings)
        let failing = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            if url.lastPathComponent == "settings.json" { throw FixtureWriteError.denied }
            try bytes.write(to: url, options: .atomic)
        }
        let start = try await failing.load()
        let command = TagOrganizationCommand.merge(source.id, into: target.id)
        guard case .persistenceFailed = await failing.apply(command, expected: start.revision)
        else { return XCTFail("Expected an interrupted two-file write") }
        XCTAssertNotEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: files.settings), settingsBefore)
        let journal = files.workspace.appendingPathExtension("tag-transaction")
        XCTAssertTrue(FileManager.default.fileExists(atPath: journal.path))
        let reopened = repository(files)
        let saved = try await reopened.load()
        XCTAssertFalse(FileManager.default.fileExists(atPath: journal.path))
        XCTAssertEqual(saved.snapshot.settings.defaultTagID, target.id)
        XCTAssertEqual(saved.snapshot.settings.defaultDurationMinutes, 37)
        XCTAssertEqual(saved.snapshot.workspace.tasks[0].tagIDs, [target.id])
        XCTAssertEqual(saved.snapshot.workspace.templates[0].tagIDs, [target.id])
        XCTAssertEqual(saved.snapshot.workspace.filters[0].tagIDs, [target.id])
        XCTAssertEqual(saved.snapshot.workspace.filters[0].ruleRoot, .and([targetRule]))
        XCTAssertNil(saved.snapshot.workspace.tags.first(where: { $0.id == target.id })?.parentID)
        XCTAssertNil(saved.snapshot.workspace.tags.first(where: { $0.id == ancestor.id })?.parentID)
        XCTAssertEqual(saved.snapshot.workspace.tags.first(where: { $0.id == sibling.id })?.parentID, target.id)
        assertRefused(await reopened.apply(command, expected: start.revision), .stale)
    }

    func testTagDeletePreservesUnavailableRulesAndClearsDefault() async throws {
        let source = TaskTag(name: "Planning", color: "#123456")
        let child = TaskTag(name: "Weekly", color: "#123456", parentID: source.id)
        let task = TaskItem(title: "Task", tagIDs: [source.id, child.id])
        let filter = TaskFilter(name: "Filter", tagIDs: [source.id],
                                ruleRoot: .condition(.init(kind: .tag, tagID: source.id)))
        let files = try fixture(WorkspaceData(tasks: [task], tags: [source, child], filters: [filter]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        var settings = AppSettings()
        settings.defaultTagID = source.id
        try JSONEncoder().encode(settings).write(to: files.settings)
        let repo = repository(files), initial = try await repo.load()
        let outcome = await repo.apply(TagOrganizationCommand.delete(source.id), expected: initial.revision)
        guard case .saved(let saved) = outcome
        else { return XCTFail("Expected confirmed tag deletion, got \(outcome)") }
        XCTAssertTrue(saved.allowsKnownFieldWrites)
        XCTAssertNil(saved.snapshot.settings.defaultTagID)
        XCTAssertEqual(saved.snapshot.workspace.tasks[0].tagIDs, [child.id])
        XCTAssertNil(saved.snapshot.workspace.tags[0].parentID)
        XCTAssertEqual(saved.snapshot.workspace.filters, [filter])
        XCTAssertTrue(TaskDestination.filter(filter.id).matchingTasks(in: saved.snapshot.workspace).isEmpty)
    }

    func testTagRecoveryKeepsUnexpectedFilesAndPendingJournal() async throws {
        let source = TaskTag(name: "Planning", color: "#123456")
        let files = try fixture(WorkspaceData(tags: [source]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        var settings = AppSettings()
        settings.defaultTagID = source.id
        try JSONEncoder().encode(settings).write(to: files.settings)
        let failing = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            if url.lastPathComponent == "settings.json" { throw FixtureWriteError.denied }
            try bytes.write(to: url, options: .atomic)
        }
        let initial = try await failing.load()
        let outcome = await failing.apply(TagOrganizationCommand.delete(source.id), expected: initial.revision)
        guard case .persistenceFailed = outcome
        else { return XCTFail("Expected an interrupted two-file write, got \(outcome)") }
        settings.defaultDurationMinutes = 47
        let unexpected = try JSONEncoder().encode(settings)
        try unexpected.write(to: files.settings)
        let workspace = try Data(contentsOf: files.workspace)
        let journal = files.workspace.appendingPathExtension("tag-transaction")
        let pending = try Data(contentsOf: journal)
        let reopened = repository(files)
        do {
            _ = try await reopened.load()
            XCTFail("Recovery must not replace an unexpected file")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: files.settings), unexpected)
        XCTAssertEqual(try Data(contentsOf: files.workspace), workspace)
        XCTAssertEqual(try Data(contentsOf: journal), pending)
    }

    func testTagRecoveryBlocksOtherWritesUntilTheJournalCanBeRemoved() async throws {
        let source = TaskTag(name: "Planning", color: "#123456")
        let child = TaskTag(name: "Weekly", color: "#123456", parentID: source.id)
        let files = try fixture(WorkspaceData(tags: [source, child]))
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: files.directory.path)
            try? FileManager.default.removeItem(at: files.directory)
        }
        var settings = AppSettings()
        settings.defaultTagID = source.id
        try JSONEncoder().encode(settings).write(to: files.settings)
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            if url == files.settings {
                try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: files.directory.path)
            }
        }
        let start = try await repo.load()
        let deletion = await repo.apply(TagOrganizationCommand.delete(source.id), expected: start.revision)
        guard case .persistenceFailed = deletion else { return XCTFail("Expected a pending transaction until cleanup") }
        let journal = files.workspace.appendingPathExtension("tag-transaction")
        let pending = try Data(contentsOf: journal)
        let workspace = try Data(contentsOf: files.workspace)
        let savedSettings = try Data(contentsOf: files.settings)
        XCTAssertNotEqual(workspace, start.snapshot.workspaceBytes)
        XCTAssertNotEqual(savedSettings, start.snapshot.settingsBytes)
        let next = TagOrganizationCommand.setCollapsed(child.id, true)
        let blocked = await repo.apply(next, expected: start.revision)
        guard case .persistenceFailed = blocked else { return XCTFail("Expected other writes to wait for journal cleanup") }
        XCTAssertEqual(try Data(contentsOf: journal), pending)
        XCTAssertEqual(try Data(contentsOf: files.workspace), workspace)
        XCTAssertEqual(try Data(contentsOf: files.settings), savedSettings)

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: files.directory.path)
        let recovered = try await repo.load()
        XCTAssertFalse(FileManager.default.fileExists(atPath: journal.path))
        XCTAssertNil(recovered.snapshot.settings.defaultTagID)
        guard case .saved(let saved) = await repo.apply(next, expected: recovered.revision)
        else { return XCTFail("Expected writes to resume after journal cleanup") }
        XCTAssertEqual(saved.snapshot.workspace.tags.map(\.id), [child.id])
        XCTAssertTrue(saved.snapshot.workspace.tags[0].isCollapsed)
    }

    func testTagTransactionConfirmsJournalAndBothWritesAfterReportedFailure() async throws {
        let source = TaskTag(name: "Planning", color: "#123456")
        let target = TaskTag(name: "Sprint", color: "#123456")
        let files = try fixture(WorkspaceData(tags: [source, target]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        var settings = AppSettings()
        settings.defaultTagID = source.id
        try JSONEncoder().encode(settings).write(to: files.settings)
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        let start = try await repo.load()
        let command = TagOrganizationCommand.merge(source.id, into: target.id)
        guard case .saved(let saved) = await repo.apply(command, expected: start.revision)
        else { return XCTFail("Expected exact durable bytes to confirm the tag merge") }
        XCTAssertEqual(saved.snapshot.settings.defaultTagID, target.id)
        XCTAssertEqual(saved.snapshot.workspace.tags, [target])
        XCTAssertFalse(FileManager.default.fileExists(atPath: files.workspace.appendingPathExtension("tag-transaction").path))
    }

    func testSavedFilterRenameRetainsAdvancedRuleAndUnavailableReferences() async throws {
        let missingList = UUID(), missingTag = UUID()
        let rule: FilterRule = .and([.condition(.init(kind: .list, listID: missingList)),
                                     .not(.condition(.init(kind: .tag, tagID: missingTag)))])
        let filter = TaskFilter(name: "Old name", listIDs: [missingList], tagIDs: [missingTag], isPinned: true, ruleRoot: rule)
        let task = TaskItem(title: "Ordinary task", body: "e\u{301}")
        let files = try fixture(WorkspaceData(tasks: [task], filters: [filter]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), start = try await repo.load()
        var draft = filter
        draft.name = " Project filter "
        guard case .saved(let saved) = await repo.apply(.update(draft), expected: start.revision),
              case .unchanged = await repo.apply(.update(draft), expected: saved.revision),
              case .refused(.stale) = await repo.apply(.delete(filter.id), expected: start.revision)
        else { return XCTFail("Expected saved, no-op and stale outcomes") }
        draft.name = "Project filter"
        XCTAssertEqual(saved.snapshot.workspace.filters, [draft])
        XCTAssertEqual(saved.snapshot.workspace.tasks, [task])
        XCTAssertTrue(TaskDestination.filter(filter.id).matchingTasks(in: saved.snapshot.workspace).isEmpty)
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    func testSavedFilterCreateAndDeleteValidateAndKeepSettingsOnConfirmedWrite() async throws {
        let files = try fixture(WorkspaceData(tasks: [TaskItem(title: "Ordinary task")]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        let start = try await repo.load()
        var draft = TaskFilter(name: "Custom", dateRules: [.custom])
        assertRefused(await repo.apply(.create(draft), expected: start.revision), .missing)
        draft.customDateFrom = Date(timeIntervalSinceReferenceDate: 815_909_000)
        guard case .saved(let saved) = await repo.apply(.create(draft), expected: start.revision),
              case .saved(let removed) = await repo.apply(.delete(draft.id), expected: saved.revision)
        else { return XCTFail("Expected confirmed filter creation and deletion") }
        XCTAssertEqual(saved.snapshot.workspace.filters, [draft])
        XCTAssertEqual(removed.snapshot.workspace, start.snapshot.workspace)
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    func testLocalPreferencesPatchOnlyOwnedValuesAndRetainUnavailableDefaults() async throws {
        let archive = TaskList(name: "Archive", color: "#123456", isArchived: true)
        let active = TaskList(name: "Active", color: "#123456")
        let files = try fixture(WorkspaceData(tasks: [TaskItem(title: "Existing")], lists: [archive, active]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let initialSettings = Data(#"{ "future" : {"opaque":true}, "startWeekOn" : 2, "urlParsing":true, "defaultReminder":"onTime", "defaultListID":"\#(archive.id.uuidString)" }"#.utf8)
        try initialSettings.write(to: files.settings)
        let repo = repository(files)
        let start = try await repo.load()
        var draft = LocalWorkspacePreferences(start.snapshot.settings)
        draft.startWeekOn = 1
        draft.defaultPriority = .high
        draft.timedReminders = []
        guard case .saved(let saved) = await repo.saveLocalPreferences(draft, expected: start.revision),
              case .unchanged = await repo.saveLocalPreferences(draft, expected: saved.revision),
              case .stale = await repo.saveLocalPreferences(draft, expected: start.revision)
        else { return XCTFail("Expected saved, unchanged and stale outcomes") }
        let after = String(decoding: saved.snapshot.settingsBytes, as: UTF8.self)
        XCTAssertTrue(after.hasPrefix(#"{ "future" : {"opaque":true}, "startWeekOn" : 1, "urlParsing":true, "defaultReminder":"onTime""#))
        XCTAssertEqual(saved.snapshot.settings.defaultListID, archive.id)
        XCTAssertEqual(saved.snapshot.settings.timedReminderDefaults, [])
        XCTAssertEqual(LocalWorkspacePreferences(saved.snapshot.settings), draft)
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)

        draft.defaultListID = UUID()
        guard case .invalid = await repo.saveLocalPreferences(draft, expected: saved.revision) else {
            return XCTFail("A newly unavailable default list must be rejected")
        }
        XCTAssertEqual(try Data(contentsOf: files.settings), saved.snapshot.settingsBytes)
        draft.defaultListID = active.id
        guard case .saved(let activeDefault) = await repo.saveLocalPreferences(draft, expected: saved.revision) else {
            return XCTFail("An active default list can be chosen explicitly")
        }
        XCTAssertEqual(activeDefault.snapshot.settings.defaultListID, active.id)
    }

    func testSmartListsPatchOwnedMembersAndPreserveOpaqueSettingsAndWorkspace() async throws {
        let task = TaskItem(title: "Existing task")
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let initialSettings = Data(#"{ "opaque" : {"future":true}, "smartListVisibility" : ["today","show"], "calendarOptions" : {"futureCalendarField":true}, "startWeekOn" : 2 }"#.utf8)
        try initialSettings.write(to: files.settings)
        let repo = repository(files), start = try await repo.load()
        XCTAssertFalse(start.allowsKnownFieldWrites)
        var draft = start.snapshot.settings
        draft.smartListVisibility[.today] = .hidden
        XCTAssertTrue(draft.reorderSmartList(moving: .inbox, before: .week))
        guard case .saved(let saved) = await repo.saveSmartLists(draft, expected: start.revision),
              case .unchanged = await repo.saveSmartLists(draft, expected: saved.revision),
              case .stale = await repo.saveSmartLists(draft, expected: start.revision)
        else { return XCTFail("Expected saved, unchanged and stale outcomes") }
        let after = String(decoding: saved.snapshot.settingsBytes, as: UTF8.self)
        XCTAssertTrue(after.hasPrefix(#"{ "opaque" : {"future":true}, "smartListVisibility" : "#))
        XCTAssertTrue(after.contains(#", "calendarOptions" : {"futureCalendarField":true}, "startWeekOn" : 2 ,"smartListOrder":"#))
        XCTAssertEqual(saved.snapshot.settings.smartListVisibility[.today], .hidden)
        XCTAssertEqual(saved.snapshot.settings.effectiveSmartListOrder, draft.effectiveSmartListOrder)
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: files.settings), saved.snapshot.settingsBytes)
    }

    func testSmartListsRejectDuplicateVisibilityPairsAndKeepMalformedBytes() async throws {
        let files = try fixture(WorkspaceData())
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let bytes = Data(#"{"smartListVisibility":["today","show","today","hidden"],"startWeekOn":2}"#.utf8)
        try bytes.write(to: files.settings)
        let repo = repository(files), start = try await repo.load()
        var draft = start.snapshot.settings
        draft.smartListVisibility[.all] = .show
        guard case .incompatible = await repo.saveSmartLists(draft, expected: start.revision)
        else { return XCTFail("Expected duplicate-key refusal") }
        XCTAssertEqual(try Data(contentsOf: files.settings), bytes)
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
    }

    func testSmartListsInsertSparseVisibilityAndConfirmAfterWriteThrow() async throws {
        let files = try fixture(WorkspaceData())
        defer { try? FileManager.default.removeItem(at: files.directory) }
        try Data(#"{ "unrelated" : [1, 2, 3] }"#.utf8).write(to: files.settings)
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        let start = try await repo.load()
        var draft = start.snapshot.settings
        draft.smartListVisibility[.all] = .show
        guard case .saved(let saved) = await repo.saveSmartLists(draft, expected: start.revision)
        else { return XCTFail("Expected confirmed settings replacement") }
        XCTAssertTrue(String(decoding: saved.snapshot.settingsBytes, as: UTF8.self).hasPrefix(#"{ "unrelated" : [1, 2, 3] ,"smartListVisibility":"#))
        XCTAssertNil(saved.snapshot.settings.smartListOrder)
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
    }

    func testTaskSectionSavesRejectStaleAssignmentsAndKeepTaskData() async throws {
        let list = TaskList(name: "Work", color: "#123456")
        let task = TaskItem(title: "Keep task", body: "Keep this body", listID: list.id)
        let files = try fixture(WorkspaceData(tasks: [task], lists: [list]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), start = try await repo.load()
        let section = TaskSection(name: "Planning")
        let create = TaskSectionChange(listID: list.id, operation: .create(section))
        let assign = TaskSectionChange(listID: list.id, operation: .assign(taskID: task.id, sectionID: section.id))
        let remove = TaskSectionChange(listID: list.id, operation: .remove(section.id))
        guard case .saved(let created) = await repo.apply(create, expected: start.revision)
        else { return XCTFail("Expected a protected section save") }
        let reopened = try await repo.load()
        XCTAssertTrue(reopened.allowsKnownFieldWrites)
        XCTAssertEqual(reopened.revision, created.revision)
        assertRefused(await repo.apply(assign, expected: start.revision), .stale)
        XCTAssertEqual(try Data(contentsOf: files.workspace), created.snapshot.workspaceBytes)
        guard case .saved(let assigned) = await repo.apply(assign, expected: reopened.revision),
              case .saved(let removed) = await repo.apply(remove, expected: assigned.revision)
        else { return XCTFail("Expected assignment and removal") }
        XCTAssertEqual(assigned.snapshot.workspace.tasks.first?.sectionID, section.id)
        var expected = task
        expected.updatedAt = try XCTUnwrap(removed.snapshot.workspace.tasks.first?.updatedAt)
        XCTAssertEqual(removed.snapshot.workspace.tasks, [expected])
        XCTAssertTrue(removed.snapshot.workspace.lists[0].sections.isEmpty)
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    func testListOrganizationMovesAndUngroupsWhilePreservingRecordsAndLegacyView() async throws {
        let parent = ListFolder(name: "Projects")
        let work = TaskList(name: "Work", color: "#123456", viewMode: .board, folderID: parent.id, isPinned: true)
        let task = TaskItem(title: "Keep task", listID: work.id, checklist: [ChecklistItem(title: "Keep step")])
        let files = try fixture(WorkspaceData(tasks: [task], lists: [work], folders: [parent]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), start = try await repo.load()
        let other = ListFolder(name: " Extra ")
        guard case .saved(let added) = await repo.apply(.saveFolder(other, creating: true), expected: start.revision),
              case .saved(let reordered) = await repo.apply(.reorderFolder(other.id, relativeTo: parent.id, after: false), expected: added.revision)
        else { return XCTFail("Expected folder creation and order") }
        XCTAssertEqual(reordered.snapshot.workspace.folders.map(\.name), ["Extra", "Projects"])
        var edit = work
        edit.name = " Work renamed "
        edit.viewMode = .list
        edit.isArchived = true
        edit.showsInSmartLists = false
        ListPlacement.folder(other.id).apply(to: &edit)
        guard case .saved(let moved) = await repo.apply(.saveList(edit, creating: false), expected: reordered.revision),
              case .unchanged = await repo.apply(.saveList(edit, creating: false), expected: moved.revision),
              case .saved(let ungrouped) = await repo.apply(.ungroupFolder(other.id), expected: moved.revision)
        else { return XCTFail("Expected a move, exact no-op and ungroup") }
        var expected = edit
        expected.name = "Work renamed"
        expected.viewMode = .board
        ListPlacement.aboveFolders.apply(to: &expected)
        XCTAssertEqual(ungrouped.snapshot.workspace.lists, [expected])
        XCTAssertEqual(ungrouped.snapshot.workspace.tasks, [task])
        XCTAssertEqual(ungrouped.snapshot.workspace.folders, [parent])
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    func testListOrganizationCopiesHierarchyAndDeletesWithoutBroadeningFilter() async throws {
        let list = TaskList(name: "Work", color: "#123456", isArchived: true, isPinned: true)
        let body = "e\u{301}"
        let task = TaskItem(title: "Parent", body: body, listID: list.id, checklist: [ChecklistItem(title: "Step")],
                            richBody: RichBody(text: body, runs: [.init(location: 0, length: 2, bold: true)]))
        let child = TaskItem(title: "Child", listID: list.id, parentID: task.id)
        let deleted = TaskItem(title: "Deleted", listID: list.id, deletedAt: Date(), parentID: task.id)
        var filter = TaskFilter(name: "Only Work")
        filter.listIDs = [list.id]
        let files = try fixture(WorkspaceData(tasks: [task, child, deleted], lists: [list], filters: [filter]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        let copyID = UUID(), start = try await repo.load()
        guard case .saved(let copied) = await repo.apply(.duplicateList(list.id, copyID: copyID), expected: start.revision),
              case .refused(.stale) = await repo.apply(.duplicateList(list.id, copyID: copyID), expected: start.revision),
              case .refused(.missing) = await repo.apply(.duplicateList(list.id, copyID: copyID), expected: copied.revision),
              case .saved(let saved) = await repo.apply(.deleteList(list.id), expected: copied.revision)
        else { return XCTFail("Expected durable copy, safe retry refusal and deletion") }
        let data = saved.snapshot.workspace
        XCTAssertEqual(data.tasks.count, 5)
        XCTAssertEqual(data.lists, [TaskList(id: copyID, name: "Work copy", color: list.color)])
        let copies = data.tasks.filter { $0.listID == copyID }
        XCTAssertEqual(copies[1].parentID, copies[0].id)
        XCTAssertTrue(copies[0].body.utf16.elementsEqual(body.utf16))
        XCTAssertEqual(copies[0].richBody, task.richBody)
        XCTAssertNotEqual(copies[0].checklist[0].id, task.checklist[0].id)
        XCTAssertEqual(data.tasks.prefix(3).map(\.listID), [nil, nil, nil])
        XCTAssertEqual(data.tasks[2].deletedAt, deleted.deletedAt)
        XCTAssertEqual(data.filters, [filter])
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    func testListOrganizationRefusesInvalidAndUnknownWritesWithoutChangingBytes() async throws {
        let files = try fixture(WorkspaceData())
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), start = try await repo.load()
        assertRefused(await repo.apply(.saveFolder(ListFolder(name: "  "), creating: true), expected: start.revision), .missing)
        let list = TaskList(name: "Orphaned", color: "#123456", folderID: UUID())
        assertRefused(await repo.apply(.saveList(list, creating: true), expected: start.revision), .missing)
        var unknown = try XCTUnwrap(JSONSerialization.jsonObject(with: start.snapshot.workspaceBytes) as? [String: Any])
        unknown["unknownOrganization"] = ["retain": true]
        let bytes = try JSONSerialization.data(withJSONObject: unknown)
        try bytes.write(to: files.workspace)
        let protected = try await repo.load()
        assertRefused(await repo.apply(.saveFolder(ListFolder(name: "Known"), creating: true), expected: protected.revision), .compatibility)
        XCTAssertEqual(try Data(contentsOf: files.workspace), bytes)
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    private struct Fixture {
        let directory: URL
        var workspace: URL { directory.appendingPathComponent("workspace.json") }
        var settings: URL { directory.appendingPathComponent("settings.json") }
    }
    private func fixture(_ data: WorkspaceData) throws -> Fixture {
        let value = Fixture(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try FileManager.default.createDirectory(at: value.directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: value.workspace)
        try JSONEncoder().encode(AppSettings()).write(to: value.settings)
        return value
    }
    private func repository(_ fixture: Fixture) -> WorkspaceFileRepository {
        WorkspaceFileRepository(workspaceURL: fixture.workspace, settingsURL: fixture.settings)
    }
    private func assertRefused(_ outcome: WorkspaceWriteOutcome, _ reason: WorkspaceWriteRefusal, file: StaticString = #filePath, line: UInt = #line) {
        guard case .refused(let actual) = outcome else { return XCTFail("Expected refusal", file: file, line: line) }
        XCTAssertEqual(actual, reason, file: file, line: line)
    }
    private func structural(_ bytes: Data, strippingOwnedFields: Bool = false) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        if strippingOwnedFields, var tasks = object["tasks"] as? [[String: Any]] {
            tasks[0].removeValue(forKey: "title"); tasks[0].removeValue(forKey: "updatedAt"); object["tasks"] = tasks
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
    func testTitlePatchPreservesStyledBodyAndEveryUnownedWorkspaceField() async throws {
        var task = TaskItem(title: "Before", body: "e\u{301} 🧩", dueDate: Date(timeIntervalSinceReferenceDate: 12345.125))
        task.richBody = RichBody(text: task.body, runs: [.init(location: 0, length: 2, bold: true)])
        task.recurrence = .monthly; task.recurrenceAnchorDay = 31
        task.reminderDates = [Date(timeIntervalSinceReferenceDate: 12000.25)]
        task.scheduledDuration = .init(start: task.dueDate!.addingTimeInterval(-301.125), end: task.dueDate!, isAllDay: false)
        var unrelated = TaskItem(title: "Unrelated", body: "Retain original")
        unrelated.richBody = RichBody(text: "mismatch", runs: [.init(location: Int.max, length: Int.max, italic: true)])
        let fixture = try fixture(WorkspaceData(tasks: [task, unrelated])); defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let original = try Data(contentsOf: fixture.workspace), settings = try Data(contentsOf: fixture.settings)
        let repo = repository(fixture), loaded = try await repo.load()
        XCTAssertTrue(loaded.allowsKnownFieldWrites)
        let outcome = await repo.apply(.title("After"), to: task.id, expected: loaded.revision, now: Date(timeIntervalSinceReferenceDate: 23456))
        guard case .saved(let saved) = outcome else { return XCTFail("Expected durable save") }
        XCTAssertEqual(saved.snapshot.workspace.tasks[0].title, "After")
        XCTAssertEqual(saved.snapshot.workspace.tasks[0].richBody, task.richBody)
        XCTAssertTrue(saved.snapshot.workspace.tasks[0].body.utf16.elementsEqual(task.body.utf16))
        XCTAssertEqual(try structural(original, strippingOwnedFields: true), try structural(Data(contentsOf: fixture.workspace), strippingOwnedFields: true))
        XCTAssertEqual(try Data(contentsOf: fixture.settings), settings)
    }
    func testNoOpLeavesBytesAndTimestampUnchanged() async throws {
        let task = TaskItem(title: "Same", body: "Exact e\u{301}")
        let fixture = try fixture(WorkspaceData(tasks: [task])); defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let bytes = try Data(contentsOf: fixture.workspace), repo = repository(fixture), loaded = try await repo.load()
        for patch in [WorkspaceFieldPatch.title(task.title), .plainBody(task.body)] {
            guard case .unchanged(let value) = await repo.apply(patch, to: task.id, expected: loaded.revision) else { return XCTFail("Expected unchanged") }
            XCTAssertEqual(value.snapshot.workspace.tasks[0].updatedAt, task.updatedAt)
        }
        XCTAssertEqual(try Data(contentsOf: fixture.workspace), bytes)
    }
    func testUnknownFieldsAnywhereLockAllWrites() async throws {
        for inSettings in [false, true] {
            let task = TaskItem(title: "Known"), other = TaskItem(title: "Other")
            let fixture = try fixture(WorkspaceData(tasks: [task, other])); defer { try? FileManager.default.removeItem(at: fixture.directory) }
            let target = inSettings ? fixture.settings : fixture.workspace
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: target)) as? [String: Any])
            if !inSettings {
                var tasks = try XCTUnwrap(object["tasks"] as? [[String: Any]]); tasks[1]["newPayload"] = ["version": 99]; object["tasks"] = tasks
            } else { object["futurePreference"] = ["keep": true] }
            let raw = try JSONSerialization.data(withJSONObject: object); try raw.write(to: target)
            let repo = repository(fixture), loaded = try await repo.load()
            XCTAssertFalse(loaded.allowsKnownFieldWrites)
            assertRefused(await repo.apply(.title("Refused"), to: task.id, expected: loaded.revision), .compatibility)
            XCTAssertEqual(try Data(contentsOf: target), raw)
        }
    }
    func testExternalWorkspaceOrSettingsChangeRejectsStaleRevision() async throws {
        let task = TaskItem(title: "Before"), fixture = try fixture(WorkspaceData(tasks: []))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: fixture.workspace)
        let repo = repository(fixture)
        for target in [fixture.workspace, fixture.settings] {
            let loaded = try await repo.load(); var changed = try Data(contentsOf: target); changed.append(32); try changed.write(to: target)
            assertRefused(await repo.apply(.title("Stale"), to: task.id, expected: loaded.revision), .stale)
            XCTAssertEqual(try Data(contentsOf: target), changed)
        }
    }
    func testUnsupportedBodyAndRecordGuardsRefuseWithoutWrite() async throws {
        let archived = TaskList(name: "Archive", color: "#000000", isArchived: true)
        var styled = TaskItem(title: "Styled", body: "Original"); styled.richBody = RichBody(text: styled.body)
        let archiveTask = TaskItem(title: "Archived", listID: archived.id)
        var trash = TaskItem(title: "Trash"); trash.deletedAt = Date()
        let fixture = try fixture(WorkspaceData(tasks: [styled, archiveTask, trash], lists: [archived])); defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let repo = repository(fixture), loaded = try await repo.load(), bytes = try Data(contentsOf: fixture.workspace)
        assertRefused(await repo.apply(.plainBody("Flatten"), to: styled.id, expected: loaded.revision), .styledBody)
        assertRefused(await repo.apply(.title("  "), to: styled.id, expected: loaded.revision), .emptyTitle)
        for id in [archiveTask.id, trash.id] { assertRefused(await repo.apply(.title("Refused"), to: id, expected: loaded.revision), .readOnlyRecord) }
        assertRefused(await repo.apply(.title("Missing"), to: UUID(), expected: loaded.revision), .missing)
        XCTAssertEqual(try Data(contentsOf: fixture.workspace), bytes)
    }
    func testPlainBodyPatchKeepsExactUnicodeAndOtherFields() async throws {
        let task = TaskItem(title: "Plain", body: "Before"), fixture = try fixture(WorkspaceData(tasks: []))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: fixture.workspace)
        let repo = repository(fixture), loaded = try await repo.load(), body = "e\u{301}\n🧩"
        guard case .saved(let saved) = await repo.apply(.plainBody(body), to: task.id, expected: loaded.revision) else { return XCTFail("Expected save") }
        XCTAssertTrue(saved.snapshot.workspace.tasks[0].body.utf16.elementsEqual(body.utf16))
        XCTAssertNil(saved.snapshot.workspace.tasks[0].richBody)
        XCTAssertEqual(saved.snapshot.workspace.tasks[0].title, task.title)
        let reopened = try await repo.load(); XCTAssertTrue(reopened.snapshot.workspace.tasks[0].body.utf16.elementsEqual(body.utf16))
    }
    func testWriteFailureKeepsLastDurableFileAndRevision() async throws {
        let task = TaskItem(title: "Durable"), fixture = try fixture(WorkspaceData(tasks: []))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: fixture.workspace)
        let repo = WorkspaceFileRepository(workspaceURL: fixture.workspace, settingsURL: fixture.settings, write: { _, _ in throw FixtureWriteError.denied })
        let loaded = try await repo.load(), raw = try Data(contentsOf: fixture.workspace)
        guard case .persistenceFailed = await repo.apply(.title("Unsaved"), to: task.id, expected: loaded.revision) else { return XCTFail("Expected write failure") }
        XCTAssertEqual(try Data(contentsOf: fixture.workspace), raw)
        let reopened = try await repo.load(); XCTAssertEqual(reopened.revision, loaded.revision)
    }
    func testCompetingCommandsCannotOverwriteEachOther() async throws {
        let task = TaskItem(title: "Before"), fixture = try fixture(WorkspaceData(tasks: []))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: fixture.workspace)
        let repo = repository(fixture), loaded = try await repo.load()
        async let first = repo.apply(.title("First"), to: task.id, expected: loaded.revision)
        async let second = repo.apply(.title("Second"), to: task.id, expected: loaded.revision)
        let outcomes = await [first, second]
        XCTAssertEqual(outcomes.filter { if case .saved = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(outcomes.filter { if case .refused(.stale) = $0 { true } else { false } }.count, 1)
    }
    func testDuplicateJSONKeysLockWrites() async throws {
        let task = TaskItem(title: "Ambiguous"), fixture = try fixture(WorkspaceData(tasks: []))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let encoded = try JSONEncoder().encode(WorkspaceData(tasks: [task]))
        var bytes = Data("{\"tasks\":[],".utf8); bytes.append(encoded.dropFirst()); try bytes.write(to: fixture.workspace)
        let repo = repository(fixture), loaded = try await repo.load()
        XCTAssertFalse(loaded.allowsKnownFieldWrites)
        assertRefused(await repo.apply(.title("Refused"), to: task.id, expected: loaded.revision), .compatibility)
        XCTAssertEqual(try Data(contentsOf: fixture.workspace), bytes)
    }

}

final class LocalEditingStorageTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func initial(_ title: String = "Original") throws -> ReadOnlyWorkspaceSnapshot {
        let task = TaskItem(title: title, body: "e\u{301} 🧩")
        return try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(WorkspaceData(tasks: [task])), settingsBytes: JSONEncoder().encode(AppSettings()))
    }
    private func repository(_ root: URL) -> WorkspaceFileRepository {
        WorkspaceFileRepository(workspaceURL: root.appendingPathComponent("workspace.json"), settingsURL: root.appendingPathComponent("settings.json"))
    }
    private func draft(_ root: URL) async throws -> TaskFieldDraft {
        try WorkspaceBootstrap.prepare(directory: root, initial: initial())
        let document = try await repository(root).load()
        return TaskFieldDraft(taskID: document.snapshot.workspace.tasks[0].id, field: .plainBody, baseRevision: document.revision,
                              text: document.snapshot.workspace.tasks[0].body)
    }
    func testBootstrapInstallsNewPairAndNeverReseedsExistingFiles() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let seed = try initial(); try WorkspaceBootstrap.prepare(directory: root, initial: seed)
        try WorkspaceBootstrap.prepare(directory: root, initial: initial("Different"))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("workspace.json")), seed.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("settings.json")), seed.settingsBytes)
    }
    func testPartialPairIsPreservedAndBlocked() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let original = Data("Existing incomplete data".utf8), url = root.appendingPathComponent("workspace.json")
        try original.write(to: url)
        XCTAssertThrowsError(try WorkspaceBootstrap.prepare(directory: root, initial: initial()))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("settings.json").path))
    }
    func testExistingCorruptPairIsNotRepairedByBootstrap() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        for name in ["workspace.json", "settings.json"] { try Data("corrupt".utf8).write(to: root.appendingPathComponent(name)) }
        try WorkspaceBootstrap.prepare(directory: root, initial: initial())
        do { _ = try await repository(root).load(); XCTFail("Must not load writable empty data") } catch { }
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("workspace.json")), Data("corrupt".utf8))
    }
    func testCompactRevisionDoesNotCopyTaskContentIntoScratch() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let value = try await draft(root)
        let encoded = try JSONEncoder().encode(value.baseRevision)
        XCTAssertLessThan(encoded.count, 256)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("Original"))
        let reopened = try await repository(root).load(); XCTAssertEqual(reopened.revision, value.baseRevision)
    }
    func testDraftRoundTripKeepsExactTextAndDoesNotWriteWorkspace() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var value = try await draft(root); let workspace = try Data(contentsOf: root.appendingPathComponent("workspace.json"))
        let url = root.appendingPathComponent("field-draft.json"), store = FieldDraftStore(fileURL: url)
        let begun = await store.begin(value); XCTAssertEqual(begun, .saved)
        value.replaceText("e\u{301}\n🧩 changed")
        let saved = await store.save(value); XCTAssertEqual(saved, .saved)
        let reopened = FieldDraftStore(fileURL: url)
        guard case .available(let restored) = await reopened.load() else { return XCTFail("Expected recovery") }
        XCTAssertEqual(restored, value); XCTAssertTrue(restored.text.utf16.elementsEqual(value.text.utf16))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("workspace.json")), workspace)
    }
    func testOlderAndClosedCallbacksCannotRecreateOrRevertDraft() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var value = try await draft(root); let original = value, url = root.appendingPathComponent("field-draft.json")
        let store = FieldDraftStore(fileURL: url); _ = await store.begin(value)
        value.replaceText("First"); let older = value; value.replaceText("Second")
        let saved = await store.save(value), stale = await store.save(older); XCTAssertEqual(saved, .saved); XCTAssertEqual(stale, .refused)
        let closed = await store.close(id: value.id), late = await store.save(value); XCTAssertEqual(closed, .saved); XCTAssertEqual(late, .refused)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let another = TaskFieldDraft(taskID: UUID(), field: original.field, baseRevision: original.baseRevision, text: original.text)
        _ = await store.begin(another)
        let wrongID = await store.save(value); XCTAssertEqual(wrongID, .refused)
    }
    func testSameSequenceDifferentUnicodeCannotReplaceCandidate() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let base = try await draft(root); var one = base, two = base
        one.replaceText("é"); two.replaceText("e\u{301}")
        XCTAssertNotEqual(one, two)
        let store = FieldDraftStore(fileURL: root.appendingPathComponent("field-draft.json")); _ = await store.begin(base)
        let first = await store.save(one), second = await store.save(two); XCTAssertEqual(first, .saved); XCTAssertEqual(second, .refused)
    }
    func testUnknownOrMalformedDraftCannotBeReplaced() async throws {
        for mode in 0..<4 {
            let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
            let value = try await draft(root), url = root.appendingPathComponent("field-draft.json")
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
            if mode == 0 { object["version"] = 99 }
            if mode == 1 { object["futurePayload"] = ["retain": true] }
            if mode == 2 { object["sequence"] = Int.max }
            let bytes = mode == 3 ? Data("broken".utf8) : try JSONSerialization.data(withJSONObject: object)
            try bytes.write(to: url)
            let store = FieldDraftStore(fileURL: url)
            guard case .unavailable = await store.load() else { return XCTFail("Expected protected draft") }
            let result = await store.begin(value); XCTAssertEqual(result, .refused)
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    func testExternalUnknownDraftAddedAfterLoadIsRetained() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var value = try await draft(root); let url = root.appendingPathComponent("field-draft.json"), store = FieldDraftStore(fileURL: url)
        _ = await store.begin(value)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]); object["newField"] = 1
        let original = try JSONSerialization.data(withJSONObject: object); try original.write(to: url)
        value.replaceText("Refused")
        let result = await store.save(value); XCTAssertEqual(result, .refused)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testFailedScratchSaveDoesNotClaimDurableRecovery() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let value = try await draft(root), url = root.appendingPathComponent("field-draft.json")
        let store = FieldDraftStore(fileURL: url, write: { _, _ in throw FixtureWriteError.denied })
        let result = await store.begin(value); XCTAssertEqual(result, .failed)
        guard case .none = await store.load() else { return XCTFail("Unsaved draft must not be reported recovered") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testFailedNewSequenceDoesNotAllowAnOlderSave() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var value = try await draft(root); let first = value, url = root.appendingPathComponent("field-draft.json")
        let store = FieldDraftStore(fileURL: url, write: { data, url in
            if try JSONDecoder().decode(TaskFieldDraft.self, from: data).text == "Fails" { throw FixtureWriteError.denied }
            try data.write(to: url, options: .atomic)
        })
        _ = await store.begin(value); value.replaceText("Fails")
        let failure = await store.save(value), old = await store.save(first); XCTAssertEqual(failure, .failed); XCTAssertEqual(old, .refused)
        guard case .available(let durable) = await store.load() else { return XCTFail("Expected earlier durable copy") }
        XCTAssertEqual(durable, first)
        value.replaceText("Works"); let retry = await store.save(value); XCTAssertEqual(retry, .saved)
    }
    func testCleanupFailureRetainsRecoveryAndRejectsLateCallback() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let value = try await draft(root), url = root.appendingPathComponent("field-draft.json")
        let store = FieldDraftStore(fileURL: url, remove: { _ in throw FixtureWriteError.denied }); _ = await store.begin(value)
        let closed = await store.close(id: value.id), late = await store.save(value)
        XCTAssertEqual(closed, .failed); XCTAssertEqual(late, .refused)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testCleanupCanRetryWithoutReopeningClosedIdentity() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let value = try await draft(root), url = root.appendingPathComponent("field-draft.json")
        let denied = root.appendingPathComponent("deny-remove")
        try Data().write(to: denied)
        let store = FieldDraftStore(fileURL: url, remove: { target in
            if FileManager.default.fileExists(atPath: denied.path) { throw FixtureWriteError.denied }
            try FileManager.default.removeItem(at: target)
        })
        _ = await store.begin(value)
        let before = try Data(contentsOf: url)
        let failed = await store.close(id: value.id); XCTAssertEqual(failed, .failed)
        guard case .available(let retained) = await store.load() else { return XCTFail("Expected retained recovery") }
        XCTAssertEqual(retained, value)
        var late = value; late.replaceText("Late callback")
        let lateSave = await store.save(late), restart = await store.begin(value)
        XCTAssertEqual(lateSave, .refused); XCTAssertEqual(restart, .refused)
        XCTAssertEqual(try Data(contentsOf: url), before)
        try FileManager.default.removeItem(at: denied)
        let retry = await store.close(id: value.id); XCTAssertEqual(retry, .saved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let afterClose = await store.save(late); XCTAssertEqual(afterClose, .refused)
        let next = TaskFieldDraft(taskID: UUID(), field: value.field, baseRevision: value.baseRevision, text: "Next edit")
        let opened = await store.begin(next); XCTAssertEqual(opened, .saved)
    }
    func testRecoveredDraftKeepsStaleRevisionAndNeverAutoSubmits() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        var value = try await draft(root); value.replaceText("Unsaved content")
        let url = root.appendingPathComponent("field-draft.json"); _ = await FieldDraftStore(fileURL: url).begin(value)
        let repo = repository(root), before = try await repo.load()
        _ = await repo.apply(.title("Changed elsewhere"), to: value.taskID, expected: before.revision)
        let current = try await repo.load()
        guard case .available(let restored) = await FieldDraftStore(fileURL: url).load() else { return XCTFail("Expected retained recovery") }
        XCTAssertNotEqual(restored.baseRevision, current.revision)
        XCTAssertEqual(restored.text, "Unsaved content")
        XCTAssertEqual(current.snapshot.workspace.tasks[0].body, value.originalText)
    }
    func testOrphanedBootstrapDoesNotBecomeWritableEmptyWorkspace() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let staged = root.appendingPathComponent(".initialization-interrupted", isDirectory: true)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: false)
        let original = Data("Retain interrupted initialization".utf8)
        try original.write(to: staged.appendingPathComponent("workspace.json"))
        XCTAssertThrowsError(try WorkspaceBootstrap.prepare(directory: root, initial: initial()))
        XCTAssertEqual(try Data(contentsOf: staged.appendingPathComponent("workspace.json")), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("workspace.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("settings.json").path))
    }

}

final class CaptureCommandTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_200_400)
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(identifier: "Europe/Moscow")!; value.firstWeekday = 2; return value }
    private func fixture(settings: AppSettings = AppSettings()) throws -> (URL, WorkspaceFileRepository) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let original = TaskItem(title: "Existing", body: "e\u{301} 🧩", richBody: RichBody(text: "e\u{301} 🧩", runs: [.init(location: 0, length: 2, bold: true)]))
        let data = WorkspaceData(tasks: [original])
        let snapshot = try ReadOnlyWorkspaceSnapshot(workspaceBytes: JSONEncoder().encode(data), settingsBytes: JSONEncoder().encode(settings))
        try WorkspaceBootstrap.prepare(directory: root, initial: snapshot)
        return (root, repo(root))
    }
    private func repo(_ root: URL, write: (@Sendable (Data, URL) throws -> Void)? = nil) -> WorkspaceFileRepository {
        if let write { return WorkspaceFileRepository(workspaceURL: root.appendingPathComponent("workspace.json"), settingsURL: root.appendingPathComponent("settings.json"), write: write) }
        return WorkspaceFileRepository(workspaceURL: root.appendingPathComponent("workspace.json"), settingsURL: root.appendingPathComponent("settings.json"))
    }
    private func prepared(_ document: WorkspaceDocument, title: String = "New task") throws -> TaskCaptureDraft {
        var input = TaskCaptureInput.start(destination: .inbox, workspace: document.snapshot.workspace, settings: document.snapshot.settings, now: now, calendar: calendar)
        input.title = title; input.body = "Exact e\u{301} 🧩"
        var value = TaskCaptureDraft(baseRevision: document.revision, input: input, now: now, calendar: calendar)
        try value.prepare(workspace: document.snapshot.workspace, settings: document.snapshot.settings)
        return value
    }
    func testContextDefaultsInboxAndExistingRecognitionHaveNoSideEffects() throws {
        let list = TaskList(name: "Work", color: "blue"), tag = TaskTag(name: "Multi word", color: "green")
        var data = WorkspaceData(); data.lists = [list]; data.tags = [tag]
        var settings = AppSettings(); settings.defaultListID = list.id; settings.defaultTagID = tag.id; settings.defaultPriority = .high; settings.defaultDate = .tomorrow; settings.removeDateText = true
        var input = TaskCaptureInput.start(destination: .inbox, workspace: data, settings: settings, now: now, calendar: calendar)
        XCTAssertNil(input.listID); XCTAssertEqual(input.priority, .high); XCTAssertEqual(input.tagIDs, [tag.id]); XCTAssertNotNil(input.dueDate)
        input.title = "Plan tomorrow #\"multi word\" #Unknown"
        let task = try input.task(id: UUID(), now: now, workspace: data, settings: settings, calendar: calendar)
        XCTAssertNil(task.listID); XCTAssertEqual(task.tagIDs, [tag.id]); XCTAssertTrue(task.title.contains("#Unknown")); XCTAssertFalse(task.title.contains("tomorrow")); XCTAssertEqual(data.tags.count, 1)
        input.chooseDate(nil); input.recognizeTags = false
        let ignored = try input.task(id: UUID(), now: now, workspace: data, settings: settings, calendar: calendar)
        XCTAssertNil(ignored.dueDate); XCTAssertTrue(ignored.title.contains("tomorrow")); XCTAssertTrue(ignored.title.contains("#\"multi word\""))
        let contextual = TaskCaptureInput.start(destination: .tag(tag.id), workspace: data, settings: settings, now: now, calendar: calendar)
        XCTAssertEqual(contextual.listID, list.id); XCTAssertEqual(contextual.tagIDs, [tag.id])
        let focused = TaskCaptureInput.start(destination: .all, calendarDate: now, workspace: data, settings: settings, now: now, calendar: calendar)
        XCTAssertEqual(focused.dueDate, calendar.startOfDay(for: now)); XCTAssertFalse(focused.hasDueTime)
    }
    func testCreateRetryAfterRestartPreservesAllUnownedDataAndSettings() async throws {
        let (root, repository) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let document = try await repository.load(), draft = try prepared(document)
        let settings = try Data(contentsOf: root.appendingPathComponent("settings.json"))
        guard case .created(let saved, let id) = await repository.create(draft) else { return XCTFail("Expected durable creation") }
        XCTAssertEqual(id, draft.id); XCTAssertEqual(saved.snapshot.workspace.tasks.count, 2)
        XCTAssertEqual(saved.snapshot.workspace.tasks.last, document.snapshot.workspace.tasks.first)
        let bytes = try Data(contentsOf: root.appendingPathComponent("workspace.json"))
        guard case .alreadyCreated(let replay, let replayID) = await repo(root).create(draft) else { return XCTFail("Expected identity replay") }
        XCTAssertEqual(replayID, id); XCTAssertEqual(replay.snapshot.workspace.tasks.count, 2)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("workspace.json")), bytes)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("settings.json")), settings)
    }

    func testTextBatchIsAtomicAndConfirmsTheWholeBatchAfterAWriteThrow() async throws {
        var settings = AppSettings()
        settings.defaultAddTo = .bottom
        let (root, repository) = try fixture(settings: settings)
        defer { try? FileManager.default.removeItem(at: root) }
        let before = try await repository.load()
        let snapshot = before.snapshot
        let batch = try TaskTextBatch(text: "First\nSecond\nSecond", destination: .inbox, workspace: snapshot.workspace,
                                      settings: snapshot.settings, now: now, calendar: calendar, recognizesDetails: false)
        let unrelated = try TaskTextBatch(text: "Later", destination: .inbox, workspace: snapshot.workspace,
                                          settings: snapshot.settings, now: now, calendar: calendar, recognizesDetails: false)
        let failedWriter = repo(root, write: { _, _ in throw FixtureWriteError.denied })
        guard case .notSaved(let unchanged) = await failedWriter.create(batch, expected: before.revision) else {
            return XCTFail("Expected the failed batch to leave the file untouched")
        }
        XCTAssertEqual(unchanged.snapshot.workspaceBytes, snapshot.workspaceBytes)
        let afterWrite = repo(root, write: { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        })
        guard case .alreadyCreated(let saved, _) = await afterWrite.create(batch, expected: before.revision) else {
            return XCTFail("Expected readback to confirm all of the submitted tasks")
        }
        XCTAssertEqual(saved.snapshot.workspace.tasks, snapshot.workspace.tasks + batch.tasks)
        XCTAssertEqual(saved.snapshot.settingsBytes, snapshot.settingsBytes)
        guard case .alreadyCreated = await repository.create(batch, expected: before.revision),
              case .refused(.stale) = await repository.create(unrelated, expected: before.revision) else {
            return XCTFail("Expected the same batch to replay and the unrelated batch to refuse its stale review")
        }
        var partial = snapshot.workspace
        partial.tasks.append(batch.tasks[0])
        let partialBytes = try JSONEncoder().encode(partial)
        let file = root.appendingPathComponent("workspace.json")
        try partialBytes.write(to: file, options: .atomic)
        guard case .refused(.commandConflict) = await repository.create(batch, expected: before.revision) else {
            return XCTFail("Expected a partial identity match to refuse the entire batch")
        }
        XCTAssertEqual(try Data(contentsOf: file), partialBytes)
    }
    func testAfterWriteThrowConfirmsSuccessAndDoesNotDuplicate() async throws {
        let (root, normal) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let draft = try prepared(try await normal.load())
        let throwing = repo(root, write: { bytes, url in try bytes.write(to: url, options: .atomic); throw FixtureWriteError.denied })
        guard case .alreadyCreated(let saved, _) = await throwing.create(draft) else { return XCTFail("Must confirm actual durable outcome") }
        XCTAssertEqual(saved.snapshot.workspace.tasks.filter { $0.id == draft.id }.count, 1)
        guard case .alreadyCreated = await normal.create(draft) else { return XCTFail("Expected retry confirmation") }
    }
    func testConfirmedFailureKeepsInputAndCanReturnToEditing() async throws {
        let (root, normal) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        var draft = try prepared(try await normal.load()); let original = draft
        draft.update { $0.title = "Must stay frozen" }; XCTAssertEqual(draft, original)
        let failing = repo(root, write: { _, _ in throw FixtureWriteError.denied })
        guard case .notSaved = await failing.create(draft) else { return XCTFail("Expected confirmed no-write") }
        let countAfter = try await normal.load().snapshot.workspace.tasks.count; XCTAssertEqual(countAfter, 1)
        draft.confirmedNotSaved(); draft.update { $0.title = "Retry title" }
        XCTAssertEqual(draft.input.title, "Retry title"); XCTAssertEqual(draft.id, original.id)
        try draft.prepare(workspace: (try await normal.load()).snapshot.workspace, settings: (try await normal.load()).snapshot.settings)
        guard case .created = await normal.create(draft) else { return XCTFail("Expected edited retry") }
    }
    func testUncertainFailureDoesNotUnlockOrAcknowledgeCreation() async throws {
        let (root, normal) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let draft = try prepared(try await normal.load())
        let failing = repo(root, write: { _, url in try Data("unreadable".utf8).write(to: url); throw FixtureWriteError.denied })
        guard case .uncertain = await failing.create(draft) else { return XCTFail("Unreadable outcome is uncertain") }
        XCTAssertNotNil(draft.preparedTask)
    }
    func testSameCommandCollisionAndStaleSubmissionNeverAppend() async throws {
        let (root, repository) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let document = try await repository.load(), one = try prepared(document), stale = try prepared(document, title: "Other")
        _ = await repository.create(one)
        guard case .refused(.stale) = await repository.create(stale) else { return XCTFail("Expected stale refusal") }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(one)) as? [String: Any])
        var prepared = try XCTUnwrap(object["preparedTask"] as? [String: Any]); prepared["title"] = "Conflicting"; object["preparedTask"] = prepared
        let conflict = try JSONDecoder().decode(TaskCaptureDraft.self, from: JSONSerialization.data(withJSONObject: object))
        guard case .refused(.commandConflict) = await repository.create(conflict) else { return XCTFail("Expected identity collision refusal") }
        let countAfter = try await repository.load().snapshot.workspace.tasks.count; XCTAssertEqual(countAfter, 2)
    }
    func testConcurrentSameCommandCreatesExactlyOnce() async throws {
        let (root, repository) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let draft = try prepared(try await repository.load())
        async let a = repository.create(draft); async let b = repository.create(draft)
        let values = await [a, b]
        XCTAssertEqual(values.filter { if case .created = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(values.filter { if case .alreadyCreated = $0 { true } else { false } }.count, 1)
        let countAfter = try await repository.load().snapshot.workspace.tasks.count; XCTAssertEqual(countAfter, 2)
    }
    func testCaptureRecoveryRetainsPreparedIdentityWithoutAutosubmit() async throws {
        let (root, repository) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let document = try await repository.load(), original = try prepared(document)
        let file = root.appendingPathComponent("capture-draft.json"); let first = CaptureDraftStore(fileURL: file)
        let saved = await first.begin(original); XCTAssertEqual(saved, .saved)
        let second = CaptureDraftStore(fileURL: file)
        guard case .available(let recovered) = await second.load() else { return XCTFail("Expected recovered capture") }
        XCTAssertEqual(recovered, original); let countAfter = try await repository.load().snapshot.workspace.tasks.count; XCTAssertEqual(countAfter, 1)
        _ = await repository.create(recovered); let closed = await second.close(id: recovered.id); XCTAssertEqual(closed, .saved)
        let late = await second.save(recovered); XCTAssertEqual(late, .refused); XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testCalendarRangeCaptureRecoversAndCreatesOneInclusiveAllDayTask() async throws {
        let (root, repository) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let document = try await repository.load(), snapshot = document.snapshot
        let start = calendar.startOfDay(for: now)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: start))
        var input = TaskCaptureInput.start(destination: .inbox, calendarDate: end, workspace: snapshot.workspace,
                                           settings: snapshot.settings, now: now, calendar: calendar)
        input.chooseCalendarRange(start...end, calendar: calendar)
        input.title = "Retreat tomorrow"
        let draft = TaskCaptureDraft(baseRevision: document.revision, input: input, now: now, calendar: calendar)
        let file = root.appendingPathComponent("capture-draft.json")
        let saved = await CaptureDraftStore(fileURL: file).begin(draft)
        XCTAssertEqual(saved, .saved)
        let restarted = CaptureDraftStore(fileURL: file)
        guard case .available(var recovered) = await restarted.load() else { return XCTFail("Expected range draft") }
        XCTAssertEqual(recovered, draft)
        let before = try await repository.load()
        XCTAssertEqual(before.revision, document.revision)
        try recovered.prepare(workspace: snapshot.workspace, settings: snapshot.settings)
        let task = try XCTUnwrap(recovered.preparedTask)
        XCTAssertEqual(task.title, input.title)
        XCTAssertEqual(task.scheduledDuration, TaskDurationRange(start: start, end: end, isAllDay: true))
        XCTAssertEqual(task.dueDate, end)
        XCTAssertFalse(task.hasDueTime)
        guard case .created = await repository.create(recovered) else { return XCTFail("Expected one task") }
        guard case .alreadyCreated = await repository.create(recovered) else { return XCTFail("Expected the same task") }
        let after = try await repository.load()
        XCTAssertEqual(after.snapshot.workspace.tasks.filter { $0.id == task.id }, [task])

        var templated = input
        templated.applyTemplate(TaskTemplate(name: "Other schedule", title: "Template",
                                             scheduledDuration: .init(start: now, end: now.addingTimeInterval(3600))))
        func preview(_ input: TaskCaptureInput) throws -> TaskItem {
            try input.task(id: UUID(), now: now, workspace: snapshot.workspace, settings: snapshot.settings, calendar: calendar)
        }
        XCTAssertEqual(try preview(templated).scheduledDuration, task.scheduledDuration)
        templated.useCalendarRangeEndOnly()
        XCTAssertNil(try preview(templated).scheduledDuration)
        XCTAssertEqual(try preview(templated).dueDate, end)
        input.dueDate = start
        XCTAssertThrowsError(try preview(input)) { XCTAssertEqual($0 as? TaskCaptureValidation, .schedule) }
    }

    func testStyledTemplatePreservesRichChecklistRecurrenceAndWindow() throws {
        let text = "e\u{301} 🧩", window = TaskDurationRange(start: now, end: now.addingTimeInterval(3600))
        let seed = TaskTemplate(name: "Styled", title: "Template task", body: text, checklist: [.init(title: "Step", isCompleted: true)], priority: .high,
                                richBody: RichBody(text: text, runs: [.init(location: 0, length: 2, bold: true)]), customRecurrence: CustomRecurrence(), scheduledDuration: window)
        var data = WorkspaceData(); data.templates = [seed]; let settings = AppSettings()
        var input = TaskCaptureInput.start(destination: .inbox, workspace: data, settings: settings, now: now, calendar: calendar); input.applyTemplate(seed)
        let id = UUID(), task = try input.task(id: id, now: now, workspace: data, settings: settings, calendar: calendar)
        XCTAssertTrue(task.body.utf16.elementsEqual(seed.body.utf16)); XCTAssertEqual(task.richBody, seed.richBody); XCTAssertEqual(task.scheduledDuration, window); XCTAssertEqual(task.customRecurrence, seed.customRecurrence)
        XCTAssertNotEqual(task.checklist.first?.id, seed.checklist.first?.id); XCTAssertEqual(task.checklist.first?.isCompleted, true)
        XCTAssertEqual(try input.task(id: id, now: now, workspace: data, settings: settings, calendar: calendar), task)
        input.body = "Flattened"; XCTAssertThrowsError(try input.task(id: id, now: now, workspace: data, settings: settings, calendar: calendar))
    }
    func testCaptureRefusesArchivedMissingTargetsAndUnknownWorkspace() async throws {
        let (root, repository) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let document = try await repository.load(); var input = TaskCaptureInput.start(destination: .inbox, workspace: document.snapshot.workspace, settings: document.snapshot.settings, now: now, calendar: calendar)
        input.title = "Valid"; input.listID = UUID()
        XCTAssertThrowsError(try input.task(id: UUID(), now: now, workspace: document.snapshot.workspace, settings: document.snapshot.settings, calendar: calendar))
        var archived = TaskList(name: "Archived", color: "blue"); archived.isArchived = true
        var archivedWorkspace = document.snapshot.workspace; archivedWorkspace.lists = [archived]; input.listID = archived.id
        XCTAssertThrowsError(try input.task(id: UUID(), now: now, workspace: archivedWorkspace, settings: document.snapshot.settings, calendar: calendar)) {
            XCTAssertEqual($0 as? TaskCaptureValidation, .target)
        }
        let draft = try prepared(document)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: document.snapshot.workspaceBytes) as? [String: Any]); raw["future"] = true
        let bytes = try JSONSerialization.data(withJSONObject: raw); try bytes.write(to: root.appendingPathComponent("workspace.json"))
        guard case .refused(.compatibility) = await repository.create(draft) else { return XCTFail("Unknown data must remain view-only") }
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("workspace.json")), bytes)
    }
}

final class LifecycleRepositoryTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 815_909_000)

    private func files(_ data: WorkspaceData) throws -> (URL, URL, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let workspace = directory.appendingPathComponent("workspace.json")
        let settings = directory.appendingPathComponent("settings.json")
        try JSONEncoder().encode(data).write(to: workspace)
        try JSONEncoder().encode(AppSettings()).write(to: settings)
        return (directory, workspace, settings)
    }

    func testSubtaskCreationUsesListAndInsertionOrderAndConfirmsDurableWrite() async throws {
        let list = TaskList(name: "Work", color: "#123456")
        let parent = TaskItem(title: "Parent", listID: list.id, dueDate: now,
                              priority: .high, checklist: [ChecklistItem(title: "Quick step")])
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: [parent], lists: [list]))
        defer { try? FileManager.default.removeItem(at: directory) }
        var configuration = AppSettings()
        configuration.defaultAddTo = .bottom
        try JSONEncoder().encode(configuration).write(to: settings)
        let repository = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        let initial = try await repository.load()
        let id = UUID(), title = "e\u{301}"
        let command = TaskLifecycleCommand.addSubtask(id: id, title: " " + title + " ")
        guard case .saved(let saved, nil) = await repository.apply(command, to: parent.id, expected: initial.revision, now: now)
        else { return XCTFail("Expected a durable linked subtask") }
        XCTAssertEqual(saved.snapshot.workspace.tasks, [parent, TaskItem(id: id, title: title, listID: list.id,
                                                                        createdAt: now, updatedAt: now, parentID: parent.id)])
        XCTAssertTrue(saved.snapshot.workspace.tasks[1].title.utf16.elementsEqual(title.utf16))
        guard case .refused(.stale) = await repository.apply(command, to: parent.id, expected: initial.revision),
              case .refused(.task(.invalidChild)) = await repository.apply(command, to: parent.id, expected: saved.revision),
              case .refused(.task(.invalidChild)) = await repository.apply(.addSubtask(id: UUID(), title: "  "), to: parent.id, expected: saved.revision)
        else { return XCTFail("Duplicate, stale and blank submissions must refuse") }
        XCTAssertEqual(try Data(contentsOf: workspace), saved.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: settings), initial.snapshot.settingsBytes)
    }

    func testParentChangesMoveTheWholeSubtreeAndRefuseCyclesAndUnavailableParents() async throws {
        let work = TaskList(name: "Work", color: "#123456")
        var archive = TaskList(name: "Archive", color: "#123456")
        archive.isArchived = true
        let root = TaskItem(title: "Root", body: "Styled", checklist: [ChecklistItem(title: "Quick step")],
                            richBody: RichBody(text: "Styled", runs: [.init(location: 0, length: 6, bold: true)]))
        let child = TaskItem(title: "Child", dueDate: now, parentID: root.id)
        let grandchild = TaskItem(title: "Grandchild", deletedAt: now, parentID: child.id)
        let parent = TaskItem(title: "Work parent", listID: work.id)
        let archived = TaskItem(title: "Archived parent", listID: archive.id)
        let note = TaskItem(title: "Note", kind: .note)
        let records = [root, child, grandchild, parent, archived, note]
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: records, lists: [work, archive]))
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await repository.load()
        for candidate in [root.id, child.id, archived.id, note.id, UUID()] {
            guard case .refused(.task(.invalidParent)) = await repository.apply(.setParent(candidate), to: root.id, expected: initial.revision)
            else { return XCTFail("Expected invalid parent refusal") }
        }
        XCTAssertEqual(try Data(contentsOf: workspace), initial.snapshot.workspaceBytes)
        guard case .saved(let saved, nil) = await repository.apply(.setParent(parent.id), to: root.id, expected: initial.revision, now: now)
        else { return XCTFail("Expected the cross-list link") }
        var expected = records
        expected[0].parentID = parent.id
        for index in 0...2 { expected[index].listID = work.id }
        for index in 1...2 { expected[index].updatedAt = now }
        XCTAssertEqual(saved.snapshot.workspace.tasks, expected)
        guard case .saved(let detached, nil) = await repository.apply(.setParent(nil), to: root.id, expected: saved.revision),
              case .unchanged = await repository.apply(.setParent(nil), to: root.id, expected: detached.revision)
        else { return XCTFail("Expected one detach followed by a no-op") }
        expected[0].parentID = nil
        XCTAssertEqual(detached.snapshot.workspace.tasks, expected)
        XCTAssertEqual(try Data(contentsOf: workspace), detached.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: settings), initial.snapshot.settingsBytes)
    }

    func testLifecycleDuplicateSavesAnIndependentTreeOnce() async throws {
        let parent = TaskItem(title: "Parent")
        var source = TaskItem(title: "Source", body: "Styled", dueDate: now,
                              checklist: [ChecklistItem(title: "Checked", isCompleted: true)],
                              completedAt: now, parentID: parent.id,
                              richBody: RichBody(text: "Styled", runs: [.init(location: 0, length: 6, bold: true)]))
        source.recurrence = .daily
        source.reminderDate = now.addingTimeInterval(-900)
        let finished = TaskItem(title: "Finished", completedAt: now, parentID: source.id)
        let deleted = TaskItem(title: "Deleted", deletedAt: now, parentID: source.id)
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: [parent, source, finished, deleted]))
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await repository.load()
        let copyID = UUID()
        let command = TaskLifecycleCommand.duplicate(copyID: copyID)
        guard case .saved(let saved, nil) = await repository.apply(command, to: source.id, expected: initial.revision, now: now)
        else { return XCTFail("Expected a durable copy") }
        let records = saved.snapshot.workspace.tasks
        XCTAssertEqual(Array(records.prefix(4)), initial.snapshot.workspace.tasks)
        XCTAssertEqual(records.count, 6)
        let copy = try XCTUnwrap(records.first { $0.id == copyID })
        XCTAssertEqual(copy.parentID, parent.id)
        XCTAssertNil(copy.completedAt)
        XCTAssertEqual(copy.occurrenceIndex, 1)
        XCTAssertEqual(copy.recurrence, source.recurrence)
        XCTAssertEqual(copy.reminderDates, source.reminderDates)
        XCTAssertEqual(copy.richBody, source.richBody)
        XCTAssertEqual(copy.checklist.first?.title, "Checked")
        XCTAssertEqual(copy.checklist.first?.isCompleted, true)
        XCTAssertNotEqual(copy.checklist.first?.id, source.checklist.first?.id)
        let child = try XCTUnwrap(records.first { $0.parentID == copyID })
        XCTAssertNotEqual(child.id, finished.id)
        XCTAssertEqual(child.completedAt, finished.completedAt)
        XCTAssertEqual(child.title, finished.title)
        guard case .refused(.stale) = await repository.apply(command, to: source.id, expected: initial.revision),
              case .refused(.task(.invalidCopy)) = await repository.apply(command, to: source.id, expected: saved.revision)
        else { return XCTFail("Repeated commands must not add copies") }
        XCTAssertEqual(try Data(contentsOf: workspace), saved.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: settings), initial.snapshot.settingsBytes)
    }

    func testLifecycleConvertsKindWithoutReplacingTheRecordOrItsChildren() async throws {
        var archive = TaskList(name: "Archive", color: "#123456")
        archive.isArchived = true
        let task = TaskItem(title: "Styled task", body: "Styled", dueDate: now, hasDueTime: true,
                            reminderDate: now.addingTimeInterval(-900), recurrence: .daily,
                            checklist: [ChecklistItem(title: "Done", isCompleted: true)], completedAt: now,
                            richBody: RichBody(text: "Styled", runs: [.init(location: 0, length: 6, bold: true)]))
        let child = TaskItem(title: "Child", parentID: task.id)
        let archived = TaskItem(title: "Archived task", listID: archive.id)
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: [task, child, archived], lists: [archive]))
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await repository.load()
        guard case .refused(.task(.archived)) = await repository.apply(.setKind(.note), to: archived.id, expected: initial.revision),
              case .saved(let note, nil) = await repository.apply(.setKind(.note), to: task.id, expected: initial.revision, now: now)
        else { return XCTFail("Expected an open note and an archived refusal") }
        var expected = task
        expected.kind = .note
        expected.completedAt = nil
        expected.updatedAt = now
        XCTAssertEqual(note.snapshot.workspace.tasks, [expected, child, archived])
        guard case .refused(.stale) = await repository.apply(.setKind(.task), to: task.id, expected: initial.revision),
              case .unchanged = await repository.apply(.setKind(.note), to: task.id, expected: note.revision)
        else { return XCTFail("Expected a stale refusal and an unchanged repeat") }
        XCTAssertEqual(try Data(contentsOf: workspace), note.snapshot.workspaceBytes)
        let reopened = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let revision = try await reopened.load().revision
        let conversionTime = now.addingTimeInterval(60)
        guard case .saved(let back, nil) = await reopened.apply(.setKind(.task), to: task.id, expected: revision, now: conversionTime)
        else { return XCTFail("Expected an open task after reopening the file") }
        expected.kind = .task
        expected.updatedAt = conversionTime
        XCTAssertEqual(back.snapshot.workspace.tasks, [expected, child, archived])
        XCTAssertEqual(try Data(contentsOf: settings), initial.snapshot.settingsBytes)
    }

    func testLifecycleCompletionCommitsOneTreeAndUndoConsumesItsRevision() async throws {
        var parent = TaskItem(title: "Parent")
        parent.dueDate = now
        parent.recurrence = .daily
        var child = TaskItem(title: "Child", body: "e\u{301}")
        child.parentID = parent.id
        var finished = TaskItem(title: "Finished")
        finished.parentID = parent.id
        finished.completedAt = now.addingTimeInterval(-120)
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: [parent, child, finished]))
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await repository.load()
        let outcome = await repository.apply(.complete, to: parent.id, expected: initial.revision, now: now)
        guard case .saved(let saved, let token?) = outcome else { return XCTFail("Expected durable completion and Undo") }
        let records = saved.snapshot.workspace.tasks
        XCTAssertEqual(records.count, 5)
        XCTAssertEqual(records[1].completedAt, now)
        XCTAssertEqual(records[2], finished)
        XCTAssertEqual(records[3].recurrenceSourceID, parent.id)
        XCTAssertEqual(records[4].parentID, records[3].id)
        let repeatCommand = await repository.apply(.complete, to: parent.id, expected: initial.revision, now: now)
        guard case .refused(.stale) = repeatCommand else { return XCTFail("Repeated command must refuse the stale revision") }
        let undone = await repository.undo(token, now: now.addingTimeInterval(1))
        guard case .saved(let reverted, nil) = undone else { return XCTFail("Expected durable Undo") }
        XCTAssertEqual(reverted.snapshot.workspace.tasks.count, 3)
        XCTAssertNil(reverted.snapshot.workspace.tasks[1].completedAt)
        XCTAssertEqual(reverted.snapshot.workspace.tasks[2], finished)
        XCTAssertTrue(reverted.snapshot.workspace.completionCascades.isEmpty)
        let repeatUndo = await repository.undo(token)
        guard case .refused(.stale) = repeatUndo else { return XCTFail("Undo must consume its revision") }
        XCTAssertEqual(try Data(contentsOf: settings), initial.snapshot.settingsBytes)
    }

    func testLifecycleReopenAfterReloadRetainsTheSuccessor() async throws {
        var original = TaskItem(title: "Recurring")
        original.dueDate = now
        original.recurrence = .daily
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: [original]))
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await first.load()
        guard case .saved = await first.apply(.complete, to: original.id, expected: initial.revision, now: now) else {
            return XCTFail("Expected completion")
        }
        let reopened = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let durable = try await reopened.load()
        guard case .saved(let result, nil) = await reopened.apply(.reopen, to: original.id, expected: durable.revision) else {
            return XCTFail("Expected reopen")
        }
        XCTAssertEqual(result.snapshot.workspace.tasks.count, 2)
        XCTAssertNil(result.snapshot.workspace.tasks[0].completedAt)
        XCTAssertEqual(result.snapshot.workspace.tasks[1], durable.snapshot.workspace.tasks[1])
    }

    func testLifecycleFailureAndAfterWriteConfirmation() async throws {
        let original = TaskItem(title: "Task")
        let (directory, workspace, settings) = try files(WorkspaceData(tasks: [original]))
        defer { try? FileManager.default.removeItem(at: directory) }
        let failing = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings) { _, _ in throw FixtureWriteError.denied }
        let initial = try await failing.load()
        guard case .persistenceFailed = await failing.apply(.trash, to: original.id, expected: initial.revision) else {
            return XCTFail("Expected refused write")
        }
        XCTAssertEqual(try Data(contentsOf: workspace), initial.snapshot.workspaceBytes)
        let afterWrite = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        guard case .saved(let durable, let undo?) = await afterWrite.apply(.trash, to: original.id, expected: initial.revision) else {
            return XCTFail("Expected confirmation after replacement")
        }
        XCTAssertNotNil(durable.snapshot.workspace.tasks[0].deletedAt)
        guard case .saved(let restored, nil) = await afterWrite.undo(undo) else { return XCTFail("Expected restore") }
        XCTAssertNil(restored.snapshot.workspace.tasks[0].deletedAt)
    }

    func testLifecycleGuardsArchivedNotesAndUnknownDataAtWriteBoundary() async throws {
        var archived = TaskList(name: "Archive", color: "#123456")
        archived.isArchived = true
        var task = TaskItem(title: "Archived task")
        task.listID = archived.id
        var child = TaskItem(title: "Archived child")
        child.listID = archived.id
        child.parentID = task.id
        var note = TaskItem(title: "Note")
        note.kind = .note
        var data = WorkspaceData(tasks: [task, child, note])
        data.lists = [archived]
        let (directory, workspace, settings) = try files(data)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await repository.load()
        guard case .refused(.task(.archived)) = await repository.apply(.trash, to: task.id, expected: initial.revision),
              case .refused(.task(.wrongStatus)) = await repository.apply(.complete, to: note.id, expected: initial.revision),
              case .refused(.task(.invalidDestination)) = await repository.apply(.move(archived.id), to: note.id, expected: initial.revision)
        else { return XCTFail("Expected guarded commands") }
        XCTAssertEqual(try Data(contentsOf: workspace), initial.snapshot.workspaceBytes)
        guard case .saved(let moved, nil) = await repository.apply(.move(nil), to: task.id, expected: initial.revision)
        else { return XCTFail("Expected movement out of archive") }
        XCTAssertNil(moved.snapshot.workspace.tasks[0].listID)
        XCTAssertNil(moved.snapshot.workspace.tasks[1].listID)
        XCTAssertEqual(moved.snapshot.workspace.tasks[1].parentID, task.id)
        var unknown = try XCTUnwrap(JSONSerialization.jsonObject(with: moved.snapshot.workspaceBytes) as? [String: Any])
        unknown["futureLifecycle"] = ["keep": true]
        let opaque = try JSONSerialization.data(withJSONObject: unknown)
        try opaque.write(to: workspace)
        let protected = try await repository.load()
        guard case .refused(.compatibility) = await repository.apply(.complete, to: task.id, expected: protected.revision)
        else { return XCTFail("Expected compatibility refusal") }
        XCTAssertEqual(try Data(contentsOf: workspace), opaque)
    }
}

extension ReadOnlyWorkspaceTests {
    func testEndReminderRoundTripsAndCalendarUndoRestoresItsAnchor() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_918_400)
        let task = TaskItem(title: "Timed task", dueDate: due, hasDueTime: true,
                            reminderFollowsSchedule: false, scheduledDuration: .init(start: due - 3_600, end: due))
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let first = repository(files), initial = try await first.load()
        let calendar = initial.snapshot.settings.calendar
        let originalJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: initial.snapshot.workspaceBytes) as? [String: Any])
        XCTAssertTrue(originalJSON["tasks"] is [[String: Any]])
        var edit = TaskScheduleEdit(task: task, settings: initial.snapshot.settings, calendar: calendar, now: due)
        edit.remindsAtEnd = true
        guard case .saved(let saved, nil) = await first.apply(edit, expected: initial.revision) else {
            return XCTFail("Expected a durable end reminder")
        }
        let savedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: saved.snapshot.workspaceBytes) as? [String: Any])
        XCTAssertEqual((savedJSON["tasks"] as? [String: Any])?["format"] as? String, "endRemindersV1")
        XCTAssertEqual(saved.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        let second = repository(files), reloaded = try await second.load()
        XCTAssertEqual(reloaded.snapshot.workspace.tasks.first?.effectiveReminderDates, [due])
        XCTAssertEqual(reloaded.snapshot.workspace.tasks.first?.reminderDates, [])
        guard case .saved(let moved, let undo?) = await second.apply(.resizeEnd(due + 900), to: task.id,
                                                                    expected: reloaded.revision, calendar: calendar) else {
            return XCTFail("Expected an end edit and Undo")
        }
        XCTAssertEqual(moved.snapshot.workspace.tasks.first?.endReminderDate, due + 900)
        guard case .saved(let renamed) = await second.apply(.title("Renamed"), to: task.id, expected: moved.revision),
              case .saved(let restored, nil) = await second.undo(undo) else {
            return XCTFail("Expected title edit and scoped Undo in the protected file")
        }
        XCTAssertEqual(renamed.snapshot.workspace.tasks.first?.endReminderDate, due + 900)
        XCTAssertEqual(restored.snapshot.workspace.tasks.first?.title, "Renamed")
        XCTAssertEqual(restored.snapshot.workspace.tasks.first?.endReminderDate, due)
        XCTAssertEqual(restored.snapshot.settingsBytes, initial.snapshot.settingsBytes)
    }

    func testScheduleNoOpPreservesPreciseRolledSeriesAndBytes() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_918_400.125)
        var task = TaskItem(title: "Precise recurring task", dueDate: due, hasDueTime: true,
                            timeZoneID: "Europe/Moscow", customRecurrence: CustomRecurrence(skipWeekends: true),
                            occurrenceIndex: 5,
                            scheduledDuration: TaskDurationRange(start: due - 12.375, end: due, isAllDay: false),
                            recurrenceNominalDate: due - 172_800)
        task.reminderDate = due - 864.125
        task.additionalReminderDates = [due - 960.25, due - 864.125]
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), original = try await repo.load()
        let calendar = original.snapshot.settings.calendar
        var edit = TaskScheduleEdit(task: task, settings: original.snapshot.settings, calendar: calendar, now: due)
        edit.chooseDay(due)
        guard case .unchanged = await repo.apply(edit, expected: original.revision) else {
            return XCTFail("Expected byte-preserving no-op")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), original.snapshot.workspaceBytes)

        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: due))
        edit.chooseDay(next)
        guard case .saved(let saved, nil) = await repo.apply(edit, expected: original.revision) else {
            return XCTFail("Expected day move")
        }
        let result = try XCTUnwrap(saved.snapshot.workspace.tasks.first)
        let moved = try XCTUnwrap(result.dueDate)
        XCTAssertEqual(moved, next)
        XCTAssertEqual(result.scheduledDuration?.start, moved - 12.375)
        XCTAssertEqual(result.scheduledDuration?.end, moved)
        XCTAssertEqual(result.occurrenceIndex, 5)
        XCTAssertEqual(result.recurrenceNominalDate, moved)
        XCTAssertEqual(result.reminderDate, task.reminderDate)
        XCTAssertEqual(result.additionalReminderDates, task.additionalReminderDates)
        XCTAssertEqual(saved.snapshot.settingsBytes, original.snapshot.settingsBytes)
    }

    func testScheduleZoneAndAutomaticRemindersFollowCivilDayAndClearIsScoped() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start))
        let seriesID = UUID()
        var task = TaskItem(title: "Across DST", body: "Preserved", dueDate: end, priority: .high, recurrence: .monthly,
                            recurrenceSourceID: seriesID, reminderFollowsSchedule: true, timeZoneID: calendar.timeZone.identifier,
                            scheduledDuration: TaskDurationRange(start: start, end: end, isAllDay: true))
        task.reminderDates = [end]
        let settings = AppSettings()
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: calendar, now: start)
        edit.setZone("Europe/Moscow")
        let changed = try edit.applying(to: task, settings: settings)
        let window = try XCTUnwrap(changed.scheduledDuration)
        XCTAssertTrue(window.isAllDay)
        XCTAssertEqual(window.end, changed.dueDate)
        XCTAssertEqual(edit.calendar.component(.day, from: window.start), 7)
        XCTAssertEqual(edit.calendar.component(.day, from: window.end), 9)
        XCTAssertEqual(window.end.timeIntervalSince(window.start), 172_800)
        XCTAssertEqual(changed.reminderDates, edit.automaticReminders(settings: settings))
        XCTAssertEqual(changed.reminderFollowsSchedule, true)

        task.reminderFollowsSchedule = false
        task.recurrenceEndDate = end
        var manual = TaskScheduleEdit(task: task, settings: settings, calendar: calendar, now: start)
        manual.setZone("America/Los_Angeles")
        let zoned = try manual.applying(to: task, settings: settings)
        XCTAssertEqual(zoned.reminderDates, [end])
        XCTAssertEqual(zoned.reminderFollowsSchedule, false)
        XCTAssertEqual(zoned.recurrenceEndDate.map { manual.calendar.component(.day, from: $0) }, 9)

        manual.hasDate = false
        let cleared = try manual.applying(to: task, settings: settings)
        let expected = TaskItem(id: task.id, title: task.title, body: task.body, priority: .high,
                                createdAt: task.createdAt, updatedAt: task.updatedAt, recurrenceSourceID: seriesID)
        XCTAssertEqual(cleared, expected)
    }

    func testScheduleInvalidStaleAndFailedWritesLeaveOriginalBytes() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_918_400)
        let task = TaskItem(title: "Valid", dueDate: due, hasDueTime: true,
                            scheduledDuration: TaskDurationRange(start: due - 60, end: due, isAllDay: false))
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), original = try await repo.load()
        var edit = TaskScheduleEdit(task: task, settings: original.snapshot.settings, calendar: .current, now: due)
        edit.setStart(due + 60)
        guard case .refused(.invalid(.invalidDuration)) = await repo.apply(edit, expected: original.revision) else {
            return XCTFail("Expected invalid range refusal")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), original.snapshot.workspaceBytes)
        edit.setEnd(due + 120)
        let failing = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings, write: { _, _ in
            throw FixtureWriteError.denied
        })
        guard case .persistenceFailed = await failing.apply(edit, expected: original.revision) else {
            return XCTFail("Expected persistence failure")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), original.snapshot.workspaceBytes)
        guard case .saved = await repo.apply(.title("Changed"), to: task.id, expected: original.revision) else {
            return XCTFail("Expected title save")
        }
        let renamed = try Data(contentsOf: files.workspace)
        guard case .refused(.stale) = await repo.apply(edit, expected: original.revision) else {
            return XCTFail("Expected stale draft refusal")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), renamed)
    }

    func testScheduleExplicitCustomRuleChangeRestartsTheSeries() throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_918_400)
        let original = CustomRecurrence(unit: .months, monthDays: [9], skipWeekends: true)
        let task = TaskItem(title: "Rolled", dueDate: due, customRecurrence: original, occurrenceIndex: 4,
                            recurrenceNominalDate: due - 172_800)
        let settings = AppSettings()
        var edit = TaskScheduleEdit(task: task, settings: settings, calendar: .current, now: due)
        edit.selectCustomRepeat(original)
        XCTAssertEqual(try edit.applying(to: task, settings: settings), task)
        var rule = original
        rule.maxOccurrences = 8
        edit.selectCustomRepeat(rule)
        let restarted = try edit.applying(to: task, settings: settings)
        XCTAssertEqual(restarted.customRecurrence, rule)
        XCTAssertEqual(restarted.occurrenceIndex, 1)
        XCTAssertEqual(restarted.recurrenceNominalDate, due)
    }
}

extension ReadOnlyWorkspaceTests {
    func testCalendarSkipCommitsOnceAndRestoresThroughRepositoryUndo() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_914_800)
        let task = TaskItem(title: "Recurring", dueDate: due, hasDueTime: true, recurrence: .weekly,
                            recurrenceEndDate: due + 7 * 86_400)
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), initial = try await repo.load()
        let calendar = initial.snapshot.settings.calendar
        guard case .saved(let skipped, let undo?) = await repo.apply(.skipOccurrence, to: task.id,
                expected: initial.revision, calendar: calendar) else { return XCTFail("Expected saved skip and Undo") }
        let current = try XCTUnwrap(skipped.snapshot.workspace.tasks.first)
        XCTAssertEqual(skipped.snapshot.workspace.tasks.count, 1)
        XCTAssertEqual(current.id, task.id)
        XCTAssertEqual(current.dueDate, calendar.date(byAdding: .day, value: 7, to: due))
        guard case .refused(.stale) = await repo.apply(.skipOccurrence, to: task.id,
                expected: initial.revision, calendar: calendar) else { return XCTFail("Expected stale refusal") }
        guard case .refused(.invalidCalendarOperation) = await repo.apply(.skipOccurrence, to: task.id,
                expected: skipped.revision, calendar: calendar) else { return XCTFail("Expected terminal refusal") }
        XCTAssertEqual(try Data(contentsOf: files.workspace), skipped.snapshot.workspaceBytes)
        guard case .saved(let restored, nil) = await repo.undo(undo) else { return XCTFail("Expected saved Undo") }
        XCTAssertEqual(restored.snapshot.settingsBytes, initial.snapshot.settingsBytes)
        XCTAssertEqual(CalendarScheduleSnapshot(try XCTUnwrap(restored.snapshot.workspace.tasks.first)),
                       CalendarScheduleSnapshot(task))
    }

    func testCalendarMoveShiftsManualReminderAndUndoPreservesLaterTitle() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_914_800.125)
        let rule = CustomRecurrence(unit: .months, monthDays: [9], skipWeekends: true)
        var task = TaskItem(title: "Move a short range", dueDate: due, hasDueTime: true,
                            reminderFollowsSchedule: false, timeZoneID: "Europe/Moscow", customRecurrence: rule,
                            occurrenceIndex: 4, scheduledDuration: TaskDurationRange(start: due - 75.375, end: due),
                            recurrenceNominalDate: due - 172_800)
        task.reminderDates = [due - 900]
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), initial = try await repo.load()
        let calendar = initial.snapshot.settings.calendar
        let target = due + 3_600
        guard case .saved(let moved, let undo?) = await repo.apply(.move(start: target, allDay: false), to: task.id,
                                                                   expected: initial.revision, calendar: calendar) else {
            return XCTFail("Expected the Calendar move and scoped Undo")
        }
        let changed = try XCTUnwrap(moved.snapshot.workspace.tasks.first)
        let newDue = target + 75.375
        XCTAssertEqual(changed.dueDate, newDue)
        XCTAssertEqual(changed.scheduledDuration?.start, target)
        XCTAssertEqual(changed.reminderDates, [newDue - 900])
        XCTAssertEqual(changed.occurrenceIndex, 4)
        XCTAssertEqual(changed.recurrenceNominalDate, newDue)
        guard case .saved(let renamed) = await repo.apply(.title("Later title"), to: task.id, expected: moved.revision) else {
            return XCTFail("Expected a durable unrelated edit")
        }
        XCTAssertTrue(undo.canRestore(in: renamed.snapshot.workspace))
        guard case .saved(let restored, nil) = await repo.undo(undo) else { return XCTFail("Expected schedule Undo") }
        let result = try XCTUnwrap(restored.snapshot.workspace.tasks.first)
        XCTAssertEqual(CalendarScheduleSnapshot(result), CalendarScheduleSnapshot(task))
        XCTAssertEqual(result.title, "Later title")
        XCTAssertEqual(restored.snapshot.settingsBytes, initial.snapshot.settingsBytes)
    }

    func testCalendarNoOpAndStaleUndoDoNotWrite() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 815_914_800.125)
        let task = TaskItem(title: "Point", dueDate: due, hasDueTime: true)
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), initial = try await repo.load()
        let calendar = initial.snapshot.settings.calendar
        guard case .unchanged = await repo.apply(.setPoint(date: due, allDay: false), to: task.id,
                                                 expected: initial.revision, calendar: calendar) else {
            return XCTFail("Expected unchanged point")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), initial.snapshot.workspaceBytes)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: due))
        let move = CalendarScheduling.moveOnDay(task, day: tomorrow, forceAllDay: false, calendar: calendar)
        guard case .saved(let moved, let undo?) = await repo.apply(move, to: task.id, expected: initial.revision, calendar: calendar) else {
            return XCTFail("Expected move")
        }
        XCTAssertEqual(moved.snapshot.workspace.tasks.first?.dueDate, tomorrow)
        XCTAssertNil(moved.snapshot.workspace.tasks.first?.scheduledDuration)
        guard case .refused(.stale) = await repo.apply(.unschedule, to: task.id, expected: initial.revision, calendar: calendar) else {
            return XCTFail("Expected a stale schedule refusal")
        }
        guard case .saved(let completed, _) = await repo.apply(.complete, to: task.id, expected: moved.revision) else {
            return XCTFail("Expected completed task")
        }
        XCTAssertFalse(undo.canRestore(in: completed.snapshot.workspace))
        guard case .refused(.changedSinceCalendarEdit) = await repo.undo(undo) else {
            return XCTFail("Expected a status guard refusal")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), completed.snapshot.workspaceBytes)
    }
}

extension ReadOnlyWorkspaceTests {
    func testCalendarPreferencesOnlyReplaceOwnedBytesAndSupportSparseLegacySettings() async throws {
        let task = TaskItem(title: "Keep the workspace exact")
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let prefix = "{\n  \"futurePreference\": { \"text\": \"e\\u0301\", \"array\": [1, 2] }, \"calendarOptions\" : "
        let suffix = " ,\n  \"defaultDurationMinutes\": 45\n}\n"
        let original = Data((prefix + "{\"additionalTimeZoneID\":\"Europe/London\"}" + suffix).utf8)
        try original.write(to: files.settings)
        let repo = repository(files), before = try await repo.load()
        XCTAssertEqual(before.snapshot.settings.calendarOptions.additionalTimeZoneID, "Europe/London")
        var options = before.snapshot.settings.calendarOptions
        options.mode = .multiWeek
        options.multiWeekCount = 6
        options.showCompleted = false
        options.sourceColors[.inbox] = "#2468AC"
        guard case .saved(let saved) = await repo.saveCalendarOptions(options, expected: before.revision) else {
            return XCTFail("Expected scoped Calendar preference write")
        }
        let persisted = try Data(contentsOf: files.settings)
        XCTAssertTrue(persisted.starts(with: prefix.utf8))
        XCTAssertTrue(String(decoding: persisted, as: UTF8.self).hasSuffix(suffix))
        XCTAssertEqual(saved.snapshot.settings.calendarOptions, options)
        XCTAssertEqual(saved.snapshot.settings.defaultDurationMinutes, 45)
        XCTAssertEqual(try Data(contentsOf: files.workspace), before.snapshot.workspaceBytes)
        guard case .unchanged = await repo.saveCalendarOptions(options, expected: saved.revision) else {
            return XCTFail("Expected unchanged Done")
        }
        XCTAssertEqual(try Data(contentsOf: files.settings), persisted)
        guard case .stale = await repo.saveCalendarOptions(.init(), expected: before.revision) else {
            return XCTFail("Expected stale preference refusal")
        }
        XCTAssertEqual(try Data(contentsOf: files.settings), persisted)
    }

    func testCalendarFoldCutoffsPersistResetAndRefuseUnknownPayload() async throws {
        let files = try fixture(WorkspaceData(tasks: [TaskItem(title: "Keep the workspace exact")]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let legacy = Data(#"{"calendarOptions":{},"other":{"keep":1}}"#.utf8)
        try legacy.write(to: files.settings)
        let repo = repository(files), before = try await repo.load()
        var draft = before.snapshot.settings.calendarOptions
        XCTAssertEqual(draft.foldedHours, .init())
        draft.foldedHours = .init(earlyEnd: 6, lateStart: 22)
        guard case .saved(let saved) = await repo.saveCalendarOptions(draft, expected: before.revision)
        else { return XCTFail("Expected custom cutoffs to save") }
        let reopened = try await repository(files).load()
        XCTAssertEqual(reopened.snapshot.settings.calendarOptions.foldedHours, draft.foldedHours)
        XCTAssertTrue(String(decoding: reopened.snapshot.settingsBytes, as: UTF8.self).hasSuffix(#","other":{"keep":1}}"#))
        draft.foldedHours = .init()
        guard case .saved(let reset) = await repo.saveCalendarOptions(draft, expected: saved.revision)
        else { return XCTFail("Expected reset to save") }
        XCTAssertFalse(String(decoding: reset.snapshot.settingsBytes, as: UTF8.self).contains("foldedHours"))
        let unknown = Data(#"{"calendarOptions":{"foldedHours":{"earlyEnd":6,"lateStart":22,"future":true}}}"#.utf8)
        try unknown.write(to: files.settings)
        let unrecognized = try await repo.load()
        draft.foldedHours = .init(earlyEnd: 8, lateStart: 20)
        guard case .incompatible = await repo.saveCalendarOptions(draft, expected: unrecognized.revision)
        else { return XCTFail("Expected the unknown nested preference to remain intact") }
        XCTAssertEqual(try Data(contentsOf: files.settings), unknown)
        XCTAssertEqual(try Data(contentsOf: files.workspace), before.snapshot.workspaceBytes)
    }

    func testCalendarPreferencesPersistIndependentIconsAndKeepLegacyMaster() async throws {
        let files = try fixture(WorkspaceData(tasks: [TaskItem(title: "Unchanged")]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let original = Data(#"{"calendarOptions":{"showItemIcons":false},"futurePreference":{"value":1}}"#.utf8)
        try original.write(to: files.settings)
        let repo = repository(files), before = try await repo.load()
        var draft = before.snapshot.settings.calendarOptions
        XCTAssertFalse(draft.showItemIcons)
        XCTAssertTrue(draft.showTaskIcons)
        XCTAssertTrue(draft.showNoteIcons)
        guard case .unchanged = await repo.saveCalendarOptions(draft, expected: before.revision)
        else { return XCTFail("Legacy settings must not be written on unchanged Done") }
        XCTAssertEqual(try Data(contentsOf: files.settings), original)
        draft.showTaskIcons = false
        draft.showItemIcons = true
        guard case .saved(let saved) = await repo.saveCalendarOptions(draft, expected: before.revision)
        else { return XCTFail("Expected independent settings to save") }
        let persisted = try Data(contentsOf: files.settings)
        XCTAssertTrue(String(decoding: persisted, as: UTF8.self).hasSuffix(#","futurePreference":{"value":1}}"#))
        let settings = try XCTUnwrap(JSONSerialization.jsonObject(with: persisted) as? [String: Any])
        let calendar = try XCTUnwrap(settings["calendarOptions"] as? [String: Any])
        XCTAssertEqual(calendar["showItemIcons"] as? Bool, true)
        XCTAssertEqual(calendar["showTaskIcons"] as? Bool, false)
        XCTAssertNil(calendar["showNoteIcons"])
        let reopened = try await repository(files).load()
        XCTAssertEqual(reopened.snapshot.settings.calendarOptions, draft)
        draft.showItemIcons = false
        guard case .saved(let hidden) = await repo.saveCalendarOptions(draft, expected: saved.revision)
        else { return XCTFail("Expected the master switch to save without resetting the split choice") }
        XCTAssertFalse(hidden.snapshot.settings.calendarOptions.showTaskIcons)
        XCTAssertTrue(hidden.snapshot.settings.calendarOptions.showNoteIcons)
        XCTAssertEqual(try Data(contentsOf: files.workspace), before.snapshot.workspaceBytes)
    }

    func testCalendarPreferencesPreserveUnknownAndDuplicateCalendarFields() async throws {
        let files = try fixture(WorkspaceData())
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        for input in [
            "{\"calendarOptions\":{\"mode\":\"future-view\"}}",
            "{\"calendarOptions\":{\"futureOption\":[\"keep\"]}}",
            "{\"calendarOptions\":{\"showCompleted\":true,\"showCompleted\":false}}"
        ] {
            let original = Data(input.utf8)
            try original.write(to: files.settings)
            let before = try await repo.load()
            var options = before.snapshot.settings.calendarOptions
            options.mode = .month
            guard case .incompatible = await repo.saveCalendarOptions(options, expected: before.revision) else {
                return XCTFail("Expected refusal of an unsupported Calendar object")
            }
            XCTAssertEqual(try Data(contentsOf: files.settings), original)
            XCTAssertEqual(try Data(contentsOf: files.workspace), before.snapshot.workspaceBytes)
        }
    }

    func testCalendarPreferencesInsertMissingObjectAndConfirmAfterWriteThrow() async throws {
        let files = try fixture(WorkspaceData())
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let original = Data("{ \"defaultDurationMinutes\" : 45 }\n".utf8)
        try original.write(to: files.settings)
        let failing = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { _, _ in
            throw FixtureWriteError.denied
        }
        let before = try await failing.load()
        var options = before.snapshot.settings.calendarOptions
        options.mode = .agenda
        guard case .persistenceFailed = await failing.saveCalendarOptions(options, expected: before.revision) else {
            return XCTFail("Expected a confirmed failed write")
        }
        XCTAssertEqual(try Data(contentsOf: files.settings), original)
        let afterWrite = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        guard case .saved(let saved) = await afterWrite.saveCalendarOptions(options, expected: before.revision) else {
            return XCTFail("Expected confirmation from the durable settings")
        }
        XCTAssertEqual(saved.snapshot.settings.calendarOptions, options)
        XCTAssertEqual(saved.snapshot.settings.defaultDurationMinutes, 45)
        XCTAssertEqual(try Data(contentsOf: files.workspace), before.snapshot.workspaceBytes)
    }
}

extension ReadOnlyWorkspaceTests {
    func testTaskMetadataWritesPreserveRichBodyScheduleHierarchyAndSettings() async throws {
        let tag = TaskTag(name: "Planning", color: "#334455")
        let unavailable = UUID()
        let body = "Plan e\u{301} 🧩"
        let due = Date(timeIntervalSinceReferenceDate: 815_914_800.125)
        let oldStep = ChecklistItem(title: "e\u{301}")
        let blank = ChecklistItem(title: " ")
        let task = TaskItem(title: "Project", body: body, tagIDs: [unavailable], dueDate: due, hasDueTime: true,
                            checklist: [oldStep, blank], timeZoneID: "Europe/Moscow",
                            scheduledDuration: .init(start: due - 60.375, end: due),
                            richBody: RichBody(text: body, runs: [.init(location: 0, length: 4, bold: true)]))
        let child = TaskItem(title: "Linked child", parentID: task.id)
        let files = try fixture(WorkspaceData(tasks: [task, child], tags: [tag]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), start = try await repo.load()
        let now = due + 900
        guard case .saved(let prioritized) = await repo.apply(.metadata(.priority(.high)), to: task.id, expected: start.revision, now: now),
              case .saved(let tagged) = await repo.apply(.metadata(.tags([unavailable, tag.id])), to: task.id, expected: prioritized.revision, now: now) else {
            return XCTFail("Expected durable priority and tag edits")
        }
        var renamed = oldStep
        renamed.title = "é"
        guard case .saved(let checked) = await repo.apply(.metadata(.setChecklistCompleted(id: blank.id, completed: true)),
                                                          to: task.id, expected: tagged.revision, now: now) else {
            return XCTFail("Expected direct check of an existing blank row")
        }
        var checkedBlank = blank
        checkedBlank.isCompleted = true
        let new = ChecklistItem(title: "Bring notes")
        let items = [new, checkedBlank, renamed]
        guard case .saved(let saved) = await repo.apply(.metadata(.checklist(items)), to: task.id, expected: checked.revision, now: now) else {
            return XCTFail("Expected staged order, title and new item to save")
        }
        var expected = task
        expected.priority = .high
        expected.tagIDs.append(tag.id)
        expected.checklist = items
        expected.updatedAt = now
        let actual = try XCTUnwrap(saved.snapshot.workspace.tasks.first)
        XCTAssertTrue(TaskMetadataChange.sameChecklist(actual.checklist, items))
        XCTAssertTrue(actual.body.utf16.elementsEqual(body.utf16))
        XCTAssertEqual(actual.richBody, task.richBody)
        XCTAssertEqual(saved.snapshot.workspace.tasks, [expected, child])
        XCTAssertEqual(saved.snapshot.workspace.tags, [tag])
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
        guard case .unchanged = await repo.apply(.metadata(.checklist(items)), to: task.id, expected: saved.revision) else {
            return XCTFail("Expected exact no-op")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), saved.snapshot.workspaceBytes)
    }

    func testTaskMetadataRefusalsPreserveBytes() async throws {
        var archive = TaskList(name: "Archive", color: "#334455")
        archive.isArchived = true
        let item = ChecklistItem(title: "Existing")
        let task = TaskItem(title: "Task", checklist: [item])
        let locked = TaskItem(title: "Archived", listID: archive.id, checklist: [item])
        let ambiguous = TaskItem(title: "Ambiguous", checklist: [item, item])
        let files = try fixture(WorkspaceData(tasks: [task, locked, ambiguous], lists: [archive]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files), start = try await repo.load()
        let cases: [(TaskItem, TaskMetadataChange, WorkspaceWriteRefusal)] = [
            (task, .tags([UUID()]), .metadata(.unavailableTag)),
            (task, .checklist([ChecklistItem(title: "\n  ")]), .metadata(.emptyChecklistTitle)),
            (task, .setChecklistCompleted(id: UUID(), completed: true), .metadata(.missingChecklistItem)),
            (ambiguous, .setChecklistCompleted(id: item.id, completed: true), .metadata(.ambiguousChecklist)),
            (locked, .priority(.high), .readOnlyRecord)
        ]
        for (record, command, refusal) in cases {
            let outcome = await repo.apply(.metadata(command), to: record.id, expected: start.revision)
            assertRefused(outcome, refusal)
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }

    func testTaskMetadataConfirmsAfterWriteThrowAndRefusesStaleRetry() async throws {
        let task = TaskItem(title: "Set priority")
        let files = try fixture(WorkspaceData(tasks: [task]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        let start = try await repo.load()
        guard case .saved(let saved) = await repo.apply(.metadata(.priority(.medium)), to: task.id, expected: start.revision) else {
            return XCTFail("Expected durable write confirmation")
        }
        XCTAssertEqual(saved.snapshot.workspace.tasks.first?.priority, .medium)
        assertRefused(await repo.apply(.metadata(.priority(.high)), to: task.id, expected: start.revision), .stale)
        XCTAssertEqual(try Data(contentsOf: files.workspace), saved.snapshot.workspaceBytes)
    }
}

extension ReadOnlyWorkspaceTests {
    func testTaskProgressWritesOnlyProgressAndRefusesStaleOrFailedWrites() async throws {
        let date = Date(timeIntervalSinceReferenceDate: 815_914_800)
        let task = TaskItem(title: "Project", body: "Keep these details", dueDate: date,
                            hasDueTime: true, reminderDate: date - 900, recurrence: .daily)
        let note = TaskItem(title: "Note", kind: .note)
        let files = try fixture(WorkspaceData(tasks: [task, note]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let repo = repository(files)
        let start = try await repo.load()
        let failedRepo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings, write: { _, _ in
            throw CocoaError(.fileWriteNoPermission)
        })
        guard case .persistenceFailed = await failedRepo.apply(.metadata(.progress(60)), to: task.id, expected: start.revision) else {
            return XCTFail("Expected a refused disk write")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
        assertRefused(await repo.apply(.metadata(.progress(80)), to: note.id, expected: start.revision), .metadata(.unavailableProgress))
        guard case .saved(let saved) = await repo.apply(.metadata(.progress(100)), to: task.id,
                                                       expected: start.revision, now: date + 1) else {
            return XCTFail("Expected saved progress")
        }
        var expected = try XCTUnwrap(TaskMetadataChange.progress(100).applying(to: task, availableTags: []))
        expected.updatedAt = date + 1
        XCTAssertEqual(saved.snapshot.workspace.tasks, [expected, note])
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
        assertRefused(await repo.apply(.metadata(.progress(50)), to: task.id, expected: start.revision), .stale)
        guard case .unchanged = await repo.apply(.metadata(.progress(100)), to: task.id, expected: saved.revision) else {
            return XCTFail("Expected no write for the same percentage")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), saved.snapshot.workspaceBytes)
    }
}

extension ReadOnlyWorkspaceTests {
    func testTaskBatchIsOneAtomicWriteWithStaleAndFailedWriteProtection() async throws {
        let first = TaskItem(title: "First")
        let second = TaskItem(title: "Second")
        let other = TaskItem(title: "Other", body: "Keep this")
        let files = try fixture(WorkspaceData(tasks: [first, second, other]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let denied = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { _, _ in
            throw FixtureWriteError.denied
        }
        let start = try await denied.load()
        let batch = TaskBatchEdit(ids: [second.id, first.id], action: .priority(.high))
        guard case .persistenceFailed = await denied.apply(batch, expected: start.revision) else {
            return XCTFail("Expected a disk refusal")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
        let repo = WorkspaceFileRepository(workspaceURL: files.workspace, settingsURL: files.settings) { bytes, url in
            try bytes.write(to: url, options: .atomic)
            throw FixtureWriteError.denied
        }
        assertRefused(await repo.apply(TaskBatchEdit(ids: [first.id, UUID()], action: .priority(.high)),
                                       expected: start.revision), .batch(.invalidSelection))
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
        guard case .saved(let saved) = await repo.apply(batch, expected: start.revision) else {
            return XCTFail("Expected both changes to be confirmed after replacement")
        }
        XCTAssertEqual(saved.snapshot.workspace.tasks.map(\.priority), [.high, .high, .none])
        XCTAssertEqual(saved.snapshot.workspace.tasks.last, other)
        assertRefused(await repo.apply(batch, expected: start.revision), .stale)
        guard case .unchanged = await denied.apply(batch, expected: saved.revision) else {
            return XCTFail("An identical batch should need no write")
        }
        XCTAssertEqual(try Data(contentsOf: files.workspace), saved.snapshot.workspaceBytes)
        XCTAssertEqual(try Data(contentsOf: files.settings), start.snapshot.settingsBytes)
    }
}

extension ReadOnlyWorkspaceTests {
    func testCalendarDetailsSaveResetAndKeepOtherSettingsBytes() async throws {
        let files = try fixture(WorkspaceData(tasks: [TaskItem(title: "Do not rewrite this")]))
        defer { try? FileManager.default.removeItem(at: files.directory) }
        let prefix = "{\n \"futureSetting\" : [1, 2], \"calendarOptions\" : "
        let suffix = ", \"defaultDurationMinutes\" : 45\n}\n"
        let original = Data((prefix + #"{"showDetails":false}"# + suffix).utf8)
        try original.write(to: files.settings)
        let repo = repository(files), start = try await repo.load()
        var draft = start.snapshot.settings.calendarOptions
        XCTAssertFalse(draft.showDetails)
        draft.showDetails = true
        guard case .saved(let saved) = await repo.saveCalendarOptions(draft, expected: start.revision) else {
            return XCTFail("Expected Show Details to save")
        }
        let reloaded = try await repo.load()
        XCTAssertTrue(reloaded.snapshot.settings.calendarOptions.showDetails)
        XCTAssertTrue(reloaded.snapshot.settingsBytes.starts(with: prefix.utf8))
        XCTAssertTrue(String(decoding: reloaded.snapshot.settingsBytes, as: UTF8.self).hasSuffix(suffix))
        draft.showDetails = false
        guard case .saved(let reset) = await repo.saveCalendarOptions(draft, expected: saved.revision) else {
            return XCTFail("Expected Show Details to clear")
        }
        XCTAssertFalse(reset.snapshot.settings.calendarOptions.showDetails)
        XCTAssertFalse(String(decoding: reset.snapshot.settingsBytes, as: UTF8.self).contains("showDetails"))
        XCTAssertTrue(reset.snapshot.settingsBytes.starts(with: prefix.utf8))
        XCTAssertTrue(String(decoding: reset.snapshot.settingsBytes, as: UTF8.self).hasSuffix(suffix))
        XCTAssertEqual(try Data(contentsOf: files.workspace), start.snapshot.workspaceBytes)
    }
}
