# SEARCH-HEADER-001 — Full Search query heading

Status: implementation candidate. macOS Tasks / full Search only, based on `cef532880b1802aaed9a957e269658620e45825f`. [BUS-023](../spec/business.md#bus-023), [UX-011](../spec/ui-ux.md#ux-011--search-and-saved-filters), [TT-023](../parity-implementation-status.md#tt-023).

## Reference and scope

The [November 2 native light-mode observation](../ticktick-spec/search-and-filters.md#quick-search) recorded Return from quick Search opening a full view headed “Search” plus the query in blue, followed by an edit pencil and Save as filter. Neither exact color nor logical geometry was recorded. On November 21, native TickTick 8.2.20 (922) was confirmed installed; no fresh full Search was submitted because it can add search history. No current comparison screenshot was captured.

Baseline Taskovsky used one monochrome title and a tooltip-only pencil. Keep the single 20-point bold heading and use the existing Taskovsky accent for the literal query as a visual distinction, not as a sampled TickTick color. Expose the heading and a named pencil to accessibility. Keep the title flexible and the Save as Filter label uncompressed when a long query truncates. Do not alter query data or matching, filters, the quick Search workflow, result highlighting, or iPhone.

## Verification

| State | Check |
| --- | --- |
| Normal light window, neutral stored fixture | Return opens full Search. “Search” and the literal accent query are one heading. Edit search, Close Search and Save as Filter remain reachable; title/snippet highlighting is unchanged. |
| Compact width and a long literal query | Heading truncates without displacing the pencil or Save as Filter. Verify the left-to-right order and absence of overlap. |
| Edit and dismiss | Enter editing, click the field, edit and Return. Open Save as Filter, confirm it receives the edited query, then Cancel; verify no filter is saved. A cleared query disables Save as Filter. |

Independent source review found no change to query bindings, filter inputs, dismissal actions or result construction. Native acceptance, matched screenshot and exact-head checks are separate. No dimensional or exact color parity is claimed; current reference measurements are unavailable.
