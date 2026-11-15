# D05 detail Priority popup

Status: locally verified; exact-head CI pending. Detail-only change; other metadata routes retain their sheets.

| Element | Observed reference | Implementation and behavior |
|---|---|---|
| Entry | Detail flag opens anchored popup | Existing detail Priority row anchors a popover; locked tasks disable entry |
| Choices | High Priority, Medium Priority, Low Priority, No Priority | Same wording/order; colored flag icons and current-value checkmark |
| Position/size | Anchored compact popup; exact dimensions unmeasured | System anchored popover, minimum250pt width,48pt rows; no calibrated pixel claim |
| Dismiss | Backdrop dismisses | Native outside dismissal leaves task unchanged |
| Selection | Actual reference write timing unobserved | Preserve existing immediate metadata save with captured revision; local submitting guard prevents repeated writes, busy disables controls, refusal stays visible |

No generic phoneLabel change. No metadata Undo exists in current action; this change does not add one. Existing repository stale/read-only validation remains authoritative; native stale rejection is not claimed without a matching test. No personal reference images are published. Actual neutral screenshot inspected and attached; no personal TickTick content.

Verification: initial full package tests/release and iPhone build-for-testing passed. Final source/native/exact CI and independent review required before merge. Existing detail-priority tests now wait for the actual popup child to disappear, not the absent sheet Cancel button.

## Local verification

844 XCTest +38 Swift tests, release build and iPhone build-for-testing passed. Independent source review clean after correcting old sheet-dismiss waits to actual popup children. Four native cases logged success: all four choices/order/wording/reopen/backdrop dismissal, Trash lock/restore, existing priority+tags persistence, and board lane migration. Native result finalized successfully after delayed collection: PriorityPopupNative.xcresult, exit0, TEST SUCCEEDED. Native stale refusal not exercised; existing revision-checked repository behavior preserved. No metadata Undo was added.

[Actual neutral screenshot](../assets/mobile-parity/2026-11-15/d05-priority-popup.png),1170×2532, inspected from the successful native run. Exact reference geometry remains uncalibrated.
