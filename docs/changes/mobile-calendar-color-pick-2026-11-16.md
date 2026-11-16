# Bounded C09 Calendar Color Pick (Taskovsky palette)

Status: implemented candidate; full `swift test`, macOS release/signature and
iPhone compile-only checks recorded below. Native Simulator execution,
screenshots and independent review remain with the parent.

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
  `#8A8F98` as circular swatches. The staged choice carries the selected
  ring, checkmark and `isSelected` trait.
- A separate **Custom** row hosts the native `ColorPicker` (system
  Grid/Spectrum/Sliders). Arbitrary existing overrides are represented
  exactly: the Custom editor opens at the true current color, a selected
  **Current color `#HEX`** row appears for values outside the palette, and
  nothing is coerced toward the palette on open.
- Missing reference families are explicitly documented, not faked: the
  palette section footer states that only Taskovsky colors are offered and
  names the six unreproduced reference families. No decorative family buttons
  exist.
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
  fixture): Default state, pick-page Default selection, palette disclosure
  note, a real `#58A58B` swatch click with selected ring, Back summary,
  outer Done, relaunch persistence, staged Default reset reverted by outer
  Cancel, then an arbitrary `#008122` custom round-trip through the native
  Sliders editor with the selected Current row, Back summary and outer Done.
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

## Open items

- Native Simulator runs of the three Calendar color tests, inspected
  screenshots, VoiceOver/reduced-motion checks and independent review remain
  with the parent.
- Exact-head hosted CI is still required before merge.
- Reference pixel matching (swatch geometry, ring weight, Custom row layout)
  remains unverified; this is structural parity, not a pixel claim.
