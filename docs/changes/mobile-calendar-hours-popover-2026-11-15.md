# Calendar hour controls on demand

Live geometry audit `01a1dc8e-cea4-7400-af19-5aa5b2512343` showed TickTick day labels directly beneath its toolbar; Taskovsky had a separate permanent Early/Late hours row above the grid. This bounded slice removes that row and provides a named clock button in the existing period navigation row, opening the same early/late expansion controls with counts and Done dismissal.

The popover is a Taskovsky preservation choice, not an observed TickTick hour-control design. Session-only expansion, count projection, cutoff behavior, reset on relaunch/away from hourly modes and schedule behavior remain unchanged. No settings/persistence change. Existing workspace provenance and other header chrome remain; no full reference geometry claim or accessibility-layout polish.

Acceptance: full suite/release/signature, independent review, native counts/expand/collapse/reopen/relaunch/dismissal, hour drag and Week/3Day navigation, actual collapsed/popover screenshots and exact-head CI. Preserve original fixtures/worktrees.

## Verification receipt
Full 826 XCTest +38 Swift Testing, release/strict signature and independent review passed. Four actual native Simulator tests passed: folded-hour counts/expand/collapse/reopen/relaunch, hour drag, three-day extent/Day navigation and Week swipe. Actual collapsed view and popover screenshots inspected: `/private/tmp/TaskovskyCalendarHoursScreens/E0C36739-AACD-461C-AA05-17B19BFE18E5.png` and `35AECF48-924E-41C2-BE7B-BD7F09CF7789.png`. Controls fit at tested ordinary text size; grid gains the former persistent row space. Native result `/private/tmp/TaskovskyCalendarHoursNative.xcresult`. Original user QA/worktrees preserved. Exact final-head CI remains required; no full header/pixel parity claim.

Additional test-only backdrop check passed in `/private/tmp/TaskovskyCalendarHoursDismiss.xcresult`: outside-gutter tap dismissed without capture or schedule action; reopening retained state, followed by normal expansion/reset flow. Independent final test review passed. Owned Simulator shut down after test.
