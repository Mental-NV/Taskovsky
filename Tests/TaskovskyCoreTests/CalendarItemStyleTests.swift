import XCTest
@testable import TaskovskyCore

/// C10 Calendar Style structural parity: genuine Modern/Classic options with
/// legacy Filled/Outline preserved verbatim and no silent migration.
final class CalendarItemStyleTests: XCTestCase {
    private func decodeOptions(_ json: String) throws -> TaskCalendarOptions {
        try JSONDecoder().decode(TaskCalendarOptions.self, from: Data(json.utf8))
    }

    func testSharedProductionPolicyMatchesSpecifiedTreatments() {
        // Legacy treatments are preserved exactly.
        XCTAssertEqual(CalendarItemStyle.filled.rendering,
                       CalendarItemStyle.Rendering(fillOpacity: 0.15, completedFillOpacity: 0.06, showsStripe: true, showsOutline: false))
        XCTAssertEqual(CalendarItemStyle.outline.rendering,
                       CalendarItemStyle.Rendering(fillOpacity: 0, completedFillOpacity: 0, showsStripe: true, showsOutline: true))
        // Modern: pale fill plus a thin colored leading stripe.
        XCTAssertEqual(CalendarItemStyle.modern.rendering.fillOpacity, 0.12, accuracy: 0.0001)
        XCTAssertTrue(CalendarItemStyle.modern.rendering.showsStripe)
        XCTAssertFalse(CalendarItemStyle.modern.rendering.showsOutline)
        // Classic: stronger saturated block fill with no distinct stripe.
        XCTAssertEqual(CalendarItemStyle.classic.rendering.fillOpacity, 0.55, accuracy: 0.0001)
        XCTAssertFalse(CalendarItemStyle.classic.rendering.showsStripe)
        XCTAssertFalse(CalendarItemStyle.classic.rendering.showsOutline)
        // Completed rows stay dimmer in both new styles.
        XCTAssertLessThan(CalendarItemStyle.modern.rendering.completedFillOpacity,
                          CalendarItemStyle.modern.rendering.fillOpacity)
        XCTAssertLessThan(CalendarItemStyle.classic.rendering.completedFillOpacity,
                          CalendarItemStyle.classic.rendering.fillOpacity)
    }

    func testLegacyStylesStayHonestAndPrimary() {
        XCTAssertEqual(CalendarItemStyle.primaryStyles, [.modern, .classic])
        XCTAssertEqual(CalendarItemStyle.legacyStyles, [.filled, .outline])
        XCTAssertFalse(CalendarItemStyle.modern.isLegacy)
        XCTAssertFalse(CalendarItemStyle.classic.isLegacy)
        XCTAssertTrue(CalendarItemStyle.filled.isLegacy)
        XCTAssertTrue(CalendarItemStyle.outline.isLegacy)
        XCTAssertEqual(CalendarItemStyle.modern.displayTitle, "Modern")
        XCTAssertEqual(CalendarItemStyle.classic.displayTitle, "Classic")
        XCTAssertTrue(CalendarItemStyle.filled.displayTitle.contains("Legacy"))
        XCTAssertTrue(CalendarItemStyle.outline.displayTitle.contains("Legacy"))
        // Legacy values are never relabeled as Modern/Classic.
        XCTAssertFalse(CalendarItemStyle.filled.displayTitle == "Modern")
        XCTAssertFalse(CalendarItemStyle.outline.displayTitle == "Classic")
    }

    func testPlatformCompletedFillsPreserveLegacyTreatments() {
        // Mac dims the fill itself (prior Mac literals).
        XCTAssertEqual(CalendarItemStyle.filled.macFillOpacity(completed: false), 0.15, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.filled.macFillOpacity(completed: true), 0.06, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.outline.macFillOpacity(completed: false), 0, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.outline.macFillOpacity(completed: true), 0, accuracy: 0.0001)
        // iPhone legacy keeps its prior fill; completed dimming comes from
        // the platform overall opacity (0.58), so a completed Filled card
        // was and stays fill 0.15 under that overall opacity.
        XCTAssertEqual(CalendarItemStyle.filled.phoneFillOpacity(completed: false), 0.15, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.filled.phoneFillOpacity(completed: true), 0.15, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.outline.phoneFillOpacity(completed: false), 0, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.outline.phoneFillOpacity(completed: true), 0, accuracy: 0.0001)
        // New styles use the shared policy value on both platforms.
        XCTAssertEqual(CalendarItemStyle.modern.macFillOpacity(completed: true),
                       CalendarItemStyle.modern.phoneFillOpacity(completed: true), accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.classic.macFillOpacity(completed: true),
                       CalendarItemStyle.classic.phoneFillOpacity(completed: true), accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.modern.phoneFillOpacity(completed: false), 0.12, accuracy: 0.0001)
        XCTAssertEqual(CalendarItemStyle.classic.phoneFillOpacity(completed: false), 0.55, accuracy: 0.0001)
    }

    func testLegacyArchiveRoundTripsWithoutMigration() throws {
        for raw in ["filled", "outline"] {
            let options = try decodeOptions(#"{"itemStyle":"\#(raw)"}"#)
            XCTAssertEqual(options.itemStyle.rawValue, raw)
            let restored = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
            XCTAssertEqual(restored.itemStyle.rawValue, raw)
            XCTAssertEqual(restored, options)
        }
    }

    func testNewStylesRoundTrip() throws {
        for style in [CalendarItemStyle.modern, CalendarItemStyle.classic] {
            var options = TaskCalendarOptions()
            options.itemStyle = style
            let restored = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
            XCTAssertEqual(restored.itemStyle, style)
            XCTAssertEqual(restored, options)
        }
    }

    func testNoSilentMigrationForMissingOrUnknownStyles() throws {
        // Missing key keeps the long-standing default; it is not upgraded to Modern.
        XCTAssertEqual(try decodeOptions("{}").itemStyle, .filled)
        // Explicit legacy values stay legacy.
        XCTAssertEqual(try decodeOptions(#"{"itemStyle":"filled"}"#).itemStyle, .filled)
        XCTAssertEqual(try decodeOptions(#"{"itemStyle":"outline"}"#).itemStyle, .outline)
        // Unknown values fall back to the long-standing default instead of
        // inventing Modern/Classic (existing `try?` decode behavior).
        var options = TaskCalendarOptions()
        options.itemStyle = .outline
        let data = try JSONEncoder().encode(options)
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        document["itemStyle"] = "holographic"
        let tampered = try JSONSerialization.data(withJSONObject: document)
        let decoded = try JSONDecoder().decode(TaskCalendarOptions.self, from: tampered)
        XCTAssertEqual(decoded.itemStyle, .filled)
        XCTAssertNotEqual(decoded.itemStyle, .modern)
        XCTAssertNotEqual(decoded.itemStyle, .classic)
    }

    func testYearHeatmapMappingRetainsSemantics() {
        XCTAssertTrue(CalendarYearStyle.heatmap.heatmapTileTitle == "Show")
        XCTAssertTrue(CalendarYearStyle.standard.heatmapTileTitle == "Hide")
        XCTAssertTrue(CalendarYearStyle.heatmap.heatmapTileSubtitle.contains("Heatmap"))
        XCTAssertTrue(CalendarYearStyle.standard.heatmapTileSubtitle.contains("Standard"))
    }

    func testStyleAndYearChoicesDoNotChangeProjectionOrTasks() throws {
        let instant = ISO8601DateFormatter().date(from: "2026-11-08T12:00:00Z")!
        let data = WorkspaceData(tasks: [
            TaskItem(title: "Prepare agenda", dueDate: instant, hasDueTime: true),
            TaskItem(title: "Review notes", kind: .note, dueDate: instant, hasDueTime: false)
        ])
        let range = DateInterval(start: instant.addingTimeInterval(-86_400), duration: 172_800)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let baseline = TaskCalendarProjection.project(data: data, range: range, options: .init(), calendar: calendar)
        for style in CalendarItemStyle.allCases {
            var options = TaskCalendarOptions()
            options.itemStyle = style
            let projected = TaskCalendarProjection.project(data: data, range: range, options: options, calendar: calendar)
            XCTAssertEqual(projected.entries, baseline.entries, "itemStyle \(style) must not change projection")
        }
        for year in CalendarYearStyle.allCases {
            var options = TaskCalendarOptions()
            options.yearStyle = year
            let projected = TaskCalendarProjection.project(data: data, range: range, options: options, calendar: calendar)
            XCTAssertEqual(projected.entries, baseline.entries, "yearStyle \(year) must not change projection")
        }
        // Settings round-trip preserves tasks bytes: only the style differs.
        var modern = TaskCalendarOptions()
        modern.itemStyle = .modern
        modern.yearStyle = .heatmap
        let restored = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(modern))
        XCTAssertEqual(restored.itemStyle, .modern)
        XCTAssertEqual(restored.yearStyle, .heatmap)
    }

    func testIconMasterAndKindSwitchesSurviveStyleChanges() throws {
        var options = TaskCalendarOptions()
        options.itemStyle = .classic
        options.showItemIcons = false
        options.showTaskIcons = false
        options.showNoteIcons = true
        let restored = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
        XCTAssertEqual(restored.itemStyle, .classic)
        XCTAssertFalse(restored.showItemIcons)
        XCTAssertFalse(restored.showTaskIcons)
        XCTAssertTrue(restored.showNoteIcons)
    }
}
