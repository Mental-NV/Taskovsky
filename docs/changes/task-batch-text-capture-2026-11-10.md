# TASK-CAPTURE-002 — Add multiple tasks from text

The active local Tasks and Calendar parity objective authorizes this work on Mac and iPhone. The isolated branch carries the earlier batch capture implementation forward to merged `main` at `aba0b9b78a2b6af3dede10542234ba3eed0bc805`.

Open Add Multiple Tasks from the Tasks actions menu. Type or paste text, review the generated tasks, then add them together. Each nonblank line becomes one task in pasted order. Whitespace around titles and blank lines are ignored. Separate identical lines remain separate tasks. Review shows the target list and the titles, dates and tags to be saved. The user can go back, change the text or disable recognition. Cancel discards the draft.

The command follows the regular local capture defaults for the active Tasks destination, priority, date, reminders and saved tags. An active regular task list and Inbox take precedence over the default list. Today, Tomorrow and Next 7 Days supply their normal contextual dates. Existing date and tag recognition applies per line. The reviewed title stays authoritative, and the batch can reuse existing tags. A line that would lose its entire title stops review and identifies the line. Recognition can be disabled for literal titles. Input and preview stay in memory until confirmation.

Save inserts all tasks in one workspace transaction, in the reviewed order at the configured top or bottom. Settings stay byte-identical. Each reviewed task has a stable identity. If a write reports an error after replacement, read back the batch to distinguish success from failure or uncertain state. A stale workspace or settings revision requires a new review. A retry of the same batch uses the same identities. A partial match or conflicting identity never inserts a second batch. The command adds no new JSON fields.

TickTick documents creating multiple tasks from copied lines with a confirmation. Taskovsky uses an explicit text entry and review on both platforms. [TickTick Add Tasks](https://help.ticktick.com/articles/7055782422935240704).

Check both native entry points, cancellation, recognition, order, exact saves, stale refusal, failed write and retry after replacement. [Business rules](../spec/business.md) · [Mac UI](../spec/ui-ux.md) · [iPhone UI](../spec/iphone.md) · [Parity](../parity-implementation-status.md).

[Mac and iPhone verification](../spec/verification.md#task-batch-text-capture).
