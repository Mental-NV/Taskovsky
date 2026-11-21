import XCTest
@testable import TaskovskyDomain

final class NormalFilterTagAllTests: XCTestCase {
    func testExplicitAllClearsRestrictiveTagModesWithoutChangingOtherCriteria() {
        let tag = UUID(), list = UUID()
        for mode in FilterTagMode.allCases {
            var filter = TaskFilter(name: "Neutral", listIDs: [list], tagIDs: [tag], keyword: "plan", tagMode: mode)
            let before = filter
            XCTAssertEqual(filter.tagMode, mode)
            filter.clearTagCriteria()
            XCTAssertTrue(filter.hasUnrestrictedTagCriteria)
            XCTAssertTrue(filter.tagIDs.isEmpty); XCTAssertEqual(filter.tagMode, .any)
            XCTAssertEqual(filter.listIDs, before.listIDs); XCTAssertEqual(filter.keyword, before.keyword)
            var tagged = TaskItem(title: "plan", listID: list); tagged.tagIDs = [tag]
            let untagged = TaskItem(title: "plan", listID: list)
            XCTAssertTrue(filter.matches(tagged)); XCTAssertTrue(filter.matches(untagged))
        }
    }
    func testEmptySelectionDoesNotMislabelRestrictiveModesAsAll() {
        for mode in [FilterTagMode.none, .anyTagged] {
            let filter = TaskFilter(name: "Neutral", tagMode: mode)
            XCTAssertFalse(filter.hasUnrestrictedTagCriteria)
            XCTAssertEqual(filter.tagMode, mode)
        }
    }
}
