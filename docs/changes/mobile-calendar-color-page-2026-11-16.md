# Mobile Calendar Color page structural parity (C07/C08)

Status: implemented candidate; local full tests/release, independent source review and three native Simulator tests passed. Exact-head hosted CI remains required.

The observed mobile inventory C07–C08 places an anchored **Color By** menu
(List/Tag/Priority, current checked, backdrop closes) and the genuine source
swatches inline on the pushed Color page: Color By, then Inbox, lists, and
folders. Taskovsky previously showed Color By plus a link to a separate
Customize List/Tag Colors page. This presentation-only slice flattens the
supported source rows into the Color page and groups List-mode rows by the
existing domain folder ownership. No persistence, domain, fixture, or Calendar
rendering change is intended.

## Behavior contract

- The Color page keeps its pushed-page position under View Options and its
  outer staged draft: Back retains the draft, outer Cancel discards it, and
  outer Done uses the existing revision-checked save.
- **Color By** is an anchored menu labeled exactly `Color By` with the current
  mode checked. Tapping outside closes it without changing the draft. The
  selection value stays accessible on the `calendarColor` control.
- List mode shows Inbox first, then active lists grouped by domain ownership:
  above-folders lists in stored order, one group per folder in folder order
  (folder names are genuine domain labels), then below-folders lists. Archived
  lists are excluded. Lists whose folder is unknown fall to the below-folders
  group, matching the Calendar filter fallback.
- Tag mode shows existing tags in stored order. Priority mode shows a truthful
  note that Priority keeps its fixed Calendar colors; there is no priority
  editing and no invented priority/tag semantics.
- Every source row keeps the existing system ColorPicker and a per-row
  Default action. Choosing Default removes that source's Calendar-only
  override so the row follows the workspace color again. Overrides stay
  Calendar-only: list and tag records are never mutated.
- Overrides for archived or otherwise unavailable sources are preserved, not
  dropped; they simply have no row. Switching Color By never clears the other
  mode's overrides. Storage keys and encoding are unchanged, so there is no
  saved-colors migration and no data loss.
- Nothing fake was added: no Health/Focus rows, no named-palette editor (the
  C09 named palette remains unverified), no guessed folder labels.

## Verification

- `swift test --disable-sandbox`: full suite passed with 0 failures,
  including two new `CalendarDisplayOptionsTests` cases covering hierarchy
  order/source identity (Inbox first, archived excluded, folder grouping,
  stored order, unknown-folder fallback) and override preservation across
  archived/missing sources plus encode round-trip and Default clearing.
- `./scripts/build-app.sh`: macOS release build completed with signature.
- `./scripts/build-ios-simulator-ci.sh /private/tmp/TaskovskyCalendarColor-ios`:
  iPhone app plus contract/navigation test bundles compiled
  (`build-for-testing` only; no tests executed).
- Initial implementation stage (superseded by the completed native run below): native UI coverage was updated but not yet run: the existing
  `testCalendarSourceColorSavesAndResetCanBeCancelled` now exercises the
  flattened page (inline Inbox pick, save, relaunch, reset, Cancel, Priority
  note, Tag customize, Done), and a new
  `testCalendarColorPageShowsFolderHierarchyAndModeSwitch` covers inline
  Inbox/list/folder rows and List→Tag→Priority switching on the
  `calendar-filter-hierarchy` fixture. Simulator execution, screenshots, and
  independent review remain with the parent; this is not a pixel-parity claim.
- No live TickTick, no personal data, no Codex. Fixtures are neutral QA
  samples only.

## Correction: stable Color By leaf IDs

Independent review found the Menu buttons expose AX labels `Color by
List/Tag/Priority` while the native tests tapped `Tag`/`Priority`. Each Menu
button now carries a stable `calendarColorMode-list/tag/priority` identifier;
all five Calendar Color callers (save/reset/Cancel test, hierarchy test, and
the existing View Options render/persist regression) tap those IDs. Unrelated
Tag/Priority controls (Tasks Group & Sort, Arrange grouping) are untouched,
and the root `calendarColor` ID is unchanged. The `calendarColor` value
assertions are retained as row/effect checks; whether the Menu label's value
survives on device is verified at native run time, not assumed here.

Origin/main PR142 (Advanced filter draft preview and read-only examples) was
merged additively underneath this work; its source, tests, docs, and asset
changes are preserved and the C07 hunks are intact.

## Native run (owned device only)

- Device: the released owned simulator `B263E8E7-F1A5-4407-894D-23FC224B1013`
  ("Taskovsky Menu QA 1114", iOS 26.3), already booted. No named/default or
  personal device was used, and no other native work ran concurrently.
- Command: `xcodebuild test` on `Mobile/TaskovskyMobile.xcodeproj`, scheme
  `TaskovskyMobile`, destination pinned to the owned simulator ID,
  `-parallel-testing-enabled NO -collect-test-diagnostics never
  CODE_SIGNING_ALLOWED=NO`, with unique DerivedData, result bundle, and log
  under `/private/tmp/TaskovskyCalendarColorNative/`. The run log is
  `run.log`; the result bundle is `result.xcresult`.
- Result: **3 tests, 0 failures** — `testCalendarSourceColorSavesAndResetCanBeCancelled`
  (67.1s), `testCalendarColorPageShowsFolderHierarchyAndModeSwitch` (23.1s),
  `testCalendarViewOptionsRenderAndPersistAcrossRelaunch` (47.1s).
- Menu AX finding: the `calendarColor` value assertions (`List`/`Tag`/`Priority`)
  passed on device, so the Menu label value survives; the stable
  `calendarColorMode-*` leaf IDs selected the modes. No selector or behavior
  weakening was needed and none was made.
- Attachments were exported from the saved xcresult (`attachments/`, with
  `manifest.json` confirming device B263E8E7 and no failure association).
  The neutral inline Color page (Color By List, Inbox/Personal swatches,
  Projects folder with Work) and the open anchored menu (checked List, Tag,
  Priority) were inspected at pixel level. Fixtures are neutral QA samples
  only; no personal data and no TickTick imagery.

Origin/main PR139 (Repeat Type menu) was merged as `d25580b`, preserving the
C07 production code, Core tests, native tests, and this receipt alongside the
PR139 source, tests, docs, and assets.

## Open items

- VoiceOver and reduced-motion checks, and matched light-theme screenshots
  beyond the two inspected native attachments, remain pending (parent coordinate).
- Tag/Priority reference layouts beyond C07/C08 remain unverified; Tag rows and
  the Priority note are truthful local behavior, not reference equivalence.
- Exact-head hosted CI is still required before merge.

## Published QA evidence

The two unmodified neutral Simulator attachments are linked from tracker C07/C08. They were independently inspected before publication. Capture source is integrated `d25580b` plus the screenshot-only native attachment committed in `8b0e625`; production code is unchanged. Reference palette contents and exact visual matching remain unverified.
