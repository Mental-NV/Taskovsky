# iPhone Tasks drawer footer Add and management (T07/T08)

Status: **Implemented; native verification passed on final source, exact-head hosted CI and independent re-review pending.** Base `bca277c` (PR157), branch `feat/mobile-drawer-add`. No commit/push/PR/merge.

Scope: the two missing drawer-footer flows from the
[reference inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md#tasks-and-organization):
T07 bottom Add and management, T08 bottom-left Add popup (List, Filter, Tag).
Current source `navigation()` in `Mobile/App/TaskovskyMobileApp.swift` renders an
indigo scroll drawer with top utilities, in-scroll Manage Smart Lists & Tags and
Templates, but no Add popup. Nothing else in the drawer changes: no reorder,
no account imitation, no external controls, no Mac change. Final geometry is
not claimed calibrated.

## Per-form element inventory (T07/T08 scope)

Reference: iPhone 13 Pro, iOS 27.2.1 via approved Mirroring; app version, text
size and viewport scale unrecorded. Taskovsky counterpart: owned Simulator
`B263E8E7`, iPhone 13 Pro, light theme, neutral fixtures.

### T07 drawer footer

**Footer container.** Reference: Add and management controls sit at the bottom
of the indigo drawer; backdrop tap returns to tasks. Taskovsky: bottom-anchored
bar inside the drawer panel via `safeAreaInset(edge: .bottom)` on the drawer
scroll content, so it never overlaps scrolled rows and stays visible after any
scroll. Safe-area-aware within the drawer. Dismissal paths unchanged: backdrop,
Done, destination tap, accessibility escape.

**Add entry (left).** Reference: bottom-left add control opening the T08 popup.
Taskovsky: leading footer button with plus icon, label "Add",
identifier `drawerAdd`. Opens the T08 menu; creates no draft by itself.

**Management entry (right).** Reference: bottom-right management opening the
T09 tall Smart Lists sheet. Taskovsky: trailing footer button reusing the
existing unified-management entry (identifier `openManagement` kept). Opens the
existing `PhoneUnifiedManagement` sheet with the current revision; no new
manager, no duplicate button (the in-scroll entry moves into the footer).
Existing utility identifiers (`openLocalSettings`, `openSmartLists`,
`manageFilters`, `manageTags`, `manageLists`, `manageTemplates`) preserved.

**Scroll/content preservation.** Existing scroll, folder/tag hierarchy, counts,
selected destination, compact and accessible reflow unchanged. Footer is
outside the scroll view, so long drawers keep every row reachable and the
footer reachable after scrolling. No user selection or existing draft is reset
by opening the footer, menu, or editors.

### T08 Add popup

**Menu container.** Reference: anchored popup above the bottom-left add control;
backdrop tap dismisses back to the drawer with nothing created. Taskovsky: a
custom anchored bubble above the footer Add button (a SwiftUI Menu rendered
its rows bottom-up on the owned Simulator, breaking the observed order);
the `drawerAddBackdrop` outside-tap layer dismisses to the drawer with no
writes. Exact reference popup geometry unverified.

**Modal containment (source) vs touch blocking (verified).** Source declares
the intent: while the popup is open, the original drawer backdrop and drawer
panel are hidden from accessibility (visually unchanged), and the popup plus
its dismiss backdrop form one modal accessibility container (`drawerAddMenu`,
children contained) so row controls stay individually reachable. What native
testing verifies is touch blocking only — observed on the owned Simulator:
hidden views remain listed in the XCUI tree but are never hittable while the
dismiss layer covers them, so the regression test asserts non-hittability plus
restoration rather than absence. Actual VoiceOver traversal/focus transfer and
Escape behavior are explicitly unverified.

**List row.** Reference: first row, opens the blank Add List sheet (T12).
Taskovsky: first menu row, label "List", identifier `drawerAddList`. Opens a
BLANK `PhoneListEditor` directly (`ListEditorRequest` with an empty list,
`creating: true`, current revision) — not the Manage Lists organizer.

**Filter row.** Reference: second row, opens the blank Normal filter editor
(T13). Taskovsky: second menu row, label "Filter", identifier
`drawerAddFilter`. Opens a BLANK `PhoneFilterEditor` directly
(`PhoneFilterRequest` with an empty filter, `creating: true`, current
revision) — not the Manage Filters list.

**Tag row.** Reference: third row, opens the blank Add Tag sheet (T15).
Taskovsky: third menu row, label "Tag", identifier `drawerAddTag`. Opens a
BLANK `PhoneTagEditor` directly (`PhoneTagRequest` with an empty tag,
`creating: true`, current revision) — not the tag manager.

**Menu order.** Exact reference order List, Filter, Tag is preserved.

### Blank creation forms (reused editors, no editor changes)

**Add List (T12).** Blank name, List Color, List/Board(Timeline) view-type
previews, More (Folder, List Type, Show in Smart List). Save disabled with an
empty name; Cancel discards with no write and returns to the drawer. Repeated
opens reset to a blank draft. Successful save persists and the list is
reachable in the drawer. Existing validation, CAS revision guard and
save/failure rules intact.

**Normal Filter (T13).** Focused blank name; List/Tag/Date/Priority conditions
(all All), Include keywords, Type All, explicit All resets, Preview footer.
Checkmark disabled until valid; Cancel discards with no write and returns to
the drawer. Repeated opens reset to a blank draft. Successful save persists
and the filter is reachable in the drawer. Advanced tab (T14) behavior
unchanged. Existing validation, CAS guard and save/failure rules intact.

**Add Tag (T15).** Blank name, palette plus custom color, Parent Tag None.
Save disabled with a blank name; Cancel discards with no write and returns to
the drawer. Repeated opens reset to a blank draft. Successful save persists
and the tag is reachable in the drawer. Existing validation, CAS guard and
save/failure rules intact.

## Excluded and unverified semantics

- T05 Share/Print and T06 Background remain explicitly deferred; no share,
  print, background, account, sync, notification, or external-service controls.
- Anchored-popup exact geometry, menu animation timing, and dark appearance
  remain unverified (light-theme priority; dark matching deferred).
- The mid-session transition to read-only/busy while the popup is already open
  is guarded in source (`canBeginEditing` in all three creation helpers plus a
  popup disable) but has no UI-test injection path, so that transition is
  unverified; the disabled Add entry in a read-only workspace is covered.
- No Taskovsky UI text references TickTick, parity work, or this inventory.
- Tracker counting: illustrated states move 39/46 to 41/46 (T07 and T08 each
  gain an attached Taskovsky screenshot). Each state counts once; individual
  screenshots are not states.

## Acceptance

- Native regression tests cover: all three blank routes with disabled empty
  save; Cancel and menu/backdrop dismissal with no writes; reopen resets blank
  draft; successful neutral List/Filter/Tag creation persists across relaunch
  and is reachable in the drawer; footer reachable after drawer scrolling;
  popup touch blocking/restoration (underlying controls non-hittable while
  open, popup rows and dismiss reachable); disabled Add in a read-only
  workspace; existing management return (`openOrganization` flow) still
  returns to drawer.
- Affected existing drawer/organization/management/creation tests stay green
  with no weakened assertions. All business validation and CAS save guards
  unchanged. New identifiers: `drawerFooter`, `drawerAdd`, `drawerAddMenu`,
  `drawerAddBackdrop`, `drawerAddList`, `drawerAddFilter`, `drawerAddTag`;
  the footer management button keeps the existing `openManagement` identifier
  (moved, not duplicated).

## Verification record (final source, uncommitted)

All checks below ran on the final source in `/private/tmp/TaskovskyDrawerAdd`
(base `bca277c` plus this change, uncommitted). Logs, xcresults and screenshots
retained under `/private/tmp/TaskovskyDrawerAddNative/` (runner-local, not
committed). Owned slot `B263E8E7` (Taskovsky Menu QA 1114, iPhone 13 Pro,
iOS 26.3.1) only; `-parallel-testing-enabled NO`, `-collect-test-diagnostics
never`; no other simulator, device, signing setting, data/reset, or settings
change. Neutral fixtures only; no personal data.

- Package: `swift test --disable-sandbox` exit 0 — **934 XCTest + 38 Swift
  Testing passed, 0 failures** (`swift-test-final.log`).
- Release: `./scripts/build-app.sh` exit 0; `codesign --verify --deep --strict
  build/Taskovsky.app` exit 0 (`build-app-final.log`).
- iPhone compile: `./scripts/build-ios-simulator-ci.sh` exit 0, TEST BUILD
  SUCCEEDED, app plus contract/navigation bundles compiled
  (`ci-ios-final.log`, `ci-ios-final/`).
- Native new: `DrawerAddTests` **7/7 passed, 0 failures**
  (`DrawerAddFinal2.xcresult`, `drawer-add-final2.log`): footer/menu order/
  outside-dismissal, popup touch blocking/restoration (underlying controls
  non-hittable while open, restored on dismissal; popup rows and dismiss
  reachable), disabled Add in read-only workspace, three blank routes with
  disabled empty saves, Cancel/no-write, reopen blank reset, neutral
  List/Filter/Tag creation with drawer reachability and relaunch persistence,
  footer reachability after scrolling, management return. The 7/7 proves touch
  blocking/restoration only, not VoiceOver isolation or accessibility
  exclusion.
- Native adjacent: `UnifiedManagementTests` (9/9) plus 9 drawer/organization/
  management/creation tests — **17/18 passed** (`AdjacentFinal.xcresult`,
  `adjacent-final.log`). The single failure,
  `testListCreationViewSelectionCancelDoesNotCreateList` (`setSwitch` helper:
  `organizationPin` coordinate tap read back "0" instead of "1"), is in the
  untouched Manage Lists organizer path; the isolated rerun on identical
  source passed (`RerunPinSwitch.xcresult`, `rerun-pinswitch.log`). Cause not
  conclusively established — recorded as an intermittent failure with the
  assertion preserved, not as proof of no regression. No assertions weakened.
- Superseded runs (kept honest, not claimed): Run1/Run2 looked up `drawerAdd`
  as a Button while the footer container identifier overrode children and the
  Menu exposed a PopUpButton mismatch; fixed by scoping the footer as a
  container and querying correctly. Run3 exposed three test bugs (empty
  TextField reads placeholder text; Menu rows rendered bottom-up; ambiguous
  "Taskovsky" static text) plus the genuine product finding that SwiftUI Menu
  rendered rows bottom-up on this stack — fixed with the custom anchored
  bubble. Run4 (5/5) predates the reviewer modal/guard changes. Old
  screenshots from Run4 remain in history only; tracker placements are the
  fresh Final2 exports below.
- Screenshots: 6 inspected fresh exports from the final-source run
  (`screens-final2/`): drawer footer, Add popup (List/Filter/Tag order),
  blank Add List / Normal Filter / Add Tag (blank names, disabled Done),
  footer after scrolling. Placed `t07-drawer-footer.png` and `t08-add-popup.png`
  with manifest SHA-256 entries. Tracker illustrated states move 39/46 to
  **41/46** (one state per form, not per image).

Still unverified: matched anchored-popup geometry and reference typography,
physical-device/locale-specific rendering, VoiceOver focus traversal/focus
transfer and Escape behavior, the mid-session read-only/busy transition while
the popup is open (guarded in source, no UI-test injection path), dark
appearance (deferred), exact-head hosted CI and independent re-review. The
fold-cutoff adjacent failure and the two PR156 baseline failures were not
rerun here and stay open. No push/PR/merge, no personal data, no live TickTick
observation, no external-agent or Computer Use contact. The owned simulator was
left booted and otherwise untouched.

Publication receipt: tested behavioral source committed as `dcc0d44`; subsequent edits only clarify test comments/evidence. Both placed Final2 PNGs were independently pixel-inspected, neutral fixtures only. All20 manifest hashes/dimensions validated after correcting a one-character hash transcription error. Source/evidence review passed; exact-head hosted CI pending.

## Main integration revalidation — November 16

Integrated main `6e94f067a3bf4fb4daf7cbec23eb140a7d3bd2fb` (PR159)
into drawer head `be884c3`. Drawer source/tests and the incoming T10
source/tests are unchanged from their respective parents. Both evidence
histories and screenshots remain; combined illustrated coverage is **42/46**.
All **21** current manifest hashes, dimensions and receipt paths validate.
README now accurately states that a separate iPhone target exists.

Independent merge/source/documentation review found no blockers. Fresh
integrated validation passed: 934 XCTest plus 38 Swift Testing tests,
macOS release build, strict deep signature verification, iPhone Simulator
CI compile, and **21/21** combined DrawerAddTests (7) and
UnifiedManagementTests (14), zero failures. Native run used only the owned
QA Simulator, neutral fixtures, serial testing and no diagnostic collection.
Logs and `Combined.xcresult` are retained in
`/private/tmp/TaskovskyDrawerIntegrationNative/`.

These selected integration tests do not close the prior intermittent
pin-switch failure or unrelated Calendar baseline failures. Earlier
accessibility, geometry and deferred appearance limits remain. Hosted CI
must pass on the new exact head before merge; earlier capacity-cancelled
runs are not successful validation.
