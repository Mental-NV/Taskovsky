# D04 assigned Tags sections

Reference: mobile-surface-inventory-2026-11-14.md D04 observed Input Tag, assigned tags in a checked section, remaining tags below, and × returning to detail. Save timing, exact sizes, hierarchy, and new-tag creation were not observed.

| Element | Placement/wording | Behavior |
| --- | --- | --- |
| Search | First section, Input Tag | Existing case-insensitive localized substring search; both partitions filtered |
| Assigned tags | First tag section | Checked current draft membership, workspace order; deselect moves into remaining |
| Remaining tags | Second tag section | Unchecked draft membership, workspace order; select moves into assigned |
| Close | Leading ×, accessible Close | Existing discard guard; no write on dismissal |
| Done | Trailing existing Done | Existing expected-revision metadata transaction; no guessed autosave |
| Unavailable tags | Existing final section | IDs preserved unless explicit removal; never silently filtered from saved draft |

Only Tags gets the new Close presentation; Priority/Progress/Checklist retain Cancel. Sections have no invented visible heading. No domain semantics or storage changes. Neutral assigned-tags QA fixture contains Planning, Studio and one unavailable reference. Native coverage checks partition order, selection movement, search/no-match, dirty dismissal, save/relaunch and unavailable ID retention. Parent owns execution, review and CI; source-only checkpoint does not claim tested or pixel-perfect parity.
