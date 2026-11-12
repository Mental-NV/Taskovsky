# CAL-DST-LAYOUT-004 — Pack repeated-hour Calendar cards by painted coordinates

Status: Implemented; independently reviewed and locally verified for the cases below. Base `7187410`; ongoing local Tasks/Calendar correctness authorization. Affects BUS-027, UX-017 and TT-033.

## Source defect and intended delta

The hourly layout sorts absolute start instants but packs lanes using civil-hour coordinates. On a fall-back date the second occurrence of 01:20 sorts after the first 01:50, although it paints above it. A prior cluster can be flushed too soon, leaving overlapping card rectangles.

Compute the existing clipped painted intervals first. Sort eligible cards by painted start ascending, painted end descending, stable entry ID. Then use the existing connected-cluster lane assignment. Cards whose painted vertical intervals overlap must occupy disjoint horizontal lanes in the same cluster. Adjacent half-open intervals may reuse a lane. Existing minimum visual heights and folded-hour bounds remain unchanged.

This affects the shared layout used by separate Mac/iPhone Day, Week and Multi-Day views. No task instants, time-zone arithmetic, recurrence, storage, drag targets, fonts, colors, icons, animation or other Calendar modes change. It does not add a second repeated-hour band or resolve ambiguity in the current 24-hour wall grid. No TickTick parity claim.

## Acceptance and verification

- New York November 1, 2026: A 01:10–01:30 EDT, B 01:50–01:55 EDT, C 01:20–01:40 EST. A/C share a two-lane cluster, B is full width; all input permutations are deterministic.
- Ordinary days, adjacent boundaries, minimum-height points and folded-window clipping remain collision-free.
- Shared geometry regression fails before fix, then all tests and Mac/iPhone builds pass. Audit callers in all hourly views and exercise native layout with owned fixtures where feasible.
- Retain O(n log n) sorting and existing lane assignment; check a large synthetic layout without asserting broad performance parity.

The original six-permutation regression failed before the fix. Final 664 XCTest cases and 37 Swift tests pass, as do Mac signed packaging and iPhone simulator compilation. Native Mac Day/Week/Multi-Day and one narrower Multi-Day configuration show the expected separation. No phone native or exhaustive pixel/VoiceOver claim. [Verification evidence](../spec/verification.md#calendar-repeated-hour-collision-packing). Exact-head hosted CI remains a pre-merge check.
