import XCTest
import TaskovskyCore
@testable import Taskovsky

final class SearchListPickerTests: XCTestCase {
    func testTabAndNativeBackTabDecodeWithoutConsumingOtherKeys() {
        XCTAssertEqual(SearchListKeyboard.backwards(character: "\t", shift: false), false)
        XCTAssertEqual(SearchListKeyboard.backwards(character: "\t", shift: true), true)
        XCTAssertEqual(SearchListKeyboard.backwards(character: "\u{19}", shift: false), true)
        XCTAssertEqual(SearchListKeyboard.backwards(character: "\u{19}", shift: true), true)
        for character in [Character(" "), Character("\r"), Character("\u{1b}"), Character("a")] {
            XCTAssertNil(SearchListKeyboard.backwards(character: character, shift: false))
        }
    }
    func testReverseTabWrapsToOKThenCancelAndForwardReturnsToFirstRow() {
        let inbox = SearchListFocus.list(TaskFilter.inboxListID)
        let order: [SearchListFocus] = [.all, inbox, .cancel, .apply]
        XCTAssertEqual(SearchListKeyboard.next(.all, in: order, backwards: true), .apply)
        XCTAssertEqual(SearchListKeyboard.next(.apply, in: order, backwards: true), .cancel)
        XCTAssertEqual(SearchListKeyboard.next(.cancel, in: order, backwards: false), .apply)
        XCTAssertEqual(SearchListKeyboard.next(.apply, in: order, backwards: false), .all)
        XCTAssertEqual(SearchListKeyboard.next(nil, in: order, backwards: true), .apply)
        XCTAssertEqual(SearchListKeyboard.next(nil, in: order, backwards: false), .all)
        XCTAssertNil(SearchListKeyboard.next(.all, in: [], backwards: true))
    }
    func testDraftIsIsolatedUntilAppliedAndCancelDoesNotMutateCommittedSelection() {
        let a = UUID(), b = UUID()
        let committed: Set<UUID> = [a]
        var draft = SearchListSelectionDraft(ids: committed)
        draft.toggle(b)
        XCTAssertEqual(committed, [a])
        XCTAssertEqual(draft.ids, [a, b])
        let reopened = SearchListSelectionDraft(ids: committed)
        XCTAssertEqual(reopened.ids, [a])
    }
    func testAllAndLastToggleRetainExistingEmptyMeansAllContract() {
        let a = UUID()
        var draft = SearchListSelectionDraft(ids: [])
        draft.toggle(a); XCTAssertEqual(draft.ids, [a])
        draft.toggle(a); XCTAssertTrue(draft.ids.isEmpty)
        draft.toggle(a); draft.selectAll(); XCTAssertTrue(draft.ids.isEmpty)
    }
    func testFolderMarkOnlyDerivesFromExplicitChildren() {
        let a = UUID(), b = UUID(), outside = UUID()
        var draft = SearchListSelectionDraft(ids: [outside])
        XCTAssertEqual(draft.mark(for: [a, b]), .none)
        draft.toggle(a); XCTAssertEqual(draft.mark(for: [a, b]), .mixed)
        draft.toggle(b); XCTAssertEqual(draft.mark(for: [a, b]), .selected)
        XCTAssertEqual(draft.mark(for: []), .none)
    }
    func testUnknownIDsPreservedUntilExplicitAll() {
        let stale = UUID(), current = UUID()
        var draft = SearchListSelectionDraft(ids: [stale])
        draft.toggle(current); XCTAssertEqual(draft.ids, [stale, current])
        draft.selectAll(); XCTAssertTrue(draft.ids.isEmpty)
    }
    func testTreeRetainsEveryListIncludingArchivedAndOrphanedInStableOrder() {
        let folder = ListFolder(name: "Folder")
        let root = TaskList(name: "Root", color: "blue")
        let child = TaskList(name: "Child", color: "blue", folderID: folder.id)
        let archived = TaskList(name: "Archived", color: "blue", folderID: folder.id, isArchived: true)
        let orphan = TaskList(name: "Orphan", color: "blue", folderID: UUID())
        let trailing = TaskList(name: "Last", color: "blue", belowFolders: true)
        let tree = SearchListTree(lists: [root, child, archived, orphan, trailing], folders: [folder])
        XCTAssertEqual(tree.leading.map(\.id), [root.id, orphan.id])
        XCTAssertEqual(tree.groups[0].lists.map(\.id), [child.id, archived.id])
        XCTAssertEqual(tree.trailing.map(\.id), [trailing.id])
    }
}
