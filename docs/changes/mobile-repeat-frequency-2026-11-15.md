# D13 Custom Repeat: Frequency wheels and weekday chips

## Bounded element contract

Reference inventory observes a tall Custom Repeat form with Repeat Type, Frequency interval/unit wheels, summary and weekday chips. This slice changes cadence presentation only; it does not guess Repeat Type conversion/default behavior.

| Element | Placement / wording | Behavior |
| --- | --- | --- |
| Existing Pattern and Anchor | Above Frequency | Existing Cadence/Specific dates and due/completion anchor remain unchanged |
| Frequency | Caption above two 150 pt wheels | Common intervals1–100 plus any existing larger selection; unit routes through unchanged `setUnit` |
| Exact interval | Disclosure beneath wheels | Numeric editor retains complete model range1–10000 without truncating existing values; blank/out-of-range visible text disables Done |
| Summary | Below wheels | Uses staged candidate recurrence label, not a second recurrence algorithm |
| Seven weekday chips | Row under weekly Frequency | Locale symbols and calendar firstWeekday order; actual stored weekday indices remain1–7 |
| Selected chip | Tinted capsule with selected accessibility state | Toggle real weekday membership; empty weekly selection disables Done through existing validation |
| Advanced editors | Below relevant Frequency unit | Monthly/yearly/specific-date patterns, skip-weekends, limits and previews retained |
| Cancel / Done | Existing navigation toolbar | Nested Cancel discards changes; Done stages valid candidate, outer Cancel still discards it |

Switching unit preserves existing model behavior: seed due-date weekday for Weeks and clear incompatible monthly/yearly fields. No anchor conversion, recurrence algorithm, interval limit or persistence rule changed. Chip labels are localized short standalone symbols with full localized accessible weekday names. Existing accessibility support remains; accessibility-specific layout polishing remains deferred.

## Verification

Full package tests (851 XCTest +38 Swift), release and initial iPhone compile passed. Initial10000-row wheel native run stalled accessibility snapshot and ended75; replaced with bounded wheel plus full-range numeric editor. Corrected final native4/4 passed with explicit wheel3/Weeks and2/Months checks, Mon/Wed membership, weekly persisted relaunch, monthly save/reopen, nested/outer Cancel, blank/0/10001 disabled and10000 nested staging/reopen. Final iPhone source compiled in the successful native run; independent final source/test review clean. Exact-head hosted CI pending. No calibrated pixel-perfect or complete D13 parity claim. Repeat Type naming/control shape and remaining spacing remain open.

The exact interval field keeps raw draft text and validates it before constructing a candidate, preventing blank/invalid text from silently committing the last parsed number. This compatibility editor is a Taskovsky addition, not claimed observed TickTick UI.

Independent final source/test review is clean. Native firstWeekday order, alternate locales, yearly and specific-date forms are not newly exercised in this slice; their source paths are retained. The10000 test covers nested staging/reopen only, not disk persistence. Nondefault weekly and monthly cases cover saved values and weekly relaunch.

[Actual neutral screenshot](../assets/mobile-parity/2026-11-15/d13-repeat-frequency.png) from final native run:3 Weeks,Mon/Wed chips, summary and retained limits. Pixel-inspected without personal task/account content.
