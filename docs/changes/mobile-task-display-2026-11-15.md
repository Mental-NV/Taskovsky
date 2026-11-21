# T02 Tasks display controls

Status: Implemented; exact-head hosted CI pending. Base `410b23d`. User-approved wide-first mobile parity; independent design review before implementation.

## Observed reference and scope

Private live TickTick audit, Codex turn `01a1e187-17b1-73e3-bc6e-7d1115ed0347`, restored after inspection: Details exposes description, tags, schedule range, reminder/repeat indicators, checklist progress and source list where present in List and sampled Kanban. Completed adds a collapsible section without changing unfinished counts. Personal reference captures are not published.

Implement Details for ordinary List/Kanban routes. Completed control is restricted to ordinary List destinations: All, Today, Tomorrow, Week, Inbox, Notes, List, Folder and Tag. Search, saved filters, dedicated history, archived lists, Calendar, Timeline and Board completion semantics remain unchanged. Hide Checklist Item is explicitly deferred: observed subtasks remained visible and embedded checklist-item hiding was not evidenced. No decorative control or fabricated View More pagination.

## Element and behavior contract

- Tasks overflow: Show Details / Hide Details, text icon, 44-point row; session state per destination, compact by default. Existing title/date and controls retained. Expanded body is a two-line plain-text preview, tag names, actual schedule-zone range, stored reminder/repeat, checklist completed/total, source list. Existing arbitrary body/rich data untouched. Kanban cards use same component.
- Ordinary List overflow: Hide Completed / Show Completed, check-circle icon, 44-point row. Existing default visible history retained; no guessed reference preference migration.
- Completed section: chevron, Completed, count, 44-point disclosure. Completed pinned tasks appear once here, never in active pinned section. Collapse is per destination and session only.
- Existing destination membership applies before projection; no global completed-task union. Won't Do unchanged because reference semantics are unverified. Active drawer counts untouched. Sorting, pins, hierarchy disclosure, drag eligibility and task opening unchanged.
- Batch snapshot excludes completed records hidden by this new toggle or section collapse. Existing subtask-collapse policy remains unchanged: matched children are still batch eligible. The batch editor freezes its snapshot; display toggles are unavailable while that modal is open, so existing selections are not silently dropped.
- Display state does not write the workspace, revision, task dates, completion, or settings. Persistence/sync polish remains deferred.

## Verification

Local full suite passed: 868 XCTest plus 38 Swift tests. Release build and iPhone build-for-testing passed. Regression fixture is neutral and isolated. Independent final source review approved. Native on source `3a9594e`: three tests passed, zero failures/skips; process exit 0 and completed `TaskDisplayNative.xcresult` summary independently parsed. Cases cover Inbox hide/collapse and batch positive/negative inclusion, sectioned List details/history, and Kanban metadata/task opening. Native build compiled the strengthened test delta. One UIKit `_UIReparentingView` runtime warning occurred during Kanban popup presentation; interactions and inspected layout passed, not claimed warning-free. Simulator released after verified completion. Exact-head hosted CI remains a merge gate.

Actual unmodified screenshots inspected for content/privacy and readable layout: [List details](../assets/mobile-parity/2026-11-15/t02-list-details.png), [Kanban details](../assets/mobile-parity/2026-11-15/t02-kanban-details.png), [Completed section](../assets/mobile-parity/2026-11-15/t02-completed-section.png). These show resulting display states, not the overflow menu itself. No calibrated pixel-perfect claim; tag chip styling and reference-specific truncation/spacing remain final polish.

Acceptance: ordinary Inbox and sectioned List hide/show/collapse, pinned completion once, Won't Do retained, batch exclusion, List and Kanban expanded details, task opening, excluded history controls; pure projection tests preserve bytes/order/membership/active counts. Existing accessibility support retained, expanded metadata has an accessible value. Accessibility-specific layout, dark theme and final calibrated pixel polish are deferred.

## PR145 integration

Integrated main `b635613` at `d9d11e9`. Sole conflict was the QA-case enum; retained both `task-display` and `arrange-hierarchy`. Production changes are separate Tasks/Calendar paths. Existing C14/T02 test groups, screenshot manifest records, tracker rows and receipts retained. On integration: 878 XCTest plus 38 Swift tests, release build and iPhone build-for-testing passed (combined command exit 0). No redundant native run: display implementation and three native acceptance methods unchanged; original completed native receipt remains source-applicable. Final integration review and refreshed exact-head CI required before merge.
