# Calendar narrow-card verification
## Narrow timed Calendar checkbox — November 12, 2026

[CAL-MAC-NARROW-01](../changes/calendar-narrow-card-affordance-2026-11-12.md) records one live TickTick Week/Modern observation: boxes visible around 37–38 screenshot pixels and hidden around 21–22 despite a fitting short title; after widening, Calendar re-entry was needed to restore them. Point scale, exact threshold, hover and Option remain unverified. This is reference observation only.

Draft Taskovsky code uses an explicit typography/content-width budget, removes the checkbox and its gap only on timed cards, and keeps Option, accessibility/context completion and drag/resize geometry. Eight pure test cases are added. Swift tests, exact-head CI and native Taskovsky acceptance are pending; no full parity row is closed. Source review and `git diff --check` are not runtime verification.
