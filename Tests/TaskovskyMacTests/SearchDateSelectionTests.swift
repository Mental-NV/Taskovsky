import XCTest
import TaskovskyCore
@testable import Taskovsky

final class SearchDateSelectionTests: XCTestCase {
    func testAllDatesResetsEveryDateRule() {
        XCTAssertEqual(DateRuleSelection.toggling(.all, in: [.nextWeek, .custom, .all]), [])
        XCTAssertEqual(DateRuleSelection.toggling(.all, in: []), [])
    }
    func testSpecificSelectionRemovesUnrestrictedSentinelAndPreservesOtherRules() {
        XCTAssertEqual(DateRuleSelection.toggling(.nextWeek, in: [.all, .noDate]), [.nextWeek, .noDate])
        XCTAssertEqual(DateRuleSelection.toggling(.nextWeek, in: [.all, .nextWeek]), [])
    }
    func testCustomConfirmationNormalizesWithoutRemovingOtherSpecificRules() {
        XCTAssertEqual(DateRuleSelection.applyingCustom(to: [.all, .noDate]), [.custom, .noDate])
        XCTAssertEqual(DateRuleSelection.applyingCustom(to: [.custom]), [.custom])
    }
    func testResetThenNextWeekReallyNarrowsMatcher() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!; c.firstWeekday = 2
        let now = c.date(from: DateComponents(year: 2026, month: 11, day: 13))!
        let next = TaskItem(title: "Next", dueDate: c.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        let current = TaskItem(title: "Current", dueDate: now)
        let reset = DateRuleSelection.toggling(.all, in: [.thisWeek])
        let narrowed = DateRuleSelection.toggling(.nextWeek, in: reset)
        let filter = TaskFilter(name: "", dateRules: Array(narrowed), status: .all)
        XCTAssertTrue(filter.matches(next, lists: [], now: now, calendar: c))
        XCTAssertFalse(filter.matches(current, lists: [], now: now, calendar: c))
        let broad = TaskFilter(name: "", dateRules: Array(DateRuleSelection.toggling(.all, in: narrowed)), status: .all)
        XCTAssertTrue(broad.matches(next, lists: [], now: now, calendar: c))
        XCTAssertTrue(broad.matches(current, lists: [], now: now, calendar: c))
    }
}
