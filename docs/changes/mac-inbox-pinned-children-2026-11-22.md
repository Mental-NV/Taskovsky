# MAC-INBOX-PIN-CHILD-001 — Keep an undated Inbox family together under Pinned

Mac Inbox List, standard grouping with Date sort only. [MAC-04 and MAC-07](../mac-parity-acceptance.md#acceptance-matrix), [TT-005](../parity-implementation-status.md#tt-005), [UX-005](../spec/ui-ux.md#ux-005). Base `6fee45d9a0e612c94d134e6763f342688d786e1d`.

In the [actual TickTick child-task observation](../ticktick-spec/tasks.md#child-task-creation-and-completion), active linked children appeared indented under their pinned parent. A comparable guarded Taskovsky Inbox List (1060 points, two named active linked undated children) placed the parent alone in Pinned and its children flat in No Date. The detail breadcrumb confirmed the link existed. Immediate parent completion moved the active children into Completed and showed a completion toast; local Undo also restored them without changing a prior completed child. The projection, not the hierarchy storage or lifecycle, is the target.

In this one list presentation, keep an active undated pinned Inbox task together with its already visible active undated Inbox task descendants. Do not jump over a hidden, dated, completed, otherwise ineligible intermediate ancestor. Keep the current per-record pin flags, order, links, and date/section membership. Different sorts, explicit date groupings, named sections, source eligibility, persisted pin/graph operations, drag policies, Calendar and iPhone remain unaffected. The reference's deeper hierarchy and blank-child creation/persistence are not inferred.

## Acceptance

- In the standard Date Inbox List, a pinned undated parent with two eligible children is a single Pinned group of three rows (depths 0, 1, 1); collapsing the parent hides both child rows and expanding restores them. No duplicate or unrelated row is introduced.
- An independently dated, completed, abandoned, deleted, filtered-out or other-list branch does not join that parent. Confirm this separately in projection tests.
- Unpin and observe the linked family return to No Date with the same selected task and no new child pin flags. Completion and Undo still update/recover the correct records and preserve a previously completed child. This does not define TickTick Undo or all pin policies.
