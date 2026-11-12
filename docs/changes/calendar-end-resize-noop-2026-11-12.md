# CAL-END-RESIZE-003 — Preserve unchanged timed range endpoints

Status: Implemented; reviewed and locally verified for the cases below. Base: `21a4739`. Authorized by the ongoing local Tasks/Calendar correctness goal. Affects BUS-029, UX-017 and TT-033; shared scheduling used by separate Mac and iPhone views.

## Defect and bounded delta

A valid timed range shorter than 15 minutes, including zero duration, currently grows to 15 minutes when an end-resize command submits its exact existing end. This also changes its due time and may move reminders. Start resizing already preserves an exact unchanged endpoint. The Mac direct resize handler can emit an unchanged snapped endpoint after dragging away and returning; iPhone uses the same command, though compact-card controls differ.

For a coherent timed duration (valid range, timed task, due equals range end), an end-resize target exactly equal to the existing end is a no-op. Preserve every task field, including reminders/provenance, recurrence and occurrence override. Equality uses the full Date instant, not rounded civil minutes; fractional seconds are retained. Actual changed endpoints keep the existing 15-minute minimum. Point tasks retain their existing explicit resize-to-duration semantics; malformed/incoherent ranges and all-day scheduling are not reinterpreted.

Native QA also exposed a zero-duration visual-hit-area error: a horizontal end-handle drag used the synthetic 15-minute display end. Duration handles now anchor to the stored due instant; zero vertical translation returns that exact instant, including fractional seconds. Point handles retain their prior conversion behavior. Mac and phone remain separate views calling a shared target helper.

No storage/schema, UI geometry, fonts, colors, icons, motion, focus, platform sharing or notification changes. No claim that TickTick uses this minimum or gesture policy. This is a Taskovsky correctness fix, not an inferred reference feature.

## Acceptance

- Exact end of zero-, five-minute and fractional-second valid timed ranges leaves task snapshot unchanged, with both manual and automatic reminder provenance and current-occurrence scope.
- No-op produces no scheduling undo token or persistence mutation in the Mac store; mobile transaction follows its existing no-change result.
- An actually changed target still clamps to 15 minutes. A near-but-not-equal fractional target is changed.
- Point conversion, all-day end resizing, invalid target rejection and existing start-resize behavior remain intact.

The original command regression failed before the fix. Final shared tests, Mac release build/signature, separate iPhone simulator build and independent review pass. Native Mac retest repeated the zero-range horizontal drags that previously extended the task: both now preserve its exact range with no Undo action. A genuine changed-end edit still clamps and Undo restores it. Short-card gesture activation remains unverified, as do iPhone native gestures. See [verification evidence](../spec/verification.md#calendar-unchanged-timed-end-resize). Exact-head hosted CI is checked before merge.
