# iPhone project layout

`ARCH-IPHONE-LAYOUT` · Approved in the November 21, 2026 request · Base `8a5519ba`

The iPhone app moves from `Mobile/App/` to [`Sources/TaskovskyMobile/`](../../Sources/TaskovskyMobile). The [Xcode project](../../TaskovskyMobile.xcodeproj) opens from the repository root. Its local Swift package reference points to the root package. iPhone-native tests live in [`Tests/MobileContracts/`](../../Tests/MobileContracts) and [`Tests/MobileNavigation/`](../../Tests/MobileNavigation). [Neutral QA fixtures](../../Tests/Fixtures/Mobile) live under `Tests/Fixtures/Mobile/` and ship in the same app resource phase.

The Mac executable keeps its SwiftPM entry point. The iPhone scheme, target membership, deployment target, Info.plist settings, and bundle and data locations carry forward. App and test source moves preserve file contents, including the four views already built on both platforms. Workspace data needs no migration. The build and QA entry points are documented in the [iPhone guide](../spec/iphone-build-qa.md).

Acceptance covers Mac tests and release packaging, the iPhone Simulator app and test bundle compile, and isolated iPhone tests that load the bundled fixtures. See the [verification ledger](../spec/verification.md#iphone-project-layout).
