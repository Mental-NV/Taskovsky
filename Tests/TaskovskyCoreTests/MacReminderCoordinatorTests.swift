import XCTest
@testable import TaskovskyCore

@MainActor final class FakeReminderCenter: MacReminderCenter {
    var status = MacReminderAuthorization.notDetermined
    var grant = true
    var requests: [MacReminderNotification] = []
    var prompts = 0
    var accesses = 0
    var presentation = false
    var pendingHook: (() -> Void)?
    func setPresentationEnabled(_ enabled: Bool) { presentation = enabled }
    var additions = 0
    var removals = 0
    var failPending = false
    var failAuthorization = false
    var failRequest = false
    var failRemoval = false
    var failAdd = false
    var failAtAddition: Int?
    var suspendedAdd: CheckedContinuation<Void, Never>?
    var suspendAdd = false
    func authorization() async throws -> MacReminderAuthorization {
        accesses += 1
        if failAuthorization { throw CocoaError(.fileReadUnknown) }; return status
    }
    func requestAuthorization() async throws -> Bool {
        prompts += 1; if failRequest { throw CocoaError(.fileReadUnknown) }
        status = grant ? .authorized : .denied; return grant
    }
    func pending() async throws -> [MacReminderNotification] {
        accesses += 1; pendingHook?()
        if failPending { throw CocoaError(.fileReadUnknown) }; return requests
    }
    func remove(identifiers: [String]) async throws {
        if failRemoval { throw CocoaError(.fileWriteUnknown) }
        removals += identifiers.count; requests.removeAll { identifiers.contains($0.identifier) }
    }
    func add(_ request: MacReminderNotification) async throws {
        if suspendAdd { await withCheckedContinuation { suspendedAdd = $0 } }
        if failAdd || failAtAddition == additions + 1 { throw CocoaError(.fileWriteUnknown) }
        additions += 1; requests.removeAll { $0.identifier == request.identifier }; requests.append(request)
    }
}

final class MacReminderCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func fixture() throws -> (URL, URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = root.appendingPathComponent("workspace.json"), settings = root.appendingPathComponent("settings.json")
        var task = TaskItem(title: "Private title")
        task.reminderDates = [now.addingTimeInterval(100.125)]
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: workspace)
        try JSONEncoder().encode(AppSettings()).write(to: settings)
        return (root, workspace, settings)
    }
    @MainActor func testDefaultOffExplicitEnableExactRoundtripAndDisable() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter()
        let sut = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        let off = await sut.refresh(now: now); XCTAssertEqual(off, .disabled); XCTAssertEqual(center.prompts, 0)
        let enabled = await sut.enable(now: now); XCTAssertEqual(enabled, .ready(pending: 1, deferred: 0))
        XCTAssertEqual(center.prompts, 1); XCTAssertEqual(center.additions, 1)
        XCTAssertEqual(center.requests.first?.body, "A task reminder is due.")
        let refreshed = await sut.refresh(now: now); XCTAssertEqual(refreshed, enabled); XCTAssertEqual(center.additions, 1)
        let disabled = await sut.disable(); XCTAssertEqual(disabled, .disabled); XCTAssertTrue(center.requests.isEmpty)
        _ = await sut.refresh(now: now); XCTAssertTrue(center.requests.isEmpty); XCTAssertEqual(center.prompts, 1)
    }
    @MainActor func testDeniedAndFailedAddRetryWithoutPrompt() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter(); center.grant = false
        let sut = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        let denied = await sut.enable(now: now); XCTAssertEqual(denied, .denied)
        _ = await sut.refresh(now: now); XCTAssertEqual(center.prompts, 1); XCTAssertTrue(center.requests.isEmpty)
        center.status = .authorized; center.failAdd = true
        let failed = await sut.enable(now: now); XCTAssertEqual(failed, .failed(stage: .addition, added: 0, removalsSubmitted: 0))
        center.failAdd = false
        let retry = await sut.refresh(now: now); XCTAssertEqual(retry, .ready(pending: 1, deferred: 0)); XCTAssertEqual(center.prompts, 1)
        center.failPending = true
        let disable = await sut.disable(); XCTAssertEqual(disable, .failed(stage: .pending, added: 0, removalsSubmitted: 0))
        center.failPending = false
        let off = await sut.refresh(now: now); XCTAssertEqual(off, .disabled); XCTAssertEqual(center.requests.count, 1)
        _ = await sut.disable(); XCTAssertTrue(center.requests.isEmpty)
    }
    @MainActor func testUnreadableUnknownDuplicateAndJournalKeepPendingWhileValidEmptyClears() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let original = try Data(contentsOf: workspace)
        let center = FakeReminderCenter(); center.status = .authorized
        let sut = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        _ = await sut.enable(now: now)
        let savedRequests = center.requests
        for bad in [Data("{\"tasks\":[],\"unknown\":true}".utf8), Data("{\"tasks\":[],\"tasks\":[]}".utf8), Data("bad".utf8)] {
            try bad.write(to: workspace)
            let result = await sut.refresh(now: now); XCTAssertEqual(result, .failed(stage: .snapshot, added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.requests, savedRequests)
            XCTAssertEqual(try Data(contentsOf: workspace), bad)
        }
        try original.write(to: workspace)
        let journal = workspace.appendingPathExtension("tag-transaction")
        try Data("do not recover".utf8).write(to: journal)
        let journalResult = await sut.refresh(now: now); XCTAssertEqual(journalResult, .failed(stage: .snapshot, added: 0, removalsSubmitted: 0))
        XCTAssertEqual(try String(contentsOf: journal), "do not recover"); XCTAssertEqual(center.requests, savedRequests)
        try FileManager.default.removeItem(at: journal)
        try FileManager.default.removeItem(at: workspace)
        let missing = await sut.refresh(now: now); XCTAssertEqual(missing, .failed(stage: .snapshot, added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.requests, savedRequests)
        try JSONEncoder().encode(WorkspaceData()).write(to: workspace)
        let empty = await sut.refresh(now: now); XCTAssertEqual(empty, .ready(pending: 0, deferred: 0)); XCTAssertTrue(center.requests.isEmpty)
    }
    @MainActor func testWorkspaceAndAppIsolationAndMalformedMetadataPreserved() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter(); center.status = .authorized
        let first = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        let other = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "Production", center: center)
        _ = await first.enable(now: now); let qa = center.requests
        _ = await other.enable(now: now); XCTAssertEqual(center.requests.count, 2)
        _ = await first.disable(); XCTAssertEqual(center.requests.count, 1); XCTAssertNotEqual(center.requests, qa)
        _ = await first.enable(now: now)
        let valid = try XCTUnwrap(center.requests.first { $0.identifier == qa[0].identifier })
        let malformed = MacReminderNotification(identifier: valid.identifier, title: valid.title, body: valid.body, metadata: [:])
        center.requests = [malformed]
        let collision = await first.refresh(now: now); XCTAssertEqual(collision, .failed(stage: .ownership, added: 0, removalsSubmitted: 0)); XCTAssertEqual(center.requests, [malformed])
        _ = await first.disable(); XCTAssertEqual(center.requests, [malformed])
    }
    @MainActor func testAuthorizationClockAndRemovalErrorsPreserveRequests() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter()
        let sut = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        center.failRequest = true
        let requestFailure = await sut.enable(now: now)
        XCTAssertEqual(requestFailure, .failed(stage: .authorization, added: 0, removalsSubmitted: 0))
        center.failRequest = false; _ = await sut.enable(now: now)
        let pending = center.requests
        center.failAuthorization = true
        let authorizationFailure = await sut.refresh(now: now)
        XCTAssertEqual(authorizationFailure, .failed(stage: .authorization, added: 0, removalsSubmitted: 0))
        center.failAuthorization = false
        let invalidClock = await sut.refresh(now: Date(timeIntervalSinceReferenceDate: .nan))
        XCTAssertEqual(invalidClock, .failed(stage: .clock, added: 0, removalsSubmitted: 0))
        center.status = .denied
        let revoked = await sut.refresh(now: now); XCTAssertEqual(revoked, .denied)
        XCTAssertEqual(center.requests, pending); XCTAssertEqual(center.prompts, 2)
        center.failRemoval = true
        let disableFailure = await sut.disable()
        XCTAssertEqual(disableFailure, .failed(stage: .removal, added: 0, removalsSubmitted: 0))
        center.failRemoval = false; _ = await sut.disable(); XCTAssertTrue(center.requests.isEmpty)
    }
    @MainActor func testPartialBatchReceiptAndRetryAndPathIsolation() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter(); center.status = .authorized
        let sut = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        _ = await sut.enable(now: now)
        var task = TaskItem(title: "Replacement")
        task.reminderDates = [now.addingTimeInterval(200), now.addingTimeInterval(300)]
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: workspace)
        center.failAtAddition = 3
        let failed = await sut.refresh(now: now)
        XCTAssertEqual(failed, .failed(stage: .addition, added: 1, removalsSubmitted: 1))
        XCTAssertEqual(center.requests.count, 1)
        center.failAtAddition = nil
        let retry = await sut.refresh(now: now)
        XCTAssertEqual(retry, .ready(pending: 2, deferred: 0)); XCTAssertEqual(center.additions, 3)
        let settings2 = root.appendingPathComponent("other-settings.json")
        try Data(contentsOf: settings).write(to: settings2)
        let another = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings2, appScope: "QA", center: center)
        _ = await another.enable(now: now); XCTAssertEqual(center.requests.count, 4)
        let workspace2 = root.appendingPathComponent("other-workspace.json")
        try Data(contentsOf: workspace).write(to: workspace2)
        let third = MacReminderCoordinator(workspaceURL: workspace2, settingsURL: settings2, appScope: "QA", center: center)
        _ = await third.enable(now: now); XCTAssertEqual(center.requests.count, 6)
        _ = await sut.disable(); XCTAssertEqual(center.requests.count, 4)
        _ = await another.disable(); XCTAssertEqual(center.requests.count, 2)
        _ = await third.disable(); XCTAssertTrue(center.requests.isEmpty)
    }
    @MainActor func testDisableQueuesBehindSuspendedAddAndQueueSurvivesCancellation() async throws {
        let (root, workspace, settings) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter(); center.status = .authorized; center.suspendAdd = true
        let sut = MacReminderCoordinator(workspaceURL: workspace, settingsURL: settings, appScope: "QA", center: center)
        let enable = Task { await sut.enable(now: now) }
        for _ in 0..<1000 { if center.suspendedAdd != nil { break }; await Task.yield() }
        let continuation = try XCTUnwrap(center.suspendedAdd)
        let disable = Task { await sut.disable() }; disable.cancel()
        await Task.yield(); XCTAssertEqual(center.removals, 0)
        center.suspendAdd = false; continuation.resume()
        _ = await enable.value
        let result = await disable.value; XCTAssertEqual(result, .disabled); XCTAssertTrue(center.requests.isEmpty)
        let off = await sut.refresh(now: now); XCTAssertEqual(off, .disabled)
    }
}
