# Baseline evidence and known deviations

## Snapshot and evidence levels

Source baseline: [`cfdec454acff91285ac00beaa20c0cf0f0961ee1`](https://github.com/Mental-NV/Taskovsky/commit/cfdec454acff91285ac00beaa20c0cf0f0961ee1), inspected November 8, 2026. This is main after [PR #2](https://github.com/Mental-NV/Taskovsky/pull/2) merged; its implementation head is [`b9de0dfe4522a818c5d08674dfbe04a396ad330a`](https://github.com/Mental-NV/Taskovsky/commit/b9de0dfe4522a818c5d08674dfbe04a396ad330a). PR #1 retains its documentation structure while incorporating that baseline. The initial documentation tree preserved that source. The authorized CI follow-up adds one workflow and, after hosted compiler failures and explicit user approval, extracts existing `TaskDetail.body` sections into private computed views. Other application source, final tests, fixtures, package/build scripts and dependencies remain unchanged.

| Evidence | What it establishes | Limit |
| --- | --- | --- |
| Exact merged source and regression files | Implemented Calendar behavior and corrective code paths | Static inspection is not runtime execution |
| [Final PR #2 correction report](../pr-2-calendar-review-findings-2026-11-08.md#verification-after-fixes) | Prior reported 464 tests passed (430 XCTest + 34 Swift Testing), release build and strict codesign verification | Prior local evidence; those logs are in ignored build directories. Fresh hosted runs are recorded separately below |
| [Calendar verification history](../ticktick-spec/calendar.md#verification-status--8-november-2026) | Earlier 453-test snapshot and bounded isolated live checks, followed by final 464-test correction evidence | Earlier totals are historical stages, not separate current gates; UI checks span release and identified debug fixtures |
| [Earlier review resolution](../code-review-findings-2026-11-08.md) | Reminder/cadence/editor regressions and selected live nested-Cancel/Quote checks | Native app Undo/Redo, quote/list switching and live paragraph-selection reproduction were not verified |
| TickTick observations/resource extract | Bounded reference UI/action/structure evidence | Not recovered scheduling algorithms or blanket parity |
| Proposed architecture and iPhone contracts | Intended future design | No extraction or iOS implementation implied |
| [Hosted macOS CI](#hosted-macos-ci) | Exact-revision automated test/build/signature/archive evidence | macOS 15 ARM64 only; not native GUI or minimum-OS verification |

The initial documentation refresh was static. Its requested follow-up now implements [macOS CI](ci-cd.md) and executes the existing suite/build pipeline. No new interactive native UI session or TickTick experiment was performed. No separate native UI-test target, release deployment or branch-protection rule is added. Main remains unchanged until an authorized merge.

<a id="known-deviations"></a>
## Review deviations and merged resolutions

Stable IDs are retained. These original source findings are fixed in the merged baseline; original reports are preserved rather than rewritten. “Fixed” here means corrective source and regression evidence are present, with prior execution reported below, not that automated CI covers every native acceptance case. Fresh automated execution is recorded below; live limits remain explicit.

| ID | Merged resolution | Evidence / remaining validation |
| --- | --- | --- |
| DEV-001 | `RepeatDraft` isolates nested Custom state; Cancel/dismiss preserves outer none/simple/custom, Done and Clear are explicit | [RepeatDraftTests](../../Tests/TaskovskyCoreTests/RepeatDraftTests.swift); [original report and live checks](../code-review-findings-2026-11-08.md#live-verification-final-build-2026-11-08) |
| DEV-002 | All-day descendant reminder shifts retain wall-clock time and relative days in the task zone | [CloneReminderTests](../../Tests/TaskovskyCoreTests/CloneReminderTests.swift), including DST, multiple/previous-day reminders, completion and persistence; no separate live reminder-delivery claim |
| DEV-003 | Nominal cadence is persisted and stepped independently of displayed weekend rolls; due edits rebase nominal state without resetting count | [NominalCadenceTests](../../Tests/TaskovskyCoreTests/NominalCadenceTests.swift), [NominalSeriesIntegrationTests](../../Tests/TaskovskyCoreTests/NominalSeriesIntegrationTests.swift); actual store successors, count/end bounds, reload and legacy fallback |
| DEV-004 | Block-range expansion respects the exclusive UTF-16 end | [BlockRangeTests](../../Tests/TaskovskyCoreTests/BlockRangeTests.swift), native text-policy cases; app-controller/live selection scenario and app Undo/Redo remain unverified |
| DEV-005 | Empty Quote toggles off to plain typing state instead of rearming | [QuoteToggleTests](../../Tests/TaskovskyCoreTests/QuoteToggleTests.swift); prior live on/off/type/reload evidence, with native app Undo/Redo and quote/list switching still unverified |

The four [Calendar review findings](../pr-2-calendar-review-findings-2026-11-08.md#resolutions--8-november-2026) are also fixed: unchanged point/precise saves are no-ops; existing short windows retain exact duration on move; future checklist rows reset completion before visibility filtering; and all-day Arrange uses displayed civil dates. [CalendarReviewRegressionTests](../../Tests/TaskovskyCoreTests/CalendarReviewRegressionTests.swift) has 11 named review tests; [TaskCalendarTests](../../Tests/TaskovskyCoreTests/TaskCalendarTests.swift) adds 18 Calendar cases. The final report records 464 total passing tests after final changes.

Prior live checks confirmed byte-identical unchanged point/short/zero saves, explicit Duration conversion with Undo, future checklist visibility under both completed settings, and Tokyo overdue classification on a Europe/Moscow host. Live short-block moves were not confirmed after the resize-handle fix. Arrange-to-hourly and cross-column drops, independent checklist interactions, exact 382-point minimum, exhaustive keyboard/VoiceOver/theme coverage and full gesture parity remain open validation work. Automated store coverage must not be described as live gesture proof.

## Evidence record for future changes

Record requirement/case ID, platform, exact source/checkout SHA, test or manual procedure, environment, fixture, command, date, result (`passed`, `failed`, `not run`) and durable artifact. A GitHub PR event may test a synthetic merge SHA rather than its head; record both explicitly. Prior local results and hosted CI runs are distinct evidence.

Visual records additionally need OS, logical content versus frame size, screenshot scale, appearance, locale/zone, text size, contrast and reduced motion. Use disposable data and cover interruption/repeated actions. The source-derived baseline remains **implemented, with automated verification limited to the recorded CI environment and cases**. Preserve live limitations even when unit/store checks pass.

<a id="hosted-macos-ci"></a>
## Hosted macOS CI — November 8, 2026

The user requested implementation/run verification of the prior CI proposal in PR #1, then explicitly approved a minimal behavior-preserving source refactor after the hosted compiler failure. No main merge or deployment was authorized/performed.

### Attempts and outcomes

| Run | PR head / actual checkout | Result |
| --- | --- | --- |
| [Initial workflow validation](https://github.com/Mental-NV/Taskovsky/actions/runs/42497446100) | Head `e546e20f9e955320818b91ddbb68e6ee9a3b43e7`; no job checkout | GitHub rejected the initial workflow before job execution. Corrected job-level log/package paths; not a test run. |
| [Xcode 16.4](https://github.com/Mental-NV/Taskovsky/actions/runs/42497493405) | Head `022bf288f715b7c1c74dcf0bc3c171a260f827ef`; merge `74b567052827c916c3267d851679ede6accbc8c5` | Swift 6.1.2 failed type checking at `TaskDetail.swift:73`, before tests ran. Build/signature/archive skipped; diagnostics uploaded. |
| [Xcode 26.3](https://github.com/Mental-NV/Taskovsky/actions/runs/42497791060) | Head `44abfbc4b8e8322da004f7b86a0ada8795407d06`; merge `18ceb361168ff53fe0b0c501dc00ec8f08a41f28` | Swift 6.2.4 reproduced the same compiler failure; diagnostics uploaded. Changing toolchain alone did not fix source compilation. |
| [Independent diagnostics](https://github.com/Mental-NV/Taskovsky/actions/runs/42498114615) | Head `7298ffd009327ae5f03690d88c3cf2b3e24f01c4`; merge `8d6070979612c7ebec72ade6dfbe07e3c69dc82e` | Already-linked test binary ran **430 XCTest + 34 Swift Testing tests, all passing**. Both debug and release app compilation failed at the same expression. The job correctly remained failed and did not upload an app. |
| [After approved refactor](https://github.com/Mental-NV/Taskovsky/actions/runs/42498387151) | Head `21a5f8b51070d32fab900d33795b82e68cf7612f`; merge `b4a095a13fba5fa1dc02352c0a49f66c162d0df0` | **Passed:** 430 XCTest + 34 Swift Testing tests (464 total), release app build, strict signature verification, restored-ZIP signature/executable/byte-identity checks, app and diagnostics uploads. |
| [Controlled failing test](https://github.com/Mental-NV/Taskovsky/actions/runs/42498767738) | Head `0486cf04dc9ffd10f03975abe9080faca0481ab8`; merge `1c8c9909b89f0dd9a37be41958f1eff8e014a573` | **Expected failure confirmed:** the one intentional XCTest failed; the other 430 XCTest and all 34 Swift Testing tests passed. The diagnostic retry also failed on that probe. Release build/signature passed independently, but archive/app upload were skipped and diagnostics uploaded. The temporary failure-probe file is removed from the completed PR tree. |

Successful-run environment: **macOS 15.8.2 (24H232), ARM64, image 20261104.0514.1; Xcode 26.3, Swift 6.2.4, macOS SDK 26.2**. PR base is `cfdec454acff91285ac00beaa20c0cf0f0961ee1`. These are PR-event synthetic merge checkouts, not commits pushed to main. The final documentation update also triggers CI; require its exact latest head's run before accepting the PR, rather than treating an earlier success as a result for later changes.

### What the source refactor proves

`TaskDetail.swift` is the only changed application file. Eight original view blocks were moved to private `@ViewBuilder` properties. Expanding the calls reconstructs the original body byte-for-byte; state ownership, bindings, actions, conditions, presentation modifiers and layout containers were retained. An independent static review found no blocking semantic issue. Static tuple nesting changes, so this is not a claim of identical internal view-tree types. Compilation/tests establish compiler compatibility in the tested environment; native focus, rich-editor, popover and visual smoke checks were not rerun.

### Evidence and remaining limits

- `swift test --disable-sandbox`, unchanged `./scripts/build-app.sh`, strict signature verification and restored-archive verification are separate stages. CI captures both test frameworks rather than hard-coding a total.
- Baseline success artifacts: [application](https://github.com/Mental-NV/Taskovsky/actions/runs/42498387151/artifacts/13624746559) and [diagnostics](https://github.com/Mental-NV/Taskovsky/actions/runs/42498387151/artifacts/13624139656). The inner application ZIP SHA-256 is `4b843b4e2e7dda5685f43bf2765a9a3439150b2f938fdf42c6f32c38914bffbc`.
- Run pages expose logs and artifacts named for the **actual checkout SHA**. App archives contain the macOS-preserving ZIP and SHA-256 checksum. Diagnostics contain provenance, compiler/SDK, stage logs and outcome summary. Artifacts expire after 14 days; preserve important evidence elsewhere before expiry.
- The failure runs prove failures are not hidden by `tee`, stage summaries survive, and diagnostics upload. A diagnostic test retry never changes the original failed gate. A failed required stage prevents app artifact publication.
- Draft and docs-only PR synchronization is exercised on PR #1. Main-push and manual-dispatch paths are configured but not executed because main was not changed. Manual dispatch needs the workflow on the default branch. Distinct concurrency groups were reviewed statically; unrelated-branch cancellation was not experimentally exercised.
- macOS 14, Intel, native GUI/VoiceOver/gesture behavior, notarization/distribution and deployment remain **not run/not provided**. Existing live limits above remain open. Required-status protection was not configured.
