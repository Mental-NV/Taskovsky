# Mobile Tasks row density — November 14, 2026

## Evidence and bounded change

The live mobile parity plan records compact Today/List rows with trailing dates and smaller metadata. Taskovsky rendered dates below the title even at standard text sizes. This slice moves the existing date caption to the trailing part of the ordinary list title row, keeps two title lines and a 44-point minimum title target, and preserves nested rows, Search and accessibility stacked layout. Existing countdown has its own unchanged target. No date format, timezone, sorting, task data, hierarchy, completion or persistence rules change.

The button accessibility value now includes the same existing date caption in ordinary lists as well as date-grouped lists. No new reference inspection or personal screenshot is needed. Exact reference metrics, title truncation policy and full VoiceOver traversal are unverified; do not claim pixel-perfect parity. Normal/large-text native screenshots and gesture tests are acceptance gates.

## Verification

Full 826 XCTest + 38 Swift Testing suite, release build/strict signature and independent source review passed. Initial three native tests passed on the earlier candidate. Review then restricted compact layout to depth-zero ordinary rows, preserving nested/Search/accessibility minimums and stacked dates; the final four-test native run passed on production source f66ad42, including long titles, nested disclosure, accessibility dates and swipe actions. Actual normal/long-title screenshots show retained trailing dates without overlap; nested rows retain existing presentation. At largest accessibility size dates remain stacked and reachable, while existing two-line title truncation and oversized rich/grip icons remain; this slice does not resolve those pre-existing gaps. Actual VoiceOver invocation and calibrated reference geometry are unverified. Original worktrees and user QA device are untouched. Hosted exact-head CI remains required before merge.


Native result: `/private/tmp/TaskovskyListRowsFinalCorrect.xcresult`; captured images in `/private/tmp/TaskovskyListRowsScreens/`: normal `D7364884-D5B3-4B23-A40C-406C92254137.png`, long title `E2DDFBB9-DE0C-489A-87C3-CA268F84A749.png`, accessibility `7CE13885-6D69-4980-9C51-3A6A96BB7D47.png`. These are local neutral QA evidence locators, not portable repository assets. A mistyped test target command failed before execution, then the corrected target ran all four tests successfully.
