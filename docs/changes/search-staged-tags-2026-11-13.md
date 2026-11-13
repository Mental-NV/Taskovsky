# SEARCH-TAGS-001 — Staged full-search tags

Status: Approved bounded implementation under the user’s autonomous local Tasks/Calendar parity direction.
Base: main `c5979c1` (PR74). Isolated branch; original worktrees preserved.

## Evidence and delta
[Retained TickTick observation](../ticktick-spec/search-and-filters.md) records All, No Tags, multiple individual tag checks, OK and Cancel. Current Search uses an immediate Menu. Replace it with a disposable draft popover, applying only on OK/Return and discarding on Cancel/Escape/outside dismissal. Reopen starts from applied values.

Preserve current Taskovsky any/all/none/anyTagged matching and Save as Filter mapping; reference combination semantics are unknown. Preserve inactive/unknown tag IDs rather than silently changing a filter. All explicitly clears selection and resets to Any selected. No Tags/Any Tag retain inactive IDs. Individual tags stay in the existing order; no invented nested behavior. Keep existing Match options as an explicitly Taskovsky control, not a reference parity claim.

## Presentation and acceptance
Use the existing Search list-picker 280pt width, 340pt maximum scrolling area, 13pt rows and footer tokens. All/No Tags and tags have named selection states. Tab/Shift-Tab wrap within visible rows and footer, Space activates, Return applies except focused Cancel, Escape discards. Long names wrap to two lines, long lists scroll, empty tags remain usable. Light theme only. No storage/schema/shared/iPhone changes.

Tests cover draft copy isolation, All reset, modes, toggles and unknown IDs; full tests, release, independent review and scoped native keyboard/cancel/reopen/scroll checks remain required. Screen capture permission is denied; no retry, settings change or screenshot claim. Exact pixels unverified.
