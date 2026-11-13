import XCTest
@testable import TaskovskyDomain

final class DateRuleSelectionTests: XCTestCase {
    func testAnyClearsArrayAndSpecificRemovesSentinel() {
        XCTAssertEqual(DateRuleSelection.togglingArray(.all, in: [.today, .custom]), [])
        XCTAssertEqual(DateRuleSelection.togglingArray(.today, in: [.all, .noDate]), [.noDate, .today])
        XCTAssertEqual(DateRuleSelection.togglingArray(.today, in: [.all, .today, .today]), [])
    }
    func testSpecificRulesKeepOrderAndCustomBoundsAndOtherCriteria() {
        var draft = TaskFilter(name: "Test", dateRules: [.all, .custom, .noDate])
        draft.keyword = "Keep"
        draft.priorities = [.high]
        draft.customDateFrom = Date(timeIntervalSince1970: 1000)
        draft.customDateTo = Date(timeIntervalSince1970: 2000)
        let original = draft
        draft.dateRules = DateRuleSelection.togglingArray(.today, in: draft.dateRules)
        XCTAssertEqual(draft.dateRules, [.custom, .noDate, .today])
        XCTAssertEqual(draft.customDateFrom, original.customDateFrom)
        XCTAssertEqual(draft.customDateTo, original.customDateTo)
        XCTAssertEqual(draft.keyword, original.keyword)
        XCTAssertEqual(draft.priorities, original.priorities)
        XCTAssertEqual(original.dateRules, [.all, .custom, .noDate])
    }
    func testArrayAnyThenTodayNarrowsAndResetBroadensMatcher() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13))!
        let today = TaskItem(title: "Keep today", dueDate: now)
        let tomorrow = TaskItem(title: "Keep tomorrow", dueDate: calendar.date(byAdding: .day, value: 1, to: now))
        var filter = TaskFilter(name: "Test", dateRules: [.all], status: .all, keyword: "Keep")
        filter.dateRules = DateRuleSelection.togglingArray(.today, in: filter.dateRules)
        XCTAssertTrue(filter.matches(today, lists: [], now: now, calendar: calendar))
        XCTAssertFalse(filter.matches(tomorrow, lists: [], now: now, calendar: calendar))
        filter.dateRules = DateRuleSelection.togglingArray(.all, in: filter.dateRules)
        XCTAssertTrue(filter.matches(tomorrow, lists: [], now: now, calendar: calendar))
        XCTAssertEqual(filter.keyword, "Keep")
    }
}
