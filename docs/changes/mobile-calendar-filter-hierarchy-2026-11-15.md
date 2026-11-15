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


## Verification receipt
- Coordinating parent reports initial three native checks passed (existing reset, overview filtering and tag/Inbox union); final three passed (folder expansion/Cancel without mutation, nested list actual results/save/relaunch, tag/Inbox union). These are overlapping runs, not six distinct new scenarios.
- Coordinating parent reports full **838 XCTest + 38 Swift Testing**, release and signature passed. Source review clean; exact-head hosted CI remains a merge gate.
- Source `77d6801`, later nested selection test `4109f13`, main integration `024417d`. No test bypass or weakened selection assertions.
- Safe actual screenshot inspected: neutral fixture only, [C05 hierarchy](../assets/mobile-parity/2026-11-15/c05-source-hierarchy.png), unmodified 1170×2532. SHA-256 `58c9e1053b6a5f1833061fb1a95b26d810f483377ebda967a22937befc854cc7`.
- Existing bulk row is below the visible capture edge; no claim that all rows fit one screen. Exact reference geometry, unsupported source choices and nested-tag presentation remain partial/unverified; no pixel-perfect claim.
