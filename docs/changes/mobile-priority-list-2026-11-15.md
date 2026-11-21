# iPhone Priority grouping in Tasks List

Wide-first T04: Priority is an observed reference grouping choice and selected in supplied/live reference. Taskovsky List now offers it alongside existing groups. Display buckets use existing priority rank High/Medium/Low/None, omit empty buckets, and preserve incoming sort inside each bucket. Pinning and completed/abandoned partitions remain outside ordinary priority buckets. No duplicate rows or priority edits are introduced. This documents Taskovsky behavior, not verified exact reference ordering.

Mobile-only grouping enum retains prior raw values and fallback/legacy Created behavior; the Mac enum and preferences are unchanged. Current global mobile preference scope remains. Explicit grouping overrides named sections in List as other existing grouping does; default restores sections. Board/Timeline behavior is unchanged. Sort and grouping remain independent. No drag-to-priority write is added.

Acceptance: domain identity/order/empty buckets; native pinning, Title sorting, relaunch, reset independence and old grouping regressions; full tests/release/signature/review/exact CI and neutral screenshots. 829 XCTest +38 Swift Testing, signed release/signature, independent review and three native regressions passed. Exact-head CI pending. No personal data used.
