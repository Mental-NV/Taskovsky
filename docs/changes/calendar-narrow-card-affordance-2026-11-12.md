# Mac Calendar narrow-card completion affordance

- **Change ID:** CAL-MAC-NARROW-01
- **Status:** Draft implementation; hosted tests and Taskovsky native acceptance pending
- **Scope:** Mac Calendar task cards only. No iPhone or scheduling/data change.
- **Starting point:** `ddef08a` (PR62); isolated clean worktree. Reconcile latest main before implementation.
- **Authority:** The user's standing Tasks/Calendar UI parity request authorizes investigation and bounded improvements. It does not establish a particular TickTick hiding threshold.
- **Related contract:** [UX-017](../spec/ui-ux.md#ux-017), [workflow](../spec/workflow.md), [reference audit](../calendar-visual-parity-audit-2026-11-08.md).

## Problem and evidence

`CalendarEntryView` in `Sources/Taskovsky/CalendarPanels.swift` currently shows a completion button whenever item icons are enabled (or temporarily revealed with Option), without checking the title's available width. Its HStack reserves an additional 5pt gap. `CalendarTimedBlock` in `Sources/Taskovsky/CalendarViews.swift` also reserves a trailing drag grip of `min(18, cardWidth / 3)` for editable entries. Narrow overlap lanes can therefore leave little title space.

The November 8 reference audit records that TickTick describes automatic checkbox hiding in limited space, **but the behavior was not independently exercised**. That statement supports a focused observation, not a numeric threshold or a claim of matched behavior. A scoped live observation was completed on November 12; see the evidence below. It brackets a transition but does not establish a numeric point threshold.

The existing title button already exposes Complete/Reopen as an accessibility action and the context menu includes it. Those routes must remain available even when a visual completion button is hidden.

## Intended bounded delta

Adapt only the task/checklist **completion checkbox** to the width available to the card's content. Do not adapt away the note icon or projected-repeat identity as part of this change. Preserve icon visibility preferences and Option's temporary force-reveal behavior. No new preference or persistence field is required.

The fit calculation must use the actual content allocation after the existing horizontal padding (4pt each side), trailing inset and applicable grip, not a hard-coded window width or overlap count. Use a pure, testable policy with measured presentation inputs if a threshold policy is chosen. The exact minimum readable title budget remains unresolved until reference observation; do not manufacture a number and label it TickTick parity.

Preserve existing 11pt compact / 12pt normal title type, 10pt time/icon type, top-leading text alignment, title strikethrough, colors, fill/outline/border/opacity, 2pt title-time spacing, 5pt visible icon gap, padding, card frame, tooltip and time text. Hiding the checkbox must remove its gap too. Keep the title view identity stable across fit changes so focus and accessibility state are not unnecessarily recreated. Do not add animation, change event lane packing, reduce the drag/resize hit targets, or alter completion/scheduling commands.

Long text may remain truncated as today. No substring slicing, fixed character count or assumption that one code point equals one displayed character is acceptable. A checkbox policy is not a guarantee that an arbitrarily narrow card can display a readable title.

## Reference observation task (when Mac reconnects)

Use the existing Taskovsky Codex chat only for scoped Computer Use, then stop it. Use isolated Taskovsky QA data and the stable QA app identity; do not change launcher/signing/permissions. Do not disturb original dirty worktrees. No real notification test is involved.

1. Compare TickTick timed cards and compact all-day/month cards while varying usable width. Record app version, display scale, window size, mode, card width and screenshots at the transition.
2. Repeat with short/long Latin titles, Cyrillic, CJK and emoji/combined characters, completed/incomplete tasks, task-icon preference off/on, and Option press/release. Observe whether hiding depends on width alone or text fit; do not infer it from a single screenshot.
3. Check that note and repeat-preview icons behave independently. If the reference does not match the proposed task-only rule, record the discrepancy before coding.
4. Capture whether the checkbox returns immediately on widening and whether hover/focus changes it. Record unknowns rather than filling them with guesses.

### Bounded first observation and handoff record

Start with one timed-overlap scenario, not the full acceptance matrix. Reuse a clearly labeled QA list and existing disposable tasks where possible; creating/modifying labeled test records is authorized, but deleting reference records is not. Record any test data left behind. Do not alter unrelated task data, account settings, notifications or the QA wrapper.

- In TickTick, hold date, task duration, overlap count, appearance and scale fixed. Slowly narrow then widen the window. Capture the last width with the checkbox and the first width without it, including screenshot pixel bounds and display scale; distinguish physical pixels from logical points.
- At the same card allocation, compare a short title with a long title by editing only a labeled QA record. Repeat once with a different leading grapheme. This discriminates width-only behavior from text-fit behavior; it does not prove a general policy.
- At both sides of the observed boundary, record hover and Option press/release, then verify that icon preference off stays off after Option release. If no transition occurs, report that negative result and the tested width range rather than extrapolating a threshold.
- Stop after this first scenario if it resolves the policy question. Return evidence to dot before implementing; broader compact/note/projected cases remain acceptance checks, not a reason to leave Codex running.

Return one record per capture with: app/version, Calendar mode, OS/display scale, window and card bounds, title/test-record identifier, completed state, icon preference, Option/hover state, checkbox visible, title visible/truncated, screenshot reference, and whether each dimension is measured or estimated. Include the exact sequence of actions, observation limits, remaining labeled records and confirmation that Codex stopped. A screenshot of the checkbox disappearing alone is insufficient to establish the title-budget rule.

## Automated acceptance plan

Once the measured policy is specified, test below/at/above the chosen boundary, available-width clamping, trailing inset/grip subtraction, compact and normal typography inputs, preference off, preference on, Option override, and non-completable/note/projected cases. Include wide-card regression and Unicode/grapheme-safe measurement cases if text measurement is used. Keep scheduling tests unchanged and passing.

## Native acceptance gates (must precede merge)

- Side-by-side reference evidence for the chosen policy, with explicitly documented approximation if necessary.
- Repeated narrowing/widening and Option press/release without flicker, stranded focus, hidden hit regions, or accidental completion.
- Title opens the same task; completion remains usable through keyboard/accessibility action and context menu when the checkbox is hidden.
- Drag move, start/end resize and Schedule entry points retain their current hit area and behavior in narrow and wide lanes.
- Check compact/noncompact, task/checklist, completed, note and projected entries; light/dark and reduced-motion settings; wide baseline unchanged.
- Run exact-head macOS tests and release build; hosted build/test success is not a native visual pass.

## Delivery and limits

Keep implementation in a draft PR until native gates pass. Update the current UI contract, parity status and verification ledger with **observed** behavior and exact evidence at that point. This proposal alone closes no parity row and fixes no user-facing defect. It deliberately does not expand into card typography, grip redesign, lane geometry, mobile layout or notification work.

## November 12 scoped reference result and explicit implementation policy

Native Codex observation completed in TickTick 8.2.20 (922), Week / Modern / Task icons on. Two open owned QA tasks overlapped November 13, 2026 09:00–09:30 Moscow. Both checkboxes remained visible with approximately 37–38 screenshot-pixel cards while the long title clipped; at 21–22 pixels both hid while short `QA` still fit. Changing `QA` to `WA` did not restore its box. Widening back to approximately 80 pixels did not restore boxes until Calendar re-entry. This supports width-sensitive behavior, not title-fit testing, for this one scenario. It does **not** prove a universal cutoff, physical-pixel/logical-point mapping or intentional hysteresis. Hover and standalone Option could not be exercised by the available Computer Use tool. Preference was inspected, not toggled. Compact/note/projected cases remain unobserved.

The reference view/list selection was restored and Codex stopped. The owned QA list retains the duplicate `QA overlap 1112` and two unintended open, undated `No Title` records. They were not deleted. No Taskovsky implementation or visual test is implied by this reference observation.

The draft intentionally adapts **timed cards only**. `CalendarCardLayout` uses the actual card width minus 8pt horizontal padding and the existing move grip. It shows a completion checkbox only if remaining content can fit the 10pt icon budget, 5pt gap and one title em (11pt compact / 12pt normal). These are Taskovsky typography-derived budgets, **not measured TickTick thresholds**. With an 18pt grip the outer boundary is 52pt compact / 53pt normal. Taskovsky therefore may hide earlier than the observed reference: its reserved grip also consumes width. This approximation must be assessed visually before merge rather than presented as pixel parity.

The helper is stateless: widening restores the checkbox immediately. We do not reproduce the single observed sticky-hidden state, whose cause/intent is unverified. Option still forces reveal and release restores saved preferences plus the width policy. Other surfaces retain their existing checkbox behavior, and note/repeat-preview identity icons are not gated. Title identity, accessibility/context completion actions, card geometry, move and resize targets, styling and persistence are unchanged. The policy never reads or slices title text, so it is independent of Unicode/grapheme length.

Eight pure-policy tests cover boundaries, grip, repeated widening, preferences/Option, unmeasured surfaces, invalid allocations and wide baseline. Test source and whitespace checks are prepared; no Swift runtime is installed in the cloud executor. Hosted exact-head CI and native Taskovsky QA remain required. The broader matrix above is not claimed complete.

Focused verification record: [narrow-card evidence](../verification/calendar-narrow-card-2026-11-12.md). The historical verification ledger is unchanged.

The broad current UI contract and parity tracker remain unchanged in this draft because replacing their historical snapshots was blocked by publication review. Integrate the verified delta into those documents through an approved scoped edit before treating the feature as merged/current.
