# Mobile Calendar header hierarchy — November 14, 2026

## Observed scope

Live inventory C01/C02 puts the mode chooser at Calendar's leading edge; C04 starts overflow with Filter View Range, View Options and Arrange Tasks. Taskovsky used the workspace drawer at the leading edge, a trailing mode chooser and separate filter icon. This slice moves existing controls into the observed hierarchy. Tasks/Search retain their drawer. Existing month Jump to Date, modes, preference transactions and calendar scheduling remain unchanged.

This is partial structural parity only. The reference trailing calendar overview (C03), existing Day/Week/Month/Year/Agenda/Multi-Day/Multi-Week names and ordering versus reference List/Year/Month/Week/3 Day/Day, month-label behavior, overview geometry, Calendar arrangement side panel and external actions remain outside this slice. Do not add inert Subscription/Share/Print entries or imply existing Jump to Date is the reference overview. No grid/data/persistence behavior changes.

## Acceptance

Full tests, release/signature, independent review, native header/menu geometry, filter Cancel/save/reopen/reset and distant-date jump are required. Inspect actual light-theme screenshots. Original worktrees and user QA device remain untouched. Exact hosted CI must pass before merge; no calibrated pixel or physical-device parity claim.

### Native acceptance receipt

Source f3a9b06: 826 XCTest +38 Swift Testing, release/strict signature and independent review passed. Three owned iPhone Simulator tests passed: header/control geometry and overflow sequence; filter Cancel/save/relaunch/All reset; distant-date jump and mode retention. Actual light-theme header/menu screenshots were inspected with no observed overlap. Result `/private/tmp/TaskovskyCalendarHeaderNative.xcresult`; header image `/private/tmp/TaskovskyCalendarHeaderScreens/D60994DF-11F0-452C-B5A7-35B9BCC69DC0.png`, menu image `F05A9F9E-C60D-4BB9-BFA2-26F93418A8A1.png` in the same directory. These are local neutral QA locators, not portable assets. Owned Simulator shut down, user QA untouched. Hosted exact-head CI remains required; no complete or pixel-perfect Calendar claim.
