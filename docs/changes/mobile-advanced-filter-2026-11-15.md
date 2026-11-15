# T14 Advanced Filter Preview and Examples

## Approved bounded contract

Reference inventory observes Filter → Logic → Filter, Add, Examples and a dimmed empty Preview. Example contents and unseen transitions were not observed. This implementation keeps the existing nested AND/OR/NOT editor and predicates rather than inventing rule conversions.

| Element | Placement and wording | Behavior |
| --- | --- | --- |
| Filter Conditions | Advanced section | Existing nested rule tree, with Filter condition labels and Logic operator headers |
| Add | Existing group footer | Existing conditions/groups and depth limits |
| Preview | Below criteria/date bounds | Read-only results of the exact staged TaskFilter.matches predicate |
| Blank Preview | Literal empty root AND/OR only | Disabled authoring affordance with explanation; empty-group evaluation and saving are unchanged |
| Examples | Beside Preview in footer section | Read-only Taskovsky-authored AND/OR/NOT explanations, no Apply or draft binding |

Authored NOT(empty), unavailable references and zero-result trees remain previewable. Normal criteria, parked Advanced drafts, custom bounds, revision checks, cancellation and write-failure retention are unchanged. Examples are not claimed as TickTick content. Exact geometric parity is not certified.

## Verification

Independent source review passed. Full 853 XCTest + 38 Swift tests, release and iPhone compile passed. Final native 4/4 passed with exit 0 and a valid parsed xcresult (0 failures/skips/runtime warnings). Initial empty-filter test used a drawer helper that closed an already-open drawer; corrected direct selection passed, and the final full four-case run passed. Actual screenshot inspection caught wrapped Keyword labels; fixed menu intrinsic width and reverified in final run. Exact-head CI pending. Native acceptance covers real nested AND/OR/NOT preview identities and save/reload, unavailable references with zero results, Examples without mutation, blank Preview gating without changing saved predicate behavior, and write failure. Neutral screenshot inspected and attached; no personal TickTick content published. Existing deep nesting/custom-date editors remain structurally different from the reference; this is not pixel-perfect certification.
