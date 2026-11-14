# Mobile Calendar explicit 3 Day mode — November 14, 2026

Reference inventory C02 records an explicit **3 Day** mode. Taskovsky exposed only configurable Multi-Day (default five). This core shortcut selects the existing Multi-Day projection with count 3 and saves both mode and count through existing Calendar options. Paging uses existing count-based navigation. Custom Multi-Day and all other modes remain available; choosing 3 Day intentionally replaces that saved Multi-Day count with 3. Configure another count in View Options as before.

A failed count-changing shortcut keeps the prior view/count and reports the error rather than introducing a temporary count override that could hide later View Options changes. General mode selection retains its existing session fallback. No schema, new persistence mechanism or accessibility-layout polish.

This closes direct access to a three-day view, not reference mode order/labels, Week overview or exact grid geometry. Reference mode-switch/persistence behavior was not exercised; three visible days use Taskovsky's existing projection and navigation rules.

Acceptance: full suite/release/signature, independent review, actual 3-column/paging/relaunch/return-to-Week native checks and failed-save retained-view regression; inspect screenshot and exact CI before merge. Original worktrees and user QA fixtures preserved.

## Verification receipt
- Full 826 XCTest + 38 Swift Testing passed, release build and strict signature verification passed.
- Three native Simulator tests passed: explicit three columns, three-day paging, relaunch persistence and return to Week; failed shortcut keeps the prior Week view; existing preference failure retains its draft.
- Actual screenshot inspected: `/private/tmp/TaskovskyThreeDayScreens/A372CECD-260A-474E-9FC5-5DA810E7259D.png`; three headers are visible. Existing centered/narrow grid, large surrounding chrome and Multi-Day caption are unchanged, so this is direct mode access rather than visual parity.
- Native result: `/private/tmp/TaskovskyThreeDayNative.xcresult`. Owned Simulator shut down; original user QA data untouched.
- Independent review caught and eliminated a proposed sticky session-count override before testing. Final exact-head hosted CI remains required before merge.
