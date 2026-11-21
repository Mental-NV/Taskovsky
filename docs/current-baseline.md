# Integration baseline

The source in the checkout being changed determines current implementation. Record its exact commit and worktree state; read the affected symbols and tests. A local checkpoint is not on GitHub `main` until merged.

## Confirmed platform boundaries

- [Package.swift](../Package.swift) declares macOS 14 and iOS 17, a macOS executable and shared Domain/Workspace targets. Mac-specific services and rendering remain separate.
- Open the [iPhone Xcode project](../TaskovskyMobile.xcodeproj) from the repository root. Its [screens](../Sources/TaskovskyMobile) sit alongside the [Mac app](../Sources/Taskovsky). See the [build/QA guide](spec/iphone-build-qa.md) and [layout change](changes/iphone-project-layout.md). iOS 17 is a deployment target, not a runtime qualification.
- Both apps use local files. Separate presentations and a smaller mobile editing surface are intentional; a mobile edit must not lose unsupported desktop data.
- Check the [feature tracker](parity-implementation-status.md) and [mobile visual tracker](mobile-visual-parity.md) for scoped status, and the [verification ledger](spec/verification.md) for evidence tied to exact builds. A dated absence claim or test run is not current evidence.

## Documentation audit checkpoint

The cleanup audited [`f162d0a4`](https://github.com/Mental-NV/Taskovsky/commit/f162d0a4a78ba72958dd0ef24b33d0b22fbb2340), which includes the [46-reference merge](https://github.com/Mental-NV/Taskovsky/pull/163). This is the audit input, not a moving pointer to the latest revision, a runtime re-test, or a parity sign-off. Earlier rollout context is [archived](archive/integration-rollout-2026-11-08-to-12.md).
