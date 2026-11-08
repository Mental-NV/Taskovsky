import XCTest
@testable import TaskovskyCore

/// Scheduled-window integration: creation defaults, validation, recurrence
/// carry, template re-shaping, and legacy decoding.
final class DurationTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor func testDefaultDurationAppliesToTimedDuesOnly() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.settings.defaultDurationMinutes = 30
        // Recognized timed due ("tomorrow at 9am"): the default block ends
        // at the due instant, independent of time zone.
        let timed = store.createTask(title: "Deep work tomorrow at 9am")
        let fetched = try XCTUnwrap(store.data.tasks.first { $0.id == timed })
        XCTAssertTrue(fetched.hasDueTime)
        XCTAssertEqual(fetched.scheduledDuration?.end, fetched.dueDate)
        XCTAssertEqual(fetched.scheduledDuration?.elapsed, 1800)
        // Dateless and all-day dues gain nothing silently.
        let dateless = store.createTask(title: "Someday")
        XCTAssertNil(store.data.tasks.first { $0.id == dateless }?.scheduledDuration)
        let allDay = store.createTask(title: "Holiday tomorrow")
        let allDayTask = try XCTUnwrap(store.data.tasks.first { $0.id == allDay })
        XCTAssertFalse(allDayTask.hasDueTime)
        XCTAssertNil(allDayTask.scheduledDuration)
    }

    @MainActor func testExplicitDurationBeatsDefaultAndHostileDrops() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.settings.defaultDurationMinutes = 60
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10, minute: 30))!
        // Timed due via explicit hasDueTime is an editor concern; here the
        // explicit window is validated and stored verbatim.
        let custom = TaskDurationRange(start: due.addingTimeInterval(-7200), end: due)
        let id = store.createTask(title: "Custom", dueDate: due, duration: custom)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.scheduledDuration, custom)
        // Hostile window (end before start) stores as none, never traps.
        task.scheduledDuration = TaskDurationRange(start: due, end: due.addingTimeInterval(-1)).validated(in: calendar)
        XCTAssertNil(task.scheduledDuration)
    }

    @MainActor func testRecurringSuccessorCarriesEndAnchoredDuration() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 9))!
        let id = store.createTask(title: "Daily", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.recurrence = .daily
        task.hasDueTime = true
        task.scheduledDuration = TaskDurationRange(start: due.addingTimeInterval(-3600), end: due)
        store.updateTask(task)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        // Next day; the window ends exactly at the due date (end-anchored,
        // never start-anchored) with the elapsed shape preserved.
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: due))
        XCTAssertEqual(successor.dueDate, next)
        let window = try XCTUnwrap(successor.scheduledDuration)
        XCTAssertEqual(window.end, next)
        XCTAssertEqual(window.elapsed, 3600)
        XCTAssertTrue(successor.hasDueTime)
    }

    @MainActor func testTemplateReanchorsDurationEndOntoDueDate() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let saved = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 14))!
        let id = store.createTask(title: "Routine", dueDate: saved)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.hasDueTime = true
        task.scheduledDuration = TaskDurationRange(start: saved.addingTimeInterval(-3600), end: saved)
        store.updateTask(task)
        let templateID = try XCTUnwrap(store.saveTemplate(from: id))
        // Instantiation onto a new due date keeps the shape (1h), anchored so
        // the window END is the due date.
        let target = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 9))!
        let instanceID = try XCTUnwrap(store.createTaskFromTemplate(id: templateID, dueDate: target))
        let instance = try XCTUnwrap(store.data.tasks.first { $0.id == instanceID })
        let window = try XCTUnwrap(instance.scheduledDuration)
        XCTAssertEqual(window.end, target)
        XCTAssertEqual(window.elapsed, 3600)
        XCTAssertTrue(instance.hasDueTime)
        // Dateless instantiation carries the absolute window AND its due
        // (records are never undated with absolute windows).
        let datelessID = try XCTUnwrap(store.createTaskFromTemplate(id: templateID))
        let dateless = try XCTUnwrap(store.data.tasks.first { $0.id == datelessID })
        XCTAssertEqual(dateless.scheduledDuration?.end, saved)
        XCTAssertEqual(dateless.dueDate, saved)
        XCTAssertTrue(dateless.hasDueTime)
    }

    @MainActor func testCreateCoheresMismatchedAndUndatedWindows() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
        // Explicit window with a different due endpoint: the window wins.
        let window = TaskDurationRange(start: due.addingTimeInterval(-7200), end: due.addingTimeInterval(-3600))
        let id = store.createTask(title: "Mismatched", dueDate: due, duration: window)
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.dueDate, window.end)
        XCTAssertEqual(task.scheduledDuration?.end, task.dueDate)
        XCTAssertTrue(task.hasDueTime)
        // Explicit window with no due date: the end becomes the due date.
        let bare = TaskDurationRange(start: due, end: due.addingTimeInterval(3600))
        let bareID = store.createTask(title: "Undated", duration: bare)
        let bareTask = try XCTUnwrap(store.data.tasks.first { $0.id == bareID })
        XCTAssertEqual(bareTask.dueDate, bare.end)
        XCTAssertTrue(bareTask.hasDueTime)
        // All-day window: no due time, end still anchors. Bounds normalize
        // to whole days in the store calendar, so the test asserts the
        // coherence invariant (due == end) rather than the raw input.
        let day = calendar.startOfDay(for: due)
        let allDay = TaskDurationRange(start: day, end: day.addingTimeInterval(86400), isAllDay: true)
        let allDayID = store.createTask(title: "All day", duration: allDay)
        let allDayTask = try XCTUnwrap(store.data.tasks.first { $0.id == allDayID })
        XCTAssertEqual(allDayTask.dueDate, allDayTask.scheduledDuration?.end)
        XCTAssertFalse(allDayTask.hasDueTime)
        XCTAssertEqual(allDayTask.scheduledDuration?.isAllDay, true)
    }

    @MainActor func testUpdateRepairsIncoherentSchedule() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
        let id = store.createTask(title: "T", dueDate: due)
        // Window without a matching due: save snaps the due to the end.
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.dueDate = nil
        task.hasDueTime = false
        task.scheduledDuration = TaskDurationRange(start: due.addingTimeInterval(-3600), end: due)
        store.updateTask(task)
        let snapped = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(snapped.dueDate, due)
        XCTAssertTrue(snapped.hasDueTime)
        // Mismatched due with a window: save snaps the due to the end.
        var moved = snapped
        moved.dueDate = due.addingTimeInterval(7200)
        store.updateTask(moved)
        XCTAssertEqual(store.data.tasks.first { $0.id == id }?.dueDate, due)
        // Invalid window drops instead of stranding incoherence.
        var hostile = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        hostile.scheduledDuration = TaskDurationRange(start: due, end: due.addingTimeInterval(-1))
        store.updateTask(hostile)
        XCTAssertNil(store.data.tasks.first { $0.id == id }?.scheduledDuration)
    }

    @MainActor func testDSTTimedSuccessorKeepsElapsedAllDayKeepsSpan() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        // Spring forward: 2026-03-08 02:00 → 03:00. A daily noon series
        // keeps exact elapsed shape through the transition.
        let due = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        let id = store.createTask(title: "DST", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.recurrence = .daily
        task.hasDueTime = true
        task.timeZoneID = "America/New_York"
        task.scheduledDuration = TaskDurationRange(start: due.addingTimeInterval(-3600), end: due)
        store.updateTask(task)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        let window = try XCTUnwrap(successor.scheduledDuration)
        XCTAssertEqual(window.end, successor.dueDate)
        XCTAssertEqual(window.elapsed, 3600)
        // All-day multi-day span survives day-for-day. The 48h input always
        // spans exactly two midnights in any zone, and every assertion runs
        // in the store's own calendar (which the spawn also uses), so the
        // span arithmetic is deterministic everywhere; the NY timed case
        // above covers transition behavior.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = utc.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let spanID = store.createTask(title: "Span", dueDate: day)
        var span = try XCTUnwrap(store.data.tasks.first { $0.id == spanID })
        span.recurrence = .daily
        span.scheduledDuration = TaskDurationRange(
            start: day, end: utc.date(byAdding: .day, value: 2, to: day)!, isAllDay: true)
        store.updateTask(span)
        store.toggleComplete(id: spanID)
        let storeCalendar = store.settings.calendar
        let spanNext = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == spanID })
        let spanWindow = try XCTUnwrap(spanNext.scheduledDuration)
        XCTAssertEqual(spanWindow.end, spanNext.dueDate)
        XCTAssertFalse(spanNext.hasDueTime)
        let spanDays = storeCalendar.dateComponents([.day], from: spanWindow.start, to: spanWindow.end).day
        XCTAssertEqual(spanDays, 2)
    }

    func testAnchoredEndMeasuresSpanFromOriginalWindow() {
        // Regression: the span must come from the original window, not from
        // the anchor — anchoring a 2-day window 5 days out must stay 2 days.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let end = calendar.date(byAdding: .day, value: 2, to: start)!
        let window = TaskDurationRange(start: start, end: end, isAllDay: true)
        let anchor = calendar.date(byAdding: .day, value: 5, to: end)!
        let moved = window.anchoredEnd(at: anchor, calendar: calendar)
        XCTAssertEqual(moved.end, anchor)
        XCTAssertEqual(calendar.dateComponents([.day], from: moved.start, to: moved.end).day, 2)
        // Timed anchoring keeps exact elapsed seconds at the anchor.
        let timed = TaskDurationRange(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200))
        let timedMoved = timed.anchoredEnd(at: anchor, calendar: calendar)
        XCTAssertEqual(timedMoved.end, anchor)
        XCTAssertEqual(timedMoved.elapsed, 3600)
    }

    @MainActor func testCloneOffsetsSubtreeAroundNewOccurrence() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let due = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12))!
        let childDue = due.addingTimeInterval(3 * 3600)
        let parent = store.createTask(title: "P", dueDate: due)
        var updated = try XCTUnwrap(store.data.tasks.first { $0.id == parent })
        updated.recurrence = .daily
        updated.hasDueTime = true
        store.updateTask(updated)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "C"))
        var updatedChild = try XCTUnwrap(store.data.tasks.first { $0.id == child })
        updatedChild.dueDate = childDue
        updatedChild.hasDueTime = true
        updatedChild.scheduledDuration = TaskDurationRange(start: childDue.addingTimeInterval(-3600), end: childDue)
        store.updateTask(updatedChild)
        store.toggleComplete(id: parent)
        // The clone keeps the +3h relative structure around the new parent
        // occurrence, with its window end-anchored at its own shifted due.
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: due))
        XCTAssertEqual(clone.dueDate, next.addingTimeInterval(3 * 3600))
        XCTAssertEqual(clone.scheduledDuration?.end, clone.dueDate)
        XCTAssertEqual(clone.scheduledDuration?.elapsed, 3600)
    }

    func testLegacyTaskDecodesWithoutDuration() throws {
        let task = TaskItem(title: "Legacy")
        let encoded = try JSONEncoder().encode(task)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "scheduledDuration")
        let decoded = try JSONDecoder().decode(TaskItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.scheduledDuration)
    }
}
