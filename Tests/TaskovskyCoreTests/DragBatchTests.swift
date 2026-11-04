import Testing
import Foundation
@testable import TaskovskyCore

/// Pure unit tests for drop-batch aggregation and the insertion-edge rule.
/// The delegates decode every provider first and commit at most once; these
/// tests pin the all-or-nothing contract without any UI infrastructure.
@Suite struct DragBatchTests {
    private func taskData(_ ids: UUID...) -> Data {
        try! JSONEncoder().encode(TaskDragPayload(ids: ids))
    }

    private func listData(_ id: UUID) -> Data {
        try! JSONEncoder().encode(ListDragPayload(id: id))
    }

    @Test func combinedTaskIDsAcrossProvidersInOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        #expect(DragBatch.combinedTaskIDs(from: [taskData(a, b), taskData(c)]) == [a, b, c])
    }

    @Test func combinedTaskIDsRejectsBadBatches() {
        let a = UUID(), b = UUID()
        // No providers, malformed data, empty payloads, and any duplicate
        // (within or across providers) all aggregate to nil: the caller must
        // not mutate.
        #expect(DragBatch.combinedTaskIDs(from: []) == nil)
        #expect(DragBatch.combinedTaskIDs(from: [Data("not-json".utf8)]) == nil)
        #expect(DragBatch.combinedTaskIDs(from: [taskData(a), Data("nope".utf8)]) == nil)
        #expect(DragBatch.combinedTaskIDs(from: [try! JSONEncoder().encode(TaskDragPayload(ids: []))]) == nil)
        #expect(DragBatch.combinedTaskIDs(from: [taskData(a, a)]) == nil)
        #expect(DragBatch.combinedTaskIDs(from: [taskData(a), taskData(a, b)]) == nil)
        // A valid provider plus an invalid one never validates a subset.
        #expect(DragBatch.combinedTaskIDs(from: [taskData(a, b), Data("nope".utf8)]) == nil)
    }

    @Test func singleListIDRequiresExactlyOneValidPayload() {
        let a = UUID(), b = UUID()
        #expect(DragBatch.singleListID(from: [listData(a)]) == a)
        #expect(DragBatch.singleListID(from: []) == nil)
        #expect(DragBatch.singleListID(from: [listData(a), listData(b)]) == nil)
        #expect(DragBatch.singleListID(from: [Data("nope".utf8)]) == nil)
    }

    @Test func insertionEdgeUsesRowMidpoint() {
        #expect(DropEdge.forLocation(y: 0, height: 38) == .above)
        #expect(DropEdge.forLocation(y: 18.9, height: 38) == .above)
        #expect(DropEdge.forLocation(y: 19, height: 38) == .below)
        #expect(DropEdge.forLocation(y: 37, height: 38) == .below)
        // Taller rows (previews, checklist items) split at their own half.
        #expect(DropEdge.forLocation(y: 30, height: 80) == .above)
        #expect(DropEdge.forLocation(y: 40, height: 80) == .below)
        // Degenerate heights fall back to below: a drop always lands on a
        // valid adjacent position.
        #expect(DropEdge.forLocation(y: 0, height: 0) == .below)
        #expect(DropEdge.forLocation(y: -5, height: -1) == .below)
    }
}
