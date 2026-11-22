# MAC-QUICK-SEARCH-001 — Show a welcome state for fresh Quick Search

Mac Tasks, [MAC-10](../mac-parity-acceptance.md#acceptance-matrix), [TT-023](../parity-implementation-status.md#tt-023), [UX-011](../spec/ui-ux.md#ux-011). Baseline `4fa9d2d001ff91527f53e8a68ab071c808cd5e3c`.

The [actual TickTick observation from November 2](../ticktick-spec/search-and-filters.md#quick-search) described a focused field, blue underline, explanatory text and an illustration on opening empty Quick Search. In the guarded Taskovsky baseline (byte-identical Search product source with isolated synthetic history), fresh normal and minimum-width launches focused correctly but showed a neutral line and an otherwise empty Recent Searches heading. Nonempty recent history and a typed no-match query already showed their respective contents.

When the trimmed query and recent history are both empty, replace the empty heading with a centered, decorative Taskovsky magnifier and the explanatory text “Search tasks, tags, lists and filters.” Accent the header divider only while the field is focused. Keep populated history, Clear, live results, local no-match, shortcuts, matching, dimensions and all Full Search behavior unchanged. No cloud search, exact reference artwork, measured hue, or matched geometry is claimed. The existing 550-point sheet can extend beyond a 382-point host; this separate sizing comparison does not establish physical clipping and is not changed.

## Acceptance

Open with isolated synthetic empty history at normal and compact Mac widths. Check focus, accent, empty-state text, decorative icon accessibility and Close/Escape. Type a local nonmatch, then check the existing no-match output. Submit a matching synthetic query to Full Search, reopen Quick Search to see it in Recents, and clear only the disposable history to return to the welcome state. Confirm result grouping and state remain separate and nothing from the user's actual history is read or written.
