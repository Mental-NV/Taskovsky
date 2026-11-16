# Calendar Style tiles structural parity (C10)

Status: implemented candidate; local tests, macOS release build with
signature, and iPhone compile passed. Native execution, screenshots, and
exact-head hosted CI remain with the parent; this is not a pixel-parity or
verified-native claim.

The observed mobile inventory C10 places **Item Style** previews for
**Modern ✓** and **Classic**, then **Show Item Icons**, on the pushed Style
page, with a **Heatmap** section showing **Hide** and **Show ✓** previews.
Back returns to View Options. Taskovsky previously exposed only
Filled/Outline pickers and Standard/Heatmap pickers. This slice adds genuine
Modern/Classic rendering with side-by-side preview tiles on the iPhone
Style page while preserving the old styles; Mac keeps its existing picker
(no Mac layout QA is available, so no Mac tile redesign is attempted).

## Element, wording, layout, behavior and uncertainty map

| Reference element | Taskovsky delta | Behavior | Uncertainty |
| --- | --- | --- | --- |
| Item Style page, side-by-side Modern/Classic preview tiles, selected blue checked circle | The iPhone Style page shows Modern and Classic tiles first, each rendering two neutral task rows through the shared production policy with a `checkmark.circle.fill` accent marker when selected; Mac lists all four choices with honest display titles in its existing picker | Tapping a tile (or picker row) stages the choice in the existing draft; nothing saves until outer Done | Exact reference tile size, spacing, typography and border are not measured; Taskovsky geometry is its own |
| Task+event samples in reference tiles | Tiles show two neutral tasks only ("Prepare agenda", "Review notes"); a caption states calendar events are unsupported | No event source is faked | Whether the reference tiles show one task plus one event, and their exact content, was not independently exercised |
| Modern pale fill + thin colored leading stripe | `modern` policy: fill opacity 0.12 (0.05 completed), 2pt tint stripe, no outline border; dark (primary) title/time, tint icons | Real production `CalendarEntryView` (Mac) and card modifiers (iPhone) read the same policy values as the tiles | Exact reference color/border hex and corner radius remain uncertain; opacities are Taskovsky choices |
| Classic stronger saturated block fill, no distinct stripe, dark text/icons | `classic` policy: fill opacity 0.55 (0.28 completed), no stripe, no outline; title/time primary, icons primary (dark) on the saturated block | Same shared-policy rendering path as Modern | Exact reference saturation, border and icon treatment remain uncertain |
| Week selection changing the same item's saturation | Not implemented; no selection-driven saturation was evidenced in Taskovsky source and none is invented | Cards keep their style fill regardless of selection | Whether the reference truly re-saturates the selected card, and by how much, is unknown |
| Show Item Icons route to a separate page | iPhone keeps the existing `Show Item Icons` pushed page untouched (master + task/note switches); Mac keeps its existing icon toggles | No Focus/Calendar icon toggles are invented; the C11 four-switch inventory stays out of scope | Reference Task/Calendar/Note/Focus rows remain unverified |
| Heatmap section, side-by-side Hide/Show month previews | The iPhone Style page shows Hide (Standard) and Show (Heatmap) tiles using the same overlap-count rule and cell treatment as the production Year grid (dots vs shading); Mac keeps its existing Standard/Heatmap picker | Hide keeps Standard dots; Show shades dates by item count via the existing count rule | Reference Hide is fully plain dates while Taskovsky Hide keeps Standard dots — an explicit non-equivalence, not a parity claim; exact reference shade scale is unverified |
| Back retains the draft into View Options; outer check applies | Unchanged staged-draft contract on both platforms: Back pops to View Options with the draft intact, outer Done runs the existing revision-checked save, outer Cancel discards | Dismissing the sheet with changed options and no explicit check is not an observed path, so the existing staged Cancel/Done contract is retained rather than reinterpreted | The reference outer-check glyph semantics were not independently exercised |
| Legacy Filled/Outline | New `modern`/`classic` cases added; `filled`/`outline` decode, encode, defaults and card treatments are byte-identical to before, always labeled "Filled (Legacy)" / "Outline (Legacy)" | Existing saved selections stay honest with no automatic migration; a saved legacy style shows a "Current saved style" note until changed | None; covered by round-trip tests |

## Data and compatibility

- `CalendarItemStyle` gains `modern`/`classic`; the default stays `filled`.
  Unknown `itemStyle` strings fall back to `filled` through the pre-existing
  `try?` decode path — the same as before, never to Modern/Classic.
  Stored values round-trip unchanged; no claim is made beyond the stored
  values and the specified opacity literals.
- `CalendarItemStyle.Rendering` is the single cross-platform source of
  truth for fill, stripe and outline treatment. Mac cards use
  `macFillOpacity` (completed Filled dims to 0.06, as before); iPhone cards
  use `phoneFillOpacity` (completed legacy Filled keeps prior fill 0.15
  with the platform overall 0.58 handling the dimming, as before). New
  styles use the shared policy value on both platforms. Outline keeps its
  stripe plus outline border on both platforms (0.5 Mac / 0.7 iPhone
  stroke, as before).
- Added a public `CalendarEntry` initializer matching the previous
  synthesized signature so preview tiles can construct neutral samples.
  No stored task, settings or projection semantics change: style and year
  choices do not alter projection entries, counts, recurrence or reminders.
- Exhaustive handling: every former `style == .filled` / `== .outline`
  branch now reads the shared policy; no `switch` on the enum existed.
  The Mac picker lists all four cases with honest display titles; the
  iPhone tiles enumerate primary + legacy explicitly.
- Tile containers carry no accessibility identifier of their own, so only
  the stable leaf IDs (`calendarItemStyle-modern/classic/filled/outline`,
  `calendarYearStyle-hide/show`) are actionable; existing native callers
  were updated to those leaf IDs.

## Verification

- `swift test --disable-sandbox`: all suites pass, including 8 new
  `CalendarItemStyleTests` (shared policy, legacy round-trip, new-style
  round-trip, no silent migration, year mapping, projection/settings
  invariance, icon-switch independence) and the 13 existing
  `CalendarDisplayOptionsTests`.
- `./scripts/build-app.sh`: macOS release build completed; ad hoc signature
  verified (`local.taskovsky.mac`, `Signature=adhoc`).
- `./scripts/build-ios-simulator-ci.sh`: iPhone app plus contract and
  navigation test bundles compiled (`TEST BUILD SUCCEEDED`); no tests
  executed.
- Native coverage is prepared but not run: the existing
  `testCalendarViewOptionsRenderAndPersistAcrossRelaunch` now taps the
  `calendarItemStyle-outline` and `calendarYearStyle-hide` leaf tiles, and a
  new `testCalendarStyleTilesSaveModernClassicAndLegacyAcrossRelaunch`
  stages Modern/Show save + relaunch with the actual heatmap grid mode,
  actual rendered Week screenshots under Modern and Classic, Back-retained
  Classic draft, outer Cancel discard, Classic/Hide save with actual Year
  Standard mode, and legacy Filled preservation across relaunches.
  Screenshots and device results remain with the parent coordinator.
- No live TickTick, no personal data, no Codex. Fixtures are neutral QA
  samples only. No push or PR was made; the branch stays isolated.
