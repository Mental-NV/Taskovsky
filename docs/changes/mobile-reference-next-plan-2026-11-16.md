# Mobile reference next plan — 2026-11-16

Docs-only follow-up to the [live textual audit](../ticktick-spec/mobile-live-audit-2026-11-16.md) (observed local 2026-11-17, UTC 2026-11-16). No implementation, screenshots, or scope changes are made here. Verify current Taskovsky behavior in source before acting on any candidate below.

## Prerequisite: evidence refresh (do first)

The live run reached all 46 states textually but produced **0 portable TickTick reference images** (dated observation from that run); support-export investigation continues separately. Follow-up 2026-11-17: one owner-supplied manual T01 window capture was published ([reference manifest](../assets/mobile-parity/2026-11-17/reference/manifest.json); device/scale unknown, no pixel certification), so portable coverage is now **1/46 with 45 missing**. Prior autonomous attempts failed (Preview capture timed out; Shift-Cmd-5 showed no toolbar); the owner image does not prove autonomous capture works. Actual further screenshot refresh stays **blocked** until a privacy-safe export exists. Do not claim matched visual acceptance from this text pass.

- **C13 / D03 have no dedicated Taskovsky state shots.** C13 is currently covered only by adjacent C14 hierarchy images; D03 has no counterpart image. Capture neutral staged shots before comparing geometry.
- **T02 / T03 are outcome mismatches, not menu matches.** The tracker holds resulting display states (T02) and board lanes (T03); the live reference is the open anchored menus. Direct menu-geometry comparison is pending.
- Any future reference capture needs a matching device/theme/fixture set (same viewport, light theme, neutral synthetic lists/tags/Week, matched keyboard state for T17) plus full-frame privacy review including sheet backdrops.
- Counts: **42/46 Taskovsky, 1/46 portable TickTick reference (T01 owner-supplied manual capture, 2026-11-17; 45 states still missing).**

Deferred scope stays deferred: **T05 Share / Print, T06 Background chooser**, and Dark appearance. This plan does not revive them.

## Prioritized candidates (largest observed structural differences first)

Each candidate is an evaluation prompt, not an approved change. Confirm the current implementation in source and receipts before scoping work. **Strong structural evidence** means the live control order and container shape were fully presented; **mismatched-state** means fixtures or captured states differ and only direction, not geometry, can be compared.

1. **Week visible structure: seven columns and all-day geometry (C01).** Strong evidence for seven visible day columns, centered month, two toolbar buttons, narrow GMT ruler, and floating add; weak evidence for density/overlap because fixtures, dates, and visible hour ranges differ and scroll behavior was unobserved. Evaluate Taskovsky's weekday-strip/navigation-strip stacking, clipped Sunday, and tall all-day band against a matched seven-column neutral Week. Do not scope scroll, overlap, drag, or resize from this run.
2. **Reminder / Repeat anchored presentation (D10–D14).** Strong evidence for anchored translucent preset menus (reminder presets with Constant Reminder; repeat presets with date-derived labels; three-choice Repeat Type popover) versus Taskovsky's pushed full pages. Mismatched-state caveat: only the all-day single-date reminder case was observed; timed/duration presets, defaults, and placement need a matched pass. Evaluate anchoring, staging/return behavior, and the expired-warning (D11) and sentence-summary (D13) treatments after verifying current staged pages.
3. **Color Pick family hierarchy (C09, with C07–C08 context).** Strong evidence for six named eight-position rows plus slash/selected-ring/Custom row, against Taskovsky's single compact palette. Evaluate whether named families are in scope at all before touching layout; C07 source-disc density and C08 popup placement stay secondary until the hierarchy question is decided.
4. **Quick-add only after a matched keyboard state (T17, with T12 More caveat).** Mismatched-state: the live composer showed no software keyboard in Mirroring while Taskovsky's capture shows a titled sheet with Cancel/Add and a real keyboard. Evaluate bottom-docked versus sheet structure, core action order, and More routing only from a matched keyboard-visible pair. T12 More expansion is explicitly unverified on both sides and is not actionable from this run.

## Non-goals

No Share/Print, Background, Dark, subscription, health/focus/declined, sync, or persistence-polish work is proposed here. Additional modes outside the original 46 stay separately tracked without changing the denominator.
