# Working on Taskovsky

Read [docs/README.md](docs/README.md) first, then the relevant [business](docs/spec/business.md), [macOS UI](docs/spec/ui-ux.md), [architecture](docs/architecture/shared-engine.md), and [workflow](docs/spec/workflow.md) documents.

## Source and specification

- Source code is the authority for the current baseline. Approved change specifications define future deltas. Record disagreements; do not claim a feature exists or a test passed solely because documentation says so.
- TickTick research under `docs/ticktick-spec/` is reference evidence. Archived documents are historical. Neither authorizes new product scope.
- Keep business rules separate from platform presentation. The existing core is not yet iOS portable. Follow the documented boundaries before sharing editor or UI code.
- Do not silently erase unsupported rich text when introducing a limited editor. See [component contracts](docs/architecture/components.md).
- Keep known review findings visible until a fix and its evidence are verified. Documentation cleanup must not close a bug or make accidental behavior normative.

## Scope and concurrent work

- Inspect the latest branch and working tree before editing. Preserve other agents' changes. Use a separate branch for each bounded task; do not change or reset someone else's checkout.
- A documentation-only task changes Markdown documentation only. Do not change application code, tests, fixtures, build files, workflows, or dependencies to make the documentation true.
- Do not implement architectural/iPhone proposals or unrelated fixes unless the task requests them. Do not merge or deploy solely because a PR was requested.

## Verification

For code changes on macOS, use the repository's existing commands and report the exact commit/environment/results:

```sh
swift test --disable-sandbox
./scripts/build-app.sh
```

For UI changes, use a disposable isolated workspace from `python3 scripts/seed-qa-fixture.py`, then launch with `--workspace /tmp/TaskovskyQA/workspace.json`. Check applicable keyboard, resize, interruption, Cancel/Escape, reload, undo, dark appearance and reduced-motion cases. Do not use personal data as a fixture. Builds, tests, source review and native visual checks are separate evidence.

For documentation-only changes, check relative links, labels, source references and the diff allowlist. Do not claim that doc checks prove runtime correctness. If builds/tests are out of scope or unavailable, state that they were not run.

Update affected current specifications, [parity rows](docs/parity-implementation-status.md) where relevant, and [verification evidence](docs/spec/verification.md) in the same feature PR. Open a draft PR unless the task asks otherwise. Do not mark proposed functionality implemented before code exists.
