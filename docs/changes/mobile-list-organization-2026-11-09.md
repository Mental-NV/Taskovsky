# MOB-ORGANIZATION-001 Lists and folders on iPhone

The November 9 local Tasks scope includes [BUS-015/016](../spec/business.md#bus-015), [IOS-009](../spec/iphone.md#ios-009) and the existing [parity register](../parity-implementation-status.md). The iPhone drawer now shows pinned shortcuts, lists above and below folders, expandable folders and archived lists. The Manage Lists sheet is accessible from the drawer. Folder expansion is session state.

The manager creates and renames lists and folders, changes list type, color, icon and placement, controls pinning and smart-list inclusion, and archives or unarchives lists. The reorder mode uses named up and down buttons inside each active list group and the folder group. Moving between groups uses the placement picker. The phone keeps an existing list's Board view mode in the file and opens the list with the phone task view.

Delete List confirms that tasks will move to Inbox and keeps unavailable saved-filter references. Ungroup Folder confirms that its lists move above the folders without losing their tasks. Duplicate List copies non-trashed records with new task and checklist IDs, remaps parent links and keeps rich descriptions, schedule and reminder values. The duplicate starts unpinned and unarchived. Desktop and iPhone share those transformations. Archive and smart-list exclusion keep their distinct eligibility rules.

Done submits a revision-checked compatible workspace change. Cancel can discard the open form, and failed writes retain its draft. The workspace replacement leaves the settings file alone. New UI and file checks use disposable fixtures. Tags, filter authoring and smart-destination preferences have their own delivery slices. [Verification](../spec/verification.md#mobile-list-organization).
