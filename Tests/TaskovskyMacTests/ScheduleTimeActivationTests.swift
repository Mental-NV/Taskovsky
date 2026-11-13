import XCTest
@testable import Taskovsky

final class ScheduleTimeActivationTests: XCTestCase {
    func testDatedDraftIsNotReseeded() {
        XCTAssertNil(ScheduleTimeActivation.seed(hasDate: true, now: Date(), calendar: .current))
    }
    func testUndatedEntryUsesScheduleZoneTodayAtMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = Date(timeIntervalSince1970: 1_763_053_200)
        let seeded = ScheduleTimeActivation.seed(hasDate: false, now: now, calendar: calendar)!
        XCTAssertEqual(seeded, calendar.startOfDay(for: now))
        XCTAssertEqual(calendar.component(.hour, from: seeded), 0)
        XCTAssertEqual(calendar.component(.minute, from: seeded), 0)
    }
    func testDSTDayUsesCalendarStartNotFixedSecondTruncation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 16))!
        XCTAssertEqual(ScheduleTimeActivation.seed(hasDate: false, now: now, calendar: calendar), calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
    }
}
