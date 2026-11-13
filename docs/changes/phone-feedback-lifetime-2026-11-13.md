# MOB-FEEDBACK-001 — Temporary success feedback lifetime

## Request and scope

The user reported Calendar “Schedule updated” feedback never dismissing and asked to fix similar cases elsewhere. This isolated iPhone change covers schedule feedback in Tasks/Calendar/Board/Timeline/Arrange, lifecycle feedback, successful capture/text-batch creation and batch actions. It does not modify macOS, storage, notification permissions or Dark appearance.

## Behavior

- Successful feedback disappears after five seconds, including its associated temporary Undo control. The task change remains saved; expiry never invokes Undo.
- VoiceOver at emission uses a fifteen-second reading/Undo window. This is a Taskovsky usability policy, not a measured TickTick timeout; actual VoiceOver usability remains unverified.
- Every emission, including repeated identical text, starts a fresh independent window. Expiry of a cancelled/replaced message cannot clear its successor.
- Calendar and Tasks scheduling feedback use separate lifetimes. Capture, lifecycle and batch channels do not expire one another.
- A newer actionable error invalidates the preceding success timer and remains visible. Compatibility, persistence, stale-write, input and recovery warnings are not auto-dismissed. Existing Undo validity checks remain in force.
- Error-only section movement, manual ordering and Calendar preference notices remain persistent; they clear through their existing successful retry/navigation paths.
- No toast is made permanently visible merely because a success action had no effect; existing pending lifetime is retained on unchanged outcomes.

## Validation

Deterministic hosted tests cover identical-text replacement, ignored cancellation, independent channels, batch dismissal/re-emission and actual model schedule/lifecycle feedback/Undo behavior. A native iPhone Simulator test moves a Timeline task, checks the notice/Undo expire, and verifies the changed geometry remains. Exact results are recorded in the verification ledger after execution. Existing accessibility labels remain; no physical-device or pixel-parity claim.
