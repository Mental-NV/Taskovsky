# Supported iPhone Sort & Group sheet

Status: In implementation, unverified. Bounded first UI slice of [the screenshot plan](mobile-sort-group-sheet-plan-2026-11-14.md), based on merged plan `a7276b6`. Independent of Priority Board PR96.

Replace List-mode nested sorting menus and the existing concrete-list Sort popover with a light bottom sheet. Use separate Group by / Sort by pill grids, blue selected treatment, a timestamp direction control and a real restore footer. At standard text size use three columns; accessibility categories use one column and scrolling. Minimum 44pt targets, selected accessibility traits, native sheet dismissal and medium/large detents. Geometry is a native approximation, not measured reference parity.

Only existing working options are exposed: Default Groups / Date / Created Time grouping where currently supported; Created Time / Modified Time / Priority sorting. Default Groups is deliberately not labelled None because it preserves existing section/default semantics. Unsupported List/Tag/Priority grouping and Date/Title/Tag sorting are not inert pills. Board menus remain unchanged. This does not complete the six-choice reference grids.

Preserve existing preference keys/scope, matching, pinning, finished groups, order storage, model setters and drag invalidation. Each explicit choice applies immediately and closes the sheet, preserving existing menu policy rather than guessing TickTick interaction. Group selection is explicit (use Default Groups to reset) and independent of sorting. Timestamp direction is separated from criterion: switching timestamp criterion retains its current direction, or starts newest-first when no timestamp sort is selected. Priority keeps its existing high-to-low behavior. Restore default sorting clears only sorting, not grouping or task/tag order; it is disabled when already default. There is no fake Restore default tag order action.

Opening from Tasks actions waits for that popover's content to disappear before presenting the sheet, avoiding simultaneous modal ownership. Native verification must confirm focus restoration, interruption, swipe/outside dismissal and repeated opening.

Required before merge: independent source review; exact-head hosted tests/iPhone compile; native Today and concrete-list opening/dismissal, independent axes, direction, reset, relaunch, grouping/drag regression, small width/largest text and actual screenshot comparison. Cloud has no Swift/Xcode, so tests are added but no runtime/visual pass claimed.

Independent source review: no confirmed blocker. Verified timestamp mapping, sorting-only reset, explicit default groups, unchanged Board/preferences and adapted test intent. Native popover-to-sheet timing, repeated opening/focus, layout and runtime checks remain mandatory and unexecuted.
