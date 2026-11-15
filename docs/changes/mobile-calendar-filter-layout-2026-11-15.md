# C05 Calendar filter layout follow-up

Status: implemented and locally verified; hosted exact-head CI pending. User explicitly requested live near-pixel layout verification of PR #130 on November 15, 2026; this bounded request is an exception to the broader final-polish ordering.

## Live reference evidence

Taskovsky Codex inspected TickTick via iPhone Mirroring in turn `01a1df6f-e874-7172-b89d-4de434edac0a`. It expanded/collapsed source groups without saving selections, restored the previous expansion, dismissed using Escape, and returned to the original Today / Group & Sort surface. No personal reference screenshot or label is committed.

Values below are **approximate screenshot measurements**, normalized to a 390-point-wide viewport, not calibrated runtime geometry or exact font metrics:

| Element | Observed TickTick | PR130 baseline | Intended correction |
| --- | --- | --- | --- |
| Sheet/header | Sheet starts ~47 pt from phone top; title ~38 pt below sheet edge | Similar position, heavier title and pill Cancel/Done | Keep standard sheet/title placement; trailing blue circular check, compact explicit Cancel for Taskovsky staged semantics |
| Main surface | One white list, ~16 pt side inset | Separate rounded cards with ~35 pt gaps | One continuous white surface at 16 pt inset |
| Top content | ~70–80 pt below sheet edge | ~105 pt | 8 pt content padding below system navigation bar; verify actual screenshot |
| Rows | ~50 pt | Selection rows ~74 pt, disclosure rows ~51 pt | 50 pt minimum with text allowed to grow; existing accessibility preserved |
| Sources | Gray leading type icons | Only group icons, blue | Gray leading icons consistently |
| Selection | Blue trailing check, no empty box | Black filled/empty squares | Blue trailing check/minus; empty unselected position |
| Disclosure | Small trailing chevron | Heavy darker chevron | 11 pt semibold tertiary chevron |
| Dividers | None discernible at Mirroring scale | Visible inset separators | No primary row separators; faint reference lines remain uncertain |

High confidence: structure, controls, relative density. Lower confidence: exact type size/weight, colors, tiny separators. Reference only inspected with All selected; other reference selection/save semantics remain unverified. This does not certify pixel-perfect parity.

## Behavior and intentional differences

Existing `TaskCalendarOptions` source mutations, unions, last-deselection behavior, revision-checked save, unavailable-source protection and Cancel/dismiss behavior remain unchanged. Expansion stays local. No unsupported Assigned to Me or subscription controls are fabricated.

Taskovsky retains explicit accessible Cancel (x) despite no visible reference Cancel. Existing bulk tag/list actions move under **More**. Existing **Show only <list>** remains in each list row's long-press menu and named accessibility action rather than occupying the main row. These intentional presentation adaptations preserve existing capabilities and require native interaction verification. Display-options route remains the original Form and text toolbar; this change only affects source filtering.

## Acceptance

- Exact source build and full suite/release.
- Native compact geometry at standard text size, readable fully expanded neutral hierarchy.
- Folder/Tags expansion, selection, staged Cancel, saved tag/Inbox unions, nested list result filtering and relaunch.
- Long-press Only, More bulk actions and cancellation.
- Independent review and exact-head hosted CI.
- Actual privacy-safe Simulator screenshot; no personal TickTick data in public repository.

## Verification

Source checkpoint `570a5fb`, integrated with unchanged main source in `b43cf3a`.
- Full Swift package suite: 838 XCTest (134 workspace + 55 Mac + 120 domain + 529 core) and 38 Swift Testing passed. Release app build and strict/deep signature verification passed. The final 8 pt phone inset refinement does not affect these shared/Mac targets.
- Five native Simulator tests passed for compact layout/secondary actions, folders/Cancel, tag+Inbox union/relaunch, nested-list actual results/relaunch, and Week overview Only filtering. After final top-inset refinement, compact geometry/Only/bulk/Cancel test passed again. Owned iPhone13Pro Simulator, iOS26.3.1, standard light appearance.
- Independent source review clean after moving 44 pt header hit area into button labels. No test assertions weakened. Initial native invocation named the wrong target and ran no tests; corrected `MobileNavigation` run supplies the evidence.
- Actual final screenshot inspected: 1170×2532, neutral QA data only, [compact layout](../assets/mobile-parity/2026-11-15/c05-compact-layout.png). First white surface ~125 pt from phone top, ~78 pt below the sheet edge; primary row pitch 50 pt, lateral inset16 pt. Old source screenshot remains historical evidence. Screenshot SHA-256: `8bcbafdf414ac06cd40ecda1899ff76f2d87afcc0ded93147ce283e8dca884c4`.
- Exact fonts/colors, additional real-device scale calibration, unobserved non-All reference selection states, and unsupported source types are not certified. No pixel-perfect acceptance claim. Hosted exact-head CI remains required before merge.
