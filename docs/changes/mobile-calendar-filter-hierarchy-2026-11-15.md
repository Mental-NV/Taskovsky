# C05 Calendar Filter View Range hierarchy

Evidence: mobile surface inventory C05 observed All first, Tags expanded, Inbox, lists and expandable folders. Assigned to Me/subscribed calendars are not supported by Taskovsky's local domain and are deliberately not fake controls.

| Element | Structure/wording | Behavior |
| --- | --- | --- |
| Header | Filter View Range | Existing Cancel/Done staged save and expected revision retained; reference checkmark visual differs |
| All | First section | Existing selectAllSources; children remain unchecked in All mode |
| Tags | Expanded local disclosure after All | Existing individual tag union selection and Select all tags retained |
| Inbox | Before lists | Existing setInboxSelected, additive union with tags/lists |
| Lists and folders | Above-folder, workspace folder order with active children, below-folder/orphan lists | Expansion only presentation state; list selection unchanged; Only route retained |
| Bulk lists | Final dedicated row | Existing Select all lists and Inbox retained, moved below hierarchy |
| Unavailable sources | Existing warning/removal section | IDs retained until explicit cleanup; archived target filtering unchanged |

No domain selection changes. Existing union, last-deselection-to-All behavior, selectOnlyList and saveCalendarOptions(expected original revision) remain. Folder and Tags expansion are local transient UI state and do not change stored folder settings or selected IDs. Folder and Tags AX identifiers live on labels only, not containers. Unsupported Assigned to Me and subscription sources absent; exact row geometry, nested tag hierarchy and reference folder initial state remain unverified.

Added neutral calendar-filter-hierarchy fixture only puts existing Work in Projects without altering tasks. Native coverage added for expansion without selection mutation/Cancel, tag-only actual result filtering, additive Inbox union, save/relaunch and All reset. Existing reset/overview Only routes reveal their lower list row before tapping. Tests not run at source checkpoint; parent owns independent review/native/full/CI and screenshots. No personal assets.
