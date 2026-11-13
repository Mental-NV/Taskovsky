import XCTest
import TaskovskyCore
@testable import Taskovsky

final class SearchWeekRangeTests: XCTestCase {
    private func calendar(_ first: Int = 2, zone: String = "America/New_York") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = first
        return calendar
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    func testWeekStartFollowsCalendar() {
        for first in [1, 2] {
            let c = calendar(first)
            let range = SearchWeekRange.bounds(for: .thisWeek, now: date(2026, 11, 13, in: c), calendar: c)!
            XCTAssertEqual(c.component(.weekday, from: range.start), first)
            XCTAssertEqual(c.dateComponents([.day], from: range.start, to: range.through).day, 6)
            XCTAssertEqual(c.component(.day, from: range.start), first == 1 ? 8 : 9)
        }
    }
    func testAdjacentWeeksCrossYearBoundary() {
        let c = calendar()
        let now = date(2027, 1, 1, in: c)
        let previous = SearchWeekRange.bounds(for: .lastWeek, now: now, calendar: c)!
        let next = SearchWeekRange.bounds(for: .nextWeek, now: now, calendar: c)!
        XCTAssertEqual(c.dateComponents([.year, .month, .day], from: previous.start), DateComponents(year: 2026, month: 12, day: 21))
        XCTAssertEqual(c.dateComponents([.year, .month, .day], from: next.start), DateComponents(year: 2027, month: 1, day: 4))
    }
    func testDSTRangeUsesCivilDaysNotSeconds() {
        let c = calendar(1)
        let now = date(2026, 3, 8, in: c)
        let range = SearchWeekRange.bounds(for: .thisWeek, now: now, calendar: c)!
        XCTAssertEqual(c.component(.hour, from: range.start), 0)
        XCTAssertEqual(c.component(.hour, from: range.through), 0)
        XCTAssertEqual(c.component(.day, from: range.through), 14)
        XCTAssertEqual(range.through.timeIntervalSince(range.start), 6 * 86400 - 3600)
    }
    func testNonWeekLabelsRemainUnchangedAndWeekLabelIncludesDates() {
        let c = calendar(zone: "Asia/Tokyo")
        let now = date(2026, 11, 13, in: c)
        for rule in FilterDateRule.allCases where ![.thisWeek, .nextWeek, .lastWeek].contains(rule) {
            XCTAssertNil(SearchWeekRange.bounds(for: rule, now: now, calendar: c))
            XCTAssertEqual(SearchWeekRange.label(for: rule, now: now, calendar: c), rule.label)
        }
        let label = SearchWeekRange.label(for: .thisWeek, now: now, calendar: c, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(label.hasPrefix("This week ("))
        XCTAssertTrue(label.contains("Nov")); XCTAssertTrue(label.contains("9")); XCTAssertTrue(label.contains("15"))
    }
}
