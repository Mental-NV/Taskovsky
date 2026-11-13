# Mac temporary feedback lifetime

Status: implemented and published as draft PR #72; hosted checks and final review pending. Requested November 13 after the user observed “Schedule updated” remaining indefinitely and requested an audit of similar messages.

## Intended delta

Calendar, Tasks Timeline and grouped Board successful schedule/capture/move feedback dismisses after five seconds. Every new event receives a new identity and fresh interval, including identical repeated messages. Dismiss, disappearance or replacement cancels its pending expiry; an old timer cannot hide a newer success or error. The five-second duration follows Taskovsky's existing completion toast, not an asserted TickTick measurement. The surface's schedule Undo button expires with the feedback opportunity. Expiry never changes task data or persistent Undo history.

Failures and stale/conflicting edit messages remain until explicit dismissal or replacement, not a silent timeout. Replacing feedback clears the previous presentation's Undo token, so an error cannot offer Undo for an unrelated old action. Existing store conflict checks remain authoritative.

Mac Summary “Saved as note” and read-description “Copied” acknowledgments follow the same temporary lifetime. Summary save errors remain visible with the report retained. The reader's copied-state lifetime does not alter the clipboard or document. Existing colors, geometry and controls are otherwise retained; Timeline/Board add a Dismiss action for retained feedback. No notification permission, OS notification, persistence, theme or launch behavior changes.

## Audit

- `TaskActionCenter` already uses a five-second cancellable timer and event identity; retained.
- Calendar, Tasks Timeline, grouped Board used standalone persistent notice/Undo state; migrated to `DesktopNotice`.
- Summary saved acknowledgment and read-description copied-code label were persistent; migrated.
- Shortcut settings feedback is validation/conflict guidance, not success; retained.
- Store recovery, save and form validation errors are actionable; retained.
- iPhone schedule, lifecycle, capture, batch and Summary feedback require a separate platform-specific fix; this change makes no mobile runtime claim.

## Verification

Regression tests cover automatic expiry, repeated identical messages, stale timer rejection, persistent error replacement, dismissal and independent surfaces. Final full Mac suite passed 775 XCTest and 38 Swift Testing cases; final signed release build passed. Independent source review passed after correcting a compile error. Scoped AX-only native Calendar QA passed: two identical saves 2.74 seconds apart; second notice still present 5.32 seconds after the first save and absent by 5.50 seconds after its own save. Undo restored the original 10:00–10:45 schedule and its new feedback expired; Dismiss cleared feedback/Undo; navigation away/back did not revive it. Timeline and Board were not sampled natively. QA bundle, fixture and preferences were restored byte-for-byte and Codex stopped. After explicit user approval, the fix was committed and published as draft PR #72. No native pointer or screen-capture result claimed. Dark parity remains deferred per current milestone.
