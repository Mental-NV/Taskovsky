# Temporarily pause remote CI

## Identity and decision

- Change ID: CHG-CI-PAUSE.
- Status: Verified for static rename, preservation and diff-scope checks; integration pending.
- Requested and approved by the user on November 10, 2026: temporarily disable remote CI, for example by renaming GitHub Action files, so ongoing work does not wait for it.
- Base: remote main `6ee96eeb8f88e74a105c518de2202233ea528efa`; isolated branch `ci/pause-remote-actions-2026-11-10`.
- Related contract: [CI-006](../spec/ci-cd.md#temporary-pause-ci-006). Product, UI, parity and deviation IDs are unaffected.

## Outcome and scope

Rename the single [workflow](../../.github/workflows/macos-ci.yml.disabled) to end in `.disabled`, preserving its entire contents, pins, permissions, jobs and file mode. Keep application code, tests, dependencies, build scripts, local worktrees, existing branches and repository protection/permission settings unchanged. Separately, the sole workflow has been manually disabled in GitHub Actions to make the requested remote pause immediate without merging. This pause is separate from [PR #5](https://github.com/Mental-NV/Taskovsky/pull/5), which proposes docs-only filtering.

## Behavior and rollback

GitHub workflow discovery requires a `.yml` or `.yaml` extension. The disabled file is retained for review but does not execute as an Actions workflow. The rename only affects branches adopting it. Separately, GitHub Actions workflow `411265830` is confirmed `disabled_manually`, so the remote pause is effective immediately across the repository; existing runs are not cancelled. No data, schema, component or UI behavior changes. Local verification remains applicable.

To end the manual remote pause, explicitly re-enable workflow `411265830` in GitHub Actions. If this filename change is integrated, also restore by renaming `.github/workflows/macos-ci.yml.disabled` to `.github/workflows/macos-ci.yml` in a reviewed change. Reconcile PR #5 or other intervening changes before restoring or integrating, so they do not unintentionally re-enable CI. Do not weaken required checks or merge/deploy as a side effect.

## Acceptance and verification

- CI-PAUSE-01: no executable `.yml` or `.yaml` workflow remains in the proposed tree.
- CI-PAUSE-02: the renamed workflow retains blob `3d0189f7169ee5149eaf9466cefc177bd75e6a4b` and mode `100644`.
- CI-PAUSE-03: all files outside the rename and six related Markdown documents retain their original Git blobs and modes.
- CI-PAUSE-04: restoring the tracked workflow requires only renaming it back; ending the independent manual pause also requires explicitly enabling workflow `411265830`; a live restoration run is not part of this task.
- CI-PAUSE-05: publish a separate draft PR, verify its exact remote head and inspect its checks/runs without waiting for CI.

See the [verification record](../spec/verification.md#remote-ci-pause-2026-11-10) and PR for actual outcomes. No local application tests, build or native UI checks are claimed. No merge or deployment is included.

## Completion record

[Draft PR #6](https://github.com/Mental-NV/Taskovsky/pull/6) contains implementation commit `40447fe47fbbdd8b5eb94b64cb3b528aea564780` and records the final published head. The implementation head was confirmed remotely, with zero check runs, workflow runs and commit statuses observed after publication. These are point-in-time observations, not runtime passes. Integration is pending user review; historical CI results remain unchanged.
