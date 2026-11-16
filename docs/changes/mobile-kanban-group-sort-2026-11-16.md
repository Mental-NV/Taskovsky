# T03/T04 scoped Kanban grouping and Title sorting

## Approved bounded scope

The user requests real mobile Tasks/Calendar behavior before final pixel polishing. The November 16 live reference observation confirmed scoped Today Kanban grouping List, Date, Created Time, Tag and Priority (no None), and Title direction visibly reordering within the selected No Tags lane. Reference state was restored. Personal reference screenshots are withheld.

This slice adds Created Time and Tag to existing scoped mobile boards and optional Title ascending/descending sorting within every lane. Ordinary list status boards and section boards are unchanged. Session-only per-destination settings do not mutate List sorting, task data, revision, pin state or order. Existing Order restores incoming board order; it is a Taskovsky compatibility option, not a claimed TickTick choice.

## Element and behavior contract

- Tasks overflow → Group & Sort retains its existing menu. Group by order is List, Date, Created Time, Tag, Priority. Each is a real projection, not a label alias.
- Sort by provides Existing Order and Title directions. Native menu selection/checks, existing type sizes and 44pt outer entry remain. Full reference sheet geometry is not claimed.
- Tag lanes use stable tag UUID IDs (duplicate names remain distinct); named lanes then No Tags. Each task appears once, using its first known tag in workspace order. Deleted/unknown tags do not invent names. This is inherited Taskovsky policy; reference multi-tag duplication is unverified.
- Created Time uses existing Taskovsky civil-day grouping in the display calendar/timezone, newest day first. Exact reference creation bucket policy is unverified.
- Title uses existing numeric/case/diacritic-insensitive Taskovsky comparator; equal keys retain incoming order in either direction. Exact reference collation is unverified. No new pin-first partition is introduced.
- Candidate membership and archive exclusion match existing scoped/Priority boards, including existing history policy. No global task union, hierarchy changes, data writes or saved-filter broadening.
- Sorting preserves selected lane ID. Grouping clears selected/targeted lane, pending move dialog and drag session. Removed lane falls back to first remaining lane.
- Tag/Created Time/Priority have no drop targets, move actions or drag grips. Date/List retain their existing revision-checked move engine; switching back restores it.

## Explicit remaining gaps

Other observed sort choices (Priority, Date, Tag, Created Time, Modified Time) and tag subsections under Priority+Tag remain unimplemented here because simple comparators would not reproduce the observed subsection behavior. No fabricated None grouping, multi-tag duplication, timeline handles or full reference parity claim. Ordinary list/section boards remain a separate feature. Accessibility-specific layout, dark theme, persistence polish, Background and Share/Print remain deferred without removing existing support.

## Verification

Source review approved the pure projection/UI changes. Domain suite, release and iPhone compile are being collected; native checks and exact-head hosted CI are pending. This receipt is not completion evidence yet.
