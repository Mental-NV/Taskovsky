# CAL-VIS-001 — Calendar visual alignment

Status: Implemented locally with bounded verification; uncommitted. The user's 8 November 2026 request to pursue a near-pixel-perfect Calendar match authorizes this bounded visual pass. No publication, merge or deployment is authorized. See the [comparison and remaining gaps](../calendar-visual-parity-audit-2026-11-08.md) and [final verification](../spec/verification.md#calendar-visual-follow-up); no pixel-perfect claim is made.

Baseline: `f85e2f6a9c538f36829961961a0749197f29c4e2`. Contracts: BUS-027–030, UX-017 and the Calendar rows of the parity tracker. Preserve scheduling, reminder/recurrence semantics, staged editors, filters, previews and local-only integration exclusions.

## Evidence and intended delta

Private captures are under `/private/tmp/TaskovskyCalendarParityAudit-1108-bh2p266m`; do not commit screenshots or the third-party static corpus. The installed TickTick executable still matches SHA-256 `e76d6757e4a1e71fd16814443bb3b02d15d0d547ac69abb67306d8dfa3ee35af`. Reference observations use the previously archived disposable Taskovsky Calendar QA list, temporarily unarchived and selected alone. Personal task captures are not retained.

Both windows were moved to the MSI MP273A display. Taskovsky's existing debug 1060-point sizing command produced a 1060-pixel-wide capture, calibrating that display's capture to 1 pixel/point. Native Fill produced 1920×1050 captures for both apps. Native Left produced a 961×1050 TickTick capture. Record actual capture dimensions, not an assumed Retina scale.

Measured light-appearance differences to address:

- TickTick's Calendar sidebar begins at the top of the workspace, next to the main header; Taskovsky currently puts it below a workspace-wide header. The reference sidebar ends at x=285 after the 62-point rail (223-point pane), versus Taskovsky's 234-point pane. Its background is white in light appearance.
- Reference main header is 54 points high, with primary-colored title and neutral bordered view/navigation controls. Taskovsky uses 58 points and inherited accent-colored controls without matching borders.
- Reference sidebar mini-month uses six rows, approximately 34 points per date row, a 54-point month header and a 32-point weekday row. Its filters begin below the divider around y=315. Taskovsky uses a shorter variable-row mini-month and permanently expanded filter content.
- Reference hourly views separate weekday and date rows; the date header opens Day view. Zone titles sit above the time ruler at the bottom of the all-day area. Taskovsky combines weekday/date into a single label and puts zone titles at its top. The inspected reference has approximately 52 points/hour; Taskovsky uses 60. This is a measured reference preference/state, not a claim of the reference's factory default.
- At narrow overlap widths, Taskovsky's time captions wrap into multiple broken lines. Keep title/time lines bounded, retain exact stored endpoints and preserve Schedule/context actions.
- Reference Year uses six-row miniature months and adapts the year grid to the viewport: four columns/three rows at 1920×1050 and three/four at 961×1050. Taskovsky's width-only adaptive grid can produce excessive columns and fixed-size typography. Preserve Standard/Heatmap preferences and date drill-down while aligning the responsive layout.

## Boundaries and acceptance

No proprietary assets are copied. No date algorithms, workspace schema, recurrence exceptions, external integrations, Agenda pagination, per-type icon settings or global shortcuts are added in this visual pass. Those remain separate audit findings. Unknown animation easing/durations are not invented from screenshots. Existing reduced-motion behavior must remain intact.

Check the corresponding header/sidebar/grid geometry before and after at matching dimensions, visible content, date/view and scroll position. Exercise Day/Week/Month/Year/Agenda/Multi-Day/Multi-Week, sidebar/Arrange collapse and overlays, crowded all-day/month cells, three rulers, narrow overlap cards, Save/Cancel, precise schedule preservation, filters and preference reload. Use disposable data only. Run the existing focused Calendar cases, full suite, release build and signature verification; identify debug sizing versus release checks explicitly. Record unsupported gestures, themes or motion measurements as limits rather than claiming full parity.

The subsequent screenshot review corrected alternating subpixel hourly rules and centered dividers in empty all-day cells. All seven header/all-day/hourly positions and bounded native card/creation/drop targets were rechecked on the corrected signed release; the full 471-test suite and release/signature gates passed again. See the audit and verification record for updated source/binary identities and explicit checklist-completion limits.
