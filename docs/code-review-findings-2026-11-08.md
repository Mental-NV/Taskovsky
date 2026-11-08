# Taskovsky code review findings

Review date: 2026-11-08  
Repository: [Mental-NV/Taskovsky](https://github.com/Mental-NV/Taskovsky)  
Reviewed commit: [`18732856fb3b9d2d5b9ca55a621dabbea3aeb761`](https://github.com/Mental-NV/Taskovsky/commit/18732856fb3b9d2d5b9ca55a621dabbea3aeb761)  
Commit title: Implemented missing featues for tasks, lists, folders, tags and rich editor for notes

## Scope and verification limits

This report records five issues found by static source review of the commit above. Source links are pinned to that commit so the evidence remains stable as the repository changes.

The reproduction steps describe paths inferred from the code, not runtime reproductions. No macOS build, automated test suite, or native UI tests were run for this review. The repository's documented validation commands are `./scripts/build-app.sh` and `swift test --disable-sandbox`; they still need to be run on a suitable macOS environment after fixes. This report does not claim that every issue in the commit has been identified.

Only this Markdown report is added by the documentation commit. No application code or tests are changed.

## 1. Canceling a new custom recurrence can still save a weekly rule

**Location:** [ScheduleEditor.swift, lines 176–179](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/Taskovsky/ScheduleEditor.swift#L176-L179) and [CustomRecurrenceEditor.swift, line 158](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/Taskovsky/CustomRecurrenceEditor.swift#L158).

**Issue and cause:** Opening “Custom…” immediately assigns a valid weekly rule to the outer schedule draft before presenting the custom editor. The custom editor's Cancel action only dismisses its sheet. It does not restore the previous outer draft. Saving the outer schedule can therefore persist a rule that the user canceled.

**Reproduction to run:**

1. Open the schedule editor for a dated, non-repeating task.
2. Expand Repeat, then choose “Custom…”.
3. Click Cancel in the custom recurrence sheet without clicking Done.
4. Click OK in the outer schedule editor.
5. Reopen the schedule and inspect its recurrence.

**Expected:** The task remains non-repeating. Canceling the custom sheet leaves the outer draft exactly as it was before the sheet opened.

**Inferred actual result:** The default weekly custom rule remains in the outer draft and is saved by OK. For a task with an existing simple rule, opening and canceling Custom can likewise leave a valid custom rule that takes precedence over the intended simple rule.

**Impact:** Merely exploring the custom recurrence editor can silently turn a one-time task into a recurring task or alter an existing cadence.

**Suggested fix:** Keep the initial custom rule in sheet-local draft state. Assign `customRule` to the outer schedule only from the explicit Done callback. Alternatively, snapshot and restore the complete prior recurrence state on cancellation, including dismissal paths other than the Cancel button.

**Regression coverage:** Test Custom → Cancel → outer OK for both a non-repeating task and an existing simple recurrence. Also test Done, Clear Rule, and sheet dismissal so their different effects remain explicit.

## 2. Cloning an all-day subtask resets its reminder time to midnight

**Location:** [TaskStore.swift, lines 393–397](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/TaskovskyCore/TaskStore.swift#L393-L397) and [lines 410–415](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/TaskovskyCore/TaskStore.swift#L410-L415).

**Issue and cause:** `cloneSubtreeIntoSuccessor` uses the same `shift(_:timed:)` helper for a descendant's due date and all of its reminder instants. When `member.hasDueTime` is false, the helper first calls `calendar.startOfDay(for: date)`. That is appropriate for an all-day due date, but it discards a reminder's clock time before shifting it by calendar days.

**Reproduction to run:**

1. Create a recurring parent whose next occurrence is one week later.
2. Add an open, all-day subtask with a reminder at 09:00 on its due date.
3. Complete the parent so the subtree is cloned under the next occurrence.
4. Inspect the cloned subtask's reminder.

**Expected:** The due date and reminder move forward by the same number of calendar days, with the reminder still at 09:00 in the applicable calendar/time zone.

**Inferred actual result:** The cloned reminder is at 00:00 on the shifted day. Multiple reminders on the same original day can also collapse to the same midnight instant.

**Impact:** Recurring subtasks can notify at the wrong time, including overnight, and lose the distinction between separately scheduled reminders.

**Suggested fix:** Separate all-day due-date normalization from reminder shifting. For an all-day member's reminder, add `dayDelta` calendar days to the original reminder date rather than to its start of day, preserving its wall-clock time under the intended time-zone and DST policy. Keep the existing elapsed-time behavior for timed members where appropriate.

**Regression coverage:** Clone an all-day subtask with 09:00 and 17:00 reminders, including a reminder on the previous day. Assert their times and relative days are retained, and cover a DST transition as well as an ordinary week.

## 3. Weekend adjustment can change an every-N-month recurrence's cadence

**Location:** [CustomRecurrence.swift, lines 545–554](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/TaskovskyCore/CustomRecurrence.swift#L545-L554) and [TaskStore.swift, lines 1243–1247](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/TaskovskyCore/TaskStore.swift#L1243-L1247).

**Issue and cause:** Monthly candidate months are calculated relative to the month of the supplied `base` date. The selected candidate is then rolled past the weekend. On the following completion, `nextRecurrenceDate` passes that adjusted due date back as the next base. If the weekend roll crossed a month boundary, the calculation loses the original interval-month alignment. Its `step = 0` candidate can also produce an extra occurrence later in the adjusted month.

**Reproduction to run:**

1. Use a Gregorian calendar and a due-date-anchored custom rule for every 2 months, on the last day of the month, with “Skip weekends (roll to Monday)” enabled.
2. Start with a due date of March 31, 2026.
3. Generate the next occurrence. The nominal May 31 date is a Sunday, so it rolls to Monday, June 1.
4. Generate the occurrence after June 1.

**Expected:** The underlying two-month sequence remains March → May → July. The next nominal date after May 31 is July 31, 2026; rolling an occurrence for a weekend should not redefine the sequence.

**Inferred actual result:** The second calculation uses June as its base month. Its `step = 0` candidate is June 30, so the series can produce June 30 instead of July 31.

**Impact:** A due-date-anchored recurrence can run sooner than requested and drift away from its original every-N-month schedule after a weekend at month-end.

**Suggested fix:** Track the unadjusted nominal occurrence or a stable series month anchor separately from the displayed, weekend-adjusted due date. Generate interval-month candidates from that nominal sequence, then apply weekend adjustment to the selected occurrence. Do not reconstruct interval alignment solely from the previously adjusted due date.

**Regression coverage:** Assert several successive occurrences, not just the first next date, for the March 31 → May 31/June 1 → July 31 example. Include intervals greater than one, year boundaries, and rolled dates that stay within the nominal month.

## 4. Block formatting can include the paragraph after a selection

**Location:** [RichBodyEditor.swift, lines 889–891](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/Taskovsky/RichBodyEditor.swift#L889-L891).

**Issue and cause:** `paragraphRange()` calculates the last paragraph using a zero-length range at `selected.location + selected.length`. An `NSRange` selection has an exclusive end, so if the selection includes a newline and ends exactly at the start of the next paragraph, that lookup resolves to the next, unselected paragraph. Unioning the first and last paragraph ranges includes it in the formatting operation.

**Reproduction to run:**

1. Enter two paragraphs: `First\nSecond`.
2. Select exactly `First\n`, leaving the caret/end of the selection at the start of `Second` and selecting none of its characters.
3. Apply a heading, quote, or list format.
4. Inspect the formatting of `Second`.

**Expected:** Only the first paragraph changes.

**Inferred actual result:** The following paragraph is included in the computed range and is also formatted.

**Impact:** Block-formatting operations can unintentionally modify neighboring text outside the user's selection.

**Suggested fix:** For a non-empty selection, ask `NSString.paragraphRange(for:)` to expand the actual selected range, or resolve its last paragraph from the final included UTF-16 position, `NSMaxRange(selected) - 1`, after validating/clamping the range. Keep collapsed-caret behavior separate.

**Regression coverage:** Test a selection ending immediately before a newline, immediately after it, inside the following paragraph, and at the end of the document. Include multiple selected paragraphs and UTF-16 text with emoji.

## 5. Quote formatting cannot be toggled off in an empty editor

**Location:** [RichBodyEditor.swift, lines 545–552](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/Taskovsky/RichBodyEditor.swift#L545-L552) and [lines 781–787](https://github.com/Mental-NV/Taskovsky/blob/18732856fb3b9d2d5b9ca55a621dabbea3aeb761/Sources/Taskovsky/RichBodyEditor.swift#L781-L787).

**Issue and cause:** `toggleQuote()` first calls `armEmptyDocumentForBlock` with the quote marker set to true and both indents set to 16. For an empty document, the helper applies those attributes and returns true on every invocation. The method returns before reaching any toggle-off logic, even if the quote typing attributes are already active.

**Reproduction to run:**

1. Open a task or note with a completely empty body.
2. Click Quote to enable it.
3. Click Quote again before typing any characters.
4. Type some text.

**Expected:** The second click disables Quote, so the first typed text is plain.

**Inferred actual result:** The second click re-arms Quote and the typed text remains quoted.

**Impact:** The Quote button behaves as a one-way enable action in an empty document, unlike its toggle behavior elsewhere. Users must use another action, such as clearing formatting or undo, to return to plain typing.

**Suggested fix:** Before arming an empty document, inspect its current quote typing state. If Quote is already active, remove the quote marker and quote indentation through the existing undo-aware typing-state update path. Preserve unrelated inline formatting and the intended pending-list behavior.

**Regression coverage:** Verify Quote on → off → type in an empty editor, including undo/redo. Compare it with the same sequence in an empty trailing paragraph and check switching between Quote and pending list formatting.

## Suggested validation order

1. Fix and test recurrence cancellation and reminder-time preservation first, because they can silently change saved schedules.
2. Add a multi-occurrence regression for monthly cadence before changing recurrence state or persistence.
3. Cover paragraph selection boundaries and empty-editor toggles with native AppKit editor tests.
4. Run the documented macOS build and full test suite, then manually exercise Cancel/Done/OK, repeated toolbar clicks, and save/reopen behavior.

All five findings remain open in this report until a fix and its validation are recorded.
