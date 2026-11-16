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

Source review approved the pure projection/UI changes and test corrections. Final source `abd5b90` (production unchanged since `17198b2`):

- Full suite: 903 XCTest and 38 Swift tests passed; release build passed.
- iPhone build-for-testing passed; final native invocation compiled the test-only Today scope correction.
- Owned iPhone 13 Pro Simulator, iOS 26.3.1: all four native tests passed, exit 0, complete parsable `KanbanGroupingNative3.xcresult`, zero failures/skips. Actual same-card Title reversal with lane retained, Created lane/count, selected Tag lane removal, real Date range move/Undo and List drag restoration verified.
- Initial native attempt passed the existing move tests but failed new setup because All is hidden by default. Corrected tests use the observed Today scope, preserving exact seven dated-task counts and all behavior assertions. No production change was needed.
- Corrected second run logged four passes but Xcode stalled finalizing its result bundle. The owned process was stopped and artifacts retained; this incomplete bundle was not accepted. One retry with supported `-collect-test-diagnostics never` completed all four tests and its bundle. Only optional verbose diagnostics disabled, not assertions or screenshot attachments.
- Complete receipt contains four UIKit `_UIReparentingView` warnings from menu presentation. They are not claimed fixed; tested interactions passed.
- Two actual neutral screenshots were inspected and added to the tracker. Created lane screenshot includes the existing floating add button overlay near the last card; final geometry/pixel polishing remains open.
- Hosted CI for the published exact head remains required before merge.
