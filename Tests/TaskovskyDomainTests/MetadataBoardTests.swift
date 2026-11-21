import XCTest
import TaskovskyDomain

final class MetadataBoardTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!; return c }
    private let now = Date(timeIntervalSince1970: 1_794_225_600)

    func testTagIdentityScopeUnknownAndMultiTagOnceWithoutMutation() throws {
        let a = TaskTag(name: "Same", color: "#112233"), b = TaskTag(name: "Same", color: "#445566")
        let archived = TaskList(name: "Archived", color: "#112233", isArchived: true)
        let first = TaskItem(title: "Multi", tagIDs: [b.id, a.id], isPinned: true)
        let second = TaskItem(title: "Second", tagIDs: [b.id])
        let unknown = TaskItem(title: "Unknown", tagIDs: [UUID()])
        let hidden = TaskItem(title: "Archived", listID: archived.id, tagIDs: [a.id])
        let data = WorkspaceData(tasks: [first, second, unknown, hidden], lists: [archived], tags: [a, b])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(data)
        let board = TaskMetadataBoardProjection(destination: .all, grouping: .tag, in: data, now: now, calendar: calendar)
        XCTAssertEqual(board.columns.map(\.id), [.tag(.tag(a.id)), .tag(.tag(b.id)), .tag(.untagged)])
        XCTAssertEqual(board.columns.flatMap(\.tasks).map(\.id), [first.id, second.id, unknown.id])
        XCTAssertTrue(board.columns[0].tasks[0].isPinned)
        let scoped = TaskMetadataBoardProjection(destination: .tag(b.id), grouping: .tag, in: data, now: now, calendar: calendar)
        XCTAssertEqual(scoped.columns.flatMap(\.tasks).map(\.id), [first.id, second.id])
        XCTAssertEqual(try encoder.encode(data), before)
        XCTAssertTrue(TaskMetadataBoardProjection(destination: .list(archived.id), grouping: .tag, in: data, now: now, calendar: calendar).columns.isEmpty)
    }

    func testCreationBucketsUseDisplayCivilDayAndStableIdentity() {
        let boundary = calendar.startOfDay(for: now)
        let a = TaskItem(title: "Before", createdAt: boundary.addingTimeInterval(-1))
        let b = TaskItem(title: "After", createdAt: boundary.addingTimeInterval(1))
        let c = TaskItem(title: "Later", createdAt: boundary.addingTimeInterval(200))
        let data = WorkspaceData(tasks: [a, b, c])
        let board = TaskMetadataBoardProjection(destination: .all, grouping: .createdTime, in: data, now: now, calendar: calendar)
        XCTAssertEqual(board.columns.count, 2)
        XCTAssertEqual(board.columns[0].id, .createdDay(boundary))
        XCTAssertEqual(board.columns[0].tasks.map(\.id), [b.id, c.id])
        XCTAssertEqual(board.columns[1].tasks.map(\.id), [a.id])
        XCTAssertTrue(TaskMetadataBoardProjection(destination: .all, grouping: .createdTime, in: WorkspaceData(), now: now, calendar: calendar).columns.isEmpty)
    }

    func testTitleSortStableTiesAndExistingOrderWithoutPinRepartition() {
        let z = TaskItem(title: "Zulu", isPinned: true), a = TaskItem(title: "alpha"), tie = TaskItem(title: "ÁLPHA")
        let tasks = [z, a, tie]
        XCTAssertEqual(TaskMetadataBoardProjection.ordered(tasks, title: nil).map(\.id), tasks.map(\.id))
        XCTAssertEqual(TaskMetadataBoardProjection.ordered(tasks, title: .ascending).map(\.id), [a.id, tie.id, z.id])
        XCTAssertEqual(TaskMetadataBoardProjection.ordered(tasks, title: .descending).map(\.id), [z.id, a.id, tie.id])
    }

    func testHistoryMembershipMatchesExistingBoardAndNoLaneDuplication() {
        let completed = TaskItem(title: "Done", completedAt: now)
        let failed = TaskItem(title: "Won't Do", wontDoAt: now)
        let active = TaskItem(title: "Active")
        let data = WorkspaceData(tasks: [completed, failed, active])
        let baseline = PriorityBoardProjection(destination: .all, in: data, now: now, calendar: calendar).columns.flatMap(\.tasks).map(\.id)
        for grouping in [TaskMetadataBoardProjection.Grouping.tag, .createdTime] {
            let actual = TaskMetadataBoardProjection(destination: .all, grouping: grouping, in: data, now: now, calendar: calendar).columns.flatMap(\.tasks).map(\.id)
            XCTAssertEqual(Set(actual), Set(baseline)); XCTAssertEqual(actual.count, baseline.count)
        }
    }
}
