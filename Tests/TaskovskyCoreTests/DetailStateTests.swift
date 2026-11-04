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
