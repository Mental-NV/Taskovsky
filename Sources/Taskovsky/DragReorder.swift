import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TaskovskyCore

extension UTType {
    /// Distinct in-app drag types so task and list payloads can never be read
    /// as each other. Registered `.ownProcess`: other apps neither offer nor
    /// accept these types. Unknown external content never matches either type.
    static let taskovskyTask = UTType(exportedAs: "com.taskovsky.task")
    static let taskovskyList = UTType(exportedAs: "com.taskovsky.list")
}

/// Native in-app providers carrying JSON for our distinct UTTypes. Both ends
/// are ours (payload structs live in TaskovskyCore), so encoding and
/// decoding always agree.
enum DragProviders {
    static func task(_ payload: TaskDragPayload) -> NSItemProvider {
        provider(type: .taskovskyTask, encoded: (try? JSONEncoder().encode(payload)) ?? Data())
    }

    static func list(_ payload: ListDragPayload) -> NSItemProvider {
        provider(type: .taskovskyList, encoded: (try? JSONEncoder().encode(payload)) ?? Data())
    }

    private static func provider(type: UTType, encoded: Data) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess) { completion in
            completion(encoded, nil)
            return nil
        }
        return provider
    }
}

/// Collects async provider loads in provider-array order, then resolves once.
/// A failed load poisons the batch so aggregation can never validate a
/// subset. Thread-safe: completions may arrive on background queues.
private final class BatchCollector {
    private let lock = NSLock()
    private var slots: [Data?]
    private var pending: Int
    private var failed = false
    private let done: ([Data]?) -> Void

    init(count: Int, done: @escaping ([Data]?) -> Void) {
        self.slots = [Data?](repeating: nil, count: count)
        self.pending = count
        self.done = done
    }

    func complete(index: Int, data: Data?) {
        lock.lock()
        if pending > 0 {
            if let data { slots[index] = data } else { failed = true }
            pending -= 1
        }
        let finished = pending == 0
        let result: [Data]? = finished ? (failed ? nil : slots.map { $0 ?? Data() }) : nil
        lock.unlock()
        if finished { done(result) }
    }
}

/// Loads every provider's representation, then calls `finish` exactly once
/// with the collected data (nil when any load failed).
private func loadBatch(_ providers: [NSItemProvider], type: UTType, finish: @escaping ([Data]?) -> Void) {
    let collector = BatchCollector(count: providers.count, done: finish)
    for (index, provider) in providers.enumerated() {
        provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
            collector.complete(index: index, data: data)
        }
    }
}

/// Compact drag preview: a single line with an optional count badge, never
/// a snapshot of the full row.
struct CompactDragPreview: View {
    let title: String
    let count: Int
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
            if count > 1 {
                Text("\(count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(accent, in: Capsule())
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        .frame(maxWidth: 260)
    }
}

/// 2pt accent insertion line. Visual only: hit testing stays with the row.
struct EdgeLine: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1).fill(accent)
            .frame(height: 2).padding(.horizontal, 10)
            .allowsHitTesting(false)
    }
}

/// One delegate per row receiving both payload types. `onDrop`/`onDrag` are
/// modifiers on the row itself, never covering overlays, so ordinary Button
/// clicks, right-clicks, drag initiation, and context menus keep working.
/// Task payloads on a move target highlight the full row; list payloads on a
/// list row show an above/below insertion line from the live pointer location
/// (halves of the fixed 38pt rows). All providers decode first and the batch
/// commits at most once: mixed types, malformed data, or ambiguous lists
/// resolve to no mutation. Rejections leave no trace.
struct SidebarDropDelegate: DropDelegate {
    /// Fixed 38pt sidebar rows split exactly in halves; no geometry reads.
    static let rowHeight: CGFloat = 38
    /// Inbox and list rows accept task payloads; other rows accept nothing.
    let acceptsTasks: Bool
    /// Non-nil for list rows, which additionally accept list reorder payloads.
    let listID: UUID?
    let onHover: (Bool, DropEdge?) -> Void
    let onDropTasks: ([UUID]) -> Bool
    let onReorderList: (UUID, Bool) -> Void

    private var taskType: UTType { .taskovskyTask }
    private var listType: UTType { .taskovskyList }

    func validateDrop(info: DropInfo) -> Bool {
        if acceptsTasks && info.hasItemsConforming(to: [taskType]) { return true }
        if listID != nil && info.hasItemsConforming(to: [listType]) { return true }
        return false
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        onHover(true, edgeIfReorder(info: info))
    }

    /// Move proposal (not the native copy cursor) with a live edge while the
    /// pointer travels between halves.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { return nil }
        onHover(true, edgeIfReorder(info: info))
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onHover(false, nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { onHover(false, nil); return false }
        let after = edgeIfReorder(info: info) == .below
        let taskProviders = info.itemProviders(for: [taskType]).filter { $0.hasItemConformingToTypeIdentifier(taskType.identifier) }
        let listProviders = info.itemProviders(for: [listType]).filter { $0.hasItemConformingToTypeIdentifier(listType.identifier) }
        guard !taskProviders.isEmpty || !listProviders.isEmpty else { onHover(false, nil); return false }
        onHover(false, nil)
        // Mixed task+list batches are ambiguous: aggregate to no mutation.
        guard taskProviders.isEmpty || listProviders.isEmpty else { return true }
        if !taskProviders.isEmpty {
            loadBatch(taskProviders, type: taskType) { datas in
                guard let datas, let ids = DragBatch.combinedTaskIDs(from: datas) else { return }
                Task { @MainActor in _ = onDropTasks(ids) }
            }
        } else if listID != nil {
            loadBatch(listProviders, type: listType) { datas in
                guard let datas, let moving = DragBatch.singleListID(from: datas) else { return }
                Task { @MainActor in onReorderList(moving, after) }
            }
        }
        return true
    }

    private func edgeIfReorder(info: DropInfo) -> DropEdge? {
        guard listID != nil, info.hasItemsConforming(to: [listType]) else { return nil }
        return DropEdge.forLocation(y: info.location.y, height: Self.rowHeight)
    }
}

/// Sidebar row with unified typed drops and (for lists) native drag-out.
/// Highlight and insertion line are drawn by the row itself; nothing covers
/// the Button, so clicks and context menus are untouched.
struct SidebarDropRow<Content: View>: View {
    let title: String
    /// Nil for Inbox (move target only, not draggable, not reorderable).
    let listID: UUID?
    let onDropTasks: ([UUID]) -> Bool
    let onReorderList: (UUID, Bool) -> Void
    let content: () -> Content
    @State private var targeted = false
    @State private var edge: DropEdge?
    var body: some View {
        Group {
            if let listID {
                content()
                    .onDrag { DragProviders.list(ListDragPayload(id: listID)) } preview: {
                        CompactDragPreview(title: title, count: 1)
                    }
            } else {
                content()
            }
        }
        .background(targeted && edge == nil ? accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .top) { if targeted && edge == .above { EdgeLine() } }
        .overlay(alignment: .bottom) { if targeted && edge == .below { EdgeLine() } }
        .onDrop(of: [.taskovskyTask, .taskovskyList], delegate: SidebarDropDelegate(
            acceptsTasks: true,
            listID: listID,
            onHover: { targeted, edge in self.targeted = targeted; self.edge = edge },
            onDropTasks: onDropTasks,
            onReorderList: onReorderList
        ))
    }
}

/// Task-row drops for Manual-sort in-group reordering. The insertion edge is
/// the row's own vertical midpoint, read from a hit-test-transparent overlay
/// that never writes layout state: it only refreshes a plain box the drop
/// handler consults, so there is no measurement feedback loop. Commits happen
/// atomically on drop only; non-manual sorts reject at validation.
/// Deleted rows do not participate: `enabled` always includes the row's
/// active state, and the store refuses deleted records as well.
struct TaskRowDropDelegate: DropDelegate {
    let target: UUID
    let enabled: Bool
    /// Current row height; consulted only when resolving the drop edge.
    let rowHeight: () -> CGFloat
    let onHover: (Bool, DropEdge?) -> Void
    let onDrop: ([UUID], UUID, Bool) -> Void

    private var taskType: UTType { .taskovskyTask }

    func validateDrop(info: DropInfo) -> Bool {
        // A list-bearing mixed drop is rejected outright: like the sidebar
        // delegate, task rows never reorder a valid task while silently
        // ignoring an accompanying list payload.
        enabled
            && info.hasItemsConforming(to: [taskType])
            && !info.hasItemsConforming(to: [.taskovskyList])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        onHover(true, edge(for: info))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { return nil }
        onHover(true, edge(for: info))
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onHover(false, nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { onHover(false, nil); return false }
        let after = edge(for: info) == .below
        let providers = info.itemProviders(for: [taskType]).filter { $0.hasItemConformingToTypeIdentifier(taskType.identifier) }
        guard !providers.isEmpty else { onHover(false, nil); return false }
        onHover(false, nil)
        // Every provider decodes before anything commits: one valid plus one
        // invalid resolves to no mutation, never a partial move.
        loadBatch(providers, type: taskType) { datas in
            guard let datas, let ids = DragBatch.combinedTaskIDs(from: datas) else { return }
            Task { @MainActor in onDrop(ids, target, after) }
        }
        return true
    }

    private func edge(for info: DropInfo) -> DropEdge {
        DropEdge.forLocation(y: info.location.y, height: rowHeight())
    }
}

/// Holds the latest measured row height without participating in layout.
/// Mutating the box never invalidates the view, so the drop handler always
/// consults a fresh midpoint with zero feedback into layout.
private final class RowHeightBox {
    var height: CGFloat = 40
}

/// Native row dragging plus Manual-sort drop halves for one task row.
struct TaskRowDragDrop: ViewModifier {
    let id: UUID
    let title: String
    let active: Bool
    let reorderEnabled: Bool
    let onReorder: ([UUID], UUID, Bool) -> Void
    @State private var targeted = false
    @State private var edge: DropEdge?
    @State private var heightBox = RowHeightBox()
    func body(content: Content) -> some View {
        Group {
            if active {
                droppable(content)
                    .onDrag { DragProviders.task(TaskDragPayload(ids: [id])) } preview: {
                        CompactDragPreview(title: title, count: 1)
                    }
            } else {
                droppable(content)
            }
        }
    }

    private func droppable(_ content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { heightBox.height = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, height in heightBox.height = height }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) { if targeted && edge == .above { EdgeLine() } }
            .overlay(alignment: .bottom) { if targeted && edge == .below { EdgeLine() } }
            .onDrop(of: [.taskovskyTask], delegate: TaskRowDropDelegate(
                target: id,
                enabled: active && reorderEnabled,
                rowHeight: { heightBox.height },
                onHover: { targeted, edge in self.targeted = targeted; self.edge = edge },
                onDrop: onReorder
            ))
    }
}
