# Atomic Mac template management

## Source-backed defect

Save as Template, template Edit/New and Delete mutate published templates before writing the workspace. Failed saves can therefore appear successful. The Settings editor also dismisses without checking save success. This is separate from the already atomic instantiation and reorder paths.

## Bounded contract

Stage these three template mutations and publish only after successful persistence. Save as Template returns nil on failure; update/delete report Bool success. Keep existing append-versus-update-by-ID, order, template capture, rich content, task data and missing-ID behavior. Do not introduce replacement-by-name or change mobile transactions/schema. Delete here refers to implementation of the existing UI operation; QA uses owned disposable records only.

Settings Edit/New keeps its draft open on failed Save, displays a 12-point red error above actions, and permits explicit retry or Cancel/Escape. Successful Save dismisses. Existing storage error UI remains authoritative; generic storage Retry does not replay a rejected mutation. Reordering/preview/applying retain their existing behavior.

## Verification plan

Reproduce each failed mutation against a disposable obstructed workspace file and verify original published templates/task data remain. Restore the destination and explicitly repeat the action, verifying durable exact-once result, order and metadata. Cover new/update/delete, missing IDs and protected recovery. Full tests/build, independent review, native owned Edit failure/retry/cancel where feasible, and exact-head CI before merge. No broad store-atomicity or reference-parity claim.

## Verified checkpoint

The pre-fix regression failed six assertions. Full local tests, signed Mac build, independent source review, native failed-Save retention/explicit retry and final wrapped-error/Cancel checks passed. The first run exposed error clipping; final error text wraps vertically. See [evidence and limits](../spec/verification.md#template-management-atomic). Exact-head CI is checked before merge.
