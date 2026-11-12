import XCTest
import TaskovskyDomain
@testable import TaskovskyWorkspace

@MainActor final class PhoneReminderCoordinatorTests: XCTestCase {
    @MainActor private final class FakeCenter: PhoneReminderCenter {
        var auth = PhoneReminderAuthorization.authorized
        var grants = true, throwsAuthorization = false, throwsRemove = false
        var requests = 0, calls = 0, addAttempts = 0, failAddAt: Int?
        var items: [PhoneReminderNotification] = []
        var onPending: (() throws -> Void)?
        var onPrompt: (() throws -> Void)?
        var onAdd: (() -> Void)?
        var holdFirstAdd = false
        var gate: CheckedContinuation<Void, Never>?
        var events: [String] = []
        func authorization() async throws -> PhoneReminderAuthorization {
            calls += 1
            if throwsAuthorization { throw CocoaError(.fileReadUnknown) }
            return auth
        }
        func requestAuthorization() async throws -> Bool {
            calls += 1; requests += 1; try onPrompt?()
            if grants { auth = .authorized }; return grants
        }
        func pending() async throws -> [PhoneReminderNotification] { calls += 1; try onPending?(); return items }
        func remove(identifiers: [String]) async throws {
            calls += 1
            if throwsRemove { throw CocoaError(.fileWriteUnknown) }
            items.removeAll { identifiers.contains($0.identifier) }; events.append("remove")
        }
        func add(_ request: PhoneReminderNotification) async throws {
            calls += 1; addAttempts += 1
            if failAddAt == addAttempts { throw CocoaError(.fileWriteUnknown) }
            if holdFirstAdd && addAttempts == 1 { await withCheckedContinuation { gate = $0 } }
            items.removeAll { $0.identifier == request.identifier }; items.append(request); events.append("add"); onAdd?()
        }
    }
    private final class FailureSwitch: @unchecked Sendable {
        private let lock = NSLock(); private var value = false
        func set(_ value: Bool) { lock.lock(); self.value = value; lock.unlock() }
        func write(_ data: Data, _ url: URL) throws {
            lock.lock(); let fail = value; lock.unlock()
            if fail { throw CocoaError(.fileWriteNoPermission) }
            try data.write(to: url, options: .atomic)
        }
    }
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func fixture(count: Int = 1) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var tasks: [TaskItem] = []
        for index in 0..<count {
            var task = TaskItem(title: "Private owned title must not be sent")
            task.reminderDates = [now.addingTimeInterval(Double(60 + index * 60))]; tasks.append(task)
        }
        try JSONEncoder().encode(WorkspaceData(tasks: tasks)).write(to: root.appendingPathComponent("workspace.json"))
        try JSONEncoder().encode(AppSettings()).write(to: root.appendingPathComponent("settings.json"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }; return root
    }
    private func subject(_ root: URL, _ center: FakeCenter) -> PhoneReminderCoordinator {
        PhoneReminderCoordinator(directory: root, appScope: "owned.test", center: center, clock: { self.now })
    }
    func testMissingPreferencesRefreshAndDisableHaveNoCenterEffects() async throws {
        let root = try fixture(), center = FakeCenter(), subject = subject(root, center)
        let first = await subject.refresh(), second = await subject.disable()
        XCTAssertEqual(first, .disabled); XCTAssertEqual(second, .disabled); XCTAssertEqual(center.calls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("local-notifications.json").path))
    }
    func testExplicitEnablePersistsBeforePromptAndRestartNeverPrompts() async throws {
        let root = try fixture(), center = FakeCenter(); center.auth = .notDetermined
        center.onPrompt = {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("local-notifications.json"))) as? [String: Any]
            XCTAssertEqual(object?["enabled"] as? Bool, true)
        }
        let first = await subject(root, center).enable()
        XCTAssertEqual(first, .ready(plannedPending: 1, deferred: 0)); XCTAssertEqual(center.requests, 1)
        let saved = try await PhoneReminderPreferences(directory: root, appScope: "owned.test").load()
        XCTAssertEqual(saved?.enabled, true)
        XCTAssertEqual(center.items.first?.title, "Taskovsky reminder")
        XCTAssertEqual(center.items.first?.body, "A task reminder is due.")
        center.auth = .notDetermined
        let restored = await subject(root, center).refresh()
        XCTAssertEqual(restored, .denied); XCTAssertEqual(center.requests, 1)
        XCTAssertEqual(center.items.count, 1)
    }
    func testDeniedAndAuthorizationErrorKeepDurableIntentWithoutAdditions() async throws {
        let root = try fixture(), center = FakeCenter(); center.auth = .notDetermined; center.grants = false
        let subject = subject(root, center)
        let denied = await subject.enable(); XCTAssertEqual(denied, .denied); XCTAssertEqual(center.requests, 1)
        center.throwsAuthorization = true
        let failed = await subject.refresh()
        XCTAssertEqual(failed, .failed(stages: [.authorization], added: 0, removalsSubmitted: 0))
        XCTAssertTrue(center.items.isEmpty)
        let saved = try await PhoneReminderPreferences(directory: root, appScope: "owned.test").load()
        XCTAssertEqual(saved?.enabled, true)
    }
    func testPreferenceWriteFailureHasNoCenterEffectAndDisableLatchesOff() async throws {
        let root = try fixture(), center = FakeCenter(), failure = FailureSwitch(); failure.set(true)
        let subject = PhoneReminderCoordinator(directory: root, appScope: "owned.test", center: center,
            clock: { self.now }, preferenceWrite: { try failure.write($0, $1) })
        let failed = await subject.enable()
        XCTAssertEqual(failed, .failed(stages: [.preferenceWrite], added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.calls, 0)
        failure.set(false); _ = await subject.enable(); XCTAssertEqual(center.items.count, 1)
        failure.set(true); center.throwsRemove = true
        let disabled = await subject.disable()
        XCTAssertEqual(disabled, .failed(stages: [.preferenceWrite, .removal], added: 0, removalsSubmitted: 0))
        center.throwsRemove = false
        let retried = await subject.refresh()
        XCTAssertEqual(retried, .disabled); XCTAssertTrue(center.items.isEmpty)
        let saved = try await PhoneReminderPreferences(directory: root, appScope: "owned.test").load()
        XCTAssertEqual(saved?.enabled, true) // Not misreported as persisted off.
        let calls = center.addAttempts; _ = await subject.refresh(); XCTAssertEqual(center.addAttempts, calls)
        failure.set(false); _ = await subject.enable(); XCTAssertEqual(center.items.count, 1)
        _ = await subject.disable()
        let afterRestart = await self.subject(root, center).refresh(); XCTAssertEqual(afterRestart, .disabled)
    }
    func testFreshSavedSnapshotAfterPendingWaitAndInvalidSnapshotPreservesPending() async throws {
        let root = try fixture(), center = FakeCenter(), subject = subject(root, center)
        _ = await subject.enable(); let original = center.items
        let workspace = root.appendingPathComponent("workspace.json"), bytes = try Data(contentsOf: workspace)
        center.onPending = { try Data("invalid".utf8).write(to: workspace) }
        let failed = await subject.refresh()
        XCTAssertEqual(failed, .failed(stages: [.snapshot], added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.items, original)
        center.onPending = nil; try bytes.write(to: workspace)
        let journal = workspace.appendingPathExtension("tag-transaction"); try Data("owned journal".utf8).write(to: journal)
        let journalFailed = await subject.refresh()
        XCTAssertEqual(journalFailed, .failed(stages: [.snapshot], added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.items, original)
        try FileManager.default.removeItem(at: journal)
        center.onPending = { try JSONEncoder().encode(WorkspaceData(tasks: [])).write(to: workspace) }
        let result = await subject.refresh()
        XCTAssertEqual(result, .ready(plannedPending: 0, deferred: 0)); XCTAssertTrue(center.items.isEmpty)
    }
    func testForeignAndMalformedRequestsSurviveAndCollisionBlocksBeforeMutation() async throws {
        let root = try fixture(), center = FakeCenter(), subject = subject(root, center)
        _ = await subject.enable(); let owned = try XCTUnwrap(center.items.first)
        let foreign = PhoneReminderNotification(identifier: "foreign", title: "Foreign", body: "", metadata: [:])
        let collision = PhoneReminderNotification(identifier: owned.identifier, title: owned.title, body: owned.body, metadata: [:])
        center.items = [foreign, collision]
        let failed = await subject.refresh()
        XCTAssertEqual(failed, .failed(stages: [.ownership], added: 0, removalsSubmitted: 0))
        _ = await subject.disable(); XCTAssertEqual(center.items, [foreign, collision])
    }
    func testPartialAdditionRetryAndFreshClockAvoidCatchup() async throws {
        let root = try fixture(count: 2), center = FakeCenter(); center.failAddAt = 2
        var time = now
        let subject = PhoneReminderCoordinator(directory: root, appScope: "owned.test", center: center, clock: { time })
        let first = await subject.enable()
        XCTAssertEqual(first, .failed(stages: [.addition], added: 1, removalsSubmitted: 0)); XCTAssertEqual(center.items.count, 1)
        center.failAddAt = nil
        let retried = await subject.refresh()
        XCTAssertEqual(retried, .ready(plannedPending: 2, deferred: 0)); XCTAssertEqual(center.items.count, 2)
        center.onPending = { time = time.addingTimeInterval(1000) }
        let expired = await subject.refresh()
        XCTAssertEqual(expired, .ready(plannedPending: 0, deferred: 0)); XCTAssertTrue(center.items.isEmpty)
    }
    func testQueuedDisableCannotBeOvertakenByDelayedEnable() async throws {
        let root = try fixture(), center = FakeCenter(); center.holdFirstAdd = true
        let subject = subject(root, center)
        let enable = Task { await subject.enable() }
        for _ in 0..<200 where center.gate == nil { try await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertNotNil(center.gate)
        let disable = Task { await subject.disable() }
        await Task.yield(); center.gate?.resume(); center.gate = nil
        _ = await enable.value; let result = await disable.value
        XCTAssertEqual(result, .disabled); XCTAssertEqual(center.events, ["add", "remove"]); XCTAssertTrue(center.items.isEmpty)
    }
    func testCorruptOrReplacedPreferenceNeverSwitchesKnownNamespace() async throws {
        let root = try fixture(), center = FakeCenter(), subject = subject(root, center)
        _ = await subject.enable(); let before = center.items
        let file = root.appendingPathComponent("local-notifications.json")
        let original = try Data(contentsOf: file)
        try Data("bad".utf8).write(to: file)
        let failed = await subject.refresh()
        XCTAssertEqual(failed, .failed(stages: [.preferenceRead], added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.items, before)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object["workspaceID"] = UUID().uuidString
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        let changed = await subject.enable()
        XCTAssertEqual(changed, .failed(stages: [.preferenceRead], added: 0, removalsSubmitted: 0))
        let off = await subject.disable()
        XCTAssertEqual(off, .failed(stages: [.preferenceRead], added: 0, removalsSubmitted: 1)); XCTAssertTrue(center.items.isEmpty)
    }
    func testPersistedFalseRetriesFailedCleanupAfterRestartWithoutPrompt() async throws {
        let root = try fixture(), center = FakeCenter(), subject = subject(root, center)
        _ = await subject.enable(); center.throwsRemove = true
        let failed = await subject.disable()
        XCTAssertEqual(failed, .failed(stages: [.removal], added: 0, removalsSubmitted: 0))
        let record = try await PhoneReminderPreferences(directory: root, appScope: "owned.test").load()
        XCTAssertEqual(record?.enabled, false); XCTAssertEqual(center.items.count, 1)
        center.throwsRemove = false; center.auth = .notDetermined
        let restored = await self.subject(root, center).refresh()
        XCTAssertEqual(restored, .disabled); XCTAssertTrue(center.items.isEmpty); XCTAssertEqual(center.requests, 0)
    }
    func testClockRecheckedBetweenAdditionsAndInvalidClockPreservesPending() async throws {
        let root = try fixture(count: 2), center = FakeCenter()
        var time = now
        let subject = PhoneReminderCoordinator(directory: root, appScope: "owned.test", center: center, clock: { time })
        center.onAdd = { time = time.addingTimeInterval(1000) }
        let result = await subject.enable()
        XCTAssertEqual(result, .ready(plannedPending: 1, deferred: 0)); XCTAssertEqual(center.addAttempts, 1)
        let before = center.items; time = Date(timeIntervalSinceReferenceDate: .nan)
        let invalid = await subject.refresh()
        XCTAssertEqual(invalid, .failed(stages: [.clock], added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.items, before)
    }

}
