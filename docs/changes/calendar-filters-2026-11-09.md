# CAL-FILTER-001 — Reliable Calendar source selection

Status: Implemented; bounded verification passed November 9, 2026. See [evidence and limits](../spec/verification.md#calendar-source-follow-up). The user's November 9 request authorizes correcting Calendar filters and scoped desktop UI/documentation discrepancies. Work stays local/uncommitted on `codex/calendar-visual-parity`, based on `f85e2f6`, preserving the complete earlier visual pass and boundary correction. No iOS work, branch integration, external services, push, PR or deployment.

Contracts: BUS-025, BUS-027/028/030, UX-017, TT-033. Source baseline: `TaskCalendarOptions.includes`, `CalendarNavigationSidebar` and `CalendarScopeCheckbox`. Private starting-tree backup/evidence: `/private/tmp/TaskovskyCalendarFilterAudit-1108-w4ksafbs`.

## Confirmed problem and target

Live installed TickTick treats All as a selection mode, not an off/empty switch. Repeating All leaves it selected. Selecting a list or tag while All is active selects only that source. Lists, Inbox and tags combine as alternatives; selecting a tag does not hide untagged tasks in a selected list. Clearing the final source returns to All. Group checkboxes have off/mixed/on states; mixed activates all members and on clears them. All and individual source labels activate the same selection as their checkbox. Group titles/arrows expand; their trailing checkbox changes group selection. The starting Taskovsky build intersects tags with lists, leaves stale tags behind All, and renders detached non-activating source labels with no group controls.

Implement these source-selection rules as domain commands, with a single settings assignment per UI action. Archived/deleted task exclusion and descendant-tag membership remain intact. Scope affects every Calendar projection, mini-month counts and Arrange's All choice. Explicit Arrange list selection remains a separate restricting chooser; do not accidentally union unrelated tag matches into that chosen list.

## Data and compatibility

Retain the existing `listIDs`, `includeInbox`, `tagIDs` fields and settings JSON. `nil` lists + Inbox + no tags denotes All; individual marks are empty in All mode. Explicit selected list IDs/Inbox and tags denote a union. Legacy nil-list tag-only scope remains tag-only rather than expanding to every list or Inbox; legacy nil-list/excluded-Inbox scope still represents all active lists without Inbox. Explicit saved empty and stale-ID selections remain restrictive on read; only an explicit clear/toggle action falls back to All. No workspace/task mutation or silent pruning of stale IDs on load. Combined custom list/tag selections adopt the corrected union semantics.

## UI contract

Keep UX-017 geometry/tokens and the one-physical-pixel boundary correction. Source rows are 30 points high, single-line 13-point text; entire individual label/checkbox region is clickable with an explicit content shape. All has a 14-point circular indicator; list/tag rows have square indicators. Groups show off/mixed/on via square, minus-square and checkmark-square; selected/mixed labels and indicators use the Calendar accent. Group titles/arrows share the expansion button; a separate trailing 20×30 selection button contains the 14-point indicator. Expose accessible labels, checked/mixed values and keyboard activation; no nested overlapping buttons. No new animations. Empty Tags disables select-all when no stale tag intent exists. Stale selections get a visible clear action outside collapsed content. No selected-source state is lost on changing view, resizing or relaunch.

## Acceptance and verification

- CF-01: repeat All through label/indicator; reset custom tags/lists/Inbox and visibly show All.
- CF-02: first source from All selects only it; repeat list/Inbox/tag toggles, remove final source to All, and exercise all group states.
- CF-03: union across lists, Inbox and tags; descendant tags, archived/deleted exclusions, empty/tagless workspaces and stale references.
- CF-04: saved JSON round-trip and actual store reload; no task-byte/scheduling changes; all seven views, mini-month and Arrange scope.
- CF-05: label and indicator activation, separate expansion, mixed state, compact layout and keyboard alternatives in isolated native app.
- CF-06: preserve previous visual work/boundaries; full tests, signed release and strict signature checks on the final tree. Document dark/motion/VoiceOver or reference cases not exercised.

Official Tasks/Calendar root articles and relevant children will be reconciled in a dated comparison ledger with source links. Documentation is a test lead; actual Mac behavior controls. Four additional zones, Option icon reveal, Year previews and recurrence exceptions are research candidates, not automatic scope expansion or confirmed defects. Read-only future forecasts alone are not a defect. Record deeper gaps separately; prioritize the filters.
