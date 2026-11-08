import XCTest
@testable import TaskovskyCore

/// Filter hardening: nextMonth, positive list IDs, unset-condition defaults,
/// dangling-reference cleanup, rule-tree merge repointing, and dedupe.
final class FilterHardeningTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    private func gregorian() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testNextMonthMatchesCalendarMonth() {
        let calendar = gregorian()
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15))!
        let inNext = TaskItem(title: "N", dueDate: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let endNext = TaskItem(title: "E", dueDate: calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!)
        let inTwo = TaskItem(title: "T", dueDate: calendar.date(from: DateComponents(year: 2027, month: 1, day: 5))!)
        let thisMonth = TaskItem(title: "M", dueDate: calendar.date(from: DateComponents(year: 2026, month: 11, day: 30))!)
        XCTAssertTrue(TaskFilter.dateRuleMatches(.nextMonth, task: inNext, now: now, calendar: calendar))
        XCTAssertTrue(TaskFilter.dateRuleMatches(.nextMonth, task: endNext, now: now, calendar: calendar))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.nextMonth, task: inTwo, now: now, calendar: calendar))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.nextMonth, task: thisMonth, now: now, calendar: calendar))
        XCTAssertFalse(TaskFilter.dateRuleMatches(.nextMonth, task: TaskItem(title: "No date"), now: now, calendar: calendar))
        XCTAssertEqual(FilterDateRule.nextMonth.label, "Next month")
    }

    func testListConditionNeedsPositiveID() {
        let filter = TaskFilter(name: "F")
        let now = Date()
        let inbox = TaskItem(title: "Inbox")
        var listed = TaskItem(title: "Listed", listID: UUID())
        // Unconfigured ("Choose list") matches nothing — not even Inbox.
        let bare = FilterRule.condition(FilterCondition(kind: .list))
        XCTAssertFalse(TaskFilter.evaluate(bare, task: inbox, filter: filter, lists: [], now: now, calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(bare, task: listed, filter: filter, lists: [], now: now, calendar: .current))
        // Explicit Inbox selection still matches inbox tasks only.
        let inboxRule = FilterRule.condition(FilterCondition(kind: .list, listID: TaskFilter.inboxListID))
        XCTAssertTrue(TaskFilter.evaluate(inboxRule, task: inbox, filter: filter, lists: [], now: now, calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(inboxRule, task: listed, filter: filter, lists: [], now: now, calendar: .current))
        // Explicit list IDs match positively; dangling IDs match nothing.
        listed.listID = UUID()
        let listRule = FilterRule.condition(FilterCondition(kind: .list, listID: listed.listID))
        XCTAssertTrue(TaskFilter.evaluate(listRule, task: listed, filter: filter, lists: [], now: now, calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(listRule, task: inbox, filter: filter, lists: [], now: now, calendar: .current))
        let dangling = FilterRule.condition(FilterCondition(kind: .list, listID: UUID()))
        XCTAssertFalse(TaskFilter.evaluate(dangling, task: listed, filter: filter, lists: [], now: now, calendar: .current))
    }

    func testUnsetConditionsUseDisplayedDefaults() {
        let filter = TaskFilter(name: "F")
        let now = Date()
        let calendar = Calendar.current
        let todayTask = TaskItem(title: "T", dueDate: now)
        let plainTask = TaskItem(title: "P")
        // Date with no rule behaves like the picker's displayed Today.
        let dateBare = FilterRule.condition(FilterCondition(kind: .date))
        XCTAssertTrue(TaskFilter.evaluate(dateBare, task: todayTask, filter: filter, lists: [], now: now, calendar: calendar))
        XCTAssertFalse(TaskFilter.evaluate(dateBare, task: plainTask, filter: filter, lists: [], now: now, calendar: calendar))
        // Priority/kind default to the displayed none/task.
        let priBare = FilterRule.condition(FilterCondition(kind: .priority))
        XCTAssertTrue(TaskFilter.evaluate(priBare, task: plainTask, filter: filter, lists: [], now: now, calendar: calendar))
        let kindBare = FilterRule.condition(FilterCondition(kind: .kind))
        XCTAssertTrue(TaskFilter.evaluate(kindBare, task: plainTask, filter: filter, lists: [], now: now, calendar: calendar))
        XCTAssertFalse(TaskFilter.evaluate(kindBare, task: TaskItem(title: "N", kind: .note), filter: filter, lists: [], now: now, calendar: calendar))
        // Unconfigured tag still matches nothing.
        let tagBare = FilterRule.condition(FilterCondition(kind: .tag))
        XCTAssertFalse(TaskFilter.evaluate(tagBare, task: plainTask, filter: filter, lists: [], now: now, calendar: calendar))
    }

    @MainActor func testDeleteListPreservesCriteriaAsNoMatch() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "Gone", color: "#000000")
        let filterID = store.createFilter(TaskFilter(name: "F", listIDs: [list, TaskFilter.inboxListID],
            ruleRoot: .condition(FilterCondition(kind: .list, listID: list))))
        store.deleteList(id: list)
        let filter = try XCTUnwrap(store.data.filters.first { $0.id == filterID })
        // Criteria arrays keep the dead ID as no-match (pruning an
        // only-deleted selection would broaden the filter); the Inbox
        // selection survives alongside it.
        XCTAssertEqual(Set(filter.listIDs), [list, TaskFilter.inboxListID])
        // Rule trees are never rewritten: the dead condition stays (failing
        // closed) instead of silently broadening or narrowing.
        XCTAssertEqual(filter.ruleRoot, .condition(FilterCondition(kind: .list, listID: list)))
    }

    @MainActor func testMergeRepointsRuleTreeTagsWithDedupe() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = store.createTag(name: "Old", color: "#000000")
        let target = store.createTag(name: "New", color: "#111111")
        let root: FilterRule = .or([
            .condition(FilterCondition(kind: .tag, tagID: source)),
            .condition(FilterCondition(kind: .tag, tagID: target)),
            .condition(FilterCondition(kind: .keyword, keyword: "keep")),
        ])
        let filterID = store.createFilter(TaskFilter(name: "F", ruleRoot: root))
        XCTAssertTrue(store.mergeTags(source: source, target: target))
        let filter = try XCTUnwrap(store.data.filters.first { $0.id == filterID })
        // Both tag conditions pointed at the target, then deduped to one.
        XCTAssertEqual(filter.ruleRoot, .or([
            .condition(FilterCondition(kind: .tag, tagID: target)),
            .condition(FilterCondition(kind: .keyword, keyword: "keep")),
        ]))
    }

    func testDeadIDsArePreservedNoMatch() {
        // A dead list ID can never equal a live task's list (deletion
        // repoints those tasks to Inbox first), so keeping it matches
        // nothing — while pruning it would broaden a filter whose only
        // selection was deleted from "nothing" to "everything".
        let dead = UUID()
        let live = UUID()
        let other = UUID()
        let filter = TaskFilter(name: "F", listIDs: [live, dead])
        for listID: UUID? in [live, other, nil] {
            let task = TaskItem(title: "T", listID: listID)
            XCTAssertEqual(filter.matches(task, lists: []), listID == live,
                           "dead ID must not match \(String(describing: listID))")
        }
        // An only-dead selection matches nothing in any post-deletion state
        // (deletion repoints tasks to Inbox first, so no task carries it).
        let onlyDead = TaskFilter(name: "D", listIDs: [dead])
        for listID: UUID? in [live, other, nil] {
            XCTAssertFalse(onlyDead.matches(TaskItem(title: "T", listID: listID), lists: []))
        }
    }
}
