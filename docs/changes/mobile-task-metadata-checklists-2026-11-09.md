# Mobile task priority, tags and checklists

Task detail can set priority, choose existing tags, and manage embedded checklist items. Priority and checklist checkmarks are discrete local commands. Tag membership and checklist text, order, additions and removals are staged until Done. The checklist editor keeps a pending nonempty entry in its draft and asks before discarding changed text. Staged checklist edits live in the open editor.

Commands own only the selected metadata and modification time. They validate the workspace revision, compatible document, active record and item or tag identities. The commands preserve rich descriptions, linked subtasks, schedules, templates and settings. Missing saved tag references stay in place until explicitly removed. Checklist paragraphs in a rich description remain part of the description preview.

The phone uses the same embedded ChecklistItem records as the Mac. Calendar inherits their saved titles, order and completion through the existing projection. Verify the result on the simulator and reload the isolated files through Mac TaskStore.
