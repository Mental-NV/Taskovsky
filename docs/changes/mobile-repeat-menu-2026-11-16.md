# D12 Repeat preset menu (mobile)

## Identity and decision

- Change ID and title: D12 Repeat preset menu, Schedule Date tab.
- Status: Implemented; eight bounded native cases passed. Exact-head hosted CI and merge pending.
- Owner or requesting instruction: D12 slice of the 46-form mobile Tasks/Calendar parity plan; user priority is light-theme broad structural similarity before pixel polish.
- Approval source and date: Task instruction November 16, 2026 (live TickTick observation of Schedule > Date > Repeat on an all-day task dated Thursday November 12; no pixel-calibrated image supplied).
- Base commit and affected platforms: `feat/mobile-repeat-menu` on main `4275fa9`; iPhone presentation plus a pure shared-domain preset helper. No macOS UI change.
- Related business, UI, component, parity and deviation IDs: D12/D13/D14 rows in [mobile-visual-parity](../mobile-visual-parity.md); [live plan](../changes/mobile-live-parity-plan-2026-11-14.md); [surface inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md) (D12/D13/D14); [iPhone specification](../spec/iphone.md) (schedule staging); prior receipts [schedule options](mobile-schedule-options-2026-11-15.md), [repeat frequency](mobile-repeat-frequency-2026-11-15.md), [repeat type](mobile-repeat-type-2026-11-15.md).

## Outcome and scope

The ordinary Date-tab Repeat control moves toward the live-observed menu structure while keeping working recurrence logic and custom data. The Repeat page lists presets in exact observed order with live-derived labels, marks the current selection with blue text and a trailing checkmark, stages a preset tap and returns to the Schedule root (the page analog of the reference menu closing), and routes Custom to the existing Custom Repeat sheet.

In scope: preset rows None / Daily / Weekly ({Weekday}) / Monthly (the {ordinal} day) / Yearly ({day} {Mon}) / Every Weekday ({Mon} - {Fri}) / Custom (trailing chevron); weekday/month/year derivation from the staged due date in the staged calendar/zone; current-selection check; preset staging through the unchanged `TaskScheduleEdit.selectSimpleRepeat`; Custom route with the unchanged seed/cancel behavior; draft summary update (`Every week on Thu` for weekly, preset label otherwise); preservation of the existing custom branch, replace-with-simple confirmation, end-date condition, outer Cancel/Done and duration/timed flows.

Non-goals (explicitly unchanged): no anchored-popup geometry (the pushed Repeat page is retained, as in the D10 reminder precedent); no grid occurrence highlight on the Date picker; no Repeat Ends summary row on the Schedule root (the existing End-by-date toggle stays on the Repeat page); no Custom sheet toolbar restyle (Cancel/Done kept); no new recurrence, anchor, end-count, notification, sync, recovery, Background/Share/Print or accessibility-layout work.

## Current behavior and intended delta

Pre-change source at `4275fa9`: `PhoneScheduleSheet.repeatSection` (`Mobile/App/PhoneScheduleSheet.swift`) shows an inline `Picker` over `RepeatRule.allCases` (order none, daily, weekdays, weekly, monthly, yearly) plus an End-by-date toggle and a `Custom repeat` button. The Repeat summary is the capitalized raw value (`Weekly`). The Repeat page is pushed from a `NavigationLink`.

Intended delta:

| Aspect | Current | Intended |
| --- | --- | --- |
| Row order | Enum order (weekdays third) | Reference order: None, Daily, Weekly, Monthly, Yearly, Every Weekday, Custom |
| Labels | Static capitalized raw values | Derived per staged due date/zone: `Weekly (Thursday)`, `Monthly (the 12th day)`, `Yearly (12 Nov)`, `Every Weekday (Mon - Fri)` |
| Selection mark | Picker check | Blue (`accentColor`) label text plus trailing checkmark and selected trait, matching the D10 preset-row pattern |
| Tap behavior | Inline picker stays on page | Stage via `selectSimpleRepeat` and pop to the Schedule root, mirroring the observed menu close |
| Custom | Text button `Custom repeat` | `Custom` row with trailing chevron opening the same sheet with the same seed; Cancel still discards without touching the staged preset |
| Custom rule present | Custom text, Edit, Replace-with-simple confirmation | Unchanged; the preset menu only renders when no custom rule is staged, so opening Repeat never converts a custom rule |
| Summary | `Weekly` | `Every week on Thu` for weekly (observed); the preset menu label for daily/monthly/yearly/weekdays; `None` and the custom short label unchanged |

New pure domain helper `RepeatPreset` (`Sources/TaskovskyCore/RepeatPreset.swift`, registered in `Package.swift` `domainSources` so the phone's `TaskovskyDomain` product includes it): reference-ordered cases, menu-label derivation, draft-summary derivation, `RepeatRule` mapping and current-preset detection (nil when a custom rule is staged). No recurrence, anchor, end-date, persistence or notification semantics change.

## Data and component contract

No schema, migration or command change. `TaskScheduleEdit.selectSimpleRepeat` / `selectCustomRepeat` / `repeatEnd` semantics are untouched, including clearing `repeatEnd` on `.none` and the existing custom-replacement confirmation path. Unsupported/advanced custom-rule payloads (specific dates, ordinals, workdays, skip-weekends, counts, anchors) keep rendering through the existing custom branch and survive Repeat opens, Custom Cancel, nested Back and outer Cancel. Staged edits still commit only through outer Done; outer Cancel still discards the whole draft including time, reminder and repeat changes.

Label derivation preconditions: a staged due date (the Repeat section only renders when `hasDate` is set) and the staged calendar/zone. Names come from the calendar's full/short weekday and short month symbols, so non-English locales get locale names inside the fixed reference sentence shapes; the `12 Nov` day-first order and the English `the … day` / `Mon - Fri` shapes intentionally follow the observed English reference and are not claimed locale-correct.

## UI and UX contract

Layout: rows in the existing Repeat `Section`, full-width buttons, 44 pt minimum hit area, `contentShape(Rectangle)`, trailing checkmark or chevron; Custom row keeps identifier `scheduleCustom`; preset rows use `scheduleRepeatPreset-<rawValue>`; selected rows carry the selected trait and `Selected` value. Typography/color follow the D10 preset-row pattern (primary text, `accentColor` when selected). The Custom chevron uses `chevron.right` in secondary style. Navigation: the Repeat row becomes a button driving `navigationDestination(isPresented:)` so a preset tap can return to the Schedule root; the pushed page keeps the `Repeat` title and Back dismissal without changes. The existing end-date toggle, `Last day` picker, custom branch, Custom sheet, replace confirmation, duration cards, Time popover, reminder page, skip-occurrence and error paths are untouched.

## Acceptance cases

- Repeat-01 opens: Repeat row opens the menu page with the seven rows in reference order and the staged preset checked (None checked on a non-repeating dated task).
- Repeat-02 labels: on a Thursday the 12th of November the rows read `Weekly (Thursday)`, `Monthly (the 12th day)`, `Yearly (12 Nov)`, `Every Weekday (Mon - Fri)`; ordinals cover 1st/2nd/3rd/21st/22nd/23rd/31st at domain level.
- Repeat-03 preset select: tapping Weekly pops to Schedule, the Repeat summary reads `Every week on Thu`, reopening shows Weekly checked, outer Done persists and reload shows the same summary.
- Repeat-04 menu dismissal: Back from the menu leaves the staged draft unchanged.
- Repeat-05 custom route and cancel: Custom opens the existing sheet seeded from the staged weekly state (By Due Dates, Every 1 Week, Thursday selected); Cancel returns to the menu with the prior preset still checked and stages nothing.
- Repeat-06 custom preservation: with a saved custom rule, Repeat opens on the existing custom branch (Edit/Replace), never on a converted simple preset; opening and backing out changes nothing.
- Repeat-07 outer Cancel: staging Weekly then outer Cancel restores the original schedule (Time/Reminder/Repeat None in the observed configuration).
- Repeat-08 end conditions: the existing End-by-date toggle and staged end date survive preset switches that keep a repeat; selecting None clears the end as before.

Unobserved and not claimed: saving over an existing custom rule via a preset (the UI still requires the explicit replace confirmation), engine occurrence highlighting on the Date grid, anchored menu placement/geometry, and the reference `Repeat Ends / Never` root row.

## Verification and release

- Domain: new `Tests/TaskovskyDomainTests/RepeatPresetTests.swift` (order, derivation, ordinals, summary, selection round-trip, custom-preservation detection, save/reload through `TaskScheduleEdit.applying`); full `swift test --disable-sandbox`, `./scripts/build-app.sh`, and the existing recurrence suites must stay green.
- iPhone: `scripts/build-ios-simulator-ci.sh` with a unique output directory; six new XCUITests plus two existing custom/nested-cancel regressions passed in the final owned Simulator run below. The Custom cancellation case starts from None; the observed Weekly-to-Custom seed is not separately certified by this run.
- Docs: this receipt, the D12 tracker row and verification pointers update in the same commit; no pixel-perfect or full-D12 claim. No push, PR or merge.

## Completion record

Implementation `5040487` was corrected in `311e4f5` after independent review found an Optional `.none` mapping that hid None, a duplicate Custom route, and an invalid native assertion comparing a full schedule label with a Repeat summary. Regression coverage now explicitly unwraps every simple preset mapping. Integration `4d92691` preserves main/C09 `d7ea3396` and passed independent source review.

The original implementation worker reported 929 XCTest with 0 failures plus 38 Swift Testing passed, macOS release/signature passed, and iPhone build-for-testing succeeded. These are local pre-integration receipts, not a fresh hosted exact-head claim. Final hosted CI remains required.

### Native acceptance, November 16

Final Run 3 tested production `4d92691` plus a test-only correction revealing the virtualized Repeat row before two post-relaunch value assertions. No product code changed for this correction. `xcodebuild test` completed with exit 0 and **8 tests passed, 0 failures, 0 skipped** in 281.795 seconds. The xcresult summary reports Passed and no runtime warnings. Device: owned iPhone 13 Pro Simulator, iOS 26.3.1, `B263E8E7-F1A5-4407-894D-23FC224B1013`; native slot released afterward. Explicit nonparallel execution and disabled diagnostic collection; no other device or personal data used.

Evidence: `/private/tmp/TaskovskyRepeatMenuNative/run3.log` and `D12RepeatMenuRun3.xcresult` in that directory. Six new cases cover menu ordering/derived labels/None check, Weekly selection and reload, menu dismissal/outer Cancel, Custom cancel from None, saved custom preservation, and repeat-end preservation/None clearing. Existing custom creation/removal and nested/outer cancellation cases also passed.

Earlier Run 1 had six passes and two failures at off-screen post-relaunch summary queries. Run 2 added an incorrect wait before scrolling and regressed to seven failures. Both bundles remain preserved. The final correction restores the existing scrolling helper and reveals the two actual target rows before retaining their exact value assertions. It does not weaken persistence checks or modify product behavior.

Final neutral screenshots were exported unchanged from Run 3 and inspected at actual pixels: [preset page](../assets/mobile-parity/2026-11-16/d12-repeat-presets.png), [staged Weekly summary](../assets/mobile-parity/2026-11-16/d12-weekly-summary.png). The fixture is Monday November 9, so its derived labels intentionally differ from the Thursday November 12 reference observation. Hashes/dimensions are in the adjacent manifest.

Still unverified: matched anchored geometry, date-grid recurrence highlights, Repeat Ends root row, reference Custom toolbar icons, Weekly-to-Custom seed in this native batch, and physical-device/locale-specific fidelity. D12 stays Partial; this is not pixel-perfect or full-parity acceptance.
