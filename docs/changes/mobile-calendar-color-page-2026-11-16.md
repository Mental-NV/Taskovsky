# Mobile Calendar Color page structural parity (C07/C08)

Status: implemented candidate, local tests and compile gates passed; native Simulator run pending with parent.

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
- Native UI coverage was updated but NOT run here: the existing
  `testCalendarSourceColorSavesAndResetCanBeCancelled` now exercises the
  flattened page (inline Inbox pick, save, relaunch, reset, Cancel, Priority
  note, Tag customize, Done), and a new
  `testCalendarColorPageShowsFolderHierarchyAndModeSwitch` covers inline
  Inbox/list/folder rows and List→Tag→Priority switching on the
  `calendar-filter-hierarchy` fixture. Simulator execution, screenshots, and
  independent review remain with the parent; this is not a pixel-parity claim.
- No live TickTick, no personal data, no Codex. Fixtures are neutral QA
  samples only.

## Open items

- Actual Simulator navigation of the new menu/rows, VoiceOver and reduced-motion
  checks, and matched light-theme screenshots are pending (parent coordinate).
- Tag/Priority reference layouts beyond C07/C08 remain unverified; Tag rows and
  the Priority note are truthful local behavior, not reference equivalence.
- Exact-head hosted CI is still required before merge.
