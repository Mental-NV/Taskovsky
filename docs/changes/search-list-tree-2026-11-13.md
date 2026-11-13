# Mac Search list selector — staged hierarchy

Status: implemented and bounded native keyboard/lifecycle QA passed; publication/hosted CI pending. Scope authorized by the
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
- Individually accessible buttons retain selected/expanded values. A picker-owned
  keyboard surface navigates the visible hierarchy with Tab/Shift-Tab, scrolls
  the active row into view, and activates it with Space. Return commits except
  on Cancel; Escape cancels. Native keyboard acceptance remains pending. No
  animation or system setting changes.
- Search query/results and Save as Filter continue to use committed state only.

## Verification

Five focused state/tree tests passed: isolation/cancel, empty-All behavior,
parent marks, stale-ID preservation and stable root/folder/archive projection.
At source `d6702bc`, 780 XCTest and 38 Swift Testing tests and signed release
build passed; independent source review found no blocker.

The first native AX session at `31c71cc` verified staged changes, folder disclosure,
mixed indicators, Inbox/archive/long-name access, OK, Cancel, Escape, outside
dismissal and reopen. It also found a keyboard focus defect. The first correction
`96a95c1` still failed native Return/Tab handling, so it was not published.
The revised root-owned keyboard surface at `d6702bc` requires a new native check.
Original QA bundle, fixture and preferences were restored after each session;
Codex stopped. Save as Filter list-ID transfer was source-reviewed but not proved
through native AX. Screen capture remains denied; no visual screenshot, exact-fit,
full keyboard accessibility or exact TickTick parity claim is made. Dark deferred.

### Subsequent native result and source-only back-tab correction

The completed native session for `d6702bc` verified forward Tab/Space, pointer
selection followed by Space, Return applying only the picker, Escape discarding,
and folder Space disclosure. Individual AX buttons remained available.
Reverse Shift-Tab failed: it could leave the active row unchanged and then apply
instead of reaching Cancel. Offscreen scrolling was not verified. QA bundle,
fixture and all three preference backups were independently checked restored.

The next source-only correction decodes both Tab with Shift and AppKit's
`NSBackTabCharacter` (U+0019), and extracts wrapping traversal for unit testing.
Two tests cover decoding/ignored keys and reverse wrapping through OK/Cancel.
SDK declarations confirm the used general key-handler overload and character
property. These new tests and this correction have **not been compiled or run**:
heavy validation is paused while the Mac has about 9.6 GiB free. Native reverse
navigation, offscreen reachability and exact-head validation remain acceptance
gates; this is not ready to merge.


### Passing acceptance recheck

At source `bbe60b9`, 782 XCTest and 38 Swift Testing tests passed and the
release/signature build passed. Independent source review found no blocker.
Native AX-only session `01a1d457-b7ae-7310-81bf-612a1c86f891` passed reverse
Tab from All to OK then Cancel (activation verified); Return on Cancel discarded
a changed Inbox draft. Forward Tab/Space, Work pointer-to-keyboard activation,
Return applying only the picker, Escape and folder Space disclosure passed.
With 24 additional disposable fixture lists, Tab reached the last and Space
selected it; the AX scrollbar moved from 0 to 0.99. AX OK and Cancel passed.
Original bundle, workspace, settings and preference files were restored and
verified; Codex stopped. No screenshot was available and denied capture was not
retried. This supersedes the pending keyboard/test gates above, not the retained
visual/exact-reference or live VoiceOver limitations. Hosted exact-head CI is
still required before merge.
