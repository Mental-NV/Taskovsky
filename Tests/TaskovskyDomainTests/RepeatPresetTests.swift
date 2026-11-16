import XCTest
@testable import TaskovskyDomain

/// D12 Repeat preset menu: reference order, live-derived labels, draft
/// summaries, current-preset detection and staging through the unchanged
/// `TaskScheduleEdit` transitions. The observed reference date is Thursday
/// November 12 (all-day); these tests pin that configuration plus ordinal
/// coverage and the custom-preservation rule that a staged custom rule never
/// reads as a simple preset.
final class RepeatPresetTests: XCTestCase {
    func calendar(_ zone: String = "UTC") -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; c.locale = Locale(identifier: "en_US")
        return c
    }
    func date(_ c: Calendar, _ month: Int = 11, _ day: Int = 12) -> Date {
        c.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    func testMenuOrderMatchesReference() {
        XCTAssertEqual(RepeatPreset.menuCases.map(\.rawValue),
                       ["none", "daily", "weekly", "monthly", "yearly", "weekdays", "custom"])
    }

    func testLabelsDeriveFromObservedThursday() {
        let c = calendar(), due = date(c)
        XCTAssertEqual(c.component(.weekday, from: due), 5) // Thursday guards the fixture
        XCTAssertEqual(RepeatPreset.none.menuLabel(due: due, calendar: c), "None")
        XCTAssertEqual(RepeatPreset.daily.menuLabel(due: due, calendar: c), "Daily")
        XCTAssertEqual(RepeatPreset.weekly.menuLabel(due: due, calendar: c), "Weekly (Thursday)")
        XCTAssertEqual(RepeatPreset.monthly.menuLabel(due: due, calendar: c), "Monthly (the 12th day)")
        XCTAssertEqual(RepeatPreset.yearly.menuLabel(due: due, calendar: c), "Yearly (12 Nov)")
        XCTAssertEqual(RepeatPreset.weekdays.menuLabel(due: due, calendar: c), "Every Weekday (Mon - Fri)")
        XCTAssertEqual(RepeatPreset.custom.menuLabel(due: due, calendar: c), "Custom")
    }

    func testOrdinalsCoverFirstSecondThirdAndTwenties() {
        let c = calendar()
        let cases = [(1, "1st"), (2, "2nd"), (3, "3rd"), (4, "4th"), (12, "12th"),
                     (21, "21st"), (22, "22nd"), (23, "23rd"), (31, "31st")]
        for (day, ordinal) in cases {
            XCTAssertEqual(RepeatPreset.monthly.menuLabel(due: date(c, 1, day), calendar: c),
                           "Monthly (the \(ordinal) day)")
        }
    }

    func testLabelsFollowStagedZone() {
        var pacific = calendar("America/Los_Angeles")
        pacific.locale = Locale(identifier: "en_US")
        // 2026-11-12 00:30 UTC is still Wednesday the 11th in Los Angeles.
        let utc = calendar()
        let due = utc.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 0, minute: 30))!
        XCTAssertEqual(RepeatPreset.weekly.menuLabel(due: due, calendar: pacific), "Weekly (Wednesday)")
        XCTAssertEqual(RepeatPreset.monthly.menuLabel(due: due, calendar: pacific), "Monthly (the 11th day)")
    }

    func testWeeklyDraftSummaryMatchesObservedWording() {
        let c = calendar(), due = date(c)
        XCTAssertEqual(RepeatPreset.weekly.draftSummary(due: due, calendar: c), "Every week on Thu")
        XCTAssertEqual(RepeatPreset.none.draftSummary(due: due, calendar: c), "None")
        XCTAssertEqual(RepeatPreset.daily.draftSummary(due: due, calendar: c), "Daily")
    }

    func testPresetRuleMappingAndCurrentDetection() {
        XCTAssertEqual(RepeatPreset.weekly.repeatRule, .weekly)
        XCTAssertEqual(RepeatPreset.weekdays.repeatRule, .weekdays)
        XCTAssertNil(RepeatPreset.custom.repeatRule)
        XCTAssertEqual(RepeatPreset.current(repeatRule: .weekly, customRule: nil), .weekly)
        XCTAssertEqual(RepeatPreset.current(repeatRule: .none, customRule: nil), RepeatPreset.none)
        let custom = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [5])
        XCTAssertNil(RepeatPreset.current(repeatRule: .none, customRule: custom))
        XCTAssertNil(RepeatPreset.current(repeatRule: .weekly, customRule: custom))
    }

    func testPresetSelectionStagesThroughEditAndRoundsTripsSave() throws {
        let c = calendar(), due = date(c)
        var task = TaskItem(title: "Neutral", dueDate: due)
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: c, now: due)
        edit.selectSimpleRepeat(.weekly)
        XCTAssertEqual(edit.repeatRule, .weekly)
        XCTAssertNil(edit.customRule)
        XCTAssertEqual(RepeatPreset.current(repeatRule: edit.repeatRule, customRule: edit.customRule), .weekly)
        let summary = try XCTUnwrap(RepeatPreset(rawValue: edit.repeatRule.rawValue)).draftSummary(due: due, calendar: c)
        XCTAssertEqual(summary, "Every week on Thu")
        let saved = try edit.applying(to: task, settings: AppSettings())
        XCTAssertEqual(saved.recurrence, .weekly)
        XCTAssertNil(saved.customRecurrence)
        let reopened = TaskScheduleEdit(task: saved, settings: AppSettings(), calendar: c, now: due)
        XCTAssertEqual(RepeatPreset.current(repeatRule: reopened.repeatRule, customRule: reopened.customRule), .weekly)
    }

    func testSelectingNoneClearsStagedEnd() {
        let c = calendar(), due = date(c)
        var task = TaskItem(title: "Neutral", dueDate: due)
        var edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: c, now: due)
        edit.selectSimpleRepeat(.monthly)
        edit.repeatEnd = c.startOfDay(for: due)
        edit.selectSimpleRepeat(.none)
        XCTAssertEqual(edit.repeatRule, .none)
        XCTAssertNil(edit.repeatEnd)
    }

    func testExistingCustomRuleIsPreservedByDetection() {
        let c = calendar(), due = date(c)
        var task = TaskItem(title: "Neutral", dueDate: due)
        task.customRecurrence = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months)
        let edit = TaskScheduleEdit(task: task, settings: AppSettings(), calendar: c, now: due)
        XCTAssertNotNil(edit.customRule)
        XCTAssertNil(RepeatPreset.current(repeatRule: edit.repeatRule, customRule: edit.customRule))
        XCTAssertEqual(edit.repeatRule, .none) // opening never converts the rule
    }
}
