import Foundation
import TaskovskyDomain

public struct TaskCaptureDraft: LocalDraftRecord {
    public let version: Int
    public let id: UUID
    public let baseRevision: WorkspaceRevision
    public let calendar: Calendar
    public let createdAt: Date
    public let originalInput: TaskCaptureInput
    public private(set) var input: TaskCaptureInput
    public private(set) var preparedTask: TaskItem?
    public private(set) var sequence: Int
    public private(set) var updatedAt: Date
    public init(id: UUID = UUID(), baseRevision: WorkspaceRevision, input: TaskCaptureInput, now: Date = Date(), calendar: Calendar = .current) {
        version = 1; self.id = id; self.calendar = calendar; self.baseRevision = baseRevision; createdAt = now; updatedAt = now
        originalInput = input; self.input = input; sequence = 0
    }
    public var hasChanges: Bool { !exactEncoding(input, originalInput) || preparedTask != nil }
    public mutating func update(_ change: (inout TaskCaptureInput) -> Void) {
        guard preparedTask == nil else { return }
        var next = input; change(&next)
        guard !exactEncoding(next, input) else { return }
        input = next; advance()
    }
    public mutating func prepare(workspace: WorkspaceData, settings: AppSettings) throws {
        guard preparedTask == nil else { return }
        preparedTask = try input.task(id: id, now: createdAt, workspace: workspace, settings: settings, calendar: calendar)
        advance()
    }
    public mutating func confirmedNotSaved() { guard preparedTask != nil else { return }; preparedTask = nil; advance() }
    private mutating func advance() {
        updatedAt = Date(); let next = sequence.addingReportingOverflow(1); sequence = next.overflow ? Int.max : next.partialValue
    }
    public func continues(_ earlier: Self) -> Bool {
        id == earlier.id && baseRevision == earlier.baseRevision && createdAt == earlier.createdAt && calendar == earlier.calendar && exactEncoding(originalInput, earlier.originalInput)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { exactEncoding(lhs, rhs) }
}
public typealias CaptureDraftStore = LocalDraftStore<TaskCaptureDraft>

func exactEncoding<T: Encodable>(_ lhs: T, _ rhs: T) -> Bool {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    guard let one = try? encoder.encode(lhs), let two = try? encoder.encode(rhs) else { return false }
    return one == two
}
