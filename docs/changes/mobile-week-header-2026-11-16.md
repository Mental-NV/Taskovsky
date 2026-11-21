# Phone Calendar mode menu order and day-header timezone (C01/C02)

## Identity and decision

- Change ID and title: C01/C02 phone Calendar mode menu primary order plus hourly day-header timezone fix.
- Status: Implemented. Three new native cases passed; adjacent regressions passed 12/14, with both failures reproduced on unchanged base `808ff22`. Exact-head hosted CI and merge pending. Independent review found no source blockers.
- Owner or requesting instruction: Task instruction November 16, 2026 — bounded C01/C02 scope from the recorded live reference inventory `docs/ticktick-spec/mobile-surface-inventory-2026-11-14.md` (C02: List → Year → Month → Week ✓ → 3 Day → Day). Broad-first light-theme parity; no fresh TickTick observation claimed.
- Approval source and date: Same task instruction; base `808ff22`, branch `feat/mobile-week-header`.
- Base commit and affected platforms: `808ff22`; iPhone presentation plus one shared-domain formatting helper. No macOS UI change.
- Related business, UI, component, parity and deviation IDs: C01/C02 rows in [mobile-visual parity](../mobile-visual-parity.md); [live plan](mobile-live-parity-plan-2026-11-14.md); [surface inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md); [iPhone specification](../spec/iphone.md) (Calendar modes); prior receipts [3 Day mode](mobile-three-day-mode-2026-11-14.md), [repeat menu](mobile-repeat-menu-2026-11-16.md).

## Outcome and scope

The phone Calendar mode menu now lists the observed primary order List (existing agenda mode), Year, Month, Week, 3 Day, Day. Existing Multi-Day and Multi-Week functionality stays available in a separated "More views" extras area below the primary choices; selecting extras Multi-Day keeps the persisted count, extras Multi-Week keeps the persisted week count. Exactly one row carries the selected check in every reachable state. The visible and accessible menu name for the agenda mode is List; the shared `TaskCalendarMode.title` still returns "Agenda" (Mac unchanged) and the existing `Agenda` accessibility identifier is preserved on that row so current lookups keep working.

The hourly single-day header (`hourlyDayHeader`) now formats its weekday label and accessible date in the supplied calendar/timezone, consistent with the numeric day and identifier. Previously the weekday and accessible date used the device zone while the number and identifier used the Calendar zone, so near a midnight boundary the header could read Sunday the 8th next to the 9th.

Non-goals (explicitly unchanged): Week layout/density/gesture parity, pinned/scrolling changes, invented today visuals, anchored-menu geometry (the popover presentation is retained), Mac menu/titles, `TaskCalendarMode` case list or persistence schema, Dark appearance (deferred).

## Current behavior and intended delta

Pre-change source at `808ff22`: `calendarModeChooser` (`Mobile/App/TaskovskyMobileApp.swift`) showed a 3 Day shortcut button followed by `ForEach(TaskCalendarMode.allCases)` in enum order (Day, Week, Month, Year, Agenda, Multi-Day, Multi-Week) with labels from the shared title. `hourlyDayHeader` (`Mobile/App/MobileCalendarPreview.swift`) formatted weekday/accessible date in the device zone.

Intended delta:

| Aspect | Current | Intended |
| --- | --- | --- |
| Primary order | 3 Day, then enum order | List, Year, Month, Week, 3 Day, Day |
| Agenda naming | Visible/accessible "Agenda" | Visible/accessible "List"; `Agenda` kept as the row's accessibility identifier; shared title unchanged |
| Multi-Day/Multi-Week | Inline enum rows | Separated "More views" extras area; same selection semantics (persisted counts) |
| Selection check | Exactly one, with 3 Day distinguished from general Multi-Day | Same invariant, extended over the new layout |
| Day header | Mixed device/supplied zones | All four fields in the supplied calendar/timezone via shared `CalendarDayHeader` |
| Dismissal | Every choice closes the menu | Unchanged; covered by new tests |

## Data and component contract

No schema, migration or command change. `selectCalendarMode(_:at:multiDayCount:)` semantics are untouched, including the 3 Day failure message and the session fallback. `CalendarDayHeader` (`Sources/TaskovskyCore/TaskCalendar.swift`, already a domain source) is a pure value computed from the supplied `Calendar`; the view renders its four fields unchanged.

## UI and UX contract

Menu rows keep the existing 44 pt minimum height, `contentShape(Rectangle())`, trailing checkmark and `Selected`/empty accessibility value. The extras header is a non-interactive secondary caption, not a button. The List row is reachable both as `List` (visible label) and as `Agenda` (preserved identifier); the 3 Day row keeps `calendarThreeDay`; extras rows carry `calendarModeMultiDay` / `calendarModeMultiWeek`.

## Per-form element inventory (C01/C02)

### C01 — Hourly Week (header strip only; grid/density/gestures remain open)

| Element | Observed reference (inventory C01) | Taskovsky implementation | Gap / acceptance |
| --- | --- | --- | --- |
| Mode chooser button | Leading mode icon | `Calendar view` button, leading position | Present; placement covered by existing header test |
| Centered month label | Centered month | `calendarJumpToDate` centered month | Present |
| Trailing controls | Calendar icon + overflow | Week-overview toggle (Week only) + `Calendar actions` overflow | Present; overview order differs |
| Weekday/date strip | Weekday/date per column | `calendarDay-` headers via `CalendarDayHeader` in the Calendar zone | Timezone fix in this change; density/overlap gestures remain open |
| All-day band, time-zone gutter, hourly grid, floating + | Observed | Implemented (prior work) | Geometry/gestures remain open |

### C02 — Calendar mode menu

| Element | Observed reference (inventory C02) | Taskovsky implementation | Gap / acceptance |
| --- | --- | --- | --- |
| Entry | Leading mode icon → anchored menu | `Calendar view` → popover | Popover retained, not anchored geometry |
| Primary rows and order | List → Year → Month → Week ✓ → 3 Day → Day | Same order and labels; List selects the existing agenda mode | Implemented; matched pixel acceptance open |
| Selection mark | Selected check on Week | Trailing checkmark + `Selected` value; exactly one in all states | New native tests |
| Extras | Not observed (no Taskovsky Multi modes in reference) | Separated "More views" area with Multi-Day / Multi-Week, persisted counts | Taskovsky addition, honestly labeled |
| Dismissal | Backdrop dismissed | Choice selection and selected-row tap dismiss; backdrop dismissal not tested in this batch | New native tests |
| Return behavior | Alt modes not selected in inventory | Year selection persists across relaunch (tested); List relaunch persistence not tested in this batch | New native tests |

Unknown and not claimed: reference selection/persistence semantics beyond what the tests exercise, anchored-menu geometry, Week density/gestures.

## Acceptance cases

- Menu-01 order: primary rows read List, Year, Month, Week, 3 Day, Day strictly top-to-bottom; extras header plus Multi-Day/Multi-Week sit below; fresh Week session shows exactly one Selected row (Week).
- Menu-02 selection: choosing Year dismisses the menu, applies Year, reopening shows Year selected; tapping the selected row dismisses without change; relaunch keeps Year; choosing List applies the agenda mode (mode title still "Agenda") and reopening shows the List row selected with no other check.
- Menu-03 extras: extras Multi-Day applies the persisted five-day count (five `calendarDay-` headers) with the check on extras Multi-Day and not on 3 Day; extras Multi-Week applies with the check on Multi-Week and exactly one check overall.
- Header-01 domain: at the 2026-11-08T11:30:00Z midnight boundary, Auckland formatting yields weekday-Monday/day 9/identifier `calendarDay-2026-11-9` with the accessible date carrying the 9th; UTC yields day 8/`calendarDay-2026-11-8`; the two outputs differ.
- Header-02 evidence: on a Europe/Moscow device the pre-fix code rendered weekday "S" with accessible "Sunday, 8 November 2026" next to numeric 9/`calendarDay-2026-11-9`; the fixed helper renders all four fields in the supplied zone.

## Verification and release

- Domain: new `Tests/TaskovskyDomainTests/CalendarDayHeaderTests.swift` (3 tests: boundary resolution, cross-zone difference, midday consistency). Full `swift test --disable-sandbox`: 934 XCTest (Workspace 153, Mac 55, Domain 185, Core 541) + 38 Swift Testing, 0 failures. `./scripts/build-app.sh` exit 0 with `codesign --verify --deep --strict` exit 0. iPhone `build-ios-simulator-ci.sh` TEST BUILD SUCCEEDED.
- iPhone: owned Simulator only (`B263E8E7-F1A5-4407-894D-23FC224B1013`, Taskovsky Menu QA 1114, iPhone 13 Pro iOS 26.3.1; nonparallel, collect-test-diagnostics never). New tests 3/3 passed (`WeekHeaderRun1.xcresult`). Adjacent set 12/14: `testCalendarViews`, all three 3-Day tests, header placement, day strip, jump-date, agenda Show-more, show-details-across-Agenda-and-Month, week-overview navigation and month scroll pass; the two failures (`testCalendarAgendaCompletesChecklistAndUsesTaskLifecycleUndo` 44 pt float artifact; `testCalendarWeekOverviewDetailFilterAndRelaunch` line 481) reproduce identically on unmodified base `808ff22` (`WeekHeaderBase.xcresult`), so they are pre-existing and not regressions. First-failure, isolated-rerun and base logs/xcresults all preserved under `/private/tmp/TaskovskyWeekHeaderNative/`.
- Docs: this receipt, the C01/C02 tracker rows (now 38/46 with screenshots), `iphone.md` menu-order notes and the verification ledger update in the same change; six neutral screenshots exported and pixel-inspected, two placed with manifest SHA-256 entries. No push, PR or merge.
