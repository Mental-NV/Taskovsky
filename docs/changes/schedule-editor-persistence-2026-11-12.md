# Acknowledged Mac schedule editor saves

## Problem

Mac ScheduleEditor OK/Clear calls the generic void updateTask writer and dismisses regardless of persistence. That writer publishes before a disk write, so a rejected write loses the staged editor and displays a schedule that is not durable. The editor also passes a whole task snapshot, although it owns only scheduling fields.

## Bounded contract

Keep the editor's opening task as a stable baseline. OK/Clear submits a schedule-only candidate plus that baseline to an acknowledged store operation. Refuse missing, deleted, archived, kind/status-changed or schedule-changed tasks without overwriting newer state. Concurrent unrelated title/body/tags/progress/list edits survive; an allowed move to another active list need not invalidate an otherwise unchanged schedule. Copy only schedule fields onto the current record, then apply existing schedule coherence, repeat-series reconciliation and end-reminder normalization. Do not change generic text autosave, creation, Calendar gestures or iPhone editing policies.

Persist the final staged workspace before publication. On failure retain the complete date/time/duration/repeat/reminder/timezone draft and present an inline failure message; do not dismiss. Explicit retry with unchanged baseline may save once. A stale baseline requires reopening rather than silently rebasing. Clear follows the same contract. Successful save closes the editor as before. Cancel/Escape remains a deliberate discard.

## Verification

Owned write-failure regression for OK and Clear, successful retry/reload, full schedule fields/recurrence coherence, unrelated concurrent content preservation, stale schedule/status/kind and archived/missing refusals. Native owned QA verifies failed OK remains open with draft and explicit retry persists, with limits recorded. Full tests, signed build, independent review and exact-head CI gate merge.
