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
        guard case .saved(let saved) = await repo.apply(edit, expected: original.revision) else {
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
