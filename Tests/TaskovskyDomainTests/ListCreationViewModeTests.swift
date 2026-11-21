import XCTest
import TaskovskyDomain

final class ListCreationViewModeTests: XCTestCase {
    func testExplicitModeCreationIsAtomicAndClearsInjectedSections() throws {
        for mode in TaskListViewMode.allCases {
            var list = TaskList(name: "  Neutral  ", color: "#123456")
            list.sections = [TaskSection(name: "Not accepted")]
            var data = WorkspaceData()
            XCTAssertEqual(ListOrganizationCommand.saveList(list, creating: true, initialViewMode: mode).apply(to: &data, now: .distantPast), true)
            XCTAssertEqual(data.lists.count, 1)
            XCTAssertEqual(data.lists[0].viewMode, mode)
            XCTAssertEqual(data.lists[0].name, "Neutral")
            XCTAssertTrue(data.lists[0].sections.isEmpty)
            let restored = try JSONDecoder().decode(WorkspaceData.self, from: JSONEncoder().encode(data))
            XCTAssertEqual(restored.lists[0].viewMode, mode)
        }
    }

    func testDefaultCreationAndExistingEditsPreserveOldContract() {
        var list = TaskList(name: "Neutral", color: "#123456")
        list.viewMode = .timeline
        var data = WorkspaceData()
        XCTAssertEqual(ListOrganizationCommand.saveList(list, creating: true).apply(to: &data, now: .distantPast), true)
        XCTAssertEqual(data.lists[0].viewMode, .list)
        data.lists[0].viewMode = .board
        data.lists[0].sections = [TaskSection(name: "Keep")]
        let sections = data.lists[0].sections
        list.name = "Edited"
        XCTAssertEqual(ListOrganizationCommand.saveList(list, creating: false, initialViewMode: .timeline).apply(to: &data, now: .distantPast), true)
        XCTAssertEqual(data.lists[0].viewMode, .board)
        XCTAssertEqual(data.lists[0].sections, sections)
    }

    func testInvalidCreationDoesNotPartiallyAppendOrChangeExistingData() {
        let existing = TaskList(name: "Existing", color: "#123456")
        var data = WorkspaceData(lists: [existing])
        let original = data
        var invalid = TaskList(name: " ", color: "#123456")
        XCTAssertNil(ListOrganizationCommand.saveList(invalid, creating: true, initialViewMode: .board).apply(to: &data, now: .distantPast))
        invalid.name = "Valid"; invalid.folderID = UUID()
        XCTAssertNil(ListOrganizationCommand.saveList(invalid, creating: true, initialViewMode: .timeline).apply(to: &data, now: .distantPast))
        XCTAssertNil(ListOrganizationCommand.saveList(existing, creating: true, initialViewMode: .board).apply(to: &data, now: .distantPast))
        XCTAssertEqual(data, original)
    }
}
