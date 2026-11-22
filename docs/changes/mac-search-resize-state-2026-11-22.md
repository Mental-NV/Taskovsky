# MAC-SEARCH-RESIZE-001 — Keep Search state on window resize

Status: candidate on `f57b859676b42ce2196fb3410f25df7a9354be41`. Mac Tasks workspace only. See [UX-003](../spec/ui-ux.md#ux-003), [UX-011](../spec/ui-ux.md#ux-011) and [TT-023](../parity-implementation-status.md#tt-023).

## Boundary

Docked and compact Tasks had their own structural views, each building its own Search pane. The pane owns the edited query and active status/date/list/tag/type criteria. Resizing across the Search-specific dock boundary (643 points with the sidebar hidden by Search) can replace that pane with a new copy of the original query. The two separate bodies' identical explicit query ID does not bridge their structural identities.

Keep one Search pane mounted in both modes and change only its width and alongside-detail presentation. Opening a different Search still uses its query identity. Do not change matching, the detail/sidebar thresholds, divider persistence, drawer actions, ordinary Tasks, Calendar split, iPhone or saved filters. Search continuity is a Taskovsky correctness requirement; the exact TickTick resize threshold and criteria retention have not been measured.

## Native baseline

On the guarded Mac app at baseline product source, a synthetic Search was edited from “QA Context” to “QA Context Progress”, filtered to Uncompleted and reduced to one selectable task. At 643 logical points (1286 image pixels) detail was docked. At 642 points (1284 pixels), the heading reverted, status reset to All Status, and all three fixture rows returned. At 643 again, the selected task correctly re-docked but the edited query and filter stayed lost. This is a reproduced Taskovsky regression, not an estimate of TickTick behavior.

## Acceptance

- From a synthetic query, set a nondefault filter and edit the term. On the same task Search, cross from 643 or above to 642 or below and back. The edited term and applied filter must remain effective, not merely reappear after growing.
- With a result selected, narrow without opening detail automatically, select the result again to open/close the drawer, and widen to re-dock the selected task. Existing dismissal, selection and responsive policies remain in effect.
- Opening Search with a different quick-search query should get a fresh session. Exit to Tasks and verify the ordinary sidebar, drawer and selected detail still work. No task/filter writes for the resize.
