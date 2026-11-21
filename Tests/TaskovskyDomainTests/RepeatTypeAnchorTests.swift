import XCTest
@testable import TaskovskyDomain

final class RepeatTypeAnchorTests: XCTestCase {
    func testSavedAnchorChoicesKeepDistinctCompletionSemantics() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        func day(_ number: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: number))! }
        let task = TaskItem(title: "Neutral", dueDate: day(1))
        func saved(_ anchor: RecurrenceAnchor) throws -> TaskItem {
            var draft = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: calendar, now: day(1))
            draft.selectCustomRepeat(CustomRecurrence(anchor: anchor, interval: 2, unit: .days))
            return try draft.applying(to: task, settings: AppSettings())
        }
        let due = try XCTUnwrap(saved(.dueDate).customRecurrence)
        let completion = try XCTUnwrap(saved(.completionDate).customRecurrence)
        XCTAssertEqual(due.nextOccurrence(after: day(1), completedAt: day(5), calendar: calendar), day(3))
        XCTAssertEqual(completion.nextOccurrence(after: day(1), completedAt: day(5), calendar: calendar), day(7))
    }
}
