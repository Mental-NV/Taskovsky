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

## Compact checkbox pointer target — November 21, 2026

The first measured native run found that clicking the center of an open or completed compact task checkbox opened Schedule at 55 pt. Option revealed the checkbox at 49 pt, where its center also opened Schedule. The normal-height checkbox worked at 55 pt. The top resize target overlapped the task checkbox in the failing layout.

The local product fix is `f13f32dd51a67d780f7d7d9a5752f14f4c6b8aee`, based on PR #65 head `5b4c9aa`. It reserves the completion column when laying out the start-resize target, even while the checkbox is hidden. The start grip uses the top edge when the available width cannot fit both controls side by side.

- The same three physical pointer clicks completed or reopened the intended compact tasks without opening Schedule. A click also completed the compact task at the 51 pt visibility cutoff. At an 18.4 pt allocation, the exposed portion of the Option checkbox completed the task and a separate drag on the top edge resized its start.
- Real move, start-resize and end-resize drags passed at 49 and 55 pt. Each in-app Undo restored the original schedule. Clicking the relocated start grip opened Schedule. Escape closed it with the slot intact.
- Tested Week view in light appearance on arm64 macOS 27.0.1 (26A434), Europe/Moscow, in a signed QA copy with a fail-closed workspace/settings guard and in-app point measurements. The 17 synthetic records were restored and the original QA bundle was put back after the candidate quit.
- The product source passed 541 XCTest and 49 Swift Testing cases through `swift test --disable-sandbox`. The release from `./scripts/build-app.sh` passed strict signature verification. Dark appearance and reduced motion were outside this focused pointer check. The local follow-up still needs CI after publication.
