# Acknowledge lifecycle storage before publishing

## Existing problem and boundary

Mac single-task lifecycle actions stage a TaskLifecycle value, then publish workspace and recurrence-Undo snapshots before attempting storage. Failure leaves visible completion/deletion/movement/duplication that is not durable. Completion, trash and restoration feedback can also claim success. The existing batch lifecycle path already writes the staged workspace first.

## Contract

Write the staged lifecycle workspace before publishing either data or its transient recurrence snapshots. A rejected mutation or failed write returns false; accepted no-op semantics remain unchanged. On write failure preserve all pre-action task/graph state and Undo snapshot ownership. A later explicit retry applies the action once. Preserve existing recurrence, cascade, pristine-successor checks, ordering, archived eligibility and task/note rules; do not rewrite their policies.

Mac action feedback and completion sound must follow a successful accepted mutation, never a failed write. Lifecycle Undo checks the active claim without consuming it, attempts persistence, and consumes/clears only on success. Failure retains the original claim until its existing expiry, not a newly extended Undo window. The existing storage banner reports persistence errors. No changes to user records outside explicit actions, and no change to the independently transactional iPhone lifecycle adapter.

## Verification

Owned failed-write regressions: recurring completion/successor creation, failed Undo and explicit retry, trash, restore, duplicate and move. Verify no phantom state/ID, preserved successor snapshots, exactly one accepted retry and reload equality. Guard completion/trash/restore success feedback. Review token expiry/stale-token behavior and existing lifecycle tests. Native owned QA should confirm failure feedback/state and accepted retry before making UI claims. Full tests, release build, independent review and exact-head CI gate merge.
