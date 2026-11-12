import XCTest
@testable import TaskovskyCore

final class RecognitionClockRangeTests: XCTestCase {
    func testInvalidTrailingClockIsNotIncludedInRecognizedRemovalRange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10))!
        var settings = AppSettings(); settings.removeDateText = true
        for clock in ["25:00", "12:60", "13pm", "0am", "24:00", "9:5", "9:555", "9:30:15"] {
            let title = "Review tomorrow at " + clock
            let recognized = try XCTUnwrap(TaskCreation.recognizeDate(in: title, calendar: calendar, now: now))
            XCTAssertFalse(recognized.hasTime)
            XCTAssertEqual(String(title[recognized.range]), "tomorrow", clock)
            let result = TaskCreation.make(workspace: WorkspaceData(), settings: settings, title: title,
                                           now: now, calendar: calendar)
            XCTAssertEqual(result.task.title, "Review  at " + clock, clock)
            XCTAssertFalse(result.task.hasDueTime)
            var input = TaskCaptureInput.start(destination: .inbox, workspace: WorkspaceData(), settings: settings,
                                               now: now, calendar: calendar)
            input.title = title
            let mobile = try input.task(id: UUID(), now: now, workspace: WorkspaceData(), settings: settings, calendar: calendar)
            XCTAssertEqual(mobile.title, result.task.title)
            XCTAssertEqual(mobile.dueDate, result.task.dueDate)
            XCTAssertFalse(mobile.hasDueTime)
            var keep = settings; keep.removeDateText = false
            XCTAssertEqual(TaskCreation.make(workspace: WorkspaceData(), settings: keep, title: title,
                                              now: now, calendar: calendar).task.title, title)
        }
    }
    func testValidClockRangesAndPrecedingClockRemainPrecise() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10))!
        for (text, hour, minute) in [("tomorrow at 00:00", 0, 0), ("tomorrow at 23:59", 23, 59),
                                    ("tomorrow at 12am", 0, 0), ("tomorrow at 12pm", 12, 0),
                                    ("tomorrow at 4pm", 16, 0), ("at 9:30 tomorrow", 9, 30)] {
            let found = try XCTUnwrap(TaskCreation.recognizeDate(in: text, calendar: calendar, now: now))
            XCTAssertTrue(found.hasTime); XCTAssertEqual(String(text[found.range]), text)
            XCTAssertEqual(calendar.component(.hour, from: found.date), hour)
            XCTAssertEqual(calendar.component(.minute, from: found.date), minute)
            XCTAssertEqual(calendar.component(.day, from: found.date), 13)
        }
        let mixed = "Review at 9 tomorrow at 25:00"
        let found = try XCTUnwrap(TaskCreation.recognizeDate(in: mixed, calendar: calendar, now: now))
        XCTAssertTrue(found.hasTime); XCTAssertEqual(calendar.component(.hour, from: found.date), 9)
        XCTAssertEqual(String(mixed[found.range]), "at 9 tomorrow")
        let invalidPrefix = "Review at 25:00 tomorrow"
        let prefix = try XCTUnwrap(TaskCreation.recognizeDate(in: invalidPrefix, calendar: calendar, now: now))
        XCTAssertFalse(prefix.hasTime); XCTAssertEqual(String(invalidPrefix[prefix.range]), "tomorrow")
    }

}
