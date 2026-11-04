import Foundation

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
}
