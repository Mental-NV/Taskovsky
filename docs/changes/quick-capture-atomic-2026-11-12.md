# Atomic ordinary Mac QuickEntry capture

## Source defect

Legacy ordinary creation publishes a new task and parsed tags before a failed write, returns an ID and lets QuickEntry clear its draft/select a phantom task. Section and Calendar capture already have acknowledged staged creation.

## Bounded change

Add an optional-result Mac QuickEntry creation API using the same TaskCreation rules and staged persistence helper. App accepts only a successful result; rejection retains the complete composer through its existing acknowledgement. Preserve list/Inbox/default/context-date/kind/body/recognition/tag/reminder/insertion semantics. Existing optional URL enrichment starts only after initial persistence succeeds.

Legacy createTask callers such as Summary, mobile capture, and the existing later destination-tag/reminder updates are unchanged. This is initial capture atomicity, not all-store transactional behavior or cross-process concurrency control.

## Verification

Reproduce failed ordinary creation before the fix. Cover failed write, unchanged workspace, retry exactly once, defaults/context/body/tags/reminders and top/bottom order; compare successful constructed records with TaskCreation. Native owned failed Add must retain full draft; retry once must persist coherent task. Full tests/build, independent review and exact-head CI before merge.
