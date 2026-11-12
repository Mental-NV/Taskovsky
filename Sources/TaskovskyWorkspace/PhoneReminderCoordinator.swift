import Foundation
import TaskovskyDomain

public enum PhoneReminderAuthorization: Sendable { case notDetermined, authorized, denied }
public struct PhoneReminderNotification: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let body: String
    public let metadata: [String: String]
    public init(identifier: String, title: String, body: String, metadata: [String: String]) {
        self.identifier = identifier; self.title = title; self.body = body; self.metadata = metadata
    }
}

/// No production implementation in this slice. All effects are injected.
@MainActor public protocol PhoneReminderCenter: AnyObject {
    func authorization() async throws -> PhoneReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func pending() async throws -> [PhoneReminderNotification]
    func remove(identifiers: [String]) async throws
    func add(_ request: PhoneReminderNotification) async throws
}

public enum PhoneReminderFailureStage: Equatable, Sendable {
    case preferenceRead, preferenceWrite, authorization, pending, snapshot, clock, ownership, removal, addition
}
public enum PhoneReminderStatus: Equatable, Sendable {
    case disabled, denied
    case ready(plannedPending: Int, deferred: Int)
    case failed(stages: [PhoneReminderFailureStage], added: Int, removalsSubmitted: Int)
}

/// Non-UI phone orchestration; no UserNotifications dependency or real center.
@MainActor public final class PhoneReminderCoordinator {
    private let center: any PhoneReminderCenter
    private let repository: WorkspaceFileRepository
    private let preferences: PhoneReminderPreferences
    private let clock: () -> Date
    private var known: PhoneReminderPreference?
    private var sessionOff = false
    private var tail: Task<PhoneReminderStatus, Never>?

    public init(directory: URL, appScope: String, center: any PhoneReminderCenter,
                clock: @escaping () -> Date = { Date() },
                preferenceWrite: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: localFileWriteOptions) }) {
        self.center = center; self.clock = clock
        repository = WorkspaceFileRepository(workspaceURL: directory.appendingPathComponent("workspace.json"),
                                             settingsURL: directory.appendingPathComponent("settings.json"))
        preferences = PhoneReminderPreferences(directory: directory, appScope: appScope, write: preferenceWrite)
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> PhoneReminderStatus) async -> PhoneReminderStatus {
        let predecessor = tail
        let next = Task { @MainActor in
            if let predecessor { _ = await predecessor.value }
            return await operation()
        }
        tail = next
        return await next.value
    }

    /// Explicit action only. Persist intent before any center effect.
    public func enable() async -> PhoneReminderStatus {
        await enqueue {
            do { _ = try await self.loadPreference() }
            catch { return self.failure(.preferenceRead) }
            do {
                guard let saved = try await self.preferences.setEnabled(true) else { return self.failure(.preferenceWrite) }
                self.known = saved; self.sessionOff = false
            } catch { return self.failure(.preferenceWrite) }
            do {
                switch try await self.center.authorization() {
                case .denied: return .denied
                case .notDetermined:
                    guard try await self.center.requestAuthorization() else { return .denied }
                case .authorized: break
                }
            } catch { return self.failure(.authorization) }
            return await self.reconcile()
        }
    }

    /// Startup/activation/saved-revision signal. Never asks for authorization.
    public func refresh() async -> PhoneReminderStatus {
        await enqueue {
            do {
                guard let saved = try await self.loadPreference() else { return .disabled }
                if self.sessionOff || !saved.enabled { return await self.cleanup() }
                return await self.reconcile()
            } catch { return self.failure(.preferenceRead) }
        }
    }

    public func disable() async -> PhoneReminderStatus {
        await enqueue {
            self.sessionOff = true
            var failures: [PhoneReminderFailureStage] = []
            do { _ = try await self.loadPreference() }
            catch { failures.append(.preferenceRead) }
            if failures.isEmpty {
                do { self.known = try await self.preferences.setEnabled(false) }
                catch { failures.append(.preferenceWrite) }
            }
            let result = await self.cleanup()
            guard !failures.isEmpty else { return result }
            if case .failed(let cleanupFailures, let added, let removed) = result {
                return .failed(stages: failures + cleanupFailures, added: added, removalsSubmitted: removed)
            }
            // Cleanup may have submitted removals; return its count separately.
            return .failed(stages: failures, added: 0, removalsSubmitted: self.lastCleanupCount)
        }
    }

    private func loadPreference() async throws -> PhoneReminderPreference? {
        let saved = try await preferences.load()
        if let known, saved?.workspaceID != known.workspaceID { throw PhoneReminderPreferenceError.invalidRecord }
        known = saved
        return saved
    }

    private var prefix: String? { known.map { "taskovsky.phone-reminder.v1.\($0.requestNamespace)." } }
    private var lastCleanupCount = 0
    private func cleanup() async -> PhoneReminderStatus {
        lastCleanupCount = 0
        guard prefix != nil else { return .disabled }
        var stage = PhoneReminderFailureStage.pending
        do {
            let pending = try await center.pending()
            let ids = pending.compactMap { decode($0) == nil ? nil : $0.identifier }
            stage = .removal
            if !ids.isEmpty { try await center.remove(identifiers: ids); lastCleanupCount = ids.count }
            return .disabled
        } catch { return failure(stage) }
    }

    private func reconcile() async -> PhoneReminderStatus {
        guard !sessionOff, known?.enabled == true, let prefix else { return .disabled }
        var stage = PhoneReminderFailureStage.authorization
        var added = 0, removed = 0
        do {
            guard try await center.authorization() == .authorized else { return .denied }
            stage = .pending
            let pending = try await center.pending()
            stage = .snapshot
            let saved = try await repository.loadReadOnlyForReminders()
            let plan = LocalReminderPlan(fromPersisted: saved.snapshot.workspace, now: clock())
            guard plan.hasValidClock else { return failure(.clock) }
            let wanted = Set(plan.requests.map { prefix + $0.identifier })
            guard !pending.contains(where: { wanted.contains($0.identifier) && decode($0) == nil }) else { return failure(.ownership) }
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
                guard now.timeIntervalSinceReferenceDate.isFinite else { return failure(.clock, added: added, removed: removed) }
                if request.fireDate <= now { expired += 1; continue }
                try await center.add(.init(identifier: prefix + request.identifier, title: request.title, body: request.body,
                    metadata: ["task": request.taskID.uuidString.lowercased(), "instant": String(request.fireDate.timeIntervalSinceReferenceDate.bitPattern, radix: 16)]))
                added += 1
            }
            return .ready(plannedPending: plan.requests.count - expired, deferred: plan.deferredCount)
        } catch { return failure(stage, added: added, removed: removed) }
    }

    private func failure(_ stage: PhoneReminderFailureStage, added: Int = 0, removed: Int = 0) -> PhoneReminderStatus {
        .failed(stages: [stage], added: added, removalsSubmitted: removed)
    }

    private func decode(_ value: PhoneReminderNotification) -> LocalReminderRequest? {
        guard let prefix, value.identifier.hasPrefix(prefix), let text = value.metadata["task"],
              let task = UUID(uuidString: text), task.uuidString.lowercased() == text,
              let raw = value.metadata["instant"], let bits = UInt64(raw, radix: 16), raw == String(bits, radix: 16) else { return nil }
        let seconds = Double(bitPattern: bits)
        guard seconds.isFinite else { return nil }
        let hex = String((seconds == 0 ? 0.0 : seconds).bitPattern, radix: 16)
        let id = LocalReminderPlan.identifierPrefix + text + "." + String(repeating: "0", count: 16 - hex.count) + hex
        guard value.identifier == prefix + id else { return nil }
        return .init(identifier: id, taskID: task, fireDate: Date(timeIntervalSinceReferenceDate: seconds), title: value.title, body: value.body)
    }
}
