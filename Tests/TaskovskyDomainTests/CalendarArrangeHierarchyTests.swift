import XCTest
import TaskovskyDomain

/// Bounded Arrange hierarchy: List grouping nests the eligible candidates of
/// each group; Tag/Priority stay flat; toggling never mutates the workspace.
final class CalendarArrangeHierarchyTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))! }

    private struct Fixture {
        let work = TaskList(name: "Work", color: "#123456")
        let home = TaskList(name: "Home", color: "#654321")
        let area = TaskTag(name: "Area", color: "#ABCDEF")
        var parent = TaskItem(title: "Neutral parent")
        var childOne = TaskItem(title: "Neutral child one")
        var childTwo = TaskItem(title: "Neutral child two")
        var excludedParent = TaskItem(title: "Neutral excluded parent")
        var orphan = TaskItem(title: "Neutral orphan child")
        var homeTask = TaskItem(title: "Neutral home task")
        var homeChild = TaskItem(title: "Neutral cross-group child")
        var note = TaskItem(title: "Neutral note")

        init(now: Date) {
            parent.listID = work.id
            childOne.listID = work.id; childOne.parentID = parent.id
            childTwo.listID = work.id; childTwo.parentID = parent.id
            childTwo.priority = .high; childTwo.tagIDs = [area.id]
            excludedParent.listID = work.id
            excludedParent.dueDate = now.addingTimeInterval(7 * 86_400)
            orphan.listID = work.id; orphan.parentID = excludedParent.id
            homeTask.listID = home.id
            homeChild.listID = home.id; homeChild.parentID = parent.id
            note.listID = work.id; note.kind = .note
        }

        var data: WorkspaceData {
            .init(tasks: [parent, childOne, childTwo, excludedParent, orphan, homeTask, homeChild, note],
                  lists: [work, home], tags: [area])
        }
    }

    private func candidates(_ fixture: Fixture, overdue: Bool = false, showNotes: Bool = true) -> [TaskItem] {
        TaskCalendarProjection.arrangementTasks(data: fixture.data, options: .init(), overdue: overdue,
                                                now: now, calendar: calendar, showNotes: showNotes)
    }

    private func workSlice(_ tasks: [TaskItem], _ fixture: Fixture) -> [TaskItem] {
        let groups = Dictionary(grouping: tasks) { $0.listID == fixture.work.id }
        return groups[true] ?? []
    }

    func testListGroupingNestsEligibleChildrenDirectlyBeneathParent() {
        let fixture = Fixture(now: now)
        let tasks = candidates(fixture)
        XCTAssertEqual(tasks.map(\.title),
                       ["Neutral parent", "Neutral child one", "Neutral child two",
                        "Neutral orphan child", "Neutral home task",
                        "Neutral cross-group child", "Neutral note"])
        let slice = workSlice(tasks, fixture)
        let rows = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                          showHierarchy: true, collapsed: [])
        XCTAssertEqual(rows.map(\.task.title),
                       ["Neutral parent", "Neutral child one", "Neutral child two",
                        "Neutral orphan child", "Neutral note"])
        XCTAssertEqual(rows.map(\.depth), [0, 1, 1, 0, 0])
        XCTAssertEqual(rows.map(\.hasChildren), [true, false, false, false, false])
        // The scheduled parent never enters the slice, so its child stays a root.
        XCTAssertEqual(rows.first { $0.task.title == "Neutral orphan child" }?.depth, 0)
    }

    func testCrossGroupParentRendersChildAsRoot() {
        let fixture = Fixture(now: now)
        let homeIDs = Set(candidates(fixture).filter { $0.listID == fixture.home.id }.map(\.id))
        XCTAssertTrue(homeIDs.contains(fixture.homeChild.id))
        let homeSlice = candidates(fixture).filter { $0.listID == fixture.home.id }
        let rows = TaskCalendarProjection.arrangementRows(for: homeSlice, grouping: .list,
                                                          showHierarchy: true, collapsed: [])
        // The parent lives in another group, so the child cannot nest under it.
        XCTAssertEqual(rows.map(\.task.title), ["Neutral home task", "Neutral cross-group child"])
        XCTAssertEqual(rows.map(\.depth), [0, 0])
        XCTAssertFalse(rows.contains { $0.hasChildren })
    }

    func testCollapseHidesDescendantsAndKeepsGroupCount() {
        let fixture = Fixture(now: now)
        let slice = workSlice(candidates(fixture), fixture)
        let collapsed: Set<UUID> = [fixture.parent.id]
        let rows = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                          showHierarchy: true, collapsed: collapsed)
        XCTAssertEqual(rows.map(\.task.title), ["Neutral parent", "Neutral orphan child", "Neutral note"])
        XCTAssertEqual(rows.first?.hasChildren, true)
        XCTAssertEqual(slice.count, 5)
    }

    func testHierarchyOffKeepsExactFlatOrderAndOnExpandsAgain() {
        let fixture = Fixture(now: now)
        let slice = workSlice(candidates(fixture), fixture)
        let off = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                         showHierarchy: false, collapsed: [])
        XCTAssertEqual(off.map(\.task.id), slice.map(\.id))
        XCTAssertTrue(off.allSatisfy { $0.depth == 0 && !$0.hasChildren })
        let on = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                        showHierarchy: true, collapsed: [])
        XCTAssertEqual(on.map(\.task.title),
                       ["Neutral parent", "Neutral child one", "Neutral child two",
                        "Neutral orphan child", "Neutral note"])
        XCTAssertEqual(Set(on.map(\.task.id)), Set(off.map(\.task.id)))
    }

    func testTagAndPriorityGroupingsStayFlat() {
        let fixture = Fixture(now: now)
        let tasks = candidates(fixture)
        for grouping in [CalendarColorMode.tag, CalendarColorMode.priority] as [CalendarColorMode] {
            let groups = TaskCalendarProjection.arrangementGroups(tasks, data: fixture.data, grouping: grouping)
            for group in groups {
                let rows = TaskCalendarProjection.arrangementRows(for: group.tasks, grouping: grouping,
                                                                  showHierarchy: true, collapsed: [])
                XCTAssertEqual(rows.map(\.task.id), group.tasks.map(\.id),
                               "Tag/Priority grouping must keep the exact flat order")
                XCTAssertTrue(rows.allSatisfy { $0.depth == 0 && !$0.hasChildren })
            }
        }
        // The tagged child is the documented flat Priority sample: it nests in
        // List grouping but renders flat under Priority.
        let priorityGroups = TaskCalendarProjection.arrangementGroups(tasks, data: fixture.data, grouping: .priority)
        let high = priorityGroups.first { $0.name == "High" }?.tasks ?? []
        XCTAssertEqual(high.map(\.title), ["Neutral child two"])
    }

    func testExcludedChildrenNeverNestAndAppearWhenEligible() {
        var fixture = Fixture(now: now)
        fixture.childOne.dueDate = now.addingTimeInterval(-86_400)
        // Without overdue, the dated child is not a candidate: nothing
        // excluded is pulled in, and only the eligible child nests.
        var tasks = candidates(fixture)
        XCTAssertFalse(tasks.contains { $0.id == fixture.childOne.id })
        var slice = workSlice(tasks, fixture)
        var rows = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                           showHierarchy: true, collapsed: [])
        XCTAssertFalse(rows.contains { $0.task.id == fixture.childOne.id })
        let nested = rows.filter { $0.depth == 1 }.map(\.task.id)
        XCTAssertEqual(nested, [fixture.childTwo.id])
        // With overdue on, the same child nests under its parent.
        tasks = candidates(fixture, overdue: true)
        XCTAssertTrue(tasks.contains { $0.id == fixture.childOne.id })
        slice = workSlice(tasks, fixture)
        rows = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                      showHierarchy: true, collapsed: [])
        let parentIndex = rows.firstIndex { $0.task.id == fixture.parent.id }!
        XCTAssertTrue(rows[parentIndex].hasChildren)
        XCTAssertEqual(rows[parentIndex + 1].task.id, fixture.childOne.id)
        XCTAssertEqual(rows[parentIndex + 1].depth, 1)
    }

    func testNotesFilterComposesWithHierarchy() {
        let fixture = Fixture(now: now)
        let withoutNotes = candidates(fixture, showNotes: false)
        XCTAssertFalse(withoutNotes.contains { $0.id == fixture.note.id })
        let rows = TaskCalendarProjection.arrangementRows(for: workSlice(withoutNotes, fixture),
                                                          grouping: .list, showHierarchy: true, collapsed: [])
        XCTAssertEqual(rows.map(\.task.title),
                       ["Neutral parent", "Neutral child one", "Neutral child two", "Neutral orphan child"])
    }

    func testCyclesSelfParentsAndDuplicatesKeepEveryEligibleRowWithStableIDs() {
        let work = TaskList(name: "Work", color: "#123456")
        var first = TaskItem(title: "Cycle A", listID: work.id)
        var second = TaskItem(title: "Cycle B", listID: work.id)
        first.parentID = second.id; second.parentID = first.id
        var lone = TaskItem(title: "Self parent", listID: work.id)
        lone.parentID = lone.id
        var duplicate = second
        duplicate.title = "Cycle B duplicate"
        let tasks = [first, second, lone, duplicate]
        let rows = TaskCalendarProjection.arrangementRows(for: tasks, grouping: .list,
                                                         showHierarchy: true, collapsed: [])
        let ids = rows.map(\.task.id)
        XCTAssertEqual(Set(ids), Set([first.id, second.id, lone.id]))
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(rows.first { $0.task.id == lone.id }?.depth, 0)
    }

    func testDuplicateIdentifiersRenderOnceInEveryBranch() {
        let work = TaskList(name: "Work", color: "#123456")
        var parent = TaskItem(title: "Dup parent", listID: work.id)
        var child = TaskItem(title: "Dup child", listID: work.id)
        child.parentID = parent.id
        var ghost = child
        ghost.title = "Dup child duplicate record"
        let tasks = [parent, child, ghost]
        for grouping in [CalendarColorMode.list, .tag, .priority] as [CalendarColorMode] {
            for show in [true, false] {
                let rows = TaskCalendarProjection.arrangementRows(for: tasks, grouping: grouping,
                                                                  showHierarchy: show, collapsed: [])
                XCTAssertEqual(rows.map(\.task.id), [parent.id, child.id],
                               "grouping=\(grouping) show=\(show)")
                XCTAssertEqual(rows.map(\.task.title)[1], "Dup child")
            }
        }
        let nested = TaskCalendarProjection.arrangementRows(for: tasks, grouping: .list,
                                                            showHierarchy: true, collapsed: [])
        XCTAssertEqual(nested.map(\.depth), [0, 1])
        XCTAssertEqual(nested.first?.hasChildren, true)
    }

    func testHierarchyProjectionDoesNotMutateCandidates() throws {
        let fixture = Fixture(now: now)
        let tasks = candidates(fixture)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(tasks)
        let slice = workSlice(tasks, fixture)
        _ = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                   showHierarchy: true, collapsed: [fixture.parent.id])
        _ = TaskCalendarProjection.arrangementRows(for: slice, grouping: .list,
                                                   showHierarchy: false, collapsed: [])
        XCTAssertEqual(try encoder.encode(tasks), before)
    }
}
