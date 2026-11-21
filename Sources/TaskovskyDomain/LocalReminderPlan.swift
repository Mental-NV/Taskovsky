import Foundation

/// A value describing a pending request, not an OS registration or delivery receipt.
public struct LocalReminderRequest: Equatable, Sendable {
    public let identifier: String
    public let taskID: UUID
    public let fireDate: Date
    public let title: String
    public let body: String

    public init(identifier: String, taskID: UUID, fireDate: Date, title: String, body: String) {
        self.identifier = identifier; self.taskID = taskID; self.fireDate = fireDate
        self.title = title; self.body = body
    }
}

public struct LocalReminderChanges: Equatable, Sendable {
    public let requestsToAdd: [LocalReminderRequest]
    public let identifiersToRemove: [String]
}

/// Pure planning only. The caller must supply a verified persisted snapshot,
/// not optimistic unsaved UI state. This type never calls notification APIs.
public struct LocalReminderPlan: Equatable, Sendable {
    /// Conservative app budget, not a statement about an OS maximum.
    public static let maximumPending = 32
    public static let identifierPrefix = "taskovsky.local-reminder.v1."
    public let hasValidClock: Bool
    public let requests: [LocalReminderRequest]
    public let eligibleCount: Int
    public var deferredCount: Int { eligibleCount - requests.count }

    public init(fromPersisted workspace: WorkspaceData, now: Date, limit: Int = maximumPending) {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            hasValidClock = false; requests = []; eligibleCount = 0
            return
        }
        hasValidClock = true
        var unique: [String: LocalReminderRequest] = [:]
        for task in workspace.tasks where task.kind == .task && task.completedAt == nil &&
            task.wontDoAt == nil && task.deletedAt == nil &&
            SmartListEligibility.allowsReminders(task, lists: workspace.lists) {
            for date in task.effectiveReminderDates where date.timeIntervalSinceReferenceDate.isFinite && date > now {
                let id = Self.identifier(taskID: task.id, date: date)
                unique[id] = LocalReminderRequest(identifier: id, taskID: task.id, fireDate: date,
                    title: "Taskovsky reminder", body: "A task reminder is due.")
            }
        }
        let ordered = unique.values.sorted {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            return $0.identifier < $1.identifier
        }
        eligibleCount = ordered.count
        requests = Array(ordered.prefix(min(max(limit, 0), Self.maximumPending)))
    }

    /// A diff only: adapters must handle authorization, durable-input provenance,
    /// request failures and concurrent generations before acting on this value.
    public func changes(fromPending pending: [LocalReminderRequest]) -> LocalReminderChanges {
        guard hasValidClock else { return .init(requestsToAdd: [], identifiersToRemove: []) }
        let existing = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { _, last in last })
        let wanted = Set(requests.map(\.identifier))
        let removed = existing.keys.filter { Self.owns($0) && !wanted.contains($0) }.sorted()
        return .init(requestsToAdd: requests.filter { existing[$0.identifier] != $0 }, identifiersToRemove: removed)
    }

    private static func identifier(taskID: UUID, date: Date) -> String {
        let seconds = date.timeIntervalSinceReferenceDate
        // Date regards signed zero as the same instant; make its identifier canonical.
        let bits = (seconds == 0 ? 0.0 : seconds).bitPattern
        let hex = String(bits, radix: 16)
        return identifierPrefix + taskID.uuidString.lowercased() + "." + String(repeating: "0", count: 16 - hex.count) + hex
    }

    private static func owns(_ identifier: String) -> Bool {
        guard identifier.hasPrefix(identifierPrefix) else { return false }
        let parts = identifier.dropFirst(identifierPrefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let uuid = UUID(uuidString: String(parts[0])),
              uuid.uuidString.lowercased() == parts[0], parts[1].count == 16,
              UInt64(parts[1], radix: 16) != nil,
              parts[1] == parts[1].lowercased() else { return false }
        return true
    }
}
