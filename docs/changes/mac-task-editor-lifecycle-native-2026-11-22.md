# Mac task editor and lifecycle checks

These are guarded native Taskovsky checks with disposable fixtures, not fresh TickTick comparisons. The [Mac acceptance matrix](../mac-parity-acceptance.md#acceptance-matrix) remains open.

## Task editor and draft ownership

At [`45b947b`](https://github.com/Mental-NV/Taskovsky/commit/45b947b60576c84caa2dfcfe79cb45053f1b2a6b), same source tree as signed `fa56000`, title and description saves were already on disk while their editor was still focused in the 1060×700 dock. At 382×584 the drawer showed both changes and retained unsubmitted checklist text. The standalone window shared that same task’s text and checklist draft; closing, opening a different task with a blank draft and reopening the first preserved isolation. Only the intended title, description and update timestamp changed. The checklist itself did not change.

Opening Schedule in the standalone window then switching via the Window menu did not expose a second or stale popover. Switching key windows can dismiss transient UI, so this does not establish simultaneous popover behavior; Tags, Templates, input method composition, app relaunch and TickTick comparison were not exercised.

## Task lifecycle and hierarchy

At [`75a21c3`](https://github.com/Mental-NV/Taskovsky/commit/75a21c333dc9ae1b33789ff98b60e809e00cd978), same source tree as signed `c649fd8`, a 1060×700 Inbox began with a pinned parent and active child and one previously completed child. Completing the parent moved all three to Completed and recorded only the newly completed child in the cascade. Explicit Reopen restored the parent and that child; the previously complete child kept its original state. The archived control was hidden from Inbox, visibly read-only when selected in its list and untouched.

A separate synthetic checklist task moved to Trash and explicitly restored to Inbox. Undo was visible but not invoked. Only the parent, formerly active child and checklist task update timestamps differed from the seed after the round trips; unrelated records, schedule fields and final cascade ledgers were unchanged. Minimum width, parent subtree Trash, Undo activation and fresh TickTick were not tested. The [dated TickTick task probe](../ticktick-spec/tasks.md#child-task-creation-and-completion) covered completion with two unchecked children, not this same lifecycle.

QA stopped and original fixture, settings and signed app state were restored after each check.
