import XCTest
@testable import TaskovskyDomain

/// C01/C02 hourly day-header formatting must resolve in the supplied
/// calendar/timezone, not the device zone. The fixed view renders through
/// `CalendarDayHeader`, so these tests exercise the production formatting
/// path at a midnight timezone boundary.
final class CalendarDayHeaderTests: XCTestCase {
    private func calendar(_ identifier: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: identifier)!
        return value
    }

    /// 2026-11-08T11:30:00Z is Monday Nov 9 00:30 in Auckland but still
    /// Sunday Nov 8 in UTC. The device-zone formatting this replaces would
    /// show Sunday's weekday/accessible date next to the 9th.
    private var boundary: Date {
        ISO8601DateFormatter().date(from: "2026-11-08T11:30:00Z")!
    }

    private func narrowReference(_ date: Date, calendar: Calendar) -> String {
        let reference = DateFormatter()
        reference.locale = Locale.autoupdatingCurrent
        reference.calendar = calendar
        reference.timeZone = calendar.timeZone
        reference.setLocalizedDateFormatFromTemplate("EEEEE")
        return reference.string(from: date)
    }

    func testBoundaryResolvesInSuppliedCalendar() {
        let auckland = calendar("Pacific/Auckland")
        let header = CalendarDayHeader(day: boundary, calendar: auckland)
        XCTAssertEqual(header.dayNumber, 9)
        XCTAssertEqual(header.identifier, "calendarDay-2026-11-9")
        XCTAssertEqual(header.weekdayNarrow, narrowReference(boundary, calendar: auckland))
        XCTAssertTrue(header.accessibleLabel.hasPrefix("Show "))
        XCTAssertTrue(header.accessibleLabel.hasSuffix(" in Day view"))
        XCTAssertTrue(header.accessibleLabel.contains("9"),
                      "Accessible date must carry the Auckland civil day: \(header.accessibleLabel)")
    }

    func testSameInstantDiffersAcrossZones() {
        let aucklandCalendar = calendar("Pacific/Auckland")
        let utcCalendar = calendar("UTC")
        let auckland = CalendarDayHeader(day: boundary, calendar: aucklandCalendar)
        let utc = CalendarDayHeader(day: boundary, calendar: utcCalendar)
        XCTAssertEqual(utc.dayNumber, 8)
        XCTAssertEqual(utc.identifier, "calendarDay-2026-11-8")
        XCTAssertEqual(utc.weekdayNarrow, narrowReference(boundary, calendar: utcCalendar))
        XCTAssertNotEqual(auckland.accessibleLabel, utc.accessibleLabel)
        XCTAssertTrue(utc.accessibleLabel.contains("8"),
                      "Accessible date must carry the UTC civil day: \(utc.accessibleLabel)")
    }

    func testMiddayDateStaysConsistent() {
        let utc = calendar("UTC")
        let noon = ISO8601DateFormatter().date(from: "2026-11-09T12:00:00Z")!
        let header = CalendarDayHeader(day: noon, calendar: utc)
        XCTAssertEqual(header.dayNumber, 9)
        XCTAssertEqual(header.identifier, "calendarDay-2026-11-9")
        XCTAssertEqual(header.weekdayNarrow, narrowReference(noon, calendar: utc))
        XCTAssertTrue(header.accessibleLabel.contains("9"))
    }
}
