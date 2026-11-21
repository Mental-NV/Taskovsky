# Calendar narrow-card verification
## Narrow timed Calendar checkbox — November 12, 2026

[CAL-MAC-NARROW-01](../changes/calendar-narrow-card-affordance-2026-11-12.md) records one live TickTick Week/Modern observation: boxes visible around 37–38 screenshot pixels and hidden around 21–22 despite a fitting short title; after widening, Calendar re-entry was needed to restore them. Point scale, exact threshold, hover and Option remain unverified. This is reference observation only.

Draft Taskovsky code uses an explicit typography/content-width budget, removes the checkbox and its gap only on timed cards, and keeps Option, accessibility/context completion and drag/resize geometry. Eight pure test cases are added. Swift tests, exact-head CI and native Taskovsky acceptance are pending; no full parity row is closed. Source review and `git diff --check` are not runtime verification.

## Bounded Taskovsky native acceptance — November 21, 2026

Product UI source: `9830e104`, integrating main `522cff5`. Native verification used a separately signed QA-only build of that source with an explicit owned-fixture launch guard and isolated preferences. The exact unmodified product build separately passed 9 focused checks, 541 XCTest cases, 47 Swift Testing cases and the signed release build. [Hosted macOS and iPhone simulator CI for that product head](https://github.com/Mental-NV/Taskovsky/actions/runs/44902270504) passed.

- In Week view (Moscow), checked two pairs of overlapping owned timed tasks (compact and normal). Narrowing hid the completion checkbox; widening restored it. Titles clipped visually but retained full accessibility titles and Complete/Reopen actions. The all-day note kept its icon.
- Real pointer drag moved the compact timed task from 09:00 to 09:30. End resizing extended the normal timed task to 11:30. In-app Undo restored each change; neither interaction accidentally completed a task. The QA app was quit afterward. Stable QA, real data and system settings were not modified.
- Exact realized card widths were not measured. The session did not establish start-resize behavior, Option-only key delivery or the hold/release/window-focus-loss lifecycle, or projected-repeat behavior. No screenshots were exported.

A new TickTick 8.2.20 Calendar accessibility inspection could not revisit the prior owned timed fixtures. The November 12 reference remains directional (width-sensitive in that observed case), not a logical-point threshold. Widening restoration above is a Taskovsky observation, not a claim to reproduce TickTick's earlier sticky-hide result. This receipt is a bounded Taskovsky acceptance pass, not full visual or interaction parity. Keep the PR draft pending review of the outstanding native gates.
