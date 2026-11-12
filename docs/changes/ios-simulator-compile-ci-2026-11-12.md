# Hosted iPhone compile gate

Status: proposed implementation; hosted result pending.

Current main contains an iPhone Xcode target plus contract/navigation test targets, but its hosted workflow only tests/packages the Mac product. Add an independent job using the existing pinned macOS 15 ARM64 / Xcode 26.3 environment to compile the iPhone scheme and its test bundles for a generic ARM64 iOS Simulator destination.

The gate records the tested checkout, toolchain, simulator SDK and resolved deployment target. It must fail for missing tools, unexpected destination/target settings, compiler failure or missing app/test products. `build-for-testing` compiles tests; it does not execute them. No simulator boot, app launch/install, device, signing identity, Apple account, notification prompt or repository permission change is needed. Keep existing documentation-only workflow exclusions and desktop checks unchanged.

A passing result demonstrates compilation against the recorded SDK with the project's iOS 17 deployment target, not runtime compatibility with iOS 17, physical-device behavior, UI/UX parity or successful tests. Preserve logs/results as diagnostics; do not publish a distribution app. Native gates on other work remain separate.
