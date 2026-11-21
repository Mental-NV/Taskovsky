# Mobile Tasks and Calendar: live parity plan

**Historical plan.** This records the November 14–15 observations and original breadth-first queue. The [current workflow](../spec/workflow.md#scope-and-delivery) supersedes its sequence and estimates; use the [current tracker](../mobile-visual-parity.md) for evidence and status.

## Current delivery priority: core features first

User direction (November 15, 2026): **Background chooser and Share / Print are explicitly deferred until core Tasks and Calendar features are finished.** Keep these surfaces in the later-work backlog, not the active core-parity implementation queue or core completion gate. This is a deferral, not a claim that they are implemented or verified, and it does not authorize new external integrations. Revisit both after core feature completion.

User direction (November 14, 2026): defer accessibility-specific layouts and accessibility-layout polishing until core Tasks and Calendar features are finished. Prioritize ordinary light-theme task/list/board/detail/schedule and Calendar workflows, observed menu/dialog structure, and the largest verified parity gaps. Preserve existing accessibility support and prevent regressions in controls changed by core work, but do not open separate accessibility-layout enhancements or treat pre-existing large-text polish gaps as new core scope. Revisit the deferred accessibility-layout backlog after core feature completion. This does not remove safety, data-integrity, functional testing, independent review or exact-head CI gates.


Status: **Observed gaps and proposed implementation queue, not completed parity.**

The user requested an overall near-pixel-perfect mobile Tasks/Calendar comparison and prioritized implementation plan. This November 14 audit complements the [macro work map](ui-macro-parity-plan-2026-11-13.md) and [iPhone specification](../spec/iphone.md). Light theme only; preserve existing dark support. Sync, local-file recovery polishing, real notification authorization and external integrations remain deferred.

## Evidence and limits

- Live reference: physical iPhone 13 Pro, iOS 27.2.1, TickTick through iPhone Mirroring; app version, text size, display zoom and capture-to-point scale were not recorded. No calibrated pixel measurements yet.
- User explicitly approved Mirroring window screenshots in Taskovsky Codex. Live screenshot and coordinate interaction succeeded; this is a narrow changed capability, not blanket permission for other capture/settings changes.
- Audit: existing Taskovsky Codex chat, turn `01a1dbb8-f07b-7052-ba00-cfb5dc6c8ae3`, November 14, about five minutes. Live frames are in its Computer Use trace, not durable repository image assets. Private task titles are omitted here; do not publish personal reference images without suitable sanitization/authorization.
- Read-only navigation used existing data, not an equivalent neutral fixture. A staged schedule draft was cancelled; original date returned. Final view restored to Today → Group & Sort, Priority grouping / Tag sorting. No task edit submitted. Computer Use stopped.
- Source baseline for this plan: main `affa52caf00b1174951b33168dc5e8cd3c9e27b2` after PR96 Priority board and PR97 Sort & Group integration. User-installed app was not verified or updated. Existing native screenshots below precede the integration; they do not prove new-head native acceptance.
- Reference Kanban was not entered in this pass. Month/Day rendering, gestures, exact progress visibility rules, sort persistence/tie-breaking and numerical geometry remain unverified. Do not infer absence of a feature from one screen.

### Comparison screenshot inventory (local evidence, not portable links)

These existing Taskovsky Simulator images were shown in the same Codex chat. Paths are evidence locators on the connected Mac, not repo assets or claimed user downloads:

| Evidence | Locator | Provenance / limit |
| --- | --- | --- |
| Priority board populated | `/private/tmp/TaskovskyPriorityQA-screens/4F24A83F-49F2-4529-B98C-8BB4837E43AD.png` | PR96 native QA; not live TickTick Kanban comparison |
| Sort & Group normal | `/private/tmp/TaskovskySortSheetQA-bounds-screens/67BD79AB-3537-48DC-943D-80F55A0CE524.png` | Native-tested PR97 source `40759b8`; Today visible behind sheet |
| Sort & Group large text | `/private/tmp/TaskovskySortSheetQA-bounds-screens/33EEEA25-D813-45C3-A45E-A90F3C852400.png` | Same source; footer reachability, not reference large-text parity |

Next visual acceptance must archive sanitized matched-state captures with device, logical viewport, capture scale, safe areas, text size, locale, timezone and source SHA. Current comparison is qualitative.

## Expanded menu/dialog inventory

The [46-state Tasks/Calendar inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md) records entry paths, labels, presentation and dismissal, plus ten grouped unobserved branches. This expands the initial qualitative audit, not its pixel/behavior acceptance. Calendar has dedicated coverage; implementation begins with the confirmed drawer gap while further matched evidence is collected.

## Per-form element and behavior contract

User direction (November 15, 2026): inspect and specify **all UI elements in each active form/state**, then implement the closest evidence-backed match in placement, size, wording, interaction and underlying business logic. General similarity means the complete structure and working behavior, not merely a recognizable shell. Near-pixel-perfect polishing is the final stage, after broad core coverage.

Use the stable IDs in the [46-state tracker](../mobile-visual-parity.md). For each active state, add a per-form element table to its bounded change specification before implementation; link it from the tracker. Include header/navigation, every visible control and label, content/empty state, menus and submenus, dialogs/popups, footer, keyboard and overlays. Enumerate conditional elements and their trigger states rather than treating one screenshot as exhaustive.

| Required field per element | Record before implementing or accepting the form |
| --- | --- |
| Identity and evidence | Stable form/element ID, reference entry path, capture/observation locator, device/build, viewport, theme, text size, locale and relevant fixture state; current Taskovsky source/build and counterpart. |
| Position and size | Exact observed placement and dimensions when measurable: logical-point bounds, alignment, ordering, spacing, safe-area/keyboard relationship, scrolling/sticky behavior and parent container. Record scale/calibration; label approximate values and unknown measurements explicitly, never invent exact numbers. |
| Wording and presentation | Verbatim observed labels, placeholders, titles, options and ordering; icons, selected/disabled/empty states, text hierarchy and general component size. Keep private task/account text out of published evidence. |
| UX behavior | Entry, tap/long-press/drag where applicable, selection/check states, focus, navigation, dismissal, Cancel/Back/Done, repeated and interrupted flows, and the visible result. Document unsampled paths as unknown. |
| Business logic | Preconditions and eligibility; data read/written; staging versus immediate application; validation/defaults; filtering, sorting and grouping; date/timezone/duration and recurrence scope where applicable; save/reopen/Undo behavior and side effects. Separate observed TickTick behavior, existing Taskovsky rules and proposed deltas. |
| Gap and acceptance | Missing/different elements, major layout/size/behavior/logic gaps, evidence confidence, implementation priority, native test cases and remaining unknowns; link exact-head review/CI and matched screenshots when available. |

**Execution passes:** (1) inventory and classify the largest verified gaps across active forms; (2) implement broad major similarity, including all evidenced elements, comparable position/size, wording, UX and business rules, prioritizing substantially missing forms/flows over isolated polish; (3) re-audit cross-form flows and remaining core elements; (4) perform final calibrated near-pixel-perfect refinement of spacing, typography and visual details. Collect precise evidence from the start, but do not spend the broad-coverage pass repeatedly tuning a single screen. Existing historical estimates and ordered slices below are not a requirement to finish fine visual polish before broader implementation.

**Evidence and scope gates:** unknown reference behavior is an investigation item, not an invented requirement or a passing result. Preserve existing Taskovsky semantics until a verified, scoped delta is specified; seek a product decision if it conflicts with approved business rules. Do not ship decorative nonfunctional controls to fake completeness. General-similarity acceptance requires the element inventory and relevant native flows to be checked; final pixel acceptance additionally requires calibrated matched captures and measured tolerances. Documentation alone does not upgrade any tracker state. Background chooser, Share / Print, accessibility-specific layouts, Dark matching and persistence polishing remain explicitly deferred as above; preserve existing accessibility and data-safety checks. This contract does not reopen deferred external integrations, notification permissions or sync work.

## Gap matrix

| Area | Live reference observation | Taskovsky evidence / delta | Priority and boundary |
| --- | --- | --- | --- |
| Tasks shell/drawer | Indigo side panel covers roughly seven-eighths of screen, dimmed Today strip remains; selected destination, counts and nesting visible together. | Navigation is presented as a large sheet; [iPhone spec](../spec/iphone.md) already describes side drawer. | P1, medium; fraction is an observation, not measured constant. Neutral workspace identity, no account imitation. |
| Today/List rows | Compact rows with trailing dates and sometimes smaller metadata; white rounded sections, count/disclosure header. | Current capture has larger rows and below-title dates; board already uses compact standard-size title/trailing date. | P1, medium; list-specific layout, preserve accessible reflow. |
| Task detail | Simple task shows compact sheet over Today, list/flag/overflow/schedule/title/bottom tools; no visible progress row or explicit description edit/format rows. Checklist task showed percentage in one Calendar detail state. | [PhoneTaskSheet](../../Mobile/App/PhoneTaskSheet.swift) renders progress for tasks and explicit description actions. | P1, medium-large; sample progress/checklist/rich states before conditional rules. Preserve editing discoverability and rich payload. |
| Calendar shell/Arrange | Leading mode chooser, centered month, trailing controls; modes List/Year/Month/Week/3 Day/Day. Trailing calendar control opens mini-month plus day-tile overview. Arrange slides from right with grid visible. | [App header](../../Mobile/App/TaskovskyMobileApp.swift) and [Arrange](../../Mobile/App/PhoneCalendarArrange.swift) use different control placement and bottom sheet. | P1, medium-large; header first, Arrange second, grid geometry only after matched captures. |
| Schedule dialogs | Date/Duration tabs; Date month grid with Time/Reminder/Repeat; Duration summaries, Start/End dates with All Day; Time wheel. Cancel discarded draft and returned original date. | [PhoneScheduleSheet](../../Mobile/App/PhoneScheduleSheet.swift) is a navigation form with Cancel/Done. | P1, medium-large; presentation over existing staged domain behavior, not persistence rewrite. |
| Group & Sort / View | View offers checked List View and Kanban View. Group: List, Date, Created Time, Tag, Priority, None. Sort: Date, Created Time, Modified Time, Title, Tag, Priority. Tag selected shows Ascending and Restore default tag order. | PR97 supplies pill presentation/reset for supported subset; PR96 adds optional Priority board. | P2; extend only confirmed semantics. Current pass did not change selection or verify reset/direction effects. |
| Kanban / alternate Calendar states | Previously supplied user screenshots cover mobile board; current live pass did not enter Kanban or inspect all Calendar modes. | Existing compact cards/Priority grouping are integrated, not complete board parity. | P2 evidence gate; do not reopen already completed work or invent missing behavior. |

## Delivery order and acceptance

**Current execution strategy (November 15, 2026): breadth first.** Cover the active screen forms with the biggest structural or functional parity gaps before polishing individual screens. Prioritize missing or substantially different core surfaces and their main flows; defer fine spacing, typography and isolated visual refinements until this broad coverage pass is complete. The ordered slices below remain a reference backlog, not a reason to repeatedly polish one screen while larger gaps remain. Keep native functional regression checks, data safety, independent review and exact-head CI as completion gates for each slice. Reassess the remaining form/state inventory after each broad coverage pass.

1. **Matched evidence baseline (0.5–1 focused day, estimate).** Neutral fixture matrix: empty/populated lists; short/long/date/tag rows; simple/checklist/rich tasks; all-day/timed events; List/Priority board. Record device and typography above. Capture reference and exact Taskovsky build at equivalent states. Preserve original data/preferences. Deliver discrepancy overlays or side-by-side crops with measured bounds before token tuning.
2. **Tasks drawer/shell (1–2 days).** Side panel/backdrop/selection/counts/nesting and utility placement. Verify dismissal, destination changes, reopening/scroll retention, safe areas, compact screen, VoiceOver focus return and non-overlap with navigation gestures. No external account controls.
3. **Today/List density (1–2 days).** Group header, checkbox/title/trailing date/metadata alignment. Compare matched viewport and text sizes; preserve completion, selection, context actions, scrolling and large-text readable reflow. No guessed universal truncation threshold.
4. **Detail then schedule presentation (3–5 days combined).** First inspect simple/zero-progress/checklist/rich/locked states to define contextual controls. Keep edit routes accessible without permanent toolbar clutter. Then Date/Duration/Time layouts over existing draft semantics. Test repeated opening, interrupted editing, Cancel/Clear/Done, field switching, rich-text preservation and accessibility. Existing deferred recovery/persistence work stays deferred; regression checks do not authorize polishing it.
5. **Calendar header, Week and Arrange (3–5 days).** Header/menu hierarchy and side arrangement first. Capture Month/Day/Week/all-day/overlapping cards before grid changes. Verify focus-date retention, view switching, sheet dismissal, safe areas, scrolling and separate movement/resize/Undo regressions.
6. **Group/Sort completeness and Kanban (2–4 days after evidence).** Compare board geometry and menu options, then independently specify each missing grouping/sort's direction, reset, tie-break and persistence semantics. Test empty groups, lane removal, long labels, accessibility and restoration to Date/List. Never ship nonfunctional visual choices merely to match a screenshot.

Indicative total: **11–19 focused engineering days**, including a first matched baseline but excluding unknown feature discoveries, review/CI waits and unavailable-device time. This is a planning range, not an elapsed-time promise or parity percentage. Re-estimate after steps 1–3. Highest immediate value is drawer + row density + simple detail, not another isolated low-impact control fix.

Each slice is a separate reviewed PR with exact-head CI, functional native tests, matched light-theme visual acceptance, and actual screenshot plus concise closed-gap description in the user chat (existing Taskovsky Codex display fallback). Mark partial coverage explicitly. Near-pixel-perfect acceptance requires agreed measured tolerances on calibrated captures, not current approximate ratios. Do not claim all mobile parity from merged PR counts.

## Documentation-only validation

This plan changes Markdown only. Relative source/doc links and whitespace are checked; independent review required before merge. Existing workflow docs-only filters should remain unchanged. No app tests, build or new runtime acceptance are implied by publication of this plan. Historical PR65/73 gates and all deferred work remain separate.
