import XCTest
@testable import TaskovskyCore

/// Store-level integration for the custom-recurrence engine: successor
/// generation with `occurrenceIndex`, legacy supersession, end/count
/// enforcement, duplication, templates, legacy decoding, badges, and filters.
final class RecurrenceIntegrationTests: XCTestCase {
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

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @MainActor func testCustomRuleGeneratesSuccessorWithIncrementedIndex() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let calendar = gregorian()
        let due = date(calendar, 2026, 11, 9)
        let id = store.createTask(title: "Custom daily", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days)
        store.updateTask(task)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        XCTAssertEqual(successor.dueDate, date(calendar, 2026, 11, 10))
        XCTAssertEqual(successor.occurrenceIndex, 2)
        XCTAssertEqual(successor.customRecurrence?.unit, .days)
        XCTAssertNil(successor.completedAt)
    }

    @MainActor func testCustomRuleSupersedesLegacyEnum() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let calendar = gregorian()
        let due = date(calendar, 2026, 11, 9) // a Monday
        let id = store.createTask(title: "Both", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.recurrence = .weekly
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days)
        store.updateTask(task)
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        // Daily custom wins over weekly legacy.
        XCTAssertEqual(successor.dueDate, date(calendar, 2026, 11, 10))
    }

    @MainActor func testCustomMaxOccurrencesStopsSeries() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let calendar = gregorian()
        let id = store.createTask(title: "Counted", dueDate: date(calendar, 2026, 11, 9))
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days, maxOccurrences: 2)
        task.occurrenceIndex = 2
        store.updateTask(task)
        store.toggleComplete(id: id)
        XCTAssertNil(store.data.tasks.first { $0.recurrenceSourceID == id })
    }

    @MainActor func testCustomCompletionAnchorMeasuresFromCompletion() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let calendar = gregorian()
        let due = date(calendar, 2026, 11, 9)
        let id = store.createTask(title: "Anchored", dueDate: due)
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.customRecurrence = CustomRecurrence(anchor: .completionDate, interval: 2, unit: .days)
        store.updateTask(task)
        // Completed "now" (years after the stale due date): the next date
        // measures 2 days from completion while the wall time (09:00) still
        // comes from the scheduled due date, per engine policy.
        store.toggleComplete(id: id)
        let successor = try XCTUnwrap(store.data.tasks.first { $0.recurrenceSourceID == id })
        let completedAt = try XCTUnwrap(store.data.tasks.first { $0.id == id }?.completedAt)
        let successorDue = try XCTUnwrap(successor.dueDate)
        // The store engine runs in the local calendar: two local days after
        // completion, wall time carried over from the scheduled due date.
        let local = store.settings.calendar
        let dayGap = local.dateComponents([.day], from: local.startOfDay(for: completedAt), to: local.startOfDay(for: successorDue)).day
        XCTAssertEqual(dayGap, 2)
        XCTAssertEqual(local.component(.hour, from: successorDue), local.component(.hour, from: due))
        XCTAssertEqual(successor.occurrenceIndex, 2)
    }

    @MainActor func testDuplicateResetsSeriesButKeepsRule() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Series 3", dueDate: Date())
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [2])
        task.occurrenceIndex = 3
        task.wontDoAt = Date()
        store.updateTask(task)
        let copyID = try XCTUnwrap(store.duplicateTask(id: id))
        let copy = try XCTUnwrap(store.data.tasks.first { $0.id == copyID })
        XCTAssertEqual(copy.occurrenceIndex, 1)
        XCTAssertEqual(copy.customRecurrence?.weekdays, [2])
        XCTAssertNil(copy.wontDoAt)
        XCTAssertNil(copy.recurrenceSourceID)
    }

    @MainActor func testTemplateCarriesRuleAndChecklistState() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let id = store.createTask(title: "Pack", dueDate: Date())
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.checklist = [ChecklistItem(title: "Passport", isCompleted: true), ChecklistItem(title: "Charger")]
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months)
        store.updateTask(task)
        let templateID = try XCTUnwrap(store.saveTemplate(from: id))
        let template = try XCTUnwrap(store.data.templates.first { $0.id == templateID })
        XCTAssertEqual(template.customRecurrence?.unit, .months)
        let instanceID = try XCTUnwrap(store.createTaskFromTemplate(id: templateID))
        let instance = try XCTUnwrap(store.data.tasks.first { $0.id == instanceID })
        XCTAssertEqual(instance.customRecurrence?.unit, .months)
        XCTAssertEqual(instance.occurrenceIndex, 1)
        XCTAssertEqual(instance.checklist.map(\.isCompleted), [true, false])
        XCTAssertNotEqual(instance.checklist.map(\.id), task.checklist.map(\.id))
    }

    func testPartialCustomRecurrenceDecodesLeniently() throws {
        // Fixture-style partial rule (only the fields a hand-written file
        // needs) decodes with memberwise defaults instead of voiding the file.
        let json = #"{"anchor":"dueDate","interval":1,"unit":"weeks","weekdays":[2,4]}"#.data(using: .utf8)!
        let rule = try JSONDecoder().decode(CustomRecurrence.self, from: json)
        XCTAssertTrue(rule.isValid)
        XCTAssertEqual(rule.weekdays, [2, 4])
        XCTAssertFalse(rule.includesLastDayOfMonth)
        XCTAssertFalse(rule.skipWeekends)
        XCTAssertNil(rule.ordinalWeekday)
        // Hostile values still decode but report invalid (fail-closed).
        let bad = #"{"interval":0,"unit":"days"}"#.data(using: .utf8)!
        XCTAssertFalse(try JSONDecoder().decode(CustomRecurrence.self, from: bad).isValid)
        // Partial ordinals default the missing half.
        let ord = try JSONDecoder().decode(OrdinalWeekday.self, from: #"{"ordinal":-1}"#.data(using: .utf8)!)
        XCTAssertEqual(ord.weekday, 1)
        XCTAssertTrue(ord.isValid)
    }

    func testLegacyTaskDecodesWithoutCustomRecurrence() throws {
        let task = TaskItem(title: "Legacy", recurrence: .daily)
        let encoded = try JSONEncoder().encode(task)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "customRecurrence")
        object.removeValue(forKey: "occurrenceIndex")
        let decoded = try JSONDecoder().decode(TaskItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.customRecurrence)
        XCTAssertEqual(decoded.occurrenceIndex, 1)
        XCTAssertTrue(decoded.isRepeating)
        // Hostile indexes clamp to the series start instead of trapping.
        var hostile = object
        hostile["occurrenceIndex"] = -40
        let clamped = try JSONDecoder().decode(TaskItem.self, from: JSONSerialization.data(withJSONObject: hostile))
        XCTAssertEqual(clamped.occurrenceIndex, 1)
    }

    func testIsRepeatingAndRepeatLabel() {
        let calendar = gregorian()
        XCTAssertFalse(TaskItem(title: "Plain").isRepeating)
        XCTAssertEqual(TaskItem(title: "Plain").repeatLabel(), "Does not repeat")
        XCTAssertTrue(TaskItem(title: "Legacy", recurrence: .daily).isRepeating)
        XCTAssertEqual(TaskItem(title: "Legacy", recurrence: .weekly).repeatLabel(), "Weekly")
        var custom = TaskItem(title: "Custom")
        custom.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .weeks, weekdays: [2, 4])
        XCTAssertTrue(custom.isRepeating)
        XCTAssertEqual(custom.repeatLabel(calendar: calendar), "Every 2 weeks · Mon, Wed")
        var monthly = TaskItem(title: "Monthly")
        monthly.customRecurrence = CustomRecurrence(
            anchor: .dueDate, interval: 1, unit: .months,
            ordinalWeekday: OrdinalWeekday(ordinal: 3, weekday: 6))
        XCTAssertEqual(monthly.repeatLabel(calendar: calendar), "Monthly · 3rd Fri")
        var specific = TaskItem(title: "Specific")
        specific.customRecurrence = CustomRecurrence(
            anchor: .dueDate, interval: 1, unit: .days,
            specificDates: [date(calendar, 2026, 12, 1), date(calendar, 2026, 12, 25)])
        XCTAssertTrue(specific.isRepeating)
        XCTAssertEqual(specific.repeatLabel(calendar: calendar), "2 specific dates")
        var invalid = TaskItem(title: "Invalid")
        invalid.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 0, unit: .days)
        XCTAssertFalse(invalid.isRepeating)
        XCTAssertEqual(invalid.repeatLabel(), "Does not repeat")
    }

    func testRepeatingFilterMatchesCustomRules() {
        let filter = TaskFilter(name: "F")
        let repeating = FilterRule.condition(FilterCondition(kind: .repeating))
        var custom = TaskItem(title: "Custom")
        custom.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .days)
        XCTAssertTrue(TaskFilter.evaluate(repeating, task: custom, filter: filter, lists: [], now: Date(), calendar: gregorian()))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.repeating, task: custom, now: Date(), calendar: gregorian()))
        let plain = TaskItem(title: "Plain")
        XCTAssertFalse(TaskFilter.evaluate(repeating, task: plain, filter: filter, lists: [], now: Date(), calendar: gregorian()))
        XCTAssertTrue(TaskFilter.evaluate(repeating, task: TaskItem(title: "Legacy", recurrence: .daily), filter: filter, lists: [], now: Date(), calendar: gregorian()))
    }
}
