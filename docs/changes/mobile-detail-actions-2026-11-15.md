# D02 Task Actions: supported lifecycle strip and real row routes

## Scope and evidence

The mobile reference inventory observes a D02 icon strip (Pin / Share / Won't Do / Delete) and rows for Add Subtask, Link Parent Task, Convert to Note, Attachment, Tags, Task Activities, Add to Live Activity and More. This bounded implementation ships the supported lifecycle strip and real Tags / Add Subtask / Link Parent Task routes through the existing flows. Share and the other external actions are deferred with no fake placeholders, and no full-parity claim is made.

| Element | Placement / wording | Working behavior |
| --- | --- | --- |
| Pin / Unpin, Won't Do, Move to Trash | Icon strip, default layouts only | Run the shared lifecycle commands; Delete uses the mapped Move to Trash label for ordinary tasks; purge stays a separate confirmed Trash action |
| Add Subtask | Actions row | Opens the existing hierarchy child sheet with revision-checked stale handling; save returns to Task Actions, then detail shows the linked child |
| Link Parent Task | Actions row | Opens the existing hierarchy parent sheet; Cancel returns to Task Actions |
| Tags | Actions row | Opens the existing tag picker; save persists, reopen shows selection, relaunch keeps it |
| Convert to Note / Task | Actions row | Existing in-place conversion, unchanged |
| Complete / Reopen, Move, Duplicate, Save/Apply Template, Restore, Delete Forever | Actions rows | Existing commands, unchanged; single-flight guard blocks accidental duplicate writes |
| More | Actions row | Existing pinned/More customization preserved |
| Custom layouts | No strip | Saved layouts keep exact pinned order and More prefix; absent new actions append to effective More with no storage rewrite until an explicit edit |
| Legacy layouts | No strip | Pre-D02 persisted layouts keep exact rows and gain the new routes in More; untouched Edit saves write nothing |
| Locked records | Trash | No strip, no Tags/Add/Link rows, no More; Restore and Delete Forever only |
| Share, Attachment, Task Activities, Live Activity, Copy Link, Print | Absent | Deferred; no placeholders rendered |

Taskovsky choices, not verified TickTick semantics: strip tiles render only for untouched or default layouts; nested Tags/hierarchy sheets dismiss back to Task Actions rather than directly to detail (partial reference behavior); unknown layout payloads refuse as a whole to preserve user data. The legacy native check proves visible routes, not raw bytes; byte stability is proven by the shared-policy domain tests and source review.

## Verification

- Native initial run on the owned Simulator destination: 7 of 8 passed (`/private/tmp/TaskovskyDetailActionsNative/D02.xcresult`). The single failure was a test-helper synchronization error in `testDetailActionsStripAndSupportedRoutes`: it asserted the Task Actions Done button while the More screen was still pushed. Helper-only correction, no product change.
- Native focused rerun of the corrected test: **TEST SUCCEEDED** (`/private/tmp/TaskovskyDetailActionsNative/D02-strip-rerun.xcresult`). Combined native result: 8 of 8 green; no product-code change between the runs.
- Package checks after PR140 integration: 863 XCTest (136 Workspace + 55 Mac + 143 Domain + 529 Core) plus 38 Swift Testing cases, 0 failures (`/private/tmp/TaskovskyDetailActions-swift-test4.log`; D02 capture checkpoint ran 861 + 38 in `swift-test3.log`). mac release rebuilt post-integration with adhoc signature verified (`codesign --verify --deep --strict`, exit 0, `build4.log`); iPhone `build-for-testing` passed post-integration (`/private/tmp/TaskovskyDetailActions-xcodebuild4.log`).
- Independent review reported clean at f649dde+9a72b78. Exact-head hosted CI pending. No pixel-perfect acceptance claim.

## Screenshot

[Neutral owned-Simulator capture](../assets/mobile-parity/2026-11-15/d02-task-actions.png): custom Task Actions sheet with the new Add Subtask, Link Parent Task and Tags rows, no strip, neutral fixture task only. Pixel-inspected, no personal content. Captured from the initial native run at fd962df; production code is unchanged since f649dde (later commits are test-helper and documentation only). No default-strip capture was attached by the native tests; none was recaptured. Reference icon geometry, Share/external actions and direct-to-detail sheet returns remain unmatched.
