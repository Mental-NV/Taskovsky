import Foundation
import Testing
@testable import TaskovskyCore

@Suite struct DueLabelsTests {
    private func calendar(identifier: String = "Asia/Tokyo") -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: identifier)!
        return cal
    }

    @Test func classifiesYesterdayTodayTomorrow() {
        let cal = calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9))!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        #expect(DueLabels.day(for: yesterday, now: now, calendar: cal) == .yesterday)
        #expect(DueLabels.day(for: now, now: now, calendar: cal) == .today)
        #expect(DueLabels.day(for: tomorrow, now: now, calendar: cal) == .tomorrow)
    }

    @Test func lateNightDueIsStillTodayInTaskTimeZone() {
        // 00:30 wall time is the same calendar day as 23:00 the evening before.
        let cal = calendar()
        let evening = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23))!
        let night = cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 30))!
        #expect(DueLabels.day(for: night, now: evening, calendar: cal) == .tomorrow)
        #expect(DueLabels.day(for: evening, now: night, calendar: cal) == .yesterday)
    }

    @Test func timedTaskDueTodayShowsOnlyTime() {
        #expect(DueLabels.rowLabel(for: .today, dayText: "2 Nov", timeText: "00:01") == "00:01")
        #expect(DueLabels.rowLabel(for: .today, dayText: "Today", timeText: nil) == "Today")
        #expect(DueLabels.rowLabel(for: .yesterday, dayText: "1 Nov", timeText: nil) == "1 Nov")
        #expect(DueLabels.detailLabel(for: .today, dayText: "2 Nov", timedSuffix: ", 00:01") == "Today, 2 Nov, 00:01")
        #expect(DueLabels.detailLabel(for: .yesterday, dayText: "1 Nov", timedSuffix: "") == "Yesterday, 1 Nov")
        #expect(DueLabels.detailLabel(for: .past(daysOverdue: 10), dayText: "23 Oct", timedSuffix: "") == "23 Oct, 10d overdue")
    }

    @Test func expandedRowsShowBothScheduleEndpointsInTheTaskCalendar() {
        let cal = calendar()
        let first = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23))!
        let sameDay = first.addingTimeInterval(1_800)
        let nextDay = first.addingTimeInterval(7_200)
        func day(_ date: Date) -> String { "Nov \(cal.component(.day, from: date))" }
        func time(_ date: Date) -> String {
            String(format: "%02d:%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))
        }
        var task = TaskItem(title: "Review", dueDate: first, hasDueTime: true)
        func label() -> String? {
            DueLabels.expandedRowLabel(for: task, calendar: cal, dayText: day, timeText: time)
        }
        #expect(label() == "Nov 9 23:00")
        task.scheduledDuration = .init(start: first, end: sameDay)
        #expect(label() == "Nov 9 23:00 – 23:30")
        task.scheduledDuration = .init(start: first, end: nextDay)
        #expect(label() == "Nov 9 23:00 – Nov 10 01:00")
        task.scheduledDuration = .init(start: first, end: nextDay, isAllDay: true)
        #expect(label() == "Nov 9 – Nov 10")
        task.scheduledDuration = .init(start: first, end: first, isAllDay: true)
        #expect(label() == "Nov 9")
        task.scheduledDuration = .init(start: nextDay, end: first)
        #expect(label() == "Nov 9 23:00")
        task.scheduledDuration = nil
        task.dueDate = nil
        #expect(label() == nil)
    }

    @Test func groupedExpandedRowsPreserveCivilDatesAndUseDisplayMidnight() throws {
        var display = Calendar(identifier: .gregorian)
        display.timeZone = try #require(TimeZone(identifier: "UTC"))
        var source = display
        source.timeZone = try #require(TimeZone(identifier: "Pacific/Kiritimati"))
        let start = try #require(display.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 30)))
        let end = start.addingTimeInterval(7_200)
        let civilStart = try #require(source.date(from: DateComponents(year: 2026, month: 11, day: 10)))
        let civilEnd = try #require(source.date(byAdding: .day, value: 1, to: civilStart))
        func day(_ date: Date) -> String { "Nov \(display.component(.day, from: date))" }
        func time(_ date: Date) -> String {
            String(format: "%02d:%02d", display.component(.hour, from: date), display.component(.minute, from: date))
        }
        let timed = TaskItem(title: "Timed range", dueDate: end, hasDueTime: true, timeZoneID: source.timeZone.identifier,
                             scheduledDuration: .init(start: start, end: end))
        let allDay = TaskItem(title: "All-day range", dueDate: civilEnd, timeZoneID: source.timeZone.identifier,
                              scheduledDuration: .init(start: civilStart, end: civilEnd, isAllDay: true))
        let point = TaskItem(title: "All-day point", dueDate: civilStart, timeZoneID: source.timeZone.identifier)
        #expect(source.isDate(start, inSameDayAs: end))
        #expect(DueLabels.expandedRowLabel(for: timed, calendar: source, displayCalendar: display, dayText: day, timeText: time)
                == "Nov 9 23:30 – Nov 10 01:30")
        #expect(DueLabels.expandedRowLabel(for: allDay, calendar: source, displayCalendar: display, dayText: day, timeText: time)
                == "Nov 10 – Nov 11")
        #expect(DueLabels.expandedRowLabel(for: point, calendar: source, displayCalendar: display, dayText: day, timeText: time)
                == "Nov 10")
    }

    @Test func overdueCountsWholeDaysAcrossDaylightSaving() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        let due = cal.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        // 23 Oct -> 2 Nov spans the 1 Nov fallback; day arithmetic still counts 10.
        #expect(DueLabels.day(for: due, now: now, calendar: cal) == .past(daysOverdue: 10))
        #expect(DueLabels.isOverdue(due: due, now: now, calendar: cal))
        #expect(!DueLabels.isOverdue(due: now, now: now, calendar: cal))
    }
}

@Suite struct UndoCoordinatorTests {
    @Test func consumeAppliesExactlyOnce() {
        let coordinator = UndoCoordinator()
        let claim = coordinator.record(taskID: UUID(), kind: .complete)
        #expect(coordinator.hasActive)
        #expect(coordinator.consume(token: claim.token) == claim)
        #expect(!coordinator.hasActive)
        #expect(coordinator.consume(token: claim.token) == nil)
    }

    @Test func inspectingFailedUndoKeepsOriginalClaimUntilExpiryOrReplacement() {
        let coordinator = UndoCoordinator()
        let original = coordinator.record(taskID: UUID(), kind: .complete)
        #expect(coordinator.claim(token: original.token) == original)
        #expect(coordinator.claim(token: original.token) == original)
        coordinator.expire(token: original.token)
        #expect(coordinator.claim(token: original.token) == nil)
        let next = coordinator.record(taskID: UUID(), kind: .trash)
        #expect(coordinator.claim(token: original.token) == nil)
        #expect(coordinator.claim(token: next.token) == next)
        #expect(coordinator.consume(token: next.token) == next)
        #expect(coordinator.claim(token: next.token) == nil)
    }

    @Test func expiryClearsWithoutApplying() {
        let coordinator = UndoCoordinator()
        let claim = coordinator.record(taskID: UUID(), kind: .complete)
        coordinator.expire(token: claim.token)
        #expect(!coordinator.hasActive)
        #expect(coordinator.consume(token: claim.token) == nil)
    }

    @Test func newerRecordSupersedesStaleToken() {
        let coordinator = UndoCoordinator()
        let first = coordinator.record(taskID: UUID(), kind: .complete)
        let second = coordinator.record(taskID: UUID(), kind: .wontDo)
        #expect(coordinator.consume(token: first.token) == nil)
        #expect(coordinator.consume(token: second.token) == second)
    }
}

@Suite struct DetailSelectionStateTests {
    @Test func selectOpensDrawerOnlyForOverlay() {
        var state = DetailSelectionState()
        let id = UUID()
        state.select(id, overlay: true)
        #expect(state.selection == id && state.drawerOpen)
        var docked = DetailSelectionState()
        docked.select(id, overlay: false)
        #expect(docked.selection == id && !docked.drawerOpen)
    }

    @Test func shrinkKeepsSelectionButDismisses() {
        var state = DetailSelectionState(selection: UUID(), drawerOpen: true)
        state.shrinkToOverlay()
        #expect(state.selection != nil && !state.drawerOpen)
        state.reopen()
        #expect(state.drawerOpen)
    }

    @Test func navigateAndCloseKeepSelection() {
        var state = DetailSelectionState(selection: UUID(), drawerOpen: true)
        state.navigate()
        #expect(state.selection != nil && !state.drawerOpen)
        state.reopen()
        state.close()
        #expect(state.selection != nil && !state.drawerOpen)
    }

    @Test func reopenWithoutSelectionStaysClosed() {
        var state = DetailSelectionState()
        state.reopen()
        #expect(!state.drawerOpen)
        state.clear()
        #expect(state.selection == nil && !state.drawerOpen)
    }
}
