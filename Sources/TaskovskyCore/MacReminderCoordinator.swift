import Foundation
import CryptoKit
import TaskovskyDomain
import TaskovskyWorkspace

// Inert Mac boundary: no concrete OS center and no app/UI integration yet.
enum MacReminderAuthorization { case notDetermined, authorized, denied }
struct MacReminderNotification: Equatable {
    let identifier: String
    let title: String
    let body: String
    let metadata: [String: String]
}
@MainActor protocol MacReminderCenter: AnyObject {
    func authorization() async throws -> MacReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func pending() async throws -> [MacReminderNotification]
    func remove(identifiers: [String]) async throws
    func add(_ request: MacReminderNotification) async throws
}

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
    private var enabled = false
    private var tail: Task<MacReminderStatus, Never>?

    init(workspaceURL: URL, settingsURL: URL, appScope: String, center: any MacReminderCenter) {
        self.center = center
        repository = WorkspaceFileRepository(workspaceURL: workspaceURL, settingsURL: settingsURL)
        // Length-delimited canonical paths and explicit app identity prevent
        // path ambiguity, process-random hashes and QA/production collisions.
        let components = [appScope, workspaceURL.resolvingSymlinksInPath().standardizedFileURL.path,
                          settingsURL.resolvingSymlinksInPath().standardizedFileURL.path]
        let key = components.map { "\($0.utf8.count):\($0)" }.joined()
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        prefix = "taskovsky.mac-reminder.v1.\(digest)."
    }

    // Entire operations are queued across suspension points, not merely actor-isolated.
    private func enqueue(_ operation: @escaping @MainActor () async -> MacReminderStatus) async -> MacReminderStatus {
        let predecessor = tail
        let task = Task { @MainActor in
            if let predecessor { _ = await predecessor.value }
            return await operation()
        }
        tail = task
        return await task.value
    }

    func enable(now: Date) async -> MacReminderStatus {
        await enqueue {
            do {
                let status = try await self.center.authorization()
                let allowed: Bool
                switch status {
                case .authorized: allowed = true
                case .denied: allowed = false
                case .notDetermined: allowed = try await self.center.requestAuthorization()
                }
                guard allowed else { self.enabled = false; return .denied }
                self.enabled = true
                return await self.reconcile(now: now)
            } catch { return .failed(stage: .authorization, added: 0, removalsSubmitted: 0) }
        }
    }

    func refresh(now: Date) async -> MacReminderStatus {
        await enqueue { await self.reconcile(now: now) }
    }

    func disable() async -> MacReminderStatus {
        await enqueue {
            self.enabled = false
            var stage = MacReminderFailureStage.pending
            do {
                let pending = try await self.center.pending()
                let ids = pending.compactMap { self.decode($0) == nil ? nil : $0.identifier }
                stage = .removal
                if !ids.isEmpty { try await self.center.remove(identifiers: ids) }
                return .disabled
            } catch { return .failed(stage: stage, added: 0, removalsSubmitted: 0) }
        }
    }

    private func reconcile(now: Date) async -> MacReminderStatus {
        guard enabled else { return .disabled }
        var stage = MacReminderFailureStage.authorization
        var added = 0, removed = 0
        do {
            guard try await center.authorization() == .authorized else { return .denied }
            stage = .snapshot
            let saved = try await repository.loadReadOnlyForReminders()
            let plan = LocalReminderPlan(fromPersisted: saved.snapshot.workspace, now: now)
            guard plan.hasValidClock else { return .failed(stage: .clock, added: 0, removalsSubmitted: 0) }
            stage = .pending
            let pending = try await center.pending()
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
            for request in diff.requestsToAdd { try await center.add(encode(request)); added += 1 }
            return .ready(pending: plan.requests.count, deferred: plan.deferredCount)
        } catch { return .failed(stage: stage, added: added, removalsSubmitted: removed) }
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
