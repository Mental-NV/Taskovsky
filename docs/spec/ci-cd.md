# Proposed macOS continuous integration

## Status and purpose

**Proposal only, not implemented.** Requested with the November 8 refresh of PR #1. The inspected main baseline is `cfdec454acff91285ac00beaa20c0cf0f0961ee1`. It has no committed GitHub Actions workflow and no native UI-test target. No hosted macOS run has been executed for this proposal. Keep implementation in a separate change; this PR remains Markdown-only.

The goal is to run Taskovsky's existing Swift tests and app packaging on a GitHub-hosted Mac, regardless of the developer or agent's local operating system. A Linux executor lacking Swift/AppKit must not be treated as a reason that remote macOS verification is impossible. CI adds a reproducible build/test result; it does not automatically provide arbitrary interactive GUI coverage, continuous deployment or a notarized release.

<a id="ci-001"></a>
## CI-001 — Runner and toolchain

Use the standard ARM64 `macos-15` hosted runner as the initial required job and select Xcode 16.4 explicitly, subject to availability when the workflow is implemented. The package needs Swift tools 6, compiles in Swift 5 language mode and declares macOS 14 minimum. Print the selected Xcode, Swift compiler, OS version and architecture in every run. Fail clearly if the selected toolchain is absent; do not silently fall back to the runner's changing default.

The [runner catalog](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job) and [macOS 15 ARM64 image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) are the source for labels and installed versions. Recheck them during implementation: an OS label and explicit Xcode path do not freeze the image, SDK patches or preinstalled packages forever. Record the image version in logs and review removal notices.

**Minimum-OS gap:** a macOS 15 test does not validate behavior on the declared macOS 14 minimum. GitHub-hosted macOS 14 is unavailable in the reviewed catalog. A later macOS 14 self-hosted/other authorized runner, or an explicit deployment-target decision, is needed for that guarantee. Do not lower or raise the deployment target in the CI-only change. Add Intel coverage only if supported distribution architectures require it and a suitable current runner is selected; a green ARM64 job proves only the tested architecture.

<a id="ci-002"></a>
## CI-002 — Events, exact revision and permissions

Propose `pull_request` (open/synchronize/reopen, including drafts), `push` to main and `workflow_dispatch`. Test drafts too; PR #1 and future work should not need ready-for-review status merely to run tests. Use read-only `contents` permission, no repository/user secrets, no personal workspace data and no production signing credentials. Pin third-party actions to reviewed full commit SHAs and update deliberately. Do not execute untrusted PR code using `pull_request_target` with privileged credentials.

Record event, repository, PR number when present, head SHA, base SHA, ref and actual `git rev-parse HEAD`. By default a [pull_request event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request) checks a synthetic merge commit, not necessarily the PR head. Label results with the revision actually tested; distinguish a head-specific investigation from the normal merge-compatibility gate. Use explicit SHA inputs/checkouts only in a reviewed manual-run design, and log them. A main push validates the real merged revision separately.

[Manual dispatch](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch) requires the workflow definition on the default branch. A proposed/new branch workflow therefore cannot promise dispatch before that prerequisite is satisfied. PR events are the initial validation route for a new workflow. Give each run a bounded timeout and concurrency cancellation for superseded revisions, without treating cancelled runs as passes. See [secure use](https://docs.github.com/en/actions/reference/security/secure-use).

<a id="ci-003"></a>
## CI-003 — Required checks and artifacts

Run these repository-supported stages on the selected Mac, preserving the real exit status when output is piped to logs:

1. Print checkout/toolchain/environment provenance and resolve/build package dependencies as needed.
2. `swift test --disable-sandbox`. The existing suite includes Foundation/Combine/AppKit-dependent tests, XCTest and Swift Testing. Capture both frameworks' results; do not hard-code 464 as a permanent expected count. That is the prior PR #2 result, not a CI result.
3. `./scripts/build-app.sh` to assemble and locally sign the release application.
4. `codesign --verify --deep --strict --verbose=2 build/Taskovsky.app`.
5. Upload test/build/signature logs and provenance even when a stage fails. Name artifacts with the actual tested SHA and architecture, use bounded retention, and retain only disposable test data. When sharing the built app, package it on macOS in a format that preserves its bundle layout, permissions and symlinks, then validate the packaged artifact. A raw cross-platform artifact upload must not be assumed to preserve an executable bundle correctly.

Start without a build cache to establish reliable baseline behavior. If caching is later useful, key it by OS/architecture, Swift/Xcode version and relevant package inputs; a stale compiled-module cache must not masquerade as a source failure. No secrets are needed for ad-hoc local signing; this is not Developer ID signing, notarization, distribution or deployment. No deployment stage is proposed.

<a id="ci-004"></a>
## CI-004 — GUI and operational limits

- A hosted macOS job can run the existing automated tests; it does not turn the documented manual Calendar/editor checks into automated GUI tests. Native drag/drop, focus, VoiceOver, real window geometry, permissions and interactive session behavior need a separately designed harness and isolated fixtures. Do not claim live gestures passed because store regressions passed.
- The macOS 15/ARM64 environment differs from both the minimum supported OS and any Intel target. Record that limitation until a deliberate matrix covers them.
- Standard hosted runners for this public repository are currently free under [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Larger runners, private-repository execution, storage/retention or future plan changes may incur charges; consult [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing) before changing runner class or repository visibility. Do not provision paid runners under this proposal.
- Queues, usage/concurrency/time limits and runner availability can delay or cancel jobs. Use the current [Actions limits](https://docs.github.com/en/actions/reference/limits), sensible timeouts and cancellable superseded builds. A missing or cancelled result blocks a gate rather than establishing success.
- Toolchain pins age as images change. Re-verify Xcode availability and supported labels before implementation and when an image update breaks setup. Preserve logs that distinguish infrastructure/setup failure from compiler/test failure.
- GitHub app/token access must allow Actions reads to inspect logs and appropriate write permission for dispatch/reruns. Verify those permissions at implementation rather than promising remote execution from an untested connector. The workflow can still run from configured repository events even if a particular client cannot dispatch it.

<a id="ci-005"></a>
## CI-005 — Acceptance for the later implementation

A separate implementation PR should demonstrate a real macOS run for its exact recorded checkout, with all existing suites, app build and signature check passing, durable logs and clear failure summaries. Prove that an intentional failing test fails the job and uploads diagnostics using a controlled temporary change. Check a docs-only draft PR runs as intended and that concurrency does not cancel an unrelated branch. Verify workflow syntax/security, artifact integrity and the default-branch manual-dispatch prerequisite.

Only after a stable run should required-status/branch-protection changes be considered under separate authorization. Report remaining minimum-OS, architecture and GUI gaps. Keep [verification](verification.md), [workflow](workflow.md) and future feature acceptance evidence synchronized, using the actual run link and tested SHA rather than the proposed YAML or a historic local test count.
