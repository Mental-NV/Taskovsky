import XCTest
@testable import TaskovskyCore

/// Integration gaps in the nominal series implementation, exercised through
/// stable production API (store completion/updateTask, engine queries,
/// preview helpers) plus the shared stepping policy:
/// - G1: explicit-date rules stay verbatim even with skipWeekends; daily /
///   weekly store behavior matches the engine.
/// - G2: the ADJUSTED occurrence is validated against the custom endDate
///   across nextOccurrence, successors, counted/uncounted previews, and
///   membership; a nil step never resurrects.
/// - G3: roll collisions with the displayed due advance instead of
///   duplicating; previews match completion.
/// - G4: manual reschedules rebase the nominal at the store boundary with
///   the count preserved; no-op saves preserve; rule clear/replace
///   restarts; staged previews use the same policy.
final class NominalSeriesIntegrationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func midnight(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func lastDayRule(interval: Int = 2) -> CustomRecurrence {
        CustomRecurrence(anchor: .dueDate, interval: interval, unit: .months,
                         includesLastDayOfMonth: true, skipWeekends: true)
    }

    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    @MainActor private func fetch(_ store: TaskStore, _ id: UUID) throws -> TaskItem {
        try XCTUnwrap(store.data.tasks.first { $0.id == id })
    }

    // MARK: - G1: explicit dates stay verbatim

    func testExplicitDatesIgnoreSkipWeekends() throws {
        // Saturday May 30 2026 14:00 must stay exactly there, not roll.
        let instant = date(2026, 5, 30, 14)
        XCTAssertEqual(calendar.component(.weekday, from: instant), 7)
        let rule = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .months, skipWeekends: true,
                                    specificDates: [instant])
        XCTAssertEqual(rule.nextOccurrence(after: date(2026, 5, 1), calendar: calendar), instant)
        XCTAssertEqual(rule.nextDueDateStep(after: date(2026, 5, 1), nominalBase: nil, calendar: calendar)?.adjusted, instant)
        // Explicit mode returns stored instants only (the start is not an
        // occurrence and is not included).
        XCTAssertEqual(rule.occurrences(from: date(2026, 5, 1), limit: 3, calendar: calendar), [instant])
    }

    @MainActor func testExplicitDateSuccessorStaysVerbatim() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let instant = date(2026, 5, 30, 14)
        let id = store.createTask(title: "Explicit", dueDate: date(2026, 5, 1))
        var task = try fetch(store, id)
        task.hasDueTime = true
        task.timeZoneID = "UTC"
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days, skipWeekends: true,
                                                specificDates: [instant])
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(successor.dueDate, instant)
    }

    @MainActor func testDailyWeeklyStoreMatchesEngine() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Daily with skipWeekends: Friday -> Monday, engine and store agree.
        let friday = date(2026, 5, 29) // a Friday
        XCTAssertEqual(calendar.component(.weekday, from: friday), 6)
        let daily = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days, skipWeekends: true)
        XCTAssertEqual(daily.nextOccurrence(after: friday, calendar: calendar), date(2026, 6, 1))
        let id = store.createTask(title: "Daily skip", dueDate: midnight(2026, 5, 29))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = daily
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(successor.dueDate, midnight(2026, 6, 1))
        // Weekly without skips: engine and preview agree across completion.
        let weekly = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .weeks, weekdays: [6])
        let start = midnight(2026, 5, 29)
        let chained = [start] + (1...3).reduce(into: [Date]()) { acc, _ in
            acc.append(weekly.nextOccurrence(after: acc.last ?? start, calendar: calendar)!)
        }
        XCTAssertEqual(weekly.occurrences(from: start, limit: 4, calendar: calendar), chained)
    }

    // MARK: - G2: adjusted date vs custom endDate

    private func endCappedRule() -> CustomRecurrence {
        var rule = lastDayRule()
        rule.endDate = midnight(2026, 5, 31)
        return rule
    }

    func testAdjustedOccurrenceExcludedByCustomEnd() throws {
        let rule = endCappedRule()
        // Nominal May 31 is within the end day, but its display (June 1)
        // escapes it: no next occurrence.
        XCTAssertNil(rule.nextOccurrence(after: midnight(2026, 3, 31), calendar: calendar, occurrenceIndex: 1))
        XCTAssertNil(rule.nextDueDateStep(after: midnight(2026, 3, 31), nominalBase: midnight(2026, 3, 31), calendar: calendar))
        XCTAssertEqual(rule.occurrences(from: midnight(2026, 3, 31), limit: 4, calendar: calendar), [midnight(2026, 3, 31)])
        XCTAssertFalse(rule.isOccurrence(on: midnight(2026, 6, 1), seriesStart: midnight(2026, 3, 31), calendar: calendar))
        XCTAssertTrue(rule.isOccurrence(on: midnight(2026, 3, 31), seriesStart: midnight(2026, 3, 31), calendar: calendar))
    }

    func testCountedPreviewRespectsRemainingCountFromRolledCurrent() {
        // Rolled June 1 (nominal May 31) at index 2 of a max-2 series is
        // already the final occurrence: no remaining preview.
        var ended = lastDayRule()
        ended.maxOccurrences = 2
        XCTAssertEqual(remainingOccurrences(rule: ended, current: midnight(2026, 6, 1), index: 2,
                                            calendar: calendar, nominal: midnight(2026, 5, 31)), [])
        // Same position in a max-3 series: exactly one remains (July 31),
        // not a fresh index-1 walk (July 31 + September 30).
        var oneLeft = lastDayRule()
        oneLeft.maxOccurrences = 3
        XCTAssertEqual(remainingOccurrences(rule: oneLeft, current: midnight(2026, 6, 1), index: 2,
                                            calendar: calendar, nominal: midnight(2026, 5, 31)),
                       [midnight(2026, 7, 31)])
    }

    func testCountedAndUncountedPreviewsExcludeRolledPastEnd() {
        var counted = endCappedRule()
        counted.maxOccurrences = 5
        // Uncounted: only the start survives.
        XCTAssertEqual(remainingOccurrences(rule: endCappedRule(), current: midnight(2026, 3, 31), index: 1,
                                            calendar: calendar, nominal: midnight(2026, 3, 31)), [])
        // Counted: the capped step ends the preview instead of emitting June 1.
        XCTAssertEqual(remainingOccurrences(rule: counted, current: midnight(2026, 3, 31), index: 1,
                                            calendar: calendar, nominal: midnight(2026, 3, 31)), [])
        // A series whose roll stays inside the end still previews (June 30
        // is within the inclusive June 30 end).
        var inside = lastDayRule(interval: 1)
        inside.endDate = midnight(2026, 6, 30)
        XCTAssertEqual(remainingOccurrences(rule: inside, current: midnight(2026, 4, 30), index: 1,
                                            calendar: calendar, nominal: midnight(2026, 4, 30)),
                       [midnight(2026, 6, 1), midnight(2026, 6, 30)])
    }

    @MainActor func testEndedSeriesSpawnsNothingAndNeverResurrects() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Ended", dueDate: midnight(2026, 3, 31))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = endCappedRule()
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        XCTAssertNil(store.data.tasks.first { $0.recurrenceSourceID == id },
                     "rolled June 1 escapes the May 31 custom end: no successor")
        XCTAssertNil(TaskStore.nextRecurrenceDate(for: try fetch(store, id), calendar: calendar))
    }

    // MARK: - G3: roll collisions advance, never duplicate

    func testRollCollisionAdvancesPastDisplayedDue() throws {
        // Monthly on the 1st and 31st with skipWeekends: Jan 31 (Sat) and
        // Feb 1 (Sun) 2026 both roll to Feb 2.
        let rule = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months,
                                    monthDays: [1, 31], skipWeekends: true)
        XCTAssertEqual(rule.weekendAdjusted(midnight(2026, 1, 31), calendar: calendar), midnight(2026, 2, 2))
        XCTAssertEqual(rule.weekendAdjusted(midnight(2026, 2, 1), calendar: calendar), midnight(2026, 2, 2))
        // Displayed due Feb 2 (rolled from the Jan 31 nominal): the step
        // must advance to a genuinely later occurrence, not re-emit Feb 2.
        let step = try XCTUnwrap(rule.nextDueDateStep(after: midnight(2026, 2, 2), nominalBase: midnight(2026, 1, 31),
                                                      calendar: calendar, occurrenceIndex: 2))
        XCTAssertGreaterThan(step.adjusted, midnight(2026, 2, 2))
        XCTAssertEqual(step.adjusted, midnight(2026, 3, 2))
        XCTAssertEqual(step.nominal, midnight(2026, 2, 28))
    }

    @MainActor func testCollisionCompletionNeverDuplicatesDue() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rule = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months,
                                    monthDays: [1, 31], skipWeekends: true)
        let id = store.createTask(title: "Collision", dueDate: midnight(2026, 1, 31))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = rule
        task.recurrenceNominalDate = midnight(2026, 1, 31)
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let first = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(first.dueDate, midnight(2026, 2, 2))
        store.toggleComplete(id: first.id)
        let second = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == first.id })
        XCTAssertGreaterThan(try XCTUnwrap(second.dueDate), try XCTUnwrap(first.dueDate))
        XCTAssertEqual(second.dueDate, midnight(2026, 3, 2))
        // Preview from the rolled due agrees with completion.
        XCTAssertEqual(remainingOccurrences(rule: rule, current: first.dueDate!, index: 2,
                                            calendar: calendar, extraLimit: 1, nominal: first.recurrenceNominalDate),
                       [midnight(2026, 3, 2)])
    }

    // MARK: - G4: store-boundary normalization

    /// Builds a genuine mid-series rolled state through production: series
    /// starts March 31, first completion spawns the rolled June 1 (nominal
    /// May 31, index 2).
    @MainActor private func makeRolledSeries(in store: TaskStore) throws -> UUID {
        let id = store.createTask(title: "Bimonthly", dueDate: midnight(2026, 3, 31))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = lastDayRule()
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let first = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(first.dueDate, midnight(2026, 6, 1))
        XCTAssertEqual(first.recurrenceNominalDate, midnight(2026, 5, 31))
        XCTAssertEqual(first.occurrenceIndex, 2)
        return first.id
    }

    @MainActor func testManualRescheduleRebasesNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = try makeRolledSeries(in: store)
        // Move the due date to August 1 keeping the rule: the stored
        // nominal (May 31) must not linger, or completion would spawn
        // July 31 BEFORE the manually chosen due.
        var moved = try fetch(store, id)
        moved.dueDate = midnight(2026, 8, 1)
        store.updateTask(moved, applyDefaultReminders: false)
        let saved = try fetch(store, id)
        XCTAssertEqual(saved.recurrenceNominalDate, midnight(2026, 8, 1))
        XCTAssertEqual(saved.occurrenceIndex, 2, "date-only edits preserve the count")
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        let successorDue = try XCTUnwrap(successor.dueDate)
        XCTAssertGreaterThan(successorDue, midnight(2026, 8, 1))
        XCTAssertEqual(successorDue, midnight(2026, 8, 31))
    }

    @MainActor func testNoOpSavePreservesRolledNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = try makeRolledSeries(in: store)
        var untouched = try fetch(store, id)
        untouched.title = "Bimonthly (renamed)"
        store.updateTask(untouched, applyDefaultReminders: false)
        let saved = try fetch(store, id)
        XCTAssertEqual(saved.recurrenceNominalDate, midnight(2026, 5, 31))
        XCTAssertEqual(saved.occurrenceIndex, 2)
    }

    @MainActor func testTimeOnlyChangeRebasesNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rule = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months, monthDays: [15], skipWeekends: true)
        let id = store.createTask(title: "Timed monthly", dueDate: date(2026, 6, 15, 14))
        var task = try fetch(store, id)
        task.hasDueTime = true
        task.timeZoneID = "UTC"
        task.customRecurrence = rule
        task.recurrenceNominalDate = date(2026, 6, 15, 14)
        store.updateTask(task, applyDefaultReminders: false)
        var moved = try fetch(store, id)
        moved.dueDate = date(2026, 6, 15, 16)
        store.updateTask(moved, applyDefaultReminders: false)
        XCTAssertEqual(try fetch(store, id).recurrenceNominalDate, date(2026, 6, 15, 16))
    }

    @MainActor func testDurationDerivedDueChangeRebasesNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Windowed", dueDate: midnight(2026, 3, 31))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = lastDayRule()
        task.scheduledDuration = TaskDurationRange(start: midnight(2026, 3, 31), end: midnight(2026, 3, 31), isAllDay: true)
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let first = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        let rolledID = first.id
        // Extend the window: coherence moves the due to the new end, and the
        // nominal follows it. The rolled successor carries its window along.
        let rolledTask = try XCTUnwrap(store.data.tasks.first(where: { $0.id == rolledID }))
        XCTAssertEqual(rolledTask.scheduledDuration?.end, midnight(2026, 6, 1))
        var extended = try fetch(store, rolledID)
        extended.scheduledDuration = TaskDurationRange(start: midnight(2026, 6, 1), end: midnight(2026, 8, 1), isAllDay: true)
        store.updateTask(extended, applyDefaultReminders: false)
        let saved = try fetch(store, rolledID)
        XCTAssertEqual(saved.dueDate, midnight(2026, 8, 1))
        XCTAssertEqual(saved.recurrenceNominalDate, midnight(2026, 8, 1))
        XCTAssertEqual(saved.occurrenceIndex, 2)
    }

    @MainActor func testClearingRuleViaStoreDropsNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = try makeRolledSeries(in: store)
        var cleared = try fetch(store, id)
        cleared.customRecurrence = nil
        store.updateTask(cleared, applyDefaultReminders: false)
        let saved = try fetch(store, id)
        XCTAssertNil(saved.recurrenceNominalDate)
        XCTAssertEqual(saved.occurrenceIndex, 1)
    }

    @MainActor func testReplacingRuleViaStoreRestarts() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = try makeRolledSeries(in: store)
        var replaced = try fetch(store, id)
        replaced.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [2])
        store.updateTask(replaced, applyDefaultReminders: false)
        let saved = try fetch(store, id)
        XCTAssertEqual(saved.occurrenceIndex, 1)
        XCTAssertEqual(saved.recurrenceNominalDate, midnight(2026, 6, 1))
    }

    // MARK: - G4: staged preview policy

    func testStagedNominalPolicy() {
        var saved = TaskItem(title: "T", dueDate: midnight(2026, 6, 1))
        saved.customRecurrence = lastDayRule()
        saved.recurrenceNominalDate = midnight(2026, 5, 31)
        saved.occurrenceIndex = 2
        // Unedited draft: the stored nominal.
        XCTAssertEqual(stagedNominal(draftDue: midnight(2026, 6, 1), draftRule: lastDayRule(), task: saved),
                       midnight(2026, 5, 31))
        // Edited date under the same rule: the staged due (store rebase).
        XCTAssertEqual(stagedNominal(draftDue: midnight(2026, 8, 1), draftRule: lastDayRule(), task: saved),
                       midnight(2026, 8, 1))
        // Changed rule: the staged due (store restart at the new series start).
        let weekly = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [2])
        XCTAssertEqual(stagedNominal(draftDue: midnight(2026, 6, 1), draftRule: weekly, task: saved),
                       midnight(2026, 6, 1))
        // Cleared rule: the staged due (no custom preview reads it, but the
        // policy stays total and unsurprising).
        XCTAssertEqual(stagedNominal(draftDue: midnight(2026, 6, 1), draftRule: nil, task: saved),
                       midnight(2026, 6, 1))
    }
}
