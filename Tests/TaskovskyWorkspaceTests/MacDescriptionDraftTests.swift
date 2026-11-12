import XCTest
@testable import TaskovskyWorkspace
import TaskovskyDomain

final class MacDescriptionDraftTests: XCTestCase {
    private func snapshot(_ text: String) -> DescriptionSnapshot { DescriptionSnapshot(body: text, rich: nil)! }
    func testExactUnicodeAndPairedRichValidation() throws {
        XCTAssertNotEqual(snapshot("é"), snapshot("e\u{301}"))
        XCTAssertNil(DescriptionSnapshot(body: "other", rich: RichBody(text: "text")))
        let plain = snapshot("text"), styled = DescriptionSnapshot(body: "text", rich: RichBody(text: "text", runs: [RichInlineRun(location: 0, length: 4, bold: true)]))!
        XCTAssertNotEqual(plain, styled)
        var draft = MacDescriptionDraft(workspaceID: UUID(), taskID: UUID(), baseline: plain)
        XCTAssertTrue(draft.replace(with: styled)); XCTAssertEqual(draft.sequence, 1)
        XCTAssertTrue(draft.replace(with: styled)); XCTAssertEqual(draft.sequence, 1)
    }
    func testRecoveryDoesNotOverwriteUnrelatedOrConflictingChanges() throws {
        let owner = UUID(); var task = TaskItem(title: "Original", body: "old")
        var draft = MacDescriptionDraft(workspaceID: owner, taskID: task.id, baseline: snapshot("old")); draft.replace(with: snapshot("new"))
        task.title = "Concurrent title"; task.dueDate = Date()
        var workspace = WorkspaceData(tasks: [task])
        XCTAssertEqual(draft.recovery(in: workspace, workspaceID: owner), .retryEligible)
        workspace.tasks[0].body = "new"; XCTAssertEqual(draft.recovery(in: workspace, workspaceID: owner), .alreadySaved)
        workspace.tasks[0].body = "external"; XCTAssertEqual(draft.recovery(in: workspace, workspaceID: owner), .conflict)
        workspace.tasks[0].deletedAt = Date(); XCTAssertEqual(draft.recovery(in: workspace, workspaceID: owner), .unavailable)
        XCTAssertEqual(draft.recovery(in: workspace, workspaceID: UUID()), .unavailable)
    }
    func testJournalReopenSequenceOwnershipAndExactClose() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("draft.json"), owner = UUID(), task = UUID()
        var draft = MacDescriptionDraft(workspaceID: owner, taskID: task, baseline: snapshot("old")); draft.replace(with: snapshot("new"))
        let journal = MacDescriptionJournal(fileURL: file, workspaceID: owner, taskID: task)
        let saved = await journal.save(draft); XCTAssertEqual(saved, .saved)
        let earlier = draft; draft.replace(with: snapshot("newer"))
        let second = await journal.save(draft); XCTAssertEqual(second, .saved)
        let stale = await journal.save(earlier); XCTAssertEqual(stale, .refused)
        let closeStale = await journal.close(earlier); XCTAssertEqual(closeStale, .refused)
        let reopened = MacDescriptionJournal(fileURL: file, workspaceID: owner, taskID: task)
        guard case .available(let loaded) = await reopened.load() else { return XCTFail("Recovery missing") }; XCTAssertEqual(loaded, draft)
        let foreign = MacDescriptionJournal(fileURL: file, workspaceID: UUID(), taskID: task)
        guard case .unavailable = await foreign.load() else { return XCTFail("Foreign recovery exposed") }
        let closed = await reopened.close(draft); XCTAssertEqual(closed, .saved)
        let late = await reopened.save(draft); XCTAssertEqual(late, .refused)
        draft.replace(with: snapshot("late newer")); let lateNewer = await reopened.save(draft); XCTAssertEqual(lateNewer, .refused)
    }
    func testWriteFailureAfterCommitAndUnknownFilePreservation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("draft.json"), owner = UUID(), task = UUID()
        var draft = MacDescriptionDraft(workspaceID: owner, taskID: task, baseline: snapshot("old")); draft.replace(with: snapshot("new"))
        let failed = MacDescriptionJournal(fileURL: file, workspaceID: owner, taskID: task, write: { _,_ in throw CocoaError(.fileWriteUnknown) })
        let failure = await failed.save(draft); XCTAssertEqual(failure, .failed); XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let after = MacDescriptionJournal(fileURL: file, workspaceID: owner, taskID: task, write: { bytes,url in try bytes.write(to:url,options:.atomic); throw CocoaError(.fileWriteUnknown) }, remove: { url in try FileManager.default.removeItem(at:url); throw CocoaError(.fileWriteUnknown) })
        let accepted = await after.save(draft); XCTAssertEqual(accepted, .saved)
        let closed = await after.close(draft); XCTAssertEqual(closed, .saved)
        let unknown = Data("{\"version\":99,\"future\":true}".utf8); try unknown.write(to:file)
        let fresh = MacDescriptionJournal(fileURL:file,workspaceID:owner,taskID:task)
        let refused = await fresh.save(draft); XCTAssertEqual(refused,.refused); XCTAssertEqual(try Data(contentsOf:file),unknown)
    }
    func testFailedNewerWritePreventsStaleCleanupAndFailedRemovalIsRetryable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("draft.json"), owner = UUID(), task = UUID()
        var draft = MacDescriptionDraft(workspaceID: owner, taskID: task, baseline: snapshot("old")); draft.replace(with: snapshot("first"))
        try JSONEncoder().encode(draft).write(to: file)
        let bytes = try Data(contentsOf: file)
        let flag = root.appendingPathComponent("blocked"); try Data().write(to:flag)
        let blocked = MacDescriptionJournal(fileURL: file, workspaceID: owner, taskID: task, write: { bytes,url in
            if FileManager.default.fileExists(atPath:flag.path) { throw CocoaError(.fileWriteUnknown) }
            try bytes.write(to:url,options:.atomic)
        })
        _ = await blocked.load()
        let earlier = draft; draft.replace(with: snapshot("second"))
        let failed = await blocked.save(draft); XCTAssertEqual(failed, .failed)
        let stale = await blocked.close(earlier); XCTAssertEqual(stale, .refused); XCTAssertEqual(try Data(contentsOf:file), bytes)
        try FileManager.default.removeItem(at:flag)
        let retried = await blocked.save(draft); XCTAssertEqual(retried,.saved)
        try bytes.write(to:file)
        try Data().write(to:flag)
        let failedCleanup = MacDescriptionJournal(fileURL:file,workspaceID:owner,taskID:task,remove:{ url in
            if FileManager.default.fileExists(atPath:flag.path) { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.removeItem(at:url)
        })
        let cleanup = await failedCleanup.close(earlier); XCTAssertEqual(cleanup,.failed); XCTAssertEqual(try Data(contentsOf:file),bytes)
        _ = await failedCleanup.load()
        try FileManager.default.removeItem(at:flag)
        let closed = await failedCleanup.close(earlier); XCTAssertEqual(closed,.saved)
    }

}
