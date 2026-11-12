# Hosted iPhone compile gate

Status: implemented; first hosted verification passed at the exact code revision recorded below.

Before this change, main contained an iPhone Xcode target plus contract/navigation test targets, but its hosted workflow only tested/packaged the Mac product. This change adds an independent job using the existing pinned macOS 15 ARM64 / Xcode 26.3 environment to compile the iPhone scheme and its test bundles for a generic ARM64 iOS Simulator destination.

The gate records the tested checkout, toolchain, simulator SDK and resolved deployment target. It must fail for missing tools, unexpected destination/target settings, compiler failure or missing app/test products. `build-for-testing` compiles tests; it does not execute them. No simulator boot, app launch/install, device, signing identity, Apple account, notification prompt or repository permission change is needed. Keep existing documentation-only workflow exclusions and desktop checks unchanged.

A passing result demonstrates compilation against the recorded SDK with the project's iOS 17 deployment target, not runtime compatibility with iOS 17, physical-device behavior, UI/UX parity or successful tests. Preserve logs/results as diagnostics; do not publish a distribution app. Native gates on other work remain separate.


## Hosted evidence

[Run 43265519146](https://github.com/Mental-NV/Taskovsky/actions/runs/43265519146) passed both jobs for head `9e0a950423f683fcdf8b4eb2c278ef70e90b80a4`, checked out as `b1163f8b6c74b0ffa17b509cef3d2fa2cd34a776` merged into base `9049f6079fab23929f457174f256caa6bdb8e570`.

- iPhone job `131347910230`: four command-contract tests passed; Xcode 26.3 (17C529), Simulator SDK 26.2, ARM64, resolved deployment target 17.0. Generic `build-for-testing` succeeded and verified the app, both test bundles and `.xctestrun` manifest. Diagnostics uploaded. No mobile tests executed.
- Desktop job `131347909475`: 753 XCTest and 38 Swift Testing tests passed, plus release build, local signature/archive verification and artifact upload. No retry was required.
- Independent source review, shell syntax and workflow event/permission checks passed. Documentation-only exclusions and read-only workflow permissions were preserved.

This evidence does not satisfy PR #61's interactive editor/native lifecycle gates. That separate PR remains draft until independently verified.
