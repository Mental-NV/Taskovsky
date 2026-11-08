# PR #2 Calendar review findings

Review date: 2026-11-08  
Pull request: [Mental-NV/Taskovsky #2](https://github.com/Mental-NV/Taskovsky/pull/2)  
Reviewed head: [`79388c42d826859ebda643c6f2400c9fc672e060`](https://github.com/Mental-NV/Taskovsky/commit/79388c42d826859ebda643c6f2400c9fc672e060) (`codex/local-calendar`)  
Exact base / merge base: [`30045bac5355b793a8c155b87ffe58584cb29fb8`](https://github.com/Mental-NV/Taskovsky/commit/30045bac5355b793a8c155b87ffe58584cb29fb8) (`main`)

## Summary

The original review identified four actionable P2 findings in the new Calendar implementation. **All four are now addressed; implementation and verification details are recorded below under Resolutions.** P2 means an ordinary correctness defect that should be fixed. The first two silently change stored scheduling information during operations that should preserve it.

This is a separate review of PR #2, not a reopening of the five earlier findings in `docs/code-review-findings-2026-11-08.md`. The PR also changes recurrence and rich-editor behavior; the findings below concern newly added Calendar paths. The original report changed no application code or tests; the follow-up implementation is recorded under Resolutions.

## 1. [P2] Preserve the existing schedule when opening and saving Schedule…

**Primary location:** [TaskCalendarWorkspace.swift:219–224](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/Taskovsky/TaskCalendarWorkspace.swift#L219-L224)  
**Save path:** [TaskCalendarWorkspace.swift:226–228](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/Taskovsky/TaskCalendarWorkspace.swift#L226-L228)

For an existing timed point task, `edit(_:)` uses its due date as the draft start and invents an end 30 minutes later. Saving always applies `.setRange`, which makes that invented end the stored due date. Opening Schedule… and saving without changing anything therefore moves a 10:00 deadline to 10:30 and adds a duration. The same draft initializer clamps an existing window shorter than 15 minutes to 15 minutes, so a no-edit save also changes a legitimate 10:00–10:05 task into 10:00–10:15.

**Reproduction to run on macOS:**

1. Create a timed task due at 10:00 with no scheduled duration.
2. In Calendar, use the card's context menu → Schedule….
3. Change nothing and click Save.
4. Reopen the task and inspect its due date, duration, and reminders.
5. Repeat with a task whose existing duration is 10:00–10:05.

**Expected:** An unchanged save preserves the original schedule, including whether the task is a point task. Existing precise durations are not enlarged just by opening the editor.

**Source-derived actual:** The point becomes 10:00–10:30 with a 10:30 due date; the five-minute window becomes 10:00–10:15. The scheduling path also moves/recomputes reminders, and a changed due date can rebase recurrence position, so this is not merely a display issue.

**Suggested fix:** Preserve the original schedule shape in the draft, support retaining a point task, and seed existing valid endpoints without a minimum-duration clamp. If the editor intentionally offers conversion to a duration, make it an explicit change. A no-edit save should be a no-op rather than committing a default intended for a new task.

**Regression coverage:**

- Timed point → open → unchanged Save: full `CalendarScheduleSnapshot` remains identical.
- Five-minute and zero-length valid windows → unchanged Save: endpoints remain identical.
- Cover a manually reminded repeating point task and ensure its reminders and nominal position do not change.
- Retain separate tests for intentional point-to-range conversion and brand-new task defaults.

## 2. [P2] Keep the exact duration when moving an existing short timed task

**Location:** [CalendarScheduling.swift:43–44](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/TaskovskyCore/CalendarScheduling.swift#L43-L44)

The timed `.move` path computes the new end using `max(900, oldWindow.end.timeIntervalSince(oldWindow.start))`. This expands every existing window shorter than 15 minutes instead of preserving its elapsed duration. Such windows are valid in the existing model: [TaskDurationRange.validated](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/TaskovskyCore/CustomRecurrence.swift#L946-L959) accepts timed `end >= start`, and the precise Calendar editor can save a five-minute range. The documented Calendar policy explicitly says existing timed windows preserve elapsed duration.

**Reproduction to run:**

1. Use a valid timed task scheduled for 10:00–10:05.
2. Drag it to 14:00 on another day, or invoke `scheduleOnCalendar` with `.move(start: target14, allDay: false)`.
3. Inspect the saved range and due date.

**Expected:** 14:00–14:05, with due date 14:05.

**Source-derived actual:** 14:00–14:15, with due date 14:15. Reminder shifts are consequently calculated using the enlarged window's due time. A Month-view drop also reaches the same mutation path, so even changing only the day can stretch the task.

**Suggested fix:** Apply the minimum to new blocks or explicit resize operations, not to an already validated duration during a move. Preserve its exact elapsed seconds. The 15-minute minimum visual hit area can remain independent of stored duration.

**Regression coverage:** Move 0-, 5-, and 10-minute existing windows through the store path, assert exact elapsed duration and reminder offsets, and verify Undo and reload. Keep a longer-duration case and a no-duration point case as controls.

## 3. [P2] Reset checklist completion state in future recurrence previews

**Location:** [TaskCalendarProjection.swift:40–45](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/TaskovskyCore/TaskCalendarProjection.swift#L40-L45)  
**Actual successor behavior:** [TaskStore.swift:529](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/TaskovskyCore/TaskStore.swift#L529)

Every projected occurrence reads `original.checklist` and copies each item's current `isCompleted` state. Real recurrence successors instead create fresh unchecked checklist items. If an item in today's still-open repeating task is already checked, Calendar incorrectly shows it as checked in all future cycles. With Show Completed disabled, that item disappears from every future preview altogether, even though it will exist unchecked in the generated successor.

**Reproduction to run:**

1. Create an open daily repeating task with two checklist items.
2. Complete one checklist item without completing the parent task.
3. Enable Show Checklist Items and Show All Repeat Cycles.
4. Inspect tomorrow's preview with Show Completed first enabled, then disabled.
5. Complete the current parent task and compare the real successor's checklist to the earlier preview.

**Expected:** The current occurrence retains its real checklist state; every future cycle previews fresh unchecked checklist items, matching the recurrence successor.

**Source-derived actual:** Future rows copy today's checked state, or omit the checked item when completed items are hidden. This also understates item counts in the mini-calendar and Year heatmap when the item is hidden.

**Suggested fix:** Determine effective checklist completion per occurrence before applying the visibility filter: keep actual state for the current entry, use unchecked state for projected entries. Do not mutate the original task or persist preview records.

**Regression coverage:** An open daily task with one checked and one unchecked checklist item should produce both unchecked child entries in the next projected cycle under either Show Completed setting. Assert that current-cycle filtering remains unchanged and compare the preview with the actual successor created by completion.

## 4. [P2] Classify all-day Arrange tasks using their displayed civil date

**Location:** [TaskCalendarProjection.swift:114–118](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/TaskovskyCore/TaskCalendarProjection.swift#L114-L118)  
**Calendar's existing civil-date conversion:** [TaskCalendarProjection.swift:95–98](https://github.com/Mental-NV/Taskovsky/blob/79388c42d826859ebda643c6f2400c9fc672e060/Sources/TaskovskyCore/TaskCalendarProjection.swift#L95-L98)

Arrange's Include overdue filter compares every stored due instant directly with midnight in the display calendar. All-day tasks, however, are displayed by their civil date in the task's own time zone. For example, an all-day task due November 8 in Asia/Tokyo is stored as November 7 at 15:00 UTC. On November 8 in a UTC display, the main Calendar correctly shows it on today, but Arrange includes it as overdue because its raw instant precedes UTC midnight.

**Reproduction to run:**

1. Use a Gregorian UTC display calendar and `now = 2026-11-08 12:00 UTC`.
2. Create an open all-day task with `timeZoneID = "Asia/Tokyo"` and due date `2026-11-08 00:00 Asia/Tokyo`.
3. Verify Calendar projects it onto November 8.
4. Call `arrangementTasks(..., overdue: true, now: now, calendar: utcCalendar)`, or open Arrange with Include overdue enabled.

**Expected:** This task is not overdue: its visible civil due date is today.

**Source-derived actual:** It is returned as overdue. The two Calendar surfaces disagree, making already-scheduled current-day work appear in the rescheduling queue.

**Suggested fix:** For all-day schedules, convert the due date from the task calendar to the display calendar using the same civil-date policy as projection before comparing days. Keep timed-task handling separate so absolute timed instants are not floated.

**Regression coverage:** Test yesterday/today/tomorrow all-day dates with task and display zones on opposite sides of UTC, including Asia/Tokyo → UTC and Pacific/Auckland → America/Los_Angeles. Today's and future visible dates must not enter the overdue queue; genuinely earlier civil dates must. Include an all-day duration whose due date is its inclusive end.

## Review scope and verification

- Reviewed the PR's 30-file change set against its exact base. GitHub comparison confirmed the base above is also the merge base, with one code commit ahead and zero behind at review time.
- Examined the new Calendar views, panels, scheduling mutations, projection, options, and store integration; the accompanying recurrence, reminder-cloning, rich-editor changes; their relevant tests, existing model contracts, and documented local policies.
- Materialized 86 source/test/document files from the reviewed commit and verified their bytes against GitHub blob SHAs. No repository `AGENTS.md` appeared in that commit's recursive tree.
- Ran local Python arithmetic/control-flow probes for the four findings. They confirmed the timestamp/clamping and checklist-filter counterexamples from the source expressions. **These probes model the expressions; they do not execute Swift, Foundation, or the native UI.**
- Attempted the documented `swift test --disable-sandbox` command. It could not start because `swift` is not installed in the available Linux environment. No Swift test pass, macOS app build, code-signing check, or native interaction check is claimed by this review.
- The PR author's 453 passing tests, signed release build, and isolated UI checks are prior author-reported evidence, not independently rerun results. GitHub returned no PR-triggered workflow runs or combined commit-status entries for the reviewed head.
- The reproduction instructions above are source-derived scenarios to run on macOS. The existing Calendar tests cover longer moves, basic checklist visibility, and several timezone cases, but do not cover these counterexamples.
- Before publication, the PR head and base were rechecked. The report-only commit is based directly on the reviewed head and its branch update uses an expected-head check to avoid overwriting concurrent work.

## Handoff for fixes

Address the four findings independently, add the focused regression cases, and run the full documented Swift suite on macOS. Exercise unchanged Schedule saves, short-window drag moves, future checklist display with both visibility settings, and cross-zone Arrange behavior in an isolated workspace. Recheck persistence and Undo after fixes.

This report does not request changes to deliberately deferred external calendar integrations, native Cmd-Z/redo, gesture anchoring parity, or other documented scope exclusions. No code fixes, merge, or deployment were performed as part of this review.


## Resolutions — 8 November 2026

All four findings were confirmed against the macOS implementation. The source-derived counterexamples were valid; no finding was dismissed. The original review above remains as provenance for the defects.

| Finding | Resolution | Regression evidence |
| --- | --- | --- |
| 1. Unchanged Schedule… save | Added `CalendarScheduleDraft`, used directly by the production editor, to retain point/range shape and exact endpoints. An unchanged draft emits no operation. Existing point tasks show one Date field with Duration off; enabling Duration explicitly seeds a new range. Existing zero-length ranges remain valid. Added `.setPoint` for intentional point edits, plus a store-level no-op guard before reminder/recurrence/timestamp updates. | `CalendarReviewRegressionTests`: unchanged manually reminded repeating point (full snapshot, timestamp and file bytes), unchanged 0/5/10-minute ranges, floating all-day point, point date edits with reminders/Undo, explicit conversion and new/undated defaults. A legacy automatic-reminder no-op test verifies its policy metadata remains unchanged. |
| 2. Moving short windows | Removed the 15-minute clamp from existing timed-window moves. Exact elapsed seconds survive, including zero and fractional durations; minimum defaults and explicit resize policy remain separate from movement and visual hit area. Captions use the actual due endpoint for zero-length ranges. Narrowed the resize hit area to the visible handle after a live drag on a short title was interpreted as resize. | Store-path move cases cover 0, 5, 10 and 90 minutes, plus fractional seconds, with exact due/reminder offsets, reload and Undo. A point move remains a point. |
| 3. Future checklist state | Compute effective checklist completion before filtering: current entries keep their actual state, projected entries use unchecked state. Projection remains pure and creates no records. | With Show Completed on/off, both future child rows are present and unchecked; current-cycle filtering remains unchanged. Compared their state with the real successor produced by completion, and asserted that projection did not mutate workspace data. |
| 4. Cross-zone Arrange | All-day overdue checks map the task's inclusive civil due/end date into the display calendar before comparison. Timed tasks retain absolute-instant behavior and the existing prior-day cutoff. | Yesterday/today/tomorrow points and all-day windows tested for Asia/Tokyo → UTC and Pacific/Auckland → America/Los_Angeles, including inclusive range ends and timed controls. |

### Verification after fixes

- **464 tests passed**: 430 XCTest and 34 Swift Testing, including 11 new review regression tests. `swift test --disable-sandbox --manifest-cache local` compiled the production UI and ran the full suite after the final source changes. Logs are under ignored `build/verification/calendar/review-*.log`.
- `./scripts/build-app.sh` succeeded and the signed release passed `codesign --verify --deep --strict build/Taskovsky.app`.
- Live Computer Use used a separately identified debug app from the same source with explicit `/private/tmp/TaskovskyCalendarReviewQA-1108/workspace.json` and `settings.json`. No real Taskovsky files or TickTick items were edited.
- In Agenda, opened and saved the point, five-minute and zero-length editors unchanged. Their fields retained 10:00, 11:00–11:05 and 12:00–12:00 respectively; Save reported Schedule unchanged. The workspace stayed **byte-identical** after all three saves.
- Enabled Duration deliberately on the point, observed 10:00–10:30, saved it, and used Undo to restore the point at 10:00 and its original reminder.
- With checklist previews enabled, tomorrow showed both future items. After hiding completed items, tomorrow still showed both, while today's checked item disappeared and its unchecked item stayed visible.
- Arrange's Include overdue showed only the Tokyo-dated yesterday task; the Tokyo today task stayed in today's all-day strip and today/tomorrow were absent from the queue. This live check used the host's Europe/Moscow display; UTC and Los Angeles comparisons are automated Foundation tests.
- A native short-block drag was first interpreted as resize and undone. After narrowing the handle hit area, subsequent native move attempts did not yield a confirmed drop through Computer Use. No successful live short-window move is claimed; exact movement, reminders, persistence and Undo are verified through the production store tests. The QA point/short/zero schedules and reminders matched their original fixtures after cleanup. Closed the QA app and confirmed it left the running-app inventory.

External integrations and the other deliberately deferred parity items remain outside scope. No native Cmd-Z or comprehensive gesture-parity claim is added by these fixes.
