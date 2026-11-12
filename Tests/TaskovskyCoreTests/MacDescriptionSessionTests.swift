import XCTest
@testable import TaskovskyCore
import TaskovskyWorkspace

final class MacDescriptionSessionTests: XCTestCase {
    @MainActor func testWorkspaceFailureKeepsRecoveryAndRetryAcknowledges() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Owned", body: "saved")
        let bytes = try JSONEncoder().encode(WorkspaceData(tasks:[task])); try bytes.write(to:file)
        let store = TaskStore(fileURL:file,seed:false), session = MacDescriptionSession(store:store)
        await session.prepare(taskID:task.id)
        try FileManager.default.removeItem(at:file); try FileManager.default.createDirectory(at:file,withIntermediateDirectories:false)
        let edited = DescriptionSnapshot(body:"unsaved",rich:nil)!
        XCTAssertNotNil(session.propose(taskID:task.id,content:edited,expectedRevision:0,editorID:UUID()))
        await session.finishPending()
        XCTAssertEqual(store.data.tasks[0].body,"saved")
        XCTAssertEqual(session.presentation(for:task)?.content,edited)
        XCTAssertFalse(session.hasUnsafeMemory)
        let reopened = MacDescriptionSession(store:store); await reopened.prepare(taskID:task.id)
        XCTAssertEqual(reopened.recoveryContent(taskID:task.id),edited)
        XCTAssertEqual(reopened.presentation(for:task)?.recovery,.retryEligible)
        try FileManager.default.removeItem(at:file); try bytes.write(to:file)
        session.retry(taskID:task.id); await session.finishPending()
        XCTAssertEqual(store.data.tasks[0].body,"unsaved")
        XCTAssertFalse(session.hasAttention)
        let location = try MacDescriptionRecoveryDirectory(workspaceURL:file)
        XCTAssertTrue(try location.savedTaskIDs().isEmpty)
    }
    @MainActor func testStaleEditorRetainsCopyableCandidateAndCurrentSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title:"Owned",body:"saved")
        try JSONEncoder().encode(WorkspaceData(tasks:[task])).write(to:file)
        let store = TaskStore(fileURL:file,seed:false), session = MacDescriptionSession(store:store)
        await session.prepare(taskID:task.id)
        XCTAssertEqual(session.propose(taskID:task.id,content:DescriptionSnapshot(body:"first",rich:nil)!,expectedRevision:0,editorID:UUID()),1)
        let sibling = UUID(), candidate = DescriptionSnapshot(body:"sibling",rich:nil)!
        XCTAssertNil(session.propose(taskID:task.id,content:candidate,expectedRevision:0,editorID:sibling))
        await session.finishPending()
        XCTAssertEqual(store.data.tasks[0].body,"first")
        XCTAssertEqual(session.conflict(taskID:task.id,editorID:sibling),candidate)
        XCTAssertTrue(session.hasUnsafeMemory)
        session.discardConflict(taskID:task.id,editorID:sibling)
        XCTAssertFalse(session.hasUnsafeMemory)
    }
    @MainActor func testKeepSavedRefreshesCurrentBaselineAfterRecoveryReview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Owned", body: "A")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: file)
        let location = try MacDescriptionRecoveryDirectory(workspaceURL: file); try location.prepare()
        var record = MacDescriptionDraft(workspaceID: location.workspaceID, taskID: task.id, baseline: DescriptionSnapshot(body: "A", rich: nil)!)
        record.replace(with: DescriptionSnapshot(body: "recovered", rich: nil)!)
        let result = await (try location.journal(taskID: task.id)).save(record); XCTAssertEqual(result, .saved)
        let store = TaskStore(fileURL: file, seed: false), session = MacDescriptionSession(store: store)
        await session.prepare(taskID: task.id)
        var changed = task; changed.body = "B"; store.updateTask(changed)
        await session.keepSaved(taskID: task.id)
        let view = try XCTUnwrap(session.presentation(for: changed))
        XCTAssertEqual(view.content.body, "B"); XCTAssertTrue(view.editable)
        XCTAssertNotNil(session.propose(taskID: task.id, content: DescriptionSnapshot(body: "C", rich: nil)!, expectedRevision: view.revision, editorID: UUID()))
        await session.finishPending()
        XCTAssertEqual(store.data.tasks[0].body, "C")
    }

}

private actor ControlledDescriptionJournal: MacDescriptionJournalAccess {
    var record: MacDescriptionDraft?
    var saved: [MacDescriptionDraft] = []
    var closes: [MacDescriptionDraft] = []
    var holdSave: Bool
    var holdClose: Bool
    var failClose: Bool
    var saveWaiter: CheckedContinuation<Void, Never>?
    var closeWaiter: CheckedContinuation<Void, Never>?
    init(holdSave: Bool = false, holdClose: Bool = false, failClose: Bool = false) {
        self.holdSave = holdSave; self.holdClose = holdClose; self.failClose = failClose
    }
    func load() -> LocalDraftLoad<MacDescriptionDraft> { record.map { .available($0) } ?? .none }
    func save(_ value: MacDescriptionDraft) async -> FieldDraftWrite {
        saved.append(value)
        if holdSave { holdSave = false; await withCheckedContinuation { saveWaiter = $0 } }
        record = value; return .saved
    }
    func close(_ value: MacDescriptionDraft) async -> FieldDraftWrite {
        closes.append(value)
        if holdClose { holdClose = false; await withCheckedContinuation { closeWaiter = $0 } }
        if failClose { return .failed }
        guard record == value else { return .refused }
        record = nil; return .saved
    }
    func abandon(_ value: MacDescriptionDraft) async -> FieldDraftWrite { await close(value) }
    func blockedSave() -> Bool { saveWaiter != nil }
    func blockedClose() -> Bool { closeWaiter != nil }
    func releaseSave() { saveWaiter?.resume(); saveWaiter = nil }
    func releaseClose() { closeWaiter?.resume(); closeWaiter = nil }
    func allowClose() { failClose = false }
}

extension MacDescriptionSessionTests {
    @MainActor private func waitFor(_ condition: () async -> Bool) async throws {
        for _ in 0..<1000 { if await condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
        throw CocoaError(.fileReadUnknown)
    }
    @MainActor func testOlderJournalAcknowledgementCannotSaveNewerTyping() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Owned", body: "saved")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: file)
        let journal = ControlledDescriptionJournal(holdSave: true)
        let store = TaskStore(fileURL: file, seed: false), session = MacDescriptionSession(store: store, makeJournal: { _, _ in journal })
        await session.prepare(taskID: task.id)
        let editor = UUID()
        XCTAssertEqual(session.propose(taskID: task.id, content: DescriptionSnapshot(body: "first", rich: nil)!, expectedRevision: 0, editorID: editor), 1)
        try await waitFor { await journal.blockedSave() }
        XCTAssertEqual(session.propose(taskID: task.id, content: DescriptionSnapshot(body: "latest", rich: nil)!, expectedRevision: 1, editorID: editor), 2)
        XCTAssertTrue(session.hasUnsafeMemory); XCTAssertEqual(store.data.tasks[0].body, "saved")
        await journal.releaseSave(); await session.finishPending()
        let writes = await journal.saved
        XCTAssertEqual(writes.map(\.content.body), ["first", "latest"])
        XCTAssertEqual(writes[0].id, writes[1].id)
        let closes = await journal.closes
        XCTAssertEqual(closes.map(\.content.body), ["latest"])
        XCTAssertEqual(store.data.tasks[0].body, "latest"); XCTAssertFalse(session.hasUnsafeMemory)
    }
    @MainActor func testTypingDuringFailedCleanupRotatesAndRemainsMemoryOnlyUntilRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Owned", body: "saved")
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: file)
        let journal = ControlledDescriptionJournal(holdClose: true, failClose: true)
        let store = TaskStore(fileURL: file, seed: false), session = MacDescriptionSession(store: store, makeJournal: { _, _ in journal })
        await session.prepare(taskID: task.id)
        let editor = UUID()
        _ = session.propose(taskID: task.id, content: DescriptionSnapshot(body: "first", rich: nil)!, expectedRevision: 0, editorID: editor)
        try await waitFor { await journal.blockedClose() }
        XCTAssertEqual(store.data.tasks[0].body, "first")
        _ = session.propose(taskID: task.id, content: DescriptionSnapshot(body: "latest", rich: nil)!, expectedRevision: 1, editorID: editor)
        await journal.releaseClose(); await session.finishPending()
        XCTAssertTrue(session.hasUnsafeMemory); XCTAssertEqual(store.data.tasks[0].body, "first")
        let before = await journal.saved; XCTAssertEqual(before.count, 1)
        await journal.allowClose(); session.retry(taskID: task.id); await session.finishPending()
        let after = await journal.saved
        XCTAssertEqual(after.map(\.content.body), ["first", "latest"])
        XCTAssertNotEqual(after[0].id, after[1].id)
        XCTAssertEqual(after[1].baseline.body, "first")
        XCTAssertEqual(store.data.tasks[0].body, "latest"); XCTAssertFalse(session.hasUnsafeMemory)
    }
    @MainActor func testDiscoveryKeepsRemovedTaskRecoveryCopyable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), id = UUID()
        try JSONEncoder().encode(WorkspaceData(tasks: [])).write(to: file)
        let location = try MacDescriptionRecoveryDirectory(workspaceURL: file); try location.prepare()
        var draft = MacDescriptionDraft(workspaceID: location.workspaceID, taskID: id, baseline: DescriptionSnapshot(body: "saved", rich: nil)!)
        draft.replace(with: DescriptionSnapshot(body: "orphan", rich: nil)!)
        let saved = await (try location.journal(taskID: id)).save(draft); XCTAssertEqual(saved, .saved)
        let session = MacDescriptionSession(store: TaskStore(fileURL: file, seed: false))
        await session.discoverRecovery()
        XCTAssertEqual(session.recoveryContent(taskID: id)?.body, "orphan")
        XCTAssertEqual(session.presentation(taskID: id)?.recovery, .unavailable)
        XCTAssertEqual(session.presentation(taskID: id)?.editable, false)
        XCTAssertTrue(session.hasAttention)
    }
}

extension MacDescriptionSessionTests {
    @MainActor func testDiscardRequiresReviewedRevisionAndKeepsTypingDuringCleanup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json"), task = TaskItem(title: "Owned", body: "saved")
        let bytes = try JSONEncoder().encode(WorkspaceData(tasks: [task])); try bytes.write(to: file)
        let journal = ControlledDescriptionJournal(holdClose: true)
        let store = TaskStore(fileURL: file, seed: false), session = MacDescriptionSession(store: store, makeJournal: { _, _ in journal })
        await session.prepare(taskID: task.id)
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        let draft = DescriptionSnapshot(body: "draft", rich: nil)!, editor = UUID()
        _ = session.propose(taskID: task.id, content: draft, expectedRevision: 0, editorID: editor)
        await session.finishPending()
        await session.discardCurrent(taskID: task.id, expectedContent: draft, expectedRevision: 0)
        XCTAssertEqual(session.presentation(for: task)?.content, draft)
        let discard = Task { await session.discardCurrent(taskID: task.id, expectedContent: draft, expectedRevision: 1) }
        try await waitFor { await journal.blockedClose() }
        var flushed = false
        let flush = Task { await session.finishPending(); flushed = true }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertFalse(flushed)
        let beforeDiscardAcknowledgement = await journal.saved
        XCTAssertEqual(beforeDiscardAcknowledgement.count, 1)
        let newer = DescriptionSnapshot(body: "newer", rich: nil)!
        XCTAssertNil(session.propose(taskID: task.id, content: newer, expectedRevision: 1, editorID: editor))
        await journal.releaseClose(); await discard.value; await flush.value
        XCTAssertEqual(session.presentation(for: task)?.content.body, "saved")
        XCTAssertEqual(session.conflict(taskID: task.id, editorID: editor), newer)
        XCTAssertTrue(session.hasUnsafeMemory)
        XCTAssertEqual(store.data.tasks[0].body, "saved")
    }
}


extension MacDescriptionSessionTests {
    @MainActor func testMissingNodeConflictDoesNotLeaveQuitWaitingForNonexistentLoad() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("workspace.json")
        try JSONEncoder().encode(WorkspaceData(tasks: [])).write(to: file)
        let session = MacDescriptionSession(store: TaskStore(fileURL: file, seed: false)), id = UUID(), editor = UUID()
        let text = DescriptionSnapshot(body: "retained", rich: nil)!
        session.retainUncommitted(taskID: id, editorID: editor, content: text)
        let finished = expectation(description: "Quit persistence barrier finishes")
        Task { await session.finishPending(); finished.fulfill() }
        await fulfillment(of: [finished], timeout: 1)
        XCTAssertTrue(session.hasUnsafeMemory)
        XCTAssertEqual(session.conflict(taskID: id, editorID: editor), text)
        XCTAssertEqual(session.presentation(taskID: id)?.editable, false)
    }
}
