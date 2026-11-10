# TASK-ACTIONS-001 — Local iPhone Duplicate and Convert

## Duplicate

Task Actions offers Duplicate for a task or note in Inbox or an active list. The action writes a copy through the shared lifecycle transaction and opens the copied detail on success. Previous task returns to the original. Trash and archived detail omit the action. A stale revision or a reused copy ID refuses without adding another task.

The copy shares the Mac policy. The new root remains in the same list and parent slot, opens with fresh identity and starts its own recurrence at position one. Copied descendants retain their existing states and point into the copied hierarchy. Deleted descendants are excluded. Content, rich formatting, checklist completion, schedule and reminders carry over. Checklist IDs are regenerated, and recurrence-source links and occurrence-only restoration baselines are removed from each copy. The transaction leaves original records and settings intact.

## Convert to Note and Convert to Task

Task Actions changes an eligible record in place. Both directions open the result by clearing the completed and Won't Do dates. The UUID, list, tags, rich description, checklist, schedule and reminders remain on that record, and existing hierarchy links remain intact. A converted note presents its checklist read-only. Converting it back brings back the task's scheduling and checklist editing controls. A kind change uses the same series reconciliation as the Mac detail editor, which clears an occurrence-only restoration baseline and uses the displayed schedule. Archived and trashed records cannot be converted.

The [TickTick Mac task menu](../ticktick-spec/tasks.md#active-task-context-menu) and [iPhone reference](../spec/iphone.md#task-action-and-editor-mapping) show these actions. The copy and conversion semantics above follow Taskovsky's Mac behavior. [Verification](../spec/verification.md#mobile-task-actions).
