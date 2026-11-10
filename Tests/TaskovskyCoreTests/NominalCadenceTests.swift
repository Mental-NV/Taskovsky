import XCTest
@testable import TaskovskyCore

/// Every-N-month nominal cadence: a weekend roll must not redefine the
/// series. March 31, 2026 -> nominal May 31 (Sunday, rolled to June 1) ->
/// July 31, not June 30. Interval alignment is tracked from the
/// unadjusted nominal occurrence stored on the task (`recurrenceNominalDate`),
/// never reconstructed from the displayed adjusted due date.
final class NominalCadenceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
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

    @MainActor func testMacRefusesToRewriteProtectedOccurrenceWithAnUnknownField() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let due = date(2026, 11, 9)
        let id = store.createTask(title: "Weekly", dueDate: due)
        var task = try fetch(store, id)
        task.recurrence = .weekly
        store.updateTask(task)
        XCTAssertNotNil(store.scheduleOnCalendar(id: id, operation: .setPoint(date: date(2026, 11, 10), allDay: false),
                                                 calendar: calendar, scope: .currentOccurrence))
        let expected = store.data
        let settings = store.settings
        let batch = try TaskTextBatch(text: "First\nSecond", destination: .inbox, workspace: expected,
                                      settings: settings, now: due, calendar: calendar, recognizesDetails: false)
        let file = store.fileURL
        XCTAssertFalse(TaskStore(fileURL: file, seed: false).needsRecovery)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var collection = try XCTUnwrap(object["tasks"] as? [String: Any])
        var records = try XCTUnwrap(collection["records"] as? [[String: Any]])
        var baseline = try XCTUnwrap(records.first?["originalOccurrenceSchedule"] as? [String: Any])
        baseline["futurePolicy"] = ["retain": true]
        records[0]["originalOccurrenceSchedule"] = baseline
        collection["records"] = records
        object["tasks"] = collection
        let newer = try JSONSerialization.data(withJSONObject: object)
        try newer.write(to: file, options: .atomic)
        guard case .uncertain = store.createTextBatch(batch, expected: expected, expectedSettings: settings) else {
            return XCTFail("Batch creation must refuse the newer protected data.")
        }
        XCTAssertEqual(store.data, expected)
        XCTAssertEqual(try Data(contentsOf: file), newer)
        let guarded = TaskStore(fileURL: file, seed: false)
        XCTAssertTrue(guarded.needsRecovery)
        guarded.save()
        XCTAssertEqual(try Data(contentsOf: file), newer)
    }

    // MARK: - Engine: nominal stepping

    /// A single step from the March start: nominal May 31, displayed June 1.
    func testNominalStepPreservesMay31() throws {
        let rule = lastDayRule()
        let nominal = try XCTUnwrap(rule.nextNominalOccurrence(after: date(2026, 3, 31), calendar: calendar, occurrenceIndex: 1))
        XCTAssertEqual(nominal, date(2026, 5, 31))
        XCTAssertEqual(rule.weekendAdjusted(nominal, calendar: calendar), date(2026, 6, 1))
    }

    /// Chained multi-occurrence generation: March -> June 1 -> July 31.
    func testOccurrencesChainAcrossRolledMonthBoundary() {
        let rule = lastDayRule()
        let preview = rule.occurrences(from: date(2026, 3, 31), limit: 4, calendar: calendar)
        XCTAssertEqual(preview, [date(2026, 3, 31), date(2026, 6, 1), date(2026, 7, 31), date(2026, 9, 30)])
    }

    /// Membership follows the rolled display days, never the drifted month.
    func testIsOccurrenceFollowsRolledDays() {
        let rule = lastDayRule()
        XCTAssertTrue(rule.isOccurrence(on: date(2026, 7, 31), seriesStart: date(2026, 3, 31), calendar: calendar))
        XCTAssertTrue(rule.isOccurrence(on: date(2026, 6, 1), seriesStart: date(2026, 3, 31), calendar: calendar))
        XCTAssertFalse(rule.isOccurrence(on: date(2026, 6, 30), seriesStart: date(2026, 3, 31), calendar: calendar))
    }

    /// A series that starts on an already-rolled display date keeps
    /// alignment once its nominal is supplied.
    func testIsOccurrenceWithNominalStart() {
        let rule = lastDayRule()
        XCTAssertTrue(rule.isOccurrence(on: date(2026, 7, 31), seriesStart: date(2026, 6, 1),
                                        calendar: calendar, nominalStart: date(2026, 5, 31)))
        XCTAssertFalse(rule.isOccurrence(on: date(2026, 6, 30), seriesStart: date(2026, 6, 1),
                                         calendar: calendar, nominalStart: date(2026, 5, 31)))
    }

    /// Year boundary: November 2026 -> January 2027 (Sunday, rolled to
    /// Feb 1) -> March 2027.
    func testNominalCadenceAcrossYearBoundary() {
        let rule = lastDayRule()
        let preview = rule.occurrences(from: date(2026, 11, 30), limit: 3, calendar: calendar)
        XCTAssertEqual(preview, [date(2026, 11, 30), date(2027, 2, 1), date(2027, 3, 31)])
    }

    /// A roll that stays inside the nominal month does not disturb the
    /// following occurrence.
    func testInMonthRollKeepsNextNominal() throws {
        // Every month on the 30th: April 30 2026 is a Thursday (no roll).
        let rule = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months,
                                    monthDays: [30], skipWeekends: true)
        let preview = rule.occurrences(from: date(2026, 4, 30), limit: 4, calendar: calendar)
        // May 30 is a Saturday -> June 1; June 30 is a Tuesday.
        XCTAssertEqual(preview, [date(2026, 4, 30), date(2026, 6, 1), date(2026, 6, 30), date(2026, 7, 30)])
    }

    /// Completion-anchored monthly series still advance from the completion
    /// instant and carry no nominal.
    @MainActor func testCompletionAnchorCarriesNoNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rule = CustomRecurrence(anchor: .completionDate, interval: 2, unit: .months,
                                    includesLastDayOfMonth: true, skipWeekends: true)
        // Completed Apr 2: the cadence date is measured from completion, so
        // the next last-day is Apr 30 (Thursday, no roll).
        let next = try XCTUnwrap(rule.nextOccurrence(after: date(2026, 3, 31),
                                                     completedAt: date(2026, 4, 2),
                                                     calendar: calendar, occurrenceIndex: 1))
        XCTAssertEqual(next, date(2026, 4, 30))
        let id = store.createTask(title: "Completion anchored", dueDate: date(2026, 3, 31, 0))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = rule
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertNil(successor.recurrenceNominalDate)
    }

    // MARK: - Store: successors, persistence, lifecycle

    /// Full completion chain through the store: Mar 31 -> Jun 1 (nominal
    /// May 31 recorded) -> Jul 31.
    @MainActor func testSuccessorChainPreservesNominalCadence() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Bimonthly", dueDate: date(2026, 3, 31, 0))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = lastDayRule()
        task.recurrenceNominalDate = date(2026, 3, 31, 0)
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let first = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(first.dueDate, date(2026, 6, 1, 0))
        XCTAssertEqual(first.recurrenceNominalDate, date(2026, 5, 31, 0))
        XCTAssertEqual(first.occurrenceIndex, 2)
        store.toggleComplete(id: first.id)
        let second = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == first.id })
        XCTAssertEqual(second.dueDate, date(2026, 7, 31, 0))
        XCTAssertEqual(second.recurrenceNominalDate, date(2026, 7, 31, 0))
        XCTAssertEqual(second.occurrenceIndex, 3)
    }

    /// The nominal survives a save/reload round trip, so the SECOND
    /// completion after a restart still aligns.
    @MainActor func testNominalSurvivesSaveReload() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Bimonthly", dueDate: date(2026, 3, 31, 0))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = lastDayRule()
        task.recurrenceNominalDate = date(2026, 3, 31, 0)
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let firstID = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id }).id
        // Reload from disk like an app restart.
        let reloaded = TaskStore(fileURL: dir.appendingPathComponent("workspace.json"), seed: false)
        let reloadedFirst = try XCTUnwrap(reloaded.data.tasks.first { $0.id == firstID })
        XCTAssertEqual(reloadedFirst.recurrenceNominalDate, date(2026, 5, 31, 0))
        reloaded.toggleComplete(id: firstID)
        let second = try XCTUnwrap(reloaded.data.tasks.first { $0.recurrenceSourceID == firstID })
        XCTAssertEqual(second.dueDate, date(2026, 7, 31, 0))
    }

    /// Legacy records without a nominal fall back to the due date (the one
    /// ambiguous transition this model cannot reconstruct).
    @MainActor func testLegacyRecordFallsBackToDueDate() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Legacy", dueDate: date(2026, 6, 1, 0))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = lastDayRule()
        XCTAssertNil(task.recurrenceNominalDate)
        store.updateTask(task, applyDefaultReminders: false)
        // June 1 has no recorded nominal, so the next step is computed from
        // the displayed due date (documents the legacy ambiguity).
        let next = TaskStore.nextRecurrenceDate(for: try fetch(store, id), calendar: calendar)
        XCTAssertEqual(next?.0, date(2026, 6, 30, 0))
    }

    /// Duplicating a mid-series task restarts the series at the copy's due
    /// date with a matching nominal.
    @MainActor func testDuplicateRestartsSeriesWithMatchingNominal() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Bimonthly", dueDate: date(2026, 3, 31, 0))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = lastDayRule()
        task.recurrenceNominalDate = date(2026, 3, 31, 0)
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let first = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        let copyID = try XCTUnwrap(store.duplicateTask(id: first.id))
        let copy = try fetch(store, copyID)
        XCTAssertEqual(copy.occurrenceIndex, 1)
        XCTAssertEqual(copy.recurrenceNominalDate, copy.dueDate)
        XCTAssertEqual(copy.dueDate, date(2026, 6, 1, 0))
    }

    /// A changed rule restarts the series: index back to 1, nominal back to
    /// the current due date. An unchanged rule leaves both alone.
    @MainActor func testRuleChangeRestartsNominal() throws {
        var task = TaskItem(title: "T", dueDate: date(2026, 6, 1, 0))
        task.customRecurrence = lastDayRule()
        task.occurrenceIndex = 3
        task.recurrenceNominalDate = date(2026, 5, 31, 0)
        task.restartCustomSeries(ruleChangedFrom: CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months))
        XCTAssertEqual(task.occurrenceIndex, 1)
        XCTAssertEqual(task.recurrenceNominalDate, date(2026, 6, 1, 0))
        // Unchanged rule: no-op.
        var same = task
        same.restartCustomSeries(ruleChangedFrom: lastDayRule())
        XCTAssertEqual(same.occurrenceIndex, 1)
        XCTAssertEqual(same.recurrenceNominalDate, date(2026, 6, 1, 0))
        // Clearing the rule drops the nominal.
        var cleared = task
        cleared.customRecurrence = nil
        cleared.restartCustomSeries(ruleChangedFrom: lastDayRule())
        XCTAssertEqual(cleared.occurrenceIndex, 1)
        XCTAssertNil(cleared.recurrenceNominalDate)
    }

    /// End-by-count still terminates the rolled series at the right index.
    @MainActor func testMaxOccurrencesEndsRolledSeries() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var rule = lastDayRule()
        rule.maxOccurrences = 3
        let id = store.createTask(title: "Counted", dueDate: date(2026, 3, 31, 0))
        var task = try fetch(store, id)
        task.hasDueTime = false
        task.timeZoneID = "UTC"
        task.customRecurrence = rule
        task.recurrenceNominalDate = date(2026, 3, 31, 0)
        store.updateTask(task, applyDefaultReminders: false)
        store.toggleComplete(id: id)
        let first = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(first.dueDate, date(2026, 6, 1, 0))
        store.toggleComplete(id: first.id)
        let second = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == first.id })
        XCTAssertEqual(second.dueDate, date(2026, 7, 31, 0))
        // Index 3 of 3: the series ends here.
        XCTAssertNil(TaskStore.nextRecurrenceDate(for: second, calendar: calendar))
    }
}
