# Phone Calendar View Options primary structure (C06)

## Identity and decision

- Change ID and title: C06 phone Calendar View Options primary row order and staging.
- Status: Implemented at source `a638aed` (base `5803158`). One new native test passes; adjacent set 13/14 with the single failure reproduced on the untouched base (pre-existing, out of scope). Exact-head hosted CI and merge pending; independent source/evidence review passed with no blocking findings.
- Owner or requesting instruction: Task instruction November 16, 2026 — bounded independent C06 structural slice from the recorded reference inventory `docs/ticktick-spec/mobile-surface-inventory-2026-11-14.md` (C06: tall grouped sheet Color → Style → Show Details → Show Completed → Show Checklist Item → Show All Repeat Cycles → Show Declined Events → Show Focus Records → Additional Time Zone → Apple Health Data; top-right ✓ returns to Week). Broad-first light-theme phone Tasks/Calendar parity. No fresh TickTick observation claimed.
- Approval source and date: Same task instruction; base `5803158`, branch `feat/mobile-view-options`.
- Base commit and affected platforms: `5803158`; iPhone presentation only. No macOS UI change.
- Related business, UI, component, parity and deviation IDs: C06 row in [mobile visual parity](../mobile-visual-parity.md); [live plan](mobile-live-parity-plan-2026-11-14.md); [surface inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md); [iPhone specification](../spec/iphone.md) R21/R22 mapping (Show Details, Additional Time Zone, excluded rows, retained desktop extras); [details contract](mobile-calendar-details-2026-11-10.md); [zone contract](mobile-calendar-zone-settings-2026-11-15.md); [navigation contract](mobile-calendar-options-navigation-2026-11-15.md); [style contract](mobile-calendar-style-tiles-2026-11-16.md); [color contract](mobile-calendar-color-page-2026-11-16.md).

## Outcome and scope (intended)

The phone Calendar View Options sheet presents the supported primary controls in the observed reference order — Color, Style, Show Details, Show Completed, Show Checklist Item (exact singular wording), Show All Repeat Cycles, Additional Time Zone — followed by the retained Taskovsky extras (configurable Multi-Day/Multi-Week ranges, all-day rows, folded-hours cutoffs) in a clearly separated extras area on the same sheet. The primary top-right control becomes a checkmark with the Done accessibility label (identifiers `calendarPreferencesDone` / `calendarPreferencesCancel` retained); Cancel behavior and staged draft semantics are unchanged. Nested Color/Style/Show-Item-Icons pages, the staged zone sheet, the original preferences and the expected-revision save/failure behavior are preserved. No business-logic change: no dropped filters, no invented rows.

Non-goals (explicitly unchanged): declined events, focus records, external calendars, Apple Health (no desktop implementation — excluded, not reproduced); exact reference typography/colors/geometry; nested-page contents; save/failure plumbing; Mac presentation.

## Current behavior and intended delta

Pre-change source at `5803158` (`Mobile/App/PhoneCalendarPreferences.swift` `display`): Appearance section (Color, Style), then a Visible Items section ordered Show Completed, Show Checklist Items (plural), Show All Repeat Cycles, Show Details (last), then Range, Time Zone Rulers, and Folded Hours sections. The display route uses a text "Done" button; the filter route already uses a checkmark with the Done label.

Intended delta:

| Aspect | Current | Intended |
| --- | --- | --- |
| Visible Items order | Completed, Checklist (plural), Repeats, Details | Details, Completed, Checklist Item (singular), Repeats |
| Checklist wording | "Show Checklist Items" | "Show Checklist Item"; identifier `calendarChecklist` unchanged |
| Time Zone placement | Below Range | Primary row directly after Repeats |
| Extras | Range/Fold sections interleaved with primary | Same controls inline in a separated "Taskovsky Extras" area below primary |
| Details helper | "Show task time and list in Agenda and Month." | Unchanged (truthful narrower scope) |
| Repeats footer | "Future repeats are previews. Open the repeating task to edit its schedule." | Unchanged |
| Top-right Done | Text "Done" | Checkmark image, accessible label Done; identifier unchanged |
| Cancel | Text "Cancel" | Unchanged |
| Business logic / staging / identifiers | — | Unchanged; all existing identifiers survive |

## Data and component contract

No schema, migration or command change. The outer staged `draft` (`TaskCalendarOptions`) still commits only through `saveCalendarOptions(_:expected:)` on Done; Cancel discards; the save-failure path keeps the error banner (`calendarPreferenceError`) and the draft. No Mac code touched.

## UI and UX contract

Primary rows keep the existing Form rows, toggle semantics and accessibility identifiers; only order, one label string and the Done glyph change. Extras stay on the same sheet (no new navigation), reachable by scroll, under a "Taskovsky Extras" header with a guidance footer. The extras were not observed in the sampled C06 inventory row; no universal claim is made about panels outside that sample. VoiceOver order follows the new visual order. The 44 pt minimum target rule is unchanged.

## Per-form element inventory (C06)

Observed reference values come from the recorded inventory row C06 only; no fresh observation was made. "Reference control" states below are the inventory's recorded values, not Taskovsky defaults.

| # | Reference control (inventory C06) | Taskovsky implementation | Disposition |
| --- | --- | --- | --- |
| 1 | Color → pushed page | `calendarColorPage` → Color page (Color By menu + inline swatches) | Supported; order position 1; nested page unchanged |
| 2 | Style → pushed page | `calendarStylePage` → Style page (Modern/Classic tiles, legacy menu, heatmap, `calendarIconsPage`) | Supported; order position 2; nested pages unchanged |
| 3 | Show Details off | `calendarDetails` toggle, first in Visible Items; helper "Show task time and list in Agenda and Month." | Supported; order position 3; narrower Agenda+Month scope kept truthful |
| 4 | Show Completed on | `calendarCompleted` toggle, second in Visible Items | Supported; order position 4 |
| 5 | Show Checklist Item off | `calendarChecklist` toggle relabeled to exact singular "Show Checklist Item", third in Visible Items | Supported; order position 5; label-only change |
| 6 | Show All Repeat Cycles on | `calendarRepeats` toggle, fourth in Visible Items; footer keeps preview semantics | Supported; order position 6 |
| 7 | Show Declined Events off | None | Excluded: no external-event implementation |
| 8 | Show Focus Records off | None | Excluded: no focus-record implementation |
| 9 | Additional Time Zone → settings page | `calendarZoneSettings` staged zone sheet, directly after Repeats | Supported; order position 7; staged sheet unchanged |
| 10 | Apple Health Data | None | Excluded: no Health implementation |
| 11 | Top-right ✓ returns to Week | Checkmark button, accessible label Done, identifier `calendarPreferencesDone`; Cancel retained (`calendarPreferencesCancel`) | Supported; staged save/Cancel semantics unchanged |
| 12 | (not observed in sampled C06) Multi-Day 2–14 / Multi-Week 2–6 ranges | Retained inline in separated Taskovsky Extras area | Taskovsky addition, honestly labeled; not reset or lost |
| 13 | (not observed in sampled C06) All-day rows (`calendarAllDayRows`) | Retained inline in Taskovsky Extras area | Taskovsky addition; Automatic + 1–12 rows unchanged |
| 14 | (not observed in sampled C06) Folded-hours cutoffs + reset (`calendarFoldPreference-*`) | Retained inline in Taskovsky Extras area | Taskovsky addition; staged cutoffs/reset unchanged |
| 15 | (not observed in sampled C06) Year Standard/Heatmap, item icons | Stay on the Style page (unchanged) | Taskovsky additions per iphone.md; not moved or dropped |

Unknown and not claimed: exact reference header/footer grouping, typography, colors, sheet height, and any reference interaction semantics beyond the staged save/Cancel behavior covered by tests.

## Acceptance cases

- C06-01 order: Color, Style, Show Details, Show Completed, Show Checklist Item (singular label), Show All Repeat Cycles, Additional Time Zone read strictly top-to-bottom; extras (all-day rows, fold preferences) sit below in a labeled extras area. No declined/focus/health/calendar rows exist.
- C06-02 staging: flipping toggles then Cancel keeps saved scope; flipping then Done applies; an unchanged nested Style visit plus Back retains the staged toggles in the new test. A combined nested change (legacy style) plus toggles committing together on Done is covered by the existing adjacent `testCalendarViewOptionsRenderAndPersistAcrossRelaunch` (legacy Outline + icon/completed/checklist/repeat staging, Done, relaunch), which passed here — not by the new test.
- C06-03 persistence/interruption: Done then reopen shows saved values; Done then terminate/relaunch keeps them; repeated open → Cancel → reopen shows the saved state; a failed save keeps the error banner and the draft.
- C06-04 extras: all-day rows and both fold pickers remain directly reachable on the same sheet and still apply (all-day-rows regression passed; the fold-cutoff timeline case fails identically on base and remains open).

## Verification and release

- Package tests: full `swift test --disable-sandbox` exit 0 — 934 XCTest (Workspace 153, Mac 55, Domain 185, Core 541) + 38 Swift Testing, 0 failures. Log `/private/tmp/TaskovskyViewOptionsNative/swift-test2.log`.
- Release and signature: `./scripts/build-app.sh` exit 0; `codesign --verify --deep --strict build/Taskovsky.app` exit 0. Log `/private/tmp/TaskovskyViewOptionsNative/build-app2.log`.
- iPhone compile: `./scripts/build-ios-simulator-ci.sh` exit 0, `TEST BUILD SUCCEEDED`. Log `/private/tmp/TaskovskyViewOptionsNative/ci-ios2.log`.
- Native tests (new): `testCalendarViewOptionsPrimaryOrderStagingAndExtras` 1/1 passed on the owned Simulator (`B263E8E7-F1A5-4407-894D-23FC224B1013`, Taskovsky Menu QA 1114, iPhone 13 Pro, iOS 26.3.1; `-parallel-testing-enabled NO`, `-collect-test-diagnostics never`). `C06Run2.xcresult`, log `C06Run2.log`.
- Native tests (adjacent): 13/14 passed (`C06Adjacent.xcresult`, log `C06Adjacent.log`). Passing: header/overflow placement, source-color save/reset, color-pick list/tag separation, color-page hierarchy/modes, all-day rows relaunch, checklist menu with hidden icons and completed rows, details across Agenda and Month, render/persist relaunch, style tiles Modern/Classic/legacy relaunch, rulers four-limit staging, save-failure draft retention, zone child/parent Cancel staging, zone-off persistence. Failing: `testCalendarFoldCutoffsDragAndPreferenceSurviveRelaunch` (`calendarHourBand-early` not found on the Day timeline, 8 s in, before View Options opens). Isolated rerun on this branch fails identically (`C06FoldRerun.xcresult`); the same single test also fails identically on the untouched base `5803158` in a separate clean worktree (`C06FoldBase.xcresult`, log `C06FoldBase.log`), so it is pre-existing/environmental and not a regression from this change. It stays open; no broad fix attempted.
- Screenshots: two unmodified 1170×2532 exports from `C06Run2.xcresult` (`C06Run2Screens/`), agent pixel-inspected (primary hierarchy + extras; neutral `calendar-options` fixture; no personal data; parent inspected both final images), placed as `c06-view-options-primary.png` / `c06-view-options-extras.png` with manifest SHA-256 entries.

Still unverified: matched reference typography/geometry, backdrop dismissal, List relaunch persistence for the mode menu (unchanged scope), dark appearance (deferred), physical-device rendering, exact-head hosted CI and independent re-review. The PR156 baselines (Agenda hit-target float artifact; Week detail-filter task absent) were not rerun here and stay open. No commit, push, PR or merge (handled by parent). The owned simulator was left booted and otherwise untouched; no other simulator, device, signing setting or reset was touched. Native slot retained under `/private/tmp/TaskovskyViewOptionsNative/` with all logs, xcresults and exports.

Final-source receipt: source `a638aed` contains the corrected extras guidance (verified visually, not by an exact-text assertion). Full package/release/compile and focused native Run2 passed after that correction; the adjacent 13/14 run predates only footer wording and test commentary, with unchanged behavioral wiring. Run1 and the baseline/rerun failures remain retained. An evidence-only provider retry failed; no source changes followed Run2. Both final PNGs were exported from Run2 and inspected directly. Independent source/evidence review passed; exact-head CI remains the merge gate.
