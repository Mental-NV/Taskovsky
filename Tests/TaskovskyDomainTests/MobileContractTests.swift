import XCTest
import TaskovskyDomain

final class MobileContractTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!; value.firstWeekday = 2
        return value
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private var now: Date { date("2026-11-09T12:00:00Z") }
    private func ids(_ tasks: [TaskItem]) -> [UUID] { tasks.map(\.id) }

    func testSummaryUsesPeriodHistoryAndExplicitArchiveSelection() {
        let archived = TaskList(name: "Archive", color: "#123456", isArchived: true)
        let excluded = TaskList(name: "Excluded", color: "#123456", showsInSmartLists: false)
        let done = TaskItem(title: "Finished", dueDate: date("2026-11-04T08:00:00Z"), completedAt: now)
        let archive = TaskItem(title: "Archived report item", listID: archived.id, dueDate: now, completedAt: now)
        let excludedTask = TaskItem(title: "Excluded report item", listID: excluded.id, dueDate: now, completedAt: now)
        let note = TaskItem(title: "Report note", kind: .note, dueDate: now)
        let trash = TaskItem(title: "Trashed report item", dueDate: now, deletedAt: now)
        let data = WorkspaceData(tasks: [done, archive, excludedTask, note, trash], lists: [archived, excluded])
        var options = SummaryReportOptions(period: .today, customStart: now, customEnd: now, status: .completed, fields: [])
        let report = SummaryReport.generate(from: data, options: options, now: now, calendar: calendar)
        XCTAssertEqual(report.text, "Summary · " + report.range + "\n\nCompleted\n- Finished")
        options.listIDs = [archived.id, excluded.id]
        options.grouping = .list
        let explicit = SummaryReport.generate(from: data, options: options, now: now, calendar: calendar)
        XCTAssertEqual(explicit.text, "Summary · " + explicit.range +
            "\n\nArchive\n- Archived report item\n\nExcluded\n- Excluded report item")
    }

    func testSummaryCustomDaysAndNextPeriodRespectExclusiveEnd() {
        let start = date("2026-11-08T00:00:00Z"), end = date("2026-11-10T00:00:00Z")
        let tag = TaskTag(name: "Planning", color: "#123456")
        let current = TaskItem(title: "Review", body: "A composed e\u{301}\nSecond line", tagIDs: [tag.id],
                               dueDate: end.addingTimeInterval(-1), priority: .high)
        let next = TaskItem(title: "Next", dueDate: end)
        let future = TaskItem(title: "Future", dueDate: date("2026-11-12T00:00:00Z"))
        let options = SummaryReportOptions(period: .custom, customStart: now, customEnd: start, fields: [.tags, .priority, .description], nextPeriod: true)
        XCTAssertEqual(options.interval(now: now, calendar: calendar), DateInterval(start: start, end: end))
        let report = SummaryReport.generate(from: WorkspaceData(tasks: [current, next, future], tags: [tag]),
                                            options: options, now: now, calendar: calendar)
        let expected = "Summary · " + report.range +
            "\n\nUndone\n- Review (#Planning · High priority)\n  A composed e\u{301}\n  Second line" +
            "\n\nNext Period Tasks\n- Next"
        XCTAssertTrue(RichBody.sameCodeUnits(report.text, expected))
    }

    func testSummaryUsesReportZoneForHeadingsAndFloatingDueDates() {
        var reportCalendar = calendar
        reportCalendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        let boundary = date("2026-11-09T11:30:00Z")
        let floating = TaskItem(title: "Floating", dueDate: boundary, hasDueTime: true)
        let explicit = TaskItem(title: "New York", dueDate: boundary, hasDueTime: true,
                                timeZoneID: "America/New_York")
        let options = SummaryReportOptions(period: .today, customStart: boundary, customEnd: boundary,
                                           grouping: .date, fields: [.date])
        let report = SummaryReport.generate(from: WorkspaceData(tasks: [floating, explicit]), options: options,
                                            now: boundary, calendar: reportCalendar)
        let heading = boundary.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                                          calendar: reportCalendar, timeZone: reportCalendar.timeZone))
        XCTAssertEqual(reportCalendar.component(.day, from: boundary), 10)
        XCTAssertEqual(report.range, "\(heading) – \(heading)")
        XCTAssertTrue(report.text.contains("\n\(heading)\n"))

        func due(in zone: TimeZone) -> String {
            let formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            let day = formatter.string(from: boundary)
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return day + " " + formatter.string(from: boundary)
        }
        let newYork = TimeZone(identifier: "America/New_York")!
        let suffix = newYork.abbreviation(for: boundary) ?? newYork.identifier
        XCTAssertTrue(report.text.contains("- Floating (\(due(in: reportCalendar.timeZone)))"))
        XCTAssertTrue(report.text.contains("- New York (\(due(in: newYork)) \(suffix))"))
    }

    func testSummaryCaptureKeepsExactTextAndBypassesCreationDefaults() throws {
        let list = TaskList(name: "Work", color: "#123456")
        let tag = TaskTag(name: "Planning", color: "#123456")
        var settings = AppSettings()
        settings.defaultListID = list.id
        settings.defaultTagID = tag.id
        settings.defaultDate = .today
        settings.defaultPriority = .high
        let text = "Summary\nA composed e\u{301} and #Planning tomorrow."
        let input = TaskCaptureInput.summaryNote(title: "Summary tomorrow #Planning", body: text)
        let note = try input.task(id: UUID(), now: now, workspace: WorkspaceData(lists: [list], tags: [tag]), settings: settings, calendar: calendar)
        XCTAssertTrue(RichBody.sameCodeUnits(note.body, text))
        XCTAssertEqual(note.title, "Summary tomorrow #Planning")
        XCTAssertEqual(note.kind, .note)
        XCTAssertNil(note.listID)
        XCTAssertNil(note.dueDate)
        XCTAssertEqual(note.priority, .none)
        XCTAssertTrue(note.tagIDs.isEmpty)
        XCTAssertTrue(note.reminderDates.isEmpty)
    }

    func testTodayAndWeekIncludeOverdueWhileSavedDatesStayBounded() {
        let overdue = TaskItem(title: "Overdue", dueDate: date("2026-11-01T10:00:00Z"))
        let today = TaskItem(title: "Today", dueDate: date("2026-11-09T10:00:00Z"))
        let tomorrow = TaskItem(title: "Tomorrow", dueDate: date("2026-11-10T10:00:00Z"))
        let boundary = TaskItem(title: "Outside week", dueDate: date("2026-11-16T00:00:00Z"))
        let data = WorkspaceData(tasks: [overdue, today, tomorrow, boundary])
        XCTAssertEqual(ids(TaskDestination.today.matchingTasks(in: data, now: now, calendar: calendar)), [overdue.id, today.id])
        XCTAssertEqual(ids(TaskDestination.week.matchingTasks(in: data, now: now, calendar: calendar)), [overdue.id, today.id, tomorrow.id])
        let filter = TaskFilter(name: "Today", dateRule: .today)
        XCTAssertFalse(filter.matches(overdue, lists: [], now: now, calendar: calendar))
        XCTAssertTrue(filter.matches(today, lists: [], now: now, calendar: calendar))
    }

    func testHistoryAndArchiveExceptionsArePreserved() {
        let archived = TaskList(name: "Archived", color: "#000000", isArchived: true)
        let excluded = TaskList(name: "Excluded", color: "#000000", showsInSmartLists: false)
        let hidden = TaskItem(title: "Hidden", listID: excluded.id)
        var history = TaskItem(title: "Archived history", listID: archived.id); history.completedAt = now
        var trashed = TaskItem(title: "Trashed"); trashed.deletedAt = now
        let data = WorkspaceData(tasks: [hidden, history, trashed], lists: [archived, excluded])
        XCTAssertTrue(TaskDestination.all.matchingTasks(in: data, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.completed.matchingTasks(in: data, now: now, calendar: calendar)), [history.id])
        XCTAssertEqual(ids(TaskDestination.list(archived.id).matchingTasks(in: data, showHistory: true, now: now, calendar: calendar)), [history.id])
        XCTAssertTrue(TaskDestination.list(archived.id).matchingTasks(in: data, showHistory: false, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.trash.matchingTasks(in: data, now: now, calendar: calendar)), [trashed.id])
    }

    func testParentTagNavigationDiffersFromSelectedTagFilter() {
        let parent = TaskTag(name: "Parent", color: "#000000")
        let child = TaskTag(name: "Child", color: "#000000", parentID: parent.id)
        var task = TaskItem(title: "Child tagged"); task.tagIDs = [child.id]
        let data = WorkspaceData(tasks: [task], tags: [parent, child])
        XCTAssertEqual(ids(TaskDestination.tag(parent.id).matchingTasks(in: data, now: now, calendar: calendar)), [task.id])
        XCTAssertFalse(TaskFilter(name: "Direct tag", tagIDs: [parent.id]).matches(task, lists: [], now: now, calendar: calendar))
    }

    func testMissingFilterRemainsEmptyAndExistingFilterUsesOwnStatus() {
        var task = TaskItem(title: "History"); task.completedAt = now
        let filter = TaskFilter(name: "Completed", status: .completed)
        let data = WorkspaceData(tasks: [task], filters: [filter])
        XCTAssertTrue(TaskDestination.filter(UUID()).matchingTasks(in: data, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(ids(TaskDestination.filter(filter.id).matchingTasks(in: data, showHistory: false, now: now, calendar: calendar)), [task.id])
    }

    func testTaskZoneDefinesRelativeDateMembership() {
        var task = TaskItem(title: "Tokyo tomorrow", dueDate: date("2026-11-09T16:00:00Z"))
        task.timeZoneID = "Asia/Tokyo"
        let data = WorkspaceData(tasks: [task])
        XCTAssertFalse(TaskDestination.today.includes(task, data: data, now: now, calendar: calendar))
        XCTAssertTrue(TaskDestination.tomorrow.includes(task, data: data, now: now, calendar: calendar))
    }

    func testLegacyMonthAndLeapAnchorsSurvivePureExtraction() {
        let feb = LegacyRecurrence.nextDate(after: date("2026-01-31T10:00:00Z"), rule: .monthly, anchorDay: 31, calendar: calendar)!
        XCTAssertEqual(feb, date("2026-02-28T10:00:00Z"))
        XCTAssertEqual(LegacyRecurrence.nextDate(after: feb, rule: .monthly, anchorDay: 31, calendar: calendar), date("2026-03-31T10:00:00Z"))
        XCTAssertEqual(LegacyRecurrence.nextDate(after: date("2024-02-29T10:00:00Z"), rule: .yearly, anchorDay: 29, anchorMonth: 2, calendar: calendar), date("2025-02-28T10:00:00Z"))
    }

    func testLegacyDailyKeepsWallClockAcrossDST() {
        var local = calendar; local.timeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(LegacyRecurrence.nextDate(after: date("2026-03-07T14:00:00Z"), rule: .daily, calendar: local), date("2026-03-08T13:00:00Z"))
    }

    func testPlainRichIdentityAndPreciseScheduleRemainPortable() {
        let composed = "é", decomposed = "e\u{301}"
        XCTAssertNil(RichBody(text: composed).valid(for: decomposed))
        var task = TaskItem(title: "Precise", dueDate: now)
        task.hasDueTime = true
        task.scheduledDuration = TaskDurationRange(start: now.addingTimeInterval(-301.125), end: now, isAllDay: false)
        let draft = CalendarScheduleDraft(task: task, focus: now, hourly: true, calendar: calendar)
        XCTAssertNil(draft.operation)
        XCTAssertEqual(draft.start, task.scheduledDuration?.start)
    }
}

extension MobileContractTests {
    func testRichPreviewKeepsExactTextAndProjectsParagraphDecorations() throws {
        let body = "Title\nFirst 🧩\nSecond\nPlain e\u{301}\nThird\nChecked\n\nQuote"
        let text = body as NSString
        func block(_ phrase: String, heading: Int? = nil, quote: Bool = false,
                   list: RichListStyle? = nil, checked: Bool? = nil) -> RichBlockRun {
            let range = text.paragraphRange(for: text.range(of: phrase))
            return .init(location: range.location, length: range.length, heading: heading, quote: quote, list: list, checked: checked)
        }
        let emoji = text.range(of: "🧩")
        let rich = RichBody(text: body, runs: [.init(location: emoji.location, length: emoji.length, bold: true, highlight: true)],
                            blocks: [block("Title", heading: 6), block("First", list: .numbered), block("Second", list: .numbered),
                                     block("Third", list: .numbered), block("Checked", list: .checklist, checked: true),
                                     .init(location: text.range(of: "\n\n").location + 1, length: 1, rule: true),
                                     block("Quote", quote: true)])
        let preview = try XCTUnwrap(RichDescriptionPreview(body: body, rich: rich))
        XCTAssertTrue(RichBody.sameCodeUnits(preview.text, body))
        XCTAssertEqual(preview.inline, rich.runs)
        XCTAssertEqual(preview.paragraphs.map(\.marker), [nil, .number(1), .number(2), nil, .number(1), .checklist(checked: true), nil, nil])
        XCTAssertEqual(preview.paragraphs.first?.heading, 6)
        XCTAssertEqual(preview.paragraphs.last?.quote, true)
        XCTAssertTrue(preview.paragraphs[6].rule)
        XCTAssertEqual(preview.paragraphs.map { text.substring(with: $0.range) }.joined().utf16.map { $0 }, Array(body.utf16))
    }

    func testRichPreviewRefusesWrongMirroredTextAndMalformedUTF16Ranges() {
        let body = "e\u{301} 🧩"
        let rich = RichBody(text: body, runs: [.init(location: 0, length: 2, bold: true)])
        XCTAssertNil(RichDescriptionPreview(body: "é 🧩", rich: rich))
        for run in [RichInlineRun(location: 0, length: .max, bold: true),
                    .init(location: -1, length: 2, bold: true),
                    .init(location: 3, length: 1, bold: true),
                    .init(location: 4, length: 1, bold: true)] {
            XCTAssertNil(RichDescriptionPreview(body: body, rich: RichBody(text: body, runs: [run])))
        }
        let malformed = RichBody(text: body, blocks: [.init(location: 0, length: 2, heading: 7)])
        XCTAssertNil(RichDescriptionPreview(body: body, rich: malformed))
    }
}
