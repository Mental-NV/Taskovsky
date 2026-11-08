import XCTest
@testable import TaskovskyCore

/// Saved-filter intent: group conversions never broaden, NOT never grants
/// archive overrides, dead entity IDs persist as no-match, and editor
/// transforms are pure and UI-tested.
final class FilterIntentTests: XCTestCase {
    @MainActor private func makeStore() -> (TaskStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("workspace.json")
        return (TaskStore(fileURL: url, seed: false), dir)
    }

    private func keyword(_ value: String) -> FilterRule {
        .condition(FilterCondition(kind: .keyword, keyword: value))
    }

    // MARK: - Pure group conversions (used by the editor menu)

    func testAndOrConversionPreservesChildrenWithoutBroadening() {
        let t1 = keyword("alpha")
        let t2 = keyword("beta")
        // Group-to-group keeps exactly the children — no inserted
        // always-true condition that would make an OR match everything.
        XCTAssertEqual(FilterRuleEdit.convertToOr(.and([t1, t2])), .or([t1, t2]))
        XCTAssertEqual(FilterRuleEdit.convertToAnd(.or([t1, t2])), .and([t1, t2]))
        XCTAssertEqual(FilterRuleEdit.convertToAnd(.and([t1])), .and([t1]))
        // Wrapping a leaf preserves the leaf itself.
        XCTAssertEqual(FilterRuleEdit.convertToOr(t1), .or([t1]))
        XCTAssertEqual(FilterRuleEdit.convertToAnd(t1), .and([t1]))
        // The converted tree matches exactly the original's conditions: an
        // inserted empty-keyword condition would match the unrelated task.
        let filter = TaskFilter(name: "F")
        let converted = FilterRuleEdit.convertToOr(.and([t1, t2]))
        XCTAssertEqual(converted, .or([t1, t2]))
        XCTAssertTrue(TaskFilter.evaluate(converted, task: TaskItem(title: "alpha and beta"), filter: filter, lists: [], now: Date(), calendar: .current))
        XCTAssertFalse(TaskFilter.evaluate(converted, task: TaskItem(title: "unrelated"), filter: filter, lists: [], now: Date(), calendar: .current))
    }

    func testSingleConditionCollapseRefusesToDropConstraints() {
        let t1 = keyword("alpha")
        let t2 = keyword("beta")
        // Exactly one child unwraps (identical semantics); multi-child
        // groups and NOTs return unchanged instead of losing conditions.
        XCTAssertEqual(FilterRuleEdit.convertToCondition(.and([t1])), t1)
        XCTAssertEqual(FilterRuleEdit.convertToCondition(.or([t1])), t1)
        XCTAssertEqual(FilterRuleEdit.convertToCondition(t1), t1)
        let multi = FilterRule.or([t1, t2])
        XCTAssertEqual(FilterRuleEdit.convertToCondition(multi), multi)
        let not = FilterRule.not(t1)
        XCTAssertEqual(FilterRuleEdit.convertToCondition(not), not)
    }

    func testNotWrapperRespectsDepthCap() {
        let leaf = keyword("alpha")
        XCTAssertEqual(FilterRuleEdit.convertToNot(leaf, depth: 2), .not(leaf))
        // At the cap the rule returns unchanged: no unbounded NOT nesting.
        XCTAssertEqual(FilterRuleEdit.convertToNot(leaf, depth: FilterRuleEdit.maxDepth), leaf)
        XCTAssertEqual(FilterRuleEdit.convertToNot(leaf, depth: 99), leaf)
    }

    // MARK: - NOT polarity for archive/exclusion overrides

    func testNegatedListIDsNeverGrantArchiveOverride() {
        let archived = TaskList(name: "Old", color: "#000000", isArchived: true)
        var task = TaskItem(title: "T", listID: archived.id)
        let filter = TaskFilter(name: "F", ruleRoot: .not(.condition(FilterCondition(kind: .list, listID: archived.id))))
        // NOT(list A) names A only negatively: the archived task stays hidden.
        XCTAssertTrue(filter.ruleListIDs.isEmpty)
        XCTAssertFalse(filter.matches(task, lists: [archived]))
        // A positive reference through an unrelated OR branch still overrides.
        let positive = TaskFilter(name: "P", ruleRoot: .or([
            .not(.condition(FilterCondition(kind: .keyword, keyword: "zzz"))),
            .condition(FilterCondition(kind: .list, listID: archived.id)),
        ]))
        XCTAssertEqual(positive.ruleListIDs, [archived.id])
        task.title = "zzz"
        XCTAssertTrue(positive.matches(task, lists: [archived]))
        // Double negation is positive again.
        let double = TaskFilter(name: "D", ruleRoot: .not(.not(.condition(FilterCondition(kind: .list, listID: archived.id)))))
        XCTAssertEqual(double.ruleListIDs, [archived.id])
    }

    // MARK: - Dead IDs persist as no-match

    @MainActor func testDeleteListPreservesDeadIDsAsNoMatch() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let list = store.createList(name: "Gone", color: "#000000")
        let filterID = store.createFilter(TaskFilter(name: "F", listIDs: [list]))
        store.deleteList(id: list)
        let filter = try XCTUnwrap(store.data.filters.first { $0.id == filterID })
        // Preserved (not pruned): renaming/editing must not broaden.
        XCTAssertEqual(filter.listIDs, [list])
        let inboxTask = TaskItem(title: "T")
        XCTAssertFalse(filter.matches(inboxTask, lists: store.data.lists))
        // Re-saving the same selections keeps the no-match state.
        var renamed = filter
        renamed.name = "Renamed"
        store.updateFilter(renamed)
        XCTAssertEqual(store.data.filters.first { $0.id == filterID }?.listIDs, [list])
        XCTAssertFalse(try XCTUnwrap(store.data.filters.first { $0.id == filterID }).matches(inboxTask, lists: store.data.lists))
    }

    @MainActor func testDeleteTagPreservesDeadIDsAsNoMatch() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let tag = store.createTag(name: "Gone", color: "#000000")
        let filterID = store.createFilter(TaskFilter(name: "F", tagIDs: [tag]))
        store.deleteTag(id: tag)
        let filter = try XCTUnwrap(store.data.filters.first { $0.id == filterID })
        XCTAssertEqual(filter.tagIDs, [tag])
        XCTAssertFalse(filter.matches(TaskItem(title: "T"), lists: store.data.lists))
        // `.all` mode with a dead ID also matches nothing.
        var allMode = filter
        allMode.tagMode = .all
        XCTAssertFalse(allMode.matches(TaskItem(title: "T"), lists: store.data.lists))
    }
}
