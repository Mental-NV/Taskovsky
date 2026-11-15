# D14 Repeat Type menu

## Element and behavior contract

Observed reference labels are By Due Dates, By Completion Date and By Specific Dates in an anchored Repeat Type menu with current check. The mobile editor replaces separate Pattern and Anchor pickers with that combined menu.

| Element | Placement / wording | Behavior |
| --- | --- | --- |
| Repeat Type | First Custom Repeat row, current value trailing | Anchored menu opens without changing the draft |
| By Due Dates | First choice, check when active | Selects existing cadence pattern and dueDate anchor |
| By Completion Date | Second choice, check when active | Selects existing cadence pattern and completionDate anchor |
| By Specific Dates | Third choice, check when active | Selects existing explicit-date pattern without changing cadence fields |
| Existing Frequency/advanced editors | Below cadence selection | Unchanged interval, unit, weekday, monthly/yearly patterns and limits |
| Existing occurrence dates/Add date | Below specific-date selection | Existing date editors, addition and deletion remain available |
| Cancel/Done | Existing toolbar | Nested Cancel discards changes, Done stages valid candidate; outer Cancel still discards all edits |

No new recurrence defaults or conversions. Inactive cadence fields and date list stay in local draft state across menu toggles. Saving retains existing candidate projection: selecting cadence clears specificDates in the saved candidate; selecting dates retains the explicit list. This is not a promise to persist both inactive patterns. Reference transition semantics remain unverified; the implementation preserves Taskovsky's existing behavior rather than guessing.

Due-date and completion-date anchoring remain distinct real engine semantics, not label aliases. Domain regression saves both via TaskScheduleEdit and verifies late completion schedules different next dates. No changed series/reset warning, preview, limits or exact-interval validation policy.

## Verification

Full852 XCTest+38 Swift tests, release and iPhone build-for-testing passed. Independent final source/test review clean at source5d5af24. Initial native5 ran: four cases passed (weekly/monthly regression, actual completion-menu save/relaunch with backdrop/nested/outer Cancel, existing Cancel regression); specificDates comparison failed because the platform DatePicker exposed empty AX values. Actual bound date accessibility values were added and independently reviewed. Two focused rerun launches were blocked by Simulator runner Busy/preflight before any test. A supported explicit boot of the same owned Simulator with nonparallel test launch then passed the focused specificDates test on final sourceed2e9f0: nonempty/distinct actual date values, toggling, save and relaunch. All five distinct cases are verified across the initial four passes and final focused pass. Final source compiled successfully in that run, and the AX fix was independently reviewed. Exact-head hosted CI remains pending. No pixel-perfect acceptance claim. Existing style/spacing and unobserved source transitions remain open.

[Neutral menu screenshot](../assets/mobile-parity/2026-11-15/d14-repeat-type.png) was captured in the passing menu case at source5d5af24 and pixel-inspected. Later change only exposes existing specific-date values to accessibility, without altering the menu or date logic. No personal TickTick content.
