# iPhone Title sorting

Wide-first T04 functional slice. The live reference inventory and supplied Group & Sort image show a Title choice. Its ordering, locale behavior and direction interaction were not exercised; this implementation does not claim exact reference collation.

Taskovsky contract: Title defaults to ascending, direction toggles ascending/descending, numeric/case/diacritic-insensitive comparison in en_US_POSIX, equal keys retain incoming stable order. Empty titles sort first ascending/last descending. Existing pin/history/section/date-group partitions remain; only within-partition ordering changes. Existing app-scoped sort preferences persist new explicit raw values without rewriting task data, existing values or grouping. Restore default sorting clears only sorting. Manual task reordering remains unavailable under sorting.

No Tag/Date sorting, extra grouping criteria, reference reset semantics, accessibility-layout polishing or task mutations. Title is one additional supported pill, not full Group & Sort parity.

Acceptance: domain numeric/case/tie/empty/no-mutation rules; native ascending/descending/pinning/relaunch/reset plus existing timestamp/grouping regression; independent review, full tests/release/signature and exact-head CI. Initial domain test caught POSIX comparison inconsistency; explicit key folding fixed source without changing expected results. Final 828 XCTest +38 Swift Testing, signed release/signature and independent rereview passed. Initial three native regressions passed; final corrected-source Title/pinning/direction/relaunch/reset regression passed. Neutral screenshot inspected and tracker updated. Exact-head hosted CI pending.
