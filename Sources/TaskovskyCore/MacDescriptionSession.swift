import Foundation
import Combine
import TaskovskyWorkspace

/// Shared by main/drawer/popup. AppKit owns live selection, composition and Undo.
@MainActor public final class MacDescriptionSession: ObservableObject {
    public struct Presentation {
        public let content: DescriptionSnapshot
        public let revision: Int
        public let editable: Bool
        public let message: String?
        public let recovery: DescriptionRecovery?
        public let conflicts: [UUID: DescriptionSnapshot]
    }
    private final class Node {
        var saved: DescriptionSnapshot
        var displayed: DescriptionSnapshot
        var revision = 0
        var loading = true
        var journal: MacDescriptionJournal?
        var draft: MacDescriptionDraft?
        var recovered: MacDescriptionDraft?
        var durable: MacDescriptionDraft?
        var cleanup: MacDescriptionDraft?
        var running = false
        var message: String?
        var conflicts: [UUID: DescriptionSnapshot] = [:]
        init(_ value: DescriptionSnapshot) { saved = value; displayed = value }
    }
    private let store: TaskStore
    private let location: MacDescriptionRecoveryDirectory?
    private var nodes: [UUID: Node] = [:]
    private var subscription: AnyCancellable?
    public init(store: TaskStore) {
        self.store = store
        location = try? MacDescriptionRecoveryDirectory(workspaceURL: store.fileURL)
        subscription = store.$data.sink { [weak self] data in self?.receive(data) }
    }
    public var taskIDs: [UUID] { nodes.keys.sorted { $0.uuidString < $1.uuidString } }
    public var hasUnsafeMemory: Bool {
        nodes.values.contains { node in
            !node.conflicts.isEmpty || (node.draft != nil && node.draft != node.durable && node.displayed != node.saved)
        }
    }
    public var hasAttention: Bool {
        nodes.values.contains { $0.recovered != nil || $0.draft != nil || !$0.conflicts.isEmpty || $0.message != nil }
    }
    public func presentation(for task: TaskItem) -> Presentation? {
        guard let node = nodes[task.id] else { return nil }
        let recovery = node.recovered?.recovery(in: store.data, workspaceID: location?.workspaceID ?? UUID())
        return Presentation(content: node.displayed, revision: node.revision,
            editable: !node.loading && node.journal != nil && node.recovered == nil && isEditable(task),
            message: node.message, recovery: recovery, conflicts: node.conflicts)
    }
    public func prepare(taskID: UUID) async {
        guard nodes[taskID] == nil, let task = store.data.tasks.first(where: { $0.id == taskID }),
              let snapshot = DescriptionSnapshot(body: task.body, rich: task.richBody) else { return }
        let node = Node(snapshot); nodes[taskID] = node; objectWillChange.send()
        do {
            guard let location else { throw CocoaError(.fileWriteInvalidFileName) }
            try location.prepare(); let journal = try location.journal(taskID: taskID); node.journal = journal
            switch await journal.load() {
            case .none: break
            case .unavailable: node.journal = nil; node.message = "Recovery data could not be read safely. It has not been replaced."
            case .available(let record):
                node.recovered = record
                node.message = "A saved description draft needs your review."
            }
        } catch { node.message = "Description recovery is unavailable. Editing is paused to protect your text." }
        node.loading = false; receive(store.data); objectWillChange.send()
    }
    /// The expected revision belongs to the actual AppKit rendering, not a refreshed host closure.
    public func propose(taskID: UUID, content: DescriptionSnapshot, expectedRevision: Int, editorID: UUID) -> Int? {
        guard let node = nodes[taskID] else { return nil } // UI must retain candidates until prepare completes.
        let task = store.data.tasks.first(where: { $0.id == taskID })
        guard !node.loading, node.journal != nil, node.recovered == nil, task.map(isEditable) == true, expectedRevision == node.revision else {
            node.conflicts[editorID] = content; node.message = "Another editor or saved value changed. Your local text is kept as a conflict."
            objectWillChange.send(); return nil
        }
        if content == node.displayed { return node.revision }
        guard node.revision < Int.max - 1, let location else {
            node.conflicts[editorID] = content; node.message = "Description cannot be saved. Your local text is retained for copying."
            objectWillChange.send(); return nil
        }
        if node.draft == nil { node.draft = MacDescriptionDraft(workspaceID: location.workspaceID, taskID: taskID, baseline: node.saved) }
        guard node.draft?.replace(with: content) == true else {
            node.conflicts[editorID] = content; node.message = "Description draft cannot advance. Your local text is retained for copying."
            objectWillChange.send(); return nil
        }
        node.displayed = content; node.revision += 1; node.message = "Saving description…"
        objectWillChange.send(); start(taskID, node: node); return node.revision
    }
    public func retry(taskID: UUID) {
        guard let node = nodes[taskID], !node.loading else { return }
        start(taskID, node: node)
    }
    public func resume(taskID: UUID) {
        guard let node = nodes[taskID], let record = node.recovered, let location,
              record.recovery(in: store.data, workspaceID: location.workspaceID) == .retryEligible else { return }
        node.recovered = nil; node.draft = record; node.durable = record
        node.saved = record.baseline; node.displayed = record.content; node.revision += 1
        node.message = "Recovered draft; saving…"; objectWillChange.send(); start(taskID, node: node)
    }
    public func keepSaved(taskID: UUID) async {
        guard let node = nodes[taskID], !node.running, let record = node.recovered, let journal = node.journal else { return }
        node.loading = true; objectWillChange.send()
        let result = await journal.close(record)
        if result == .saved { node.recovered = nil; node.message = nil; node.loading = false; receive(store.data) }
        else { node.message = "The saved draft could not be cleared. It is still preserved." }
        node.loading = false; objectWillChange.send()
    }
    public func conflict(taskID: UUID, editorID: UUID) -> DescriptionSnapshot? { nodes[taskID]?.conflicts[editorID] }
    /// Explicit caller action only; copying alone does not discard the retained candidate.
    public func discardConflict(taskID: UUID, editorID: UUID) {
        guard let node = nodes[taskID] else { return }
        node.conflicts.removeValue(forKey: editorID)
        if node.conflicts.isEmpty, node.draft == nil, node.recovered == nil { node.message = nil }
        objectWillChange.send()
    }
    public func recoveryContent(taskID: UUID) -> DescriptionSnapshot? { nodes[taskID]?.recovered?.content }
    public func finishPending() async {
        for (id, node) in nodes where node.draft != nil || node.cleanup != nil { start(id, node: node) }
        while nodes.values.contains(where: { $0.running }) { try? await Task.sleep(nanoseconds: 10_000_000) }
    }
    private func start(_ id: UUID, node: Node) {
        guard !node.running, node.journal != nil, node.recovered == nil else { return }
        node.running = true
        Task { await persist(id, node: node) }
    }
    private func persist(_ id: UUID, node: Node) async {
        defer { node.running = false; objectWillChange.send() }
        guard let journal = node.journal else { return }
        while true {
            if let cleanup = node.cleanup {
                guard await journal.close(cleanup) == .saved else {
                    node.message = "Description was saved, but recovery cleanup failed. Newer edits remain pending."
                    return
                }
                node.cleanup = nil
            }
            guard let captured = node.draft else { node.message = node.conflicts.isEmpty ? nil : "A local conflict needs your review."; return }
            let outcome = await journal.save(captured)
            guard outcome == .saved else {
                node.message = "Description is not saved. Recovery could not be written; keep this app open and retry or copy your text."
                return
            }
            node.durable = captured
            guard node.draft == captured else { continue }
            guard store.saveDescription(taskID: id, content: captured.content, expected: node.saved) else {
                node.message = "Description is not saved to the task. A recovery copy is saved; retry or copy your text."
                return
            }
            node.saved = captured.content
            // Rotate before awaiting cleanup so newer typing gets a fresh identity.
            node.draft = nil; node.cleanup = captured
            objectWillChange.send()
        }
    }
    private func isEditable(_ task: TaskItem) -> Bool {
        task.deletedAt == nil && !store.data.lists.contains { $0.id == task.listID && $0.isArchived }
    }
    private func receive(_ workspace: WorkspaceData) {
        for (id, node) in nodes where node.draft == nil && node.recovered == nil && !node.loading {
            guard let task = workspace.tasks.first(where: { $0.id == id }), let value = DescriptionSnapshot(body: task.body, rich: task.richBody) else { continue }
            if value != node.displayed { node.saved = value; node.displayed = value; node.revision += 1 }
        }
        objectWillChange.send()
    }
}
