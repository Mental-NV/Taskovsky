# macOS continuous integration

## Status and purpose

**Implemented**, in [`.github/workflows/macos-ci.yml`](../../.github/workflows/macos-ci.yml), after the user requested implementation and verification on November 8, 2026. The original workflow from PR #1 is present in main `6ee96eeb8f88e74a105c518de2202233ea528efa`. This follow-up adds documentation-only path filtering on its own branch. The [verification ledger](verification.md#hosted-macos-ci) records historical test/build results; the [filter verification entry](verification.md#docs-only-ci-filter) distinguishes static acceptance from hosted execution for this change.

The workflow runs the existing Swift tests and release-app packaging on a GitHub-hosted Mac regardless of a developer's local OS. It is CI plus downloadable build artifacts, **not continuous deployment, Developer ID signing or notarization**. The current source also contains a separate iPhone app and native test targets. The new [iPhone compile-only gate](#ci-006) compiles those targets; it does not execute their tests. Interactive native checks remain separate.

<a id="ci-001"></a>
## CI-001 — Runner and toolchain

The desktop job is `Test and package (macOS 15, ARM64)`, on standard hosted `macos-15`. It asserts `uname -m == arm64`. `DEVELOPER_DIR` selects `/Applications/Xcode_26.3.app/Contents/Developer`; setup asserts Xcode 26.3 and logs compiler, SDK, OS, architecture and runner-image versions. Missing or unexpected tools fail rather than silently falling back.

The initial proposed Xcode 16.4 pin was actually tested. Its Swift 6.1.2 compiler failed to type-check the existing `TaskDetail.body` at `TaskDetail.swift:73`, before test execution. Xcode 26.3/Swift 6.2.4 reproduced the same source compiler failure. The user then explicitly approved a behavior-preserving `TaskDetail.body` refactor: eight original view sections became private computed `@ViewBuilder` properties, with the original state, bindings, actions and layout retained. The package deployment target and tests are unchanged. See the ledger for actual results after the refactor.

[Runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) is rechecked when updating the pin. An OS label and Xcode path do not freeze SDK patches or the hosted image forever. The package still uses Swift tools 6, Swift 5 language mode, and declares macOS 14 minimum.

**Coverage gaps:** macOS 15/ARM64 does not establish macOS 14 or Intel compatibility. Hosted macOS 14 is no longer available in the reviewed inventory; use an authorized minimum-OS environment or a separately approved deployment-target decision for that guarantee. Do not change the product target or provision paid runners as routine CI maintenance.

<a id="ci-002"></a>
## CI-002 — Events, exact revision and permissions

- `pull_request`: opened, synchronize and reopened, including drafts, except documentation-only changes as defined below.
- `push`: main only, after integration, with the same documentation-only exclusions.
- `workflow_dispatch`: retained without path filtering, so a documentation revision can still be built deliberately. The workflow is already present on the default branch; select the desired branch/ref when dispatching.
- Every run records event, repository, PR number, head/base SHA, event ref/SHA and actual `git rev-parse HEAD`. Checkout uses the event revision and asserts it equals `GITHUB_SHA`. PR CI therefore tests GitHub's synthetic merge commit, not just the PR head. The ledger records both.
- Job timeout is 30 minutes. Concurrency groups combine workflow name with PR number or ref and cancel superseded runs in that group. Different PR numbers and branch refs have separate groups. This grouping is statically checked; unrelated-branch cancellation has not been tested by opening extra PRs. A cancelled run is not a pass.
- `contents: read` is the only requested token permission. Checkout does not persist credentials. No user/repository secrets, production signing credentials or personal workspace data are needed. There is no privileged `pull_request_target` execution, cache, deployment or repository-settings write.
- Official actions use verified full commit pins: checkout v7.0.1 (`3d3c42e5aac5ba805825da76410c181273ba90b1`) and upload-artifact v7.0.2 (`cf430e030ddbb5b0abf93d22962f4752f3646cd9`), both Node 24. Review version, inputs and upstream release before changing them.

See GitHub's [PR event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request), [manual dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch) and [secure use](https://docs.github.com/en/actions/reference/security/secure-use) documentation.

### Documentation-only exclusions

Both automatic events use the same `paths-ignore` list: `docs/**`, root `README.md` and root `AGENTS.md`. The documentation subtree includes archived/reference documents and their non-runtime evidence/assets. Keep executable/build inputs outside that subtree, or revise these filters before consuming anything in it at build/test/runtime. This is deliberately not a repository-wide `**/*.md` rule: Markdown fixtures or files elsewhere still trigger CI.

| Change set | Automatic macOS CI |
| --- | --- |
| Only the allowlisted documentation paths, including additions/deletions | Skip |
| Source, tests, package/build scripts, resources, configuration or `.github/**` | Run |
| Documentation plus any non-ignored path | Run |
| Docs-only latest commit on a PR whose overall diff still includes code | Run |
| Non-main branch push or tag push without a PR event | No push run, unchanged |
| Manual dispatch | Run, regardless of paths |

The filter uses GitHub's event diff, not a commit-message convention. Renames must be reviewed using both old and new paths: a move across the documentation boundary is not treated as documentation-only during review. Native rename evaluation is not independently reimplemented or verified here; if an expected run is absent for a boundary-crossing rename, dispatch the branch explicitly. A skipped event starts no runner, check job or artifact upload. It does not retroactively cancel an already queued/running check, including a documentation PR opened before this change. Other branches must contain the updated workflow before its filtering behavior can be relied on.

### Required checks and native filter limits

- The November 8 read-only inspection of [main metadata](https://api.github.com/repos/Mental-NV/Taskovsky/branches/main) reported `protected: false`, required-check enforcement off and no check contexts; the [ruleset list](https://api.github.com/repos/Mental-NV/Taskovsky/rulesets) was empty. The detailed protection endpoint was unavailable to the integration. No repository settings are changed.
- Do not require the path-filtered macOS job as an unconditional merge gate. A skipped workflow can leave a required check pending. Before enabling required CI, use an always-running gate that can report successful documentation-only validation while conditionally running the expensive job. The current workflow also has no `merge_group` trigger; add and verify merge-queue checks before enabling a queue.
- GitHub uses a three-dot PR diff and a two-dot existing-branch push diff. The documented comparison limit is the first 3,000 changed files; an unexamined code file can therefore be missed in a very large mixed update. Pushes over 1,000 commits or diff timeouts run unconditionally. Split unusually large updates or dispatch manually and inspect the exact run. These are native platform limits, not guarantees that a local pattern test can remove.

See GitHub's [path-filter and diff documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onpushpull_requestpull_request_targetpathspaths-ignore) (checked November 8, 2026), [skipped required checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/troubleshooting-required-status-checks#handling-skipped-but-required-checks) and [merge-group events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#merge_group).

<a id="ci-003"></a>
## CI-003 — Stages and artifacts

1. Checkout and record provenance, then verify pinned toolchain.
2. Run `swift test --disable-sandbox`, capturing both XCTest and Swift Testing output. Counts are observed evidence, not a hard-coded pass threshold. A compilation failure is not a completed test run.
3. If the test stage fails, retry the already-built test binary with `swift test --disable-sandbox --skip-build` for additional diagnostics. This cannot erase the original failure and is not a replacement passing gate.
4. Run the unchanged `./scripts/build-app.sh` after toolchain success, even if tests fail, to collect independent release-build evidence.
5. Run `codesign --verify --deep --strict --verbose=2 build/Taskovsky.app`.
6. Package with macOS `ditto -c -k --sequesterRsrc --keepParent`, restore into a disposable directory, check executable permission and byte identity, and verify the restored bundle's signature. Save a SHA-256 checksum next to the archive.
7. Upload the app ZIP and checksum as `Taskovsky-<actual-tested-SHA>-arm64` only after earlier required stages succeed.
8. Always write a stage-outcome summary and upload available logs as `diagnostics-<actual-tested-SHA>-ARM64`, including after a failed test/build. Runner loss or cancellation may prevent even an always-run cleanup step; no diagnostics are promised after infrastructure termination.

Shell steps use `set -euo pipefail` so `tee` cannot hide command failures. A failed test stage keeps the job failed even if diagnostic tests or independent release/signature checks pass. Archive production/upload require all normal prior stages to succeed; the summary distinguishes `failure`, `success` and `skipped`. Both artifact families retain for **14 days**, not indefinitely. Download needed evidence before expiry; GitHub log retention is separately controlled by repository settings. Artifacts require appropriate GitHub access. The nested ZIP preserves the macOS bundle rather than relying on raw artifact uploads to preserve executable modes.

Start with no build cache. Ad-hoc signing needs no private certificate and does not make this app a trusted distribution release. The archived binary is built and signature-checked, not launched or installed as part of CI.

<a id="ci-004"></a>
## CI-004 — GUI and operational limits

- Existing unit/store/text tests are not live Calendar gestures, VoiceOver, focus, window geometry, appearance, OS permissions or native editor Undo/Redo checks. Use isolated fixtures and a separately designed native harness for those.
- Standard hosted runners for this public repository are currently free under [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Larger runners, private execution, changed storage/retention or future plans can incur charges. Recheck [pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing) before changing scope.
- Queues, usage limits, image/toolchain changes and runner availability can delay or fail a run. Consult [Actions limits](https://docs.github.com/en/actions/reference/limits) and distinguish infrastructure/setup errors from source failures.
- GitHub Actions reads and job-log/artifact listing were exercised through the connected client. Dispatch/rerun permissions are separate; this implementation was triggered through PR events. Do not claim a client can dispatch until both permissions and default-branch availability are verified.
- No branch-protection or required-status rule was added. A visible passing check is not an enforced merge gate until the owner separately authorizes that configuration.

<a id="ci-005"></a>
## CI-005 — Verification and routine use

For a feature branch, push changes to a draft/open PR and inspect its latest applicable macOS CI run. Match the PR head, base and tested merge SHA in provenance before accepting results. Require all applicable stages and inspect failures in `tests.log`, `build.log`, `signature.log` or `package.log`; retrieve `summary.md` and environment logs from diagnostics. A changed code/mixed head needs a new result. A filtered documentation-only head needs static document review, not a fabricated runtime pass; manually dispatch it if new binary evidence is needed.

The [verification ledger](verification.md#hosted-macos-ci) is the implementation acceptance record, including the baseline run, controlled failure behavior, archive validation and exact environment. Hosted success does not close the recorded minimum-OS, Intel or manual UI gaps. The [filter follow-up](verification.md#docs-only-ci-filter) separately records what was exercised for the updated triggers. A later required-status change or deployment needs its own authorization.


<a id="ci-006"></a>
## CI-006 — iPhone Simulator compile-only gate

The independent `Compile iPhone and tests (Simulator ARM64)` job uses the same pinned `macos-15` / Xcode 26.3 environment and event revision. Existing documentation-only exclusions apply to both jobs. Missing tools fail rather than silently selecting a different Xcode. No branch protection, permissions or signing secrets change.

`./scripts/build-ios-simulator-ci.sh build/ci-ios` runs `build-for-testing` for the shared `TaskovskyMobile` scheme, Debug, `iphonesimulator`, generic iOS Simulator destination, ARM64 and disabled signing. It records the resolved iOS 17.0 deployment target, checks app/test bundles and the test-run manifest, and preserves provenance/build logs and `.xcresult` diagnostics for 14 days. Use a fresh output directory for local reruns; previous evidence is not deleted. The small Python command-double suite tests failure propagation and the non-execution contract, not iOS behavior.

**This is a compile gate, not a test run.** It does not boot a Simulator, launch/install an app, run `MobileContracts`/`MobileNavigation`, request permissions, contact an Apple developer account, publish a signed iPhone release, or prove iOS 17 runtime/physical-device/UI compatibility. Both desktop and iPhone compilation jobs must succeed for a code PR; independent native gates can still block readiness. The first hosted execution passed on Xcode 26.3 / Simulator SDK 26.2; exact revision and limits are recorded in [the change record](../changes/ios-simulator-compile-ci-2026-11-12.md) and [verification ledger](verification.md#hosted-ios-compile).
