import XCTest
@testable import TaskovskyCore

/// Subtree-clone reminder policy: cloning must distinguish due-date
/// start-of-day normalization from reminder instants. An all-day member's
/// reminders keep their wall-clock time and relative calendar day when
/// shifted (09:00 stays 09:00, a previous-day reminder stays previous-day),
/// across ordinary weeks and DST transitions in the task's zone. Timed
/// members keep exact elapsed-time shifting. These tests complete a
/// recurring parent through the real `toggleComplete` → successor →
/// `cloneSubtreeIntoSuccessor` path and inspect the clone.
final class CloneReminderTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    private func gregorian(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func at(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @MainActor private func fetch(_ store: TaskStore, _ id: UUID) throws -> TaskItem {
        try XCTUnwrap(store.data.tasks.first { $0.id == id })
    }

    /// All-day child with 09:00 + 17:00 same-day reminders and a 09:00
    /// previous-day reminder: every reminder keeps its clock time and its
    /// day offset after the clone shifts one calendar day.
    @MainActor func testClonePreservesAllDayReminderClockTimeAndDayOffset() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let calendar = gregorian()
        let due = at(calendar, 2026, 11, 9)
        let parent = store.createTask(title: "Repeat parent", dueDate: due)
        var updated = try fetch(store, parent)
        updated.recurrence = .daily
        updated.hasDueTime = false
        updated.timeZoneID = "UTC"
        store.updateTask(updated, applyDefaultReminders: false)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "All-day child"))
        var updatedChild = try fetch(store, child)
        updatedChild.dueDate = due
        updatedChild.hasDueTime = false
        updatedChild.timeZoneID = "UTC"
        updatedChild.reminderDates = [
            at(calendar, 2026, 11, 9, 9),
            at(calendar, 2026, 11, 9, 17),
            at(calendar, 2026, 11, 8, 9),
        ]
        store.updateTask(updatedChild, applyDefaultReminders: false)
        store.toggleComplete(id: parent)
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        XCTAssertEqual(clone.dueDate, at(calendar, 2026, 11, 10))
        XCTAssertFalse(clone.hasDueTime)
        XCTAssertEqual(clone.reminderDates, [
            at(calendar, 2026, 11, 9, 9),
            at(calendar, 2026, 11, 10, 9),
            at(calendar, 2026, 11, 10, 17),
        ])
    }

    /// DST spring-forward week in the task zone (America/New_York, clocks
    /// forward Mar 8 2026): a Friday → Friday weekly clone keeps 09:00
    /// wall-clock time on both sides of the transition.
    @MainActor func testClonePreservesWallClockAcrossDST() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let zoneID = "America/New_York"
        let calendar = gregorian(zoneID)
        let due = at(calendar, 2026, 3, 6) // Friday, EST
        let parent = store.createTask(title: "Weekly parent", dueDate: due)
        var updated = try fetch(store, parent)
        updated.recurrence = .weekly
        updated.hasDueTime = false
        updated.timeZoneID = zoneID
        store.updateTask(updated, applyDefaultReminders: false)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Zone child"))
        var updatedChild = try fetch(store, child)
        updatedChild.dueDate = due
        updatedChild.hasDueTime = false
        updatedChild.timeZoneID = zoneID
        updatedChild.reminderDates = [
            at(calendar, 2026, 3, 6, 9),
            at(calendar, 2026, 3, 5, 17),
        ]
        store.updateTask(updatedChild, applyDefaultReminders: false)
        store.toggleComplete(id: parent)
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        // Same wall-clock times, shifted one calendar week in the task zone.
        XCTAssertEqual(clone.reminderDates, [
            at(calendar, 2026, 3, 12, 17),
            at(calendar, 2026, 3, 13, 9),
        ])
        let parts = calendar.dateComponents([.hour, .minute], from: try XCTUnwrap(clone.reminderDates.last))
        XCTAssertEqual(parts.hour, 9)
        XCTAssertEqual(parts.minute, 0)
    }

    /// Mixed zones, spring forward: parent in UTC, all-day child in
    /// America/New_York with a 09:00 reminder. March 8 2026 springs forward.
    /// The clone keeps 09:00 wall-clock in the CHILD zone (09:00 EDT), not
    /// the root zone's wall time (which would read 10:00).
    @MainActor func testMixedZonesPreserveMemberWallClockSpringForward() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let utc = gregorian("UTC")
        let ny = gregorian("America/New_York")
        let parentDue = at(utc, 2026, 3, 6) // Friday, UTC midnight
        let parent = store.createTask(title: "UTC parent", dueDate: parentDue)
        var updated = try fetch(store, parent)
        updated.recurrence = .weekly
        updated.hasDueTime = false
        updated.timeZoneID = "UTC"
        store.updateTask(updated, applyDefaultReminders: false)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "NY child"))
        var updatedChild = try fetch(store, child)
        updatedChild.dueDate = parentDue
        updatedChild.hasDueTime = false
        updatedChild.timeZoneID = "America/New_York"
        // 09:00 in the CHILD zone on the due day.
        updatedChild.reminderDates = [at(ny, 2026, 3, 6, 9)]
        store.updateTask(updatedChild, applyDefaultReminders: false)
        store.toggleComplete(id: parent)
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        // Parent displacement is 7 days; the member arithmetic runs in the
        // child zone: NY Mar 5 (the due instant's NY day) + 7 = Mar 12 EDT,
        // reminder offset +1 day at 09:00 wall time.
        XCTAssertEqual(clone.dueDate, at(ny, 2026, 3, 12))
        XCTAssertEqual(clone.reminderDates, [at(ny, 2026, 3, 13, 9)])
        let parts = ny.dateComponents([.hour, .minute], from: try XCTUnwrap(clone.reminderDates.first))
        XCTAssertEqual(parts.hour, 9, "child-zone wall clock, not root-zone 10:00")
        XCTAssertEqual(parts.minute, 0)
    }

    /// Mixed zones, fall back: the same shape across November 1 2026 keeps
    /// 09:00 EST instead of slipping to 08:00.
    @MainActor func testMixedZonesPreserveMemberWallClockFallBack() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let utc = gregorian("UTC")
        let ny = gregorian("America/New_York")
        let parentDue = at(utc, 2026, 10, 30) // Friday, UTC midnight
        let parent = store.createTask(title: "UTC parent", dueDate: parentDue)
        var updated = try fetch(store, parent)
        updated.recurrence = .weekly
        updated.hasDueTime = false
        updated.timeZoneID = "UTC"
        store.updateTask(updated, applyDefaultReminders: false)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "NY child"))
        var updatedChild = try fetch(store, child)
        updatedChild.dueDate = parentDue
        updatedChild.hasDueTime = false
        updatedChild.timeZoneID = "America/New_York"
        updatedChild.reminderDates = [at(ny, 2026, 10, 30, 9)]
        store.updateTask(updatedChild, applyDefaultReminders: false)
        store.toggleComplete(id: parent)
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        XCTAssertEqual(clone.dueDate, at(ny, 2026, 11, 5))
        XCTAssertEqual(clone.reminderDates, [at(ny, 2026, 11, 6, 9)])
        let parts = ny.dateComponents([.hour, .minute], from: try XCTUnwrap(clone.reminderDates.first))
        XCTAssertEqual(parts.hour, 9, "child-zone wall clock across fall-back")
        XCTAssertEqual(parts.minute, 0)
    }

    /// Mixed zones, timed child: elapsed shifting stays exact and
    /// zone-independent.
    @MainActor func testMixedZonesTimedKeepsElapsed() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let utc = gregorian("UTC")
        let parentDue = at(utc, 2026, 3, 6, 14)
        let parent = store.createTask(title: "UTC timed parent", dueDate: parentDue)
        var updated = try fetch(store, parent)
        updated.recurrence = .weekly
        updated.hasDueTime = true
        updated.timeZoneID = "UTC"
        store.updateTask(updated, applyDefaultReminders: false)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "NY timed child"))
        var updatedChild = try fetch(store, child)
        updatedChild.dueDate = parentDue
        updatedChild.hasDueTime = true
        updatedChild.timeZoneID = "America/New_York"
        updatedChild.reminderDates = [parentDue.addingTimeInterval(-1800)]
        store.updateTask(updatedChild, applyDefaultReminders: false)
        store.toggleComplete(id: parent)
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        XCTAssertEqual(clone.dueDate, parentDue.addingTimeInterval(7 * 24 * 3600))
        XCTAssertEqual(clone.reminderDates, [parentDue.addingTimeInterval(7 * 24 * 3600 - 1800)])
    }

    /// Timed members keep exact elapsed-time shifting (control case: this
    /// behavior already worked and must not change).
    @MainActor func testCloneKeepsTimedElapsedTime() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let calendar = gregorian()
        let due = at(calendar, 2026, 11, 9, 14)
        let parent = store.createTask(title: "Timed parent", dueDate: due)
        var updated = try fetch(store, parent)
        updated.recurrence = .daily
        updated.hasDueTime = true
        updated.timeZoneID = "UTC"
        store.updateTask(updated, applyDefaultReminders: false)
        let child = try XCTUnwrap(store.addSubtask(to: parent, title: "Timed child"))
        var updatedChild = try fetch(store, child)
        updatedChild.dueDate = due
        updatedChild.hasDueTime = true
        updatedChild.reminderDates = [at(calendar, 2026, 11, 9, 13, 30)]
        store.updateTask(updatedChild, applyDefaultReminders: false)
        store.toggleComplete(id: parent)
        let clone = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == child })
        XCTAssertEqual(clone.dueDate, at(calendar, 2026, 11, 10, 14))
        XCTAssertEqual(clone.reminderDates, [at(calendar, 2026, 11, 10, 13, 30)])
    }
}
