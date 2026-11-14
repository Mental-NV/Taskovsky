# Mobile schedule Date month grid — November 14, 2026

Live reference inventory D07 shows a visible month grid in Date scheduling, with nested Time/Reminder/Repeat controls. This core presentation slice replaces Taskovsky's compact single-date picker with the system graphical month picker for non-Duration schedules. It retains the same `due`/`edit.chooseDay` binding, calendar/time zone, shortcut actions, outer Cancel/Done and existing duration/time/reminder/repeat logic. Duration schedules retain the prior compact Date and Start/End presentation.

This is partial parity: native system grid styling, existing form/toolbars and toggles remain. Date/Duration tabs and reference popup styling are not implemented here. No new persistence behavior, notification permission, integration or accessibility-layout polish. Preserve existing support; target core ordinary light-theme scheduling.

Acceptance gates: full Swift suite, release/signature, independent review; native visible-grid selection, outer Cancel, save/reopen/relaunch, existing shortcuts and nested/Duration cancellation; inspect actual Simulator screenshots and exact hosted CI before merge. Original worktrees and user device data remain untouched. No calibrated pixel or physical-device parity claim.


## Acceptance receipt

Production source d2aa50f: 826 XCTest +38 Swift Testing, release/strict signature and independent review passed. Five owned native Simulator tests passed: actual month-grid day selection with outer Cancel/save/relaunch; shortcut save/relaunch; nested custom-repeat and schedule-removal Cancel; interrupted Time/skip/Undo; timed Duration end-reminder save/relaunch and removal back to Date. Initial result `/private/tmp/TaskovskyScheduleGridNative.xcresult`, additional transitions `/private/tmp/TaskovskyScheduleGridTransitions.xcresult`. Inspected actual ordinary grid screenshot: no observed overlap and Time/Duration/removal controls remain reachable. Existing user device/data were untouched.

Actual neutral screenshot `/private/tmp/TaskovskyScheduleGridScreens/1D45E12C-FDBB-4EF5-9458-EE0F365F36DA.png` is a local evidence locator, not portable repository asset. Exact source CI43649372148 passed; receipt-only final head still requires its own hosted checks. No full scheduling/pixel-parity claim. Accessibility-specific layout polish remains deferred per user.
