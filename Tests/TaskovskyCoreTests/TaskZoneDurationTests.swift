import XCTest
@testable import TaskovskyCore

/// All-day duration windows must be normalized in the RECORD's zone, not the
/// host/settings zone. `updateTask` runs schedule coherence on every save;
/// when `timeZoneID` names a zone different from the Mac's, `startOfDay`
/// normalization in the wrong calendar shifts absolute endpoints and the
/// displayed due day. Timed windows carry exact instants and are unaffected.
final class TaskZoneDurationTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    private func zoneCalendar(_ id: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: id)!
        return calendar
    }

    private func midnight(_ y: Int, _ m: Int, _ d: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// True when the host zone currently matches the candidate zone, in
    /// which case the wrong-calendar path is indistinguishable: such cases
    /// are skipped so at least one zone always exercises the bug.
    private func hostMatchesZone(_ id: String, at date: Date) -> Bool {
        TimeZone.current.secondsFromGMT(for: date)
            == TimeZone(identifier: id)!.secondsFromGMT(for: date)
    }

    @MainActor private func fetch(_ store: TaskStore, _ id: UUID) throws -> TaskItem {
        try XCTUnwrap(store.data.tasks.first { $0.id == id })
    }

    // MARK: - All-day endpoints stay on task-zone midnights

    @MainActor func testAllDayWindowSurvivesUnrelatedEditInTaskZone() throws {
        var ran = 0
        for zoneID in ["America/New_York", "Pacific/Auckland"] {
            let taskCal = zoneCalendar(zoneID)
            let start = midnight(2026, 6, 10, in: taskCal)
            let end = midnight(2026, 6, 12, in: taskCal)
            if hostMatchesZone(zoneID, at: start) { continue }
            ran += 1
            let (store, dir) = makeStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            let id = store.createTask(title: "Zone probe")
            var task = try fetch(store, id)
            task.timeZoneID = zoneID
            task.dueDate = end
            task.hasDueTime = false
            task.scheduledDuration = TaskDurationRange(start: start, end: end, isAllDay: true)
            store.updateTask(task, applyDefaultReminders: false)
            // An unrelated title edit must not shift absolute endpoints.
            var edited = try fetch(store, id)
            edited.title = "Zone probe (renamed)"
            store.updateTask(edited, applyDefaultReminders: false)
            let saved = try fetch(store, id)
            XCTAssertEqual(saved.scheduledDuration?.start, start, zoneID)
            XCTAssertEqual(saved.scheduledDuration?.end, end, zoneID)
            XCTAssertEqual(saved.dueDate, end, zoneID)
            XCTAssertFalse(saved.hasDueTime)
            // Midnight in the TASK zone, not the host zone.
            let parts = taskCal.dateComponents([.hour, .minute, .second], from: try XCTUnwrap(saved.dueDate))
            XCTAssertEqual(parts.hour, 0, zoneID)
            XCTAssertEqual(parts.minute, 0, zoneID)
            let span = taskCal.dateComponents([.day], from: taskCal.startOfDay(for: start), to: taskCal.startOfDay(for: end)).day
            XCTAssertEqual(span, 2, zoneID)
        }
        XCTAssertGreaterThan(ran, 0, "at least one zone must differ from the host zone")
    }

    @MainActor func testAllDayWindowKeepsDaySpanAcrossDST() throws {
        var ran = 0
        // New York springs forward Mar 8 2026; Auckland falls back Apr 5 2026.
        let cases = [("America/New_York", (2026, 3, 7), (2026, 3, 9)),
                     ("Pacific/Auckland", (2026, 4, 4), (2026, 4, 6))]
        for (zoneID, s, e) in cases {
            let taskCal = zoneCalendar(zoneID)
            let start = midnight(s.0, s.1, s.2, in: taskCal)
            let end = midnight(e.0, e.1, e.2, in: taskCal)
            if hostMatchesZone(zoneID, at: start) { continue }
            ran += 1
            let (store, dir) = makeStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            let id = store.createTask(title: "DST probe")
            var task = try fetch(store, id)
            task.timeZoneID = zoneID
            task.dueDate = end
            task.hasDueTime = false
            task.scheduledDuration = TaskDurationRange(start: start, end: end, isAllDay: true)
            store.updateTask(task, applyDefaultReminders: false)
            var edited = try fetch(store, id)
            edited.title = "DST probe (renamed)"
            store.updateTask(edited, applyDefaultReminders: false)
            let saved = try fetch(store, id)
            XCTAssertEqual(saved.scheduledDuration?.start, start, zoneID)
            XCTAssertEqual(saved.scheduledDuration?.end, end, zoneID)
            XCTAssertEqual(saved.dueDate, end, zoneID)
            let span = taskCal.dateComponents([.day], from: taskCal.startOfDay(for: start), to: taskCal.startOfDay(for: end)).day
            XCTAssertEqual(span, 2, zoneID)
        }
        XCTAssertGreaterThan(ran, 0, "at least one zone must differ from the host zone")
    }

    // MARK: - Zone change coherence and reminder alignment

    @MainActor func testChangingZoneKeepsCoherentEndpointsAndReminders() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.settings.allDayReminder = .onDay9
        let ny = zoneCalendar("America/New_York")
        let auck = zoneCalendar("Pacific/Auckland")
        let start = midnight(2026, 6, 10, in: ny)
        let end = midnight(2026, 6, 12, in: ny)
        let id = store.createTask(title: "Zone move")
        var task = try fetch(store, id)
        task.timeZoneID = "America/New_York"
        task.dueDate = end
        task.hasDueTime = false
        task.scheduledDuration = TaskDurationRange(start: start, end: end, isAllDay: true)
        task.reminderDates = []
        task.reminderFollowsSchedule = nil
        store.updateTask(task, applyDefaultReminders: false)
        // Move the record to Auckland with default reminders on.
        var moved = try fetch(store, id)
        moved.timeZoneID = "Pacific/Auckland"
        store.updateTask(moved)
        let saved = try fetch(store, id)
        XCTAssertEqual(saved.dueDate, saved.scheduledDuration?.end)
        XCTAssertFalse(saved.hasDueTime)
        // Endpoints are Auckland-midnight normalized, not bit-identical to
        // New York midnights (the stored zone changed, so the wall days do).
        let savedEnd = try XCTUnwrap(saved.scheduledDuration?.end)
        let endParts = auck.dateComponents([.hour, .minute, .second], from: savedEnd)
        XCTAssertEqual(endParts.hour, 0)
        XCTAssertEqual(endParts.minute, 0)
        // Default reminder recomputed in the NEW zone: 9am on the due day.
        let expected = TaskStore.defaultReminderDates(
            due: try XCTUnwrap(saved.dueDate), hasTime: false,
            settings: store.settings, calendar: auck)
        XCTAssertEqual(saved.reminderDates, expected)
        XCTAssertEqual(saved.reminderFollowsSchedule, true)
        XCTAssertEqual(expected.count, 1)
        XCTAssertEqual(auck.component(.hour, from: try XCTUnwrap(expected.first)), 9)
    }

    // MARK: - Timed windows and fallback behavior

    @MainActor func testTimedWindowInstantsNeverShift() throws {
        var ran = 0
        for zoneID in ["America/New_York", "Pacific/Auckland"] {
            let taskCal = zoneCalendar(zoneID)
            let start = taskCal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9, minute: 30))!
            let end = taskCal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 11, minute: 0))!
            if hostMatchesZone(zoneID, at: start) { continue }
            ran += 1
            let (store, dir) = makeStore()
            defer { try? FileManager.default.removeItem(at: dir) }
            let id = store.createTask(title: "Timed probe")
            var task = try fetch(store, id)
            task.timeZoneID = zoneID
            task.dueDate = end
            task.hasDueTime = true
            task.scheduledDuration = TaskDurationRange(start: start, end: end)
            store.updateTask(task, applyDefaultReminders: false)
            var edited = try fetch(store, id)
            edited.title = "Timed probe (renamed)"
            store.updateTask(edited, applyDefaultReminders: false)
            let saved = try fetch(store, id)
            XCTAssertEqual(saved.scheduledDuration?.start, start, zoneID)
            XCTAssertEqual(saved.scheduledDuration?.end, end, zoneID)
            XCTAssertEqual(saved.dueDate, end, zoneID)
            XCTAssertTrue(saved.hasDueTime)
        }
        XCTAssertGreaterThan(ran, 0, "at least one zone must differ from the host zone")
    }

    @MainActor func testUnknownZoneFallsBackToSettingsCalendar() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ny = zoneCalendar("America/New_York")
        let start = midnight(2026, 6, 10, in: ny)
        let end = midnight(2026, 6, 12, in: ny)
        let id = store.createTask(title: "Unknown zone")
        var task = try fetch(store, id)
        task.timeZoneID = "Not/AZone"
        task.dueDate = end
        task.hasDueTime = false
        task.scheduledDuration = TaskDurationRange(start: start, end: end, isAllDay: true)
        // Must not crash; falls back exactly like the reminder path does.
        store.updateTask(task, applyDefaultReminders: false)
        let saved = try fetch(store, id)
        let settingsCal = store.settings.calendar
        XCTAssertEqual(saved.scheduledDuration?.start, settingsCal.startOfDay(for: start))
        XCTAssertEqual(saved.scheduledDuration?.end, settingsCal.startOfDay(for: end))
        XCTAssertEqual(saved.dueDate, saved.scheduledDuration?.end)
        XCTAssertFalse(saved.hasDueTime)
    }

    @MainActor func testDisabledTimezoneSettingKeepsStoredZone() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.settings.enableTimeZone = false
        let ny = zoneCalendar("America/New_York")
        let start = midnight(2026, 6, 10, in: ny)
        let end = midnight(2026, 6, 12, in: ny)
        let id = store.createTask(title: "Zone kept")
        var task = try fetch(store, id)
        task.timeZoneID = "America/New_York"
        task.dueDate = end
        task.hasDueTime = false
        task.scheduledDuration = TaskDurationRange(start: start, end: end, isAllDay: true)
        store.updateTask(task, applyDefaultReminders: false)
        var edited = try fetch(store, id)
        edited.title = "Zone kept (renamed)"
        store.updateTask(edited, applyDefaultReminders: false)
        let saved = try fetch(store, id)
        // The disabled setting must not silently clear the record's zone,
        // and coherence still honors it.
        XCTAssertEqual(saved.timeZoneID, "America/New_York")
        XCTAssertEqual(saved.scheduledDuration?.start, start)
        XCTAssertEqual(saved.scheduledDuration?.end, end)
    }
}
