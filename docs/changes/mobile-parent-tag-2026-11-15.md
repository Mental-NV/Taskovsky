# T16 — Parent Tag selection

The original mobile inventory observed Add Tag → Parent Tag as a pushed picker with None selected, existing tags and radio circles. Taskovsky now exposes an explicit pushed list instead of its system navigation picker. None appears first, eligible tag paths follow, and selected/unselected circles expose one choice. This is structural similarity, not a claim of identical dimensions or unknown reference ordering.

Selecting updates only the enclosing tag editor draft and returns to it. Back leaves the draft unchanged. The editor's Cancel/discard, Done validation and original revision-safe save remain authoritative. Existing TagOrganization.allowsParent excludes self/descendants; no new domain semantics or writes occur in the picker. Unknown saved parent IDs are not silently normalized on opening. Existing path labels distinguish nested names.

Verification pending: full/release, independent review, native None/checkstate/Back/Cancel/cycle exclusion, existing creation/pin and rename/reparent/relaunch regressions, screenshot and exact-head CI. No test-source-only pass claims.

## Verification receipt

Integrated PR133 cleanly; source review and integration review clean. Full integrated suite passed 844 XCTest (134+55+126+529) plus38 Swift Testing, release and strict signature. Initial native run passed creation/pin/assignment and rename/reparent/relaunch; new Back test selected an underlying navigation bar instead of Parent Tag. Test-only correction scopes its navigation bar; final focused native passed on integrated build. Production picker source unchanged. Three distinct native cases passed across these runs, not a full-suite native claim. Screenshot is the actual neutral None-only cycle-exclusion state; alternate radio geometry and pixel parity remain unverified. Exact-head hosted CI pending.
