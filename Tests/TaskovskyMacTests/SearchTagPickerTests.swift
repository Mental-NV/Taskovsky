import XCTest
import TaskovskyCore
@testable import Taskovsky

final class SearchTagPickerTests: XCTestCase {
    func testDraftChangesDoNotMutateAppliedSelection() {
        let id = UUID(), second = UUID()
        let applied = SearchTagDraft(ids: [id], mode: .all)
        var draft = applied
        draft.toggle(second)
        draft.mode = .none
        XCTAssertEqual(applied, SearchTagDraft(ids: [id], mode: .all))
        XCTAssertEqual(draft.ids, [id, second])
        XCTAssertEqual(draft.mode, .none)
    }
    func testAllExplicitlyClearsUnknownIDsAndResetsMode() {
        var draft = SearchTagDraft(ids: [UUID()], mode: .none)
        draft.selectAll()
        XCTAssertTrue(draft.ids.isEmpty)
        XCTAssertEqual(draft.mode, .any)
    }
    func testModesPreserveInactiveSelection() {
        let missing = UUID()
        var draft = SearchTagDraft(ids: [missing], mode: .any)
        for mode in FilterTagMode.allCases {
            draft.mode = mode
            XCTAssertEqual(draft.ids, [missing])
        }
    }
    func testToggleOnlyChangesChosenIDAndPreservesMode() {
        let first = UUID(), second = UUID(), unknown = UUID()
        var draft = SearchTagDraft(ids: [first, unknown], mode: .all)
        draft.toggle(first)
        draft.toggle(second)
        XCTAssertEqual(draft.ids, [second, unknown])
        XCTAssertEqual(draft.mode, .all)
        draft.toggle(second)
        XCTAssertEqual(draft.ids, [unknown])
    }
}
