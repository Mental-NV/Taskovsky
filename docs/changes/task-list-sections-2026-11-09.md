# TASK-SECTION-001 — Named sections in regular lists

TickTick documents adding sections to regular lists, renaming or deleting them, dragging sections and tasks, and creating a task within a section. Those interactions set the scope for the Taskovsky List and Board interfaces. The available reference evidence does not establish the deletion effect on member tasks or exact sort precedence. [TickTick grouping guide](https://help.ticktick.com/articles/7056594711640801280) · [TickTick Kanban guide](https://help.ticktick.com/articles/7055782353376903168#editing-sections)

## Shared model

Section names are trimmed and must contain text. Stable identifiers distinguish sections independently of their names. A regular list owns its ordered definitions. Root tasks can belong to one of those sections, and their descendants inherit the root’s section in the List and Board projection. No Section holds unassigned tasks. Moving a root to another list clears its former membership. Duplicating a list creates new section identifiers and remaps the copied roots. Removing a section clears its assignments and retains every task and descendant.

Archived lists keep their section data and refuse edits. Generic list edits preserve section definitions. Generic task edits preserve membership for a root that stays in the same list. Revision-checked changes reject stale assignments before saving.

Files with section data use a listSectionsV1 task collection envelope. A pre-sections writer fails to decode it and retains the file through the existing unreadable-data protection. Files without section data retain the previous task collection format, including the occurrence schedule format when required.

## List and Board controls

On Mac, use Manage Sections in the list's More menu. On iPhone, open Manage Sections beside the List and Board switch. The organizer adds, renames and removes sections, offers Move Up and Move Down, and provides a drag handle. Removing a section asks for confirmation and moves its tasks to No Section. Archived lists show their sections read-only.

Both platforms show the saved section order in List and Board. Active pinned rows retain their Pinned group in List. A top-level task can move through its menu or by dragging to a section header or Board column. A section's Add task action saves the new task and assignment together. The iPhone capture sheet also offers the section for the chosen list. Lists without sections retain the status Board. In a section Board, moving a card changes membership and preserves status. Intra-column Board ordering is separate from membership.

A failed Mac section save keeps the previous workspace visible. iPhone uses a revision-checked workspace transaction. The organizer uses its grip to reorder rows within the sheet. Dropping outside the visible section rows leaves the saved order intact. The verification record separates the Mac and iPhone grip checks from the earlier menu checks. [Verification](../spec/verification.md#task-list-sections).
