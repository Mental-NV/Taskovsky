# iPhone Day and Multi-Day viewport fill

Live read-only TickTick geometry observation, Codex turn `01a1dc8e-cea4-7400-af19-5aa5b2512343`, found Week/3 Day/Day fill the available width after the time gutter. Captured gutter/grid/right-inset estimates were 13%/84%/3%, not calibrated points or acceptance constants. Calendar Week/date and starting Today tab were restored; no task changes.

Taskovsky's actual three-day screenshot used fixed 64pt columns, covering roughly half the viewport and leaving blank sides. Day used fixed 300pt. This candidate sizes Day/Multi-Day columns from available viewport after existing timezone rulers, retaining existing 300pt Day/64pt Multi-Day minimums so narrow layouts or extra rulers still scroll. Week sizing and Week-only swipe recognizer remain unchanged. Existing header chrome, ruler widths, folded-hour controls and precise reference geometry are not addressed. No new scheduling/data behavior.

Acceptance: independent review, full tests/release/signature, native three-column extent/paging/persistence, Day navigation, Week swipe, Day Arrange drag/Undo and timed resize, actual screenshots and exact-head CI. Preserve original fixtures/worktrees. No accessibility-specific layout polish.

## Verification receipt
Full 826 XCTest + 38 Swift Testing, release build, strict signature and independent source/tests/docs review passed. Five native Simulator tests passed: three-column extent/equal pitch/Day navigation; three-day paging/relaunch; Week swipe and vertical scroll; Day Arrange drag/Undo; Day timed resize after panel dismissal.

Actual screenshots inspected: `/private/tmp/TaskovskyHourlyViewportScreens/0506CF44-39BE-49B2-AC3F-A6A742E868B6.png` (3 Day) and `5DA7B5A4-D9A8-44F9-9415-D0F213C790EA.png` (Day) show columns reaching trailing edge after gutter. Result `/private/tmp/TaskovskyHourlyViewportNative.xcresult`. Owned Simulator shut down; user QA untouched. Extra-zone and large day-count overflow were source-reviewed but not separately native-tested. Header chrome, fold controls, reference right inset and calibrated geometry remain open. Exact final-head CI required before merge.
