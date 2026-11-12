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
