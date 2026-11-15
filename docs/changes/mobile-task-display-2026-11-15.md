# T02 Tasks display controls

Status: In implementation. Base `410b23d`. User-approved wide-first mobile parity; independent design review before implementation.

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

Local full suite passed: 868 XCTest plus 38 Swift tests. Release build and iPhone build-for-testing passed. Regression fixture is neutral and isolated. Native checks are queued behind the previously reserved Simulator session; no native pass or screenshot is claimed yet. Independent final source review, completed native result bundle, final changed-test compile and exact-head hosted CI remain gates before merge.

Acceptance: ordinary Inbox and sectioned List hide/show/collapse, pinned completion once, Won't Do retained, batch exclusion, List and Kanban expanded details, task opening, excluded history controls; pure projection tests preserve bytes/order/membership/active counts. Existing accessibility support retained, expanded metadata has an accessible value. Accessibility-specific layout, dark theme and final calibrated pixel polish are deferred.
