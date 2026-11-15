# Day Calendar seven-date selector

Live TickTick geometry audit `01a1dc8e-cea4-7400-af19-5aa5b2512343` observed a seven-date selector above Day's single timed column. Taskovsky previously exposed only its focused date header. This candidate replaces that header in-place with the existing Calendar week containing the focus date, using current calendar week-start/timezone rules. Selecting another date reuses existing Day focus selection; no task scheduling/persistence changes. Previous/Next and Today retain existing behavior. Week and other modes retain their prior headers.

The reference strip's exact selection and week-start/paging behavior was not exercised; this is a bounded functional counterpart, not calibrated geometry or complete Day-header parity. Existing ruler/chrome and current calendar settings are preserved. No speculative Date/Duration conversion change: live tab switching seeded time in TickTick but retention/save semantics were not established.

Acceptance: full tests/release/signature, independent review, native seven-date/selection/week-boundary/Today checks, switch back to Week, Day drag/Undo/resize and actual screenshot; exact-head CI before merge. Preserve original worktrees/fixtures and defer accessibility-layout polish.

## Verification receipt
Full 826 XCTest +38 Swift Testing, release/strict signature, independent review/rereview passed. Four final native tests passed: seven-date selection/week-boundary/Today/Week restoration, 3Day/Day viewport navigation, Day Arrange drag/Undo, and timed resize. Actual screenshot `/private/tmp/TaskovskyDayStripFinalScreens/2B8063AA-E834-4854-B3F4-B7D2A5051D79.png` inspected; seven dates and selected state fit. Result `/private/tmp/TaskovskyDayStripFinal.xcresult`. Owned Simulator shut down, original user QA/worktrees untouched.

Initial native tests caught parent accessibility identifier propagation replacing individual date IDs. Removed the parent ID and reran all four tests; no failure waived. New weekday/spoken labels use the supplied calendar/timezone. Exact-head CI remains required before merge. Reference exact strip interaction, geometry and broad timezone/locale matrix remain open.
