# Treat preceding numeric clocks as whole tokens

## Reproduction and scope

The preceding-clock recognizer can begin inside a colon-separated numeric token: `at 25:10:15 tomorrow` is treated as `10:15 tomorrow`. That assigns a time not accepted from the full input and removes the inner fragment when Remove date text is enabled.

Reject a preceding-clock match starting immediately after a digit or a digit-plus-colon. Leave the malformed clock literal while still recognizing the independent date phrase. Keep valid whole preceding 12/24-hour clocks, punctuation-separated inputs, trailing valid clocks and existing whitespace policy unchanged. This is a narrow shared capture correctness correction, not a general grammar rewrite or TickTick behavior claim.

## Acceptance

Regression coverage must verify the recognized span, timed flag and captured title for numeric fragments; shared Mac creation and iPhone TaskCaptureInput must agree. Valid preceding clocks and removal-disabled controls must remain unchanged. Run full tests, Mac/iPhone builds, independent review and exact-head CI. No unrelated date arithmetic, timezone, recurrence or reminder policy changes.
