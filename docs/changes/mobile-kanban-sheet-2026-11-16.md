# T04 Kanban Group & Sort reference-structured sheet

## User-prioritized correction

The user requested verification of PR149 against live mobile TickTick, matching positions, sizes and labels and removing nonexistent controls. This supersedes further D10 implementation for this slice. Baseline PR149 rendered a tall native popup menu with Existing Order and combined Title direction choices. A same-viewport owned Simulator baseline screenshot was captured before changes.

The restored, read-only live reference audit found a rounded white bottom sheet occupying approximately41% of the viewport, no title/Done/drag handle/footer/reset. Group by: List, Date, Created Time / Tag, Priority in a three-column pill grid. Sort by: Date, Created Time, Modified Time / Title, Tag, Priority, with Ascending/Descending and arrow at the header's right. Selected pills are blue/white without checkmark; other pills pale gray/dark. Choosing a group/sort keeps the sheet open and changes the content behind it. Direction survives changing sort. Tapping the backdrop dismisses. Private TickTick screenshots remain withheld.

## Implementation contract

- Dedicated bottom overlay with explicit tappable dimmed backdrop, rounded top corners, no extra title/buttons/footer/handle. Height approximately41%, minimum330pt to retain usable standard-size controls; matching is normalized, not calibrated pixel-perfect.
- Three equal columns,10pt column gap,36pt visible rounded pills inside44pt hit areas,14pt labels,24pt side/top inset. Direction has a full44pt hit row with no overlapping grid hit area. Current semantic light/dark colors remain supported; dark matching remains deferred.
- Freeze the destination in the presentation request. Immediate session bindings do not close the sheet, mutate data, change List preferences or redirect choices to another destination. Existing incoming order remains until first actual sort selection; no fabricated selected pill or visible Existing Order/reset. Direction defaults ascending and remains per destination across choices.
- All six choices have genuine behavior. Date uses existing schedule/display-date policy (missing last), Created/Modified compare actual timestamps, Title uses existing numeric case/diacritic-insensitive comparator, Priority uses existing rank. Equal keys retain incoming order in both directions. These are Taskovsky policies, not exact reference tie/collation claims.
- Tag creates real collapsible subsections inside each existing lane. Stable lane+tag IDs isolate collapse state and accessibility identifiers; duplicate tag names remain distinct. Primary known tag is inherited Taskovsky policy, one card per task. Named sections follow direction, unknown/no tags remain last, secondary row order remains incoming. Exact TickTick multi-tag/secondary semantics are unverified. Collapse survives direction changes, clears on grouping change and prunes removed section keys.
- Date/List move/drop semantics still target the outer lane. Tag subsections are not drop targets; metadata-only lanes remain read-only. Ordinary list status/section boards and their styling are unchanged.

## Verification gates

Domain full suite and release build passed before final UI-only review corrections. Final corrected iPhone compile, source review, actual native all-six-sort ordering/projection, persistent open selection, exact grid labels/order, backdrop dismissal, Tag collapse and existing Date/List move regressions are pending. No readiness or pixel-perfect claim yet. Baseline and final images must be inspected before publication; only neutral owned-fixture images allowed.
