# Spec driven development workflow

Use a small, reviewable specification change before implementation, then keep the accepted behavior, code and verification together. This repository does not require a new framework, generator or copied second specification system to begin.

## 1 Read and freeze the starting point

Record the base commit, branch and clean/dirty state. Read the relevant business and UI contracts, architecture boundaries, current parity row and known deviations. Reconcile new commits from concurrent work. Do not assume the November 8 baseline remains current after code changes.

For a documentation alignment task, read code to establish current behavior. For a future feature, keep the current baseline distinct from the requested outcome. A source defect belongs in the deviation ledger, not in an silently rewritten requirement.

## 2 Define one bounded change

Copy the [change template](change-template.md) into `docs/changes/<short-feature-name>.md` when work is requested. Assign a stable change ID and link affected `BUS`, `UX`, component and parity IDs. The proposal must state:

- User outcome, scope, non-goals and which platforms change.
- Current source behavior and the precise intended delta.
- Business invariants, data/schema/migration implications, command and failure semantics.
- UI geometry, typography, alignment, colors, icons, motion, focus, keyboard/touch actions and component states, using existing tokens where appropriate.
- Acceptance cases including interruption, validation, cancellation, undo, reload and platform differences.
- Verification plan and unresolved product decisions.

An omitted visual detail is not permission to copy a TickTick screenshot or redesign the screen. Resolve meaningful ambiguity before implementation; explicitly preserve existing behavior outside the change. An iPhone-only capability limit can be deliberate, but must not cause shared-data loss.

## 3 Review the intended outcome

Use status `Proposed` until the product owner approves the scope or the implementing user request already specifies it unambiguously. Record the approval source/date without inventing a decision. Then use `Approved`. Architecture documents are proposals, not a blanket assignment to refactor everything.

Agree on meaningful business and UI decisions before implementation. A separate spec-only PR is useful for large changes; a small feature may keep proposal, implementation and evidence in one PR with distinct sections. The user remains able to review the delta.

## 4 Implement the contract

Use status `In implementation`. Inspect existing patterns and tests, add focused regression coverage where requested, and make the smallest coherent vertical slice. Both platforms call the shared engine for domain rules. Keep platform renderers and UI state separate. Extract components in behavior-preserving stages rather than mixing a port, data-format rewrite and redesign.

Implementation must not silently change the approved specification to match what was easiest to code. Record new limitations or decisions and get the required scope approval. Preserve concurrent fixes and do not absorb another workstream's commits merely to make a feature appear complete.

## 5 Verify each layer independently

- Domain: acceptance cases, recurrence/date boundaries, graph lifecycle, migrations, corrupted data, persistence and undo.
- Components: isolated contract tests and host/harness checks; rich text includes exact UTF-16 identity and cross-capability round trips.
- macOS: existing tests and build on macOS; isolated app checks for affected flows and layout boundaries.
- iPhone, when implemented: its own build, simulator/device, keyboard/touch/VoiceOver/Dynamic Type and lifecycle checks.
- Visual: known fixture, OS, appearance, point dimensions, scale, locale, text size and reduced-motion setting. Record actual screenshots/artifacts and measured results.

Test-file existence, a green historical report and static code inspection are not a current pass. Record passed, failed and not-run separately with exact commit. Tests for proposed modules do not exist merely because a test strategy is written here.

## 6 Review and finish together

Review the diff against acceptance cases, documentation and unintended scope. For UI, compare actual states and transitions rather than only one screenshot. Check data compatibility and unsupported-feature handling before releasing a limited client.

Use `Implemented, verification pending` when code exists but checks remain. Use `Verified` only for the specified acceptance cases/platform/environment with evidence. A merged change may still carry explicit known deviations. After integration, update current baseline contracts, parity and evidence links, then mark the change `Integrated` with the merge commit. Keep completed change records as history rather than competing current specifications.

Open a draft PR unless requested otherwise. PR creation does not authorize merging, deploying or running destructive actions against real data.

## Suggested implementation request

> Implement change `<ID>` from `<path>` at its approved revision. Preserve unrelated behavior and concurrent work. Follow the linked business/UI/component contracts and verification plan. Report unresolved decisions before broadening scope. Update the current specifications and evidence, distinguish not-run checks, and open a draft PR. Do not merge.

For documentation-only requests, replace the implementation/verification instruction with a Markdown-only allowlist and static document checks. Do not create application tests or fix known defects as a side effect of reconciling documentation.

## Hosted macOS verification

The [macOS CI workflow](../../.github/workflows/macos-ci.yml) runs tests, release packaging, signature checks and archive integrity checks for PR events, including drafts, and pushes to main. It skips automatic runs when every changed path is under `docs/` or is root `README.md` or `AGENTS.md`. Mixed documentation/code changes still run. A documentation-only commit on a PR that still contains code changes also runs because GitHub evaluates the full PR diff. Manual dispatch remains available without a path filter. The [CI specification](ci-cd.md#ci-002) describes exact triggers, required-check caveats and native filter limits.

For each feature, inspect the latest applicable run for its exact PR head and actual synthetic merge checkout. A filtered documentation-only update has no new build or artifact and is not a runtime pass; perform its static document checks instead, or dispatch manually if a build is needed. Download the diagnostics and app artifacts if needed before their 14-day expiry. A failed, skipped or cancelled required stage is not a pass. CI does not replace affected native UI acceptance, macOS 14 testing or Intel testing. Branch-protection enforcement and deployment are not configured by this work.

