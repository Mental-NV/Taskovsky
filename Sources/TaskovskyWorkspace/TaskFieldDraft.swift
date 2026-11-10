import Foundation

public enum TaskDraftField: String, Codable, Sendable { case title, plainBody }

/// Scratch content only: compact revisions, not a second workspace snapshot.
public struct TaskFieldDraft: LocalDraftRecord {
    public let version: Int
    public let id: UUID
    public let taskID: UUID
    public let field: TaskDraftField
    public let baseRevision: WorkspaceRevision
    public let originalText: String
    public private(set) var text: String
    public private(set) var sequence: Int
    public private(set) var updatedAt: Date

    public init(id: UUID = UUID(), taskID: UUID, field: TaskDraftField, baseRevision: WorkspaceRevision,
                text: String, now: Date = Date()) {
        version = 1; self.id = id; self.taskID = taskID; self.field = field
        self.baseRevision = baseRevision; originalText = text; self.text = text
        sequence = 0; updatedAt = now
    }
    public var hasChanges: Bool { !text.utf16.elementsEqual(originalText.utf16) }
    public mutating func replaceText(_ value: String, now: Date = Date()) {
        guard !value.utf16.elementsEqual(text.utf16) else { return }
        text = value; updatedAt = now
        let next = sequence.addingReportingOverflow(1)
        sequence = next.overflow ? Int.max : next.partialValue
    }
    public func continues(_ earlier: Self) -> Bool {
        id == earlier.id && taskID == earlier.taskID && field == earlier.field && baseRevision == earlier.baseRevision &&
            originalText.utf16.elementsEqual(earlier.originalText.utf16)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version && lhs.id == rhs.id && lhs.taskID == rhs.taskID && lhs.field == rhs.field &&
        lhs.baseRevision == rhs.baseRevision && lhs.sequence == rhs.sequence && lhs.updatedAt == rhs.updatedAt &&
        lhs.originalText.utf16.elementsEqual(rhs.originalText.utf16) && lhs.text.utf16.elementsEqual(rhs.text.utf16)
    }
}

public protocol LocalDraftRecord: Codable, Equatable, Identifiable, Sendable where ID == UUID {
    var version: Int { get }
    var sequence: Int { get }
    func continues(_ earlier: Self) -> Bool
}
public enum LocalDraftLoad<Record: LocalDraftRecord>: Sendable { case none, available(Record), unavailable }
public typealias FieldDraftLoad = LocalDraftLoad<TaskFieldDraft>
public enum FieldDraftWrite: Equatable, Sendable { case saved, refused, failed }

/// One active editor per session. Closed IDs and older callbacks cannot recreate
/// or replace its file. Unknown draft bytes are never silently overwritten.
public typealias FieldDraftStore = LocalDraftStore<TaskFieldDraft>

public actor LocalDraftStore<Record: LocalDraftRecord> {
    private let fileURL: URL
    private let write: @Sendable (Data, URL) throws -> Void
    private let remove: @Sendable (URL) throws -> Void
    private var reserved: Record?
    private var latestOffered: Record?
    private var closing: Record?

    public init(fileURL: URL,
                write: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: localFileWriteOptions) },
                remove: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.fileURL = fileURL; self.write = write; self.remove = remove
    }
    public func load() -> LocalDraftLoad<Record> {
        let value = read()
        if case .none = value { closing = nil }
        if reserved == nil, closing == nil, case .available(let draft) = value { reserved = draft; latestOffered = draft }
        return value
    }
    public func begin(_ draft: Record) -> FieldDraftWrite {
        guard closing == nil, draft.version == 1, draft.sequence >= 0, draft.sequence < Int.max else { return .refused }
        if reserved == nil {
            switch read() {
            case .none: reserved = draft; latestOffered = draft
            case .available(let existing): reserved = existing; latestOffered = existing
            case .unavailable: return .refused
            }
        }
        return save(draft)
    }
    public func save(_ draft: Record) -> FieldDraftWrite {
        guard let reserved, let latestOffered,
              draft.continues(reserved),
              draft.version == 1, draft.sequence >= latestOffered.sequence, draft.sequence < Int.max,
              draft.sequence != latestOffered.sequence || draft == latestOffered else { return .refused }
        switch read() {
        case .none: break
        case .available(let existing) where existing == reserved: break
        case .available, .unavailable: return .refused
        }
        self.latestOffered = draft
        do {
            try write(JSONEncoder().encode(draft), fileURL)
            self.reserved = draft
            return .saved
        } catch { return .failed }
    }
    public func close(id: UUID) -> FieldDraftWrite {
        guard let expected = reserved ?? closing, expected.id == id else { return .refused }
        // Invalidate before cleanup; delayed saves from this ID are refused.
        // Retain only the exact cleanup candidate so a failed remove is retryable
        // without reopening the identity for writes, even after load().
        reserved = nil; latestOffered = nil; closing = expected
        switch read() {
        case .none: closing = nil; return .saved
        case .available(let existing) where existing == expected:
            do { try remove(fileURL); closing = nil; return .saved } catch { return .failed }
        case .available, .unavailable: return .refused
        }
    }
    private func read() -> LocalDraftLoad<Record> {
        let bytes: Data
        do { bytes = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return .none }
        catch { return .unavailable }
        do {
            let draft = try JSONDecoder().decode(Record.self, from: bytes)
            let encoded = try JSONEncoder().encode(draft)
            guard draft.version == 1, draft.sequence >= 0, draft.sequence < Int.max,
                  JSONKeySafety.hasUniqueKeys(bytes), try canonical(bytes) == canonical(encoded) else { return .unavailable }
            return .available(draft)
        } catch { return .unavailable }
    }
    private func canonical(_ value: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: value), options: .sortedKeys)
    }
}
