# Real iPhone Group & Sort choices

User requested underlying business behavior, not placeholder controls. Group grid now has exact observed order List / Date / Created Time / Tag / Priority / None. Sort grid: Date / Created Time / Modified Time / Title / Tag / Priority. Selected group and sort are independent. Existing Priority sort remains high-to-low; timestamp/title/metadata criteria expose direction. Major structural similarity is the target; fine pixel polish deferred.

List partitions aggregate scopes by actual list ownership; Inbox explicit. None removes ordinary grouping, including named sections, while pinned/completed/abandoned partitions remain. Legacy Default Groups is not an alias for List; preserved preferences retain their prior behavior, with a separate Restore default grouping action. This intentional extra compatibility action differs from the supplied image.

Tag grouping owns each row once by first known workspace-order tag; multi-tag items are not duplicated. Unknown-only/untagged rows go to No Tags. Date uses existing task civil-day projection, missing dates last in either direction. Tag sort uses the chosen known tag's folded numeric name, missing tags last. These conservative Taskovsky semantics are documented, not claimed as observed TickTick ownership/collation. See [pure domain contract](mobile-group-sort-domain-2026-11-15.md).

All sort call sites receive workspace metadata and calendar. Preference raw values stay compatible. No task data edits, tag/list reorder, drag-to-group semantics or Mac changes. Restore default sorting clears sorting only; it does not pretend to implement unknown reference Restore default tag order semantics.

Validation pending: domain composition/identity/missing/timezone, native selections/results/relaunch/reset, full tests/release, independent review and exact CI. Original reference images remain private; publish neutral fixture images only.
