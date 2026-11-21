# SEARCH-HEADER-001 — Full Search query heading

Status: native acceptance for the bounded header change. macOS Tasks / full Search only, based on `cef532880b1802aaed9a957e269658620e45825f`. [BUS-023](../spec/business.md#bus-023), [UX-011](../spec/ui-ux.md#ux-011--search-and-saved-filters), [TT-023](../parity-implementation-status.md#tt-023).

## Reference and scope

The [November 2 native light-mode observation](../ticktick-spec/search-and-filters.md#quick-search) recorded Return from quick Search opening a full view headed “Search” plus the query in blue, followed by an edit pencil and Save as filter. Neither exact color nor logical geometry was recorded. On November 21, native TickTick 8.2.20 (922) was confirmed installed; no fresh full Search was submitted because it can add search history. No current comparison screenshot was captured.

Baseline Taskovsky used one monochrome title and a tooltip-only pencil. Keep the single 20-point bold heading and use the existing Taskovsky accent for the literal query as a visual distinction, not as a sampled TickTick color. Expose the heading and a named pencil to accessibility. Keep the title flexible and the Save as Filter label uncompressed when a long query truncates. Do not alter query data or matching, filters, the quick Search workflow, result highlighting, or iPhone.

## Verification

| State | Check |
| --- | --- |
| Normal light window, neutral stored fixture | Return opens full Search. “Search” and the literal accent query are one heading. Edit search, Close Search and Save as Filter remain reachable; title/snippet highlighting is unchanged. |
| Compact width and a long literal query | Heading truncates without displacing the pencil or Save as Filter. Verify the left-to-right order and absence of overlap. |
| Edit and dismiss | Enter editing, click the field, edit and Return. Open Save as Filter, confirm it receives the edited query, then Cancel; verify no filter is saved. A cleared query disables Save as Filter. |

## Results — November 21

- Product revision `08a40739219724b9d15955215af43559ff514005`: Mac Xcode 27.0 full Swift test command, release build and strict signature check passed. Independent source review found no change to query bindings, filter inputs, dismissal actions or result construction.
- Guarded Taskovsky QA debug build used identical Search source and disposable workspace/settings. Missing and mismatched launch arguments were refused. Return opened full Search; the prefix used primary text and the query was blue at observed normal (1060 × 700) and compact (780 × 580) capture sizes. A narrower window truncated a long title without hiding either action; the accessibility heading retained the full query, and the pencil had its own label. These are capture sizes, not calibrated TickTick geometry.
- Clicking Edit search opened the field; clicking the field, changing the query and pressing Return updated heading and results. Existing yellow title/snippet highlights remained visible. Save as Filter opened with the synthetic query prefilled; Cancel returned to Search. Empty query displayed “Search” and disabled Save as Filter. Fixture hashes were unchanged and the QA process was quit.
- No screenshot was exported. Exact TickTick hue, geometry and the fresh matched comparison remain unverified. Dark appearance, full keyboard traversal and VoiceOver were not exercised. [Product CI](https://github.com/Mental-NV/Taskovsky/actions/runs/44920728152) is separate from native interaction. [PR #167](https://github.com/Mental-NV/Taskovsky/pull/167).
