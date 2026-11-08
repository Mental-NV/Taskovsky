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

All five findings were open at the time of the static review. Their fixes and validation are recorded below.

## Resolutions (recorded 2026-11-08, implementation worker)

**Current status: all five findings addressed.** Final validation passes
435 tests (401 XCTest + 34 Swift Testing), with no failures, errors, or
warnings. The release build and local signature verification pass. Logs:
[tests](../build/verification/swift-test.log),
[release build](../build/verification/build-app.log). The fixes remain
uncommitted. Live checks and their limits are recorded at the end.

The original static findings above retain their evidence and reproduction
steps. Each item below records the actual fix and regression evidence.
First-pass validation (superseded by the final run above):
`swift test --disable-sandbox --manifest-cache local` →
380 XCTest + 34 Swift Testing = 414 tests, 0 failures, 0 warnings
(`build/verification/swift-test.log`); `./scripts/build-app.sh` exit 0 and
`codesign --verify --deep --strict build/Taskovsky.app` passes
(`build/verification/build-app.log`). No commits; working tree holds the
source/test changes for parent review. No live UI verification was run by
the worker (parent owns that); see the per-item limits.

### 1. Custom recurrence Cancel — fixed (RepeatDraft)

Opening Custom no longer assigns to the outer draft. The outer repeat state
now lives in a `RepeatDraft` value (`Sources/TaskovskyCore/ScheduleDraft.swift`):
`openCustomSheet(seed:)` stages the committed rule (or a caller seed) into
`stagedCustom`; only `commitCustom` writes the committed rule (clearing the
legacy enum), and Clear Rule commits nil; `cancelCustom` and every dismissal
path drop only the staged value; `dropCustom` backs "Use Simple".
`ScheduleEditor` routes both Custom… buttons and the sheet callbacks through
it (`Sources/Taskovsky/ScheduleEditor.swift`); the sheet initializes its own
local draft from `stagedCustom`, so Cancel cannot leak a rule into OK for no-rule, simple, or
existing-custom drafts.
Regression: `Tests/TaskovskyCoreTests/RepeatDraftTests.swift` (10 tests:
open/cancel/done/clear/dismissal across no-rule, simple, and custom drafts,
plus the full cancel→done→clear sequence). The tests failed to compile
pre-fix (no such policy type existed); the pre-fix leak is the cited
assignment at `ScheduleEditor.swift:176-179` of the reviewed commit.
The SwiftUI button/sheet wiring is covered by review and the live checks
below; the automated tests exercise the shared draft policy.

### 2. Cloned all-day reminders — fixed (shiftReminder)

`cloneSubtreeIntoSuccessor` (`Sources/TaskovskyCore/TaskStore.swift`) no
longer shifts reminders through the due-date `startOfDay` normalizer. A new
`shiftReminder` keeps each reminder's own wall-clock time and its relative
calendar-day offset (same shape as the successor path's existing
day-offset/hour re-stamp): 09:00 stays 09:00, a previous-day reminder stays
previous-day, across ordinary weeks and DST in the task's zone. Timed
members keep exact elapsed-time shifting (unchanged).
Regression: `Tests/TaskovskyCoreTests/CloneReminderTests.swift` (3 tests
through real `toggleComplete` → successor → subtree clone: 09:00/17:00 +
previous-day reminders; America/New_York DST spring-forward week; timed
elapsed-time control). Pre-fix run: reminders collapsed to midnight and two
same-day reminders merged — the exact reported failure. Post-fix: 3/3 pass.
Zone pinning (`timeZoneID = "UTC"` / `"America/New_York"`) keeps the tests
host-independent (host here is MSK, UTC+3).

### 3. Every-N-month nominal cadence — fixed (recurrenceNominalDate)

Interval alignment now tracks the unadjusted nominal occurrence instead of
being reconstructed from the displayed adjusted due:
- `TaskItem.recurrenceNominalDate` (`Sources/TaskovskyCore/Models.swift`,
  compatible: new init param defaulting nil, `decodeIfPresent`, synthesized
  encode) records the nominal occurrence for the current due date; legacy
  records decode nil and fall back to the due date for one transition.
- `CustomRecurrence.nextNominalOccurrence(after:calendar:occurrenceIndex:)`
  + `weekendAdjusted(_:calendar:)` split stepping from rolling; monthly and
  yearly chain on the internal nominal cursor in `occurrences()` and in
  `isOccurrence(on:seriesStart:calendar:nominalStart:)` (new optional
  nominal, default preserves old signature behavior). Daily/weekly keep
  adjusted chaining (their skip semantics advance past weekend days) and the
  completion anchor still advances from the completion instant.
- `TaskStore.nextCustomStep` advances due-date series from
  `recurrenceNominalDate ?? dueDate` and returns the new nominal;
  `nextRecurrenceDate` and successors share it; successors record the
  nominal (nil for completion anchor/legacy); `duplicateTask` restarts the
  series at the copy's due date; subtree clones shift the nominal with the
  member; `restartCustomSeries(ruleChangedFrom:)` on `TaskItem` resets
  index + nominal on rule changes and is called from `ScheduleEditor.apply`,
  `ScheduleEditor.clear`, and `TaskDetail.applyTemplate`.
- Previews share the alignment: `remainingOccurrences(..., nominal:)`
  advances from the nominal, and the ScheduleEditor preview and occurrence
  check pass `task.recurrenceNominalDate`.
Regression: `Tests/TaskovskyCoreTests/NominalCadenceTests.swift` (13
tests): Mar 31 → May 31/Jun 1 → Jul 31 engine chain, `isOccurrence` with
and without nominal, year boundary (Nov 30 → Feb 1 → Mar 31), in-month roll,
completion-anchor semantics + nil nominal, store successor chain, save/reload
persistence, legacy fallback, duplicate restart, rule-change restart,
maxOccurrences termination. A throwaway probe using only pre-existing API
reproduced the reported drift (`[Mar 31, Jun 1, Jun 30, Aug 31]`) before the
fix and was deleted afterwards; post-fix the chain is
`[Mar 31, Jun 1, Jul 31, Sep 30]`.
Known limit: a legacy record sitting on an
already-rolled due date transitions once from that date (pinned by
`testLegacyRecordFallsBackToDueDate`). Its original nominal date cannot be
recovered from the adjusted date alone.

### 4. Block selection boundaries — fixed (blockRange)

The exclusive-end policy is now a tested Core seam:
`RichMutate.blockRange(for:in:)` resolves the last paragraph from the final
included UTF-16 unit (`NSMaxRange - 1`); `RichBodyController.paragraphRange()`
delegates to it (all block toggles share the fix, behavior otherwise
unchanged: collapsed caret, exact-EOF caret, clamping).
Regression: `Tests/TaskovskyCoreTests/BlockRangeTests.swift` (11 tests):
before/after newline, into the following paragraph, EOF, multiple
paragraphs, emoji UTF-16, collapsed carets, empty string, plus the production
toggle path on a real `NSTextView` (`toggleQuote` over the shared range
leaves the second paragraph alone, and toggles back off). The new
`{0,6} → {0,6}` test was proven against the old inline computation in a
throwaway probe (`{0,12}`, probe deleted).

### 5. Empty-editor Quote toggle — fixed (isQuoteArmed + shared transforms)

`toggleQuote` now checks `RichTyping.isQuoteArmed(in:)` before arming an
empty document: a second tap disarms via `disarmedQuoteAttributes` (drops
the marker, zeroes indents, preserves inline formatting) through the same
undo-aware `setTyping` path with the pending-list displacement, mirroring
the list/checklist toggle. The arm constants moved into
`RichTyping.quoteIndent` and the trailing-empty-paragraph path now uses the
same `armedQuoteAttributes`/`disarmedQuoteAttributes` transforms, so both
paths arm/disarm identically.
Regression: `Tests/TaskovskyCoreTests/QuoteToggleTests.swift` (7 tests):
decision policy (plain/list-armed/quote-armed), transform inline-format
preservation, empty-doc on→off→type-is-plain with undo (armed) / redo
(plain) and persistence of plainness, off→on re-arm, trailing-paragraph
comparison, and quote-displaces-pending-list transitions — all driven
against real `NSTextView` typing state in production order with an
explicitly-grouped `UndoManager` (event grouping disabled: no runloop in
tests would otherwise coalesce the two taps).
Limit: the controller itself lives in the app target and cannot be imported
by the test bundle, so the one-line wiring (check-then-disarm vs arm) is
covered by shared-policy tests + review, not by a controller callback test.
The live on→off→type check passed; native Undo/Redo and quote/list switching
were not verified live. See the final live-check record below.

## Integration follow-up (recorded 2026-11-08, same session)

Parent review of the first-pass nominal patch found seven integration gaps.
All are fixed below; the five original resolutions above stand except where
noted. Validation rerun: `swift test --disable-sandbox
--manifest-cache local` → 400 XCTest + 34 Swift Testing = 434 tests,
0 failures, 0 errors, 0 warnings (`build/verification/swift-test.log`);
`./scripts/build-app.sh` exit 0 and `codesign --verify --deep --strict
build/Taskovsky.app` passes (`build/verification/build-app.log`).
Regressions were observed failing before each fix where practical (details
per item); pre-existing tests that encoded artificial setups were rebuilt
through production instead of weakened.

### G1. Nominal chaining only where needed — fixed (nextDueDateStep)

New shared engine entry `CustomRecurrence.nextDueDateStep(after:nominalBase:calendar:occurrenceIndex:)`,
used by the store (`nextCustomStep`), `occurrences`, `isOccurrence`, and
`remainingOccurrences`, so engine, completion, and previews cannot diverge.
Shapes needing nominal chaining (monthly/yearly + skipWeekends, due-date
anchor, non-explicit dates) advance from the nominal and roll each step;
every other shape steps from the displayed due exactly as `nextOccurrence`
does — explicit dates verbatim even with the checkbox on
(`weekendAdjusted` returns stored instants untouched; `chainsNominally`
now excludes explicit dates), daily/weekly with historical adjusted
chaining. One pre-existing `RecurrenceIntegrationTests` max-count test was
rebuilt through production (create → complete → complete →
no-successor) instead of hand-setting index 2 alongside a new rule, which
now (correctly) restarts the series.
Regression: `NominalSeriesIntegrationTests` explicit-verbatim engine +
store tests and the daily/weekly engine↔store parity test.

### G2. Adjusted date validated against the custom end — fixed

`weekendAdjusted` now returns nil when the roll pushes past the inclusive
custom `endDate`, so every chaining site (`nextDueDateStep`, `occurrences`,
`isOccurrence`, counted/uncounted `remainingOccurrences`) excludes the
rolled escape (May 31 nominal → June 1 display with end May 31 yields no
next occurrence). `nextOccurrence` itself already validated the rolled date
(pinned by test). A nil step ends the series and never falls back to
another step (pinned: ended series spawns nothing, `nextRecurrenceDate`
stays nil).
Regression: end-capped engine/preview/membership/store assertions in
`NominalSeriesIntegrationTests`, including counted-preview exclusion and
the never-resurrect store case.

### G3. Forward progress vs displayed due — fixed (collision loop)

`nextDueDateStep` requires the rolled result strictly after the displayed
due: a roll collision ([1,31] monthly + skipWeekends: Jan 31 and Feb 1
both roll to Feb 2) advances the nominal cursor to a genuinely later
occurrence (Mar 2, nominal Feb 28) instead of duplicating Feb 2 or
terminating. `remainingOccurrences` drops through an already-displayed
current due when starting from a stale nominal, so previews match
completion.
Regression: engine collision test + multi-completion store test (no
duplicate due, preview agrees) in `NominalSeriesIntegrationTests`.

### G4. Store-boundary normalization — fixed (normalizeSeriesPosition)

New shared `TaskItem.normalizeSeriesPosition(old:)`, called by
`TaskStore.updateTask` after schedule coherence settles the final due:
rule changes (add/clear/replace, including via store/template) restart the
series; a changed due under an unchanged rule rebases the nominal to the
new due with the count preserved, so completion advances forward from the
manually chosen occurrence (time-only, zone-translated, and
duration-derived due changes all flow through the same comparison);
anything else — including a no-op save of a rolled task — preserves the
stored nominal. The editor's preview/membership now use the same staged
policy via `stagedNominal(draftDue:draftRule:task:)` (new, tested) instead
of the raw stored nominal.
Regression: `NominalSeriesIntegrationTests` rebase (date/time/duration),
no-op preservation, clear/replace restart, and `stagedNominal` policy
tests. Pre-fix runs showed the stale nominal (May 31 surviving an Aug 1
move, rebasing nothing); post-fix the move rebases to Aug 1 and completion
yields Aug 31. The collision loop additionally guarantees no backwards
spawn even for un-normalized states.

### G5. Per-member zones in subtree clone — fixed

`cloneSubtreeIntoSuccessor` computes all-day due/reminder/window shifts in
the applicable member zone (own `timeZoneID`, else the root calendar)
while retaining the parent's calendar-day displacement; timed members keep
exact elapsed shifting. Pre-fix runs showed the reported defect (09:00 NY
reminder cloned as 10:00/08:00/19:00 wall times via the root UTC calendar).
Regression: `CloneReminderTests` mixed-zone spring-forward, fall-back, and
timed-elapsed tests through real completion/clone.

### G6. Sheet dismissal wiring — fixed

The custom sheet now passes `onDismiss: { repeatDraft.cancelCustom() }`,
so Cancel, swipe-down, and any other dismissal drops the staged seed
through the tested production path. After Done/Clear the staged value is
already nil, so the handler is a safe no-op; Clear Rule's explicit commit
semantics are unchanged. `RepeatDraft` + `cancelCustom` tests now exercise
the path the sheet actually calls.

### G7. Rich-test claims — fixed

`blockRange` clamps without any unguarded addition: out-of-range locations
(`NSNotFound`, negative, past-end) map to the nearest edge before
arithmetic, and the span is capped via `length - location` (no
underflow: location ≤ length). New `BlockRangeTests` cover
`NSNotFound`/oversized/negative bounds with no trapping. `QuoteToggleTests`
wording now states explicitly that the tests mirror (not live-verify) the
controller wiring and that the parent exercises real toolbar taps.

### Remaining legacy ambiguity (unchanged)

Already-rolled records without a nominal still transition once from the
displayed due (`testLegacyRecordFallsBackToDueDate`); history cannot be
reconstructed.

### Preview-count follow-up (recorded 2026-11-08, same session)

Parent review found one remaining gap in `remainingOccurrences`: the
`base < current` early branch restarted an `occurrences` walk at the
nominal with index 1 and dropped old dates, resetting the remaining count
for a rolled current occurrence (max-2/index-2 returned [Jul 31] instead
of []; max-3 returned [Jul 31, Sep 30] instead of [Jul 31] — both
reproduced failing before the fix). The helper is now one bounded walk
for counted and uncounted previews alike, stepping from the actual
current display date, nominal, and index via the shared `nextDueDateStep`
(or the completion-anchor policy), so previews retain count, end,
explicit-date, and completion-anchor semantics and match completion.
The uncounted roll-collision preview (Feb 2 nominal Jan 31 → Mar 2, never
repeating Feb 2) is preserved. Regression:
`testCountedPreviewRespectsRemainingCountFromRolledCurrent` in
`NominalSeriesIntegrationTests.swift`.
Validation rerun: `swift test --disable-sandbox --manifest-cache local` →
401 XCTest + 34 Swift Testing = 435 tests, 0 failures, 0 errors, 0
warnings (`build/verification/swift-test.log`); `./scripts/build-app.sh`
exit 0 and `codesign --verify --deep --strict build/Taskovsky.app`
passes, 0 warnings (`build/verification/build-app.log`).

## Live verification (final build, 2026-11-08)

The parent checked the final build in a uniquely identified app,
`Taskovsky Review QA` (`org.taskovsky.qa.reviewfindings`), with a disposable
five-task workspace at `/private/tmp/TaskovskyReviewQA-20261108`. Its running
process's explicit `--workspace` and `--settings` paths and recognizable
fixture contents were verified before editing. No normal workspace was
used.

- **Cancel → outer OK → reopen:** the one-time task still showed
  “Does not repeat”; the weekly task still showed “Weekly on Monday,” even
  after changing the sheet-local unit to Day before Cancel. Saved JSON
  confirmed `recurrence: none` / `weekly`, respectively, with no custom rule.
- **Existing custom draft:** changing the interval and canceling left the
  outer draft at every 2 days. Explicit Done changed it to every 3 days;
  outer OK and reopening showed every 3 days. Clear Rule followed by outer
  OK and reopening showed “Does not repeat”; saved JSON had no custom rule.
- **Empty editor Quote:** focus the blank body, click Block Quote twice,
  and paste `Plain after Quote on-off`. The editor displayed unindented
  plain text. Saved JSON contained that exact body and no `richBody`, so
  the canceled quote did not persist or resurrect.

Native Undo produced no observable change through computer use. The native
Edit menu appeared disabled for Undo/Redo, and subsequent menu actions
returned stale-element errors. Native Undo/Redo, quote/list switching, and
the live paragraph-selection reproduction therefore remain **unverified
live**, rather than being counted as passes. Automated native `NSTextView`
tests cover selection boundaries and the shared Quote typing/Undo policies;
they do not instantiate the app controller. Reminder and cadence checks
were verified through the engine/store regressions, including actual
completion, cloning, and save/reload paths.
