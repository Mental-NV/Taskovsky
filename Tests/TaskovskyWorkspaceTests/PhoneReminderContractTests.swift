import XCTest
import TaskovskyDomain
import TaskovskyWorkspace

/// Architecture probes only: this fake harness is not a shipped phone adapter.
/// No UserNotifications import, authorization, registration or app launch.
final class PhoneReminderContractTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private struct FakeCenter {
        var pending: [LocalReminderRequest] = []
        var updates = 0
        mutating func reconcile(_ plan: LocalReminderPlan) {
            let changes = plan.changes(fromPending: pending)
            pending.removeAll { changes.identifiersToRemove.contains($0.identifier) }
            for request in changes.requestsToAdd {
                pending.removeAll { $0.identifier == request.identifier }; pending.append(request)
            }
            updates += 1
        }
    }
    private func fixture() throws -> (URL, URL, URL, TaskItem) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = root.appendingPathComponent("workspace.json"), settings = root.appendingPathComponent("settings.json")
        var task = TaskItem(title: "Owned phone reminder"); task.reminderDates = [now.addingTimeInterval(60)]
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: workspace)
        try JSONEncoder().encode(AppSettings()).write(to: settings)
        return (root, workspace, settings, task)
    }
    private func refresh(_ repository: WorkspaceFileRepository, center: inout FakeCenter) async throws {
        let saved = try await repository.loadReadOnlyForReminders()
        center.reconcile(LocalReminderPlan(fromPersisted: saved.snapshot.workspace, now: now))
    }
    func testDraftDoesNotAlterPersistedPlanAndAcknowledgedCompletionCancelsIt() async throws {
        let (root, workspace, settings, task) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        let initial = try await repo.load()
        var unsavedDraft = initial.snapshot.workspace
        unsavedDraft.tasks[0].reminderDates = [now.addingTimeInterval(3600)]
        var center = FakeCenter()
        try await refresh(repo, center: &center)
        XCTAssertEqual(center.pending.map(\.fireDate), task.reminderDates)
        XCTAssertNotEqual(center.pending.map(\.fireDate), unsavedDraft.tasks[0].reminderDates)
        guard case .saved(let completed, _) = await repo.apply(.complete, to: task.id, expected: initial.revision, now: now) else {
            return XCTFail("Owned completion must be acknowledged")
        }
        XCTAssertNotEqual(completed.revision, initial.revision)
        try await refresh(repo, center: &center); XCTAssertTrue(center.pending.isEmpty)
    }
    func testFailedTransactionDoesNotWithdrawSavedReminder() async throws {
        let (root, workspace, settings, task) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings,
                                           write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        let initial = try await repo.load()
        var center = FakeCenter(); try await refresh(repo, center: &center)
        let before = center.pending, bytes = try Data(contentsOf: workspace)
        guard case .persistenceFailed = await repo.apply(.complete, to: task.id, expected: initial.revision, now: now) else {
            return XCTFail("Injected write failure must not succeed")
        }
        try await refresh(repo, center: &center)
        XCTAssertEqual(center.pending, before); XCTAssertEqual(try Data(contentsOf: workspace), bytes)
    }
    func testInvalidAndJournalSnapshotsNeverBecomeEmptyCancellationPlans() async throws {
        let (root, workspace, settings, _) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceFileRepository(workspaceURL: workspace, settingsURL: settings)
        var center = FakeCenter(); try await refresh(repo, center: &center)
        let before = center.pending, updates = center.updates, bytes = try Data(contentsOf: workspace)
        for bad in [Data("bad".utf8), Data("{\"tasks\":[],\"future\":true}".utf8)] {
            try bad.write(to: workspace)
            do { try await refresh(repo, center: &center); XCTFail("Must refuse invalid snapshot") } catch { }
            XCTAssertEqual(center.pending, before); XCTAssertEqual(center.updates, updates)
            XCTAssertEqual(try Data(contentsOf: workspace), bad)
        }
        try bytes.write(to: workspace)
        let journal = workspace.appendingPathExtension("tag-transaction")
        let journalBytes = Data("unresolved owned fixture".utf8); try journalBytes.write(to: journal)
        do { try await refresh(repo, center: &center); XCTFail("Must not recover a journal to plan") } catch { }
        XCTAssertEqual(center.pending, before); XCTAssertEqual(center.updates, updates)
        XCTAssertEqual(try Data(contentsOf: journal), journalBytes)
    }
    func testIndependentPhoneContainersDoNotReadEachOthersSavedData() async throws {
        let (firstRoot, firstWorkspace, firstSettings, firstTask) = try fixture()
        let (secondRoot, secondWorkspace, secondSettings, secondTask) = try fixture()
        defer { try? FileManager.default.removeItem(at: firstRoot); try? FileManager.default.removeItem(at: secondRoot) }
        let first = WorkspaceFileRepository(workspaceURL: firstWorkspace, settingsURL: firstSettings)
        let second = WorkspaceFileRepository(workspaceURL: secondWorkspace, settingsURL: secondSettings)
        var firstCenter = FakeCenter(), secondCenter = FakeCenter()
        try await refresh(first, center: &firstCenter); try await refresh(second, center: &secondCenter)
        XCTAssertEqual(firstCenter.pending.map(\.taskID), [firstTask.id]); XCTAssertEqual(secondCenter.pending.map(\.taskID), [secondTask.id])
        XCTAssertNotEqual(firstCenter.pending.first?.identifier, secondCenter.pending.first?.identifier)
        // This proves repository separation, not future notification namespace isolation.
    }
}
