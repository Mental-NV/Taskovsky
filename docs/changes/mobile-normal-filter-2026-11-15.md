# T13 Normal Filter conditions and Preview

## Element and behavior contract

Observed saved-filter reference structure is Filter Conditions with List, Tag, Date, Priority rows, All summaries, Include keyword, Type and footer Preview. This slice applies only to Normal saved filters. Search retains its existing section, ordering, plural Lists/Tags/Dates labels and Any summaries.

| Element | Placement / wording | Real behavior |
| --- | --- | --- |
| Filter Conditions | Normal form section | List → Tag → Date → Priority navigation rows |
| All summaries | Empty unconstrained selections | Existing empty-array predicate semantics; no normalization on opening |
| List/Tag/Priority/Type All | First selector row | Explicitly clears criteria; Tag also resets restrictive tag mode to Any selected |
| Include keyword | Below conditions | Existing task search predicate, not title-only matching |
| Type | Beneath keyword | Existing Tasks/Notes multi-selection |
| More | Below primary criteria | Preserves Status and Tag matching controls/values |
| Preview | Footer navigation | Read-only task results using the same TaskFilter.matches predicate as match count and saved filter |
| Done/Cancel | Existing toolbar | Existing revision-checked save, failed-write retention and discard confirmation unchanged |

No changed predicate evaluation, advanced-rule precedence, Normal/Advanced parked drafts, custom date bound policy or unavailable list/tag retention. Restrictive No tags/Any tag modes remain unchanged on opening and are shown honestly in the Tag summary; explicit Tag All clears both IDs and mode. Ordinary tag choices preserve the current More matching mode, as before.

Preview does not mutate tasks or save the filter. It reflects the current workspace and current staged criteria, including explicit archived-list selection through the existing predicate. Existing header name/mode/pin/count and custom-range editors remain. Their exact visual fit and unseen reference transitions are not certified.

## Verification

- Source and semantic review clean after fixing restrictive Tag-mode All behavior.
- Full 853 XCTest + 38 Swift tests and release passed; final iPhone compile pending.
- Production helper tests verify explicit Tag All restores both tagged/untagged matching while preserving other criteria, and opening restrictive empty modes is not mislabeled All.
- Native multi-criteria preview/persistence/cancellation, restrictive Tag mode reset, Search archive, Advanced and failed-write regressions pending while another coordinated native task owns the Simulator.
- Exact-head CI and final actual screenshot pending. No pixel-perfect acceptance claim.
