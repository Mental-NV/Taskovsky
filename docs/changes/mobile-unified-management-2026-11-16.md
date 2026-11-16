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
| Manage entry | Drawer utility row, after Smart Lists | Opens the unified sheet with the live settings snapshot and revision; existing shortcuts untouched |
| Sheet title / tabs | `Manage`, segmented `Smart Lists` / `Tags` | Smart Lists selected on entry; one shared staged draft across tabs |
| Smart Lists tab rows | `Smart Lists` section (top group), `Drawer sections` (Filters), `History` (bottom group) | Same pickers, identifiers and within-group reorder as the standalone sheet; Tags visibility lives on the Tags tab instead of being duplicated |
| Add Filter | Own row below drawer sections | Opens the real Normal filter editor (`New Filter`); save persists via `SavedFilterChange`, Cancel writes nothing |
| Tags tab visibility | `Tags` section, `Tags` picker | Same Show / Show if not empty / Hidden control as before, staged in the shared draft |
| Add Tag | Tags section action | Opens the real `Add Tag` editor (name, desktop palette, custom color, parent, pin); blank name disables confirmation |
| Tag rows | Below Add Tag, depth-indented with pin/chevron | Same order/labels as the standalone manager; tap opens the real `Edit Tag` editor gated by the dirty check; no immediate per-move saves here (reorder stays in Manage Tags) |
| Toolbar | `Cancel` leading; `Reorder`/`Finish` + `Done` trailing | `Done` saves when dirty else closes (checkmark-equivalent close); `Cancel` confirms only when dirty; reorder affects Smart Lists tab only |
| Dirty gate | Confirmation dialog on nested entry | Save-then-open, Discard-then-open, or Keep Editing; failed parent save keeps the draft and never opens the child |
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
