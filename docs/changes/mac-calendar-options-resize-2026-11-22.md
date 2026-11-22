# MAC-CALENDAR-OPTIONS-001 — Preserve View Options during Calendar resize

Status: candidate on `fd7e627f0f37cd532bdcd6e0c7dc20880df2ca79`. Mac only. [MAC-20](../mac-parity-acceptance.md#acceptance-matrix), [TT-033](../parity-implementation-status.md#tt-033), [UX-017](../spec/ui-ux.md#ux-017).

## Evidence and change

On the guarded baseline, Calendar Week at a 382 × 584 point window presented the 360 × 560 View Options sheet with its full footer. Scrolling to the lower controls set the scrollbar fraction to 1. Widening the same host to 1060 points without dismissing the sheet reset its scroll to 0. The header's Actions menu had moved to a different structural row at the 760-point Calendar-content boundary and owned the presentation. At 1060 points, opening nested Time Zone Settings and choosing Asia/Tokyo without saving produced a draft row; resizing to 780 dismissed the nested editor and discarded that draft, while the parent returned at scroll 0. No preferences were committed.

Attach the existing sheet to the Calendar workspace rather than the shifting header. Preserve its contents, size, Done/Escape, options behavior, nested editor contracts, and keyboard guards. The change applies while the same Calendar workspace remains mounted; it does not keep a Calendar sheet alive if the parent Tasks/Calendar split removes that workspace. The [dated TickTick reference](../ticktick-spec/calendar.md#view-options) establishes an Options surface, not equivalent resize behavior.

## Acceptance

- On guarded Week, open View Options at compact width, scroll to lower controls, resize wide then compact with the sheet still open, and check the same control/scroll position remains.
- Open a nested editor from View Options and exercise its Cancel/close behavior. If supported at runtime, verify an unsaved draft remains while resizing; do not claim this from scroll retention alone.
- Dismiss View Options with Done or Escape, open again, and verify Jump to Date still opens and cancels separately. No unrelated task or settings writes.
