# Arrange Task Hierarchy on iPhone — November 15, 2026

Bounded List-grouping hierarchy for Calendar Arrange Tasks. Show Task
Hierarchy is checked by default as session-only presentation state, alongside
the existing Undated/Overdue/Notes options. Only List grouping nests; Tag
and Priority keep their existing flat order (narrow-filter interaction there
was unverified against the reference and stays unchanged).

Behavior: the hierarchy covers the currently eligible candidates inside
their existing group. A parent shows a trailing disclosure; its children sit
directly beneath with modest indentation and keep their own checkboxes,
drag grips and schedule buttons. Collapse hides the descendants and keeps
the group count unchanged. Turning the option off removes disclosures and
shows the same children flat in their original positions; turning it back on
restores the expanded tree. Excluded parents are never pulled in: orphans
remain visible roots and retain order and group count. Toggling never
mutates tasks, revisions, schedules or settings. Cycle-safe by construction
through the shared `TaskHierarchy.listRows` projection; duplicate
identifiers render once so row identity stays stable and no eligible row
vanishes.

Scope: domain (`TaskCalendarProjection.arrangementRows`) plus the phone
Arrange sheet and a neutral `arrange-hierarchy` QA case. macOS Arrange is
untouched. Recurring safety, revision checks, drag payloads and scheduling
targets are unchanged. Priority/Tag flat rendering is a documented bound,
not a reference claim.
