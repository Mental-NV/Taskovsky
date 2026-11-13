# TASK-TRASH-001 — Read-only embedded checklist in Trash rows

TaskRow's main completion and rename controls reject deleted tasks, but its embedded checklist only guarded archived readOnly state. App passes that flag for archived lists, not Trash, leaving checkbox mutations possible on deleted tasks when checklist previews are shown.

Apply the same deleted-or-readOnly guard to both checklist button enabled state and action. Active and restored tasks retain edits; archived tasks stay locked. No store/persistence, restore, deletion or detail behavior changes. Reference Trash controls expose Restore/Delete Forever, but this repair is source-backed UI consistency, not a claim about unobserved TickTick checklist semantics.

Acceptance: active checklist changes; Trash checkbox disabled and unavailable for activation; restore retains original state and re-enables; archived disabled. Unit policy regression plus native AX and full build/CI/review required. No screenshot or capture/settings changes.
