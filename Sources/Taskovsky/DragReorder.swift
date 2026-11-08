import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TaskovskyCore

extension UTType {
    /// Distinct in-app drag types so task, list, folder, and smart payloads
    /// can never be read as each other. Registered `.ownProcess`: other apps
    /// neither offer nor accept these types. Unknown external content never
    /// matches any of them.
    static let taskovskyTask = UTType(exportedAs: "com.taskovsky.task")
    static let taskovskyList = UTType(exportedAs: "com.taskovsky.list")
    static let taskovskyFolder = UTType(exportedAs: "com.taskovsky.folder")
    static let taskovskySmart = UTType(exportedAs: "com.taskovsky.smart")
    static let taskovskyTag = UTType(exportedAs: "com.taskovsky.tag")
}

/// Native in-app provider for the task UTType, the only native drag source
/// left (task-row grips dropping onto Inbox/list rows). List, folder, smart,
/// and tag moves run through the in-app engine instead, so their providers
/// were removed with their dead native sources. Both ends are ours (payload
/// structs live in TaskovskyCore), so encoding and decoding always agree.
enum DragProviders {
    static func task(_ payload: TaskDragPayload) -> NSItemProvider {
        let provider = NSItemProvider()
        let encoded = (try? JSONEncoder().encode(payload)) ?? Data()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.taskovskyTask.identifier, visibility: .ownProcess) { completion in
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
/// with the collected data (nil when any load failed). Shared with the
/// Kanban column drops so every task drop decodes through one helper.
func loadBatch(_ providers: [NSItemProvider], type: UTType, finish: @escaping ([Data]?) -> Void) {
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
/// Task rows keep using this unchanged.
struct EdgeLine: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1).fill(accent)
            .frame(height: 2).padding(.horizontal, 10)
            .allowsHitTesting(false)
    }
}

/// TickTick-style sidebar insertion marker: a 2pt accent line with a hollow
/// 8pt ring at its leading end, inset ~28pt from the row's leading edge and
/// extending near its trailing edge. The 8pt-tall view centers the 2pt line
/// on the row edge via a ±4pt overlay offset at the call site, so layout
/// never moves. Visual only.
struct SidebarInsertionLine: View {
    /// Leading inset from the row's leading edge; nested list rows inherit
    /// their outer indentation automatically, so the same value works.
    var leadingInset: CGFloat = 28
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .strokeBorder(accent, lineWidth: 1.5)
                .frame(width: 8, height: 8)
            RoundedRectangle(cornerRadius: 1).fill(accent)
                .frame(height: 2)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, 10)
        .allowsHitTesting(false)
    }
}

/// Shared insertion-edge overlay for all four sidebar row types: the marker
/// sits exactly on the hovered edge (±4pt centers the 8pt-tall marker on it)
/// and clears with the row's targeted state on exit and completion.
struct SidebarEdgeOverlay: ViewModifier {
    let targeted: Bool
    let edge: DropEdge?
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) { if targeted && edge == .above { SidebarInsertionLine().offset(y: -4) } }
            .overlay(alignment: .bottom) { if targeted && edge == .below { SidebarInsertionLine().offset(y: 4) } }
    }
}

extension View {
    func sidebarInsertionEdge(targeted: Bool, edge: DropEdge?) -> some View {
        modifier(SidebarEdgeOverlay(targeted: targeted, edge: edge))
    }
}

/// Native task-drop receiver for Inbox and list rows (task payloads arriving
/// from task-row grips). List/smart/folder/tag moves run through the in-app
/// engine instead, so this delegate advertises tasks only and always presents
/// the full-row highlight. All providers decode first and the batch commits
/// at most once: malformed or duplicate-bearing batches resolve to no
/// mutation. Rejections leave no trace.
struct SidebarTaskDropDelegate: DropDelegate {
    let onHover: (Bool) -> Void
    let onDropTasks: ([UUID]) -> Bool

    private var taskType: UTType { .taskovskyTask }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [taskType])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        onHover(true)
    }

    /// Move proposal (not the native copy cursor) for the dragged tasks.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { return nil }
        onHover(true)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onHover(false)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { onHover(false); return false }
        let taskProviders = info.itemProviders(for: [taskType]).filter { $0.hasItemConformingToTypeIdentifier(taskType.identifier) }
        guard !taskProviders.isEmpty else { onHover(false); return false }
        onHover(false)
        loadBatch(taskProviders, type: taskType) { datas in
            guard let datas, let ids = DragBatch.combinedTaskIDs(from: datas) else { return }
            Task { @MainActor in _ = onDropTasks(ids) }
        }
        return true
    }
}

/// Shared in-app sidebar drag session owned by the workspace and used by all
/// four draggable row types. The minimum-distance DragGesture on each row
/// feeds `SidebarDragEngine` (the same driver the regression tests exercise);
/// this coordinator only mirrors engine state into published view state,
/// holds the captured row preview, and routes the engine's release decision
/// through `SidebarDragPolicy` into the store. Native task drops onto
/// Inbox/list rows keep their dedicated receiver; this session never reads or
/// writes an NSDragging session.
@MainActor
final class SidebarDragCoordinator: ObservableObject {
    /// Active dragged payload, nil when idle.
    @Published var active: SidebarDragPayload?
    /// Independent preview content captured from the source row's
    /// presentation (title, icon, count, color, disclosure) — never an
    /// `AnyView` proxy of the transient modifier content.
    @Published var preview: SidebarDragPreview?
    /// Source row width the preview mirrors.
    @Published var previewWidth: CGFloat = 199
    /// Latest pointer location in the workspace coordinate space.
    @Published var pointer = CGPoint.zero
    /// Current hover target, gated by the engine through the policy.
    @Published var hover: SidebarDropTarget?
    /// Insertion edge for the hovered reorder target; nil for assign
    /// highlights (folder/root) and when nothing is hovered.
    @Published var edge: DropEdge?
    /// Latest registered target frames in workspace coordinates. Replaced
    /// wholesale on every preference pass, so hidden sidebars (which register
    /// nothing) leave no stale frames behind. Plain storage (not published):
    /// preference passes must not re-render by themselves.
    var frames: [SidebarDropTarget: [CGRect]] = [:] {
        didSet { if engine.isActive { resync() } }
    }
    /// Visible scroll-viewport frame of the active sidebar, in workspace
    /// coordinates. Hit tests fail closed without it, so a scrolled-out
    /// target can never accept a drop outside the visible pane.
    var viewport: CGRect? {
        didSet { if engine.isActive { resync() } }
    }

    private var engine = SidebarDragEngine()
    private var store: TaskStore?
    private var lastStart = CGPoint.zero
    private var lastPayload: SidebarDragPayload?

    func bind(store: TaskStore) { self.store = store }

    var isActive: Bool { engine.isActive }
    var dragging: Bool { engine.isActive }

    /// Feeds one gesture move event into the engine. The row's presentation
    /// snapshot is captured for the floating preview only when the session
    /// actually starts, so idle hover traffic never allocates previews.
    /// The minimum-distance gesture trigger below is unchanged.
    func update(startLocation: CGPoint, payload: SidebarDragPayload, preview: SidebarDragPreview, width: CGFloat, location: CGPoint) {
        lastStart = startLocation
        lastPayload = payload
        let wasActive = engine.isActive
        engine.update(startLocation: startLocation, location: location, payload: payload, frames: frames, viewport: viewport)
        pointer = location
        if engine.isActive, !wasActive {
            self.preview = preview
            previewWidth = width
        }
        sync()
    }

    /// Whether `target` currently shows any custom indicator.
    func isHovered(_ target: SidebarDropTarget) -> Bool {
        engine.isActive && hover == target
    }

    /// Ends the gesture at `location`, re-hit-testing there before deciding.
    /// A release with no matching session (for example after an Escape
    /// cancel) clears the same-sequence suppress flag without committing, so
    /// `.onEnded` can call this unconditionally with no observer race.
    /// Commits happen exactly once, at release.
    @discardableResult
    func gestureEnded(at location: CGPoint) -> Bool {
        pointer = location
        let decision = engine.release(at: location, frames: frames, viewport: viewport)
        sync(clearPreview: true)
        guard case .commit(let payload, let target, let after) = decision, let store else { return false }
        return SidebarDragPolicy.commit(source: payload, target: target, after: after, store: store)
    }

    /// Aborts a live session (Escape, window focus loss). Idle cancels are
    /// no-ops; a same-sequence restart after a live cancel is suppressed by
    /// the engine until the pointer lifts.
    func cancel() {
        engine.cancel()
        sync(clearPreview: true)
    }

    private func sync(clearPreview: Bool = false) {
        active = engine.active
        hover = engine.hover
        edge = engine.edge
        if clearPreview || !engine.isActive { preview = nil }
    }

    /// Re-resolves the hover when frames or the viewport shift mid-drag
    /// (for example a layout pass settling). The engine ignores the call
    /// while a cancel suppress is in force.
    private func resync() {
        guard let payload = lastPayload else { return }
        engine.update(startLocation: lastStart, location: pointer, payload: payload, frames: frames, viewport: viewport)
        sync()
    }
}

/// Collects sidebar drop-target frames in workspace coordinates. Values
/// append per target so distinct affordances can register under their IDs
/// (heading under `.root`, the end strip under `.rootEnd`).
struct SidebarDropFramesKey: PreferenceKey {
    static var defaultValue: [SidebarDropTarget: [CGRect]] = [:]
    static func reduce(value: inout [SidebarDropTarget: [CGRect]], nextValue: () -> [SidebarDropTarget: [CGRect]]) {
        for (key, rects) in nextValue() { value[key, default: []].append(contentsOf: rects) }
    }
}

/// Carries the source row width from its layout pass to the drag gesture.
private struct SidebarSourceSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 199, height: 38)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Drag source shared by all four sidebar row types: a minimum-distance
/// gesture in workspace coordinates that feeds the shared engine and commits
/// once at release. The caller passes an independent `SidebarDragPreview`
/// captured from the row's presentation (title, icon, count, color,
/// disclosure), so the floating card never renders the transient
/// pre-modifier content proxy outside its source modifier. Taps still select
/// (the tap gesture only fires without movement), right-clicks and context
/// menus are untouched, and no nested gesture blocks keyboard activation on
/// the row itself.
struct SidebarDragSource: ViewModifier {
    @EnvironmentObject var coordinator: SidebarDragCoordinator
    let payload: SidebarDragPayload
    let preview: SidebarDragPreview
    @State private var size = CGSize(width: 199, height: 38)
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SidebarSourceSizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(SidebarSourceSizeKey.self) { size = $0 }
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .named("taskovskySidebar"))
                    .onChanged { value in
                        coordinator.update(
                            startLocation: value.startLocation,
                            payload: payload,
                            preview: preview,
                            width: max(CGFloat(SidebarPreviewSpec.minWidth), size.width),
                            location: value.location
                        )
                    }
                    .onEnded { value in coordinator.gestureEnded(at: value.location) }
            )
    }
}

/// Drop-target frame registration shared by all four sidebar row types plus
/// the root affordance. Inactive sidebars (hidden docked panel) register
/// nothing so their off-screen frames can never win a hit test.
struct SidebarDropTargetFrame: ViewModifier {
    let target: SidebarDropTarget
    let active: Bool
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SidebarDropFramesKey.self,
                    value: active ? [target: [proxy.frame(in: .named("taskovskySidebar"))]] : [:]
                )
            }
        )
    }
}

/// Visible scroll-viewport frame of the active sidebar, in workspace
/// coordinates. Inactive sidebars report nil; the last non-nil frame wins so
/// a hidden panel can never shrink the gate.
struct SidebarViewportKey: PreferenceKey {
    static var defaultValue: CGRect?
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue() { value = next }
    }
}

extension View {
    func sidebarDragSource(_ payload: SidebarDragPayload, preview: SidebarDragPreview) -> some View {
        modifier(SidebarDragSource(payload: payload, preview: preview))
    }
    func sidebarDropTargetFrame(_ target: SidebarDropTarget, active: Bool) -> some View {
        modifier(SidebarDropTargetFrame(target: target, active: active))
    }
    func sidebarViewportFrame(active: Bool) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SidebarViewportKey.self,
                    value: active ? proxy.frame(in: .named("taskovskySidebar")) : nil
                )
            }
        )
    }
}

/// Floating in-app drag image for sidebar rows, rendered purely from the
/// captured `SidebarDragPreview` (title, icon, count, color, disclosure) at
/// the source width and row height: an opaque adaptive card under a subtle
/// blue tint and shadow, with one assembled opacity. The layout mirrors the
/// row label (same icon frame, fonts, dot, and count) reusing ListSymbol and
/// CalendarSymbol. It carries no drag source, no drop target, no hit testing,
/// and no accessibility presence, so it is purely visual and can never
/// intercept events or register a second session. Rendered once at the
/// workspace level (not per row), so it can cross the sidebar edge.
struct SidebarFloatingPreview: View {
    let preview: SidebarDragPreview
    let width: CGFloat
    var body: some View {
        HStack(spacing: 10) {
            if preview.showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Group {
                switch preview.leading {
                case .listSymbol(let symbol):
                    ListSymbol(symbol: symbol)
                case .calendarText(let text):
                    CalendarSymbol(text: text)
                case .systemImage(let name):
                    Image(systemName: name).font(.system(size: 16)).frame(width: 20)
                case .folder:
                    Image(systemName: "folder").font(.system(size: 14)).frame(width: 20)
                }
            }
            .foregroundStyle(.primary)
            .frame(width: 20)
            Text(preview.title).font(.system(size: 14)).lineLimit(1)
            if let hex = preview.colorHex {
                Circle().fill(Color(hex: hex)).frame(width: 7, height: 7).accessibilityHidden(true)
            }
            Spacer(minLength: 2)
            if let count = preview.count, count > 0 {
                Text("\(count)").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .frame(width: max(CGFloat(SidebarPreviewSpec.minWidth), width), height: CGFloat(SidebarPreviewSpec.height))
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).fill(accent.opacity(0.12)))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
        .opacity(SidebarPreviewSpec.opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Sidebar list row: native task-drop target (from task rows) plus the
/// in-app reorder source/target for list moves. List reorder, folder/root
/// assignment, and the floating preview all run through the shared engine;
/// the native drop advertises tasks only. Highlight and insertion line are
/// drawn by the row itself; nothing covers the row, so taps, right-clicks,
/// and context menus keep working.
struct SidebarDropRow<Content: View>: View {
    /// Nil for Inbox (task target only, not draggable, not reorderable).
    let listID: UUID?
    /// Independent preview for the floating card; nil for Inbox (never a
    /// drag source).
    let preview: SidebarDragPreview?
    /// False while the containing sidebar is hidden, so off-screen frames
    /// are never registered for hit testing.
    var framesActive: Bool = true
    let onDropTasks: ([UUID]) -> Bool
    let content: () -> Content
    @EnvironmentObject var coordinator: SidebarDragCoordinator
    @State private var taskTargeted = false
    var body: some View {
        let customTarget: SidebarDropTarget? = listID.map { .list($0) }
        let customHovered = customTarget.map { coordinator.isHovered($0) } ?? false
        let customEdge: DropEdge? = customHovered ? coordinator.edge : nil
        // Native task-drop state and custom in-app state never co-occur (only
        // one pointer drag exists at a time); the merge keeps both visuals.
        // Task drops always highlight the full row; reorder markers come only
        // from the in-app engine.
        Group {
            if let listID, let customTarget, let preview {
                content()
                    .sidebarDragSource(.list(listID), preview: preview)
                    .sidebarDropTargetFrame(customTarget, active: framesActive)
            } else {
                content()
            }
        }
        .background((taskTargeted || customHovered) && customEdge == nil ? accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .sidebarInsertionEdge(targeted: customHovered, edge: customEdge)
        .onDrop(of: [.taskovskyTask], delegate: SidebarTaskDropDelegate(
            onHover: { taskTargeted = $0 },
            onDropTasks: onDropTasks
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
        // Any list/smart/folder/tag-bearing mixed drop is rejected outright:
        // task rows never reorder a valid task while silently ignoring an
        // accompanying foreign payload. Sorted-policy rejection happens in
        // the commit handler (with a user message), not here, so drops still
        // reach the handler to explain themselves.
        enabled
            && info.hasItemsConforming(to: [taskType])
            && !info.hasItemsConforming(to: [.taskovskyList])
            && !info.hasItemsConforming(to: [.taskovskySmart])
            && !info.hasItemsConforming(to: [.taskovskyFolder])
            && !info.hasItemsConforming(to: [.taskovskyTag])
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

/// Drop-only halves for one task row. Drag-out moved to the dedicated grip
/// inside TaskRow so title editing, text selection, and checks are never a
/// drag source. Sorted-policy rejection happens in the commit handler with a
/// user message; validation only enforces active state and pure type hygiene.
struct TaskRowDragDrop: ViewModifier {
    let id: UUID
    let title: String
    let active: Bool
    let onReorder: ([UUID], UUID, Bool) -> Void
    @State private var targeted = false
    @State private var edge: DropEdge?
    @State private var heightBox = RowHeightBox()
    func body(content: Content) -> some View {
        droppable(content)
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
                enabled: active,
                rowHeight: { heightBox.height },
                onHover: { targeted, edge in self.targeted = targeted; self.edge = edge },
                onDrop: onReorder
            ))
    }
}

/// Dedicated reorder grip: six dots on the row's leading edge. The 14pt slot
/// is always reserved so the row never jumps; the dots appear on hover or
/// selection. Native `.onDrag` attaches here, never to the whole row. Clicking
/// (or its accessible action) selects the row when manual, or reports the
/// sorted-mode message when reordering is disabled. No grip for trashed rows.
struct TaskReorderGrip: View {
    let id: UUID
    let title: String
    let active: Bool
    /// Selected state from the row; hover is tracked internally so the dots
    /// appear on hover OR selection while the 14pt slot stays reserved.
    let visible: Bool
    let onActivate: () -> Void
    @State private var hovering = false
    private var shown: Bool { visible || hovering }
    var body: some View {
        Group {
            if active {
                // Code-native six dots with explicit foreground and opacity:
                // no symbol-font/template ambiguity, so a selected row always
                // paints its handle. Opacity (not a clear color) hides the
                // dots without changing layout or the 14pt hit slot.
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 3) {
                            Circle().frame(width: 3, height: 3)
                            Circle().frame(width: 3, height: 3)
                        }
                    }
                }
                .frame(width: 14, height: 20)
                .foregroundStyle(Color.secondary)
                .opacity(shown ? 1 : 0)
                .contentShape(Rectangle())
                    .onHover { hovering = $0 }
                    .onTapGesture(perform: onActivate)
                    .accessibilityLabel("Reorder \(title)")
                    .accessibilityHint("Drag to reorder. Activating selects the task, or explains why reordering is unavailable while sorted.")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(named: "Reorder") { onActivate() }
                    .onDrag { DragProviders.task(TaskDragPayload(ids: [id])) } preview: {
                        CompactDragPreview(title: title, count: 1)
                    }
            } else {
                Color.clear.frame(width: 14, height: 20)
            }
        }
        .frame(width: 14)
    }
}

/// Smart sidebar row: in-app reorder source and drop target. Hover gating,
/// the insertion marker, and the release commit all run through the shared
/// engine; no native drag source or drop delegate remains. Visual-only
/// indicators; taps, keyboard, and context menus keep working.
struct SmartDropRow<Content: View>: View {
    let key: SmartListKey
    let preview: SidebarDragPreview
    /// False while the containing sidebar is hidden.
    var framesActive: Bool = true
    let content: () -> Content
    @EnvironmentObject var coordinator: SidebarDragCoordinator
    var body: some View {
        let target = SidebarDropTarget.smart(key)
        let hovered = coordinator.isHovered(target)
        let edge: DropEdge? = hovered ? coordinator.edge : nil
        content()
            .sidebarDragSource(.smart(key), preview: preview)
            .sidebarDropTargetFrame(target, active: framesActive)
            .background(hovered && edge == nil ? accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .sidebarInsertionEdge(targeted: hovered, edge: edge)
    }
}

/// Folder sidebar row: in-app folder source and drop target (list assigns
/// highlight the full row, folder reorders show the insertion marker).
/// Hover gating, marker, and commit all run through the shared engine; no
/// native drag source or drop delegate remains. Visual-only indicators;
/// disclosure taps, keyboard, and menus keep working.
struct FolderDropRow<Content: View>: View {
    let folderID: UUID
    let preview: SidebarDragPreview
    /// False while the containing sidebar is hidden.
    var framesActive: Bool = true
    let content: () -> Content
    @EnvironmentObject var coordinator: SidebarDragCoordinator
    var body: some View {
        let target = SidebarDropTarget.folder(folderID)
        let hovered = coordinator.isHovered(target)
        let edge: DropEdge? = hovered ? coordinator.edge : nil
        content()
            .sidebarDragSource(.folder(folderID), preview: preview)
            .sidebarDropTargetFrame(target, active: framesActive)
            .background(hovered && edge == nil ? accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .sidebarInsertionEdge(targeted: hovered, edge: edge)
    }
}

/// Tag sidebar row: in-app reorder source and drop target. Hover gating, the
/// insertion marker, and the release commit all run through the shared
/// engine; no native drag source or drop delegate remains. Taps, context
/// menus, and keyboard keep working; the source row is never dimmed and the
/// floating preview mirrors the row at its own width.
struct TagDropRow<Content: View>: View {
    let tagID: UUID
    let preview: SidebarDragPreview
    /// False while the containing sidebar is hidden.
    var framesActive: Bool = true
    let content: () -> Content
    @EnvironmentObject var coordinator: SidebarDragCoordinator
    var body: some View {
        let target = SidebarDropTarget.tag(tagID)
        let hovered = coordinator.isHovered(target)
        let edge: DropEdge? = hovered ? coordinator.edge : nil
        content()
            .sidebarDragSource(.tag(tagID), preview: preview)
            .sidebarDropTargetFrame(target, active: framesActive)
            .background(hovered && edge == nil ? accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .sidebarInsertionEdge(targeted: hovered, edge: edge)
    }
}
