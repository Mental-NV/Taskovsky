# Mac Search list selector — staged hierarchy

Status: implemented locally; native verification pending. Scope authorized by the
November 13 request to implement the macro-area Tasks/Calendar light-theme parity plan.

## Outcome and evidence

Full Search's **All Lists** control becomes a folder/list hierarchy with staged
OK/Cancel selection. The retained [TickTick observation](../ticktick-spec/search-and-filters.md#full-search-controls)
records an expandable tree, leaf checks, mixed parent indication and OK/Cancel.
Only Cancel was exercised in that reference session. Exact TickTick geometry,
All selection glyphs, parent-click semantics and dismissal behavior are not proven.
This is a bounded observed-pattern improvement, not exact parity certification.

## Contract

- Mac full Search only; quick search, iPhone, dates/tags/status and matching stay unchanged.
- Open a presentation draft copied from current selected IDs. Leaf toggles affect
  only the draft. OK commits once; Cancel, Escape and outside dismissal discard.
- Empty IDs remain the existing All scope. The All row clears IDs; clearing the
  last selected leaf also means All. No implicit enumeration or matching changes.
- Folder rows disclose/collapse; their check/mixed indicators derive from explicit
  selected children. Folder bulk toggling is intentionally not added without evidence.
- Preserve folder/list data order, root above/below-folder placement, orphaned
  roots, archived lists and unknown selected IDs. No schema or persistence mutation.
- Use a 280-point popover, at most 340-point scrolling list, 13-point type, 22-point
  child indentation, existing list symbols, standard accent and secondary colors.
  These are Taskovsky layout choices, not measured reference constants.
- Standard focusable buttons and selected/expanded accessibility values. Return
  commits via OK; Escape cancels. No animation or system setting changes.
- Search query/results and Save as Filter continue to use committed state only.

## Verification

Five focused state/tree tests passed: isolation/cancel, empty-All behavior,
parent marks, stale-ID preservation and stable root/folder/archive projection.
Independent source review found no blocking issue. Full suite/release and native
reopen/OK/Cancel/Escape/outside behavior are pending. Screen capture remains denied;
no visual screenshot, exact-fit or full accessibility claim is made. Dark deferred.
