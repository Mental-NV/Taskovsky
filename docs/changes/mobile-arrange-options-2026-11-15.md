# C14 — functional Arrange options

## Reference and bounded behavior

The mobile inventory observed an anchored Arrange overflow containing Undated Task, Overdue Task, Show Notes and Show Task Hierarchy. This slice implements the first three as real composable filters. Hierarchy display remains unimplemented: observed wording alone does not establish nesting, group crossing or parent eligibility rules.

| Element | Position and wording | Behavior |
|---|---|---|
| Undated Task | First option; check when enabled | Includes eligible undated tasks/notes. Off excludes them without modifying records |
| Overdue Task | Second option; check when enabled | Existing overdue rule and Calendar-zone civil-day semantics unchanged |
| Show Notes | Third option; check when enabled | Includes notes only if they also satisfy date/source eligibility |
| Existing help | Below choices | Preserves schedule/drag hints |

Default state preserves existing behavior: undated and notes enabled, overdue disabled. Options are local to an Arrange session like the previous overdue control; reopening resets them. This is not a claim about TickTick persistence or full C14 equivalence. Grouping, source filters, scheduling actions, revisions, drag/Undo and stored tasks are not changed. Domain optional arguments default to existing behavior for Mac callers.

## Acceptance

- Independent combinations of undated/notes/overdue, empty results and source restrictions.
- Existing date semantics, completed/archived exclusion and defaults.
- Native menu state, live rows, repeated toggles and reopening; existing schedule/drag/Undo regression.
- Independent source review, full/release, native and exact-head CI before merge.

## Verification checkpoint

Domain source `1105324`: five focused tests passed. The full local run logged 840 XCTest (134+55+122+529) and 38 Swift Testing passes. Independent source/test review is clean. Release compilation reached 143/148 before the execution transport disconnected; no final app/signature result is present, so release is unverified. Two native launch requests timed out in permission review; no native log/result bundle was created. Do not treat these as native failures or passes and do not duplicate the uncertain release process. Exact-head hosted CI and screenshot remain pending. SwiftUI Menu may not expose accessibilityValue, so native acceptance uses real candidate inclusion/exclusion plus inspected checkmark capture rather than unsupported AX assertions.

## Resumed acceptance

After Mac execution recovered, a fresh isolated checkout integrated main at `cec8cf1`. Four owned Simulator tests passed: independent option inclusion/exclusion/reopening, source-scoped scheduling, drag/Undo and recurring staged scope. Result: `TaskovskyArrangeResumeNative.xcresult`. The attached unmodified screenshot is from that tested checkpoint, with neutral seeded data; all three option labels/checkmarks are visible. Existing menu help truncation is visible, not claimed fixed. Show Task Hierarchy remains deferred pending behavioral evidence.

PR135 was integrated at `f7a036b`; independent integration review confirms C14 production/domain unchanged and all native methods retained without duplication. Native acceptance belongs to `cec8cf1`, not a newly executed integrated run. The original uncertain local release was not repeated; exact-head hosted CI must supply the final compile/test/release gate before merge. No live TickTick data or user Simulator was changed.
