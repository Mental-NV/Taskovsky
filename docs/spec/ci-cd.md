# macOS continuous integration

## Temporary pause: CI-006

Remote CI is temporarily paused in this branch at the user's request on November 10, 2026. The workflow is preserved byte-for-byte as [`macos-ci.yml.disabled`](../../.github/workflows/macos-ci.yml.disabled). GitHub discovers workflow files only with a `.yml` or `.yaml` extension, so this branch has no executable Actions workflow.

This is a branch-local file change, not a repository-wide Actions setting. Main and existing branches remain unchanged until this change is integrated or explicitly adopted there. Existing workflow runs are not cancelled. Manual dispatch is unavailable for the disabled file. Local verification remains required where applicable; lack of a remote check is not a test pass.

To restore the previous workflow, rename `.github/workflows/macos-ci.yml.disabled` back to `.github/workflows/macos-ci.yml` in a reviewed change. Preserve the contents, reconcile any other CI changes, and verify the restored workflow on its exact revision. [PR #5](https://github.com/Mental-NV/Taskovsky/pull/5) separately proposes docs-only path filtering and remains unchanged; merging it must not inadvertently recreate an active workflow while this pause is intended.

No required-check or repository-security settings are changed. At inspection, main reported protection disabled and no required checks, and the ruleset list was empty. The detailed protection endpoint was unavailable to this integration. Recheck requirements before integration; a required check that no longer runs can leave a PR waiting.

The sections below preserve the prior workflow configuration and historical implementation evidence. Their execution instructions apply after restoration. See [CHG-CI-PAUSE](../changes/pause-remote-ci.md) and the [pause verification record](verification.md#remote-ci-pause-2026-11-10).

## Status and purpose

**Implemented on PR #1's branch**, in [`.github/workflows/macos-ci.yml`](../../.github/workflows/macos-ci.yml.disabled), after the user requested implementation and verification on November 8, 2026. This replaces the earlier proposal. Tests, release build, signature and restored-archive checks have passed on the recorded hosted run. Main remains `cfdec454acff91285ac00beaa20c0cf0f0961ee1` until an authorized merge. The [verification ledger](verification.md#hosted-macos-ci) records actual runs, tested revisions and limits.

The workflow runs the existing Swift tests and release-app packaging on a GitHub-hosted Mac regardless of a developer's local OS. It is CI plus downloadable build artifacts, **not continuous deployment, Developer ID signing or notarization**. There is no native UI-test target. Architecture extraction and the iPhone app remain proposals.

<a id="ci-001"></a>
## CI-001 — Runner and toolchain

The single job is `Test and package (macOS 15, ARM64)`, on standard hosted `macos-15`. It asserts `uname -m == arm64`. `DEVELOPER_DIR` selects `/Applications/Xcode_26.3.app/Contents/Developer`; setup asserts Xcode 26.3 and logs compiler, SDK, OS, architecture and runner-image versions. Missing or unexpected tools fail rather than silently falling back.

The initial proposed Xcode 16.4 pin was actually tested. Its Swift 6.1.2 compiler failed to type-check the existing `TaskDetail.body` at `TaskDetail.swift:73`, before test execution. Xcode 26.3/Swift 6.2.4 reproduced the same source compiler failure. The user then explicitly approved a behavior-preserving `TaskDetail.body` refactor: eight original view sections became private computed `@ViewBuilder` properties, with the original state, bindings, actions and layout retained. The package deployment target and tests are unchanged. See the ledger for actual results after the refactor.

[Runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) is rechecked when updating the pin. An OS label and Xcode path do not freeze SDK patches or the hosted image forever. The package still uses Swift tools 6, Swift 5 language mode, and declares macOS 14 minimum.

**Coverage gaps:** macOS 15/ARM64 does not establish macOS 14 or Intel compatibility. Hosted macOS 14 is no longer available in the reviewed inventory; use an authorized minimum-OS environment or a separately approved deployment-target decision for that guarantee. Do not change the product target or provision paid runners as routine CI maintenance.

<a id="ci-002"></a>
## CI-002 — Events, exact revision and permissions

- `pull_request`: opened, synchronize and reopened, including draft and documentation-only PRs. There are no path filters.
- `push`: main only, after integration.
- `workflow_dispatch`: manual use **requires this workflow on the default branch first**. Before PR #1 merges, PR synchronization is the verified route; do not merge merely to enable dispatch.
- Every run records event, repository, PR number, head/base SHA, event ref/SHA and actual `git rev-parse HEAD`. Checkout uses the event revision and asserts it equals `GITHUB_SHA`. PR CI therefore tests GitHub's synthetic merge commit, not just the PR head. The ledger records both.
- Job timeout is 30 minutes. Concurrency groups combine workflow name with PR number or ref and cancel superseded runs in that group. Different PR numbers and branch refs have separate groups. This grouping is statically checked; unrelated-branch cancellation has not been tested by opening extra PRs. A cancelled run is not a pass.
- `contents: read` is the only requested token permission. Checkout does not persist credentials. No user/repository secrets, production signing credentials or personal workspace data are needed. There is no privileged `pull_request_target` execution, cache, deployment or repository-settings write.
- Official actions use verified full commit pins: checkout v7.0.1 (`3d3c42e5aac5ba805825da76410c181273ba90b1`) and upload-artifact v7.0.2 (`cf430e030ddbb5b0abf93d22962f4752f3646cd9`), both Node 24. Review version, inputs and upstream release before changing them.

See GitHub's [PR event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request), [manual dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch) and [secure use](https://docs.github.com/en/actions/reference/security/secure-use) documentation.

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

For a feature branch, push changes to a draft/open PR and inspect its latest macOS CI run. Match the PR head, base and tested merge SHA in provenance before accepting results. Require all applicable stages and inspect failures in `tests.log`, `build.log`, `signature.log` or `package.log`; retrieve `summary.md` and environment logs from diagnostics. A changed head needs a new result.

The [verification ledger](verification.md#hosted-macos-ci) is the implementation acceptance record, including the baseline run, controlled failure behavior, archive validation and exact environment. Hosted success does not close the recorded minimum-OS, Intel or manual UI gaps. Main-push/manual event paths remain configured but unexecuted until separately authorized integration. A later required-status change or deployment needs its own authorization.
