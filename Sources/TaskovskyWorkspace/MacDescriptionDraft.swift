import Foundation
import TaskovskyDomain

/// Exact paired content, not an AppKit Undo stack or a phone edit-operation log.
public struct DescriptionSnapshot: Codable, Equatable, Sendable {
    public let body: String
    public let rich: RichBody?
    public init?(body: String, rich: RichBody?) {
        guard (try? RichBodyEdit.applying([], to: body, rich: rich)) != nil else { return nil }
        self.body = body; self.rich = rich
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        RichBody.sameCodeUnits(lhs.body, rhs.body) && exactEncoding(lhs.rich, rhs.rich)
    }
    private enum CodingKeys: String, CodingKey { case body, rich }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let body = try c.decode(String.self, forKey: .body), rich = try c.decodeIfPresent(RichBody.self, forKey: .rich)
        guard let value = Self(body: body, rich: rich) else { throw CocoaError(.fileReadCorruptFile) }
        self = value
    }
}

public enum DescriptionRecovery: Equatable, Sendable { case retryEligible, alreadySaved, conflict, unavailable }

/// Unused foundation: no current Mac editor or application lifecycle wiring.
public struct MacDescriptionDraft: LocalDraftRecord {
    public let version: Int
    public let id: UUID
    public let workspaceID: UUID
    public let taskID: UUID
    public let baseline: DescriptionSnapshot
    public private(set) var content: DescriptionSnapshot
    public private(set) var sequence: Int
    public init(id: UUID = UUID(), workspaceID: UUID, taskID: UUID, baseline: DescriptionSnapshot) {
        version = 1; self.id = id; self.workspaceID = workspaceID; self.taskID = taskID
        self.baseline = baseline; content = baseline; sequence = 0
    }
    @discardableResult public mutating func replace(with value: DescriptionSnapshot) -> Bool {
        guard sequence < Int.max - 1 else { return false }
        if content == value { return true }
        content = value; sequence += 1; return true
    }
    public func continues(_ earlier: Self) -> Bool {
        id == earlier.id && workspaceID == earlier.workspaceID && taskID == earlier.taskID && baseline == earlier.baseline
    }
    public func recovery(in workspace: WorkspaceData, workspaceID: UUID) -> DescriptionRecovery {
        guard self.workspaceID == workspaceID, version == 1, sequence >= 0, sequence < Int.max,
              workspace.tasks.filter({ $0.id == taskID }).count == 1,
              let task = workspace.tasks.first(where: { $0.id == taskID }), task.deletedAt == nil,
              !workspace.lists.contains(where: { $0.id == task.listID && $0.isArchived }),
              let saved = DescriptionSnapshot(body: task.body, rich: task.richBody) else { return .unavailable }
        if saved == content { return .alreadySaved }
        return saved == baseline ? .retryEligible : .conflict
    }
}

/// One caller-owned, dedicated recovery file. Does not create directories,
/// assign workspace identities, mutate tasks, autoapply recovery or wire UI.
/// Reuses the existing serialized journal with exact after-write/readback handling.
public actor MacDescriptionJournal {
    private let workspaceID: UUID
    private let taskID: UUID
    private let journal: LocalDraftStore<MacDescriptionDraft>
    private let validate: @Sendable () throws -> Void
    public init(fileURL: URL, workspaceID: UUID, taskID: UUID,
                validate: @escaping @Sendable () throws -> Void = {},
                write: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: localFileWriteOptions) },
                remove: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.workspaceID = workspaceID; self.taskID = taskID; self.validate = validate
        journal = LocalDraftStore(fileURL: fileURL, write: { bytes, url in
            do { try validate(); try write(bytes, url) }
            catch { try validate(); guard (try? Data(contentsOf: url)) == bytes else { throw error } }
        }, remove: { url in
            do { try validate(); try remove(url) }
            catch let error {
                do { try validate(); _ = try Data(contentsOf: url); throw error }
                catch let read as CocoaError where read.code == .fileReadNoSuchFile { return }
            }
        })
    }
    public func load() async -> LocalDraftLoad<MacDescriptionDraft> {
        guard (try? validate()) != nil else { return .unavailable }
        let loaded = await journal.load()
        if case .available(let value) = loaded, !owns(value) { return .unavailable }
        return loaded
    }
    public func save(_ value: MacDescriptionDraft) async -> FieldDraftWrite {
        guard owns(value), (try? validate()) != nil else { return .refused }
        return await journal.begin(value)
    }
    public func close(_ value: MacDescriptionDraft) async -> FieldDraftWrite {
        guard owns(value), (try? validate()) != nil else { return .refused }
        return await journal.close(expected: value)
    }
    private func owns(_ value: MacDescriptionDraft) -> Bool {
        value.workspaceID == workspaceID && value.taskID == taskID && value.version == 1 && value.sequence >= 0 && value.sequence < Int.max
    }
}
