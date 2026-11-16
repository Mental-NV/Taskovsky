# T09/T11 Unified Smart Lists/Tags management — 2026-11-16

- Status: Implemented, verification pending (native slot not run).
- Owner instruction: implement fresh in `feat/mobile-management-tabs-fresh`; preserve
  `/private/tmp/TaskovskyUnifiedManagement` (dirty) and
  `/private/tmp/TaskovskyUnifiedManagementVerify` untouched; no patch transfer.
- Base: `b635613` (merge PR #145). Current source is the authority; T13/T14 filter and
  T15/T16 tag behavior retained unchanged.
- Related: [inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md) (T09/T11),
  [BUS-017](../spec/business.md#bus-017), [BUS-018](../spec/business.md#bus-018),
  [IOS-009](../spec/iphone.md#ios-009), [TT-019](../parity-implementation-status.md#tt-019),
  [TT-020](../parity-implementation-status.md#tt-020),
  [TT-024](../parity-implementation-status.md#tt-024),
  [TT-025](../parity-implementation-status.md#tt-025).
- Existing routes retained: drawer Smart Lists, Manage Filters and Manage Tags shortcuts
  are unchanged; the unified surface is an additional entry point.

## Outcome and scope

The drawer utility row gains **Manage**, which opens one tall sheet with **Smart Lists**
and **Tags** tabs sharing a single staged visibility/order draft (`UnifiedManagementSession`).
Tab switching never resets staged rows. The Smart Lists tab keeps genuine visibility
pickers (Show / Show if not empty / Hidden with current check), within-group reorder and
**Add Filter**. The Tags tab keeps the Tags visibility picker, **Add Tag** and the
existing tag rows backed by the real tag editor. Nested Add/Edit Tag and Add Filter reuse
the standalone `PhoneTagEditor` / `PhoneFilterEditor` and their revision-checked saves —
no duplicated mutations.

A dirty parent gates nested entry behind explicit **Save Changes / Discard Changes /
Keep Editing**. The parent CAS token stays pinned while dirty; a successful child mutation
refreshes the parent baseline only when clean, never swallowing a newer external revision
or overwriting newer settings. Child Cancel creates/mutates nothing and resets no
unrelated draft. Unsupported reference rows (Assigned to Me, Subscribed Calendars) are
absent, not faked. No T02 display-control changes.

## Per-element layout, wording and behavior

Reference: inventory T09 (tall sheet, Smart Lists selected, visibility rows with current
state, Add Filter, upper-right checkmark returns) and T11 (Tags tab: Tags visibility
Show if not empty, Add Tag, tag rows, return to Smart Lists before closing).

| Element | Placement / wording | Real behavior |
| --- | --- | --- |
| Manage entry | Drawer body row `Manage Smart Lists & Tags` above Manage Templates | Opens the unified sheet with the live settings snapshot and revision; existing shortcuts untouched. A toolbar entry was tried first and reverted: the fifth icon-only toolbar button collapsed all drawer utilities into the overflow menu, hiding the existing Settings/Smart Lists/Filters/Tags entries (proven by the first native run) |
| Sheet title / tabs | `Manage`, segmented `Smart Lists` / `Tags` | Smart Lists selected on entry; one shared staged draft across tabs |
| Smart Lists tab rows | `Smart Lists` section (top group), `Drawer sections` (Filters), `History` (bottom group) | Same pickers, identifiers and within-group reorder as the standalone sheet; Tags visibility lives on the Tags tab instead of being duplicated |
| Add Filter | Own row below drawer sections | Opens the real Normal filter editor (`New Filter`); save persists via `SavedFilterChange`, Cancel writes nothing |
| Tags tab visibility | `Tags` section, `Tags` picker | Same Show / Show if not empty / Hidden control as before, staged in the shared draft |
| Add Tag | Tags section action | Opens the real `Add Tag` editor (name, desktop palette, custom color, parent, pin); blank name disables confirmation |
| Tag rows | Below Add Tag, depth-indented with pin/chevron | Same order/labels as the standalone manager; tap opens the real `Edit Tag` editor gated by the dirty check; no immediate per-move saves here (reorder stays in Manage Tags) |
| Toolbar | `Cancel` leading; `Reorder`/`Finish` + `Done` trailing | `Done` saves when dirty else closes (checkmark-equivalent close); `Cancel` confirms only when dirty; reorder affects Smart Lists tab only |
| Dirty gate | Alert on nested entry | Save-then-open, Discard-then-open, or Keep Editing; failed parent save clears the pending intent and never opens the child. A confirmation dialog was tried first and reverted: rendered from inside this sheet it becomes a popover sheet whose cancel button is not exposed, leaving Keep Editing unreachable; the alert keeps all three choices explicit. Discard-then-open presents on the next MainActor turn: same-transaction alert-dismiss plus sheet-present no-ops the handoff (found by the native run, fixed without weakening assertions) |
| Errors | Inline banners (`managementError`) | Stale and write-failure messages mirror the standalone sheets; drafts retained |

Unknown reference details (not invented): exact tall-sheet height/detent, segmented control
metrics, row pitch, upper-right glyph (reference checkmark vs this sheet's `Done` text —
kept consistent with the existing standalone sheets), tag row trailing affordance, and any
transition animation. The reference's example visibility values are not defaults.

## Data and CAS contract

`UnifiedManagementSession` (TaskovskyWorkspace) holds baseline settings, baseline
revision, staged settings and selected tab. `stage` never touches the baseline;
`select` preserves the draft; `needsChildDecision` is exactly `isDirty`;
`discardStaged` resets staged but keeps the token; `markSaved` advances the baseline
after the parent's own successful save; `adoptBaseline` returns false and changes
nothing while dirty. The view additionally adopts the live document into the baseline
only via `adoptBaseline`, so a clean parent follows child saves and external updates
while a dirty parent keeps its original token and fails stale instead of overwriting.

Tag cycle safety (`TagOrganization.allowsParent`), palette/custom-color round-trip,
duplicate-name rejection and filter unavailable-reference retention are unchanged
production paths, covered by repository tests below.

## Acceptance cases (all neutral fixture)

Workspace (`Tests/TaskovskyWorkspaceTests/UnifiedManagementTests.swift`, 14 tests):
tabs preserve staged visibility/order; reorder stages without touching the baseline;
discard keeps the token; baseline adoption only when clean; staging writes no files;
real tag create (custom color) and filter create (unavailable tag) persist and reload;
stale parent save fails without overwriting newer settings; clean parent adopts the
child revision and a later parent save succeeds; dirty parent keeps the pinned token
across a child mutation and its later save reports stale with files intact; stale
tag/filter writes refused without mutation; failed parent write retains the draft
without mutation; cyclic reparent and duplicate names refused without mutation.

Native (`Mobile/UITests/UnifiedManagementTests.swift`, 7 tests, prepared — NOT RUN):
sheet opens Smart Lists-selected; unsupported rows absent; staged visibility survives tab
switch (proven by the discard prompt); real Add Tag and Add Filter save + relaunch
reopen; dirty gate Keep Editing / Discard + child Cancel paths; dirty gate Save path;
save-failure banner with retained draft. Stale-write UI is unverified: the `stale-save`
QA injection only affects task/capture saves, so CAS staleness is covered at repository
level instead. Screenshots attach in-test for later export.

## Verification receipt

- `swift test --disable-sandbox`: 890 XCTest (Workspace 150 incl. 14 new, Mac 55,
  Domain 154, Core 531) + 38 Swift Testing, 0 failures. Full log:
  `/tmp/mgmt-swift-test.log`. (Three bundles also print zero-test summaries; not counted.)
- `./scripts/build-app.sh`: exit 0, release `build/Taskovsky.app`, log
  `/tmp/mgmt-release.log`.
- `./scripts/build-ios-simulator-ci.sh`: **TEST BUILD SUCCEEDED** (Xcode 27.0 27A266a,
  Swift 6.4, simulator SDK 27.0, iOS 17.0 target, signing disabled). App, MobileContracts
  and MobileNavigation bundles plus the xctestrun manifest compiled; **no tests executed**.
  Zero warnings/errors referencing the new files. Logs: `/tmp/mgmt-ios2/`
  (`provenance.log`, `compile.log`, `compile.xcresult`).
- iOS compile fix: explicit `set: { option in ... }` in the visibility binding
  (`$1` mis-resolved because Mobile sources are outside the SwiftPM build that
  `swift test` compiles).
- Native tests: prepared only, DO NOT RUN until the parent coordinates the slot.
- Old checkouts `/private/tmp/TaskovskyUnifiedManagement` and
  `/private/tmp/TaskovskyUnifiedManagementVerify` were never read, listed or modified.
- Exact-head hosted CI pending. No push/PR. No live TickTick, no personal data.

## Independent-review blockers fixed — 2026-11-16

The review of `e1a2502` raised four data-safety blockers; all are fixed on this
branch with no other-tree changes. `main` and `origin/main` remain at `b635613`
(the branch base), so no integration was required.

| # | Blocker | Fix |
| --- | --- | --- |
| B1 | `pendingChild.editTag` captured a full `TaskTag` while `openChild` paired that stale snapshot with the latest revision after Save/Discard | Pending child now captures only the tag ID; `openChild` resolves `UnifiedManagementSession.tagHandoff(tagID:in:)` from the single live document and opens the editor with that exact pair, refusing with "That tag is no longer available." when the tag is gone |
| B2 | Smart Lists reorder mode persisted across the Tags tab, hiding Finish while disabling Add Tag | Tab setter resets `reordering` when leaving Smart Lists; the invariant is reorder ⟹ Smart Lists tab |
| B3 | Failed Save-and-Continue retained `pendingChild`, so a later ordinary Done could open the stale requested child | Failed boundary clears the pending intent; a later Done retries the save instead of navigating |
| B4 | Blanket clean `.onChange` adoption accepted all external revisions, unlike the owned-child-only prose | Adoption is now the explicit `adoptCleanBaseline(from:)` on one exact document (settings+revision never paired across revisions), documented as safe for any provenance while clean and refusing while dirty; view routes through `adoptLatestDocumentIfClean()` |

Regression tests: domain suite grew 14 → 17 (`testEditHandoffResolvesCurrentSnapshotNeverStaleCapture` renames then deletes the tag externally while the parent decision is dirty; `testChildCancelResolvesWithoutWriting`; `testCleanAdoptFollowsWorkspaceOnlyChildChange`; clean/dirty adoption now uses real documents). Native suite grew 7 → 9 prepared (reorder reset across tabs; failed-save-then-Done opens nothing). A bare `.delete(tagID)` literal in the new test silently resolved to the SavedFilterChange overload (filter delete → `.missing`); it now reads `TagOrganizationCommand.delete(tagID)` per repo convention — found by the test run, not by inspection.

Limitations, stated honestly: external tag churn while the dirty gate is open is UI-unreachable (the modal sheet admits no second writer), so B1 is covered at repository level; the transient-failure-then-recovery variant of B3 is unstageable with the permanent-failure QA case, so the native test locks the failed boundary (error, no navigation, draft retained) and the clearing itself is review-verified; stale parent/child saves remain repository-level (the `stale-save` QA injection covers only task/capture saves).

Verification after fixes: `swift test --disable-sandbox` 893 XCTest (Workspace 153, Mac 55, Domain 154, Core 531) + 38 Swift Testing, 0 failures, log `/tmp/mgmt2-swift-test.log`; `./scripts/build-app.sh` exit 0; `codesign --verify --deep --strict build/Taskovsky.app` exit 0, log `/tmp/mgmt2-release.log`; `./scripts/build-ios-simulator-ci.sh` TEST BUILD SUCCEEDED (same toolchain), zero warnings/errors in the new/changed files (three pre-existing unused-`menu` warnings in `ReadOnlyNavigationTests.swift` untouched), logs `/tmp/mgmt2-ios/`. Native tests prepared, NOT run.

## Upstream PR146 integration and native execution — 2026-11-16

Integrated `origin/main` `0dac439` (PR146 task display) as merge `addebf6`: clean merge, no conflicts; T02 display hunks (`detailDestinations`, `supportsCompletedDisplay`, `displayProjection`) and unified-management hunks (`openManagement`, `tagHandoff`, `adoptCleanBaseline`) both present; tracer files `TaskDisplayProjectionTests` and T02 screenshots retained. No T02 source reversal.

Native slot used the owned simulator only (Taskovsky Menu QA 1114, `B263E8E7-F1A5-4407-894D-23FC224B1013`, iPhone 13 Pro, iOS 26.3.1): nonparallel, collect-test-diagnostics never, unique dir `/private/tmp/TaskovskyManagementTabsNative/`. No user-QA changes, no resets, no desktop input.

First run (toolbar entry): 0/9 — the fifth toolbar button collapsed every drawer utility behind More, hiding existing entries. Fixed by moving the entry to the drawer body; no existing tests touched. Second run: 8/11 — the nested-sheet confirmation dialog drops its cancel button from the AX tree and double-reports identified buttons; switched the gate to an alert. The same run also proved the toolbar fix via the two existing tests. Third run: 10/11 — Discard-then-open ran synchronously inside the alert action while the gate was still marked open, no-opping the handoff; deferred to the next MainActor turn. Fourth run: **11/11 passed, exit 0** (9 unified + `testSmartListFailedSaveKeepsDraftAndDrawer` + `testTagManagerCreatesPinsAndAssignsNestedTag` as no-regression witnesses). The xcresult independently records 11 passed, 0 failed, 0 skipped on device `B263E8E7`. Logs: `native-run[1-5].log`; result bundles `unified-management[2-5].xcresult`; screenshots in `screenshots/` (Smart Lists tab, Tags tab, drawer Filters after Add Filter, save-failure draft, failed-save-then-Done — all neutral fixture content, visually inspected).

Final gates on the corrected source: `swift test --disable-sandbox` 895 XCTest (153/55/156/531 — PR146 adds Domain coverage) + 38 Swift Testing, 0 failures (`/tmp/mgmt4-swift-test.log`); `./scripts/build-app.sh` exit 0; `codesign --verify --deep --strict` exit 0 (`/tmp/mgmt4-release.log`); iPhone `build-ios-simulator-ci.sh` TEST BUILD SUCCEEDED (`/tmp/mgmt4-ios/`). Exact-head CI remains pending.
