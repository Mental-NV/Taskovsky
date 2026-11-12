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
        var journal: (any MacDescriptionJournalAccess)?
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
    private let makeJournal: (MacDescriptionRecoveryDirectory, UUID) throws -> any MacDescriptionJournalAccess
    public private(set) var recoveryErrors: [UUID: String] = [:]
    public private(set) var discoveryError: String?
    private var preparing = Set<UUID>()
    private var compositions: [UUID: (taskID: UUID, content: DescriptionSnapshot)] = [:]
    public convenience init(store: TaskStore) {
        self.init(store: store, makeJournal: { try $0.journal(taskID: $1) })
    }
    init(store: TaskStore, makeJournal: @escaping (MacDescriptionRecoveryDirectory, UUID) throws -> any MacDescriptionJournalAccess) {
        self.store = store; self.makeJournal = makeJournal
        location = try? MacDescriptionRecoveryDirectory(workspaceURL: store.fileURL)
        subscription = store.$data.sink { [weak self] data in self?.receive(data) }
    }
    public var compositionSnapshots: [UUID: DescriptionSnapshot] { compositions.mapValues(\.content) }
    public var taskIDs: [UUID] { nodes.keys.sorted { $0.uuidString < $1.uuidString } }
    public var hasUnsafeMemory: Bool {
        !compositions.isEmpty || nodes.values.contains { node in
            !node.conflicts.isEmpty || (node.draft != nil && node.draft != node.durable && node.displayed != node.saved)
        }
    }
    public var hasAttention: Bool {
        !recoveryErrors.isEmpty || discoveryError != nil || nodes.values.contains { $0.recovered != nil || $0.draft != nil || !$0.conflicts.isEmpty || $0.message != nil }
    }
    public func presentation(for task: TaskItem) -> Presentation? { presentation(taskID: task.id) }
    public func presentation(taskID: UUID) -> Presentation? {
        guard let node = nodes[taskID], let location else { return nil }
        let current = store.data.tasks.filter { $0.id == taskID }
        let task = current.count == 1 ? current.first : nil
        let recovery = node.recovered?.recovery(in: store.data, workspaceID: location.workspaceID)
        return Presentation(content: node.displayed, revision: node.revision,
            editable: !node.loading && node.journal != nil && node.recovered == nil && task.map(isEditable) == true,
            message: node.message, recovery: recovery, conflicts: node.conflicts)
    }
    /// Includes records whose original task was removed, so they remain copyable.
    public func discoverRecovery() async {
        do {
            guard let location else { throw CocoaError(.fileReadInvalidFileName) }
            try location.prepare()
            let ids = try location.savedTaskIDs()
            discoveryError = nil
            for id in ids { await prepare(taskID: id) }
        } catch { discoveryError = "Description recovery could not be listed safely. Existing files were not changed." }
        objectWillChange.send()
    }
    public func prepare(taskID: UUID) async {
        guard nodes[taskID] == nil, !preparing.contains(taskID) else { return }
        preparing.insert(taskID)
        defer { preparing.remove(taskID); objectWillChange.send() }
        let matches = store.data.tasks.filter { $0.id == taskID }
        let task = matches.count == 1 ? matches.first : nil
        let snapshot = task.flatMap { DescriptionSnapshot(body: $0.body, rich: $0.richBody) }
        do {
            guard let location else { throw CocoaError(.fileWriteInvalidFileName) }
            try location.prepare(); let journal = try makeJournal(location, taskID)
            let loaded = await journal.load()
            let node: Node
            switch loaded {
            case .none:
                guard let snapshot else {
                    recoveryErrors[taskID] = "Description is missing or unsupported. Editing is paused; no data was replaced."
                    return
                }
                node = Node(snapshot)
            case .unavailable:
                recoveryErrors[taskID] = "Recovery data could not be read safely. It has not been replaced."
                return
            case .available(let record):
                node = Node(snapshot ?? record.baseline)
                node.recovered = record
                node.message = "A saved description draft needs your review."
            }
            node.journal = journal; node.loading = false; nodes[taskID] = node
            recoveryErrors.removeValue(forKey: taskID); receive(store.data)
        } catch { recoveryErrors[taskID] = "Description recovery is unavailable. Editing is paused to protect your text." }
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
    /// Marked text stays in AppKit. This memory-only copy protects teardown/quit,
    /// but is not a claim that the input-method composition itself is durable.
    public func hasComposition(editorID: UUID) -> Bool { compositions[editorID] != nil }
    public func trackComposition(taskID: UUID, editorID: UUID, content: DescriptionSnapshot?) {
        if let content { compositions[editorID] = (taskID, content) }
        else { compositions.removeValue(forKey: editorID) }
        objectWillChange.send()
    }
    public func retainUncommitted(taskID: UUID, editorID: UUID, content: DescriptionSnapshot) {
        let node: Node
        if let existing = nodes[taskID] { node = existing }
        else { node = Node(content); node.loading = false }
        nodes[taskID] = node
        node.conflicts[editorID] = content
        node.message = "Uncommitted editor text is retained for copying. It has not been saved to the task."
        compositions.removeValue(forKey: editorID)
        objectWillChange.send()
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
    public func canDiscardCurrent(taskID: UUID) -> Bool {
        guard let node = nodes[taskID] else { return false }
        return !node.running && !node.loading && node.draft != nil && node.recovered == nil
            && !compositions.values.contains(where: { $0.taskID == taskID })
    }
    public func discardCurrent(taskID: UUID, expectedContent: DescriptionSnapshot, expectedRevision: Int) async {
        guard let node = nodes[taskID], !node.running, !node.loading, node.recovered == nil,
              node.revision == expectedRevision, node.displayed == expectedContent,
              let captured = node.draft, captured.content == expectedContent, let journal = node.journal,
              !compositions.values.contains(where: { $0.taskID == taskID }) else { return }
        node.loading = true; objectWillChange.send()
        // If cleanup is pending, this newer draft has not been offered yet.
        let result: FieldDraftWrite
        if let cleanup = node.cleanup { result = await journal.close(cleanup) }
        else { result = await journal.abandon(captured) }
        node.loading = false
        guard node.draft == captured, node.revision == expectedRevision else {
            node.message = "The draft changed while discard was pending. Text remains retained."
            objectWillChange.send(); return
        }
        if result == .saved {
            node.draft = nil; node.durable = nil; node.cleanup = nil; node.message = nil
            receive(store.data)
        } else { node.message = "The draft could not be discarded safely. It remains retained for retry or copying." }
        objectWillChange.send()
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
        while nodes.values.contains(where: { $0.running || $0.loading }) { try? await Task.sleep(nanoseconds: 10_000_000) }
    }
    private func start(_ id: UUID, node: Node) {
        guard !node.running, !node.loading, node.journal != nil, node.recovered == nil else { return }
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
        DescriptionSnapshot(body: task.body, rich: task.richBody) != nil && task.deletedAt == nil && !store.data.lists.contains { $0.id == task.listID && $0.isArchived }
    }
    private func receive(_ workspace: WorkspaceData) {
        for (id, node) in nodes where node.draft == nil && node.recovered == nil && !node.loading {
            guard let task = workspace.tasks.first(where: { $0.id == id }), let value = DescriptionSnapshot(body: task.body, rich: task.richBody) else { continue }
            if value != node.displayed { node.saved = value; node.displayed = value; node.revision += 1 }
        }
        objectWillChange.send()
    }
}
