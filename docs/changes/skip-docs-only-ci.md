# Skip documentation-only macOS CI

## Identity and decision

- Change ID: `CI-DOCS-001`.
- Status: Implemented, hosted verification pending.
- Request: “feature improvement: exclude CI for docs only updates”, November 8, 2026.
- Base: `6ee96eeb8f88e74a105c518de2202233ea528efa` on main; branch `ci/skip-docs-only-updates`.
- Contract: [CI-002](../spec/ci-cd.md#ci-002); no business, UI, data-format or parity behavior changes.

## Outcome and scope

Avoid allocating the macOS runner for an automatic event whose changed paths are exclusively documentation. Add matching native `paths-ignore` filters for PR events and main pushes, covering `docs/**`, root `README.md` and root `AGENTS.md`. Keep manual dispatch, all build/test/package stages, action pins, permissions, timeouts and concurrency unchanged. No merge, deployment, branch-protection change or alteration to another workstream is part of this change.

Previously all supported PR/main-push events ran the workflow, including documentation-only changes. The new filter evaluates the event diff, so a PR with any remaining code changes still runs even when its latest commit only edits docs. Documentation outside the explicit allowlist stays conservative and runs CI. Reserve `docs/` for non-runtime documentation/evidence; review the filters before adding executable inputs there.

## Acceptance cases

| Case | Expected result |
| --- | --- |
| D01: PR or main push changes only allowlisted documentation, including nested docs/evidence/assets | No new automatic macOS workflow |
| D02: Source, tests, package/build scripts, resources, workflow or configuration changes | Automatic macOS workflow runs |
| D03: Documentation plus a non-ignored path; PR still has earlier code changes | Automatic macOS workflow runs |
| D04: Markdown fixture or README outside the allowlist | Automatic macOS workflow runs |
| D05: Documentation deletion or rename wholly within the allowlist | Documentation-only policy; inspect GitHub event behavior |
| D06: Rename crosses documentation boundary | Review as a code change; require CI, dispatch explicitly if no run appears |
| D07: Manual dispatch, including a docs-only revision | Runs without path filtering |
| D08: Non-main push, tag, unsupported PR event | Existing trigger restrictions retained |
| D09: Existing queued/running workflow before a filtered event | No retroactive cancellation by the filter |

No UI, persisted state or migration changes apply. Reverting the trigger exclusions restores the prior automatic behavior. The filter skips workflow creation, not individual test assertions; it creates no passing runtime evidence or artifact for a docs-only revision.

## Verification and release

[Verification evidence](../spec/verification.md#docs-only-ci-filter) records static checks and hosted results separately. The [CI contract](../spec/ci-cd.md#ci-002) documents required-check, merge-queue, diff-size and rename limits. Do not enable unconditional required checks or merge queues without the corresponding always-running/merge-group design. Do not treat simulated event decisions as live GitHub event tests.

Release remains review of a separate draft PR. The user has not requested a merge. Existing documentation-only PRs and the desktop checkout are untouched.
