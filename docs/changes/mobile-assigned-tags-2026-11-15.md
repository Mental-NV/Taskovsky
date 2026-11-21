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


## Verification receipt
- Source checkpoint `9459da6`. Independent source review reported clean by coordinating parent.
- Owned Simulator run session 56579: both `testAssignedTagsPartitionSearchAndCloseDiscard` and `testAssignedTagsSaveRetainsUnavailableIDsAcrossRelaunch` passed, as reported by coordinating parent.
- Full 835 XCTest + 38 Swift Testing / release run 95844: **passed**, including signed release and independently reverified signature (exit 0). Hosted exact-head CI and merge gates remain pending.
- Actual 1170×2532 owned Simulator screenshot inspected: neutral Planning/Studio fixture and unavailable-ID notice only, no personal data. Unmodified image [D04 assigned tags](../assets/mobile-parity/2026-11-15/d04-assigned-tags.png).
- SHA-256: `1e40871b196a8ccd286542ca352fb950b006a5b8781505fb7292509eebfb24ab`.
- Remaining: matched reference layout and reference save timing unverified; no pixel-perfect claim.
