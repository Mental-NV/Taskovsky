# iPhone mobile specification change

## Identity and decision

- Change ID: `CHG-IPHONE-MOBILE-SPEC`.
- Status: Approved documentation scope; proposed implementation, not started or verified by this change.
- Request: update the mobile specification and publish it as a separate PR. User decisions recorded on 8 November 2026 are incorporated in canonical decision rows D01–D13.
- Base: `f85e2f6a9c538f36829961961a0749197f29c4e2` on main. The separate dirty desktop evidence snapshot is identified in Section 14 of the canonical specification; none of its source changes is included here.
- Affected platform: proposed iPhone client, with shared-engine and macOS compatibility constraints. Markdown documentation only.
- Stable contracts: IOS-001–IOS-014; related BUS, UX, ARCH, CMP and RICH contracts are cited in the canonical specification. TickTick comparison rows do not independently authorize scope.

## Outcome and scope

Replace the earlier limited iPhone proposal in [the canonical specification](../spec/iphone.md) with the detailed, desktop-derived mobile scope and screenshot-grounded visual contracts. Preserve all existing IOS anchors. Do not create a second normative mobile specification.

Retain desktop-backed Calendar, Board, Summary, saved filters, templates and organization. Screenshots guide layout, not new features; Matrix, the screenshot-only Week-card mode and other unsupported controls remain excluded. Reduced rich-editor controls are permitted only with no-loss preservation.

Current decisions are local JSON storage with sync later, a provisional conservative iOS 17 floor pending API/toolchain audit, iPhone 13 Pro reference calibration, early local pre-alpha testing, and conditional ordinary local notifications. Notification feasibility requires a free Xcode Personal Team physical-device smoke test; paid membership is not an assumed prerequisite and delivery is not guaranteed. No APNs, App Store release or TestFlight rollout is included.

## Current behavior and intended delta

Current source is a local macOS application, not an iOS implementation. Core still contains AppKit dependencies. Desktop stores reminder data but has no operating-system notification delivery. The conditional local-notification plan is an explicit user-requested exception to desktop functional scope, not an inferred TickTick feature.

The previous proposal excluded or deferred some implemented desktop capabilities. The revised canonical scope retains those capabilities while distinguishing staged delivery gaps from scope removal. Section 14 pins current source links and separately records uncommitted Calendar evidence hashes. This PR makes no runtime behavior change and fixes no source defect.

## Data and component contract

[Sections 5–8 and 10–11](../spec/iphone.md#ios-005) specify staged edits, shared commands, lossless rich/unknown payload handling, compatibility locks, local storage, cancellation, durable saves, stale edits, recovery and platform adapters. Existing workspace and settings files are separate; no cross-device synchronization or new migration is implemented here.

## UI and UX contract

[Sections 3–9](../spec/iphone.md#ios-002) contain navigation, screen, input, keyboard, layout, semantic styling, screenshot measurements, missing states and accessibility requirements. Section 9 separates observed source pixels from the qualified iPhone 13 Pro reconstruction and unverified capture settings. No screenshot assets or private screenshot content are redistributed.

## Acceptance cases

[Section 13](../spec/iphone.md#13-acceptance-scenarios) defines A01–A39, including cancellation, duplicate actions, lifecycle, stale state, rich-data preservation, notifications and development-device checks. All runtime cases remain not run. [IOS-014](../spec/iphone.md#ios-014) defines the staged rollout; documentation approval is not evidence that a stage passed.

## Verification and release

Static checks cover canonical anchors, acceptance IDs, Markdown table shape, link/reference targets and the three-file Markdown allowlist. Results and limits are recorded in the [verification ledger](../spec/verification.md#iphone-mobile-specification-2026-11-08). No mobile build, simulator session, physical-device test, native UI check or notification/signing smoke test was run. No desktop build/test was run for this documentation-only change. Hosted CI triggered by the draft PR is separate exact-commit evidence and must be read before claiming a pass.

## Completion record

This is the specification review deliverable only. Implementation and release are not assigned by publication. No merge, deployment, source/test/workflow edit or desktop-worktree modification is included. Future implementation must reconcile the latest desktop source and update evidence without silently changing these contracts.
