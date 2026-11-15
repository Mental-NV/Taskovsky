# Mobile Group & Sort domain contract

The reference shows List / Date / Created Time / Tag / Priority / None grouping and Date / Created Time / Modified Time / Title / Tag / Priority sorting. Exact multi-tag ownership, ordering and missing-value policy were not exercised. These are explicit conservative Taskovsky decisions, not a claim of identical TickTick semantics.

- **List** is a genuine partition: Inbox first, known lists in workspace order, then unknown list IDs in stable UUID order under `Unavailable List`. Equal names do not merge distinct list identities. Empty buckets are omitted. Archived lists and rows are not silently dropped by this projection; caller scope is authoritative.
- **None** returns one untitled bucket with input order unchanged, distinct from List and from legacy default named sections.
- **Tag** assigns each row exactly once to its first known tag in workspace order, independent of task tag-ID order. Buckets follow workspace tag order. Nested tags stay distinct, not flattened into ancestors. Unknown-only and untagged rows share `No Tags` last. All original tag IDs remain untouched. Duplicate metadata IDs use the first record without a crash or duplicate bucket.
- **Date sort** uses existing `TaskDueDateGroup.displayDue`, including its all-day civil-date timezone mapping and finite-date validation. Ascending/descending compare those keys; undated/invalid dates stay last in either direction, with stable equal-key order. It does not re-expand recurrence, choose a duration start, or change due dates.
- **Tag sort** uses the same primary known tag as Tag grouping. It compares folded case/diacritic-insensitive POSIX names numerically; missing tags stay last in either direction. Equal folded names retain incoming order rather than changing tag/task IDs.
- Projections/comparators are read-only value operations. Caller retains destination filtering, archive/lifecycle eligibility, pinned/history sections, subtask presentation and drag eligibility. Every supplied row is retained exactly once; it is not appropriate to pass all workspace tasks instead of the existing scoped input.

Focused tests cover stable membership/order, missing/duplicate metadata, nested/multi-tag rows, numeric/folded ties, nil/invalid dates and no mutation. Parent owns UI integration, combination tests, native verification and exact-head CI; no UI acceptance is claimed here.

Verification: `swift test --disable-sandbox --filter TaskOrganizationSortTests` passed all five tests on November 15, 2026. This is focused domain verification only, not full suite/native/CI acceptance.
