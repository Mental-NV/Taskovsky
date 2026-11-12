import XCTest
import UserNotifications
@testable import TaskovskyCore

final class MacLocalNotificationsTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func fixture() throws -> (URL, URL, URL, MacReminderPreferenceStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = root.appendingPathComponent("workspace.json"), settings = root.appendingPathComponent("settings.json")
        var task = TaskItem(title: "Private title"); task.reminderDates = [now.addingTimeInterval(60.125)]
        try JSONEncoder().encode(WorkspaceData(tasks: [task])).write(to: workspace)
        try JSONEncoder().encode(AppSettings()).write(to: settings)
        let id = MacReminderCoordinator.workspaceKey(workspaceURL: workspace, settingsURL: settings, appScope: "QA")
        return (root, workspace, settings, .init(url: root.appendingPathComponent("opt-in.json"), identity: id))
    }
    @MainActor func testDefaultOffThenExplicitEnableAndRestartDoesNotPrompt() async throws {
        let (root, workspace, settings, pref) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter()
        let service = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await service.start(); await service.refresh()
        XCTAssertEqual(center.accesses, 0); XCTAssertEqual(center.prompts, 0); XCTAssertNil(try pref.read())
        await service.setEnabled(true)
        XCTAssertEqual(try pref.read(), true); XCTAssertTrue(service.isEnabled); XCTAssertEqual(center.prompts, 1); XCTAssertEqual(center.requests.count, 1)
        center.status = .notDetermined
        let restarted = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await restarted.start()
        XCTAssertEqual(center.prompts, 1); XCTAssertTrue(restarted.isEnabled); XCTAssertTrue(restarted.statusText.contains("not authorized"))
        center.status = .authorized; await restarted.refresh(); XCTAssertEqual(center.additions, 1)
        await restarted.setEnabled(false); XCTAssertEqual(try pref.read(), false); XCTAssertTrue(center.requests.isEmpty); XCTAssertFalse(center.presentation)
    }
    @MainActor func testPreferenceFailuresDoNotPromptOrResumeSessionAfterFailedDisable() async throws {
        let (root, workspace, settings, pref) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter(); center.status = .authorized
        try pref.save(true)
        var failed = pref; failed.write = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        let service = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: failed, center: center, clock: { self.now })
        await service.start(); XCTAssertEqual(center.requests.count, 1)
        await service.setEnabled(false)
        XCTAssertEqual(try pref.read(), true); XCTAssertTrue(service.statusText.contains("previous preference")); XCTAssertFalse(center.presentation); XCTAssertTrue(center.requests.isEmpty)
        let accesses = center.accesses
        await service.refresh(); XCTAssertEqual(center.accesses, accesses)
        let corrupt = Data("{\"version\":2,\"identity\":\"other\",\"enabled\":true}".utf8)
        try corrupt.write(to: pref.url)
        let broken = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await broken.start(); await broken.setEnabled(true)
        XCTAssertEqual(center.accesses, accesses); XCTAssertEqual(center.prompts, 0)
        XCTAssertEqual(try Data(contentsOf: pref.url), corrupt)
    }
    @MainActor func testFailedEnablePersistsNothingAndDisabledCleanupRetries() async throws {
        let (root, workspace, settings, pref) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter()
        var failed = pref; failed.write = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        let broken = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: failed, center: center, clock: { self.now })
        await broken.setEnabled(true); XCTAssertNil(try pref.read()); XCTAssertEqual(center.accesses, 0); XCTAssertEqual(center.prompts, 0)
        let service = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await service.setEnabled(true); center.failRemoval = true
        await service.setEnabled(false); XCTAssertEqual(try pref.read(), false); XCTAssertEqual(center.requests.count, 1)
        center.failRemoval = false
        let restarted = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await restarted.start(); XCTAssertTrue(center.requests.isEmpty); XCTAssertEqual(center.prompts, 1)
    }
    @MainActor func testDuplicatePreferenceKeysCannotRestoreOptIn() async throws {
        let (root, workspace, settings, pref) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("{\"version\":1,\"identity\":\"\(pref.identity)\",\"enabled\":false,\"enabled\":true}".utf8)
        try bytes.write(to: pref.url)
        let center = FakeReminderCenter()
        let service = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await service.start(); await service.setEnabled(true)
        XCTAssertEqual(center.accesses, 0); XCTAssertEqual(center.prompts, 0)
        XCTAssertEqual(try Data(contentsOf: pref.url), bytes); XCTAssertFalse(service.isEnabled)
    }
    @MainActor func testFreshClockAfterPendingWaitDoesNotCatchUpExpiredReminder() async throws {
        let (root, workspace, settings, pref) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        var clock = now
        let center = FakeReminderCenter(); center.status = .authorized
        center.pendingHook = { clock = self.now.addingTimeInterval(120) }
        let service = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { clock })
        await service.setEnabled(true); XCTAssertTrue(center.requests.isEmpty); XCTAssertEqual(center.additions, 0)
    }
    @MainActor func testSnapshotIsReadAfterPendingWaitAndOwnershipRejectsMalformedData() async throws {
        let (root, workspace, settings, pref) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let center = FakeReminderCenter(); center.status = .authorized
        center.pendingHook = { try! JSONEncoder().encode(WorkspaceData()).write(to: workspace) }
        let service = MacLocalNotifications(workspaceURL: workspace, settingsURL: settings, appScope: "QA", preference: pref, center: center, clock: { self.now })
        await service.setEnabled(true); XCTAssertTrue(center.requests.isEmpty)
        let task = UUID().uuidString.lowercased()
        let bits = now.timeIntervalSinceReferenceDate.bitPattern, raw = String(bits, radix: 16)
        let prefix = "owned."
        let id = prefix + LocalReminderPlan.identifierPrefix + task + "." + String(repeating: "0", count: 16 - raw.count) + raw
        XCTAssertTrue(MacNotificationRequestFactory.owns(identifier: id, metadata: ["task": task, "instant": raw], prefix: prefix))
        XCTAssertFalse(MacNotificationRequestFactory.owns(identifier: id, metadata: [:], prefix: prefix))
        XCTAssertFalse(MacNotificationRequestFactory.owns(identifier: id, metadata: ["task": task, "instant": raw], prefix: "foreign."))
    }
    func testPureUTCTriggerRoundsUpAndPreservesExactMetadata() throws {
        // Request/trigger construction only. Never instantiate UNUserNotificationCenter.
        let first = ISO8601DateFormatter().date(from: "2026-11-01T05:30:00Z")!
        for instant in [first, first.addingTimeInterval(3600), first.addingTimeInterval(0.125)] {
            let descriptor = MacReminderNotification(identifier: "owned", title: "Taskovsky reminder", body: "A task reminder is due.", metadata: ["instant": String(instant.timeIntervalSinceReferenceDate.bitPattern, radix: 16), "task": UUID().uuidString])
            let request = try MacNotificationRequestFactory.request(descriptor, now: instant.addingTimeInterval(-60))
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertFalse(trigger.repeats); XCTAssertEqual(trigger.dateComponents.timeZone?.secondsFromGMT(), 0)
            let calendar = try XCTUnwrap(trigger.dateComponents.calendar)
            XCTAssertEqual(calendar.date(from: trigger.dateComponents), Date(timeIntervalSinceReferenceDate: ceil(instant.timeIntervalSinceReferenceDate)))
            XCTAssertEqual(request.content.userInfo["instant"] as? String, descriptor.metadata["instant"])
            XCTAssertThrowsError(try MacNotificationRequestFactory.request(descriptor, now: instant))
        }
        for seconds in [Double.nan, Double.infinity, 1e30] {
            let request = MacReminderNotification(identifier: "invalid", title: "", body: "", metadata: ["instant": String(seconds.bitPattern, radix: 16)])
            XCTAssertThrowsError(try MacNotificationRequestFactory.request(request, now: now))
        }
    }
    @MainActor func testDurableRevisionChangesOnlyAfterSuccessfulWrites() throws {
        let (root, workspace, settings, _) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = TaskStore(fileURL: workspace, settingsURL: settings, seed: false)
        let start = store.persistedChangeRevision
        store.save(); XCTAssertEqual(store.persistedChangeRevision, start + 1)
        let bytes = try Data(contentsOf: workspace)
        try FileManager.default.removeItem(at: workspace); try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false)
        store.save(); XCTAssertEqual(store.persistedChangeRevision, start + 1)
        try FileManager.default.removeItem(at: workspace); try bytes.write(to: workspace)
        store.settings.dateRecognition.toggle(); XCTAssertEqual(store.persistedChangeRevision, start + 2)
    }
}
