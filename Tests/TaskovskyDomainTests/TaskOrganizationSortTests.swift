import XCTest
import TaskovskyDomain

final class TaskOrganizationSortTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }

    func testMetadataSortAndOrganizationGroupsComposeWithoutLossOrMutation() {
        let list = TaskList(name: "Work", color: "#000000")
        let tag = TaskTag(name: "Tag", color: "#000000")
        var a = TaskItem(title: "A", listID: list.id, dueDate: Date(timeIntervalSince1970: 100)); a.tagIDs = [tag.id]
        let b = TaskItem(title: "B", parentID: a.id)
        let c = TaskItem(title: "C", listID: list.id, dueDate: Date(timeIntervalSince1970: 200))
        let tasks = [c, b, a], data = WorkspaceData(tasks: tasks, lists: [list], tags: [tag])
        let before = data
        for sort in TaskMetadataSort.allCases {
            let sorted = tasks.sorted { sort.precedes($0, $1, in: data, calendar: calendar) }
            let projections = [TaskOrganizationGroup.byList(sorted, in: data), TaskOrganizationGroup.byTag(sorted, in: data), TaskOrganizationGroup.ungrouped(sorted)]
            for groups in projections {
                XCTAssertEqual(groups.flatMap(\.tasks).count, tasks.count)
                XCTAssertEqual(Set(groups.flatMap(\.tasks).map(\.id)), Set(tasks.map(\.id)))
                for group in groups {
                    XCTAssertEqual(group.tasks, sorted.filter { item in group.tasks.contains { $0.id == item.id } })
                }
            }
        }
        XCTAssertEqual(data, before)
    }

    func testListGroupingIsDistinctFromNoneAndRetainsEveryRow() {
        let first = TaskList(name: "First", color: "#000000")
        let second = TaskList(name: "Second", color: "#000000", isArchived: true)
        let missing = UUID()
        let tasks = [TaskItem(title: "Second", listID: second.id), TaskItem(title: "Inbox"),
                     TaskItem(title: "Unknown", listID: missing), TaskItem(title: "First", listID: first.id),
                     TaskItem(title: "First again", listID: first.id)]
        let data = WorkspaceData(tasks: tasks, lists: [first, second, first])
        let before = data
        let groups = TaskOrganizationGroup.byList(tasks, in: data)
        XCTAssertEqual(groups.map(\.id), [.inbox, .list(first.id), .list(second.id), .missingList(missing)])
        XCTAssertEqual(groups.map(\.title), ["Inbox", "First", "Second", "Unavailable List"])
        XCTAssertEqual(groups[1].tasks.map(\.id), [tasks[3].id, tasks[4].id])
        XCTAssertEqual(Set(groups.flatMap(\.tasks).map(\.id)), Set(tasks.map(\.id)))
        XCTAssertEqual(groups.flatMap(\.tasks).count, tasks.count)
        XCTAssertEqual(TaskOrganizationGroup.ungrouped(tasks).first?.tasks, tasks)
        XCTAssertTrue(TaskOrganizationGroup.ungrouped([]).isEmpty)
        XCTAssertEqual(data, before) // No archive filtering, task edits or metadata rewriting.
    }

    func testTagOwnershipUsesWorkspaceOrderNotTaskOrderAndNoDuplication() {
        let first = TaskTag(name: "Tag 10", color: "#000000")
        let second = TaskTag(name: "Tag 2", color: "#000000", parentID: first.id)
        let unknown = UUID()
        var multi = TaskItem(title: "Multi"); multi.tagIDs = [second.id, unknown, first.id, first.id]
        var nested = TaskItem(title: "Nested", parentID: multi.id); nested.tagIDs = [second.id]
        var orphan = TaskItem(title: "Unknown"); orphan.tagIDs = [unknown]
        let none = TaskItem(title: "None")
        let tasks = [none, multi, orphan, nested]
        let data = WorkspaceData(tasks: tasks, tags: [first, second, first])
        let groups = TaskOrganizationGroup.byTag(tasks, in: data)
        XCTAssertEqual(groups.map(\.id), [.tag(first.id), .tag(second.id), .untagged])
        XCTAssertEqual(groups.flatMap(\.tasks).map(\.id), [multi.id, nested.id, none.id, orphan.id])
        XCTAssertEqual(groups.last?.title, "No Tags")
        XCTAssertEqual(TaskOrganizationGroup.primaryTag(for: multi, in: data)?.id, first.id)
        XCTAssertEqual(multi.tagIDs, [second.id, unknown, first.id, first.id])
        XCTAssertTrue(TaskOrganizationGroup.byTag([], in: data).isEmpty)
        XCTAssertEqual(TaskOrganizationGroup.byTag(tasks, in: WorkspaceData()).first?.tasks, tasks)
    }

    func testTagSortingNumericFoldedTiesAndMissingAlwaysLast() {
        let ten = TaskTag(name: "Tag 10", color: "#000000")
        let two = TaskTag(name: "tag 2", color: "#000000")
        let equal = TaskTag(name: "TÁG 2", color: "#000000")
        var a = TaskItem(title: "A"); a.tagIDs = [ten.id]
        var b = TaskItem(title: "B"); b.tagIDs = [two.id]
        var c = TaskItem(title: "C"); c.tagIDs = [equal.id]
        let d = TaskItem(title: "Missing")
        let tasks = [d, a, c, b], data = WorkspaceData(tags: [ten, two, equal])
        func sorted(_ sort: TaskMetadataSort) -> [UUID] { tasks.sorted { sort.precedes($0, $1, in: data, calendar: calendar) }.map(\.id) }
        XCTAssertEqual(sorted(.tagAscending), [c.id, b.id, a.id, d.id])
        XCTAssertEqual(sorted(.tagDescending), [a.id, c.id, b.id, d.id])
        XCTAssertFalse(TaskMetadataSort.tagAscending.precedes(b, c, in: data, calendar: calendar))
        XCTAssertFalse(TaskMetadataSort.tagDescending.precedes(c, b, in: data, calendar: calendar))
    }

    func testAllDayDateSortingProjectsCivilDateInsteadOfAbsoluteInstant() {
        let format = ISO8601DateFormatter()
        let allDay = TaskItem(title: "Tokyo day", dueDate: format.date(from: "2026-11-08T15:00:00Z")!, timeZoneID: "Asia/Tokyo")
        let timed = TaskItem(title: "Previous UTC evening", dueDate: format.date(from: "2026-11-08T20:00:00Z")!, hasDueTime: true)
        XCTAssertEqual(TaskDueDateGroup.displayDue(for: allDay, calendar: calendar), format.date(from: "2026-11-09T00:00:00Z")!)
        XCTAssertTrue(TaskMetadataSort.dateAscending.precedes(timed, allDay, in: WorkspaceData(), calendar: calendar))
        XCTAssertTrue(TaskMetadataSort.dateDescending.precedes(allDay, timed, in: WorkspaceData(), calendar: calendar))
    }

    func testDateSortingUsesDisplayDateAndRetainsNilAndEqualOrder() {
        let early = TaskItem(title: "Early", dueDate: Date(timeIntervalSince1970: 100), hasDueTime: true)
        let late = TaskItem(title: "Late", dueDate: Date(timeIntervalSince1970: 500), hasDueTime: true)
        let tie = TaskItem(title: "Tie", dueDate: early.dueDate, hasDueTime: true)
        let missing = TaskItem(title: "None")
        let invalid = TaskItem(title: "Invalid", dueDate: Date(timeIntervalSinceReferenceDate: .infinity), hasDueTime: true)
        let tasks = [missing, late, early, invalid, tie], data = WorkspaceData(tasks: tasks)
        func sorted(_ sort: TaskMetadataSort) -> [UUID] { tasks.sorted { sort.precedes($0, $1, in: data, calendar: calendar) }.map(\.id) }
        XCTAssertEqual(sorted(.dateAscending), [early.id, tie.id, late.id, missing.id, invalid.id])
        XCTAssertEqual(sorted(.dateDescending), [late.id, early.id, tie.id, missing.id, invalid.id])
        XCTAssertEqual(TaskMetadataSort(rawValue: "DateAscending"), .dateAscending)
        XCTAssertEqual(TaskMetadataSort(rawValue: "TagDescending"), .tagDescending)
    }
}
