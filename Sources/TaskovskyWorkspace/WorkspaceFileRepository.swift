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

    fileprivate func canFinish(from before: Self, to after: Self) -> Bool {
        (workspaceDigest == before.workspaceDigest || workspaceDigest == after.workspaceDigest) &&
            (settingsDigest == before.settingsDigest || settingsDigest == after.settingsDigest)
    }
}

private struct PendingTagTransaction: Codable {
    let version: Int
    let expected: WorkspaceRevision
    let workspace: Data
    let settings: Data
}

public struct WorkspaceDocument: Sendable {
    public let snapshot: ReadOnlyWorkspaceSnapshot
    public let revision: WorkspaceRevision
    public let allowsKnownFieldWrites: Bool
}

public enum WorkspaceFieldPatch: Sendable {
    case title(String), plainBody(String), richBody([RichBodyEdit]), metadata(TaskMetadataChange)
}
public enum WorkspaceWriteRefusal: Equatable, Sendable {
    case stale, compatibility, missing, readOnlyRecord, emptyTitle, styledBody
    case metadata(TaskMetadataValidation), richBody(RichBodyEditError)
    case batch(TaskBatchRefusal)
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

public enum WorkspaceScheduleRefusal: Error, Equatable, Sendable {
    case stale, compatibility, missing, readOnlyRecord, invalidCalendarOperation, changedSinceCalendarEdit
    case invalid(TaskScheduleValidation)
}

public struct WorkspaceCalendarUndo: Sendable {
    fileprivate let schedule: CalendarScheduleUndo

    public func canRestore(in data: WorkspaceData) -> Bool {
        guard let task = data.tasks.first(where: { $0.id == schedule.taskID }) else { return false }
        return schedule.canRestore(task, lists: data.lists, tasks: data.tasks)
    }
}

public enum WorkspaceScheduleOutcome: Sendable {
    case saved(WorkspaceDocument, undo: WorkspaceCalendarUndo?)
    case unchanged(WorkspaceDocument)
    case refused(WorkspaceScheduleRefusal)
    case persistenceFailed
}

public enum WorkspaceSettingsOutcome: Sendable {
    case saved(WorkspaceDocument), unchanged(WorkspaceDocument)
    case stale, incompatible, invalid, persistenceFailed
}
public typealias WorkspaceCalendarPreferencesOutcome = WorkspaceSettingsOutcome

/// Single-process local-file adapter. An interrupted tag/default change can
/// finish from its journal. Other processes must not share these live files.
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
        if FileManager.default.fileExists(atPath: tagTransactionURL.path) {
            return try finishTagTransaction()
        }
        return try readCurrentFiles()
    }

    private func readCurrentFiles() throws -> WorkspaceDocument {
        try document(workspace: Data(contentsOf: workspaceURL), settings: Data(contentsOf: settingsURL))
    }

    private var tagTransactionURL: URL { workspaceURL.appendingPathExtension("tag-transaction") }

    private func finishTagTransaction() throws -> WorkspaceDocument {
        let raw = try Data(contentsOf: tagTransactionURL)
        let pending = try JSONDecoder().decode(PendingTagTransaction.self, from: raw)
        guard pending.version == 1, JSONKeySafety.hasUniqueKeys(raw) else { throw CocoaError(.fileReadCorruptFile) }
        let before = try readCurrentFiles()
        let after = try document(workspace: pending.workspace, settings: pending.settings)
        guard after.allowsKnownFieldWrites, before.revision.canFinish(from: pending.expected, to: after.revision)
        else { throw CocoaError(.fileWriteUnknown) }
        try replaceIfNeeded(pending.workspace, current: before.snapshot.workspaceBytes, at: workspaceURL)
        try replaceIfNeeded(pending.settings, current: before.snapshot.settingsBytes, at: settingsURL)
        let saved = try readCurrentFiles()
        guard saved.revision == after.revision else { throw CocoaError(.fileWriteUnknown) }
        // Keep later writes blocked until this transaction can be retired.
        try FileManager.default.removeItem(at: tagTransactionURL)
        return saved
    }

    private func replaceIfNeeded(_ bytes: Data, current: Data, at url: URL) throws {
        guard bytes != current else { return }
        do { try write(bytes, url) } catch {
            guard (try? Data(contentsOf: url)) == bytes else { throw error }
        }
    }

    public func saveCalendarOptions(_ options: TaskCalendarOptions, expected: WorkspaceRevision) -> WorkspaceCalendarPreferencesOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .stale }
        let snapshot = current.snapshot
        guard options != snapshot.settings.calendarOptions else { return .unchanged(current) }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let replacement = try encoder.encode(options)
            guard try JSONDecoder().decode(TaskCalendarOptions.self, from: replacement) == options else { return .invalid }
            guard let bytes = try CalendarSettingsPatch.replacing(snapshot.settingsBytes,
                                                                 current: snapshot.settings.calendarOptions,
                                                                 with: replacement) else { return .incompatible }
            return try saveSettings(bytes, workspace: snapshot.workspaceBytes)
        } catch { return .persistenceFailed }
    }

    public func saveSmartLists(_ draft: AppSettings, expected: WorkspaceRevision) -> WorkspaceSettingsOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .stale }
        let snapshot = current.snapshot
        let visibilityChanged = draft.smartListVisibility != snapshot.settings.smartListVisibility
        let orderChanged = draft.effectiveSmartListOrder != snapshot.settings.effectiveSmartListOrder
        guard visibilityChanged || orderChanged else { return .unchanged(current) }
        do {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            var bytes = snapshot.settingsBytes
            if visibilityChanged {
                guard draft.smartListVisibility.count == SmartListKey.allCases.count else { return .invalid }
                let pairs = SmartListKey.allCases.flatMap { key in [key.rawValue, draft.smartListVisibility[key]!.rawValue] }
                guard let patched = try SettingsMemberPatch.replacing("smartListVisibility", in: bytes, with: encoder.encode(pairs),
                                                                     validate: { existing in
                    if existing == Data("null".utf8) { return true }
                    let pairs = try decoder.decode([String].self, from: existing)
                    let keys = stride(from: 0, to: pairs.count, by: 2).map { pairs[$0] }
                    return pairs.count.isMultiple(of: 2) && Set(keys).count == keys.count
                }) else { return .incompatible }
                bytes = patched
            }
            if orderChanged {
                let order = draft.effectiveSmartListOrder
                guard let patched = try SettingsMemberPatch.replacing("smartListOrder", in: bytes, with: encoder.encode(order),
                                                                     validate: { existing in
                    existing == Data("null".utf8) || (try? decoder.decode([SmartListKey].self, from: existing)) != nil
                }) else { return .incompatible }
                bytes = patched
            }
            let decoded = try decoder.decode(AppSettings.self, from: bytes)
            guard decoded.smartListVisibility == draft.smartListVisibility,
                  decoded.effectiveSmartListOrder == draft.effectiveSmartListOrder else { return .invalid }
            return try saveSettings(bytes, workspace: snapshot.workspaceBytes)
        } catch { return .persistenceFailed }
    }

    public func saveLocalPreferences(_ draft: LocalWorkspacePreferences, expected: WorkspaceRevision) -> WorkspaceSettingsOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .stale }
        let snapshot = current.snapshot
        let previous = LocalWorkspacePreferences(snapshot.settings)
        guard draft != previous else { return .unchanged(current) }
        guard draft.valid(from: previous, workspace: snapshot.workspace) else { return .invalid }
        do {
            guard let bytes = try draft.patch(snapshot.settingsBytes, from: snapshot.settings) else { return .incompatible }
            let decoded = try JSONDecoder().decode(AppSettings.self, from: bytes)
            guard LocalWorkspacePreferences(decoded) == draft else { return .invalid }
            return try saveSettings(bytes, workspace: snapshot.workspaceBytes)
        } catch { return .persistenceFailed }
    }

    private func saveSettings(_ bytes: Data, workspace: Data) throws -> WorkspaceSettingsOutcome {
        let staged = try document(workspace: workspace, settings: bytes)
        do { try write(bytes, settingsURL) } catch {
            guard (try? load())?.revision == staged.revision else { return .persistenceFailed }
        }
        return .saved(staged)
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
                                      calendar: calendar ?? current.snapshot.settings.calendar,
                                      addPosition: current.snapshot.settings.defaultAddTo) else {
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
            case .completeFromWontDo:
                current.snapshot.workspace.tasks.first { $0.id == taskID }?.wontDoAt.map(TaskLifecycleCommand.undoBoardCompletionToWontDo)
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

    public func apply(_ edit: TaskBatchEdit, expected: WorkspaceRevision, now: Date = Date(),
                      calendar: Calendar? = nil) -> WorkspaceWriteOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        let settings = current.snapshot.settings
        let lifecycle = TaskLifecycle(data: current.snapshot.workspace, completionSnapshots: completionSnapshots)
        do {
            guard let staged = try edit.applying(to: lifecycle, settings: settings, now: now,
                                                 calendar: calendar ?? settings.calendar) else {
                return .unchanged(current)
            }
            let outcome = saveKnownWorkspace(staged.data, current: current)
            if case .saved = outcome { completionSnapshots = staged.completionSnapshots }
            return outcome
        } catch let reason as TaskBatchRefusal {
            return .refused(.batch(reason))
        } catch {
            return .refused(.batch(.readOnlyRecord))
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
        editSchedule(taskID: edit.taskID, expected: expected, now: now) { task, document in
            guard task.kind == .task else { throw WorkspaceScheduleRefusal.readOnlyRecord }
            return (try edit.applying(to: task, settings: document.snapshot.settings), nil)
        }
    }

    public func apply(_ operation: CalendarScheduleOperation, to taskID: UUID, expected: WorkspaceRevision,
                      calendar: Calendar, scope: CalendarScheduleScope = .series, now: Date = Date()) -> WorkspaceScheduleOutcome {
        editSchedule(taskID: taskID, expected: expected, now: now) { task, document in
            if case .unschedule = operation {
                // Explicit removal also works for an unrecognized zone.
            } else {
                let local = TaskCalendarProjection.taskCalendar(task, fallback: calendar)
                guard task.timeZoneID.map({ TimeZone(identifier: $0) != nil }) ?? true else {
                    throw TaskScheduleValidation.invalidTimeZone
                }
                guard task.scheduledDuration.map({ $0.validated(in: local) != nil }) ?? true else {
                    throw TaskScheduleValidation.invalidDuration
                }
                guard task.customRecurrence?.isValid != false else { throw TaskScheduleValidation.invalidRepeat }
            }
            guard let changed = CalendarScheduling.prepared(operation, to: task, displayCalendar: calendar,
                    settings: document.snapshot.settings, policyCalendar: calendar, scope: scope, in: document.snapshot.workspace.tasks) else {
                throw WorkspaceScheduleRefusal.invalidCalendarOperation
            }
            let undo = CalendarScheduleUndo(taskID: task.id, before: CalendarScheduleSnapshot(task),
                                            after: CalendarScheduleSnapshot(changed),
                                            completedAt: task.completedAt, wontDoAt: task.wontDoAt, operation: operation)
            return (changed, WorkspaceCalendarUndo(schedule: undo))
        }
    }

    public func undo(_ undo: WorkspaceCalendarUndo, now: Date = Date()) -> WorkspaceScheduleOutcome {
        editSchedule(taskID: undo.schedule.taskID, expected: nil, now: now) { task, document in
            let data = document.snapshot.workspace
            guard let restored = undo.schedule.restoring(on: task, lists: data.lists, tasks: data.tasks) else {
                throw WorkspaceScheduleRefusal.changedSinceCalendarEdit
            }
            return (restored, nil)
        }
    }

    private func editSchedule(taskID: UUID, expected: WorkspaceRevision?, now: Date,
                              change: (TaskItem, WorkspaceDocument) throws -> (TaskItem, WorkspaceCalendarUndo?)) -> WorkspaceScheduleOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        if let expected, current.revision != expected { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        var data = current.snapshot.workspace
        guard let index = data.tasks.firstIndex(where: { $0.id == taskID }) else { return .refused(.missing) }
        let original = data.tasks[index]
        guard original.deletedAt == nil, !SmartListEligibility.isArchived(original, lists: data.lists) else {
            return .refused(.readOnlyRecord)
        }
        do {
            var (task, undo) = try change(original, current)
            guard CalendarScheduleSnapshot(task) != CalendarScheduleSnapshot(original) else { return .unchanged(current) }
            task.updatedAt = now
            data.tasks[index] = task
            let bytes = try JSONEncoder().encode(data)
            let staged = try document(workspace: bytes, settings: current.snapshot.settingsBytes)
            guard staged.allowsKnownFieldWrites else { return .refused(.compatibility) }
            do { try write(bytes, workspaceURL) } catch {
                guard (try? load())?.revision == staged.revision else { return .persistenceFailed }
            }
            return .saved(staged, undo: undo)
        } catch let reason as WorkspaceScheduleRefusal {
            return .refused(reason)
        } catch let reason as TaskScheduleValidation {
            return .refused(.invalid(reason))
        } catch {
            return .persistenceFailed
        }
    }

    public func apply(_ command: ListOrganizationCommand, expected: WorkspaceRevision,
                      now: Date = Date()) -> WorkspaceWriteOutcome {
        editKnownWorkspace(expected: expected) { data, _ in command.apply(to: &data, now: now) }
    }

    public func apply(_ change: TaskSectionChange, expected: WorkspaceRevision,
                      now: Date = Date()) -> WorkspaceWriteOutcome {
        editKnownWorkspace(expected: expected) { data, _ in change.apply(to: &data, now: now) }
    }

    public func apply(_ command: SavedFilterChange, expected: WorkspaceRevision) -> WorkspaceWriteOutcome {
        editKnownWorkspace(expected: expected) { data, _ in try command.apply(to: &data) }
    }

    public func apply(_ command: TaskTemplateChange, expected: WorkspaceRevision,
                      now: Date = Date(), calendar: Calendar? = nil) -> WorkspaceWriteOutcome {
        editKnownWorkspace(expected: expected) { data, settings in
            try command.apply(to: &data, settings: settings, now: now, calendar: calendar ?? settings.calendar)
        }
    }

    public func apply(_ command: TagOrganizationCommand, expected: WorkspaceRevision,
                      now: Date = Date()) -> WorkspaceWriteOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        var data = current.snapshot.workspace
        let oldDefault = current.snapshot.settings.defaultTagID
        var newDefault = oldDefault
        guard let changed = command.apply(to: &data, defaultTagID: &newDefault, now: now) else { return .refused(.missing) }
        guard changed else { return .unchanged(current) }
        guard oldDefault != newDefault else { return saveKnownWorkspace(data, current: current) }
        do {
            let encoder = JSONEncoder()
            let workspace = try encoder.encode(data)
            let rawDefault = try encoder.encode(newDefault)
            guard let settings = try SettingsMemberPatch.replacing("defaultTagID", in: current.snapshot.settingsBytes,
                                                                   with: rawDefault, validate: { raw in
                try JSONDecoder().decode(UUID?.self, from: raw) == oldDefault
            }) else { return .refused(.compatibility) }
            let staged = try document(workspace: workspace, settings: settings)
            guard staged.allowsKnownFieldWrites else { return .refused(.compatibility) }
            let journal = try encoder.encode(PendingTagTransaction(version: 1, expected: current.revision,
                                                                    workspace: workspace, settings: settings))
            do { try write(journal, tagTransactionURL) } catch {
                guard (try? Data(contentsOf: tagTransactionURL)) == journal else { return .persistenceFailed }
            }
            return .saved(try finishTagTransaction())
        } catch { return .persistenceFailed }
    }

    private func editKnownWorkspace(expected: WorkspaceRevision,
                                    edit: (inout WorkspaceData, AppSettings) throws -> Bool?) -> WorkspaceWriteOutcome {
        let current: WorkspaceDocument
        do { current = try load() } catch { return .persistenceFailed }
        guard current.revision == expected else { return .refused(.stale) }
        guard current.allowsKnownFieldWrites else { return .refused(.compatibility) }
        var data = current.snapshot.workspace
        do {
            guard let changed = try edit(&data, current.snapshot.settings) else { return .refused(.missing) }
            guard changed else { return .unchanged(current) }
            return saveKnownWorkspace(data, current: current)
        } catch { return .persistenceFailed }
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
        case .richBody(let edits):
            do {
                let updated = try RichBodyEdit.applying(edits, to: original.body, rich: original.richBody)
                let prior = original.richBody ?? RichBody(text: original.body)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                if try encoder.encode(updated) == encoder.encode(prior) { return .unchanged(current) }
                data.tasks[index].body = updated.text
                data.tasks[index].richBody = updated.isEmpty ? nil : updated
            } catch let reason as RichBodyEditError {
                return .refused(.richBody(reason))
            } catch { return .persistenceFailed }
        case .metadata(let command):
            do {
                guard let updated = try command.applying(to: original, availableTags: data.tags) else {
                    return .unchanged(current)
                }
                data.tasks[index] = updated
            } catch let reason as TaskMetadataValidation {
                return .refused(.metadata(reason))
            } catch { return .persistenceFailed }
        }
        data.tasks[index].updatedAt = now
        return saveKnownWorkspace(data, current: current)
    }

    private func saveKnownWorkspace(_ data: WorkspaceData, current: WorkspaceDocument) -> WorkspaceWriteOutcome {
        do {
            let bytes = try JSONEncoder().encode(data)
            let staged = try document(workspace: bytes, settings: current.snapshot.settingsBytes)
            // No await between revision check and replacement. This serializes
            // this actor, not an independent process or a shared live file.
            guard staged.allowsKnownFieldWrites else { return .refused(.compatibility) }
            do { try write(bytes, workspaceURL) } catch {
                guard (try? load())?.revision == staged.revision else { return .persistenceFailed }
            }
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
        if object["defaultTagID"] is NSNull { object.removeValue(forKey: "defaultTagID") }
        // Codable represents this enum-keyed dictionary as alternating pairs.
        // Its iteration order is not persisted intent. The Calendar options
        // patch preserves this map as stored; compare it semantically.
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
    /// The lexical bounds of one root member, or a zero-width insertion
    /// point before the closing brace. The caller verifies unique keys.
    mutating func rootMember(named wanted: String) -> (range: Range<Int>, hasMembers: Bool)? {
        whitespace()
        guard index < bytes.count, bytes[index] == 123 else { return nil }
        index += 1
        whitespace()
        let hasMembers = index < bytes.count && bytes[index] != 125
        while index < bytes.count && bytes[index] != 125 {
            guard let keyRange = string(), let key = try? JSONDecoder().decode(String.self, from: Data(bytes[keyRange])) else { return nil }
            whitespace()
            guard index < bytes.count, bytes[index] == 58 else { return nil }
            index += 1
            whitespace()
            let start = index
            guard value(depth: 1) else { return nil }
            if key == wanted { return (start..<index, hasMembers) }
            whitespace()
            guard index < bytes.count else { return nil }
            if bytes[index] == 125 { break }
            guard bytes[index] == 44 else { return nil }
            index += 1
            whitespace()
        }
        guard index < bytes.count, bytes[index] == 125 else { return nil }
        return (index..<index, hasMembers)
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
