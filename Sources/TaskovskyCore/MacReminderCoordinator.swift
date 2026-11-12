import Foundation
import CryptoKit
import TaskovskyDomain
import TaskovskyWorkspace

// Mac orchestration boundary. All center effects are injected.
enum MacReminderAuthorization { case notDetermined, authorized, denied }
struct MacReminderNotification: Equatable {
    let identifier: String
    let title: String
    let body: String
    let metadata: [String: String]
}
@MainActor protocol MacReminderCenter: AnyObject {
    func setPresentationEnabled(_ enabled: Bool)
    func authorization() async throws -> MacReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func pending() async throws -> [MacReminderNotification]
    func remove(identifiers: [String]) async throws
    func add(_ request: MacReminderNotification) async throws
}

extension MacReminderCenter { func setPresentationEnabled(_ enabled: Bool) {} }

enum MacReminderFailureStage: Equatable { case authorization, snapshot, clock, pending, ownership, removal, addition }
enum MacReminderStatus: Equatable {
    case disabled, denied
    case failed(stage: MacReminderFailureStage, added: Int, removalsSubmitted: Int)
    case ready(pending: Int, deferred: Int)
}

@MainActor final class MacReminderCoordinator {
    private let center: any MacReminderCenter
    private let repository: WorkspaceFileRepository
    private let prefix: String
    private(set) var lastErrorDiagnostic: String?
    private var enabled = false
    private var tail: Task<MacReminderStatus, Never>?

    init(workspaceURL: URL, settingsURL: URL, appScope: String, center: any MacReminderCenter) {
        self.center = center
        repository = WorkspaceFileRepository(workspaceURL: workspaceURL, settingsURL: settingsURL)
        prefix = "taskovsky.mac-reminder.v1.\(Self.workspaceKey(workspaceURL: workspaceURL, settingsURL: settingsURL, appScope: appScope))."
    }

    nonisolated static func workspaceKey(workspaceURL: URL, settingsURL: URL, appScope: String) -> String {
        let components = [appScope, workspaceURL.resolvingSymlinksInPath().standardizedFileURL.path,
                          settingsURL.resolvingSymlinksInPath().standardizedFileURL.path]
        let key = components.map { "\($0.utf8.count):\($0)" }.joined()
        return SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // Entire operations are queued across suspension points, not merely actor-isolated.
    private func enqueue(_ operation: @escaping @MainActor () async -> MacReminderStatus) async -> MacReminderStatus {
        let predecessor = tail
        let task = Task { @MainActor in
            if let predecessor { _ = await predecessor.value }
            self.lastErrorDiagnostic = nil
            return await operation()
        }
        tail = task
        return await task.value
    }

    func enable(now: Date) async -> MacReminderStatus { await enable(clock: { now }) }

    func enable(clock: @escaping () -> Date) async -> MacReminderStatus {
        await enqueue {
            do {
                let status = try await self.center.authorization()
                let allowed: Bool
                switch status {
                case .authorized: allowed = true
                case .denied: allowed = false
                case .notDetermined: allowed = try await self.center.requestAuthorization()
                }
                guard allowed else { self.enabled = false; self.center.setPresentationEnabled(false); return .denied }
                self.enabled = true
                return await self.reconcile(clock: clock)
            } catch { self.record(error); return .failed(stage: .authorization, added: 0, removalsSubmitted: 0) }
        }
    }

    func refresh(now: Date) async -> MacReminderStatus {
        await enqueue { await self.reconcile(clock: { now }) }
    }

    /// Restore persisted intent without requesting authorization, including
    /// recovery after an earlier explicit request was denied.
    func restoreEnabled(clock: @escaping () -> Date) async -> MacReminderStatus {
        await enqueue {
            self.enabled = true
            return await self.reconcile(clock: clock)
        }
    }

    /// Stops this process immediately; used when persisting opt-out fails.
    func suspend() async {
        _ = await enqueue { self.enabled = false; self.center.setPresentationEnabled(false); return .disabled }
    }

    func disable() async -> MacReminderStatus {
        await enqueue {
            self.enabled = false
            self.center.setPresentationEnabled(false)
            var stage = MacReminderFailureStage.pending
            do {
                let pending = try await self.center.pending()
                let ids = pending.compactMap { self.decode($0) == nil ? nil : $0.identifier }
                stage = .removal
                if !ids.isEmpty { try await self.center.remove(identifiers: ids) }
                return .disabled
            } catch { self.record(error); return .failed(stage: stage, added: 0, removalsSubmitted: 0) }
        }
    }

    private func reconcile(clock: () -> Date) async -> MacReminderStatus {
        guard enabled else { return .disabled }
        var stage = MacReminderFailureStage.authorization
        var added = 0, removed = 0
        do {
            guard try await center.authorization() == .authorized else { center.setPresentationEnabled(false); return .denied }
            center.setPresentationEnabled(true)
            stage = .pending
            let pending = try await center.pending()
            stage = .snapshot
            let saved = try await repository.loadReadOnlyForReminders()
            let plan = LocalReminderPlan(fromPersisted: saved.snapshot.workspace, now: clock())
            guard plan.hasValidClock else { return .failed(stage: .clock, added: 0, removalsSubmitted: 0) }
            let desiredIDs = Set(plan.requests.map { prefix + $0.identifier })
            // Do not overwrite a malformed/unknown request merely because its ID
            // collides with one we would like to own.
            guard !pending.contains(where: { desiredIDs.contains($0.identifier) && decode($0) == nil }) else { return .failed(stage: .ownership, added: 0, removalsSubmitted: 0) }
            let diff = plan.changes(fromPending: pending.compactMap(decode))
            stage = .removal
            if !diff.identifiersToRemove.isEmpty {
                try await center.remove(identifiers: diff.identifiersToRemove.map { prefix + $0 })
                removed = diff.identifiersToRemove.count
            }
            stage = .addition
            var expired = 0
            for request in diff.requestsToAdd {
                let now = clock()
                guard now.timeIntervalSinceReferenceDate.isFinite else { return .failed(stage: .clock, added: added, removalsSubmitted: removed) }
                if request.fireDate <= now { expired += 1; continue }
                try await center.add(encode(request)); added += 1
            }
            return .ready(pending: plan.requests.count - expired, deferred: plan.deferredCount)
        } catch { record(error); return .failed(stage: stage, added: added, removalsSubmitted: removed) }
    }

    private func record(_ error: Error) {
        let value = error as NSError
        let knownDomains = ["UNErrorDomain", "NSCocoaErrorDomain", "NSPOSIXErrorDomain"]
        // Do not expose localizedDescription, userInfo, paths or arbitrary domains.
        let domain = knownDomains.contains(value.domain) ? value.domain : "Other error"
        lastErrorDiagnostic = "\(domain) (\(value.code))"
    }

    private func encode(_ request: LocalReminderRequest) -> MacReminderNotification {
        let bits = request.fireDate.timeIntervalSinceReferenceDate.bitPattern
        return .init(identifier: prefix + request.identifier, title: request.title, body: request.body,
                     metadata: ["task": request.taskID.uuidString.lowercased(), "instant": String(bits, radix: 16)])
    }

    private func decode(_ pending: MacReminderNotification) -> LocalReminderRequest? {
        guard pending.identifier.hasPrefix(prefix), let text = pending.metadata["task"],
              let task = UUID(uuidString: text), task.uuidString.lowercased() == text,
              let raw = pending.metadata["instant"], let bits = UInt64(raw, radix: 16),
              raw == String(bits, radix: 16) else { return nil }
        let seconds = Double(bitPattern: bits)
        guard seconds.isFinite else { return nil }
        let normalized = (seconds == 0 ? 0.0 : seconds).bitPattern
        let hex = String(normalized, radix: 16)
        let id = LocalReminderPlan.identifierPrefix + text + "." + String(repeating: "0", count: 16 - hex.count) + hex
        guard pending.identifier == prefix + id else { return nil }
        return .init(identifier: id, taskID: task, fireDate: Date(timeIntervalSinceReferenceDate: seconds),
                     title: pending.title, body: pending.body)
    }
}
