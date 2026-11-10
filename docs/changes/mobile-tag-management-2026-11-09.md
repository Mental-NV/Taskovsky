# MOB-TAGS-001 Tag management on iPhone

The November 9 local Tasks scope includes [nested tags and merge](../parity-implementation-status.md#tt-019), [BUS-017](../spec/business.md#bus-017) and the [iPhone organization contract](../spec/iphone.md#ios-009). The [TickTick macOS inspection](../ticktick-spec/lists-and-tags.md#tag-hierarchy-and-editor) observed hierarchical tags, a parent selector, pin, merge and delete. Taskovsky follows its own existing reference and hierarchy rules for the effects of those actions.

## Phone interaction

Manage Tags opens from the drawer toolbar, even when the Tags section is hidden. New Tag and Edit Tag use a native form with name, color, parent and pin controls. Done validates and saves the staged form. Cancel asks before discarding edits. Reorder moves a tag among its siblings and saves each accepted move. Parent changes are made in the editor. Pinned tags are shortcuts in Pinned. The Tags section has separate row and disclosure controls. Expanding or collapsing a branch persists its state. Selecting a parent shows tasks tagged with it or a descendant.

Merge and delete require confirmation. Merge rewrites references in tasks, templates and saved filters and updates the default tag when necessary. Delete removes task and template references, promotes children and clears a matching default. Saved filters keep unavailable tag IDs, so deleting a tag does not broaden the filter. The phone prevents invalid parent selection and rejects newly entered duplicate names. Desktop keeps its existing presentation and calls the shared tag rules.

## Storage and verification

Done checks the loaded workspace revision and compatibility before applying a command. A merge or deletion that also changes the default tag stages both file replacements in a local journal. Recovery on load finishes only if each file matches its recorded original or replacement content. Unexpected content stops recovery and preserves the journal and files. Other writes wait until the completed journal can be removed. An unconfirmed save leaves the form open. The settings write changes only the default-tag member.

Acceptance covers creating, assigning and pinning a child; reordering and staged editing; descendant merge and saved-filter matching after relaunch; deletion with an unavailable filter; and interruption between file replacements. Verification uses disposable iPhone data, Mac regression and release checks, and exact file comparisons. Physical-device, VoiceOver and Dynamic Type checks are separate.
