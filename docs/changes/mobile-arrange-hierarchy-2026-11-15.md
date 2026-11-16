# Arrange Task Hierarchy on iPhone — November 15, 2026

Bounded List-grouping hierarchy for Calendar Arrange Tasks. Show Task
Hierarchy is checked by default as session-only presentation state, alongside
the existing Undated/Overdue/Notes options. Only List grouping nests; Tag
and Priority keep their existing flat order (narrow-filter interaction there
was unverified against the reference and stays unchanged).

Behavior: the hierarchy covers the currently eligible candidates inside
their existing group. A parent shows a trailing disclosure after its title;
its children sit directly beneath with modest leading indentation and keep
their own drag grips and schedule buttons. Collapse hides the descendants
and keeps the group count unchanged. Turning the option off removes
disclosures and shows the same children flat in their original positions;
turning it back on clears any stored collapse and restores the expanded
tree. Excluded parents are never pulled in: orphans remain visible roots
and retain order and group count. Toggling never mutates tasks, revisions,
schedules or settings. Cycle-safe by construction through the shared
`TaskHierarchy.listRows` projection; every presentation branch renders the
first occurrence of a duplicate identifier once, so row identity stays
stable and no eligible row vanishes.

Scope: domain (`TaskCalendarProjection.arrangementRows`) plus the phone
Arrange sheet and a neutral `arrange-hierarchy` QA case. macOS Arrange is
untouched. Recurring safety, revision checks, drag payloads and scheduling
targets are unchanged. Priority/Tag flat rendering is a documented bound,
not a reference claim.

## Screenshot review limit

The neutral expanded/collapsed captures were independently inspected. Narrow Arrange rows still wrap long titles heavily, with the parent disclosure consuming additional width. This is a remaining layout-density gap, not pixel parity. The real drag/Undo regression passed on unchanged production source after the four hierarchy/scope cases. Full final logs show 876 XCTest plus 38 Swift Testing cases (the initial summary counted four zero-test bundle reports as tests; corrected in the verification ledger).

## Child Done follow-up

The final focused native regression passed on test-only `1b777d2` with production unchanged: actual child editor identity, Done, child-only removal from eligible undated rows, parent remaining unscheduled, sibling/orphan eligibility retained, and the saved child schedule summary unchanged after relaunch. This supersedes the earlier untested-Done limit; it does not assert every unrelated field or exact pre-Done timestamp. Complete xcresult and process exit 0 verified.
