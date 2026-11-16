import XCTest
import TaskovskyDomain

final class BoardOrderingTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    func testEveryScalarSortIsRealStableAndReversible() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let a = TaskItem(title: "Alpha", dueDate: day, priority: .high, createdAt: day, updatedAt: day.addingTimeInterval(20))
        let b = TaskItem(title: "Zulu", dueDate: day.addingTimeInterval(86400), priority: .low, createdAt: day.addingTimeInterval(10), updatedAt: day)
        let tasks = [b,a], data = WorkspaceData(tasks: tasks)
        for kind in [TaskBoardSortKind.date, .createdTime, .title, .priority] {
            XCTAssertEqual(TaskBoardOrdering.ordered(tasks, kind: kind, ascending: true, in: data, calendar: calendar).map(\.id), [a.id,b.id])
            XCTAssertEqual(TaskBoardOrdering.ordered(tasks, kind: kind, ascending: false, in: data, calendar: calendar).map(\.id), [b.id,a.id])
        }
        XCTAssertEqual(TaskBoardOrdering.ordered(tasks, kind: .modifiedTime, ascending: true, in: data, calendar: calendar).map(\.id), [b.id,a.id])
        XCTAssertEqual(TaskBoardOrdering.ordered(tasks, kind: .modifiedTime, ascending: false, in: data, calendar: calendar).map(\.id), [a.id,b.id])
        XCTAssertEqual(TaskBoardOrdering.ordered(tasks, kind: nil, ascending: true, in: data, calendar: calendar).map(\.id), tasks.map(\.id))
        let tie = TaskItem(title: "ALPHA", dueDate: day, priority: .high, createdAt: day, updatedAt: day.addingTimeInterval(20))
        for kind in TaskBoardSortKind.allCases where kind != .tag {
            for ascending in [true,false] {
                XCTAssertEqual(TaskBoardOrdering.ordered([a,tie], kind: kind, ascending: ascending, in: data, calendar: calendar).map(\.id), [a.id,tie.id])
            }
        }
    }
    func testTagIsRealSectionsWithStableIDsAndNoDuplicates() {
        let z = TaskTag(name: "Zulu", color: "#111111"), a = TaskTag(name: "Alpha", color: "#222222"), duplicate = TaskTag(name: "Alpha", color: "#333333")
        let first = TaskItem(title: "One", tagIDs: [a.id,z.id]), second = TaskItem(title: "Two", tagIDs: [a.id]), third = TaskItem(title: "Three", tagIDs: [duplicate.id]), unknown = TaskItem(title: "Unknown", tagIDs: [UUID()])
        let tasks = [unknown,first,second,third], data = WorkspaceData(tasks: tasks, tags: [z,a,duplicate])
        let asc = TaskBoardOrdering.tagSections(tasks, in: data, ascending: true)
        let desc = TaskBoardOrdering.tagSections(tasks, in: data, ascending: false)
        XCTAssertEqual(asc.map(\.id), [.tag(a.id),.tag(duplicate.id),.tag(z.id),.untagged])
        XCTAssertEqual(desc.map(\.id), [.tag(z.id),.tag(a.id),.tag(duplicate.id),.untagged])
        XCTAssertEqual(asc.flatMap(\.tasks).count,tasks.count)
        XCTAssertEqual(Set(asc.flatMap(\.tasks).map(\.id)),Set(tasks.map(\.id)))
        XCTAssertEqual(desc.first?.tasks.map(\.id),[first.id])
        XCTAssertEqual(TaskBoardOrdering.ordered(tasks, kind: .tag, ascending: false, in: data, calendar: calendar).map(\.id),tasks.map(\.id))
    }
    func testMissingDateStaysLastEitherDirection() {
        let dated = TaskItem(title: "Dated", dueDate: Date()), missing = TaskItem(title: "Missing")
        let data = WorkspaceData(tasks:[missing,dated])
        for asc in [true,false] {
            XCTAssertEqual(TaskBoardOrdering.ordered(data.tasks, kind:.date, ascending:asc, in:data, calendar:calendar).map(\.id),[dated.id,missing.id])
        }
    }
}
