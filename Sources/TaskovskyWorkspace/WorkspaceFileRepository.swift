import Foundation
import CryptoKit
import TaskovskyDomain

public struct WorkspaceRevision: Codable, Equatable, Sendable {
    private let workspaceDigest: Data
    private let settingsDigest: Data
    fileprivate init(workspace: Data, settings: Data) {
        workspaceDigest = Data(SHA256.hash(data: workspace))
        settingsDigest = Data(SHA256.hash(data: settings))
    }
}

public struct WorkspaceDocument: Sendable {
    public let snapshot: ReadOnlyWorkspaceSnapshot
    public let revision: WorkspaceRevision
    public let allowsKnownFieldWrites: Bool
}

public enum WorkspaceFieldPatch: Sendable { case title(String), plainBody(String) }
public enum WorkspaceWriteRefusal: Equatable, Sendable {
    case stale, compatibility, missing, readOnlyRecord, emptyTitle, styledBody
}
public enum WorkspaceWriteOutcome: Sendable {
    case saved(WorkspaceDocument), unchanged(WorkspaceDocument)
    case refused(WorkspaceWriteRefusal)
    case persistenceFailed
}

public enum WorkspaceCreateRefusal: Equatable, Sendable {
    case stale, compatibility, commandConflict, invalidCapture
    case validation(TaskCaptureValidation)
}
public enum WorkspaceCreateOutcome: Sendable {
    case created(WorkspaceDocument, UUID), alreadyCreated(WorkspaceDocument, UUID)
    case refused(WorkspaceCreateRefusal)
    case notSaved(WorkspaceDocument), uncertain
}

public struct WorkspaceLifecycleUndo: Sendable {
    fileprivate let command: TaskLifecycleCommand
    fileprivate let taskID: UUID
    public let revision: WorkspaceRevision
}

public enum WorkspaceLifecycleRefusal: Equatable, Sendable {
    case stale, compatibility, task(TaskLifecycleRefusal)
}

public enum WorkspaceLifecycleOutcome: Sendable {
    case saved(WorkspaceDocument, undo: WorkspaceLifecycleUndo?)
    case unchanged(WorkspaceDocument)
    case refused(WorkspaceLifecycleRefusal)
    case persistenceFailed
}

public enum WorkspaceScheduleRefusal: Equatable, Sendable {
    case stale, compatibility, missing, readOnlyRecord
    case invalid(TaskScheduleValidation)
}

public enum WorkspaceScheduleOutcome: Sendable {
    case saved(WorkspaceDocument), unchanged(WorkspaceDocument)
    case refused(WorkspaceScheduleRefusal)
    case persistenceFailed
}

/// Single-process local-file adapter. No default path, migration, recovery,
/// networking, or whole-record update API. Other processes must not share it.
public actor WorkspaceFileRepository {
    private let workspaceURL: URL
    private let settingsURL: URL
    private let write: @Sendable (Data, URL) throws -> Void
    private var completionSnapshots: [UUID: [TaskItem]] = [:]

    public init(workspaceURL: URL, settingsURL: URL,
                write: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: localFileWriteOptions) }) {
        self.workspaceURL = workspaceURL; self.settingsURL = settingsURL; self.write = write
    }

    public func load() throws -> WorkspaceDocument {
        try document(workspace: Data(contentsOf: workspaceURL), settings: Data(contentsOf: settingsURL))
    }

    public func apply(_ command: TaskLifecycleCommand, to taskID: UUID,
                      expected: WorkspaceRevision, now: Date = Date(),
                      calendar: Calendar? = nil) -> WorkspaceLifecycleOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }

        var lifecycle = TaskLifecycle(data: current.snapshot.workspace, completionSnapshots: completionSnapshots)
        do {
            guard try lifecycle.apply(command, to: taskID, now: now,
                                      calendar: calendar ?? current.snapshot.settings.calendar) else {
                return .unchanged(current)
            }
            let bytes = try JSONEncoder().encode(lifecycle.data)
            let staged = try document(workspace: bytes, settings: current.snapshot.settingsBytes)
            guard staged.allowsKnownFieldWrites else { return .refused(.compatibility) }
            do { try write(bytes, workspaceURL) } catch {
                // A writer may report failure after replacement. Publish the
                // graph and its transient snapshots only for confirmed bytes.
                guard (try? load())?.revision == staged.revision else { return .persistenceFailed }
            }
            completionSnapshots = lifecycle.completionSnapshots
            let undoCommand: TaskLifecycleCommand? = switch command {
            case .complete: .reopen
            case .trash: .restore
            default: nil
            }
            let undo = undoCommand.map { WorkspaceLifecycleUndo(command: $0, taskID: taskID, revision: staged.revision) }
            return .saved(staged, undo: undo)
        } catch let reason as TaskLifecycleRefusal {
            return .refused(.task(reason))
        } catch {
            return .persistenceFailed
        }
    }

    public func undo(_ token: WorkspaceLifecycleUndo, now: Date = Date()) -> WorkspaceLifecycleOutcome {
        apply(token.command, to: token.taskID, expected: token.revision, now: now)
    }

    /// The stable new task ID is also the local command identity. A retry first
    /// checks that ID, including after a writer threw following replacement.
    public func create(_ draft: TaskCaptureDraft) -> WorkspaceCreateOutcome {
        guard let prepared = draft.preparedTask, prepared.id == draft.id else { return .refused(.invalidCapture) }
        let current: WorkspaceDocument
        do { current = try load() } catch { return .uncertain }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        if let existing = current.snapshot.workspace.tasks.first(where: { $0.id == draft.id }) {
            return exactEncoding(existing, prepared) ? .alreadyCreated(current, existing.id) : .refused(.commandConflict)
        }
        guard current.revision == draft.baseRevision else { return .refused(.stale) }
        do {
            let expected = try draft.input.task(id: draft.id, now: draft.createdAt, workspace: current.snapshot.workspace,
                                               settings: current.snapshot.settings, calendar: draft.calendar)
            guard exactEncoding(prepared, expected) else { return .refused(.invalidCapture) }
        } catch let reason as TaskCaptureValidation { return .refused(.validation(reason)) }
        catch { return .refused(.invalidCapture) }
        var data = current.snapshot.workspace
        if current.snapshot.settings.defaultAddTo == .top { data.tasks.insert(prepared, at: 0) }
        else { data.tasks.append(prepared) }
        do {
            let bytes = try JSONEncoder().encode(data)
            let staged = try document(workspace: bytes, settings: current.snapshot.settingsBytes)
            guard staged.allowsKnownFieldWrites else { return .refused(.invalidCapture) }
            try write(bytes, workspaceURL)
            return .created(staged, prepared.id)
        } catch {
            // Failure is not proof that replacement did not happen. Confirm
            // the identity before acknowledging success or unlocking editing.
            if let latest = try? load(), latest.allowsKnownFieldWrites {
                if let existing = latest.snapshot.workspace.tasks.first(where: { $0.id == draft.id }) {
                    return exactEncoding(existing, prepared) ? .alreadyCreated(latest, existing.id) : .refused(.commandConflict)
                }
                if latest.revision == current.revision { return .notSaved(latest) }
            }
            return .uncertain
        }
    }

    public func apply(_ edit: TaskScheduleEdit, expected: WorkspaceRevision,
                      now: Date = Date()) -> WorkspaceScheduleOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        var data = current.snapshot.workspace
        guard let index = data.tasks.firstIndex(where: { $0.id == edit.taskID }) else { return .refused(.missing) }
        let original = data.tasks[index]
        guard original.kind == .task, original.deletedAt == nil,
              !SmartListEligibility.isArchived(original, lists: data.lists) else { return .refused(.readOnlyRecord) }
        do {
            var task = try edit.applying(to: original, settings: current.snapshot.settings)
            guard CalendarScheduleSnapshot(task) != CalendarScheduleSnapshot(original) else { return .unchanged(current) }
            task.updatedAt = now
            data.tasks[index] = task
            let bytes = try JSONEncoder().encode(data)
            let staged = try document(workspace: bytes, settings: current.snapshot.settingsBytes)
            guard staged.allowsKnownFieldWrites else { return .refused(.compatibility) }
            do { try write(bytes, workspaceURL) } catch {
                guard (try? load())?.revision == staged.revision else { return .persistenceFailed }
            }
            return .saved(staged)
        } catch let reason as TaskScheduleValidation {
            return .refused(.invalid(reason))
        } catch {
            return .persistenceFailed
        }
    }

    public func apply(_ patch: WorkspaceFieldPatch, to taskID: UUID, expected: WorkspaceRevision,
                      now: Date = Date()) -> WorkspaceWriteOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        var data = current.snapshot.workspace
        guard let index = data.tasks.firstIndex(where: { $0.id == taskID }) else { return .refused(.missing) }
        let original = data.tasks[index]
        guard original.deletedAt == nil, !SmartListEligibility.isArchived(original, lists: data.lists) else { return .refused(.readOnlyRecord) }
        switch patch {
        case .title(let value):
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .refused(.emptyTitle) }
            if value.utf16.elementsEqual(original.title.utf16) { return .unchanged(current) }
            data.tasks[index].title = value
        case .plainBody(let value):
            guard original.richBody == nil else { return .refused(.styledBody) }
            if value.utf16.elementsEqual(original.body.utf16) { return .unchanged(current) }
            data.tasks[index].body = value
        }
        data.tasks[index].updatedAt = now
        do {
            let bytes = try JSONEncoder().encode(data)
            let staged = try document(workspace: bytes, settings: current.snapshot.settingsBytes)
            // No await between revision check and replacement. This serializes
            // this actor, not an independent process or a shared live file.
            try write(bytes, workspaceURL)
            return .saved(staged)
        } catch { return .persistenceFailed }
    }

    private func document(workspace: Data, settings: Data) throws -> WorkspaceDocument {
        let snapshot = try ReadOnlyWorkspaceSnapshot(workspaceBytes: workspace, settingsBytes: settings)
        let encoder = JSONEncoder()
        let compatible = try JSONKeySafety.hasUniqueKeys(workspace) && JSONKeySafety.hasUniqueKeys(settings) && canonical(workspace) == canonical(encoder.encode(snapshot.workspace)) &&
            canonicalSettings(settings) == canonicalSettings(encoder.encode(snapshot.settings))
        return WorkspaceDocument(snapshot: snapshot, revision: WorkspaceRevision(workspace: workspace, settings: settings),
                                 allowsKnownFieldWrites: compatible)
    }
    private func canonicalSettings(_ bytes: Data) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] ?? [:]
        // Codable represents this enum-keyed dictionary as alternating pairs.
        // Its iteration order is not persisted intent. Settings are never
        // rewritten by these commands; compare the known map semantically.
        if let pairs = object["smartListVisibility"] as? [String], pairs.count.isMultiple(of: 2) {
            var values: [String: String] = [:]
            for index in stride(from: 0, to: pairs.count, by: 2) { values[pairs[index]] = pairs[index + 1] }
            // Duplicated keys are not a canonical known representation.
            if values.count * 2 == pairs.count { object["smartListVisibility"] = values }
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
    private func canonical(_ bytes: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: bytes), options: [.sortedKeys, .fragmentsAllowed])
    }
}

/// Validation of lexical object keys, after Foundation has validated the JSON.
/// Duplicate known keys would otherwise disappear during a semantic round trip.
struct JSONKeySafety {
    let bytes: [UInt8]
    var index = 0
    static func hasUniqueKeys(_ data: Data) -> Bool {
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else { return false }
        var scanner = Self(bytes: Array(data))
        return scanner.value(depth: 0)
    }
    mutating func whitespace() { while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 } }
    mutating func string() -> Range<Int>? {
        guard index < bytes.count, bytes[index] == 34 else { return nil }
        let start = index; index += 1
        while index < bytes.count {
            if bytes[index] == 34 { index += 1; return start..<index }
            if bytes[index] == 92 { index += 2 } else { index += 1 }
        }
        return nil
    }
    mutating func value(depth: Int) -> Bool {
        whitespace(); guard depth < 128, index < bytes.count else { return false }
        let start = bytes[index]
        if start == 34 { return string() != nil }
        if start == 123 || start == 91 {
            let object = start == 123, end: UInt8 = object ? 125 : 93
            index += 1; whitespace()
            if index < bytes.count && bytes[index] == end { index += 1; return true }
            var keys = Set<String>()
            while index < bytes.count {
                if object {
                    guard let range = string(), let key = try? JSONDecoder().decode(String.self, from: Data(bytes[range])), keys.insert(key).inserted else { return false }
                    whitespace(); guard index < bytes.count && bytes[index] == 58 else { return false }; index += 1
                }
                guard value(depth: depth + 1) else { return false }
                whitespace(); guard index < bytes.count else { return false }
                if bytes[index] == end { index += 1; return true }
                guard bytes[index] == 44 else { return false }; index += 1; whitespace()
            }
            return false
        }
        let before = index
        while index < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
        return index > before
    }
}
