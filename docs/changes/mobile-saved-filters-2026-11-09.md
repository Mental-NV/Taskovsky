# MOB-SAVED-FILTERS-001 Saved filter authoring on iPhone

The November 9 local Tasks scope includes [Normal filters](../parity-implementation-status.md#tt-024), [Advanced filter logic](../parity-implementation-status.md#tt-025) and the [iPhone organization and search contracts](../spec/iphone.md#ios-009). Manage Filters opens from the drawer toolbar, including when the drawer's Filters section is hidden. Pinned filters appear in Pinned.

The iPhone editor has separate Normal criteria and Advanced rule controls. Normal mode edits keyword, status, list and tag selections, tag matching, priorities, task types and date rules, including custom bounds. Advanced mode edits the shared AND, OR and NOT tree and its typed conditions. A live match count uses the same task matcher as the saved destination. Switching an existing advanced filter to Normal asks before replacing its tree on Save. Cancel discards the staged form.

Missing list and tag references remain part of a saved filter until deliberately changed. Renaming an advanced filter preserves its tree. Done checks the workspace revision and compatibility, and a failed save retains the draft. Delete removes only the named filter and leaves the tasks and settings. The phone uses its own presentation and shares the Desktop filter values and predicates.

The [verification record](../spec/verification.md#mobile-saved-filters) distinguishes the native checks, portable contracts and Mac file reloads. Full-search authoring, tag management, and Summary have separate coverage and delivery work.
