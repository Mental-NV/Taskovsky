# Minimum-height timed Calendar outline

Status: published in PR67, stacked on PR66 source `b8c0d5e`; light-theme interaction and independent source review passed. Final exact-head checks are required. On November 13 the user explicitly deferred Dark-theme work and directed completion of the white/light-theme UI.

## Observed defect and scope

The isolated exact-source dark renderer confirmed that minimum-height 15-point timed task and note cards lose their bottom Outline stroke, both on base and PR66. The title/button plus padding can require more than the proposed height. The flexible frame previously left its minimum implicit, so its decoration could be taller than the caller's clipped slot.

Set the flexible frame minimum height to zero only for `fillsAllocatedHeight` timed cards. This makes the decorated frame accept the existing slot; it does not change the allocated duration, minimum slot, typography, clipping, controls or scheduling. Non-timed cards retain the previous implicit minimum. Do not reduce fonts or move resize handles to disguise overflow. No persistence, phone, notification or system settings change. This corrects a verified Taskovsky defect; it does not establish exact TickTick parity.

## Verification and acceptance

An isolated native probe based on PR66 source `b8c0d5e` plus this one-line layout delta built successfully and passed the existing 72 dark render assertions across task/note, 15/30/45/60-minute, narrow/wide, Filled/Outline and folded-hour clipped cases. The minimum-height narrow Outline near-right paint shortfall changed from 29 screenshot pixels to zero in both task and note samples. All candidate paint samples were within two screenshot pixels of their allocated bottom; grip visibility and clipping assertions passed. Screenshot review confirms the bottom outline. These are screenshot pixels at renderer scale 2, not a new layout threshold.

The renderer used exact production column/card sources, a test-only entry point, synthetic fixtures and offscreen Dark appearance. It did not open a desktop window or alter global appearance, QA app identity, signing or preferences. The preserved reference is `/private/tmp/TaskovskyPR66Dark`; independent probe is `/private/tmp/TaskovskyOutlineProbe.ghmfil`.

Clean-source native `swift test --disable-sandbox` passed: 766 XCTest cases (134 Domain, 104 Workspace, 528 Core) and 38 Swift Testing cases. Independent source review found no actionable defect and confirmed non-timed layout, gestures, scheduling and accessibility declarations are unchanged. Release build passed; the produced app passed `codesign --verify --deep --strict`.

Subsequent native light QA sampled 15-minute task/note Filled/Outline cards at narrow/wide widths, controls, resize/move/Undo, context and accessibility. A matched parent comparison confirmed narrow title mouse-click misses were pre-existing, not introduced by this correction. QA bundle, fixture and preferences were restored and scoped Codex stopped. Production-app Dark interaction remains unverified and is explicitly deferred by the user's November 13 light-only direction, not a current merge gate. No claim of full Calendar parity or completion of PR65 focus testing. Native light evidence does not certify every narrow-title interaction; that separate limitation remains open.

## Retained render receipt

Probe source differs from the clean candidate only by explanatory comments and line wrapping at the product change. Its extra entry-point/column-wrapper changes are test-only, not part of the candidate. SHA-256:

- Probe CalendarPanels.swift: `fdf0feec94efed5c4389b4247c40bce4ec190e78afb5279704bad1b2a7b7de37`
- Clean CalendarPanels.swift: `a624c47b80de86095ba3db018b1b8c1233030442de0266548ee5798b07b20640`
- Renderer: `c372eefb488efa8f272248548d2c81660efdbf1d11265d765b220578290b8ab3`
- Column wrapper: `50c6e1bdb59f3923eb0e6575bb10727201a08f9ffc1a0179e6f4ef8dd3b4e665`
- Candidate measurements.tsv: `7c97dade60a6386acf03f5ca971600f7bde4f3b33f43d221021226f68556b70f`

These receipts identify preserved local artifacts, not a portable automated test in CI.

## Hosted verification and scope

Exact source head `7769514` passed hosted run `43374899581`: macOS Swift tests, release build, signature and archive checks, plus iPhone Simulator compile-only. This documentation update requires its own final checks. The user has delegated review/merge and asked to finish PR66 and its dependent correction under the light-only scope. Dark interaction must be verified when Dark work resumes; no OS appearance, capture permission or notification setting is changed for this scope decision.
