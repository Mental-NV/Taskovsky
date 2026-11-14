# Mobile Tasks row density — November 14, 2026

## Evidence and bounded change

The live mobile parity plan records compact Today/List rows with trailing dates and smaller metadata. Taskovsky rendered dates below the title even at standard text sizes. This slice moves the existing date caption to the trailing part of the ordinary list title row, keeps two title lines and a 44-point minimum title target, and preserves nested rows, Search and accessibility stacked layout. Existing countdown has its own unchanged target. No date format, timezone, sorting, task data, hierarchy, completion or persistence rules change.

The button accessibility value now includes the same existing date caption in ordinary lists as well as date-grouped lists. No new reference inspection or personal screenshot is needed. Exact reference metrics, title truncation policy and full VoiceOver traversal are unverified; do not claim pixel-perfect parity. Normal/large-text native screenshots and gesture tests are acceptance gates.

## Verification

Full 826 XCTest + 38 Swift Testing suite, release build/strict signature and independent source review passed. Initial three native tests passed on the earlier candidate. Review then restricted compact layout to depth-zero ordinary rows, preserving nested/Search/accessibility minimums and stacked dates; a final four-test native run including long titles and nested disclosure is required before acceptance. Original worktrees and user QA device are untouched. Hosted exact-head CI remains required before merge.
