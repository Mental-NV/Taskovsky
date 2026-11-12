# Atomic Mac Calendar task creation

## Source-backed defect

The new Calendar task editor uses legacy creation, publishes task/tags before saving, announces success and dismisses even after a workspace-write failure. Both the workspace handler and shared editor button dismiss unconditionally. Timeline/template creation already have atomic paths.

## Bounded contract

Add a Calendar-specific optional-result creation API using the existing staged persistence helper. Construct task, recognized tags, duration and reminder defaults together using existing creation rules. Publish only after successful persistence; optional existing URL enrichment runs only after success. Preserve top/bottom insertion, explicit list/Inbox policy, all-day/timed range normalization and defaults. Reject invalid title/range input before writing.

For new Calendar tasks only, failure retains title, list, range and all-day draft, shows a wrapping 12-point red error above actions, and leaves Add Task available for explicit retry or Cancel/Escape. Do not announce success, select a phantom task or clear prior undo on failure. Success closes the editor and keeps existing Calendar-filter notice behavior.

Existing Schedule/Timeline edit behavior, ordinary Tasks quick-add, Summary saving and iPhone creation remain unchanged. No general transactional-store, notification-delivery or TickTick gesture-parity claim.

## Verification plan

Reproduce original failure using a disposable file obstruction with timed/all-day and top/bottom cases. Verify no published task/tag/reminder state on failure, and explicit retry produces one durable coherent task. Cover invalid input and recovery guard. Full tests/build, independent review, native owned Calendar Add Task failure/retry/Cancel, and exact-head CI before merge. Preserve original worktrees and stable QA identity.
