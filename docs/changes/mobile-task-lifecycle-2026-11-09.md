# MOB-LIFECYCLE-001 · Local task lifecycle

Approved scope follows the autonomous Tasks and Calendar goal and IOS-004/D09. The implementation lives in the isolated mobile worktree based on merged specification commit 6ee96ee.

Extract the existing Mac graph rules for completion, reopening, recurrence, pinning, movement and Trash into the shared domain. The Mac store remains the persistence and observation facade. The phone stages those commands against the loaded revision and publishes the result after local persistence. Keep the workspace format, cascade ledgers, rich content and unrelated records intact. Keep pristine successor snapshots in memory and preserve successors when their pristine state cannot be established.

Expose separate task row completion and detail navigation. Detail provides status, Pin, Move to List, Move to Trash, Restore and a named Delete Forever confirmation. Notes have no completion action. Archived items can move out into Inbox or an active list. Restore and purge apply to individual trashed records under the existing rules. Confirmed completion and Trash allow Undo while the saved revision is still current. Use the shared pinned grouping. Calendar detail uses the same commands.

Verify shared Mac behavior, guarded writes, failure outcomes, recurrence and subtree changes, user-visible phone flows and Mac reload of neutral simulator fixtures. Record layout and verification limits separately from the task rules.

## Verification

The Mac suite passed 534 cases. The signed Mac build passed strict signature checks. The full simulator suite passed 78 of 79 cases and the corrected capture timing check passed in a focused rerun on identical app binaries. All six new native lifecycle cases passed in the full run. The 29 file audits and 28 Mac fixture reloads passed, along with the focused capture file and reload. The phone action sheet, drawer hit-area correction and remaining parity gaps are described in the verification ledger. [Lifecycle verification](../spec/verification.md#mobile-task-lifecycle).
