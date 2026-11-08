import XCTest
@testable import TaskovskyCore

/// Outer repeat-draft policy for the Custom recurrence sheet: opening the
/// sheet must stage a seed WITHOUT touching the committed draft. Only an
/// explicit Done (including intentional Clear Rule) commits; Cancel and
/// sheet dismissal preserve the previous complete recurrence state, for
/// both non-repeating tasks and existing simple rules. These tests drive
/// the exact `RepeatDraft` transitions the ScheduleEditor's Custom… /
/// Edit Custom… buttons and sheet callbacks call.
final class RepeatDraftTests: XCTestCase {
    private func seed(weekday: Int = 2) -> CustomRecurrence {
        CustomRecurrence(anchor: .dueDate, interval: 1, unit: .weeks, weekdays: [weekday])
    }

    func testOpenWithoutRuleStagesSeedAndLeavesDraftUntouched() {
        var draft = RepeatDraft(repeatRule: .none, customRule: nil)
        draft.openCustomSheet(seed: seed())
        XCTAssertEqual(draft.repeatRule, .none)
        XCTAssertNil(draft.customRule)
        XCTAssertEqual(draft.stagedCustom, seed())
    }

    func testOpenWithSimpleRuleLeavesLegacyPickUntouched() {
        var draft = RepeatDraft(repeatRule: .weekly, customRule: nil)
        draft.openCustomSheet(seed: seed())
        XCTAssertEqual(draft.repeatRule, .weekly)
        XCTAssertNil(draft.customRule)
        XCTAssertEqual(draft.stagedCustom, seed())
    }

    func testOpenWithExistingCustomRuleStagesCommittedRule() {
        let committed = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .days)
        var draft = RepeatDraft(repeatRule: .none, customRule: committed)
        draft.openCustomSheet(seed: seed())
        XCTAssertEqual(draft.stagedCustom, committed)
        XCTAssertEqual(draft.customRule, committed)
    }

    func testCancelPreservesNoRuleState() {
        var draft = RepeatDraft(repeatRule: .none, customRule: nil)
        draft.openCustomSheet(seed: seed())
        draft.cancelCustom()
        XCTAssertEqual(draft.repeatRule, .none)
        XCTAssertNil(draft.customRule)
        XCTAssertNil(draft.stagedCustom)
    }

    func testCancelPreservesExistingSimpleRule() {
        var draft = RepeatDraft(repeatRule: .weekly, customRule: nil)
        draft.openCustomSheet(seed: seed())
        draft.cancelCustom()
        XCTAssertEqual(draft.repeatRule, .weekly)
        XCTAssertNil(draft.customRule)
        XCTAssertNil(draft.stagedCustom)
    }

    func testCancelPreservesExistingCustomRule() {
        let committed = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .days)
        var draft = RepeatDraft(repeatRule: .none, customRule: committed)
        draft.openCustomSheet(seed: seed())
        draft.cancelCustom()
        XCTAssertEqual(draft.customRule, committed)
        XCTAssertNil(draft.stagedCustom)
    }

    func testDoneCommitsRuleAndClearsLegacyPick() {
        var draft = RepeatDraft(repeatRule: .weekly, customRule: nil)
        draft.openCustomSheet(seed: seed())
        let done = CustomRecurrence(anchor: .dueDate, interval: 3, unit: .days)
        draft.commitCustom(done)
        XCTAssertEqual(draft.customRule, done)
        XCTAssertEqual(draft.repeatRule, .none)
        XCTAssertNil(draft.stagedCustom)
    }

    func testClearRuleCommitsNilAndKeepsLegacyPick() {
        let committed = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .days)
        var draft = RepeatDraft(repeatRule: .none, customRule: committed)
        draft.openCustomSheet(seed: seed())
        draft.commitCustom(nil)
        XCTAssertNil(draft.customRule)
        XCTAssertEqual(draft.repeatRule, .none)
        XCTAssertNil(draft.stagedCustom)
    }

    func testFullSequenceCancelThenDoneThenClear() {
        var draft = RepeatDraft(repeatRule: .none, customRule: nil)
        // Explore and cancel: nothing sticks.
        draft.openCustomSheet(seed: seed())
        draft.cancelCustom()
        XCTAssertNil(draft.customRule)
        // Reopen and commit: the rule lands, the legacy enum clears.
        draft.openCustomSheet(seed: seed())
        let done = CustomRecurrence(anchor: .dueDate, interval: 1, unit: .months)
        draft.commitCustom(done)
        XCTAssertEqual(draft.customRule, done)
        // Edit then clear: back to non-repeating.
        draft.openCustomSheet(seed: seed())
        XCTAssertEqual(draft.stagedCustom, done)
        draft.commitCustom(nil)
        XCTAssertNil(draft.customRule)
        XCTAssertNil(draft.stagedCustom)
    }

    func testDropCustomKeepsLegacyPick() {
        let committed = CustomRecurrence(anchor: .dueDate, interval: 2, unit: .days)
        var draft = RepeatDraft(repeatRule: .monthly, customRule: committed)
        draft.dropCustom()
        XCTAssertNil(draft.customRule)
        XCTAssertEqual(draft.repeatRule, .monthly)
        XCTAssertNil(draft.stagedCustom)
    }
}
