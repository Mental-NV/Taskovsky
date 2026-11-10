import TaskovskyDomain
import Foundation
import CoreGraphics

/// Typed, distinguishable drag payloads shared by the workspace view and its
/// tests. Task moves carry one or more task IDs; list reordering carries
/// exactly one list ID. Validation (existence, deleted records, self-drops,
/// group membership) happens in the store and in the drop delegates; the
/// helpers below only decode and aggregate raw provider data.
public struct TaskDragPayload: Codable, Hashable, Sendable {
    public var ids: [UUID]
    public init(ids: [UUID]) { self.ids = ids }
}

public struct ListDragPayload: Codable, Hashable, Sendable {
    public var id: UUID
    public init(id: UUID) { self.id = id }
}

public struct FolderDragPayload: Codable, Hashable, Sendable {
    public var id: UUID
    public init(id: UUID) { self.id = id }
}

public struct SmartDragPayload: Codable, Hashable, Sendable {
    public var key: SmartListKey
    public init(key: SmartListKey) { self.key = key }
}

/// Tag payloads encode under a distinct `tagID` field (not `id`) so raw
/// cross-type decoding also rejects list/folder bytes; the distinct
/// `.taskovskyTag` UTType separates identical transports regardless.
public struct TagDragPayload: Codable, Hashable, Sendable {
    public var tagID: UUID
    public init(tagID: UUID) { self.tagID = tagID }
}

/// Above/below insertion edge, derived from the drop location in the row's
/// own coordinate space. Pure so the midpoint rule is unit-testable.
public enum DropEdge: Equatable, Sendable {
    case above
    case below

    /// Insertion edge for a pointer at height `y` in a row of `height`.
    /// Degenerate heights fall back to below so a drop always lands on a
    /// valid adjacent position.
    public static func forLocation(y: Double, height: Double) -> DropEdge {
        guard height > 0, y < height / 2 else { return .below }
        return .above
    }
}

/// All-or-nothing batch aggregation over decoded provider data. Every entry
/// must be well-formed and unambiguous before anything commits: any
/// malformed, empty, mixed, or duplicate-bearing batch aggregates to nil and
/// the caller must not mutate. Order follows the provider (array) order so
/// multi-provider batches stay deterministic.
public enum DragBatch {
    /// Combines task IDs across providers in order. Nil when there are no
    /// providers, any entry is malformed or empty, or any ID repeats.
    public static func combinedTaskIDs(from datas: [Data]) -> [UUID]? {
        guard !datas.isEmpty else { return nil }
        var ids: [UUID] = []
        var seen = Set<UUID>()
        for data in datas {
            guard let payload = try? JSONDecoder().decode(TaskDragPayload.self, from: data),
                  !payload.ids.isEmpty,
                  payload.ids.allSatisfy({ seen.insert($0).inserted }) else { return nil }
            ids.append(contentsOf: payload.ids)
        }
        return ids
    }

    /// Requires exactly one well-formed list payload. Nil for zero, multiple,
    /// or malformed entries — a reorder drop is never ambiguous.
    public static func singleListID(from datas: [Data]) -> UUID? {
        guard datas.count == 1,
              let payload = try? JSONDecoder().decode(ListDragPayload.self, from: datas[0]) else { return nil }
        return payload.id
    }

    /// Requires exactly one well-formed folder payload.
    public static func singleFolderID(from datas: [Data]) -> UUID? {
        guard datas.count == 1,
              let payload = try? JSONDecoder().decode(FolderDragPayload.self, from: datas[0]) else { return nil }
        return payload.id
    }

    /// Requires exactly one well-formed smart-list payload.
    public static func singleSmartKey(from datas: [Data]) -> SmartListKey? {
        guard datas.count == 1,
              let payload = try? JSONDecoder().decode(SmartDragPayload.self, from: datas[0]) else { return nil }
        return payload.key
    }

    /// Requires exactly one well-formed tag payload. List/folder bytes use
    /// the `id` field and never decode as the distinct `tagID` shape.
    public static func singleTagID(from datas: [Data]) -> UUID? {
        guard datas.count == 1,
              let payload = try? JSONDecoder().decode(TagDragPayload.self, from: datas[0]) else { return nil }
        return payload.tagID
    }
}

/// In-app sidebar drag payload. One value per draggable sidebar row type;
/// filter rows and the Inbox are never sources.
public enum SidebarDragPayload: Hashable, Sendable {
    case smart(SmartListKey)
    case list(UUID)
    case folder(UUID)
    case tag(UUID)
}

/// In-app sidebar drop target. `.root` is the Lists heading (top root
/// assignment); `.rootEnd` is the unlabeled end strip for trailing root
/// placement below all folders. Both accept lists only.
public enum SidebarDropTarget: Hashable, Sendable {
    case smart(SmartListKey)
    case list(UUID)
    case folder(UUID)
    case tag(UUID)
    case root
    case rootEnd
}

/// Independent floating-preview content for a sidebar drag, captured from the
/// source row's presentation (title, icon, count, color, disclosure) — never a
/// transient `AnyView` proxy rendered outside its source modifier. The app's
/// floating card renders purely from this value.
public struct SidebarDragPreview: Hashable, Sendable {
    /// Leading icon for the preview card.
    public enum Leading: Hashable, Sendable {
        /// Custom list symbol (raw string; empty/nil falls back to default).
        case listSymbol(String?)
        /// Calendar glyph text (day number or weekday letters).
        case calendarText(String)
        /// Plain SF symbol name.
        case systemImage(String)
        /// Folder glyph (used with `showsDisclosure`).
        case folder
    }
    public var title: String
    public var leading: Leading
    public var colorHex: String?
    public var count: Int?
    public var showsDisclosure: Bool
    public init(title: String, leading: Leading, colorHex: String? = nil, count: Int? = nil, showsDisclosure: Bool = false) {
        self.title = title; self.leading = leading; self.colorHex = colorHex; self.count = count; self.showsDisclosure = showsDisclosure
    }
}

/// Pinned spec for the floating preview card the app renders from
/// `SidebarDragPreview`: explicit width floor and row height, one assembled
/// opacity, and the pointer offset. Tested in-repo (no desktop input).
public enum SidebarPreviewSpec {
    public static let minWidth: Double = 80
    public static let height: Double = 38
    public static let opacity: Double = 0.7
    public static let pointerOffsetX: Double = 14
    public static let pointerOffsetY: Double = -24
}

/// How a hovered target presents an in-app sidebar drag: an above/below
/// insertion marker for reorder targets, or a full-row highlight for assign
/// targets (list onto folder/root).
public enum SidebarHoverStyle: Equatable, Sendable {
    case marker(DropEdge)
    case highlight
}

/// Shared validation and commit rules for the in-app sidebar drag path used
/// by all four draggable row types. Hover gating is purely type/group/self
/// based (no store reads) so the marker only appears where a commit could
/// succeed; the commit itself re-validates through the store and reports
/// success. Commits happen exactly once, at release, via `commit`; hovering
/// and cancelling never mutate.
public enum SidebarDragPolicy {
    /// Whether hovering `target` with `source` may show any indicator.
    /// Self-drops, cross-type drops, and cross-group smart moves are
    /// rejected before any marker appears.
    public static func allowsHover(source: SidebarDragPayload, target: SidebarDropTarget) -> Bool {
        switch (source, target) {
        case (.smart(let moving), .smart(let key)):
            guard moving != key else { return false }
            return smartGroup(of: moving) != nil && smartGroup(of: moving) == smartGroup(of: key)
        case (.list(let moving), .list(let key)):
            return moving != key
        case (.list, .folder), (.list, .root):
            return true
        case (.folder(let moving), .folder(let key)):
            return moving != key
        case (.tag(let moving), .tag(let key)):
            return moving != key
        case (.list, .rootEnd):
            return true
        default:
            return false
        }
    }

    /// Presentation for an allowed hover: `nil` when `allowsHover` is false.
    /// Reorder targets resolve the insertion edge from the pointer height in
    /// the row; assign targets highlight the whole row. The pointer height is
    /// relative to the target row top (negative = above, past height = below
    /// clamps to the nearer half via `DropEdge.forLocation`).
    public static func hoverStyle(source: SidebarDragPayload, target: SidebarDropTarget, pointerY: Double, rowHeight: Double) -> SidebarHoverStyle? {
        guard allowsHover(source: source, target: target) else { return nil }
        switch (source, target) {
        case (.list, .folder), (.list, .root), (.list, .rootEnd):
            return .highlight
        default:
            return .marker(DropEdge.forLocation(y: pointerY, height: rowHeight))
        }
    }

    /// Commits a release over `target` (`after` selects the below edge for
    /// reorder targets; assign targets ignore it). Returns the store's
    /// success value; invalid combinations return false without mutating.
    /// Main-actor like the store it writes through.
    @MainActor
    @discardableResult
    public static func commit(source: SidebarDragPayload, target: SidebarDropTarget, after: Bool, store: TaskStore) -> Bool {
        switch (source, target) {
        case (.smart(let moving), .smart(let key)):
            return store.settings.reorderSmartList(moving: moving, before: key, afterTarget: after)
        case (.list(let moving), .list(let key)):
            return store.reorderLists(moving: moving, before: key, afterTarget: after)
        case (.list(let moving), .folder(let folderID)):
            return store.moveListToFolder(listID: moving, folderID: folderID)
        case (.list(let moving), .root):
            return store.moveListToFolder(listID: moving, folderID: nil)
        case (.list(let moving), .rootEnd):
            return store.moveListToRootEnd(listID: moving)
        case (.folder(let moving), .folder(let key)):
            return store.reorderFolders(moving: moving, before: key, afterTarget: after)
        case (.tag(let moving), .tag(let key)):
            return store.reorderTags(moving: moving, before: key, afterTarget: after)
        default:
            return false
        }
    }

    private static func smartGroup(of key: SmartListKey) -> [SmartListKey]? {
        if AppSettings.topSmartGroup.contains(key) { return AppSettings.topSmartGroup }
        if AppSettings.bottomSmartGroup.contains(key) { return AppSettings.bottomSmartGroup }
        return nil
    }
}

/// Release decision returned by `SidebarDragEngine.release(at:frames:viewport:`,
/// re-hit-tested at the release point rather than carried over from the last
/// move event. Stores never see a `.none`: hovering nothing, an invalid
/// target, or a release outside the visible viewport all cancel silently.
public enum SidebarDragRelease: Equatable, Sendable {
    case commit(payload: SidebarDragPayload, target: SidebarDropTarget, after: Bool)
    case none
}

/// Pure in-app sidebar drag lifecycle driver. The app's gesture layer feeds
/// this engine (and these tests drive the same type directly, with no UI):
/// press sequences start the session only past `startThreshold`, every move
/// re-resolves the hover through `SidebarDragPolicy`, and release re-hit-tests
/// at the release coordinates before reporting a commit. Cancelling (Escape,
/// focus loss) suppresses restarts for the remainder of that pointer sequence
/// without blocking the next one; a second source can never hijack a live
/// session. Hit tests fail closed outside the visible scroll viewport, so a
/// scrolled-out target never accepts a drop outside the visible pane.
public struct SidebarDragEngine: Sendable {
    /// Minimum pointer travel from the press point before a session starts,
    /// mirroring the gesture's own minimum distance.
    public static let startThreshold: Double = 8
    public private(set) var active: SidebarDragPayload?
    public private(set) var hover: SidebarDropTarget?
    /// Insertion edge for the hovered reorder target; nil for assign
    /// highlights (folder/root) and when nothing is hovered.
    public private(set) var edge: DropEdge?
    /// True after a mid-sequence cancel until the next pointer sequence (or a
    /// release) clears it. Same-sequence move events are ignored while set.
    public private(set) var suppressUntilNewSequence = false
    /// Press origin of the current pointer sequence; a changed origin re-arms
    /// the driver for the next sequence.
    private var sequenceOrigin: CGPoint?
    public init() {}

    public var isActive: Bool { active != nil }

    /// Feeds one gesture move event. The first call of a sequence (a changed
    /// `startLocation`) re-arms the driver; travel below the threshold keeps
    /// the session idle; a mismatched payload never hijacks a live session.
    public mutating func update(startLocation: CGPoint, location: CGPoint, payload: SidebarDragPayload, frames: [SidebarDropTarget: [CGRect]], viewport: CGRect?) {
        if sequenceOrigin != startLocation {
            sequenceOrigin = startLocation
            suppressUntilNewSequence = false
            active = nil
            hover = nil
            edge = nil
        }
        guard !suppressUntilNewSequence else { return }
        if active == nil {
            let dx = location.x - startLocation.x
            let dy = location.y - startLocation.y
            guard dx * dx + dy * dy >= Self.startThreshold * Self.startThreshold else { return }
            active = payload
        } else if active != payload {
            return
        }
        resolveHover(payload: payload, location: location, frames: frames, viewport: viewport)
    }

    /// Ends the sequence at `location`, re-hit-testing there before deciding.
    /// Always clears the session (and the suppress flag), so a second call is
    /// a no-op `.none`: commits happen exactly once, at release.
    @discardableResult
    public mutating func release(at location: CGPoint, frames: [SidebarDropTarget: [CGRect]], viewport: CGRect?) -> SidebarDragRelease {
        defer {
            active = nil
            hover = nil
            edge = nil
            suppressUntilNewSequence = false
            sequenceOrigin = nil
        }
        guard let payload = active else { return .none }
        guard let hit = Self.hitTest(payload: payload, location: location, frames: frames, viewport: viewport) else { return .none }
        return .commit(payload: payload, target: hit.target, after: hit.edge == .below)
    }

    /// Aborts a live session (Escape, window focus loss). Idle cancels are
    /// no-ops so a stray cancel can never suppress the next drag; the
    /// same-sequence suppress flag blocks restarts until the pointer lifts.
    public mutating func cancel() {
        guard active != nil else { return }
        active = nil
        hover = nil
        edge = nil
        suppressUntilNewSequence = true
    }

    private mutating func resolveHover(payload: SidebarDragPayload, location: CGPoint, frames: [SidebarDropTarget: [CGRect]], viewport: CGRect?) {
        guard let hit = Self.hitTest(payload: payload, location: location, frames: frames, viewport: viewport) else {
            hover = nil
            edge = nil
            return
        }
        hover = hit.target
        switch SidebarDragPolicy.hoverStyle(source: payload, target: hit.target, pointerY: Double(hit.y), rowHeight: Double(hit.height)) {
        case .marker(let resolved):
            edge = resolved
        case .highlight, nil:
            edge = nil
        }
    }

    private struct Hit {
        var target: SidebarDropTarget
        var y: CGFloat
        var height: CGFloat
        var edge: DropEdge { DropEdge.forLocation(y: Double(y), height: Double(height)) }
    }

    /// Absolute-coordinate hit test gated by the policy. The pointer must sit
    /// inside the visible viewport first; overlapping frames resolve to the
    /// smallest area so a row always wins over a containing root affordance.
    private static func hitTest(payload: SidebarDragPayload, location: CGPoint, frames: [SidebarDropTarget: [CGRect]], viewport: CGRect?) -> Hit? {
        guard let viewport, viewport.contains(location) else { return nil }
        var best: (target: SidebarDropTarget, y: CGFloat, height: CGFloat, area: CGFloat)?
        for (target, rects) in frames {
            for rect in rects where rect.contains(location) {
                let area = rect.width * rect.height
                if best == nil || area < best!.area {
                    best = (target, location.y - rect.minY, rect.height, area)
                }
            }
        }
        guard let match = best, SidebarDragPolicy.allowsHover(source: payload, target: match.target) else { return nil }
        return Hit(target: match.target, y: match.y, height: match.height)
    }
}
