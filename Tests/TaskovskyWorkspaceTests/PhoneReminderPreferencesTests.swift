import XCTest
@testable import TaskovskyWorkspace

final class PhoneReminderPreferencesTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func file(_ root: URL) -> URL { root.appendingPathComponent("local-notifications.json") }
    private func store(_ root: URL) -> PhoneReminderPreferences { PhoneReminderPreferences(directory: root, appScope: "owned.test") }

    func testMissingIsOffAndDoesNotWriteOrMintOnReadOrDisable() async throws {
        let root = try directory()
        let subject = PhoneReminderPreferences(directory: root, appScope: "owned.test",
            makeID: { XCTFail("Must not mint"); return UUID() }, write: { _, _ in XCTFail("Must not write") })
        let read = try await subject.load(), disabled = try await subject.setEnabled(false)
        XCTAssertNil(read); XCTAssertNil(disabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(root).path))
    }
    func testConcurrentEnableAndDisablePreserveOneDurableIdentity() async throws {
        let root = try directory(), subject = store(root)
        let records = try await withThrowingTaskGroup(of: PhoneReminderPreference?.self) { group in
            for _ in 0..<20 { group.addTask { try await subject.setEnabled(true) } }
            var result: [PhoneReminderPreference] = []
            for try await value in group { if let value { result.append(value) } }
            return result
        }
        XCTAssertEqual(records.count, 20); XCTAssertEqual(Set(records.map(\.workspaceID)).count, 1)
        let initial = try XCTUnwrap(records.first), before = try Data(contentsOf: file(root))
        _ = try await subject.setEnabled(true)
        XCTAssertEqual(try Data(contentsOf: file(root)), before)
        let offResult = try await subject.setEnabled(false)
        let off = try XCTUnwrap(offResult)
        XCTAssertFalse(off.enabled); XCTAssertEqual(off.workspaceID, initial.workspaceID)
        let reopened = try await store(root).load()
        XCTAssertEqual(reopened, off)
        let again = try await subject.setEnabled(true)
        XCTAssertEqual(again, initial)
    }
    func testRelocationRetainsNamespaceAndIndependentDirectoryDoesNot() async throws {
        let parent = try directory(), first = parent.appendingPathComponent("first"), moved = parent.appendingPathComponent("moved")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: false)
        let originalResult = try await store(first).setEnabled(true)
        let original = try XCTUnwrap(originalResult)
        try FileManager.default.moveItem(at: first, to: moved)
        let relocated = try await store(moved).load()
        XCTAssertEqual(relocated, original)
        XCTAssertEqual(relocated?.requestNamespace, original.requestNamespace)
        let separate = try await store(try directory()).setEnabled(true)
        XCTAssertNotEqual(separate?.requestNamespace, original.requestNamespace)
        XCTAssertFalse(original.requestNamespace.contains(parent.path))
        XCTAssertFalse(original.requestNamespace.contains("owned.test"))
        do { _ = try await PhoneReminderPreferences(directory: moved, appScope: "other.app").load(); XCTFail("Foreign scope") } catch { }
    }
    func testMalformedRecordsArePreservedOnReadEnableAndDisable() async throws {
        let root = try directory(), subject = store(root)
        let id = UUID().uuidString
        let valid = "{\"version\":1,\"workspaceID\":\"\(id)\",\"appScope\":\"owned.test\",\"enabled\":true}"
        let bad = ["not json", "{}", valid.replacingOccurrences(of: "\"version\":1", with: "\"version\":2"),
                   valid.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":true,\"enabled\":false"),
                   valid.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":1"),
                   valid.replacingOccurrences(of: id, with: "invalid"),
                   valid.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"future\":{}"),
                   valid.replacingOccurrences(of: "owned.test", with: "other.app")]
        for text in bad {
            let bytes = Data(text.utf8); try bytes.write(to: file(root))
            do { _ = try await subject.load(); XCTFail("Invalid read accepted") } catch { }
            for enabled in [false, true] {
                do { _ = try await subject.setEnabled(enabled); XCTFail("Invalid write accepted") } catch { }
                XCTAssertEqual(try Data(contentsOf: file(root)), bytes)
            }
        }
    }
    func testFailureBeforeWritePreservesIdentityAndIntentAndRetryUsesDisk() async throws {
        let root = try directory()
        let failed = PhoneReminderPreferences(directory: root, appScope: "owned.test",
            write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        do { _ = try await failed.setEnabled(true); XCTFail("Write failure") } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(root).path))
        let initial = try await store(root).setEnabled(true), before = try Data(contentsOf: file(root))
        do { _ = try await failed.setEnabled(false); XCTFail("Write failure") } catch { }
        XCTAssertEqual(try Data(contentsOf: file(root)), before)
        let stillSaved = try await failed.load()
        XCTAssertEqual(stillSaved, initial)
        let retried = try await store(root).setEnabled(false)
        XCTAssertEqual(retried?.workspaceID, initial?.workspaceID); XCTAssertEqual(retried?.enabled, false)
    }
    func testThrowAfterCommitIsAcknowledgedAndNoOpWriterIsNot() async throws {
        let root = try directory()
        let after = PhoneReminderPreferences(directory: root, appScope: "owned.test", write: { data, url in
            try data.write(to: url, options: .atomic); throw CocoaError(.fileWriteUnknown)
        })
        let saved = try await after.setEnabled(true), reloaded = try await store(root).load()
        XCTAssertEqual(saved, reloaded); XCTAssertEqual(saved?.enabled, true)
        let noop = PhoneReminderPreferences(directory: root, appScope: "owned.test", write: { _, _ in })
        do { _ = try await noop.setEnabled(false); XCTFail("No durable write") } catch { }
        let unchanged = try await noop.load(); XCTAssertEqual(unchanged, saved)
    }
    func testMissingDirectoryAndSymlinkRecordAreRefusedWithoutMutatingTarget() async throws {
        let root = try directory(), missing = root.appendingPathComponent("missing")
        do { _ = try await store(missing).setEnabled(true); XCTFail("Missing directory") } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let target = root.appendingPathComponent("target"), bytes = Data("owned untouched".utf8)
        try bytes.write(to: target)
        try FileManager.default.createSymbolicLink(at: file(root), withDestinationURL: target)
        do { _ = try await store(root).setEnabled(true); XCTFail("Symlink record") } catch { }
        XCTAssertEqual(try Data(contentsOf: target), bytes)
    }
}
