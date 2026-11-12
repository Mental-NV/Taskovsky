import XCTest
import TaskovskyDomain

final class LocalReminderPlanTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func task(_ index: Int, at date: Date) -> TaskItem {
        TaskItem(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                 title: "Private title", body: "Private body", reminderDate: date)
    }

    func testEligibilityUsesStoredActiveTasksAndNotViewVisibility() {
        var archived = TaskList(name: "Archived", color: "#123456"); archived.isArchived = true
        var excluded = TaskList(name: "Excluded", color: "#123456"); excluded.showsInSmartLists = false
        var tasks = (1...8).map { task($0, at: now + 60) }
        tasks[1].completedAt = now; tasks[2].wontDoAt = now; tasks[3].deletedAt = now
        tasks[4].kind = .note; tasks[5].listID = archived.id; tasks[6].listID = excluded.id
        tasks[7].listID = UUID() // Existing missing-list policy remains eligible.
        let plan = LocalReminderPlan(fromPersisted: .init(tasks: tasks, lists: [archived, excluded]), now: now)
        XCTAssertEqual(plan.requests.map(\.taskID), [tasks[0].id, tasks[6].id, tasks[7].id])
        XCTAssertTrue(plan.requests.allSatisfy { $0.title == "Taskovsky reminder" && $0.body == "A task reminder is due." })
    }

    func testEndpointDedupeAndNoForecastOrDueOnlyReminder() {
        var repeated = task(1, at: now + 60); repeated.recurrence = .daily
        repeated.dueDate = now + 60; repeated.hasDueTime = true
        repeated.scheduledDuration = .init(start: now + 30, end: now + 60)
        repeated.endReminderEnabled = true
        repeated.additionalReminderDates = [now + 60, now + 120]
        let dueOnly = TaskItem(title: "Due only", dueDate: now + 90)
        let plan = LocalReminderPlan(fromPersisted: .init(tasks: [repeated, repeated, dueOnly]), now: now)
        XCTAssertEqual(plan.requests.map(\.fireDate), [now + 60, now + 120])
        var successor = task(2, at: now + 86_460); successor.recurrenceSourceID = repeated.id
        XCTAssertEqual(LocalReminderPlan(fromPersisted: .init(tasks: [repeated, successor]), now: now).eligibleCount, 3)
    }

    func testExactDSTInstantsAndFractionalDatesKeepStableIdentity() throws {
        let first = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T05:30:00Z"))
        let second = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T06:30:00Z"))
        var repeatedHour = task(1, at: first); repeatedHour.timeZoneID = "America/New_York"
        repeatedHour.additionalReminderDates = [second, second + 0.25]
        let data = WorkspaceData(tasks: [repeatedHour])
        let plan = LocalReminderPlan(fromPersisted: data, now: first - 1)
        XCTAssertEqual(plan.requests.map(\.fireDate), [first, second, second + 0.25])
        XCTAssertEqual(Set(plan.requests.map(\.identifier)).count, 3)
        XCTAssertEqual(plan, LocalReminderPlan(fromPersisted: data, now: first - 0.5))
    }

    func testBudgetOrderingAndReplenishmentAreDeterministic() {
        let tasks = (1...40).reversed().map { task($0, at: now + Double($0 / 2 + 1)) }
        let data = WorkspaceData(tasks: tasks)
        let plan = LocalReminderPlan(fromPersisted: data, now: now, limit: Int.max)
        XCTAssertEqual(plan.requests.count, 32); XCTAssertEqual(plan.eligibleCount, 40); XCTAssertEqual(plan.deferredCount, 8)
        XCTAssertEqual(plan, LocalReminderPlan(fromPersisted: .init(tasks: Array(tasks.reversed())), now: now))
        XCTAssertEqual(LocalReminderPlan(fromPersisted: data, now: now, limit: -1).requests.count, 0)
        XCTAssertEqual(LocalReminderPlan(fromPersisted: data, now: now, limit: 3).deferredCount, 37)
        let later = LocalReminderPlan(fromPersisted: data, now: now + 10)
        XCTAssertTrue(later.requests.allSatisfy { $0.fireDate > now + 10 })
        XCTAssertEqual(later.deferredCount, 0)
    }

    func testPastNonfiniteAndInvalidClockFailClosed() {
        var record = task(1, at: now - 1)
        record.additionalReminderDates = [now, now + 1, Date(timeIntervalSinceReferenceDate: .infinity), Date(timeIntervalSinceReferenceDate: .nan)]
        let data = WorkspaceData(tasks: [record])
        let plan = LocalReminderPlan(fromPersisted: data, now: now)
        XCTAssertEqual(plan.requests.map(\.fireDate), [now + 1])
        let invalid = LocalReminderPlan(fromPersisted: data, now: Date(timeIntervalSinceReferenceDate: .nan))
        XCTAssertFalse(invalid.hasValidClock)
        XCTAssertTrue(invalid.changes(fromPending: plan.requests).identifiersToRemove.isEmpty)
        XCTAssertTrue(invalid.changes(fromPending: plan.requests).requestsToAdd.isEmpty)
    }

    func testReconciliationLeavesForeignRequestsAndAvoidsUnchangedRescheduling() throws {
        let original = task(1, at: now + 60)
        let plan = LocalReminderPlan(fromPersisted: .init(tasks: [original]), now: now)
        let existing = try XCTUnwrap(plan.requests.first)
        let foreign = LocalReminderRequest(identifier: "another-feature.1", taskID: UUID(), fireDate: now + 1, title: "Other", body: "Other")
        let lookalike = LocalReminderRequest(identifier: LocalReminderPlan.identifierPrefix + "unrelated", taskID: UUID(), fireDate: now + 1, title: "Other", body: "Other")
        let pending = [existing, foreign, lookalike]
        XCTAssertEqual(plan.changes(fromPending: pending).requestsToAdd, [])
        XCTAssertEqual(plan.changes(fromPending: pending).identifiersToRemove, [])
        var moved = original; moved.reminderDate = now + 120
        let changed = LocalReminderPlan(fromPersisted: .init(tasks: [moved]), now: now)
        XCTAssertEqual(changed.changes(fromPending: pending).identifiersToRemove, [existing.identifier])
        XCTAssertEqual(changed.changes(fromPending: pending).requestsToAdd, changed.requests)
        let empty = LocalReminderPlan(fromPersisted: .init(), now: now)
        XCTAssertEqual(empty.changes(fromPending: pending).identifiersToRemove, [existing.identifier])
        let obsoleteContent = LocalReminderRequest(identifier: existing.identifier, taskID: existing.taskID, fireDate: existing.fireDate, title: "Old", body: "Old")
        XCTAssertEqual(plan.changes(fromPending: [obsoleteContent]).requestsToAdd, [existing])
    }
}
