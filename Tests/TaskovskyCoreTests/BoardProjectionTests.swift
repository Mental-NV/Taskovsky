import XCTest
@testable import TaskovskyCore

/// Status-board projection: the board owns every non-deleted status in its
/// list, independent of the rows' Show Completed toggle.
final class BoardProjectionTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor func testBoardDatasetIgnoresHistoryVisibility() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "L", color: "#000000")
        let other = store.createList(name: "O", color: "#111111")
        let open = store.createTask(title: "Open", listID: list)
        let done = store.createTask(title: "Done", listID: list)
        store.toggleComplete(id: done)
        let wont = store.createTask(title: "Wont", listID: list)
        store.markWontDo(id: wont)
        let note = store.createTask(title: "Note", listID: list, kind: .note)
        _ = store.createTask(title: "Elsewhere", listID: other)
        let trashed = store.createTask(title: "Gone", listID: list)
        store.trashTask(id: trashed)
        // The rows hide history when the toggle is off; the board keeps it
        // (stored order follows the add policy, so membership is set-wise).
        let board = BoardProjection.tasks(forList: list, in: store.data)
        XCTAssertEqual(Set(board.map(\.id)), [open, done, wont, note])
        // Split covers every record exactly once; the note stays open.
        let split = BoardProjection.split(board)
        XCTAssertEqual(Set(split.open.map(\.id)), [open, note])
        XCTAssertEqual(split.completed.map(\.id), [done])
        XCTAssertEqual(split.wontDo.map(\.id), [wont])
        let all = split.open + split.completed + split.wontDo
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
    }

    @MainActor func testBoardCompletionUndoReopenCycle() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "L", color: "#000000")
        let task = store.createTask(title: "T", listID: list)
        // Complete through the board path: the record leaves Open.
        store.toggleComplete(id: task)
        var split = BoardProjection.split(BoardProjection.tasks(forList: list, in: store.data))
        XCTAssertTrue(split.open.isEmpty)
        XCTAssertEqual(split.completed.map(\.id), [task])
        // Undo reopens it back into Open.
        store.undoCompletion(id: task)
        split = BoardProjection.split(BoardProjection.tasks(forList: list, in: store.data))
        XCTAssertEqual(split.open.map(\.id), [task])
        // Won't Do lands in its own column; reopen returns it.
        store.markWontDo(id: task)
        split = BoardProjection.split(BoardProjection.tasks(forList: list, in: store.data))
        XCTAssertEqual(split.wontDo.map(\.id), [task])
        store.reopenTask(id: task)
        split = BoardProjection.split(BoardProjection.tasks(forList: list, in: store.data))
        XCTAssertEqual(split.open.map(\.id), [task])
    }

    @MainActor func testAllCompletedListStillRendersBoard() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "L", color: "#000000")
        let task = store.createTask(title: "T", listID: list)
        store.toggleComplete(id: task)
        // No active tasks remain, yet the board dataset is non-empty: the UI
        // renders the Completed column instead of the "All clear" state.
        let board = BoardProjection.tasks(forList: list, in: store.data)
        XCTAssertFalse(board.isEmpty)
        XCTAssertTrue(BoardProjection.split(board).open.isEmpty)
    }
}
