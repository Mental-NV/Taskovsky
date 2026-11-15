import Foundation

/// Supported task-detail actions behind the D02 actions sheet.
///
/// Raw values are the persisted layout encoding. They must stay stable:
/// saved layouts on device decode by these values, and unknown values must
/// keep decoding as a whole-layout refusal instead of silent reordering.
public enum DetailAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case complete, reopen, wontDo, pin, move, duplicate, convert, trash, saveTemplate, applyTemplate
    case addSubtask, linkParent, tags

    public var id: Self { self }
}

/// Presentation policy for the D02 actions sheet layout.
///
/// The icon strip renders only for untouched (empty) or default layouts.
/// Any saved custom layout keeps its exact pinned/more order and placement:
/// decoding never reorders and never appends missing actions. Restoring
/// defaults clears back to empty storage, which brings the strip back.
/// Schema-unknown payloads fail decoding as a whole so the UI preserves
/// them untouched instead of rewriting or dropping saved actions.
public struct DetailActionLayout: Codable, Equatable, Sendable {
    /// Actions rendered as icon-strip tiles when the strip is shown.
    public static let stripActions: [DetailAction] = [.pin, .wontDo, .trash]

    public var pinned: [DetailAction] = DetailAction.allCases
    public var more: [DetailAction] = []

    public init(pinned: [DetailAction] = DetailAction.allCases, more: [DetailAction] = []) {
        self.pinned = pinned
        self.more = more
    }

    public static var `default`: Self { Self() }

    public var isDefault: Bool { self == Self() }

    public static func decode(_ data: Data) -> Self? {
        if data.isEmpty { return Self() }
        guard var layout = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        var seen = Set<DetailAction>()
        layout.pinned = layout.pinned.filter { seen.insert($0).inserted }
        layout.more = layout.more.filter { seen.insert($0).inserted }
        return layout
    }

    /// The strip shows only for untouched or default layouts. Saved custom
    /// layouts — including older defaults that predate newer actions — keep
    /// their exact rows with no strip and no forced migration.
    public static func showsStrip(for data: Data) -> Bool {
        data.isEmpty || decode(data) == Self()
    }

    /// Rows for the main actions list. When the strip is shown, strip actions
    /// are excluded so each appears exactly once. Custom layouts render their
    /// exact pinned order unchanged.
    public func pinnedRows(showingStrip: Bool) -> [DetailAction] {
        showingStrip ? pinned.filter({ !Self.stripActions.contains($0) }) : pinned
    }

    /// Storage form. Default layouts clear back to empty data so restoring
    /// defaults brings the strip back; custom layouts encode exactly.
    public func encoded() -> Data {
        guard self != Self(), let data = try? JSONEncoder().encode(self) else { return Data() }
        return data
    }
}
