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
        let options = try decode(#"{"additionalTimeZones":[{"identifier":"bad"},{"identifier":"Asia/Tokyo","label":"  Tokyo  "},{"identifier":"Asia/Tokyo","label":"duplicate"},{"identifier":"America/New_York"},{"identifier":"Europe/London"},{"identifier":"Europe/Paris"},{"identifier":"Pacific/Auckland"}]}"#)
        XCTAssertEqual(options.additionalTimeZones.map(\.identifier), ["Asia/Tokyo", "America/New_York", "Europe/London", "Europe/Paris"])
        XCTAssertEqual(options.additionalTimeZones.map(\.label), ["Tokyo", "", "", ""])
        XCTAssertTrue(options.showAdditionalTimeZones)
        XCTAssertEqual(CalendarTimeZone.normalized([.init(identifier: "UTC", label: String(repeating: "x", count: 100))])[0].label.count, 32)
    }

    func testFourAdditionalRulersPersistAndHidePrimaryDuplicate() throws {
        var settings = AppSettings()
        settings.calendarOptions.showAdditionalTimeZones = true
        settings.calendarOptions.additionalTimeZones = [
            .init(identifier: "America/New_York", label: "NYC"), .init(identifier: "Asia/Tokyo", label: "Tokyo"),
            .init(identifier: "Europe/London", label: "London"), .init(identifier: "Europe/Paris", label: "Paris")
        ]
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.calendarOptions.additionalTimeZones, settings.calendarOptions.additionalTimeZones)
        XCTAssertEqual(restored.calendarOptions.visibleTimeZones(primary: TimeZone(identifier: "Europe/Moscow")!).count, 4)
        XCTAssertEqual(restored.calendarOptions.visibleTimeZones(primary: TimeZone(identifier: "Asia/Tokyo")!).count, 3)
        XCTAssertEqual(restored.calendarOptions.additionalTimeZones.count, 4)
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

    func testCalendarSourceColorsRoundTripAndKeepProjectionRules() throws {
        let list = TaskList(name: "Work", color: "#123456")
        let archive = TaskList(name: "Archive", color: "#987654", isArchived: true)
        let tag = TaskTag(name: "Planning", color: "#234567")
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskItem(title: "Task", listID: list.id, tagIDs: [UUID(), tag.id], dueDate: day, priority: .high)
        let inbox = TaskItem(title: "Inbox task", dueDate: day)
        let data = WorkspaceData(tasks: [task, inbox], lists: [list, archive], tags: [tag])
        var options = try decode("{}")
        XCTAssertEqual(CalendarColorSource.swatches(in: data, by: .list).map(\.id), [.inbox, .list(list.id)])
        XCTAssertEqual(CalendarColorSource.swatches(in: data, by: .tag).map(\.id), [.tag(tag.id)])
        XCTAssertTrue(CalendarColorSource.swatches(in: data, by: .priority).isEmpty)
        XCTAssertEqual(TaskCalendarProjection.color(for: task, data: data, by: .list), "#123456")
        XCTAssertEqual(TaskCalendarProjection.color(for: task, data: data, by: .tag), "#234567")
        options.sourceColors[.list(list.id)] = "#abcdef"
        options.sourceColors[.inbox] = "#445566"
        options.sourceColors[.tag(tag.id)] = "#AABBCC"
        options.sourceColors[.tag(tag.id)] = "#zzzzzz"
        let restored = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
        XCTAssertEqual(options, restored)
        XCTAssertEqual(restored.sourceColors[.list(list.id)], "#ABCDEF")
        let range = DateInterval(start: day.addingTimeInterval(-86_400), duration: 172_800)
        func colors(_ mode: CalendarColorMode) -> [UUID: String] {
            options.colorBy = mode
            return Dictionary(uniqueKeysWithValues: TaskCalendarProjection.project(data: data, range: range,
                options: options, calendar: .current).entries.map { ($0.taskID, $0.color) })
        }
        XCTAssertEqual(colors(.list), [task.id: "#ABCDEF", inbox.id: "#445566"])
        XCTAssertEqual(colors(.tag), [task.id: "#AABBCC", inbox.id: "#445566"])
        XCTAssertEqual(colors(.priority), [task.id: "#E65757", inbox.id: "#7C6CF2"])
        options.sourceColors[.list(list.id)] = nil
        XCTAssertEqual(colors(.list)[task.id], "#123456")
    }

    @MainActor func testMacCalendarSourceColorSaveRefusesStaleAndUnwritableSettings() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: dir) }
        let workspace = dir.appendingPathComponent("workspace.json")
        let settings = dir.appendingPathComponent("settings.json")
        let bytes = try JSONEncoder().encode(WorkspaceData(tasks: [TaskItem(title: "Keep exact")]))
        try bytes.write(to: workspace)
        let store = TaskStore(fileURL: workspace, settingsURL: settings, seed: false)
        let original = store.settings.calendarOptions.sourceColors
        var colors = original
        colors[.inbox] = "#123456"
        try FileManager.default.createDirectory(at: settings, withIntermediateDirectories: false)
        XCTAssertFalse(store.saveCalendarSourceColors(colors, expected: original))
        XCTAssertEqual(store.settings.calendarOptions.sourceColors, original)
        try FileManager.default.removeItem(at: settings)
        XCTAssertTrue(store.saveCalendarSourceColors(colors, expected: original))
        XCTAssertFalse(store.saveCalendarSourceColors(original, expected: original))
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: settings)).calendarOptions.sourceColors, colors)
        XCTAssertEqual(try Data(contentsOf: workspace), bytes)
    }

}
