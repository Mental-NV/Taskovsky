import XCTest
@testable import Taskovsky

final class DetailFormattingTests: XCTestCase {
    func testToolsStartCollapsedAndToggleWithoutTaskMutation() {
        let id = UUID()
        var state = DetailFormattingPresentation()
        XCTAssertFalse(state.isVisible(for: id, locked: false))
        state.toggle(for: id)
        XCTAssertTrue(state.isVisible(for: id, locked: false))
        state.toggle(for: id)
        XCTAssertFalse(state.isVisible(for: id, locked: false))
    }
    func testToolsNeverLeakToAnotherDocumentOrLockedDetail() {
        let first = UUID(), second = UUID()
        var state = DetailFormattingPresentation()
        state.toggle(for: first)
        XCTAssertFalse(state.isVisible(for: second, locked: false))
        XCTAssertFalse(state.isVisible(for: first, locked: true))
        state.reset()
        XCTAssertFalse(state.isVisible(for: first, locked: false))
        state.toggle(for: second)
        XCTAssertTrue(state.isVisible(for: second, locked: false))
    }
}
