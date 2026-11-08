import XCTest
@testable import TaskovskyCore

final class CalendarDisplayOptionsTests: XCTestCase {
    private func decode(_ json: String) throws -> TaskCalendarOptions {
        try JSONDecoder().decode(TaskCalendarOptions.self, from: Data(json.utf8))
    }

    func testLegacySingleZoneMigratesWithoutEnablingAbsentOrInvalidZone() throws {
        let old = try decode(#"{"additionalTimeZoneID":"America/New_York"}"#)
        XCTAssertTrue(old.showAdditionalTimeZones)
        XCTAssertEqual(old.additionalTimeZones, [.init(identifier: "America/New_York")])
        XCTAssertTrue(old.showItemIcons)
        XCTAssertEqual(old.yearStyle, .heatmap) // Preserve the previous Year appearance.
        for json in ["{}", #"{"additionalTimeZoneID":null}"#, #"{"additionalTimeZoneID":"invalid"}"#] {
            let options = try decode(json)
            XCTAssertFalse(options.showAdditionalTimeZones)
            XCTAssertTrue(options.additionalTimeZones.isEmpty)
        }
    }

    func testExplicitNewCollectionTakesPrecedenceOverLegacyValue() throws {
        let options = try decode(#"{"additionalTimeZoneID":"America/New_York","additionalTimeZones":[],"showAdditionalTimeZones":false,"yearStyle":"unknown"}"#)
        XCTAssertNil(options.additionalTimeZoneID)
        XCTAssertTrue(options.additionalTimeZones.isEmpty)
        XCTAssertEqual(options.yearStyle, .heatmap)
    }

    func testHiddenZonesLabelsAndOrderSurviveSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.calendarOptions.additionalTimeZones = [
            .init(identifier: "Asia/Tokyo", label: "Tokyo team"),
            .init(identifier: "America/New_York", label: "NYC")
        ]
        settings.calendarOptions.showAdditionalTimeZones = false
        settings.calendarOptions.yearStyle = .standard
        settings.calendarOptions.showItemIcons = false
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored, settings)
        XCTAssertTrue(restored.calendarOptions.visibleTimeZones(primary: TimeZone(identifier: "UTC")!).isEmpty)
        var shown = restored.calendarOptions
        shown.showAdditionalTimeZones = true
        XCTAssertEqual(shown.visibleTimeZones(primary: TimeZone(identifier: "UTC")!).map(\.label), ["Tokyo team", "NYC"])
    }

    func testInvalidAndDuplicateZonesAreRemovedWithoutDisplacingValidRows() throws {
        let options = try decode(#"{"additionalTimeZones":[{"identifier":"bad"},{"identifier":"Asia/Tokyo","label":"  Tokyo  "},{"identifier":"Asia/Tokyo","label":"duplicate"},{"identifier":"America/New_York"},{"identifier":"Europe/London"},{"identifier":"Europe/Paris"}]}"#)
        XCTAssertEqual(options.additionalTimeZones.map(\.identifier), ["Asia/Tokyo", "America/New_York", "Europe/London"])
        XCTAssertEqual(options.additionalTimeZones.map(\.label), ["Tokyo", "", ""])
        XCTAssertTrue(options.showAdditionalTimeZones)
        XCTAssertEqual(CalendarTimeZone.normalized([.init(identifier: "UTC", label: String(repeating: "x", count: 100))])[0].label.count, 32)
    }

    func testPrimaryZoneIsHiddenWithoutDiscardingConfiguration() {
        var options = TaskCalendarOptions()
        options.additionalTimeZones = [.init(identifier: "Asia/Tokyo", label: "Tokyo"), .init(identifier: "Europe/London")]
        options.showAdditionalTimeZones = true
        XCTAssertEqual(options.visibleTimeZones(primary: TimeZone(identifier: "Asia/Tokyo")!).map(\.identifier), ["Europe/London"])
        XCTAssertEqual(options.visibleTimeZones(primary: TimeZone(identifier: "UTC")!).count, 2)
        XCTAssertEqual(options.additionalTimeZones.count, 2)
    }

    func testBlankLabelsUseDateSpecificAbbreviationAcrossDST() {
        let zone = CalendarTimeZone(identifier: "America/New_York", label: " \n")
        let summer = ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z")!
        let winter = ISO8601DateFormatter().date(from: "2026-12-01T12:00:00Z")!
        XCTAssertEqual(zone.title(at: summer), "EDT")
        XCTAssertEqual(zone.title(at: winter), "EST")
        XCTAssertEqual(CalendarTimeZone(identifier: zone.identifier, label: " NYC ").title(at: summer), "NYC")
    }

    func testDisplayPreferencesDoNotChangeTaskSchedulesOrProjection() {
        let instant = ISO8601DateFormatter().date(from: "2026-11-08T12:00:00Z")!
        let data = WorkspaceData(tasks: [TaskItem(title: "Point task", dueDate: instant, hasDueTime: true)])
        let range = DateInterval(start: instant.addingTimeInterval(-86_400), duration: 172_800)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let original = TaskCalendarProjection.project(data: data, range: range, options: .init(), calendar: calendar)
        var options = TaskCalendarOptions()
        options.yearStyle = .standard
        options.showItemIcons = false
        options.additionalTimeZones = [.init(identifier: "Pacific/Auckland", label: "Tomorrow")]
        options.showAdditionalTimeZones = true
        let changed = TaskCalendarProjection.project(data: data, range: range, options: options, calendar: calendar)
        XCTAssertEqual(changed.entries, original.entries)
        XCTAssertEqual(changed.entries.first?.due, instant)
    }
}
