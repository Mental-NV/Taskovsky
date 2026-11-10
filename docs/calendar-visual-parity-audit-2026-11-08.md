# Calendar visual comparison — 8 November 2026

The approved [CAL-VIS-001](changes/calendar-visual-parity-2026-11-08.md) follow-up brings the local Calendar closer to TickTick. It does **not** establish pixel-perfect or complete functional parity. Changes are local and uncommitted on `codex/calendar-visual-parity`, based on merged PR #3 at `f85e2f6a9c538f36829961961a0749197f29c4e2`. No external integrations were added.

## Method and evidence

Reference: installed TickTick 8.2.20, build 922, arm64; main executable SHA-256 `e76d6757e4a1e71fd16814443bb3b02d15d0d547ac69abb67306d8dfa3ee35af`. Both applications used the disposable three-item **Taskovsky Calendar QA** list, Sunday week start, November 8–14, primary Moscow zone, Week and the top of the hourly scroll range. The similarly named “move resize today at 14:00” reference item is actually undated; its title was not treated as scheduling evidence.

Captures and accessibility records remain private under `/private/tmp/TaskovskyCalendarParityAudit-1108-bh2p266m`. The principal records are `comparison-reference-week-fill`, `comparison-before-week-fill`, **`comparison-boundary-corrected-release-week-fill`**, `reference-year-fill`, `reference-year-half` and `comparison-final-release-year-{fill,half}`. The earlier `comparison-final-release-week-fill` is retained as pre-correction evidence and is superseded for Week rendering. No third-party assets, static exports or screenshots are committed. The private directory is temporary local evidence, not durable CI storage.

The MSI MP273A display was calibrated to one capture pixel per logical point using the existing debug 1060×700 sizing command. Native Fill produced 1920×1050 images for both apps; Left produced 961×1050. Initial Retina captures and unsuccessful edge-resize attempts were not used as matched-size evidence. Light appearance, normal text size and Europe/Moscow were used. Dark appearance, increased contrast/text size and reduced-motion runtime behavior were not verified.

| Measurement | Before Taskovsky | Reference | Final Taskovsky |
| --- | --- | --- | --- |
| Sidebar/divider edge, absolute capture x | 297 | 285–286 | 284–285 |
| Primary ruler/day boundary x | 351–352 | 341–342 | 341–342 |
| Hour pitch | 60 | 52 | 52 |
| All-day/grid boundary y, one all-day item | 143–145 | 141–142 | 140–142 |
| Sidebar body sample RGB | 235/235/235 | 254/254/254 | 254/254/254 |
| Year columns × rows, Fill / Left | Width-only adaptive layout | 4×3 / 3×4 | 4×3 / 3×4 |

Edges are approximate JPEG transitions, not exact vector bounds. Typography, border strength, card tint, sidebar group selection indicators and native control details still differ; the global local-only rail also differs deliberately. There is no whole-image similarity score. `final-pixel-metrics.jsonl` preserves the bounded file analysis.

### Follow-up boundary correction

Final screenshot review correctly identified two defects that the first-column measurements missed. Half-point hourly rectangles disappeared at alternating fractional column positions on the calibrated 1× display. Separately, empty all-day scroll views shrank inside their externally sized wrappers, placing their leading dividers near the centers of otherwise correctly spaced columns. This was a combination of subpixel line rasterization and internal empty-cell layout, not evidence that the hourly date columns had doubled in width.

The correction uses a one-physical-pixel, non-interactive day-boundary view and applies the all-day cell's explicit width/height before its overlays and drop destination. Date headers use the same boundary treatment. Every column still derives its width from the same hourly parent calculation; the correction does not change date or scheduling algorithms.

| Boundary index (Sunday = 0) | Reference x | Corrected date / all-day / hourly x |
| --- | --- | --- |
| 0 | 341 | 341 / 341 / 341 |
| 1 | 567 | 567 / 567 / 567 |
| 2 | 792 | 792 / 792 / 792 |
| 3 | 1018 | 1018 / 1018 / 1018 |
| 4 | 1243 | 1243 / 1243 / 1243 |
| 5 | 1469 | 1469 / 1469 / 1469 |
| 6 | 1694 | 1694 / 1694 / 1694 |

`boundary-before.jsonl` / `boundary-after.jsonl` record all seven positions, rather than only the first gutter. Native signed-release checks passed for 12 hourly probes immediately either side of the six internal boundaries, 14 all-day left/right probes across seven cells, and seven card Schedule/date probes. Creation probes were canceled; the three-item comparison fixture retained exactly three tasks. `boundary-seven-card-release` shows one 09:00–10:00 card per day within its matching column.

Controlled native drops also succeeded: an Arrange item reached Monday November 9 as an all-day point, and Sunday's one-hour card reached Tuesday November 10 at 07:30–08:30. In this Computer Use session, `drag` left the native drag pending until a click at the intended endpoint completed it. An earlier mixed probe had therefore produced a later write after another action; its first no-change snapshot was not a reliable drop outcome. The isolated repeat kept the layout fixed, explicitly completed each endpoint and verified persisted scheduling plus Undo. All scheduling fields returned to the controlled fixture's baseline. This is bounded destination coverage, not proof of every drag, anchoring or auto-scroll behavior. A separate resize/Undo repeat restored the resized card; it was not used as proof that the earlier mixed drag probe restored all unrelated tasks.

## Implemented presentation changes

- Full-height white sidebar beside the main header; six-row mini-month, period highlighting and collapsible Lists/Tags sections.
- Neutral title and bordered, right-aligned controls; Calendar-scoped blue accent.
- Separate weekday/date rows, date-header drill-down to Day, zone titles at the bottom of the all-day gutter and a denser hourly grid.
- Bounded title/time lines, compact all-day cards, hover/focus creation controls and adjusted Month spacing.
- Year layout based on viewport proportions, with six-week miniature months and scaled typography.

Scheduling, recurrence, reminders, stored colors and the workspace schema retain their existing policies. See [UX-017](spec/ui-ux.md#ux-017) for source dimensions and [verification](spec/verification.md#calendar-visual-follow-up) for exact build identity/results.

## Audit disposition and remaining gaps

| Area | Evidence and disposition |
| --- | --- |
| Seven views and navigation | All seven reference modes reached with QA-only scope. All seven updated Taskovsky modes rendered in the isolated native app. Week date-header selection now opens Day; Year date selection retains Taskovsky's prior-detailed-mode policy. |
| Sidebar, sizing, scroll | Matched Fill and Left captures confirm the main geometry changes. Taskovsky debug 780×580 checks cover compact Sidebar/Arrange overlays, three rulers and crowded entries. Exact 382-point width remains unverified. All-day overflow reached scroll value 1; Month +29 more opened a contained sheet and Escape dismissed it. |
| Creation, Cancel, precise Save | Typed new-task draft plus Escape left the three-item fixture unchanged. Signed-release unchanged point and five-minute Save reported Schedule unchanged; normalized fixture bytes stayed identical. |
| Resize and Undo | Initial signed-release overlap A changed from 09:00–10:30 to 09:00–10:45; Undo restored scheduling fields in that fixture. The boundary follow-up repeated resize/Undo and confirmed controlled cross-column timed and Arrange-to-all-day drops with explicit endpoint completion, as detailed above. Earlier no-change drag snapshots remain unconfirmed; short-window moves, interrupted gestures and exhaustive destination/anchoring behavior remain open. |
| Filters and reload | Empty list scope hid entries; All restored them. Area tag selection narrowed entries and survived process relaunch with Day mode and three rulers. Disclosure expansion and focused date are transient by design. Collapsed group selection indicators are still visually different from the reference. |
| Styles, Year quantity and icons | Live reference panels distinguish Modern/Classic, Heatmap Hide/Show and separate Task/Note icon controls. Taskovsky Filled/Outline, Standard dots/Heatmap and one global icon switch are independent policies. The reference describes automatic checkbox hiding in limited space; that behavior was not independently exercised. Extremely narrow overlap lanes in Taskovsky can still show mostly icons. |
| Agenda and shortcuts | Reference Show more extended the horizon from May 31, 2027 to November 30, 2027. Taskovsky remains a fixed 30-day Agenda. Numeric reference shortcuts 1–5 worked; Taskovsky has no equivalent Calendar mode shortcuts. These functional gaps are deferred from this visual pass. |
| Multi-day bars, recurrence and checklists | Taskovsky still uses per-day fragments, with no all-day resize, series-exception editor or independent checklist scheduling. **Checklist completion UI: unverified in this visual pass.** Checked/unchecked and future-preview rows were rendered, but no checklist completion control was activated in either application. Historical checklist visibility/model results are not a live completion-interaction pass. Reference interaction semantics were not re-established through controlled mutations in this session. Existing core regressions passed; they are not gesture-parity proof. |
| Time rulers / working hours | Three local Taskovsky rulers rendered at compact/full widths and survived reload. First-displayed-date DST conversion remains the known policy. Reference 07/21 ruler handles were visible, but their behavior and working/visible-hour preference semantics remain unknown. Static weekend controls do not establish runtime availability. |
| Motion, keyboard, accessibility and themes | Escape dismissal and Calendar date/action controls were exercised; exhaustive keyboard/VoiceOver, focus reveal of hover controls, high contrast and reduced motion remain open. Sidebar frame capture began too late to measure easing/duration. A process-only dark override remained light, so its capture is named `final-release-reload-light-override-ineffective`; it is not dark-mode evidence. No system appearance/accessibility preference was changed. |
| External modules/integrations | Deliberately excluded under the user's local-only scope; see the [explicit deferrals](parity-implementation-status.md#calendar-integrations-deliberately-deferred--8-november-2026). No subscription/account placeholders added. |

## REA and static-evidence limits

REA opened the main binary lazily, but Hopper document discovery timed out (`cleanup_incomplete` / `provider_timeout`). Hopper then displayed its expired-demo notice and exited after acknowledgment. No pseudocode or recovered gesture implementation was obtained. The empty evidence export contains zero records and is not analysis proof. The retained runtime `/tmp/rea-c4hV6n` still lacks authenticated shutdown acknowledgment; no socket removal, process killing, configuration changes or licensing workaround was attempted.

The existing private full-static corpus was checked against the installed executable. It contains metadata naming Calendar resize previews, split-view animation duration, weekend controls and an auto-scroll collection view. These are candidate-presence clues only: they do not establish a Calendar handler's algorithm, active settings, timing or ownership. No guessed animation or auto-scroll behavior was implemented from them.

## Cleanup

The temporary reference QA list was re-archived and observed under Archived Lists. Tasks Lists/Archived Lists sections were collapsed. Calendar All was visibly checked; Day/Today November 8, hidden sidebar and the native previous window size were restored. Reference Style/icon preferences and task schedules were not changed. The isolated Taskovsky QA app was closed after the final captures. Production Taskovsky files were never used.
