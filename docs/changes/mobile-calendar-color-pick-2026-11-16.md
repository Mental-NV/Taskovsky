# Bounded C09 Calendar Color Pick (Taskovsky palette)

Status: implemented and natively verified for the three bounded Color tests;
independent review, exact-head hosted CI and merge remain with the parent.

The observed reference inventory (C09) pushes **Color Pick** from a source
swatch with six named families (Recommend/Macaron/Morandi/Rococo/Classic/
Memphis), eight circular swatches each, a slash on the first Recommend cell,
a thin current-color ring, and a separate Custom row opening the native
Grid/Spectrum/Sliders editor. Only `#35D870` was ever read exactly from the
reference; no other reference family color is known. Per the approved bounded
alternative, this slice does **not** reproduce the named families.

## Behavior contract

- Each Color page source row (Inbox, lists, tags) now pushes a **Color Pick**
  page instead of hosting the inline system picker. The row keeps its
  accessible name (`Inbox`, list/tag name as identifier), its current-value
  summary (`#HEX` or `Default`), its swatch preview, and its per-row
  **Default** reset (`Use default color for <name>`).
- The pushed page offers an honest **Taskovsky colors** section: a Default
  slash option (the source's own default color with a slash, ring-selected
  when no override is staged) plus the seven existing desktop user colors
  `#526BF5`, `#EC6574`, `#E7A548`, `#58A58B`, `#9C7BD5`, `#5BA7CC`,
  `#8A8F98` as circular swatches. The staged choice carries the observed
  thin selected ring and the `isSelected` trait; no extra checkmark is
  invented.
- A separate **Custom** row hosts the native `ColorPicker` (system
  Grid/Spectrum/Sliders). Arbitrary existing overrides are represented
  exactly: the Custom editor opens at the true current color, a selected
  **Current color `#HEX`** row appears for values outside the palette, and
  nothing is coerced toward the palette on open.
- Missing reference families are documented in this receipt and the C09
  tracker row, never in the product UI: no in-app footer discusses the
  reference families, and no decorative family buttons exist. The six
  unreproduced reference families are Recommend, Macaron, Morandi, Rococo,
  Classic and Memphis.
- Staging follows the outer draft only: picks write into
  `draft.sourceColors` (`CalendarColorSource.Overrides`, same source IDs and
  defaults). Pick-page Back keeps staged changes; outer Cancel discards them;
  outer Done commits them through the existing revision-checked save. This
  differs from the reference, where swatch selections appear to survive
  Back/outer dismissal with an unknown savepoint; the difference is kept
  explicit rather than weakening Taskovsky cancellation.
- No task, list or tag records are mutated. `colorBy` switches never clear
  other modes' overrides; archived/unavailable sources keep their overrides
  with no row. Storage keys and encoding are unchanged: no migration, no data
  loss. `PhoneEntityColor` remains the single hex bridge.

## Verification

- `testTaskovskyPaletteMatchesDocumentedDesktopColorsAndStoresExactly`
  (`Tests/TaskovskyCoreTests/CalendarDisplayOptionsTests.swift`): the shared
  palette equals the seven documented desktop colors, each normalizes through
  `Overrides`, and a palette pick stores exactly.
- Native `testCalendarSourceColorSavesAndResetCanBeCancelled`
  (`Mobile/UITests/ReadOnlyNavigationTests.swift`, `calendar-options`
  fixture): Default state, pick-page Default selection, a real `#58A58B`
  swatch click with selected ring, Back summary, outer Done, relaunch
  persistence, a staged `#EC6574` palette pick reverted by outer Cancel, a
  staged row-Default reset reverted by outer Cancel, then an arbitrary
  `#008122` custom round-trip through the native Sliders editor with the
  selected Current row, Back summary, outer Done, relaunch persistence of the
  exact hex with the selected Current marker and no palette selection, and
  finally a Default-swatch tap staged on the new page, verified through Back,
  outer Done and relaunch.
- Native `testCalendarColorPickKeepsListAndTagOverridesSeparate` (same file,
  `calendar-filter-hierarchy` fixture): real List (`Work` → `#526BF5`) and
  Tag (`Planning` → `#EC6574`) swatch clicks with rings, Back summaries,
  mode switches preserving both overrides, outer Done commit, and in-session
  reopen showing both.
- Existing `testCalendarColorPageShowsFolderHierarchyAndModeSwitch` and
  `testCalendarViewOptionsRenderAndPersistAcrossRelaunch` are unchanged and
  keep covering hierarchy rows, the Color By menu, the Priority note and the
  View Options persist path against the new row identifiers.
- Fixtures: the existing `calendar-options` and `calendar-filter-hierarchy`
  QA cases already carry non-palette colors (Inbox `#7C6CF2`, Work
  `#4670FA`, Personal `#30A77A`, Planning `#E6A53A`), so
  custom/arbitrary preservation is exercised with no new fixture.
- Native Simulator execution was not run in this session (coordinate later);
  the cases above are prepared and compile-verified only.

## Native run (owned device only)

- Device: the owned, already-booted simulator
  `B263E8E7-F1A5-4407-894D-23FC224B1013` ("Taskovsky Menu QA 1114"),
  destination pinned by ID. A second booted simulator (iPhone 13 Pro
  `ED2459ED`) was present but never targeted. No named/default or personal
  device was used, no personal data or settings, no Codex, no live TickTick.
- Command: `xcodebuild test` on `Mobile/TaskovskyMobile.xcodeproj`, scheme
  `TaskovskyMobile`, `-parallel-testing-enabled NO -collect-test-diagnostics
  never CODE_SIGNING_ALLOWED=NO`, with fresh DerivedData, result bundle and
  log per run. The iPhone compile gate was re-verified after the slash
  correction (TEST BUILD SUCCEEDED, no tests executed); the full `swift
  test` suite (541 tests, 0 failures) and macOS release/signature build
  remain green on identical SPM/Mac sources — the correction touches only
  the Xcode-only Mobile target.
- Run 1 (`/private/tmp/TaskovskyCalendarColorPickNative/`, log `run.log`,
  result `result.xcresult`): **3 tests, 0 failures in 175.9s** —
  `testCalendarSourceColorSavesAndResetCanBeCancelled` (106.4s),
  `testCalendarColorPickKeepsListAndTagOverridesSeparate` (46.1s),
  `testCalendarColorPageShowsFolderHierarchyAndModeSwitch` (23.4s).
  `xcodebuild` exit 0, `TEST SUCCEEDED`, 0 errors in the log. The bundle
  parses; `issues` holds 0 errors and 0 failures plus 2 benign runtime
  `_UIReparentingView` warnings with no failure association.
- Pixel inspection of the 5 exported attachments found one real defect: the
  Default option's SF Symbol slash did not render (magnified crop shows a
  solid swatch). Bounded correction: the slash is now drawn geometry
  (`PhoneDefaultSlash`, white 2.5pt diagonal), selected palette swatches
  keep the observed thin ring only, no checkmark was added.
- Run 2 (`/private/tmp/TaskovskyCalendarColorPickPalette2/`, fresh
  DerivedData/bundle/log): the single
  `testCalendarSourceColorSavesAndResetCanBeCancelled` (with one added
  `attach`, no assertion change) **passed in 106.3s**, exit 0,
  `TEST SUCCEEDED`, 0 log errors. The re-captured pick page shows the white
  diagonal slash on the Default swatch, the thin blue ring on the selected
  `#58A58B` swatch, and no checkmark.
- Published captures (all inspected at pixel level, neutral QA fixtures
  only, no personal data): pick page with selected palette swatch and
  visible Default slash
  (`assets/mobile-parity/2026-11-16/c09-color-pick-palette.png`), pick page
  with selected Current `#008122` custom row
  (`assets/mobile-parity/2026-11-16/c09-current-custom.png`), saved source
  summary with Inbox `#58A58B`
  (`assets/mobile-parity/2026-11-16/c09-color-summary.png`). The earlier
  hierarchy, Color By menu and staged-across-modes attachments remain in
  their result bundles as run evidence; the C07/C08 rows keep their prior
  checkpoint images.

## Fidelity limitations (explicit, not claims)

- The reference named families (Recommend, Macaron, Morandi, Rococo,
  Classic, Memphis) are not reproduced; only `#35D870` was ever read
  exactly from the reference and no family palette is invented.
- Our staged semantics differ from the reference on purpose: picks stage
  into the outer draft (Back keeps, outer Cancel discards, outer Done
  commits) instead of the reference's unknown savepoint. This difference is
  kept explicit rather than weakening Taskovsky cancellation.
- Exact reference swatch geometry, ring weight and typography remain
  unverified; this is structural parity, not a pixel-perfect claim.

## Open items

- VoiceOver and reduced-motion checks, exact-head hosted CI and merge
  remain with the parent.
- No further native execution is planned on this worker; the Simulator is
  released after this verified run.
