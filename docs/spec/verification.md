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

<a id="calendar-display-follow-up"></a>
## Calendar display follow-up — PR #3, November 8, 2026

This section records a later feature integration, not a revision of the historical PR #1/#2 outcomes above. Calendar source head [`13a3a486153fc1217f6228cb8e6cd8266dffb366`](https://github.com/Mental-NV/Taskovsky/commit/13a3a486153fc1217f6228cb8e6cd8266dffb366) is integrated with main [`b4216dec6ee2d95471038cf41ca6f92efcb94039`](https://github.com/Mental-NV/Taskovsky/commit/b4216dec6ee2d95471038cf41ca6f92efcb94039). Main's documentation reorganization, hosted workflow and TaskDetail refactor are retained. Source adds named secondary zones with staged search/configuration, Year Standard/Heatmap and item-icon visibility; see [BUS-030](business.md#bus-030), [UX-017](ui-ux.md#ux-017) and [TT-033](../parity-implementation-status.md#tt-033).

| Evidence | Result and scope | Limits |
| --- | --- | --- |
| [Original local report](../ticktick-spec/calendar.md#display-gap-follow-up--8-november-2026) and [investigation](../calendar-gap-investigation-2026-11-08.md) | **Reported passed:** 437 XCTest + 34 Swift Testing tests (471 total), including seven new [display-preference regressions](../../Tests/TaskovskyCoreTests/CalendarDisplayOptionsTests.swift); release build and strict codesign verification. Reported release executable SHA-256 `ef3346eb5cccc2a36a55aa4f540569a3b9433cf9d3a88fb0d5135bcee57669c4`. | Prior local evidence, not independently rerun in the cloud. Original logs are ignored build artifacts; exact OS/toolchain and tested checkout SHA were not recorded in that report, so the branch commit identifies the retained report/source rather than proving the checkout of the local execution. |
| Original isolated native checks | Reported search/Choose, labels/order/three-row limit, staged Save/Cancel/remove, visibility and process reload, icons/context-menu completion, Year styles/drill-down and unchanged task schedules in the disposable fixture. | No production workspace used. Native checks were not repeated during integration. Compact three-ruler layout, later-column DST offsets and earlier drag/keyboard/VoiceOver limitations remain open. |
| Cloud documentation integration | Static comparison of exact main and Calendar source refs; current specifications and canonical parity updated while preserving main corrections, moved pointers, historical reports and extended resource evidence. | Documentation/link/allowlist checks do not establish runtime correctness. No Mac operation, new TickTick experiment or local app/test execution performed during this step. |
| Final integrated-head hosted macOS CI | **Pending at documentation integration.** Require the checks for the final [PR #3](https://github.com/Mental-NV/Taskovsky/pull/3) head, recording actual checkout SHA and run URL in the PR's verification record before merge. | Do not reuse PR #1 success or the original local 471-test report as proof for the integrated head. Build, tests, signature and restored-archive checks remain separate gates; successful CI does not establish native visual parity. |

The original reference report distinguishes observed named-zone behavior from static Year/icon controls and unknown limits/gestures. Its reference cleanup was confirmed by the user, not independently re-inspected. No external integrations or additional product scope are introduced by this follow-up.


<a id="iphone-mobile-specification-2026-11-08"></a>
## iPhone mobile specification — 8 November 2026

This documentation-only change reconciles [the canonical iPhone specification](iphone.md) and records [CHG-IPHONE-MOBILE-SPEC](../changes/iphone-mobile-spec.md). Base main is `f85e2f6a9c538f36829961961a0749197f29c4e2`. The source freeze includes separately identified, read-only desktop working-tree evidence; its uncommitted Swift files are not included in this PR. Source-file and diff hashes are recorded in the specification, not represented as published commits.

- Static document checks passed: existing IOS-001–IOS-014 anchors retained uniquely, A01–A39 retained uniquely, Markdown table column counts, defined reference links, repository-relative targets and pinned source paths checked against the base repository tree, and three-file Markdown-only diff allowlist.
- Canonical detail remains in `docs/spec/iphone.md`; the change record links it rather than creating a competing specification. Screenshot assets and private screenshot content are not redistributed.
- All proposed acceptance scenarios are not run. No iPhone target, portable engine extraction, migration, sync or notification implementation is added. No simulator/device/native UI, API-floor audit, Personal Team signing or local-notification smoke test was performed by this publication task.
- macOS tests and builds were not run locally for this documentation-only update. Any hosted PR CI is separate, pending exact-head evidence; historical green checks do not validate this specification or its future iPhone implementation.
- User decisions and documentation approval do not mark implementation verified. Publication does not authorize merging, App Store submission, TestFlight or deployment.

<a id="calendar-visual-follow-up"></a>
## Calendar visual follow-up — local working tree, November 8, 2026

Approved scope: [CAL-VIS-001](../changes/calendar-visual-parity-2026-11-08.md). The [dated audit](../calendar-visual-parity-audit-2026-11-08.md) records reference observations, measurements, cleanup and remaining differences. This work is uncommitted on `codex/calendar-visual-parity`, based on `f85e2f6a9c538f36829961961a0749197f29c4e2`; that base SHA alone does not identify the changed build. No commit, push, PR or deployment was performed for this follow-up.

Environment: **macOS 27.0.1 (26A434), arm64; Xcode 27.0 (27A266a), Swift 6.4 (`swiftlang-6.4.0.34.1 clang-2100.3.34.1`)**. UI records use the MSI MP273A at calibrated 1 capture pixel/point, normal text size, light appearance and Europe/Moscow. Native Fill 1920×1050 and Left 961×1050 are distinct from the existing debug 780×580 sizing check.

Private evidence root: `/private/tmp/TaskovskyCalendarParityAudit-1108-bh2p266m`. It contains logs, captures, disposable fixtures, source manifest and the renamed isolated QA app; these temporary local artifacts are not hosted CI or guaranteed permanent storage.

The table below records the initial visual pass. The subsequent **boundary review correction** below supersedes its source/executable identities and Week capture; earlier logs and bounded native results remain historical evidence.

| Gate | Result / evidence | Scope and limits |
| --- | --- | --- |
| Final source identity | `final-source-manifest.json` SHA-256 **`28c3f62648f7ad6d49557e2cfb874e431a84d2330bc84684fbd261fb249f6e93`** | Sorted relative paths and file hashes for Sources, Tests, scripts and Package.swift; includes new CalendarAppearance.swift. Documentation edits are outside this compilation-input manifest. |
| Existing full tests | **Passed: 437 XCTest + 34 Swift Testing = 471**, zero failures. `swift test --disable-sandbox`; `final-tests.log` | Includes the existing 36 Calendar model/store/display cases. No new tests that merely mirror visual constants were added. Model tests do not establish native layout or gesture parity. |
| Final release build | **Passed:** `./scripts/build-app.sh`; `final-release-build.log` | Local ad hoc signed build, no distribution/notarization. Release executable SHA-256 **`8ff252c2874e6b69378dcf6b85e7ef3a75dadf0bf176bd16397df19120fb068c`**. |
| Signature | **Passed:** `codesign --verify --deep --strict --verbose=2 build/Taskovsky.app`; isolated renamed app also verified | QA app copied the same release executable and was re-signed with bundle `local.taskovsky.calendar-parity-audit`. Never launched against production data. |
| Matched visual comparison | **Passed for recorded geometry:** final signed-release Week and Year full/half captures; `final-pixel-metrics.jsonl` | See audit for before/reference/after measurements and residual border, tint, typography and control differences. No pixel-perfect or exhaustive visual claim. |
| Debug native layout checks | **Passed for exercised cases:** all seven modes; 780×580 compact Sidebar/Arrange; three rulers; crowded all-day scrolling and Month overflow/Escape; typed creation draft/Escape | Debug executable SHA-256 **`15eaa27acd2e956c2e09811cf7a953aa390a921040525d5db492fffd2c44798e`**. Earlier mode captures preceded the final header vertical inset/mini-month spacing adjustment; final compact crowded checks used the final source. Native release behavior is listed separately. |
| Signed-release regressions | **Passed:** unchanged point/five-minute Save, resize/Undo, empty/All list scope, tag filtering/reload, Week date-header drill-down and persisted Day/three-zone preferences | Point and short-window unchanged Save left normalized fixture bytes identical. Resize changed overlap A to 10:45; Undo restored scheduling fields. An attempted task move produced no file change and is **unconfirmed**, not passed. Focus date/disclosure expansion are intentionally transient. |
| Appearance/motion/accessibility | **Not verified:** dark, high contrast, enlarged text, reduced motion, full VoiceOver/keyboard order and hover-control keyboard reveal | Process-only dark override stayed light. Animation capture latency was too high for duration/easing inference. No system preference changed and no new guessed animation constants introduced. |

The baseline was independently tested/built before source edits, with the same 471-test total; its exact release/debug identities remain in private `build-identity.json`. Those baseline results are not substituted for the final results above. REA/Hopper failure, retained runtime state, unresolved reference semantics and user-state cleanup are recorded in the dated audit. Existing precise scheduling, recurrence/checklist and timezone regression contracts remain in force; unexercised native drag/DST/minimum-size paths remain open.

### Boundary review correction — final local source

Direct screenshot review found alternating missing hourly dividers and offset empty all-day dividers. File measurements confirmed subpixel rasterization of half-point rules plus empty internal scroll-view sizing. [The audit's boundary correction](../calendar-visual-parity-audit-2026-11-08.md#follow-up-boundary-correction) records the cause, implementation and all seven measured positions. No scheduling algorithms changed.

| Gate | Latest result |
| --- | --- |
| Source identity | Same base/branch, still uncommitted. `boundary-source-manifest.json` SHA-256 **`087df6f611e0730b445bbf1b3fe66c9a8bc603a348ff0d3e1f0b322d3b963688`**; same sorted Sources/Tests/scripts/Package.swift format as the initial manifest. |
| Full tests | **Passed again:** 437 XCTest + 34 Swift Testing = **471**, zero failures; `swift test --disable-sandbox`, `boundary-final-tests.log`. |
| Release build/signature | **Passed again:** `./scripts/build-app.sh`, `boundary-final-release-build.log`; strict signature verification in `boundary-codesign.log`. Release executable SHA-256 **`c6ae594c6990ae204279d9c7c01b8d01d3eb0ae823435b7a375f34bf37a632bc`**. The isolated re-signed QA app copied that executable and also passed verification. |
| Debug executable | SHA-256 **`67d330d604d2295dab0dc1c55a0ab3ab44974a7625c2b85c1ffa3381b7b5681f`**. Not used for the corrected native boundary checks. |
| Matched Week capture | `comparison-boundary-corrected-release-week-fill.jpg`, 1920×1050 at 1×, same three tasks/date/scope/scroll as reference. `boundary-after.jsonl` locates all seven date/all-day/hourly rules at x **341, 567, 792, 1018, 1243, 1469, 1694**, matching reference. Earlier `comparison-final-release-week-fill.jpg` remains pre-correction evidence. |
| Native date/card targets | **Passed:** 12 hourly creation probes on both sides of six internal boundaries, 14 all-day left/right creation probes across seven cells, seven timed-card Schedule/date probes. Each draft was canceled. JSON probe records and `boundary-seven-card-release` retained privately; comparison fixture still has exactly three tasks. |
| Native drops / Undo | **Passed in controlled repeats:** Arrange to Monday Nov 9 all-day point and Sunday one-hour card to Tuesday Nov 10 07:30–08:30; both Undo operations restored all controlled-fixture scheduling fields. Computer Use `drag` remained pending until a click at its intended endpoint completed the native drop. Earlier immediate no-change snapshots and a mixed-layout probe were inconclusive; they are not counted as failed/passed destination mappings. Source review confirms cards, headers and per-day destinations share the parent width calculation; explicit all-day frames now include empty cells. |
| Resize / Undo | **Passed again for the resized card:** Boundary day 1 changed 09:00–10:00 to 09:00–10:30, then returned to its original schedule. The earlier mixed drag fixture had a separate later write; no claim is made that resize Undo reversed that unrelated operation. |
| Checklist completion UI | **Unverified in this visual pass.** Checked/unchecked and forecast rows were rendered; no checklist completion control was activated in either app. Historical/model coverage does not establish current completion-interaction behavior. |

The corrected release checks ran in the same recorded Mac/toolchain/display environment. Taskovsky QA was closed afterward and TickTick was not touched during this boundary review. Exact minimum width, dark/contrast/large-text/reduced-motion/VoiceOver, short-window moves and exhaustive drag/auto-scroll/DST behavior retain their prior limits. No commit, push, PR or deployment was performed.

<a id="calendar-source-follow-up"></a>
## Calendar source and documented display corrections — November 9, 2026

Scope: [CAL-FILTER-001](../changes/calendar-filters-2026-11-09.md), [CAL-DISPLAY-002](../changes/calendar-documented-navigation-zones-2026-11-09.md), [official/live comparison](../tasks-calendar-comparison-2026-11-09.md). Same dirty `codex/calendar-visual-parity` checkout and base `f85e2f6a9c538f36829961961a0749197f29c4e2`; the preceding visual/boundary changes are preserved. This section supersedes earlier source/executable identities for the current tree without claiming their native cases were all rerun. No commit, push, PR, deployment or iOS implementation was made in this checkout.

Environment remains macOS 27.0.1 (26A434), arm64, Xcode 27.0 (27A266a), Swift 6.4 (`swiftlang-6.4.0.34.1 clang-2100.3.34.1`), Europe/Moscow. Native light-appearance checks used disposable fixtures, normal text and MSI MP273A at 1×, with full-window 1920×1050 captures and debug compact sizing. Earlier opening captures used the Retina display and are not matched-scale visual comparisons. The audit crossed midnight from November 8 to 9.

Private evidence root: `/private/tmp/TaskovskyCalendarFilterAudit-1108-w4ksafbs`. `starting-tree`, `starting-diff.patch` and `starting-state.json` preserve the initial dirty state. Temporary logs/screenshots/manifests are local artifacts, not durable hosted CI.

| Gate | Result / identity | Limits |
| --- | --- | --- |
| Final compilation inputs | `sealed-source-manifest.json` SHA-256 **`d1cac1c075854c9b94b275c10b9487ed4f316dfda133e08b0dc05ce9fc596a36`** | Sorted relative file/hash map for Sources, Tests, scripts and Package.swift. Documentation changes are outside this manifest. |
| Full tests | **Passed: 451 XCTest + 34 Swift Testing = 485**, zero failures; `sealed-full-tests.log` | `CLANG_MODULE_CACHE_PATH=/private/tmp/taskovsky-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/taskovsky-module-cache swift test --disable-sandbox --manifest-cache local`. Initial unmodified invocation failed before compiling because the default module cache was not writable; the recorded passing run uses a writable cache. Includes 13 new source-selection regressions and an additional four-zone persistence/primary-duplicate regression, 50 Calendar model/store/display cases total. |
| Release build and signatures | **Passed:** unchanged `./scripts/build-app.sh`, `sealed-release-build.log`; strict deep signature verification of build and guarded QA bundle | Release executable SHA-256 **`829388ecec6713a870a7f7942384f775760952d1836b52111734d184f27ca3fe`**. Ad hoc local signing; no distribution/notarization/account changes. |
| Baseline defect reproduction | **Confirmed:** detached All-label activation did not restore scope; checked All could still be tag-restricted | `taskovsky-before-all-label-does-not-restore`, `taskovsky-before-all-checked-but-tag-restricts`, using the previous boundary-corrected release. These are baseline failure evidence, not final results. |
| Debug source interactions | **Passed:** 15 scenarios in `debug-ui-filter-proofs.json` | Pointer label/indicator activation, Inbox, parent-tag descendants, list/tag union, final-source fallback, All reset/idempotence, mixed/full group selection and separate group expansion. The original 15 used M1 debug; final release separately rechecked core reset behavior. |
| View and compact scope | **Passed:** union selection retained in all seven views, including mini-month count; `debug-seven-view-scope.json`, `debug-union-*` | Work+Area shows three dated tasks. Debug 780 sizing checked compact sidebar, All reset and restoring custom scope; no enlarged-text/VoiceOver claim. |
| Final debug display changes | **Passed:** Day→Year→date opens Week; Year January title opens Month. Four-zone draft disables fifth Add; Escape cancels, Save persists, compact four-ruler Week renders | `debug-year-date-opens-week`, `debug-year-title-opens-january`, `debug-four-zones-draft`, `debug-four-zones-week`, `debug-four-zones-compact`. Search uses displayed city names (spaces); searching the raw underscore-containing New York identifier returned no results and remains a minor search limitation. |
| Final release native regressions | **Passed:** custom union and four rulers survived relaunch; All clears union; repeating All remains All; tag-only and final-tag removal restore All; Year date/title transitions | `release-reload-union-four-zones`, `release-all-clears-union`, `release-tag-only`, `release-last-source-restores-all`, `release-year-title-month`. Native release checking is distinct from debug layout checks. |
| Saved empty/stale safety | **Passed on final release:** explicit empty scope reloads with zero entries and explanation; unavailable references reload restrictively with visible recovery outside collapsed groups. All / Clear unavailable sources explicitly restore six entries | `release-saved-empty-stays-restrictive`, `release-saved-empty-explicit-all`, `release-stale-sources-stay-restrictive`, `release-stale-clear-explicitly-restores-all`. Fixture settings were deliberately seeded while the QA process was closed. |
| Data preservation | **Passed:** `initial-filter-workspace.json` byte-equals `filter-fixture/workspace.json` after all native selection/display checks | Source selection/display wrote preferences only. Unit tests separately exercise actual TaskStore reload, legacy scope, descendants, unavailable IDs, empty/tagless data, lifecycle exclusion and Arrange restrictions. Full native Arrange combinations were not rerun. |
| Installed TickTick | **Observed:** source union/reset/group controls, Year navigation, four additional draft rows, cancellation and bounded cleanup | Public guide links, exact observations and conflicts are in the dated comparison. Option icon reveal remains documentation-only after an unsupported reference control action; no modifier behavior claim. No new REA result. |
| Appearance/input/gestures | **Not run in this filter pass:** dark, contrast, large text, reduced motion, complete keyboard/VoiceOver traversal, exhaustive scheduling gestures, cross-column DST, exact minimum width | Existing gesture/model evidence retains its original scope; these checks cannot be inferred from source or 485 passing tests. |

**Isolation incident and correction.** A stale helper reopened the older private Calendar Audit app without isolation arguments, which read normal Taskovsky data. It was closed before an intentional task command; normal workspace/settings modification times predated this audit (November 6 22:22:39 and November 8 22:49:59 respectively, versus audit start November 8 23:59:53), so no writes during the incident were found. `qa-isolation-incident.json` records the event. Both private bundles were changed to guarded launchers with fixed disposable defaults; no-argument process launch was verified to receive disposable workspace/settings. Explicit app-parameter helpers replaced the stale captured handle. This corrects the isolation procedure; it does not justify claiming production data was never opened.

**Reference restoration.** The archived QA list was re-archived and observed; original three tasks retained. Both newly owned test probes were recoverably deleted and absent from active results, with no Trash purge. Four additional zones were never saved; reopening showed Moscow alone. Icon preferences remained on. Calendar returned to All, Day/Today November 9, sidebar hidden and source groups collapsed, original 1337×700 window retained. `reference-cleanup.json` and restoration captures retain evidence. The final Taskovsky QA process was closed. The broader desktop/mobile parity goal remains open; this is a bounded Desktop milestone.

<a id="mobile-foundation-preview"></a>
## Shared mobile foundation, preview and conservative repository — November 9, 2026

This is a partial implementation milestone under the user's autonomous local Tasks/Calendar parity request, following the Desktop milestone above. It does **not** establish full desktop/mobile parity or a writable phone release. Scope: [MOB-FOUNDATION-001](../changes/mobile-foundation-2026-11-09.md), [MOB-PREVIEW-001](../changes/mobile-preview-2026-11-09.md), [MOB-PERSIST-001](../changes/mobile-compatible-writes-2026-11-09.md), IOS-008/012/014. No commit, push, PR, device signing, runtime download, notification permission, external integration or deployment was performed.

**Checkout:** `origin/main` was freshly fetched and confirmed at merged PR #4, **`6ee96eeb8f88e74a105c518de2202233ea528efa`**. A separate worktree at `/private/tmp/TaskovskyMobile-1109`, branch `codex/mobile-local-prealpha`, preserves the original dirty Desktop tree. The original Desktop compilation-input manifest was rechecked unchanged after mobile work. Its corrected source-selection/four-zone domain files, regressions and coherent Calendar UI/appearance files were explicitly carried into this branch; private `desktop-domain-integration.json` records every original/copied hash. Projection calls the extracted pure recurrence helper instead of TaskStore's facade. The integration retains PR #4's canonical mobile specification and verification history, and no Desktop checkout file was edited or committed to achieve it.

**Environment:** macOS 27.0.1 (26A434), arm64; Xcode 27.0 (27A266a), Swift 6.4. iOS SDK 27.0; compiler targets include `arm64-apple-ios17.0-simulator` and `x86_64-apple-ios17.0-simulator`. Native execution used an isolated **Taskovsky QA iPhone 13 Pro**, **iOS 26.3.1 (23D8133), arm64**, standard 390×844 point/1170×2532 pixel portrait capture. The available runtime inventory also includes 26.5 and 27.0. No iOS 17 runtime or physical-device result is claimed. The app's sample clock is November 9, 2026, Europe/Moscow; dynamic system status information is not a visual comparison target.

Private evidence root: `/private/tmp/TaskovskyMobileEvidence-1109`. Temporary derived data/results are not durable hosted CI. See [Mobile build/test instructions](../../Mobile/README.md).

| Gate | Actual result | Scope and limits |
| --- | --- | --- |
| Main baseline | **471 tests passed:** 437 Core XCTest + 34 Swift Testing; `baseline-macos-tests.log` | Fresh test of merged mobile-spec base before source extraction. |
| Initial extraction | **479 passed:** baseline plus 8 portable characterization tests; `extraction-macos-tests.log` | Destination/history/filter semantics, task zones, legacy cadence/month/leap/DST, exact rich identity and precise schedule no-op. Initial compile exposed a cross-module Undo memberwise initializer; explicit public initializer fixed the boundary. |
| Final Mac suite | **505 passed:** 451 Core XCTest + 8 Domain XCTest + 12 Workspace XCTest + 34 Swift Testing; `repository-macos-tests.log` | `CLANG_MODULE_CACHE_PATH=/private/tmp/taskovsky-mobile-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/taskovsky-mobile-module-cache swift test --disable-sandbox --manifest-cache local`. Earlier intermediate 496-pass run preceded the 9 additional repository cases and is not the final total. Separate XCTest bundles are summed once each, not inferred from the last bundle's total. |
| Mac release/signature | **Passed:** unchanged `./scripts/build-app.sh`, `repository-macos-release.log`; strict deep signature verification | Executable SHA-256 **`1869afb6f2d420764c5fe31302e11e4267081de3eb7035a542e9045cdf3f8c1a`**. Mac dependency inspection shows system frameworks, with no missing portable-product runtime dependency. New native Mac UI checks after module extraction were not run; earlier Desktop native checks retain their exact original scope. |
| Final source/project identity | `repository-source-manifest.json` SHA-256 **`9bcd737691efe43f8cde2a4453136d7935a08217d017c3dd7164cf3c8a6d63c4`** | Sorted hashes for Sources, Tests, scripts, Mobile source/project/scheme and Package.swift, excluding Markdown and user-specific Xcode state. Exact manifests and binary maps are in `repository-build-identity.json`. |
| Portable iOS build | **Passed:** standalone Foundation-domain compile for iOS 17; native Xcode simulator app build with iOS 17 minimum | Actual compiler targets establish compile availability only. TaskovskyDomain imports Foundation and has no Core/UI/file/network dependency. Core still retains Mac services/editor; full editor-host extraction is pending. |
| Final simulator tests | **21 passed, 0 failed/skipped:** 8 shared tests + 12 repository/read tests + 1 UI navigation test; `repository-ios-tests.log`, `repository-summary.json`, `repository-ios-tests.xcresult` | `xcodebuild -project Mobile/TaskovskyMobile.xcodeproj -scheme TaskovskyMobile -destination 'platform=iOS Simulator,id=ED2459ED-2E4D-4E78-8A2E-5628A303C444' -derivedDataPath /private/tmp/TaskovskyMobileEvidence-1109/DerivedData -resultBundlePath /private/tmp/TaskovskyMobileEvidence-1109/repository-ios-tests.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test`. Runtime warning below remains open despite the passing test result. |
| iOS executable identity | Main launcher **`c1c37b3c6dd163ad3e28d128c329cdd2b4d29564e678c617f82650d365fee597`**; debug code **`1d6d08d2164be33720aedd78fa6912bfe26a8ebd6c38a0f0a787c8e789d9c18d`** | Debug code resides in `TaskovskyMobile.debug.dylib`; the launcher alone does not identify it. Domain/Workspace framework hashes are retained in the binary map. This is a simulator test build, not a signed device/distribution artifact. |
| Immutable viewing | **Passed:** originals retained with unknown payload elsewhere, malformed rich/mismatched text; unreadable workspace/settings and unknown enum fail closed | The reader has no save callback. The UI uses generated neutral Debug samples, not Mac data; Release starts empty/read-only. Tests do not prove a complete real-data loader or phone metadata editor, neither of which is wired. |
| Conservative writes | **Passed on Mac and iOS:** known styled-title preservation, exact Unicode, all unowned workspace fields, settings bytes, true no-op, unknown fields elsewhere/settings, duplicate JSON keys, stale revisions, competing commands, archive/trash/missing/body guards and injected write failure | Explicit injected URLs only; one actor serializes in-process patches. Whole-document canonical structural round-trip gate can lock valid legacy data. Enum-keyed visibility maps compare as known unordered maps; settings are never rewritten. This is not arbitrary opaque-data write support, a migration, multi-process locking, capture idempotence or the complete S3 round-trip matrix. |
| Native preview navigation | **Passed:** Tasks→styled detail→Done→Calendar Year/Month→Search→matching task result; no Add control | Four 1170×2532 screenshots per passing run. The final `repository-screenshots/manifest.json` maps names to exact files. Seven Calendar modes are present in source, but only Year/Month were exercised in this UI test. Filters/full display/Arrange/gestures and other modes remain unverified on phone. |
| Visual review | **Partial only:** preview cards, detail, capsule and read-only/search states reviewed; final capture has neutral content | No near-pixel-perfect sign-off. Year currently scrolls its fourth month row; default text/layout and several header/card details differ from the reference. The first boot's Year capture was partly covered by a system Apple Intelligence banner, not an app capability. An emoji rendered as a fallback glyph in the detail capture; underlying UTF-16 preservation passed independently. |
| Remaining acceptance | **Not run/not implemented:** iOS 17 runtime, physical iPhone/Personal Team signing, notifications, full rich rendering/editor host, safe phone editing/capture/lifecycle, real-data bootstrap/recovery, Board/Summary, full settings/search/filter/organization UI, Dynamic Type/VoiceOver/dark/RTL/rotation/interruptions/performance | A simulator pass does not satisfy these gates. No alert-delivery promise or OS permission prompt was introduced. Full original Mac→phone-edit→Mac fixture exchange remains pending; platform tests constructed equivalent controlled fixtures independently. |

### Test-run corrections and open runtime issue

The first Xcode test build tried linking x86_64 app objects against ARM-only active simulator dependencies. Debug `ONLY_ACTIVE_ARCH=YES` fixed the configuration; the failed build is retained in `preview-ios-tests.log`. A later 12-test run passed all cases but spent minutes collecting verbose simulator diagnostics. Its identified `simctl diagnose` child was terminated; Xcode then finalized with exit 0 and TEST SUCCEEDED. A clean repeated run used `-collect-test-diagnostics never`, passed 12 cases and finalized normally. The final 21-case repository run also used that flag and completed normally. No failed test was changed into a pass by suppressing a test assertion or replacing the app implementation.

**MOB-DEV-001 — unsupported runtime view attachment.** Both final simulator reports contain a runtime warning that `_UIReparentingView` was added to `UIHostingController.view` through an unsupported hierarchy. Tests report zero failures, but this warning remains an unresolved UI integration issue. The app source uses SwiftUI presentation, text selection and search, with no explicit native subview insertion; the precise trigger/cause is not established. Investigate with a minimal native reproduction before choosing a workaround. Do not mark S4 accessibility/visual acceptance complete or silently dismiss this warning as a proven OS defect.

No production user file was read or written by the mobile work. Repository write tests used their own generated temporary files; the phone preview generated samples in memory. This statement is about mobile work, not a revision of the separately documented earlier Desktop QA isolation incident.

### Corrected native Calendar follow-up — current preview

Expanded UI tests supersede the earlier preview's native scope and open-warning status, without rerunning unrelated Mac code. Two isolated UI attempts failed before test startup with SpringBoard Busy/preflight errors. An explicit simulator boot/`bootstatus -b` completion allowed the tests to run. These launch failures are retained separately from application assertions.

The first expanded Calendar test failed because the Inbox sample remained visible after Work was tapped. A stricter value assertion then showed the native switch still off; therefore the initial failure did **not** establish a projection-cache cause. Full-row checkbox buttons now expose Selected/Not selected and route label/indicator activation through one domain command. Projection is independently derived once in the outer view body and passed to its renderer, avoiding cached Binding-derived entries. The former native mode Menu was replaced with a contained 220-point popover, seven 44-point rows and selected checkmark.

**Final corrected native run:** `checkbox-ios-tests.log`, `checkbox-summary.json`, `checkbox-ios-tests.xcresult`: **24 passed, zero failed/skipped, `runtimeWarnings: []`**. This comprises the same 20 shared/repository cases plus four separate UI tests for task details, Search, all seven Calendar choices, and Work/All source selection. Work's value becomes Selected, the Inbox sample disappears, and All restores it. The screenshot caption in that run said Month after All reset, but the actual source-reset test used Week; the caption was corrected and a focused case rerun is recorded in `filter-caption-final.log`/result bundle. No task mutation was enabled by these UI corrections.

Current source/project manifest: `checkpoint-source-manifest.json` SHA-256 **`40cf4ff204e26e457d34a13b3c8df4608a1748f3b067ad1f969fc2c6977ad68a`**. Current debug app code SHA-256 **`00f9d87ee1e41c9820f634c1f2d2f6a22a1fa7e3c78e1b068db272d9d36f0d70`**; launcher and Domain/Workspace frameworks retain the identities in `checkpoint-build-identity.json`. Mac source inputs and the 505-test/release evidence above are unchanged by these Mobile-only view/test changes.

**MOB-DEV-001 disposition:** no longer reproduced in the final tested flows after the popover/checkbox changes. The exact private-framework mechanism is not established; do not claim every OS/runtime or presentation combination is fixed. **MOB-DEV-002 (source-row activation):** final native selected-value and content assertions pass with the full-row checkbox control. The earlier failed assertions remain as provenance, not current failures.

Six final native attachments are mapped in `checkbox-screenshots/manifest.json`: Tasks, styled plain preview, Search, Year, Month, and Week after source reset. These are functional/layout smoke captures, not visual parity sign-off. The read-only sample limitation, fourth Year row scrolling, glyph fallback, real-data/durable-edit UI, full rich rendering, advanced interactions and accessibility/device/notification gaps above remain open.

Local source checkpoints are saved outside the temporary worktrees under `/Users/mental/.codex/visualizations/2026/11/07/01a1b800-c122-7fd1-bbb3-0695744921b6/taskovsky-checkpoints/`. They contain dirty-source overlays, base/branch/file hashes and tracked diffs, with no commit/push. The authoritative working trees remain separate; temporary build/results folders retain their original paths and limited lifetime.

<a id="mobile-local-editing"></a>
## Local phone field editing — November 9, 2026

This section supersedes the read-only/current-scope claims in the historical preview reports above. Source remains uncommitted on isolated `codex/mobile-local-prealpha`, base `6ee96eeb8f88e74a105c518de2202233ea528efa`. [MOB-EDIT-001](../changes/mobile-local-editing-2026-11-09.md) connects app-container files, conservative field patches and separate resumable drafts. No commit/push, device install, signing-account change, notification prompt or external integration. The original Desktop checkout remains on `codex/calendar-visual-parity`; all 98 entries in its sealed source manifest still match, SHA-256 `d1cac1c075854c9b94b275c10b9487ed4f316dfda133e08b0dc05ce9fc596a36`.

Environment: macOS 27.0.1 ARM64, Xcode 27.0 (27A266a), Swift 6.4. Phone execution uses only the owned **Taskovsky QA iPhone 13 Pro**, iOS 26.3.1 (23D8133), simulator UUID `ED2459ED-2E4D-4E78-8A2E-5628A303C444`. The iOS 17 deployment target is a compile target, not tested runtime support. Evidence root: `/private/tmp/TaskovskyMobileEvidence-1109/`; compact records and source checkpoint are also preserved outside temporary worktrees below.

| Check | Verified result | Scope and limits |
| --- | --- | --- |
| Mac suites | **520 passed:** 451 Core XCTest + 8 Domain XCTest + 27 Workspace XCTest + 34 Swift Testing; `local-editing-sealed-macos-tests.log` | `CLANG_MODULE_CACHE_PATH=/private/tmp/taskovsky-mobile-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/taskovsky-mobile-module-cache swift test --disable-sandbox --manifest-cache local`. Fourteen initial bootstrap/scratch cases plus one cleanup-retry regression extend the prior 505. Counts are summed once per bundle. |
| Mac release | **Passed:** `./scripts/build-app.sh`, `local-editing-sealed-macos-release.log`, strict deep signature verification | Executable SHA-256 `1869afb6f2d420764c5fe31302e11e4267081de3eb7035a542e9045cdf3f8c1a`. Narrow mobile services are not called by the Mac executable. No new native Mac UI check after this mobile slice; earlier Desktop evidence retains its own scope. |
| Final simulator run | **49 passed, 0 failed/skipped, runtimeWarnings: []**; `local-editing-final49.log`, `local-editing-final49-summary.json`, `local-editing-final49.xcresult` | 8 Domain + 27 Workspace + 14 UI cases. `xcodebuild -project Mobile/TaskovskyMobile.xcodeproj -scheme TaskovskyMobile -destination 'platform=iOS Simulator,id=ED2459ED-2E4D-4E78-8A2E-5628A303C444' -derivedDataPath /private/tmp/TaskovskyMobileEvidence-1109/DerivedData -resultBundlePath /private/tmp/TaskovskyMobileEvidence-1109/local-editing-final49.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test`. |
| Bootstrap/recovery services | **Passed:** install without reseed, corrupt/partial/orphan-staged pairs, compact revision, exact Unicode round-trip, unknown/version/malformed scratch, failed initial/newer write, ordered/closed callbacks, cleanup failure/retry, stale recovery | All explicit temporary URLs. Failed cleanup retains an exact removal candidate so retries work while writes/begin stay refused for the closed identity. No recovery overwrite/import or multi-process locking. A production operation ticket also rejects obsolete refresh completions; no deliberate refresh-race stress test was run. |
| Native editing | **Passed:** styled-task title save/relaunch, plain-body kill/relaunch/Resume/Done, dirty Cancel Keep Editing/Discard, recovery Discard, unchanged Done, failed/stale saves, unknown workspace/draft guards, invalid isolation arguments | Recovery test waits for “Recovery copy saved” before termination. It does **not** measure the pre-acknowledgment force-kill window. Dirty swipe is blocked; explicit Cancel offers the alert. Native undo/selection and marked-text guards are present in source, not a full IME/Undo acceptance pass. |
| Mac→phone→Mac files | **13 QA file audits and 12 known-format Mac reloads passed:** `local-editing-final49-roundtrip.json` | Bundled fixtures were written by actual Mac TaskStore using explicit URLs and `seed: false`; SHA-256 workspace `93aac4e8973e9a4ec6cdcb23ff25180648f514526391a5a6ac5811ce6a091968`, settings `e7d62e0d24c6c15c8f697abc5d42b0430d72652c2e23babb83e5112c14f7fc7c`. Native phone edits change only title/body + updatedAt. All other decoded fields, styled payload/text, schedule/tag/list data remain exact; settings bytes are identical. View/no-op/Cancel/refusal cases preserve raw workspace bytes. Unknown synthetic data and version-99 scratch remain intact. `scripts/verify-mobile-qa-roundtrip.py` maps result attachments to UUID-only QA directories; the Mac helper loads without saving. This is eight neutral records, not arbitrary-format or shared-live-file compatibility. |
| Calendar/navigation regression | **Passed:** seven modes, Work/All source selection, Search, detail dismissal and view-only navigation | The earlier source-control/popover regressions remain covered. No runtime warnings in the final exercised flows. Advanced phone Calendar authoring/display/Arrange/drag-resize and reference visual parity are still pending. |
| Exact source/build identity | Manifest `local-editing-source-manifest.json`, SHA-256 `607804d9adf474b5ccbefccd5ef7fabe2c49c323d657bfdc0e0c8921a3d8faf6`; complete binary map `local-editing-build-identity.json` | 121 source/test/script/project/resource files, excluding Markdown/user-specific state. iOS launcher SHA-256 `c1c37b3c6dd163ad3e28d128c329cdd2b4d29564e678c617f82650d365fee597`, actual debug-code SHA-256 `1be89c00137f50cd991d30d5ca86d2455c1ec05df6e1d1e6a3682daf116c3864`. Framework hashes are in the map. Simulator artifacts are not a device/distribution build. |

### Failures, corrections and native layout evidence

The first editing run reported **42/44 passed**. The compact confirmation dialog omitted its cancel-role “Keep Editing” action; an alert now exposes both choices. The stale-save assertion also used a label longer than XCTest's identifier limit; the app's refusal retained the draft, and the test now addresses the error by a stable identifier. The focused two-case rerun passed. Subsequent expanded 47- and Mac-fixture 48-case runs passed; they precede later source changes and are not the final source proof.

Screenshot review then found short text centered in the editor's minimum-height space. The native host now returns the proposed width and its wrapper aligns top-leading. **MOB-DEV-003:** final recovered-description capture verifies the corrected inset and reachable Cancel/Done/keyboard. **MOB-DEV-004:** source review found failed draft cleanup invalidated the identity without permitting removal retry. A separate cleanup candidate and a transient-failure regression now prove retry without re-enabling late saves. Earlier service/UI passes did not cover that defect. Final native attachments are in `local-editing-final49-attachments/manifest.json`; recovered description, failed save, stale edit and styled preview were visually inspected. The styled plain preview still shows an emoji fallback glyph; exact underlying UTF-16/rich data survives the file audit. These are smoke checks, not reference visual sign-off.

Normal Debug/Release now starts with an empty local workspace; capture is not implemented yet. Task creation/lifecycle, metadata/schedule/organization editors, full rich rendering, settings/search/Board/Summary, physical iPhone/signing/notifications, iOS 17 runtime, IME/VoiceOver/Dynamic Type/dark/RTL/rotation/long-text performance remain open. File protection is requested until first unlock; normal Application Support backup eligibility is retained under device settings, but actual backup/restore was not tested. No new user/desktop workspace data was read or written by this mobile work; only explicitly owned neutral QA folders and temporary fixtures were audited.

A new `MobileEditing-2026-11-09.zip` source checkpoint and `mobile-editing-evidence/` are preserved under `/Users/mental/.codex/visualizations/2026/11/07/01a1b800-c122-7fd1-bbb3-0695744921b6/taskovsky-checkpoints/`. The earlier DesktopCalendar/MobilePrealpha snapshots remain unchanged. ZIP CRCs and every source entry hash were checked; no Git metadata, personal workspace or deployment artifact is included. Working trees remain authoritative and uncommitted.

<a id="mobile-local-capture"></a>
## Local task/note capture — November 9, 2026

[MOB-CAPTURE-001](../changes/mobile-capture-2026-11-09.md) implements the first task/note workflow on the previously empty normal phone workspace, plus explicit destination/date/priority/tags, saved templates and separate recovery. These checks supersede the earlier statement that the phone cannot create tasks. The work is uncommitted on isolated `codex/mobile-local-prealpha`, base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The original Desktop checkout remains untouched (98 sealed source hashes match); prior checkpoints and restored TickTick reference state are unchanged. No push, deployment, signing-account change, external integration or notification prompt.

Environment: macOS 27.0.1 ARM64, Xcode 27.0 (27A266a), Swift 6.4. Native tests use the owned Taskovsky QA iPhone 13 Pro, iOS 26.3.1 (23D8133), UUID `ED2459ED-2E4D-4E78-8A2E-5628A303C444`. `vtool -show-build` on the actual debug code reports IOSSIMULATOR minimum 17.0, SDK 27.0. No iOS 17 runtime or physical-device verification. Exact files are under `/private/tmp/TaskovskyMobileEvidence-1109/` and the compact checkpoint below.

| Check | Result | Scope |
| --- | --- | --- |
| Mac extraction and commands | **530 cases passed:** 451 Core XCTest, 8 Domain, 37 Workspace and 34 Swift Testing; `capture-sealed-macos-tests.log` | `CLANG_MODULE_CACHE_PATH=/private/tmp/taskovsky-mobile-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/taskovsky-mobile-module-cache swift test --disable-sandbox --manifest-cache local`. The prior 520 cases passed immediately after extraction; ten added command cases cover context, existing tags, templates, compatibility, restart/concurrent retry, failure classification and recovery. A strengthened archived-target assertion passed separately in `capture-archive-guard-macos.log`. No new native Mac UI run; the Mac command facade is exercised by the store suites. |
| Mac release/signature | **Passed:** `./scripts/build-app.sh`, `capture-sealed-macos-release.log`, strict deep signature check | Executable SHA-256 `85381ebfebdc9ccc7be5d2be4a7ad1299fb7b8247ffcb0413808ae68b9dc5f64`. Mac retains existing URL-title dispatch; the portable creation path has no network calls. |
| Full simulator and focused corrections | **69 distinct cases verified across two runs:** full **68 passed / 1 test-harness failure**, followed by **2 focused passes** (corrected note scroll assertion and strengthened archived-target case); zero skipped or runtime warnings in both | 45 shared + 24 native cases in the full run; the focused archive case repeats one shared case. `capture-final-ios.log`, `capture-final-summary.json`, `capture-final.xcresult`, `capture-final-focused.log`, `capture-final-focused-summary.json`, `capture-final-focused.xcresult`. Final app/Domain/Workspace binary hashes are identical across those runs. A full clean rerun after the test-only adjustments was not performed. |
| File audit and Mac reload | **23 QA files audited, 22 Mac reloads without writes**; the focused note was independently re-audited/reloaded | Seven successful captures add exactly one UUID record and preserve every pre-existing decoded field, templates, tags and settings bytes. Cancel and failed saves preserve raw workspace bytes; the stale case contains only the injected unrelated title/timestamp edit. Normal capture uses a bundled Mac-written neutral fixture; the blank test uses an empty QA root and the template test adds one synthetic styled template to the Mac fixture. No real workspace was read or written. `capture-roundtrip.json` and `capture-focused-roundtrip.json`. |
| Native capture and Calendar | **Passed:** first task in empty workspace, note/body/list/priority/existing-tag/No date, recognition removal, template protection, dirty Cancel, relaunch/Resume, failed save/Keep Editing, after-write confirmation, stale refusal, Week all-day visibility and Month overflow→Day | Validated native sheets and actual saved files. The template retains rich Unicode, checklist content with fresh step identity, custom recurrence and its end-anchored range. Calendar uses the focused date at local start of day. Capture defers rich authoring, existing-task schedules/lifecycle, template management and organization writes. No reference capture screenshot exists; this is a functional native adaptation. |
| Build identity | `capture-source-manifest.json` SHA-256 `4c4d624406e9f433179ae80399bcd92a5d4465597e8913bc7ea085b63e8970c4`; `capture-build-identity.json` contains binary map, full/focused source identities and original Desktop hash record | 124 source/test/script/project/resource files, excluding Markdown/user state. iOS launcher `0719c9ab840f0cf1a45b0ea62af9377b882522ad76e96bbf07e541692a5e67e8`; actual debug code `136265944c41933dd6459e3f2b315028a2ced377bfbd0af2f5f8c6ccb8112360`. Test-only corrections change the test inputs, not these app binaries. |

The simulator command was `xcodebuild -project Mobile/TaskovskyMobile.xcodeproj -scheme TaskovskyMobile -destination 'platform=iOS Simulator,id=ED2459ED-2E4D-4E78-8A2E-5628A303C444' -derivedDataPath /private/tmp/TaskovskyMobileEvidence-1109/CaptureFinalDerivedData -resultBundlePath /private/tmp/TaskovskyMobileEvidence-1109/capture-final.xcresult -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test`. The focused rerun used the same app build folder and only `testCaptureNoteWithListPriorityAndExistingTag` and `testCaptureRefusesArchivedMissingTargetsAndUnknownWorkspace`. The read-only audit accepts `--capture`; `--only-case` supports the focused note report. Both use explicit simulator QA UUIDs and the Mac fixture tool. Exact invocations are recorded with the evidence.

### Corrections and limits

The first native run passed four of seven cases. A saved Calendar item was hidden by the one-card all-day lane; hourly views now size the lane to the largest visible day's stack, and Month provides an overflow route to Day. Today uses the live session clock in normal launches. The template test scrolled down while its target was above; the corrected test scrolls up. Failed-save re-entry initially did not regain keyboard focus; explicit Keep Editing now focuses the retained title, and Retry remains available. The four-case fresh rerun passed those corrections plus removable recognition. One intermediate build hit SwiftUI type-check complexity; separating the recognition section and rebuilding in a fresh folder addressed that and a stale-module diagnostic.

The later full run's note test saved successfully but failed an overly strict pre-tap visibility assertion for the scrollable list picker. The focused rerun uses native auto-scroll and validates the same fields and durable outcome. The initial failures remain in the retained logs; screenshots cover the neutral capture form, date and recognition controls, styled template and failed-save states. The styled preview still shows an emoji fallback glyph; the underlying rich/UTF-16 data matches exactly in the file audit. These checks do not establish every date/time picker case, physical IME, VoiceOver, Dynamic Type, dark/RTL/rotation, long-content performance or reference visual parity. The pre-acknowledgment scratch debounce window is unchanged and unmeasured; recovery checks await the durable acknowledgment. The task UUID provides single-process idempotence; independent shared-file writes or purging the matching record before a retry are outside this contract. No permanent receipt ledger or schema migration was introduced.

`MobileCapture-2026-11-09.zip` and `mobile-capture-evidence/` are preserved under `/Users/mental/.codex/visualizations/2026/11/07/01a1b800-c122-7fd1-bbb3-0695744921b6/taskovsky-checkpoints/`. The earlier DesktopCalendar, MobilePrealpha and MobileEditing snapshots were not replaced. ZIP CRCs and source file hashes were verified; no Git metadata, personal workspace or deployment artifact is included.

<a id="mobile-task-lifecycle"></a>
## Shared task lifecycle on iPhone — November 9, 2026

The isolated mobile worktree is based on merged specification commit `6ee96eeb8f88e74a105c518de2202233ea528efa` and carries uncommitted changes on `codex/mobile-local-prealpha`. The desktop source matches all 98 entries of its sealed manifest. The change extracts the Mac graph commands into TaskLifecycle and connects the phone's Tasks rows and shared detail to the same rules. [MOB-LIFECYCLE-001](../changes/mobile-task-lifecycle-2026-11-09.md).

Mac verification used macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Phone verification used the owned iPhone 13 Pro simulator, iOS 26.3.1 (23D8133), UUID `ED2459ED-2E4D-4E78-8A2E-5628A303C444`. The tested debug binary targets iOS Simulator 17.0 with SDK 27.0.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **534 tests passed** and signed release verified | 451 Core, 8 Domain, 41 Workspace and 34 Swift Testing cases. The Core suite exercises the Mac facade with shared lifecycle, recurrence and Trash logic. Logs are `lifecycle-final-macos.log` and `lifecycle-macos-release.log`. Release SHA-256 `8194923c6cd9ac743636e7b92193bc8135c2674cc3f6f82b83675b4ea40e67da`. |
| Simulator | **79 distinct cases verified** | The full run passed 78 of 79 cases. The capture suggestion disappearance assertion failed before the settled UI state. Its focused rerun passed on the same app and shared binaries. Both summaries report zero runtime warnings and zero skipped cases. |
| New native checks | **6 lifecycle cases passed** | Separate row completion and Undo, pinned grouping after Won’t Do/reopen, archived movement, Trash Undo and relaunch restore, named purge confirmation with Cancel, and no success feedback on failed write. |
| File audit | **29 audits passed** and **28 fixtures reloaded through Mac TaskStore** | Two successor records form one tree. Completion and Trash use their persisted stamps. The separate Trash child stays deleted on restore. Purge removes one selected record and detaches survivors. Failed writes preserve raw bytes. The audit checks the earlier capture and edit cases as well. The focused capture file also passes its independent audit and reload. |
| Build identity | `lifecycle-source-manifest.json` SHA-256 `b64fa3390dad71a1e7df4c1f20e07dfb8792f48324fca87bcdfd33e01c3b502c` | The 125 entries cover source, tests, project, scripts and resources. `lifecycle-build-identity.json` records the full-run manifest and final manifest, the exact test-only change and app binaries. The simulator debug code SHA-256 is `c2cc5615eced5e17af335a5b065899283411104516a8253325f8043a1a2a606c`. |

The first lifecycle run passed the four repository cases plus native recurring completion and the failed-write case. Four native cases failed at navigation through the plain drawer rows. The row now gives its full width a hit area. The regression test waits for the drawer to dismiss. The capture regression waits for each ignored suggestion to disappear before proceeding. The final file audit independently confirms the resulting title, date and tags.

The phone uses a single task action sheet, a separate 44-point row target and a named system confirmation for Delete Forever. The Mac facade now publishes each graph mutation as a unit. Completion reopening uses one store save, and pristine successor matching checks exact title and body code units. Undo requires the revision that recorded the command. Explicit Reopen or Restore can apply from a later revision under the existing graph rules. Relaunch retains spawned records when the in-memory pristine snapshots are unavailable.

The Mac command was `swift test --disable-sandbox --manifest-cache local` with explicit writable module-cache paths. Release uses `./scripts/build-app.sh` and strict deep signature verification. The full simulator command uses the mobile project and scheme with the owned UUID, `LifecycleDerivedData`, disabled parallel testing, `-collect-test-diagnostics never` and `CODE_SIGNING_ALLOWED=NO`. The focused rerun selects `testCaptureRecognitionShowsRemovableCandidates`. Exact commands, logs, summaries and screenshots are saved with the checkpoint.

Phone lifecycle checks used Tasks rows and detail. Calendar reaches the same detail through source inspection. Calendar gesture editing, existing-task schedules and metadata, child editing, Board, Summary and organization remain open. Visual evidence covers the tested default appearance and simulator size. Physical device, VoiceOver, Dynamic Type, dark appearance and the remaining reference layout checks require separate evidence.

The source archive and compact evidence are under `taskovsky-checkpoints/MobileLifecycle-2026-11-09.zip` and `taskovsky-checkpoints/mobile-lifecycle-evidence/`. Archive CRCs and entry hashes were verified. The workspace format retains the same graph ledgers and settings files.

<a id="mobile-task-scheduling"></a>
## Existing-task scheduling on iPhone — November 9, 2026

The isolated worktree stays on `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. [The local scheduling change](../changes/mobile-task-scheduling-2026-11-09.md) adds the shared detail editor to Tasks and Calendar. The Mac facade and phone use the same default-reminder detection and series-position reconciliation. The phone repository owns the atomic write and guards against stale revisions and lossy round trips.

Mac verification used macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. The phone used the owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133). Its debug binary targets iOS Simulator 17.0 with SDK 27.0.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **538 tests passed** and signed release verified | 451 Core, 8 Domain, 45 Workspace and 34 Swift Testing. The new regressions cover an exact-byte no-op with fractional endpoints and rolled recurrence, a due-date rebase, DST zone conversion and reminder provenance, scoped removal, stale/invalid/failed writes and an explicit custom-rule restart. Release SHA-256 `cb593ddd1e84591f19296378b42084b11aad4c8be3681c373cea8ae00e9372f9`. |
| Scheduling workflows | **Five focused simulator cases and five independent Mac reloads passed** | Calendar date save and relaunch, nested and outer Cancel, custom repeat and staged removal, New York zone selection with a timed window and manual reminder, failed write retaining the draft. The file audit checked each owned field, all unrelated tasks and unchanged settings. |
| Full simulator | **88 tests passed** | 53 shared contracts and 35 native UI cases, with zero skips, failures or reported runtime warnings. |
| Full file audit | **34 file audits and 33 Mac reloads passed** | The unknown-data refusal keeps its original bytes and skips Mac reload. Supported files reopen without writes, including the three persisted schedule outcomes. |
| Build identity | `schedule-source-manifest.json` SHA-256 `d612cb9ca31868d9214502fc186b8a393a01d934abbb3707d728dc8ad042e4ff` | The 127 entries include project, sources, tests, scripts and resources. The simulator app SHA-256 is `a62f6bc7aacc70332ae74808424d4517afd316156d87d67c2d1de98a20345a50`. The evidence records the tested app and test-bundle digests. |

The first simulator invocation used the wrong test target name and ran no cases. A later date persistence test searched the Today list after moving its fixture to tomorrow. It now reopens Calendar after relaunch. The zone test first tapped the center of the reminder row and left its switch enabled. The corrected test taps the switch itself and checks its state before adding a reminder.

A valid custom rule that is opened and saved without changes keeps its saved representation and position. The simulator exercised daily custom rule creation and cancellation. The other custom patterns use the existing shared rule engine and still need focused native field-by-field checks. Direct Calendar moves and resize, Calendar Arrange, device notification delivery and physical-device accessibility remain open. External calendar integrations stay deferred in the parity record.

The source archive is `taskovsky-checkpoints/MobileSchedule-2026-11-09.zip`. Compact evidence includes the Mac build and test logs, simulator summaries, neutral screenshots and QA audit results. The Mac desktop source still matches its 98-entry sealed manifest. A separate live recheck of an older Desktop QA bundle verified input, Month scrolling and window reflow. The old bundle used regular app settings and saved Month over the observed Week view. The workspace file modification time predates the recheck. The desktop evidence records the settings incident and restoration status.

<a id="mobile-calendar-arrange"></a>
## Calendar Arrange and direct scheduling on iPhone — November 9, 2026

The isolated worktree is `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The [Arrange change](../changes/mobile-calendar-arrange-2026-11-09.md) ports Calendar scheduling, grouping and scoped Undo. The original Desktop worktree is checked independently against its 98-entry source manifest.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **540 tests passed** and signed release verified | 451 Core, 8 Domain, 47 Workspace and 34 Swift Testing. Shared Calendar tests check a fractional range move with shifted manual reminders, nominal cadence, exact no-op, revision refusal and Undo that preserves an unrelated title but refuses a later status change. Release SHA-256 `92a7a64a5f27df1d0b9fa8368e06ae1733266bb4f01c1d53ff1db6e022b3fa61`. |
| Native Calendar | **Five Arrange and direct edit cases passed** | Scope, overdue inclusion, priority grouping, Cancel and focused-day save through relaunch. Card removal and Undo. Hourly drop creates a snapped 30-minute timed range. Month drop retains an all-day date. The timed resize saves the intended 30-minute extension. |
| Full simulator | **95 tests passed** with zero skips and one UIKit runtime warning | 55 shared contracts and 40 native UI cases on the full-suite build. The warning occurred while opening Calendar actions. The follow-up replaces the system menu with the Calendar view picker's popover pattern. |
| Final popover verification | **Eight simulator cases and eight Mac reloads passed** | No warnings, skips or failures. The focused run covers Arrange and relaunch, removal/Undo, source filters, Hour and Month drag, timed resize, all seven modes and task-detail date editing from Calendar. Each final fixture passes its exact file audit. |
| Full file audit | **39 fixtures passed and 38 Mac reloads passed** | The unknown-data fixture stayed byte-identical and skipped Mac reload. All five new Calendar fixtures reopened without writes. |
| Source identity | `arrange-source-manifest.json` SHA-256 `5510aab21f0de8f3aa43c47a5662047df062f02511151dd1c9f20433d89d2530` | The 129 final inputs differ from the full-suite manifest `8a04647fee4d7988cac6dfb7fb21608c63815122a8d73be18c6c7b6cd9ed79eb` only in the Calendar actions presentation in TaskovskyMobileApp.swift. Final simulator debug code SHA-256 `c882737c84b50c7b42907034b85c1fb88ca7f9104aff6fb2eeb8c32ed5afbd71`. The evidence separates the launcher from the code library. |

The first native run encountered repeated animation-idle waits when the same touch surface handled drag and the context menu. A separate visible grip allowed both workflows to complete. The subsequent UI run reported a successful resize, but the persisted file showed a 15-minute change from a 30-minute gesture. The final build measures the drag in a fixed coordinate space so the moving handle does not change the measurement. The persisted range now ends exactly 30 minutes later and keeps its start. The file audit independently checks the changed due date and automatic reminder.

Verification uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a), Swift 6.4 and the owned iPhone 13 Pro simulator with iOS 26.3.1 (23D8133). The app targets iOS 17.0. The Mac release uses local ad hoc signing. Simulator tests use fresh Debug UUID fixtures and disabled parallel execution. App settings files are outside the Calendar write scope.

Arrange uses a sheet with staged placement. Card dragging stays inside the same phone Calendar session. Timed resize handles are available on sufficiently tall final segments. The card menu and named accessibility actions cover other supported shapes. Additional gesture combinations, dense target sizing, VoiceOver, Dynamic Type, physical devices, advanced Calendar display controls and reference-matched visuals require separate verification. External calendar integrations remain deferred in the parity record.

The uncommitted source archive is `taskovsky-checkpoints/MobileCalendarArrange-2026-11-09.zip`. The companion evidence includes both simulator summaries, fixture audit reports, build manifests, the isolated popover diff and neutral screenshots. All 98 Desktop source inputs still match their sealed manifest.

<a id="mobile-calendar-preferences"></a>
## Calendar view preferences on iPhone — November 9, 2026

The isolated checkout is `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The [Calendar preference change](../changes/mobile-calendar-preferences-2026-11-09.md) separates writes to the Calendar options object from task transactions. Original workspace bytes and every byte outside the settings object's Calendar value are checked independently.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **543 tests passed** and signed release verified | 451 Core, 8 Domain, 50 Workspace and 34 Swift Testing. New contracts cover sparse and legacy settings, absent Calendar objects, exact adjacent bytes, no-op, stale edits, unknown values, duplicate keys, failed replacement and confirmation after a write reports an error. Release SHA-256 `92a7a64a5f27df1d0b9fa8368e06ae1733266bb4f01c1d53ff1db6e022b3fa61`. |
| Focused simulator and file audit | **Five native preference/navigation cases and five Mac reloads passed** | Saved filters and All reset, seven modes, appearance and visibility, named ruler staging/capacity and failed preference save. The initial full-contract focused run passed 63 cases with no runtime warnings. |
| Full simulator | **101 tests passed** | 58 shared contracts and 43 native cases. Zero failures, skips or runtime warnings. The final build also checks temporary mode navigation when a save fails and recovery of the prior saved mode on relaunch. |
| Full file audit | **42 fixture audits and 41 Mac reloads passed** | Nine cases changed saved settings within the Calendar value. Unrelated setting bytes match the start of each session. Task writes remain independently scoped. Unknown task data stays byte-identical and skips Mac reload. |
| Source identity | `prefs-source-manifest.json` SHA-256 `a489dc8c368cc1c894d479b48defe07cb27208a7524abe59dbbe56a3af47f377` | 131 build/test inputs. Final simulator debug code SHA-256 `4830497a6286502b059f1dbe30d69e6a4289cac9ad0721be8451b9919c764db9`. The build record separately identifies the launcher, code library and test bundles. |

The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Simulator evidence uses the isolated iPhone 13 Pro on iOS 26.3.1 (23D8133). The app targets iOS 17.0. Native tests use UUID-owned Debug fixtures, and the audit reopens eligible cases through Mac TaskStore without writes.

Mode is saved on an explicit view change. Filter and View Options sheets save on Done, and the nested zone editor changes only the outer draft until that save. Source controls stay in a phone sheet, and the stored Mac sidebar value passes through. Focus date and Arrange remain session state. Rulers use the first displayed day for conversions, matching the current Mac rule. The settings file audit allows the documented legacy first-zone alias when rulers are shown and checks exact bytes outside Calendar options.

The native checks verify named ruler search, nested Cancel, the four-ruler limit, and persistence across relaunch. Reordering and removing rulers, every range endpoint, cross-column DST presentation, physical devices, Dynamic Type and VoiceOver require separate native checks. External calendar integrations remain deferred in the parity record.

The uncommitted source archive is `taskovsky-checkpoints/MobileCalendarPreferences-2026-11-09.zip`. The companion evidence includes the Mac and simulator results, preference and task file audits, build identity, and neutral screenshots. The original Desktop checkout still matches all 98 sealed source inputs.

<a id="mobile-rich-description-preview"></a>
## Rich description preview on iPhone — November 9, 2026

The isolated mobile checkout is `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The [rich description change](../changes/mobile-rich-description-preview-2026-11-09.md) projects known inline runs and paragraph decorations without changing their stored UTF-16 text. Task and note detail and protected template capture use the native preview.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **545 tests passed** and signed release verified | 451 Core, 10 Domain, 50 Workspace and 34 Swift Testing. New projection cases check exact decomposed text and emoji code units, numbered-group reset, headings, quote/checklist/rule decorations, mirrored-text mismatch, overflow and split surrogate pairs. Release SHA-256 `1a1fe35c013b8ea888d2461ee5334d09bcd8a870fd6d03149176bfffcb6c0473`. |
| Focused simulator and file audit | **65 cases passed**, including five native flows and five Mac reloads | Styled description, compound formatting through title edit and relaunch, malformed fallback, Mac-authored styled task title edit and protected template instantiation. The focused run reported zero failures, skips or runtime warnings. |
| Full simulator | **105 tests passed** | 60 shared contracts and 45 native cases. Zero skips, failures or runtime warnings. |
| Full file audit | **44 fixture audits and 43 Mac reloads passed** | The compound rich title edit changed only title and modification time. The malformed case was byte-identical. The unknown workspace case preserved its bytes and skipped Mac reload. |
| Dark appearance | **One focused case and one Mac reload passed** | Same tested app binary. The dark screenshot shows the same decorations, selection surface and contrast-dependent styles. The owned simulator returned to its original light appearance. |
| Source identity | `rich-preview-source-manifest.json` SHA-256 `a14430cadda9b1e723436082ce5de078aeac80aff0535f181e2b9dc325d38cf7` | 133 final source, resource and test inputs. Final simulator debug code SHA-256 `b3b39d93a3c258d0cf903dbb327faefba0148c88984274d1c1e5f448ce4ca917`. The Mac and simulator builds are independently identified. |

The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Phone evidence uses an owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133), with the app targeting iOS 17.0. The audit includes the existing Mac-written styled task fixture, a compound neutral fixture generated by the shared model, and a malformed-range variant. Mac TaskStore reopens the compound fixture and compares it to the expected description, inline and block values.

The compound screenshot shows heading, underline, highlight, inline code and strike, two numbered paragraphs, a quote, a bullet, a checked rich paragraph, a rule and a link. The simulator displays the puzzle emoji as a missing glyph in the earlier SwiftUI plain preview and the new UIKit preview. Both the native text value and file audit retain its exact code units. The preview leaves the styled body read-only. Clipboard, link activation, mixed-direction layout, VoiceOver, physical-device behavior and styled authoring have separate verification gates.

The uncommitted source archive is `taskovsky-checkpoints/MobileRichDescriptionPreview-2026-11-09.zip`. The companion evidence includes light and dark previews, the earlier plain screenshot for the simulator glyph comparison, and the full fixture audits. All 98 original Desktop source inputs still match their sealed manifest.

<a id="mobile-task-metadata"></a>
## Task priority, tags and checklists on iPhone — November 9, 2026

The [metadata change](../changes/mobile-task-metadata-checklists-2026-11-09.md) runs in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. Existing tasks can set priority, select existing tags and edit embedded checklist items. The repository applies revision-checked changes to the owned fields and modification time.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **548 tests passed** and signed release verified | 451 Core, 10 Domain, 53 Workspace and 34 Swift Testing. The new cases cover scoped writes, unavailable tag retention, exact checklist text and order, archive and identity guards, stale revision and confirmation after a reported write failure. Release SHA-256 `2e1a594596f3e9b42e920b55bf229deaa2efa4697d756a007c36439ee5ba2387`. |
| Focused discard | **One native test and one Mac reload passed** | Keep Editing retains typed text. Discard restores the saved checklist view, with unchanged workspace and settings bytes. |
| Full simulator | **112 tests passed** | 63 shared contracts and 49 native cases. No failures, skips or runtime warnings. New native cases verify priority and tag persistence after relaunch, checklist check/rename/add/remove and Calendar display, Discard and retention of a failed draft. |
| Full file audit | **48 fixture audits and 47 Mac reloads passed** | Metadata writes preserve the exact description, linked subtask, schedule and unrelated records. The checklist visibility case changes only the expected Calendar setting. The unknown workspace retains its bytes and skips Mac reload. |
| Dark appearance | **One checklist workflow and one Mac reload passed** | The same app binary saved the checklist and showed it in Calendar. The simulator returned to its original light appearance. The screenshot retains the previously observed missing puzzle glyph. |
| Source identity | `metadata-source-manifest.json` SHA-256 `d2813e584468360a399d82e58ee5f7ff86d8a42d34539f092050f54aa176ede5` | 135 source, resource and test inputs. Simulator debug code SHA-256 `ae731c951aba0accf5d186337f918c7c7a24f0acd078627c4d5d400c622d7348`. |

The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Native checks use an owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133). The app targets iOS 17.0.

Tag and checklist drafts live in the open sheet. The new tests use isolated neutral samples with a styled description, linked subtask and unavailable saved tag. Checklist order is exercised at the file contract. Native reorder gestures, physical-device input, Dynamic Type and VoiceOver have separate verification gates.

The uncommitted source archive is `taskovsky-checkpoints/MobileTaskMetadata-2026-11-09.zip`. Its companion evidence includes the file audits, build identity, test results and neutral screenshots. The 98 original Desktop source inputs still match their sealed manifest.

<a id="mobile-task-hierarchy"></a>
## Linked subtasks on iPhone — November 9, 2026

The [hierarchy change](../changes/mobile-task-hierarchy-2026-11-09.md) runs in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. Task detail can add and complete a child, open either side of a parent link, move a subtree and detach a child. The phone uses the existing local task record and the graph operations shared with Mac TaskStore.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **550 tests passed** and signed release verified | 451 Core, 10 Domain, 55 Workspace and 34 Swift Testing. The new cases cover insertion preference, child identity and exact title, write-after-replacement confirmation, refusals, whole-subtree move including a trashed descendant and a byte-stable no-op. Release SHA-256 `21a6ec6cdfaebe15f39b62e509792ef4230676b7d70d5c4a3ebae7f7c048f1da`. |
| Focused simulator | **Nine tests and three Mac fixture reloads passed** | Six workspace contracts and three native flows. The phone creates and completes a child independently, excludes descendants from the parent picker, moves a subtree across lists, reloads, discards and detaches. |
| Simulator regression | **116 of 117 passed in the full run, and the corrected case passed on rerun** | The Trash test's sheet-wide badge lookup found the independently trashed child after restoring the parent. The corrected test checks parent editability, opens the still-trashed child and checks that its detail stays locked. The rerun used identical app code. Both runs reported zero skips and runtime warnings. |
| File audit | **51 fixture audits and 50 Mac reloads passed** | The unknown workspace retained its bytes. The corrected Trash case also passed a separate file comparison and Mac reload. |
| Source identity | `hierarchy-source-manifest.json` SHA-256 `57303d6ce681ab987edce2a6d697f463c53c2412c5fb51c29137557af2434a46` | 136 source, resource and test inputs. Only the UI test source changed after the full run. Simulator debug code SHA-256 `f57b3df255796a32647f80e47f8b21d0416f666efbd13ecb81f546d8c39ed860` in both runs. |

Native evidence uses the owned iPhone 13 Pro on iOS 26.3.1 (23D8133). The app targets iOS 17.0. The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. File comparisons use UUID-isolated samples and check the saved parent, direct child and relocated subtree through Mac TaskStore.

The phone lists open parent candidates. It stages changes in the open sheet and previews cross-list moves. Row indentation is capped at four levels to leave room for titles on narrow screens. The underlying links and navigation retain deeper levels. Native physical-device, VoiceOver and Dynamic Type checks remain open.

The uncommitted source archive is `taskovsky-checkpoints/MobileTaskHierarchy-2026-11-09.zip`. Its companion evidence records both simulator runs, file comparisons, build identity and neutral screenshots. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-list-organization"></a>
## Lists and folders on iPhone — November 9, 2026

The [list and folder change](../changes/mobile-list-organization-2026-11-09.md) runs in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. Desktop and the phone use shared list duplication, deletion, ungrouping and reorder operations. The phone also stages edits in revision-checked forms.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **553 tests passed** and signed release verified | 451 Core, 10 Domain, 58 Workspace and 34 Swift Testing. The new cases cover revision, compatibility and validation refusal, exact no-op, list/folder moves, Board value preservation, list copy identity, filter retention and confirmation after replacement. Release SHA-256 `c8cff823780098509deec0e710f296dca8fed67e51f2d48488baf2c67ef44cf1`. |
| Focused checks | **Four native workflows and four Mac reloads passed across focused runs** | Folder ordering, naming, placement, collapse/expand, ungroup and relaunch passed on the final build. The first build also passed archive/exclusion, copy/delete and write-failure cases. |
| Full simulator | **124 tests passed** | 68 shared contracts and 56 native workflows. No failures, skips or runtime warnings. All four organization workflows passed on the final build. |
| Full file audit | **55 fixture audits and 54 Mac reloads passed** | Confirmed ungrouping kept both lists, archiving and unarchiving preserved tasks, copying remapped the hierarchy, and deleting moved originals to Inbox while retaining the missing-list filter. Unknown workspace data retained its bytes and skipped Mac reload. |
| Dark appearance | **One folder workflow and one Mac reload passed** | Folder reorder, editing, drawer expansion, ungroup and relaunch used the same simulator build. The simulator returned to its original light appearance. |
| Source identity | `organization-source-manifest.json` SHA-256 `de9fdb8c0aaa93f932bdaff8f05830632ee4b1bf1d945214c09f13c9a72557b1` | 138 source, resource and test inputs. Simulator debug code SHA-256 `ee497df63cb06e432bc55e7357da7e7473b6212fcf25c44f8ee2207dda9c2ac7`. |

Native checks use the owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133). The app targets iOS 17.0. The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Changes run against disposable UUID-isolated workspaces.

Folder expansion and unsaved forms live in the phone session. Reorder moves within an active group, while the placement picker moves between groups. The phone preserves the stored Board value and displays tasks in the list interface. VoiceOver, Dynamic Type and physical-device checks remain open.

The uncommitted source archive is `taskovsky-checkpoints/MobileListOrganization-2026-11-09.zip`. The companion evidence records the full and focused results, fixture comparisons, build identity, and light and dark screenshots. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-smart-lists"></a>
## Smart List visibility and order on iPhone — November 9, 2026

The [Smart List change](../changes/mobile-smart-lists-2026-11-09.md) runs in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The drawer uses saved top, history, Tags and Filters preferences. The settings sheet saves selected visibility and within-group order on Done.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **556 tests passed** and signed release verified | 451 Core, 10 Domain, 61 Workspace and 34 Swift Testing. Three new cases cover byte-scoped writes, sparse settings, rejection of duplicate visibility keys, stale and unchanged saves, and confirmation after replacement. Release SHA-256 `c013d487df9d226ff5f9a6cf9a702cc2d446c57aa9a963e5f0368d722fc39c9a`. |
| Focused simulator | **32 tests and two Mac reloads passed** | Two native workflows verify staged Cancel, visibility, grouped reorder, fallback, relaunch and failed-save draft retention. Zero skips, failures or runtime warnings. |
| Full simulator | **129 tests passed** | 71 shared contracts and 58 native workflows. Zero skips, failures or runtime warnings. |
| Full file audit | **57 fixture audits and 56 Mac reloads passed** | Smart List edits leave Calendar and other preference bytes and the workspace file intact. The unknown-workspace case retains its bytes and skips Mac reload. |
| Dark appearance | **One Smart List workflow and one Mac reload passed** | The same simulator build verified order and visibility after relaunch. The simulator returned to its original light appearance. |
| Source identity | `smart-lists-source-manifest.json` SHA-256 `e5bca05b03ded796f88adabae972013a939146651e87afc11691b50ba4bdb711` | 139 source, resource and test inputs. Simulator debug code SHA-256 `47708a8545df538abdce68a93ee9aed9aca16eb74b56f30c2f3b078a060d7c5d`. |

The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Native checks use the owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133), with an iOS 17.0 deployment target. The scoped settings audit compares the exact bytes outside the edited members and checks workspace bytes unchanged.

The Summary report and its phone controls remain open, and its saved visibility value is retained. Smart List settings drafts live in the open form. VoiceOver, Dynamic Type and physical-device checks remain separate.

The Desktop drawer uses the same group keys and visibility cases as before, now through the shared value rules. Its layout and interaction code remain platform-specific. The evidence for the Desktop adapter in this slice is the Mac regression suite, release verification and source comparison. Native UI evidence is from the iPhone simulator.

The uncommitted source archive is `taskovsky-checkpoints/MobileSmartLists-2026-11-09.zip`. Its companion evidence includes native light and dark screenshots, result summaries and file checks. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-saved-filters"></a>
## Saved filter authoring on iPhone — November 9, 2026

The [saved filter change](../changes/mobile-saved-filters-2026-11-09.md) runs in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The phone's own filter manager and editors use the Desktop filter model, predicates and rule transformations.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **558 tests passed** and signed release verified | 451 Core, 10 Domain, 63 Workspace and 34 Swift Testing. Two added cases cover an exact advanced rename, unavailable IDs, unchanged and stale commands, custom-bound validation and confirmation after replacement. Release SHA-256 `229ac585cc354698abbe3cbde2443adc26385ae56363efc0341fd133bf20b442`. |
| Focused simulator | **36 tests and four Mac reloads passed** | Normal creation, pin, match and deletion. Nested Advanced AND/OR authoring and relaunch. Canceling mode replacement and renaming a filter with unavailable list and negated tag references. Failed-save draft retention. Zero skips, failures or runtime warnings. |
| Full simulator | **135 tests passed** | 73 shared contracts and 62 native workflows. Zero skips, failures or runtime warnings. |
| Full file audit | **61 fixture audits and 60 Mac reloads passed** | Checked the nested rule tree and unrelated data, retained references, the create/delete cycle and exact failed-save bytes. The unknown-workspace fixture retains its bytes and skips Mac reload. |
| Dark appearance | **One nested Advanced workflow and one Mac reload passed** | The same simulator build authored and reopened the rule. The simulator returned to its original light appearance. |
| Source identity | `saved-filters-source-manifest.json` SHA-256 `7f556953049d4c7e281044921760a752a7cc3d15abcaa022ab13b6eabc370455` | 141 source, resource and test inputs. Simulator debug code SHA-256 `d25bbed165917c449ca97ce2c0b50799b33c1962a2f4adb63d55a11cc03839d5`. |

The Mac host uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Native checks use the owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133), with iOS 17.0 as the deployment target. The file comparison checks the exact saved tree and original settings. Mac TaskStore reopens the fixtures and evaluates the saved filters.

Native evidence covers the workflows above. Every combination of date, status and entity conditions has separate coverage needs, as do VoiceOver, Dynamic Type and physical devices. Filter drafts live in the open form. Calendar sources retain their own list/tag selector.

The uncommitted source archive is `taskovsky-checkpoints/MobileSavedFilters-2026-11-09.zip`. Its companion evidence includes the focused and full simulator results, exact fixture checks, build identity, and light and dark screenshots. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-tag-management"></a>
## Tag management on iPhone — November 9, 2026

The [tag management change](../changes/mobile-tag-management-2026-11-09.md) runs in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The phone owns its tag forms and drawer controls and shares the hierarchy and reference rules with Desktop.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac | **563 tests passed** and signed release verified | 451 Core, 10 Domain, 68 Workspace and 34 Swift Testing. New cases cover interrupted paired writes, merge into a descendant, unavailable filter rules, post-replacement confirmation, preserving unexpected bytes and blocking writes until journal cleanup. Release SHA-256 `82d8930223c8ed37007e9bcff62398f4e645c9f16b5d92c4adf21f091f27a2dc`. |
| Focused simulator | **41 tests and four Mac reloads passed** | 37 shared workspace contracts and four native tag workflows. Nested creation, pinning, drawer disclosure and task assignment; sibling reorder, canceled edit, reparent and relaunch; descendant merge and filter reload; delete with a retained filter. Zero skips, failures or runtime warnings. |
| Full simulator | **144 tests passed** | 78 shared contracts and 66 native workflows. Zero skips, failures or runtime warnings. |
| Full file audit | **65 fixture audits and 64 Mac reloads passed** | Exact comparisons covered sibling order, hierarchy, task and template memberships, saved rules, timestamps and default-tag settings. The unknown-workspace fixture retains its bytes and skips Mac reload. |
| Dark appearance | **One tag workflow and one Mac reload passed** | The same simulator build reordered siblings, discarded a rename, saved a new name and parent, then reopened the tag. The simulator returned to light appearance. |
| Source identity | `tags-source-manifest.json` SHA-256 `0f8b79d0341e473cc02b10fd0b88635909a742db3bb176508a7a501f5bf0b38c` | 143 source, resource and test inputs. Simulator debug code SHA-256 `fee6c06f4ab2962d4b6650262cdc22b17c07bb3dda949e8f6ede065eee658ef7`. |

Mac testing uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Native testing uses the owned iPhone 13 Pro simulator on iOS 26.3.1 (23D8133). The deployment target remains iOS 17.0.

Tag form drafts live in the open editor. Native verification did not exercise changing the color, VoiceOver, Dynamic Type or a physical device.

The uncommitted source archive is `taskovsky-checkpoints/MobileTagManagement-2026-11-09.zip`. Its companion evidence includes the focused and full results, exact file checks, build identity and light and dark screenshots. All 98 sealed inputs of the original Desktop checkout still match.

<a id="nested-filter-layout"></a>
## Board and separate nested-filter layouts — November 9, 2026

The [iPhone Board](../changes/mobile-board-2026-11-09.md) and [nested filter layout](../changes/nested-filter-layout-2026-11-09.md) run in the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac tests and release | **565 tests passed** and release signature verified | 451 Core, 10 Domain, 70 Workspace and 34 Swift Testing. New Board contracts cover per-list scope and recurring completion from Won’t Do with Undo. Release SHA-256 `0669a707bc5c3525e2720b44c9e3b0ad66938d81ecafd9e2d23b72dd5d9538d5`. |
| Native Mac editor | **Passed** | Disposable fixture with AND, OR and NOT. Converted OR to AND, unwrapped NOT, added and removed a deeper group, and dismissed with Escape. The files kept their checksums. A keyboard rename and Save changed only the filter name. A separate reopen preserved the exact rule and unavailable tag without writing either file. |
| Native Mac appearance | **Light and dark captured** | The standard release produced the light and reopened screenshots. The guarded dark QA build adds only `.preferredColorScheme(.dark)` to the root view. Its files matched after close. |
| First Board simulator run | **Four workflows and four Mac reloads passed** | Per-list mode persisted through relaunch, archived completed-only board remained read-only, drag rejected a note and moved a task, and recurring completion from Won’t Do could be undone. |
| Initial combined simulator run | **150 tests, 69 fixture audits and 68 Mac reloads passed** | The first filter layout build produced one UIKit warning when opening the first Add menu. The iPhone structural actions were moved to native action sheets. |
| Final focused simulator | **47 tests and eight Mac reloads passed** | Four filter workflows, four Board workflows and 39 shared contracts. Zero skips, failures or runtime warnings. |
| Compact iPhone | **One nested workflow and one Mac reload passed** | iPhone SE (3rd generation), 375-point screen. The same app code exercised deep groups, action sheets, keyword editing, keyboard dismissal and saved results. Zero runtime warnings. The disposable simulator was removed. |
| Final full simulator | **150 tests passed** | 80 shared contracts and 70 native workflows. Zero skips, failures or runtime warnings. |
| Final file audit | **69 fixture audits and 68 Mac reloads passed** | Exact comparisons cover saved filter rules, unavailable references, Board mode scope, archived no-op, drag and recurring Undo. The unknown-workspace fixture retains its bytes and skips Mac reload. |
| Final iPhone dark appearance | **One nested workflow and one Mac reload passed** | Zero runtime warnings. The original light appearance was restored. |
| Source identity | `filter-layout-source-manifest.json` SHA-256 `a5c7ee88facf7e2ee5bb7b97e3be93b61e27ef9cbdb628f3c13c97070cf0ab9d` | 144 inputs. Simulator debug code SHA-256 `a5008140dc85fdeab1e77e583df374451ea89b8cbb02769f8f610259345a63ec`. |

Mac testing uses macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. iPhone testing uses iOS 26.3.1 (23D8133) on disposable iPhone 13 Pro and iPhone SE (3rd generation) simulators. The app targets iOS 17.0.

An initial baseline Mac launch showed the regular workspace and was closed before editing. The two regular files had modification times predating the launch. Their first hashes were taken after that launch and matched again after guarded testing. Subsequent QA launchers required both disposable files and always supplied their absolute paths. Each launcher exited without opening the app when either file was missing. The isolation evidence records the actual process arguments, file checksums and the timing of the checks.

The native checks cover the recorded workflows. VoiceOver, Dynamic Type and physical-device checks remain open.

The uncommitted source archive is `taskovsky-checkpoints/BoardAndFilterLayout-2026-11-09.zip`. Companion evidence includes matched Mac before and after captures, iPhone before and after captures, compact and dark screenshots, and isolation and reload reports. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-summary"></a>
## Editable local Summary — November 9, 2026

The [Summary implementation](../changes/mobile-summary-2026-11-09.md) uses the same report generator on Mac and iPhone. The native editors keep separate UI and draft state. This checkpoint uses the isolated `codex/mobile-local-prealpha` checkout at base `6ee96eeb8f88e74a105c518de2202233ea528efa`.

| Check | Result | Coverage |
| --- | --- | --- |
| Time zone reproduction and regression | **Reproduced and fixed** | At 11:30 UTC on November 9, the report selected November 10 in Pacific/Kiritimati while the Moscow test host printed November 9 in the range and heading. The fixed generator uses the report calendar for the range, date headings and due fields without an explicit task time zone. The same test verifies that a New York task retains its local due time and zone abbreviation. Four focused Summary contracts passed on Mac. |
| Guarded native Mac Summary | **Passed on the initial build** | All Lists excluded the archived completed fixture. An explicit archived list selection included it. Regeneration and saving an edited report left settings and all existing records intact. The new Inbox note preserved the exact UTF-8 text, including a decomposed accent and emoji, and had no schedule, priority or tags. The launcher refused to open when either disposable file was missing. |
| Final Mac tests and release | **569 tests passed** and release signature verified | 451 Core, 14 Domain, 70 Workspace and 34 Swift Testing. Release executable SHA-256 `e421bb87272fc90cd1673025713ba02632f985b0ad1bd6a711ef4652d8d0ccf6`. |
| Original full iPhone | **153 passed of 155** | Two existing native tests failed. The advanced-filter test checked for the NOT heading immediately after wrapping. It passed on a same-build rerun. The Smart List save error was below the visible rows. All 71 fixture audits and 70 Mac reloads passed. |
| Time zone build | **16 focused tests and two Mac reloads passed** | Fourteen shared Domain contracts and both native Summary workflows. Its full suite passed 155 of 156 and reproduced the Smart List error visibility problem. All 71 fixture audits and 70 Mac reloads passed. |
| Final focused iPhone | **22 tests and eight Mac reloads passed** | Fourteen shared Domain contracts and eight native Summary, Smart List and saved-filter workflows. The Smart List error stays visible above the scrolling rows, and the saved-filter test waits for the NOT heading and checks its label. Summary checks cover filters and cancellation, regeneration, Copy feedback, exact-text Inbox save and reopen, and recovery after a failed write and relaunch. |
| Final full iPhone | **156 tests, 71 fixture audits and 70 Mac reloads passed** | 84 shared contracts and 72 native cases. The unknown-workspace fixture preserved its bytes and skipped Mac reload. No failures, skips or runtime warnings. |
| iPhone dark appearance | **One native Summary workflow and one Mac reload passed on the initial and final builds** | Generated and edited the report and saved the exact text as a note. The original light appearance was restored. Disposable acceptance devices were removed after evidence export. |
| Final source identity | `summary-acceptance-source-manifest.json` SHA-256 `acc8b64f73ce040c657964575d738050ba9a455505fd8cf62a1c9a2d21398e83` | 146 inputs. The initial, time zone and acceptance manifests and build records preserve the exact source and binary identity of each run. The acceptance build changes the Smart List error placement and the NOT assertion. The Mac release inputs match the time zone build. |

Mac testing used macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. iPhone testing used disposable iPhone 13 Pro simulators with iOS 26.3.1 (23D8133). The app targets iOS 17.0.

The iPhone Copy check verified UI feedback. The file audit compared the edited report to the saved note byte for byte. Freeform report edits live in the open report. Recoverable drafts cover Save as Note. Physical-device, VoiceOver and Dynamic Type checks remain open. External integrations remain deferred.

The uncommitted source archive is `taskovsky-checkpoints/MobileSummary-2026-11-09.zip`. The companion evidence includes the failing and passing time zone test, separate build identities, full fixture audits and native screenshots. All 98 sealed inputs in the original Desktop checkout still match.

<a id="mobile-search"></a>
## Local Search and saved queries — November 9, 2026

The [iPhone Search implementation](../changes/mobile-search-2026-11-09.md) uses the Mac full-search task rules with a native criteria sheet, organization links and local history. The work is on `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`.

| Check | Result | Coverage |
| --- | --- | --- |
| Initial focused test | **Three passed of four** | The first related-task test expected a Back button after the parent link had already returned to the starting task. The corrected test checks the child Back action and parent link separately and verifies the query after closing the task. |
| Final focused iPhone | **Four tests and four Mac reloads passed** | Title, body and embedded-step matches, task and note results, Trash exclusion, default and explicit archive scope, related-task navigation, distinct list/tag/filter routes, staged criteria cancellation, history deduplication and clearing, and Save as Filter after relaunch. |
| Final full iPhone | **159 tests passed** | 84 shared and 75 native tests. Zero failures, skips or runtime warnings. |
| File audit | **74 fixture checks and 73 Mac reloads passed** | The unknown-workspace fixture retains its bytes and skips Mac reload. Search-only workflows preserved workspace and settings bytes. Saving a search added one filter with its exact query, status and explicit archived-list selection. Mac Taskovsky resolved the saved filter to the expected archived task without writing either file. |
| Dark appearance | **One native workflow and one Mac reload passed** | The checklist search and organization routing workflow ran again in dark appearance. The owned simulator returned to light appearance before removal. |
| Mac tests and build | **569 tests passed and release signature verified** | The Search change leaves Mac app source as in the Summary checkpoint. The Mac fixture helper separately verifies saved search criteria. Release executable SHA-256 `50a5e9ded7f8451342a8edd02fd8098b06cc61c702471d48d2734dc33eab4a43`. |
| Source identity | **147 inputs verified** | `search-final-source-manifest.json` SHA-256 `963deb063066fff613d4bcd120ac728e015a0d8b6ceb42ed7e7b21c012324235`. Eight inputs differ from the sealed Summary checkpoint. |

Mac tests ran on macOS 27.0.1 ARM64 with Xcode 27.0 (27A266a) and Swift 6.4. The iPhone simulator was an owned iPhone 13 Pro on iOS 26.3.1 (23D8133). Search history uses device-local preferences and a separate key for each QA session. The native history case verifies deduplication, clearing and relaunch. The ten-entry cap follows the implementation. Reference visual matching, physical-device, VoiceOver and Dynamic Type remain open.

The uncommitted source archive is `taskovsky-checkpoints/MobileSearch-2026-11-09.zip`. Its companion evidence includes light and dark screenshots, exact build checksums, and the initial and final results. All 98 sealed Desktop inputs still match. External search remains deferred.

<a id="mobile-templates"></a>
## Local Templates and Mac edit preservation — November 9, 2026

The [Templates implementation](../changes/mobile-templates-2026-11-09.md) is on `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`.

| Check | Result | Coverage |
| --- | --- | --- |
| Mac tests and release | **571 tests passed and release signature verified** | The focused storage tests cover an unchanged save, a protected styled body, an explicit Mac body replacement, invalid and stale writes, hierarchy, copied checklist identities and schedule reconciliation. Release executable SHA-256 `c1a40441fa8a87adc022c8e61c0c1791c97e3ba1e4fe5eed7fa309b2f457b1fd`. |
| Guarded Mac editor | **Cancel, Save and reopen passed** | The guard refused to launch without either fixture file. Escape preserved both files byte for byte. Renaming the styled template preserved the checked step, formatting, recurrence and duration. The name was the only change in the decoded workspace, and the settings bytes were unchanged. Mac TaskStore reopened both files without writing. The guarded app was closed. |
| Focused iPhone | **Four tests and two Mac reloads passed** | Two workspace tests and two native workflows. Created, reopened, renamed and deleted a template. Saved a styled task as a template and applied it to a linked child. The file audit compared exact styled content, regenerated checklist identities and unowned fields. Mac TaskStore independently reopened the result. |
| Full iPhone | **163 tests, 76 fixture checks and 75 Mac reloads passed** | 86 shared and 77 native tests, including the existing Add flow for a styled template. Zero failures, skips or runtime warnings. The unknown-workspace fixture retained its bytes and skipped Mac reload. |
| Dark appearance | **One native workflow and one Mac reload passed** | The styled-template Save and Apply workflow ran again in dark appearance. The simulator returned to light appearance before removal. |
| Final source identity | **149 inputs verified** | `template-final-source-manifest.json` SHA-256 `a6c6cae4796d7d5bb289d34dda1dd9f7d74e9625b694bc04c06512d3459445a1`. Thirteen inputs differ from the Search checkpoint, including the two audit tools. |

Mac tests ran on macOS 27.0.1 ARM64, Xcode 27.0 (27A266a) and Swift 6.4. Native iPhone tests ran on an owned iPhone 13 Pro simulator with iOS 26.3.1 (23D8133). Styled authoring on the phone remains outside the reduced template editor. Physical-device, VoiceOver, Dynamic Type and reference visual matching remain open.

The uncommitted source archive is `taskovsky-checkpoints/MobileTemplates-2026-11-09.zip`. The companion evidence includes light and dark application screenshots, native Mac isolation and save logs, exact build checksums and the file audits. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-local-settings"></a>
## Local iPhone Settings — November 9, 2026

The [local Settings implementation](../changes/mobile-local-settings-2026-11-09.md) is on `codex/mobile-local-prealpha` at base `6ee96eeb8f88e74a105c518de2202233ea528efa`.

| Check | Result | Coverage |
| --- | --- | --- |
| Initial native attempts | **Two issues isolated** | The Work selector matched both the drawer row and the picker option. Scoping the assertion to the picker addressed the ambiguity. The next attempt exposed the drawer gesture dismissing the sheet while trying to reach Settings. The entry moved to the drawer toolbar. |
| Final focused iPhone | **Two tests and one Mac reload passed** | The UI discarded an unsaved priority, saved Work, High and Sunday, then relaunched. Add used Work and High, and Calendar exposed Sunday in the week view. The storage test covered stale and invalid writes, a no-op, retention of a saved unavailable default and exact preservation of an opaque sibling. |
| Final full iPhone | **165 tests, 77 fixture checks and 76 Mac reloads passed** | 87 shared and 78 native tests. Zero failures, skips or runtime warnings. The Settings audit found only the three selected values changed and the task file remained byte-for-byte identical. Mac Taskovsky reopened the saved preferences without writes. The unknown-workspace fixture retained its bytes and skipped Mac reload. |
| Dark appearance | **One native workflow and one Mac reload passed** | The settings save, relaunch, Add and Calendar workflow ran again in dark appearance. The simulator returned to light before removal. |
| Mac tests and release | **572 tests passed and release signature verified** | 451 Core, 14 Domain, 73 Workspace and 34 Swift Testing. The iPhone styling changes do not enter the Mac build. Release executable SHA-256 `80b378a53aec3c96ed82588c406eb7bd7acee2309e8512e63994ade632ad834c`. |
| Final source identity | **151 inputs verified** | `local-settings-visual-source-manifest.json` SHA-256 `688bb1b94258958f3aed6153fb6d394e731a038009d159d61151788a6c061037`. Ten inputs differ from the Templates checkpoint. The final appearance change makes the circular confirmation control blue. |

Mac tests ran on macOS 27.0.1 ARM64 with Xcode 27.0 (27A266a) and Swift 6.4. The native tests used an owned iPhone 13 Pro simulator with iOS 26.3.1 (23D8133). The staged Settings screenshot shows the rounded sheet, centered title, grouped controls and blue confirmation button. Physical-device, VoiceOver, Dynamic Type, reference measurement and OS reminder delivery remain open.

The uncommitted archive is `taskovsky-checkpoints/MobileLocalSettings-2026-11-09.zip`. Companion evidence includes Settings in light and dark, the resulting Add defaults and Sunday Calendar, exact build checksums, and the fixture audits. All 98 sealed inputs of the original Desktop checkout still match.

<a id="mobile-rich-editor"></a>

### MOB-RICH-EDIT-001 iPhone formatted description editing

[Change and transaction contract](../changes/mobile-rich-editor-2026-11-09.md). The rich editor and the ordinary plain editor use different native adapters. Task and note detail use a separate selectable preview.

- **Native workflows.** On a disposable iPhone 13 Pro simulator, edit a stored styled description, apply a quote, Undo, Redo, terminate, resume and save. Separately select “Project” using a native double tap, apply italic and add an HTTP(S) link. Paste the same word over a bold selection and exercise Undo and Redo. A malformed description still displays its saved plain text, and an incompatible workspace disables body writes.
- **Storage.** The exact task JSON and settings audits compare the saved text, every owned rich run and paragraph range, and all unrelated values. Mac TaskStore reloads the audited known workspace without writing. The unknown-workspace case retains the original bytes. The shared contract tests cover scalar alignment, repeated-character edit ranges, style inheritance, paragraph selection and splitting, refused operations, stale revisions and scratch replay.
- **Composition.** A hosted test drives the production UIKit view with two marked-text updates and unmarking. The underlying draft stays unchanged while text is marked. The committed text adds exactly one edit at the original style boundary.
- **Limits.** System IME keyboard candidates, hardware and gesture Undo/Redo, VoiceOver, physical devices and complete Dynamic Type coverage remain separate. The simulator can show a missing puzzle glyph while the saved UTF-16 text remains intact. External services remain deferred.

**Exact run.** The uncommitted `codex/mobile-local-prealpha` worktree is based on `6ee96eeb8f88e74a105c518de2202233ea528efa`. The final source manifest has 154 inputs and SHA-256 `d4fe7f88f8f5caa672ebcc01932ddba4688073f2d5dd45c96598c1dea223ceef`. The earlier Local Settings checkpoint and all 98 original Desktop inputs were verified against their sealed hashes before integration.

- Mac: 582 tests passed (451 Core, 22 Domain, 75 Workspace, 34 Swift Testing). The local release built and passed strict signature verification. The iPhone Release build compiled for the simulator.
- iPhone 13 Pro, iOS 26.3.1 (23D8133): 179 full-suite tests passed (98 shared/hosted, 81 native UI) with zero failures or skips. The 80 QA fixture audits included 79 Mac reopens without writes. The incompatible fixture retained its bytes and refused writes.
- The exact build separately passed 30 focused tests and five file audits, including four Mac reopens without writes. The native link workflow also passed in dark mode and at the accessibility-medium text size, each with a file audit and Mac reopen. The owned simulators were removed after verification.
- Earlier native runs identified a caret jump during fast input and a system Copy/Paste menu overlapping the formatting controls at larger text sizes. The final build retains the live UIKit caret and places the recovery caption between the toolbar and description. The focused and larger-text reruns passed after those changes.

<a id="calendar-current-occurrence-agenda"></a>

### CAL-OCCURRENCE-001 and CAL-AGENDA-001

[Local change and compatibility contract](../changes/calendar-current-occurrence-agenda-2026-11-09.md). The original Desktop worktree was kept separate. The changes are prepared on the isolated mobile line and exercised with neutral QA data on Mac and iPhone.

- **Current occurrence.** Mac Computer Use opened a recurring card's Schedule sheet, selected This occurrence, changed November 9 to November 10, saved, and used Undo. The saved file kept the weekly baseline. Undo restored the original date and the settings stayed byte-for-byte identical. iPhone QA exercised the drag scope chooser, visible Cancel, a saved exception after relaunch, unchanged forecast count, and explicit Restore original schedule.
- **Compatibility.** The iPhone audit compares the saved moved and restored files with the Mac-created fixture and checks the exact schedule members and all unrelated data. The prior Mac TaskStore refused the protected file and left it byte-for-byte intact, including after a save attempt. The current reader reopened it. Both readers accept the restored legacy shape. The Mac test inserts an unfamiliar field into the protected baseline and confirms the current writer leaves the complete bytes intact.
- **Recurrence semantics.** Shared checks cover a current card moved beyond its next forecast, coincident card identities, a resized nominal monthly series, unchanged successor reminder/duration/subtree offsets, reopened predecessors with retained successors, and schedule Undo after an unrelated title edit.
- **Agenda.** Mac showed through December 8, 2026, then through June 8, 2027, and returned to December 8 with Today. Both Mac files remained identical. iPhone showed a task 60 days out and removed it from the visible window on Today. The iPhone workspace stayed byte-for-byte identical. Its expected settings change was the selected Agenda mode.
- **Timed resize.** Earlier simulator runs occasionally grabbed the card rather than its partly offscreen resize handle. The new named control is explicitly scrolled into the usable viewport before dragging. The focused checks verify the persisted end time and also tap the same handle to open and cancel the staged resize editor.
- **Mac numeric mode shortcuts.** A separate Mac-only build changed a single Desktop source file over the exact iPhone regression candidate. Computer Use verified 1–5 in the Calendar window, typed 42 in the Calendar Add draft, cancelled it with Escape, and typed 3 in Tasks quick entry. The Agenda mode returned, the workspace bytes were identical, and saved settings were semantically identical after normalizing the stored Smart List dictionary order.

**Exact run.** Integrated on the isolated, uncommitted mobile branch at base `6ee96eeb8f88e74a105c518de2202233ea528efa`. The iPhone source manifest has SHA-256 `2c142e6592f23ac232d9ad2b6bbe0c2de716f08d30792fae0331c0542f7e602f`. The Mac manifest with numeric shortcuts has SHA-256 `a6f989de53d52544a6d92bbca312da9df94517419c60aa80374dc69e34d10e13` and differs only in the Desktop Calendar workspace file.

- Mac: 588 tests passed. The local Mac release built and passed strict signature verification. The exact iPhone candidate compiled in Release.
- iPhone 13 Pro simulator, iOS 26.3.1: 11 focused tests and 187 full-suite tests passed. The full run recorded 80 baseline file audits with 79 Mac reopens without writes, plus separate audits for the moved occurrence, explicit restoration and Agenda.
- The first focused file-audit runner exited on a shell array expansion error after the tests passed. The full run reused the same app and test binaries in a fresh simulator with the corrected runner. All full audits passed and the owned simulator was removed.
- All 98 recorded inputs in the original Desktop tree matched their sealed checksums.

<a id="calendar-folded-hours"></a>

### CAL-FOLD-001 — Local Calendar folded hours

[Change contract](../changes/calendar-folded-hours-2026-11-09.md). The exact isolated source manifest has SHA-256 `de72b70e8e28526440db20eb7bc8aecef91a7e94ccfeb30ecd9028983e4a8867`. The original Desktop tree still matches all 98 sealed inputs.

- Mac native QA opened Day at 07:00–21:00, read one timed item in each folded band, revealed 06:30 and 22:00 independently, and restored both folds. Workspace and settings remained byte-for-byte identical. The Mac suite passed 589 tests, and the local release passed strict signature verification.
- On iPhone 13 Pro (iOS 26.3.1), five focused tests and a separate dark-appearance check passed. The fold fixture survived relaunch with its task file identical. Selecting Day was the sole settings change. The native early drop saved 02:00, and the timed-resize audit verified the real endpoint. The Mac reopened both changed files without writes. The disposable dark-mode simulator returned to its initial light appearance before removal.
- The shared geometry check covers clipping at the visible boundaries, suppressing the direct handle while the actual endpoint is folded, and converting the expanded grid's pointer offsets to wall-clock minutes. The full iPhone suite passed 189 tests and 80 baseline file audits, with 79 Mac reopens without writes, plus separate moved occurrence, restoration, Agenda and folded-hours audits. The disposable regression simulator was removed.

<a id="mobile-task-actions"></a>

### TASK-ACTIONS-001 — iPhone Duplicate and Convert

[Change contract](../changes/mobile-task-actions-2026-11-09.md). The exact isolated source manifest has SHA-256 `ca3086f4ca7788f08e456eb88ddd1f8a32875ebc9ab3e2ee98ab045f740ef8aa`. The original Desktop worktree matched all 98 sealed inputs at integration.

- Mac tests passed 591 cases and the local app passed strict signature verification. The shared transaction tests checked completed-task conversion, archive refusal, unchanged repeat, stale refusal, reopening and original fields. The Mac QA app converted a styled task to a note and back from its More menu. Both saves retained the task, child link, formatted body and checklist. The fixture’s explicit null Inbox ID re-encoded as an absent optional field. Settings stayed byte-for-byte identical and the guarded app was closed.
- On iPhone 13 Pro (iOS 26.3.1), two focused native tests passed. Duplicate opened the separate copy and Previous task returned to the original. The saved graph added one root and one child with fresh IDs and preserved the original records. Convert to Note remained in effect after relaunch. Convert to Task restored the schedule and checklist controls, retaining all record fields except the updated timestamp. The Mac reopened both workspaces without writes. The focused simulator was removed after the audits.
- The full iPhone run passed 193 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus separate moved occurrence, restoration, Agenda, folded-hours, duplication and conversion audits. The disposable regression simulator was removed.

<a id="calendar-icon-visibility"></a>

### CAL-ICONS-001 — Calendar task and note icons

[Change contract](../changes/calendar-icon-visibility-2026-11-09.md). The exact isolated source manifest has SHA-256 `aaadb2ff7cd475fbf27a8c0e5c6222afe9dea7149f7088102502357d964c86c5`. The original Desktop worktree matched all 98 sealed inputs at integration.

- Mac tests passed 593 cases, and the local app passed strict signature verification. The guarded Mac QA app showed a note icon after hiding task icons, then showed a task checkbox after hiding note icons. Both cards remained present. The workspace stayed byte-for-byte identical. The only settings value changed was note icon visibility. Saving also reordered the serialized Smart List dictionary without changing its values.
- On iPhone 13 Pro (iOS 26.3.1), three focused checks passed. The native test saved a task-only icon change, checked it after relaunch, cancelled a draft master switch change and saved the reverse task/note choices. The two Day captures show each card type separately retaining its icon. The final settings change was Day mode and hidden note icons. Workspace bytes stayed identical and the Mac reader reopened the file without writes. The focused simulator was removed.
- The full iPhone run passed 196 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus seven individual audits for occurrence move and restoration, Agenda, folded hours, Duplicate, Convert and icon visibility. The disposable regression simulator was removed.

<a id="calendar-adjustable-cutoffs"></a>

### CAL-FOLD-001 follow-up — Adjustable Calendar cutoffs

[Change contract](../changes/calendar-folded-hours-2026-11-09.md#adjustable-cutoffs). The exact isolated source manifest has SHA-256 `4ba6ce3b650936818cce906060ce7286f8d4cbe780a368dd6564771215f1950d`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 595 tests, and the local app passed strict signature verification. The guarded Mac QA app expanded both bands, dragged the early marker from 07:00 to 06:00, and used the late marker’s accessibility Increment action to reach 22:00. Folding both bands kept the 06:30 task visible and counted one hidden late task. The task file remained byte-for-byte identical. The only changed settings value was the saved cutoffs. Saving reordered the serialized Smart List dictionary without changing its values.
- On iPhone 13 Pro (iOS 26.3.1), three focused checks passed. Direct drag moved the early cutoff to 06:00. The late cutoff was set to 22:00 through View Options, then the native test relaunched and cancelled a staged Reset. The saved cutoffs remained 06:00 and 22:00. Selecting Day and changing the cutoffs were the only settings changes, and the task file stayed byte-for-byte identical. The Mac reader reopened without writes.
- The full iPhone run passed 199 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus eight individual audits covering recurrence, Agenda, folded hours, task actions, icon visibility and adjustable cutoffs. The disposable regression simulator was removed.

<a id="task-timestamp-sorting"></a>

### TASK-SORT-001 — Created and Modified task sorts

[Change contract](../changes/task-timestamp-sorting-2026-11-09.md). The exact isolated source manifest has SHA-256 `700126848dbb9bc1d723cfdfdbc06357dc0827826c6d6138af26f6c765954d22`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 596 cases and the local release passed strict signature verification. A guarded Work list with tasks on different due dates put the pinned row first and correctly reversed the remaining rows in the two Modified directions. Workspace and settings files stayed byte-for-byte identical. The app closed and the shared QA sort and navigation preferences were restored.
- On iPhone 13 Pro (iOS 26.3.1), two focused checks passed. The native Work list kept its pinned item first, verified both directions for both timestamps, and kept Oldest Modified after relaunch. The saved key belonged to the disposable QA session. Workspace and settings bytes remained identical and the Mac reader reopened without writes. The first native build exposed a UIKit view-hierarchy warning when presenting the picker. The replacement uses the existing Calendar-style popover and its rerun emitted no runtime warning.
- The full iPhone run passed 201 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus nine individual audits. The disposable regression simulator was removed.

<a id="rich-description-heading-folds"></a>

### RICH-FOLD-001 — Collapsible description headings

[Change contract](../changes/rich-description-heading-folds-2026-11-09.md). The exact isolated source manifest has SHA-256 `3f8b320ca8c9dfd773a0256daff6304236c7cbe717b5d0b7e5bb726b325c2f0f`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 597 tests, and the signed release passed strict verification. The guarded Mac reader folded a nested heading, collapsed its parent, and retained the nested fold when the parent reopened. Escape returned to the full editable body. The app closed and both fixture files stayed byte-for-byte identical.
- On iPhone 13 Pro (iOS 26.3.1), two focused tests passed, including exact visible UTF-16 text and the full editor body after folding. A separate dark-appearance native test passed. Both workspace and settings bytes stayed identical and the Mac reader reopened both fixtures without writes. The dark simulator returned to its original appearance before removal.
- The full iPhone run passed 203 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus ten individual audits. The disposable regression simulator was removed.

<a id="mobile-calendar-month-zoom"></a>

### CAL-MONTH-ZOOM-001 — Flexible iPhone Month grid

[Change contract](../changes/mobile-calendar-month-zoom-2026-11-09.md). The exact isolated source manifest has SHA-256 `3042d61b670e70ae0a5b7adc62057644c242944762031aaf26bc753790487712`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 598 tests, and the local release passed strict signature verification. Shared Calendar checks covered navigating civil weeks across a daylight-saving transition. The zoom controls are on iPhone.
- On iPhone 13 Pro (iOS 26.3.1), three focused checks passed, including both zoom directions, navigation, mode reset and a Month all-day drag. The initial pinch-out test placed touches outside Calendar because the scroll view extends beneath the floating navigation bar. The verified test pinches inside the visible week. Zoom left workspace bytes intact and the only settings change was Month mode. The Mac reader reopened both focused fixtures without writes.
- The full iPhone run passed 205 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus eleven individual audits. The disposable regression simulator was removed.

<a id="calendar-all-day-rows"></a>

### CAL-ALLDAY-001 — All-day row count

[Change contract](../changes/calendar-all-day-rows-2026-11-09.md). The exact isolated source manifest has SHA-256 `df478daad30acc1c09d0623d5ca8efabd32fd87133c746ca87aa1cc360a4a0ee`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 599 tests and the local release passed strict signature verification. The guarded app dragged the divider from two to five rows and reached six through the accessibility Increment action. The six all-day cards fit and the 13:00–14:00 card remained aligned. The task file stayed byte-identical. Saving changed the row count and reordered the serialized Smart List dictionary without changing its values. The disposable settings and prior guarded app were restored.
- On iPhone 13 Pro (iOS 26.3.1), three focused checks passed. The app scrolled to a hidden all-day task in the two-row strip, retained that row count after relaunch, and discarded the staged Automatic reset. The task file stayed byte-identical and the only settings changes were Day mode and the saved row count.
- The full iPhone run passed 207 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus twelve individual audits. The disposable regression simulator was removed.

<a id="calendar-hourly-zoom"></a>

### CAL-HOUR-ZOOM-001 — Mac hourly timeline zoom

[Change contract](../changes/calendar-hourly-zoom-2026-11-09.md). The isolated source manifest has SHA-256 `3c5d3ae22d005597788960f0d53503d0655d42311ff7eb0463adae658ea42e5b`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 600 tests and the local release passed strict signature verification. In a guarded Week fixture with four additional rulers, the scale went from 100% to 115% and back. The 13:00–14:00 card kept its time and aligned with the ruler. Both fixture files and scoped QA preferences stayed intact.
- A separate guarded harness at 382 × 580 points changed only the initial window size. The stacked zoom controls accepted coordinate clicks, and vertical and horizontal scrolling worked. Both fixture files stayed byte-identical. The prior guarded bundle and saved window frame were restored. Physical pinch and Control-scroll remain unverified. Computer Use rejected the modifier-only Control press.
- Three focused iPhone checks passed on the shared scale contract, Month zoom and the two-row all-day strip. Both task files stayed byte-identical. The disposable simulator was removed. The prior all-day rows milestone records the full 207-test iPhone regression.

<a id="task-list-sections"></a>

### TASK-SECTION-001 — Named list sections

[Change contract](../changes/task-list-sections-2026-11-09.md). The exact isolated source manifest has SHA-256 `8dad38c07a70b45e6e6517d191c8b6135ba4e398993dbed84ca520dab7675069`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 606 tests, including a failed-write check that left the published workspace unchanged. A guarded Mac fixture exercised add, rename, reorder through the menu, scoped quick entry, the Board move menu and removal. Its task moved from Planning to Review and then to No Section. The Mac organizer drag attempt left the order unchanged. A second guarded run on the final signed build saved a new section and task together. The original tasks and settings remained intact. Both disposable fixtures, scoped preferences and the prior guarded bundle were restored.
- Three focused iPhone checks passed. The native workflow created and reordered sections, renamed one, captured a task, dragged it to another Board section and removed the destination. The task reappeared in No Section after relaunch. The audit preserved the eight original tasks and settings bytes. The pre-sections Mac store refused the saved protected fixture and left both files intact, while the current store opened it.
- The full iPhone run passed 214 tests and 80 baseline file audits, with 79 baseline Mac reopens without writes, plus thirteen individual audits. The simulator reported a missing transfer-type declaration and a UIKit reparenting warning in the original section drag path. The subsequent shared grip candidate replaced that path and its focused organizer and Board checks ran without runtime warnings. The disposable regression simulator was removed.

<a id="calendar-all-day-spans"></a>

### CAL-ALL-DAY-SPANS-001 — Continuous all-day bars and section grip follow-up

[All-day range contract](../changes/calendar-all-day-spans-2026-11-09.md) and [named sections](../changes/task-list-sections-2026-11-09.md). The combined source manifest has SHA-256 `bc4b083a05749c57659407eea83e329fcbaf2970e5b6b934c8b467ab8f5fe27a`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The combined Mac suite passed 607 tests and the signed release passed strict verification. Separate guarded Mac trials exercised Week and Multi-Day overlapping ranges, Day continuation labels, movement from November 9–11 to November 12–14 and Undo. The dedicated grip moved the range. Undo restored the schedule and changed only the task’s modification timestamp. The fixtures, scoped preferences and prior signed QA bundle were restored.
- The Mac organizer grip moved Review above Planning. A release outside the rows retained that order, and the file audit recorded only the section reorder. A separate iPhone gesture check reordered the sections through the same organizer.
- The combined iPhone run passed eight focused tests. The Calendar file audit kept the moved span at three dates and preserved the overlapping review. The section and all-day rows file audits preserved the expected settings and task data. The disposable simulator was removed. The base sections checkpoint records the full 214-test regression.

<a id="calendar-month-spans"></a>

### CAL-MONTH-SPANS-001 — Week-row segments in Month and Multi-Week

[All-day range contract](../changes/calendar-all-day-spans-2026-11-09.md). The isolated source manifest has SHA-256 `ea6a540d4bedd407bd0d31d3e8809fcd7ce8c72e7e8712713c09aa1a49be5c88`. The original Desktop worktree matched all 98 sealed inputs at integration.

- The Mac suite passed 608 tests and the signed release passed strict verification. In native Month, a five-day range covered November 13–15 on one row and November 16–17 on the next. Saturday showed +1 more, and the overflow sheet contained the hidden point task. Multi-Week showed the same two segments. Moving the continuation grip kept five all-day dates, and Undo restored the schedule. The overlapping range, point task, QA preferences and prior signed bundle were preserved. The restored disposable fixture matched its initial bytes.
- Four focused iPhone checks passed without runtime warnings. The native checks exercised two-row continuation in Month and Multi-Week, the hidden Saturday count, the existing point-task drop, and Month zoom. The Mac reopened the zoom fixture without writes. The disposable focused simulator was removed.
- The full regression on the sealed Month source passed 220 iPhone tests without runtime warnings. It passed 80 baseline file audits and 79 Mac reopens without writes. The feature audits confirmed the two range layouts, a three-day range move, the saved section reorder, and preservation of the other tasks. The disposable simulator was removed. The 214-test section and eight-test combined runs are recorded above.
- A separate native iPhone check extended only the span UI test. The app source matches the full regression. The added check moved the three-day range, undid it, and confirmed the original dates after relaunch. The saved workspace differed only in the moved task’s modification timestamp. The overlapping task and settings matched, and the disposable simulator was removed.

<a id="calendar-date-range-creation"></a>

### CAL-RANGE-CREATE-001 — Staged Mac date-range creation

[All-day range contract](../changes/calendar-all-day-spans-2026-11-09.md). The isolated integrated manifest has SHA-256 `d649147d4bbb18891e41f3607fc438772d10d89fac45fa7d7591901149c1c65e`. The original Desktop worktree matched all 98 sealed inputs.

- The Mac suite passed 608 tests and the release passed strict signature verification. Native Month staged November 9–12 and Cancel preserved both files byte-for-byte. A backward drag across week rows saved exactly one all-day task for November 6–11. Multi-Week staged November 14–17 and the single-date double-click still staged November 12. The existing spanning-bar drop and Undo worked in the same build. The prior QA bundle, fixture bytes and scoped window settings were restored.
- The isolated iPhone UI suite includes the focused range Undo and relaunch check documented above. The completed full Month regression used its sealed source and original test implementation. The two new Calendar view files compile on Mac, and the iPhone app source is identical to the full run’s app source.

<a id="mobile-calendar-range-capture"></a>

### CAL-RANGE-CREATE-002 — Staged iPhone Calendar range capture

[Change contract](../changes/mobile-calendar-range-capture-2026-11-09.md). The isolated source manifest has SHA-256 `2bce2fc8393d46109a613fbd3178d8204e6c225bbba628538ed5335e17e88e07`. The original Desktop worktree matched all 98 sealed inputs.

- The Mac suite passed 609 tests and the signed local release passed strict verification. The final manifest adds only iPhone view and UI test differences to the Mac-tested source. The range capture repository test also passed on iPhone. It reopened the staged range, preserved its title and end date, created one task, and returned the same result on retry. It covered template precedence, conversion to a point, and rejection of a mismatched due date.
- Six focused iPhone checks passed without runtime warnings. In Month, a backward drag selected November 6–11. Cancel closed the initial draft. After relaunch, the retained draft required Add, then saved exactly one all-day task with its original date words and both endpoints intact. Both week-row segments appeared. The run also verified ordinary scrolling, pinch zoom, existing point-task drag, and overflow navigation to Day. Multi-Week Cancel preserved the original workspace bytes. The file audits confirmed the earlier tasks and cleared recovery files. The disposable simulator was removed.
- The preceding sealed Month candidate passed its 220-test regression. That run covered sections, Board movement and Calendar span movement. This range capture change was tested separately as described above. The separate span Undo and relaunch check is recorded above.

<a id="calendar-all-day-resize"></a>

### CAL-ALL-DAY-RESIZE-001 — All-day end resizing

[Change contract](../changes/calendar-all-day-resize-2026-11-09.md). The isolated source manifest has SHA-256 `b53888c1d3e9eb584fb6d488c647868a0d68f856ad2989f3c22c72e3e9bd054a`. The original Desktop worktree matched all 98 sealed inputs.

- The Mac suite passed 610 tests and the signed local release passed strict verification. The shared test covered inclusive dates across the New York daylight-saving transition in a Tokyo Calendar, the one-day minimum, no-op releases, and projected occurrences.
- In the guarded Mac app, Week extended November 9–11 to November 9–12 and shortened it to November 9. The one-day range kept its end handle. In Month, the final segment moved from November 17 to November 15. The continuing segment had no resize handle, and clicking the final handle opened the precise editor. Undo restored both schedules. The fixture bytes and prior guarded bundle were restored after exit.
- Seven focused iPhone tests passed without runtime warnings. Week resize, Undo and reload preserved the one-day range and its handle. Month resized across week rows. The saved starts and unrelated tasks were preserved, and the expected settings matched. The run also checked all-day scrolling, range drag and Undo, Month continuation and capture recovery. The disposable simulator was removed.
- The preceding sealed Month source passed the full 220-test regression. The separately sealed range capture and resize source passed the [full 226-test regression](#calendar-all-day-resize-full-regression).

<a id="calendar-week-edge-paging"></a>

### CAL-WEEK-EDGE-001 — iPhone Week edge paging

[Change contract](../changes/calendar-week-edge-paging-2026-11-09.md). The isolated source manifest has SHA-256 `11df16e04464e5fb1c409131460fbbf6332240ce7cab74fd29735461a2da78c4`. Only the iPhone Calendar view and its UI test changed from the all-day resize checkpoint. The original Desktop worktree matched all 98 sealed inputs.

- Four focused iPhone tests passed without runtime warnings. A quick edge release kept the same week. A dwell on the right advanced one week, a dwell on the left retreated one week, and ordinary horizontal scrolling still reached the last visible day. Paging preserved workspace and settings bytes. The disposable simulator was removed.
- The same build passed range drop, Undo and relaunch, the recurring drop scope and persisted exception, and all-day end resize and Undo. XCTest used separate touch sequences for edge paging and scheduling drops. A single continuous edge hover followed by a drop on the newly visible week remains unverified.
- The prior 610-test Mac result covers the unchanged Mac source. The separate 226-test regression uses the all-day resize source sealed before this change.

<a id="task-timeline"></a>

### TASK-TIMELINE-001 — Local Tasks Timeline

[Change contract](../changes/task-timeline-2026-11-09.md). The isolated source manifest has SHA-256 `593aeebcd1911679b2ddb3b0690e2de8b1edbeffbdd70784569357bf85309a91`. The original Desktop worktree matched all 98 sealed inputs.

- The Mac suite passed 612 tests and the signed local release passed strict verification. The shared checks cover list, folder and saved filter membership, undated tasks, archiving and civil-day positions across daylight saving time.
- Native Mac checks exercised the list, folder and saved filter views, point and duration rendering, horizontal axis scrolling, scale and period changes, and schedule Cancel, Save and Undo. The guarded build used a disposable workspace and restored the fixture, prior guarded bundle and scoped QA preferences.
- Three focused iPhone tests passed without runtime warnings. The Timeline test verified scoped rows, scale and period changes, undated schedule Cancel and Undo, and per-list persistence across relaunch. Board mode and folder organization also passed. The file audit verified the restored schedule, preserved unrelated workspace fields and identical settings. The disposable simulator was removed.
- Direct creation on the date axis, drag to move and resize, continuous zoom and section grouping remain open.

<a id="task-timeline-direct-scheduling"></a>

### TASK-TIMELINE-002 — Direct Timeline scheduling

[Change contract](../changes/task-timeline-2026-11-09.md#direct-schedule-editing). The isolated source manifest has SHA-256 `e13bd9789cb3d78103ea1ff176c25a43bd82ee93586ce039bce844429a31a11d`. All 98 sealed inputs in the original Desktop worktree matched.

- The Mac suite passed 613 tests and the signed local release passed strict verification. The shared regression covered an inclusive three-day span crossing daylight saving time, ignored a sub-day all-day drag and an out-of-window move, enforced the one-day resize minimum, and checked quarter-hour snapping and coarse timed resize.
- On Mac, a bar move shifted November 9–11 to November 11–13. Resizing kept November 9 and extended the end to November 13. Undo restored the original dates after each gesture. A blank-axis click staged November 11. Cancel closed the draft, and submitting the next draft created one all-day point on November 11 while keeping “tomorrow” in its title. The folder picker offered the two active task lists. The disposable fixture, prior guarded bundle and scoped QA preferences were restored.
- Three focused iPhone checks passed without runtime warnings. The native Timeline test exercised a short no-op drag, moving both endpoints, resizing the end, both Undo paths, long-press capture and Cancel. The file audit confirmed one all-day point in the intended list, restoration of the original schedule and preservation of unrelated tasks and settings. The prior Timeline scope test and the Calendar recurring drag scope test also passed. The disposable simulator was removed.
- Dragging from Arrange, continuous zoom, and project section grouping remain open.

<a id="calendar-all-day-resize-full-regression"></a>

### CAL-ALL-DAY-RESIZE-002 — Full iPhone regression

The full simulator regression used the sealed range capture and all-day resize source, SHA-256 `b53888c1d3e9eb584fb6d488c647868a0d68f856ad2989f3c22c72e3e9bd054a`. It passed 226 tests with no failures, skips or runtime warnings. The follow-up file audits passed 80 cases, with 79 Mac reopens that made no writes. They confirmed span movement and Undo after relaunch, saved section order, one recovered range capture, write-free Multi-Week capture cancellation, and Week and Month all-day end resizing. The disposable simulator was removed. Week edge paging and the Tasks Timeline have separate focused results above.

<a id="task-timeline-section-grouping"></a>

### TASK-TIMELINE-003 — Timeline section grouping

[Change contract](../changes/task-timeline-2026-11-09.md#project-grouping). The isolated source manifest has SHA-256 `db460d8b0aceecf7a744a2c74b825d2311161da701db6db2fa9242fca9ad84ad`. All 98 sealed inputs in the original Desktop worktree matched.

- The Mac suite passed 614 tests. The signed release passed strict verification. The shared test verified saved section order, the No Section group, list headings, Inbox, and a visible subtask inheriting the section of a parent outside the filter.
- The guarded Mac build displayed Build then Review, with the expected bar or point aligned to each task label. Folder and saved-filter views showed qualified section headings and excluded the archived list. Browsing preserved the protected workspace and settings byte-for-byte. The prior guarded bundle, fixture and scoped preferences were restored.
- Three focused iPhone tests passed without warnings. The grouping check verified section and task order and filter list headings. The direct move, resize, and capture check and the scope, mode, and Undo check also passed. The disposable simulator was removed.
- Dragging from Arrange and continuous zoom remain open.

<a id="task-timeline-arrange-drag"></a>

### TASK-TIMELINE-004 — Drag from Arrange to Timeline

[Change contract](../changes/task-timeline-2026-11-09.md#arrange-by-dragging). The isolated source manifest has SHA-256 `39a10a108c058c191345208ae079f1604dd218758319903864ef6267b1bd9ae9`. All 98 sealed inputs in the original Desktop worktree matched.

- The Mac suite passed 615 tests, and the signed release passed strict verification. The shared regression covered all-day and timed points, quarter-hour snapping across daylight saving time, and refusal outside the date window. The final iPhone package adds a drag type declaration. Mac source and the checked release binary are identical to the guarded run.
- The guarded Mac build left the task undated after a release outside the chart. A Week drop scheduled November 11 and Undo restored the undated row. A Day drop set November 10 at noon. The file audit found only the intended scheduling change. The prior guarded bundle, fixture and scoped preferences were restored.
- Three focused iPhone tests passed without runtime warnings. The Arrange test exercised an outside release, Week drop and Undo, and Day drop and relaunch. The file audit confirmed the exact noon point, its default reminder, unchanged settings and unrelated records. The other tests covered direct move, resize and capture, and the earlier scope and editing flows. The disposable simulator was removed.
- The initial Mac native drop probe was replaced with an in-window gesture after the QA window stopped responding. That probe preserved both fixture files. The iPhone retained its native drag-and-drop path. The earlier iPhone runs passed the tests and each recorded three warnings for the missing drag type declaration. The final package exports the type.

<a id="task-timeline-colors"></a>

### TASK-TIMELINE-005 — Timeline task colors

[Change contract](../changes/task-timeline-2026-11-09.md#task-colors). The isolated source manifest has SHA-256 `1583284b3fadf7623a04b0784953e60ccdd04a17f30de88b718586e08645075c`. All 98 sealed inputs in the original Desktop worktree matched.

- The Mac suite passed 616 tests, and the signed release passed strict verification. The shared test verified all three color rules, list fallback for an untagged task, and unchanged schedule coordinates and membership.
- The guarded Mac check used the compact palette to switch list, tag and priority colors in Timeline. The final iPhone popover leaves the guarded Mac implementation byte-for-byte equivalent. Both fixture files remained byte-identical. The prior guarded app, fixture and scoped preferences were restored.
- The focused iPhone test passed without warnings. It selected Tag and Priority and checked that the task's displayed schedule remained the same. The file audit found only the deliberate List-to-Timeline mode change and preserved settings byte-for-byte. The disposable simulator was removed. The earlier iPhone menu tests passed with a UIKit view-hierarchy warning. The final iPhone selector uses the app’s SwiftUI popover pattern.
- The palette choice is scoped to the current Timeline view. Continuous zoom and exact reference geometry remain open.

<a id="task-timeline-zoom"></a>

### TASK-TIMELINE-006 — Anchored Timeline zoom

[Change contract](../changes/task-timeline-2026-11-09.md#zoom). The isolated source manifest has SHA-256 `e0de184aa078c859ae59d5e127ac4212add828c34d24566e5dbae4b98ae39106`. All 98 sealed inputs in the original Desktop worktree matched.

- The Mac suite passed 617 tests, and the signed release passed strict verification. The shared test checked the fractional-day anchor and the 75% to 300% bounds.
- The guarded Mac check verified the date-axis midpoint at 125%, reset to 100%, zoom out to 80%, and reset on switching to Day. The scheduled dates and workspace and settings files stayed unchanged. The prior guarded bundle, fixture and scoped preferences were restored. The Mac trackpad pinch and Control-scroll routes were reviewed in source and were outside the native Mac check.
- Four focused iPhone tests passed without warnings. The native pinch kept a date mark near the gesture center. The period stayed fixed, and the buttons and scale reset passed. The saved-file audit found only the deliberate List-to-Timeline mode choice and identical settings. Arrange drop, direct capture, move and resize, scope, and Undo also passed. The disposable simulator was removed.
- The separately sealed Timeline Colors source has a [full iPhone regression record](#task-timeline-colors-full-regression).

<a id="scoped-boards"></a>

### TASK-BOARD-003 — Date and list Boards in grouped destinations

[Change contract](../changes/scoped-boards-2026-11-09.md). The isolated source manifest has SHA-256 `a9b6d320121e1386e295bee0475db56dfb7f7ac617f986f7fb83b0c385e2766b`. All 98 sealed inputs in the original Desktop worktree matched.

- The Mac suite passed 619 tests, and the signed release passed strict verification. The shared checks covered Next 7 Days columns, overdue and archive boundaries, due clock and range length, and valid folder and tag list targets.
- The guarded Mac fixture confirmed date and list moves via the card’s Move to menu. Undo restored the date range. The saved-file audit found only the deliberate list and section change and the expected timestamps. The settings, restored fixture, prior guarded bundle and scoped preferences matched. The first guarded drag trial left the fixture unchanged. Native drag remains unverified.
- Four focused iPhone tests passed without runtime warnings. They covered the Next 7 Days date move and Undo, folder scope, tag Board list move, a saved regular-list Board, and the Timeline path. The saved-file audits confirmed the restored range and the intended list and section change. Settings were byte-identical in both new flows. The tests used the Move menu. The first run found a test selector mismatch on the tag drawer, which the second run corrected. Both disposable simulators were removed.

<a id="mobile-subtask-and-board-qa"></a>

### MOB-QA-002 — Subtask navigation and grouped Board drag

The sealed Timeline Colors run read the old parent title before the child transition completed. The same assertion failed in two of three standalone repetitions. Both reached the child’s parent-link step after the early assertion. The revised test waits for the expected title after each tap. This change affects only the iPhone test source.

On the isolated grouped Board source with this test change, SHA-256 `247bf1eed47fa5de338c4435628750b0868ed17249ab552d6c3724cd28b9411f`, all three runs each of child navigation, cross-list hierarchy navigation, and native tag Board drag passed without runtime warnings. The Board drag moved the card from Work to Personal through the drag grip and verified the destination count. The simulator was removed. The grouped Board checkpoint still records the separate Mac and iPhone menu and saved-file audits.

<a id="mac-board-drag-declaration"></a>

### TASK-BOARD-004 — Mac task drag type declaration

The guarded Mac package reported a missing declaration for the native task drag type. The revised package declares the five task navigation drag identifiers used in the drop validator as data types. The existing task provider remains restricted to the current process. The Mac source manifest SHA-256 is `789173207a4bb26bad6a20147cee0286b6a58bd44e5a70d5e3218ffc300bcff5`. Its 619 tests and strict release signature check passed.

The revised guarded run showed zero drag-type declaration warnings and completed the Move to Personal command. Its fixture audit found the expected list, section and timestamp changes and unchanged schedule and settings. Computer Use drag attempts left the cards in place, so a direct Mac drag remains unverified. The fixture, scoped preferences and prior guarded bundle were restored. Native iPhone tag Board drag has its own verification above.

The combined isolated input manifest SHA-256 is `391ce518718a3399ade019556daffdd50101742d9ff127cac5c0ce00fe9b46bf`. The Mac package used the unchanged application source, and the separately verified phone change affects only its UI tests.

<a id="task-timeline-colors-full-regression"></a>

### TASK-TIMELINE-007 — Full iPhone regression on Timeline Colors

The full regression used the sealed Timeline Colors source, SHA-256 `1583284b3fadf7623a04b0784953e60ccdd04a17f30de88b718586e08645075c`. It recorded 237 passes, 1 failures, 0 skips, and 0 runtime warnings. The recorded failures were `testLinkedSubtaskCreationAndIndependentCompletionPersist()`. The [subtask diagnostic](#mobile-subtask-and-board-qa) records the standalone reproduction and the later test-only timing correction. The full result retains the original test outcome.

The saved-file checks passed 80 baseline cases with 79 Mac reopens that made no writes. Six additional audits verified Week edge paging, Timeline movement and resize with Undo, range-aware capture, saved section grouping, undated arrangement, and task colors. The disposable full-run simulator was removed. Zoom and grouped Boards have separate native records on their own source manifests.

<a id="mac-grouped-board-grip"></a>

### TASK-BOARD-005 — Mac grouped Board grip

The Mac grouped Board has a dedicated grip and visible destination highlight. The grip checks the source card and release position against the visible Board before applying a move. The existing card menu and native card drag path remain available.

The isolated source manifest SHA-256 is `77ab56cda2638b3a85a2ced2cdefd43d013ac95b3849994773def35e79d460f6`. All 619 Mac tests and strict release signature verification passed. In the guarded macOS 27.0.1 app, Computer Use dragged an all-day workshop from the Tuesday column into the open area of the Wednesday column and Undo restored the original dates. The file audit confirmed that the inclusive span moved from November 8–10 to November 9–11. Another drag moved a card from Work to Personal, clearing its former section. Releasing outside the Board left both files byte-identical. The saved settings, restored fixture, scoped preferences and prior guarded bundle matched. The original Desktop seal still matched all 98 inputs.

The combined iPhone regression used the preceding source manifest and is recorded separately. [Full iPhone regression](#combined-iphone-full-regression)

<a id="mac-rich-slash"></a>

### RICH-SLASH-001 — Mac description formatting shortcuts

[Change contract](../changes/mac-rich-slash-2026-11-09.md). The isolated Mac source manifest SHA-256 is `f7773763f10ec9083ec14ec2afa9659e1739bc17aa932db59237d4de26cd0763`. All 619 tests passed and the release passed strict signature verification.

In the guarded macOS 27.0.1 detached task window, the native slash menu opened at the caret. Heading 2 changed the rich companion while keeping the exact body. Keyboard Undo removed the heading and Redo restored it. Escape from the slash menu entered a literal slash, and a slash typed after a word stayed in the text without opening the menu. Undo removed both literal edits. The saved-file checks found only the deliberate body or heading changes and the expected timestamp. The final body text, other records, saved settings, restored fixture, scoped preferences and prior guarded bundle matched their expected state.

The first native trial verified formatting and cancellation but did not dispatch the keyboard undo through the detached editor. The revised editor routes the focused keyboard shortcuts to its own history. The combined iPhone regression uses the preceding checkpoint and the same iPhone source inputs.

<a id="combined-iphone-full-regression"></a>

### MOB-QA-003 — Full combined local Tasks and Calendar regression

The full simulator suite used the sealed pre-clipboard iPhone checkpoint, SHA-256 `391ce518718a3399ade019556daffdd50101742d9ff127cac5c0ce00fe9b46bf`. It recorded 245 passes, 0 failures, 0 skips and 0 runtime warnings. The run includes the subtask timing correction, Week paging, Timeline zoom and the three grouped Board flows.

The baseline file audit passed 80 cases with 79 Mac reopens that made no writes. The additional Week, Timeline, zoom and grouped Board audits passed. The disposable simulator was removed. Rich clipboard checks have their own focused record.

<a id="rich-description-clipboard"></a>

### RICH-CLIPBOARD-001 — Copy and paste supported description formatting

[Change contract](../changes/rich-description-clipboard-2026-11-09.md). The Mac source manifest SHA-256 is `afa2aa08dad13faab1bfaa49925af354143f84ee1a46b8c7dea48fe6994f9a12`. The combined source manifest SHA-256 is `f0a31627b5122800c6d6583493a2dac08e78711b48ffb02f12c1c35ca2ff50e0` and includes the final iPhone toolbar and verification changes. All 622 Mac tests passed, including clipped UTF-16 selections, checked checklist state, rich-paste replay and paragraph boundary checks. The release passed strict signature verification.

The guarded Mac test used its unique private pasteboard and synthetic descriptions. It verified copy, paste, Undo and Redo across separate task editors. Saved files retained the exact Unicode, heading, checklist, rule and link, along with unrelated records and settings. The fixture, scoped preferences and prior guarded app were restored.

Three focused iPhone tests used the disposable simulator and session-named pasteboards. They covered rich copy and paste across tasks, draft Undo/Redo and recovery, the visible Paste as Plain Text control over an identical selection, and the existing link-editing path. The plain-paste fixture seeded only its own named pasteboard with the synthetic first word. A native double-tap selected the bold word before paste, leaving the full description text identical. The cross-description test exercised native Copy and Paste. The saved file retained the copied formatting and exact code units. Settings were byte-identical. The first simulator run exposed a focus change during a SwiftUI update. The revised editor defers changes that may resign the text responder until after that update. The disposable clipboard simulators were removed.

The clipboard checks exercised synthetic content on private pasteboards. The production general clipboard path and conversion of foreign rich formats were outside these native checks.

<a id="rich-description-markdown-paste"></a>

### RICH-CLIPBOARD-002 — Recognize supported Markdown on ordinary plain-text paste

[Change contract](../changes/rich-description-markdown-paste-2026-11-10.md). The Mac source manifest SHA-256 is `e936543fcc148ce88eef6cb00c9c59ee85461369f7a981f6ebda6b470367ba23`. The iPhone source manifest SHA-256 is `439102aca1648789edec442b6b9e1611ce3350d1d3e931253dece1f36bb8d47e`. All 625 Mac tests passed and the release passed strict signature verification. New model tests checked exact Unicode and line endings, literal same-app copy, fenced and inline code preservation, and safe paragraph boundaries.

In the guarded Mac app, ordinary Paste on a synthetic description recognized Heading 2, bullets, numbered items, a quote, bold and a link. Paste as Plain Text kept the complete source string. Keyboard Undo restored the prior body and Redo restored the styles. The file checks compared the exact UTF-16 ranges and all unaffected records/settings. The scoped preferences, disposable fixture and prior guarded app were restored.

Five focused iPhone tests passed without runtime warnings. The Markdown case verified ordinary and literal paste from the same named QA pasteboard, draft Undo/Redo and the saved description. The saved file retained the expected block and inline styles, exact text and unrelated records/settings. The earlier runs exposed a test destination outside the opening list and an undispatched keyboard Paste after text selection. The final test uses two visible synthetic descriptions and the native Paste menu. An isolated action trace confirmed the named board, selection, text recognition and successful edit. The other tests covered rich copy between tasks, the existing literal-style removal and link-editing flows, and Summary with its own named QA pasteboard. The disposable focused simulators were removed.

Clipboard QA used synthetic inputs and named pasteboards. The production general pasteboard and physical-device behavior are outside this record. The full iPhone regression on the preceding rich-clipboard source and Summary QA isolation has a separate source manifest.

<a id="calendar-timed-move-grip"></a>

### CAL-HOURLY-MOVE-001 — Dedicated Mac timed Calendar move grip

[Change contract](../changes/calendar-timed-move-grip-2026-11-10.md). All 625 Mac tests passed and the release passed strict signature verification. The Mac source manifest SHA-256 is `60e659f21a6be447d6fc3f088b93c8d34e3091d18fa233a69fcf1b29375e445a`. The combined manifest is `9df23f0822dec6cde0881c66f3dc337b519c14ca7e27a8f9b2cf33147dc41e36`. The original Desktop seal matched all 98 inputs.

The guarded baseline run on the preceding build reproduced unchanged body drags on a five-minute and resized card. The separate resize handle worked and Undo restored the original range. A drag below the title opened a creation draft that was canceled. An earlier coordinate calibration changed the disposable all-day row setting. The baseline fixture and scoped settings were restored.

The revised guarded Mac Week grid moved a 300-second range to Wednesday at 11:00 and Undo restored its original start, end and reminder. After scrolling, a 323-second range moved to Thursday at 14:30 and retained its duration. A point moved within Wednesday to 10:30 and stayed a point. Both saved moves survived relaunch. The reminder offsets shifted with the moves. Releasing above the visible hourly grid and canceling Schedule left the files byte-identical. At 115 percent zoom the separate end handle resized the five-minute task to 09:45 and Undo restored it. Both guarded trials restored their fixtures, scoped preferences and prior app.

Two focused iPhone tests passed on the existing touch paths, with no skips or runtime warnings. The Day grid moved a 323-second range one hour, restored its original position with Undo, moved it again, and showed the saved position after relaunch. The file audit verified the exact duration and reminder shift and unchanged unrelated records. The first run used an absolute screen position that shifted with feedback. The final test uses the hour ruler as a reference. Both disposable simulators were removed.

The Mac native move checks used Week at the tested viewport. Day and Multi-Day use the same Mac grid, and the iPhone native checks used Day. Other viewport widths, VoiceOver and reference gesture equivalence remain open.

<a id="calendar-arrange-hourly-native"></a>

### CAL-ARRANGE-004 — Mac Arrange drop into an hourly slot

The guarded Mac Week grid used the same signed release as the [timed move grip](#calendar-timed-move-grip), manifest SHA-256 `60e659f21a6be447d6fc3f088b93c8d34e3091d18fa233a69fcf1b29375e445a`. The undated synthetic task was dragged from its Arrange grip to Wednesday November 11 at 11:00. An endpoint click completed the native drag in Computer Use. The saved range was 11:00–11:30, with the fixture's automatic reminder at the due time. Undo returned the task to Arrange and removed both the schedule and reminder. The audit checked the full workspace and byte-identical settings. The guarded app was closed and its fixture, preferences and prior bundle were restored.

<a id="clipboard-iphone-full-regression"></a>

### MOB-QA-004 — Full iPhone regression after rich clipboard support

The full suite used the sealed rich clipboard and Summary QA source, SHA-256 `377a39f5158621133d49220c873b365d4631e04d3a0238a45857eec749622bba`. It recorded 249 passes, 0 failures, 0 skips and 0 runtime warnings. Rich description and Summary clipboard actions used only named pasteboards with synthetic data. The separate [Markdown paste verification](#rich-description-markdown-paste) covers the later source.

The file audit passed 80 baseline cases with 79 Mac reopens that made no writes. The additional Week, Timeline, zoom, Board and rich clipboard file audits passed. The disposable simulator was removed.

<a id="calendar-timed-start-resize"></a>

### CAL-HOURLY-RESIZE-002 — Timed Calendar start resize

[Change contract](../changes/calendar-timed-start-resize-2026-11-10.md). The Mac source manifest SHA-256 is `eeda5a895c9f972f5bf196dcbddd7974e05f50b0b89d67fcc2993228be8f072f`. The focused iPhone manifest is `c2973ab7973ec2bcec28c26464d9b4a236b60b022a9089a19f9e9a3205083911`, with identical iPhone build inputs. All 627 Mac tests passed and the release passed strict signature verification. The shared tests verify no-op short and zero ranges, the 15-minute clamp, fixed reminder provenance, clipped endpoints and restoring the baseline of a recurring occurrence.

The compact grip marks were aligned to the card edges after the initial native check. The final guarded Mac Week grid exposed the folded task's start handle only after expanding Early hours. Its point task had only the existing end control. Dragging the five-minute task's start to 08:30 kept the due time at 09:12, and Undo restored 09:07. Dragging the 323-second range's start beyond its end clamped it to exactly 15 minutes, retaining the fractional due time and manual reminder. Relaunch preserved the saved schedule. File checks found only the intended start and timestamps, with byte-identical settings. The prior guarded app, scoped preferences and disposable fixture were restored.

Five focused iPhone tests passed without runtime warnings on the disposable simulator. They covered the shared rules, a native Day start drag, Undo and relaunch, staged Cancel, a compact card's Resize Start menu, and the existing move and end drag. File checks confirmed the new start and unchanged due time, reminders and unrelated records. The initial build failed because the test referenced an internal property. The final test verifies recurrence restoration through the public command. Both disposable simulators were removed.

Native checks used Mac Week and iPhone Day. The other hourly modes share their respective grid. All-day start adjustment and exact TickTick gesture equivalence remain open.

<a id="calendar-all-day-start-resize"></a>

### CAL-ALLDAY-RESIZE-002 — All-day Calendar start resize

[Change contract](../changes/calendar-all-day-start-resize-2026-11-10.md). Mac source manifest SHA-256 is `28e94261650c8b5fe5c28243596c00aedc173311a3ec397e5561817b58b1c641`. The iPhone source manifest SHA-256 is `45a762a94993f76fa3280a619cded0078956bfae3c63d1b1ff49492aaad4ad78`. The two differing files are the iPhone Calendar view and its UI test. The Mac build inputs are identical. All 628 Mac tests passed and the release passed strict signature verification. The new shared regression covers civil-date conversion between Tokyo and New York across the March daylight-saving transition, the one-day clamp, no-op and projected rows. The first Mac run exposed an obsolete assertion that rejected all-day input to the shared start command. The rerun removed that expectation and retained the timed point and invalid-date assertions.

The guarded Mac Week trial verified the leading and trailing handles on an editable range, the trailing-only handle on a continuation, and the separate controls on a one-day duration. Clicking the start handle opened Schedule and Escape dismissed it. A drag extended the start one day, Undo restored it, and a drag beyond the end clamped the range to its due day. Relaunch preserved the exact bytes. File checks confirmed the fixed due day, reminders, unrelated tasks and settings. The prior guarded app, scoped preferences and fixture were restored.

Six focused iPhone simulator tests passed with zero failures, skips or runtime warnings. They cover Week start drag, one-day clamp, staged Cancel, Undo and relaunch, Month start drag across a week row, and the existing Week and Month end handles. The Week and Month file audits confirmed that only the start, its update timestamp and the intentional Calendar view setting could change. The first two iPhone runs exposed a narrow Week card whose content pushed the handles outside their date column. The final layout uses compact grips and constrains the title area. The test measures both handle boundaries and the saved-file audit verifies exact dates. The disposable simulator was removed.

Direct drag was verified in Mac Week and iPhone Week and Month. Multi-Day and Multi-Week reuse their corresponding grids. Exact TickTick all-day drag geometry, physical iPhone and broader accessibility verification remain open.

<a id="calendar-date-jump"></a>

### CAL-NAV-001 — Calendar date jump

[Change contract](../changes/calendar-date-jump-2026-11-10.md). Mac and iPhone used source manifest SHA-256 `9d013fd4e87b493a6bcc9ebd6a93788562a038d84597a8f3710bf3d2dc372ba8`. All 628 Mac tests passed and the release passed strict signature verification.

The guarded Mac Calendar verified Shift-Command-J, direct date entry, month grid selection, Cancel and Escape. The shortcut stayed outside the schedule editor and Tasks. Both date-entry routes retained Week. Relaunch restored the starting focus. Workspace and settings bytes matched the fixture and the prior guarded app and scoped preferences were restored.

Three focused iPhone simulator tests passed with zero failures, skips or runtime warnings. The new test stages March 2027, cancels, confirms the distant date on the second attempt, retains Week and checks the session focus reset after relaunch. The other tests cover the seven modes and Agenda Show more. The file audit found byte-identical workspace and settings. The disposable simulator was removed.

TickTick documents a configurable date-picker shortcut. Taskovsky's default is Shift-Command-J on Mac and its iPhone picker is available from the month header. Exact installed TickTick behavior and physical iPhone interaction remain open. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

<a id="rich-description-markdown-typing"></a>

### RICH-TYPING-001 — Typed Markdown in rich descriptions

[Change contract](../changes/rich-description-markdown-typing-2026-11-10.md). Mac used source manifest SHA-256 `2eacf197b0154f82d3d5123a14865a2742f111747017e1e4db86712752ff86bd`. iPhone used `b81c87ccf0c099574d5835db5979134499f194ac4abd14958290306fac66f7f2`. Only the Mac editor file differs. All 630 Mac tests passed and the release passed strict signature verification.

The first guarded Mac trial verified native heading, bold, Undo/Redo and checklist input. Smart Dashes turned the first two leading hyphens into an em dash. The revised editor keeps the second leading hyphen literal for that keystroke. The final guarded trial verified the same formatting flows and the third-hyphen divider. Relaunch preserved the exact description and companion. The file audit confirmed bold, Heading 2, an unchecked checklist and the divider with byte-identical settings and no unrelated workspace edits. The prior guarded app, scoped preferences and fixture were restored.

Five focused iPhone tests passed with zero failures, skips or runtime warnings. They covered shared Unicode and paragraph edits, typed heading and bold, Undo/Redo, checklist and divider, ordinary versus literal paste, and draft recovery. The saved-file audit verified exact text, formatting and unrelated fields. Both disposable simulators were removed. The shared tests cover italic, highlight, strikethrough, numbered lists, quotes, CRLF, nested/escaped markers and fenced-code protection. Native marked-text composition and physical iPhone behavior remain open.

TickTick documents these typing triggers. Taskovsky stores supported styles in its existing rich companion. Fenced code blocks still need a paragraph representation. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704).

<a id="start-edge-iphone-full-regression"></a>

### MOB-QA-005 — Full iPhone regression through timed start resize

The full suite used the sealed Markdown paste and Calendar timed start source, SHA-256 `eeda5a895c9f972f5bf196dcbddd7974e05f50b0b89d67fcc2993228be8f072f`. It recorded 257 passes, 0 failures, 0 skips and 0 runtime warnings. Rich description and Summary clipboard actions used only named pasteboards with synthetic data. The native Mac and focused iPhone [start-resize verification](#calendar-timed-start-resize) has separate results.

The file audit passed 80 baseline cases with 79 Mac reopens that made no writes. The additional Week, Timeline, zoom, Board, rich clipboard, Markdown paste, short timed move and start-resize file audits passed. The disposable simulator was removed.

<a id="calendar-tasks-split"></a>

### CAL-SPLIT-001 — Tasks beside Calendar

[Change contract](../changes/calendar-tasks-split-2026-11-10.md). The Mac source manifest SHA-256 is `417810243512d99fc7aa93ca33dd494e608ebe75d1ca11fb3eb07f1c2d7a8581`. All 631 Mac tests passed and the release passed strict signature verification. The width test covers the minimum available width, a regular window with a docked task sidebar, and a narrow window. The change affects Mac workspace files only.

The guarded Mac app showed Tasks and Week in one window after choosing Show with Calendar from the Tasks context menu. The detail overlay stayed inside Tasks. The divider responded to an accessible resize, the split preference survived relaunch, and the full Calendar and Hide Calendar commands worked. The same-source guarded debug build used the existing QA window sizing commands. At 1060 points the window returned to Tasks and at 1280 points the split returned.

The first trial displayed both panes but did not complete a list-to-Calendar drop with a secondary text representation. The final build uses the existing private task type for both drag sources and Calendar destinations. The guarded task dropped into the timed grid at the intended snapped time, Undo restored its undated state, and a second drop produced a date-only point. The standalone Calendar grip moved that point and Undo restored it. Relaunch retained the date. Exact file checks found unchanged unrelated records and settings. The prior guarded app, test fixture and preferences were restored.

The reference evidence is the installed TickTick 8.2.20 build 922 English resource keys and the vendor’s June 2024 changelog. Exact reference split sizing and shortcut customization remain open. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

<a id="calendar-month-span-width-regression"></a>

<a id="mobile-month-span-width-regression"></a>

### iPhone Month span width regression check

The broader iPhone run through typed Markdown recorded a failure in the older Month continuation test. Its leading segment's title button measured 122.67 points, below the 125-point test threshold. The start handle occupies its own space in the same all-day bar. The revised test measures each complete segment through the title and its visible drag and resize controls. Both original width thresholds, vertical separation, horizontal continuation, overflow and Multi-Week checks remain in place.

Four focused iPhone tests passed on source manifest `2f8e3fcaf4a2baa995258cc736d24e72a4906d53d18c7aa685ba4742190b4a8b` with zero failures, skips or runtime warnings. Only the iPhone UI test differs from the preceding checkpoint. The saved-file audits found byte-identical workspace files after browsing Month and Multi-Week and verified the intentional date changes from Week and Month resize. The simulator was removed. The broader run retains its original failure record.

<a id="calendar-custom-shortcuts"></a>

### CAL-NAV-002 — Configurable Mac Calendar shortcuts

[Change contract](../changes/calendar-custom-shortcuts-2026-11-10.md). Mac source manifest SHA-256 is `86747ea492d6c4bc79351750af19315ddedb389b83e2e992004730fe70411237`. All 631 Mac tests passed and the release passed strict signature verification. The change affects Mac app sources only.

The first build saved both chords but refreshed the menu bindings only after relaunch. The verified build shares binding state between Settings and the View menu, and recreates each command when its chord changes. The guarded Mac Settings recorder showed the default date shortcut and an unassigned split. It rejected a duplicate date chord and the existing New Note shortcut. Escape left the binding unassigned. Option-Command-J opened Jump to Date immediately after recording and the old shortcut ceased to open it. Shift-Command-K toggled the split from Tasks. The date jump stayed inactive in ordinary Tasks. Relaunch kept both recorded bindings. Clear disabled the split chord and Restore Defaults returned the date jump to Shift-Command-J. The file audit found byte-identical workspace and settings. The guarded app and scoped preferences were restored.

The vendor changelog documents both configurable shortcuts. Taskovsky's recorder accepts a Command-based letter chord with an additional modifier. Exact installed TickTick defaults and recording UI remain open. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

<a id="calendar-option-icons"></a>

### CAL-DISPLAY-006 — Hold Option to reveal Calendar icons on Mac

[Change contract](../changes/calendar-option-icons-2026-11-10.md). Mac source manifest SHA-256 is `5e35a14d18bedac8e110697210a89c0732974b54b03e683c12506c7c26ed828e`. All 631 Mac tests passed and the release passed strict signature verification. The two changed inputs are Mac app sources.

With the saved master and both per-kind switches off, standalone Calendar initially hid the task and note icons. Option-click on the leading task target completed and reopened the task. Option-click on the note’s leading target stayed in Calendar, while a plain click at the same point opened the note detail. In split view, Option-click on the Calendar checkbox completed the same task. Undo restored it and the checkbox stayed hidden after release. The default date jump still worked from split Calendar. Ordinary Tasks kept its checkbox and did not open Calendar on the Option probe. The file audit found byte-identical Calendar settings and only the test task’s modification timestamp changed. The fixture, guarded app and scoped preferences were restored.

The original Calendar view-options guide documents the temporary reveal on Mac. The app keeps the input within the key Calendar workspace window and uses existing entry controls. [TickTick Calendar View Options](https://help.ticktick.com/articles/7055782085826445312).

<a id="markdown-typing-iphone-full-regression"></a>

### MOB-QA-006 — Full iPhone regression through typed Markdown

The full suite used the sealed all-day start, date jump and typed Markdown source, SHA-256 `2eacf197b0154f82d3d5123a14865a2742f111747017e1e4db86712752ff86bd`. It recorded 263 passes, one failure, zero skips and zero runtime warnings. `testCalendarMonthAllDayRangeContinuesOnNextWeekRow()` failed the older title-width assertion. The [corrected whole-bar test passed in the focused rerun](#mobile-month-span-width-regression). Rich description and Summary clipboard actions used only named pasteboards with synthetic data. The [focused typed Markdown checks](#rich-description-markdown-typing) have separate results.

The file audit passed 80 baseline cases with 79 Mac reopens that made no writes. All 26 file-audit groups passed, including exact saved all-day endpoints, no-write date navigation and the rich ranges created by typed Markdown. The disposable simulator was removed.

<a id="task-created-date-groups"></a>

### TASK-GROUP-001 — Creation-date grouping on Mac and iPhone

[Change contract](../changes/task-created-date-groups-2026-11-10.md). Source manifest SHA-256 is `1247e0e0750e7b9b835e74592edf8bafa0f16f196cd96f45fc8ab6dea5d3e642`. All 632 Mac tests passed and the release passed strict signature verification. Five focused iPhone simulator tests passed with zero failures, skips or runtime warnings. The tests included the existing timestamp sort and the corrected Month continuation check.

Mac QA showed a named Review section and a pinned row. Group by Created Date moved the two unpinned tasks under their localized creation-day headers, with newest day first. Activating the task grip in manual sort showed the grouping-specific reorder message. Created · Oldest First reversed the date groups. Both settings survived relaunch. Turning grouping off restored the Review header and its add target. Completed kept its existing menu without the grouping choice. The file audit verified byte-identical workspace and settings and restored the fixture, guarded app and scoped preferences.

The iPhone test kept the pinned row above the creation days, checked default and oldest-first order, restored a named section, and confirmed both settings survived relaunch. Its audit confirmed byte-identical workspace and settings, including the original section assignment, and preferences scoped to the QA session. The domain test verifies the boundary at Moscow midnight across New Year, independent of the due date. The focused simulator was removed. The full 266-test run started separately on the same source.

The reference documents creation grouping separately from sort. Local-day labels and device-wide List preference are Taskovsky choices. [TickTick release notes](https://help.ticktick.com/articles/7082552170989486080).

<a id="rich-code-blocks"></a>

### RICH-BLOCK-001 — Saved description code blocks

[Change contract](../changes/rich-code-blocks-2026-11-10.md). Source manifest SHA-256 is `4ce05d24fee643166131b15d4182ac378a83b525249e02eae905d223a9abefa2`. All 635 Mac tests passed and the release passed strict signature verification. Seven focused iPhone simulator tests passed across two runs with zero failures, skips or runtime warnings.

Guarded Mac QA pasted a closed fence into a disposable task, checked Undo and Redo, opened Read Description and copied the block. Paste as Plain Text in another task produced the exact same characters, including the trailing newline, with no rich companion. Relaunch reopened the saved block. The Code Block tool removed only the paragraph style and Undo restored it. The audit found only the intended descriptions and modification times changed, with byte-identical settings. The guarded app, fixture and preferences were restored.

The iPhone check compared ordinary and explicit plain paste, exercised Undo and Redo, saved, relaunched and pasted the reader’s copy into another task. The file audit verified the two UTF-16 ranges, their shared block ID, the exact plain copy and unchanged settings and other fields. The existing clipboard file audit needed its second case in a separate run on the same simulator. Both named-board audits passed and the focused simulator was removed.

The shared tests cover CRLF, decomposed Unicode, emoji, literal formatting marks, adjacent separate blocks, removing the style without changing the text, joining lines within a block and protected workspace encoding. An older Mac reader left the new format byte-for-byte unchanged. The reference documents code blocks and one-click Copy. Taskovsky’s typed fence trigger and syntax highlighting remain open. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704) · [TickTick changelog](https://ticktick.com/public/changelog/en.html).

<a id="rich-typed-code-fence"></a>

### RICH-BLOCK-002 — Type a code block fence

[Change contract](../changes/rich-typed-code-fence-2026-11-10.md). Mac source manifest SHA-256 is `c754b6ed34beb964273aac0f3b1d78066b6f8e0e8853efbdda57c75518183040`. The iPhone source SHA-256 is `a6c0960084ce6d1583f66cf86a8f3565d2b6018c892f6efdebe756fdc75ce97b`. The manifests differ only in the Mac editor, AppKit renderer and Mac-only test. All 638 Mac tests passed and the release passed strict signature verification. Five focused iPhone simulator tests passed with zero failures, skips or runtime warnings.

Mac QA typed both fences with the Return key, verified Undo and Redo at opening and closing, continued through two code lines, and typed a Markdown heading afterward. The first Mac trial left the code style at the trailing caret after redoing the close. The verified AppKit build recomputes code typing attributes from the restored paragraph and clears them at an empty trailing caret. Relaunch showed the saved snippet and its Copy action. The audit found two code ranges and one ordinary heading, with byte-identical settings and unrelated records. The guarded app, fixture and scoped preferences were restored.

The first iPhone trial lost characters during rapid multiline typing after the opening conversion. The verified build updates the existing text storage during code edits. It passed the same rapid sequence, opening Undo and Redo, a literal hash line, closing, a following heading and relaunch. The audit verified exact saved text, two code ranges and an ordinary heading. Existing code paste, whole-block copy and typed Markdown also passed. Both disposable iPhone simulators were removed.

The shared tests cover CRLF, an opening before existing text, a final code line without a separator, an exact standalone closing fence, literal whitespace, and return to prose. The protected workspace format is unchanged. TickTick documents the opening shortcut. The standalone closing rule is Taskovsky’s local choice. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704).

<a id="task-created-groups-iphone-full-regression"></a>

### MOB-QA-007 — Full iPhone regression through creation-date grouping

The full suite used source manifest SHA-256 `1247e0e0750e7b9b835e74592edf8bafa0f16f196cd96f45fc8ab6dea5d3e642`. It recorded 266 passes, 0 failures, 0 skips and 0 runtime warnings. The test inventory includes both creation grouping cases and the corrected whole-bar Month test. Rich clipboard actions used named boards with synthetic data.

The file audit passed 80 baseline cases with 79 Mac reopens that made no writes. All 28 audit groups passed, including creation grouping’s section assignment and exact task bytes and the Month continuation’s no-write check. The disposable simulator was removed.

<a id="rich-highlight-colors"></a>

### RICH-HIGHLIGHT-001 — Multiple description highlight colors

[Change contract](../changes/rich-highlight-colors-2026-11-10.md). The Mac source manifest SHA-256 is `8133d3e50abd4fc1bfe617243d32f9c53b7fe152fe4a9d8b694e057fa03cbbde` and the iPhone source SHA-256 is `97e0607ee9701c3afdcf740a0a47d874d50fc5f6bdc1972011f66c61318143a6`. Only the iPhone UI test differs between them. All 640 Mac tests passed and the release passed strict signature verification. Six focused iPhone simulator tests passed with zero failures, skips or runtime warnings.

The Mac accessibility tree names the menu Highlight Colors. The guarded Mac QA build applied blue, changed it to pink, removed it, and stepped through Undo and Redo. Saved ranges confirmed that the original yellow and bold stayed intact. Copy into another task and a relaunch preserved both colors and exact text. The prior QA build, fixture files and preferences were restored.

The initial iPhone trials saved the correct source ranges, but keyboard selection failed after relaunch and the first touch attempt did not expose Select All. The passing rerun extended the selection using its visible handle and used the native Copy and Paste menus. The saved file audit verified both colors and original bold in the destination, unchanged settings, and preservation by an older Mac reader. All four disposable simulators were removed.

The shared tests cover exact Unicode, color edits over existing bold and inline code, legacy yellow, color clipboard protection and workspace round trips. The Mac renderer tests cover overlapping inline code and highlight and restoring its wash after removal. The reference documents multiple colors. Taskovsky’s palette and storage are local choices. [TickTick release notes](https://help.ticktick.com/articles/7082552170989486080).

<a id="rich-checklist-toggle"></a>

### RICH-CHECKLIST-001 — Direct description checkbox toggles

[Change contract](../changes/rich-checklist-toggle-2026-11-10.md). Mac source manifest SHA-256 is `f13bffa09c37580609cad9363dc9d3e52200a982bd8e9e3fce736dbda6d3cc15` and iPhone source SHA-256 is `cc0952d738a9f884e8bce101f52d89c2172fd696d4761baa48514d6ed76a554d`. The only difference is the Mac editor source. All 641 Mac tests passed, including the native layout and mutation regression. The release passed strict signature verification. Five focused iPhone simulator tests passed with zero failures, skips or runtime warnings, including regressions for colored highlights, rich copy, typed Markdown and typed code fences.

Once the editor had focus, a prose click and a bullet click left the workspace bytes unchanged. The first native Mac trial revealed that Computer Use supplied Command with its clicks. The final handler accepts that modifier in the checkbox gutter and leaves other text click behavior to AppKit. The open and checked description items then toggled independently, and Undo/Redo and relaunch retained the expected states. The saved-file audit found only the two checkbox states and the target task’s modification timestamp changed. The prior QA build, fixture files and preferences were restored.

The first iPhone trial left the simulator keyboard tutorial open. The passing case dismissed it, then tapped adjacent prose and a bullet before toggling both checkboxes. Undo/Redo and Done retained the two independent states, and a further toggle after relaunch was discarded with Cancel. The saved file preserved exact Unicode, inline bold, other blocks, tasks and settings. Both disposable simulators were removed. The reference guide establishes description checklists. The exact hit targets and local editor transactions are Taskovsky choices. [TickTick editing guide](https://help.ticktick.com/articles/7507338582718152704).

<a id="task-option-times"></a>

### TASK-TIME-001 — Hold Option to reveal full task times on Mac

[Change contract](../changes/task-option-times-2026-11-10.md). Mac source manifest SHA-256 is `16f6c4fe089690c329d0af42ce41637da07e61a49796c8e221c0d3ee7e77278a`. All 642 Mac tests passed, including date, time zone, point, same-day, overnight, all-day and invalid-window label cases. The release passed strict signature verification.

The signed Mac build retained compact labels after release, hid the configured Calendar icons, and opened and cancelled Jump to Date. Computer Use cannot send a standalone modifier and its snapshots followed key release. A separate guarded build recorded native held and released events and the actual List label layout. It displayed Tokyo same-day and overnight ranges, a three-day all-day range and a timed Board point. The overnight List label occupied two lines. The split view activated both Tasks and Calendar together. Settings as the key window suppressed the reveal. Calendar number shortcuts changed Month and Week in standalone Calendar and stayed inactive in split view.

The workspace and settings were byte-identical throughout the Option checks. The separate number shortcut probe returned the settings to their original values. Both QA builds, fixtures and scoped preferences were restored. The diagnostics stayed outside the integrated source.

TickTick documents holding Option for task times. The local label format and responsive List/Board treatment are Taskovsky choices. [TickTick Mac changelog](https://ticktick.com/public/changelog/en.html).

<a id="calendar-skip-occurrence"></a>

### CAL-REPEAT-002 — Skip the current Calendar occurrence

[Change contract](../changes/calendar-skip-occurrence-2026-11-10.md). Source manifest SHA-256 is `a0191aa88d9a6018358d49ce7940201c4f8bb50475df02c9a07c1ed6493a1ebe`. All 645 Mac tests passed and the release passed strict signature verification. Six focused iPhone simulator tests passed with zero failures, skips or runtime warnings. The shared tests verify nominal series advancement, a monthly anchor, completion-based cadence, preservation of the same record, terminal and stale refusals, and scoped Undo.

The guarded Mac build staged and canceled the action, moved a two-day all-day range and its manual reminder one day, then restored the previous schedule with Undo. A second skip survived relaunch, and the editor omitted the action at the terminal occurrence. The audit confirmed only the target schedule and modification timestamp changed. The prior QA build, fixture files and preferences were restored.

The iPhone Month case moved the current weekly occurrence before staging a skip. Cancel kept the moved occurrence. Done advanced from the saved series baseline, and Undo recovered the exception. A second skip survived relaunch as the terminal occurrence. The file audit confirmed the exact task ID, next date, shifted manual reminder, and unchanged other records and settings. The disposable simulator was removed. TickTick documents the current-occurrence action. The completion anchor and terminal handling are Taskovsky choices. [TickTick FAQ](https://help.ticktick.com/articles/7055792921664028672).

<a id="calendar-card-completion"></a>

### CAL-COMPLETION-001 — Calendar task and checklist completion

[Change contract](../changes/calendar-card-completion-2026-11-10.md). Source manifest SHA-256 is `a9b45e99387c6dd5309d7a080cf189fa57ccfac60aa59005e1a32c95676bc3bc`. All 646 Mac tests passed and the release passed strict signature verification. The store regression covers a narrow checklist write, an identical no-op and a failed write without an in-memory change.

The guarded Mac Agenda build completed and reopened an item using its checkbox and completed it with the icons hidden through the card menu. The checked state survived relaunch. A forecast had no completion action. The saved-workspace audit matched every field except the chosen item and its task's modification timestamp. The prior guarded build, fixture files and QA preferences were restored.

Four focused iPhone simulator tests passed with zero failures or skips. They covered the 44-point Agenda checkbox, task completion and reopening with lifecycle Undo, hidden-icon checklist menus, Show Completed, read-only forecasts, relaunch and prior Calendar options and occurrence scheduling. The saved-workspace audits confirmed the exact checklist item and preserved the other items, parent status, schedule, and unrelated tasks. The disposable simulator was removed. VoiceOver and physical-device testing remain open.

The iPhone-only alignment follow-up centered the Agenda title and drag grip with the checkbox. Source manifest SHA-256 is `2a0c9f07b479c3023300684e71550ab646f71550408d7a155e020eb1b15ef1f9`. Four focused tests passed on a fresh simulator, including Agenda Show more, completion, lifecycle Undo and hidden-icon menus. Both completion file audits passed. The aligned Agenda and hidden-icon menu screenshots are in the checkpoint evidence. The Mac source and tested release are identical to the previous checkpoint.

<a id="rich-checklist-full-iphone-regression"></a>

### MOB-QA-008 — Full iPhone regression through description checkbox toggles

The full suite used source manifest SHA-256 `f13bffa09c37580609cad9363dc9d3e52200a982bd8e9e3fce736dbda6d3cc15`. It recorded 274 passes, 1 failures, 0 skips and 0 runtime warnings. Failed cases include `testRichChecklistTapsSaveAndCancelOnlyTheirParagraphs()`. The test inventory retains all 266 prior tests and adds nine cases covering saved code blocks, typed code fences, highlight colors and description checkbox toggles. Rich clipboard actions used named boards with synthetic data.

The file audit passed 80 baseline cases with 79 Mac reopens that made no writes. 31 of 32 audit groups passed. The description-checkbox audit found both markers still in their initial states and the body unchanged. The disposable simulator was removed.

<a id="rich-checklist-selection-menu-qa"></a>

### MOB-QA-009 — Rich-description checkbox test and native selection menu

A full regression on the older source missed two rich-description checkbox taps. The saved task kept both initial marker states and the exact body. On the same source, an isolated repeat passed twice and failed once. The failed replay showed the native iOS selection menu covering the first checkbox and intercepting the tap. Its saved file kept the first item unchecked.

The corrected test moves the caret out of the selection menu's hit area and checks that the software keyboard remains visible before tapping the markers. All six runs and six exact saved-workspace comparisons passed. Source manifest SHA-256 is `86bfc1182f5e335ed43fbbee5171c24d4cb07116a22f4b19ed396480c11a73a5`. Only the test changed. The simulator was removed.

<a id="board-display-settings"></a>

### TASK-BOARD-DISPLAY-001 — Desktop Board display settings

[Change contract](../changes/board-display-settings-2026-11-10.md). Source manifest SHA-256 is `b392c496b3a4d3e7b5090e3c7c6d89787ae01be42c48b33226fbaa2d8ee13eb6`. All 646 Mac tests passed, and the local release passed strict signature verification. The Board's three column sizes and idle task input are Mac presentation preferences. iPhone source and shared models match the prior verified checkpoint.

The guarded Mac build exercised the three width choices across status, section and grouped Boards. The short status Board stayed aligned at the top of the pane. Cancel discarded a draft choice. Done saved the width and idle input setting. Hiding the input left section capture and New Task available. An in-progress title survived a width change, and List retained its input. The saved preferences survived relaunch. The file audit confirmed byte-identical workspace and shared settings files. The prior guarded build, QA preferences and fixture files were restored. Exact TickTick dimensions and preference scope remain unverified.

<a id="task-progress"></a>

### TASK-PROGRESS-001 — Local task progress

[Change contract](../changes/task-progress-2026-11-10.md). Source manifest SHA-256 is `612de19363a880cfe75720161b4a928535b0f70adc7350dbae4ee0fe5389fa57`. All 650 Mac tests passed, and the release passed strict signature verification. The subsequent iPhone sheet and test changes left the tested Mac sources identical. Domain and store tests cover exact field changes, checklist derivation, protected-format transitions, stale drafts, disk refusal, recurring successors and progress surviving other desktop edits.

The guarded Mac run discarded a changed draft with Escape, saved 100% on an open task, and changed a separate task from 25% to 50% by checking one item. Both values survived relaunch. Its saved-file audit confirmed only the selected values and modification timestamps changed. The prior guarded build, fixture files and QA preferences were restored.

The final iPhone simulator run passed eight focused tests with zero failures, skips or runtime warnings. It covered Cancel, long-press entry, slider and one-point stepper, 100% without completion, relaunch and checklist derivation. The first simulator run saved 99% when the test drove the slider to its far end. The revised build uses the stepper for exact values. Its first test used an incorrect increment-button identifier and made no file writes. The corrected test passed against both the original sheet and the compact, expandable editor with a simplified slider. The final file audit checked the progress and checklist fields and byte-identical settings. An older Mac reader refused the protected file and the current reader opened it, with both leaving the files byte-identical. All four disposable simulators were removed.

<a id="summary-report-options"></a>

### TASK-SUMMARY-002 — Local Summary criteria and fields

[Change contract](../changes/summary-report-options-2026-11-10.md). Source manifest SHA-256 is `d3fa80af2b3d865cf181ab2b247c05731322867cbf2202c257a0c04328afcca7`. All 652 Mac tests passed, and the release passed strict signature verification. The shared tests cover intersecting list, tag and priority criteria, parent-tag descendants, exact manual and checklist progress, optional completion fields, and sorting with stable ties in the current and upcoming sections.

The guarded Mac build exercised Summary tag and priority selection, title sorting and the three new fields. It saved the rendered report as an Inbox note. The note body matched the captured report, the source tasks and settings were preserved, and the QA bundle, fixture and preferences were restored.

Nine focused iPhone simulator tests passed with zero failures, skips or runtime warnings. The first iPhone test tapped switch rows outside their native controls and saved the unfiltered text. The second run applied scope and progress but missed the partially offscreen Completion Date switch. The final test scrolls to the fields and verifies each switch before applying the draft. The correction changed only the iPhone test source. The report with tag and priority scope matched both the parent and child tag cases. Cancel preserved the report. The edited report survived relaunch as an Inbox note. The saved-file audit matched the exact edited text and verified that only the new note was added. All three simulators were removed. TickTick's exact sorting choices and generated punctuation remain unverified.


<a id="board-display-full-iphone-regression"></a>

### MOB-QA-010 — Full iPhone regression through Calendar completion and skip

The sealed pre–Task Progress and pre–Summary options source has manifest SHA-256 `b392c496b3a4d3e7b5090e3c7c6d89787ae01be42c48b33226fbaa2d8ee13eb6`. All 281 tests passed, with zero skips and zero runtime warnings. The suite retains all 275 prior tests and adds six for Calendar card completion, lifecycle Undo and skipping a recurring occurrence. The earlier description checkbox workflow also passed. Clipboard tests used named boards with synthetic data.

All 34 saved-file audit groups passed, including Calendar completion and skip, and the 80 baseline file cases included 79 Mac reopens without writes. The disposable iPhone 13 Pro simulator was removed.


<a id="summary-report-presets"></a>

### TASK-SUMMARY-003 — Device-local Summary presets

[Change contract](../changes/summary-report-presets-2026-11-10.md). Source manifest SHA-256 is `12d84a5733f8cb42837bc0a347df7cc4d0ff69d1d64312475b8408737fb552f2`. The Mac build uses the equivalent Mac source in manifest `5a76482ecbaf96785b67372826dc13669223e506a143cf041e9d604b9ff52dec`. All 653 Mac tests passed and the release passed strict signature verification. The shared contract test round-tripped every option and verified relative and custom periods, duplicate names, stable identity, rename, deletion and invalid data.

The guarded Mac build saved, applied, renamed and deleted a named preset. A relaunch preserved the preset while restoring the ordinary initial report options. Renaming and deleting preserved the report text. Cancelling deletion kept the preset. Workspace and settings files were byte-identical, and the original guarded bundle and preferences were restored. The native check covered the wide Summary options rail.

All 11 focused iPhone simulator tests passed with zero failures, skips and runtime warnings. The first run also passed 11 tests and reported a SwiftUI reparenting warning when opening the preset menu. The final build uses a dedicated preset screen. Applying and managing presets stayed staged until Done, and Cancel preserved the edited report and discarded the staged preset. The final audit found one renamed preset in the QA preference key and verified byte-identical workspace and settings. The two existing note tests preserved exact report text and unrelated records, and the failed-save workflow left its workspace and settings byte-identical. Both simulators were removed. Physical-device and VoiceOver checks remain open.


<a id="foreign-rich-description-paste"></a>

### RICH-CLIPBOARD-003 — Supported HTML and RTF description paste

[Change contract](../changes/rich-description-foreign-paste-2026-11-10.md). Final source manifest SHA-256 is `5ad5a236ace65e20cbb197e41a358f7c27c00f75cef59aa375d166e7890ce8ec`. All 657 Mac tests passed, and the release passed strict signature verification. Four focused contracts check Unicode ranges, matching whitespace, allowed links and inline CSS, refused embedded RTF data, malformed and oversized payloads, and conflicting HTML and RTF representations.

The guarded Mac app pasted synthetic HTML with bold, italic and one web link. Undo and Redo treated the paste as one edit. Paste as Plain Text saved the same characters without styles. Relaunch reopened both descriptions without a write. The saved-file audit found the expected exact text and inline ranges, preserved unrelated records and settings, and verified restoration of the QA files, bundle and preferences.

The first eight iPhone simulator checks passed. Review found that unstyled HTML could be replaced by different RTF text when no plain representation was available. The final importer retains the HTML text in that case. The final four iPhone checks passed with zero failures, skips or runtime warnings. They covered HTML with a plain alternative, RTF without one, internal rich copy and paste, and plain Markdown paste. Both runs audited exact saved text, supported ranges, literal paste, untouched records and settings. Clipboard QA used synthetic content on private pasteboards. Both disposable simulators were removed. The HTML screenshot retains the simulator’s previously observed puzzle-emoji fallback glyph. The file audit confirms the exact UTF-16 text. Physical-device behavior and general-pasteboard prompts remain unverified.


<a id="task-batch-editing"></a>

### TASK-BATCH-001 — Local batch editing from task lists

[Change contract](../changes/task-batch-editing-2026-11-10.md). Source manifest SHA-256 is `af18edd59f12267a6bf795e9625a04cea1b2c2f606fae48cdc2023f2a4f89b6d`. All 662 Mac tests passed, and the release passed strict signature verification. The new shared tests verify unchanged fields, unavailable selections, tag addition and removal, archived list movement, duration and reminders on a date move, unscheduling, descendant cascades, recurrence successors and an idempotent completion. The repository tests cover stale revisions, no-op, failed writes and confirmation after a write throws. The Mac store test confirms a disk refusal leaves the visible data intact.

The guarded Mac app opened Select Tasks from the current list, cancelled a staged edit with byte-identical files and applied Low priority to two items. Both priorities were visible after relaunch. An archived selection offered only Move to List. The file audit found only the selected priorities and timestamps changed. The original guarded app, fixture files and QA preferences were restored.

Six focused iPhone simulator tests passed with zero skips, failures or runtime warnings. The native workflows covered cancel, priority, tag addition, clearing dates, moving selected tasks to another list, completion, cancelling the Trash confirmation and confirming the move to Trash. The file audits verified the intended edits, exact unowned fields and unchanged settings. The disposable simulator was removed. Physical-device and exact reference UI comparisons remain open.


<a id="mobile-calendar-show-details"></a>

### CAL-MOBILE-DETAILS-001 — Show Details in iPhone Calendar

[Change contract](../changes/mobile-calendar-details-2026-11-10.md). Source manifest SHA-256 is `6b1977c648158849454cbf93e8618df3802f5e560f79f1f71e502832ae2bfc63`. All 664 Mac tests passed, and the release passed strict signature verification. Shared cases check localized labels in the display zone, a range across midnight, timed points, all-day labels, missing lists and an unchanged projection. Repository coverage verifies sparse options, explicit legacy false, save and reset, and byte preservation outside the option slice.

Seven focused iPhone simulator tests passed with zero skips, failures or runtime warnings. The new native flow checked default-off, cancelling an enable, enabling with Done, Agenda details, Day retaining its standard presentation, Month details at high zoom, reopening after relaunch and cancelling a disable. The workflow returned to Week before auditing the saved file. Only `showDetails` changed, with the exact workspace and adjacent settings bytes preserved. The adjacent checks covered Agenda completion and undo, Month range continuation, timed end resize and saved view options. Both disposable simulators were removed.

The supplied TickTick R22 screenshot establishes the List and Month scope and shows the switch off. The official guide identifies time and list. Taskovsky uses its Agenda name and a compact Month subtitle with full accessibility metadata. On the 390-point iPhone, existing narrow Month cards still truncate titles and some list names. Physical-device verification and a live side-by-side reference comparison remain open.


<a id="mobile-calendar-month-scroll"></a>

### CAL-MOBILE-MONTH-SCROLL-001 — Continuous Full Month browsing on iPhone

[Change contract](../changes/mobile-calendar-month-scroll-2026-11-10.md). iPhone source manifest SHA-256 is `a5ad22d66a043c7ef31b7d7e30664f79a9204700cdbd08a7d4dc914de04dc5b1`. All 665 Mac tests passed, and the release passed strict signature verification. The Mac verification source manifest is `7afde9888ac3ca40ff822ce091eef8abf696a089bcc4ea216df2b563023da14f`. Only two iPhone source files differ. The shared tests cover the bounded civil-week range, both rebasing thresholds, a distant jump, the spring clock change and a week spanning two calendar years.

Thirteen focused iPhone simulator tests passed with zero skips, failures or runtime warnings. The native browse workflow moved from November back into October, forward through December into January, and then directly to March using Jump to Date. Today and the month arrows kept their existing meanings. Relaunch returned to November in saved Month mode. The saved fixture and settings matched their initial bytes. Adjacent tests covered zoom, Show Details, range continuations, both resize edges, a local task drop, recurring scope and restore, and range capture/recovery. The file audits confirmed the capture's November 6–11 inclusive dates, the new start and end dates on both resize fixtures, and exact preservation of other workspace records. The disposable simulators were removed.

The preliminary runs exposed ambiguous day numbers, unstable window shifts and competing scroll and edit gestures. The final build gives each date its full accessibility label, retains a visible week when shifting the buffer and holds the grid during range selection and endpoint resizing. The reference changelog establishes free vertical Month browsing. The buffer and zoom scope are Taskovsky choices. Narrow Month cards can still truncate titles. Physical-device and VoiceOver navigation checks remain open.


<a id="foreign-rich-paste-full-iphone-regression"></a>

### MOB-QA-011 — Full iPhone regression through foreign rich paste

Source manifest SHA-256 is `5ad5a236ace65e20cbb197e41a358f7c27c00f75cef59aa375d166e7890ce8ec`. The sealed source recorded 292 passes, 0 failures, 0 skips and 0 runtime warnings. The inventory retains all 281 prior tests and adds 11 covering Task Progress, Summary options and presets, and external HTML/RTF paste with synthetic clipboard fixtures. Later batch and Calendar display work used separate focused runs.

The file audit passed 80 baseline cases with 79 Mac reopens that made no writes. All 38 recorded audit groups passed. The disposable simulator was removed.


<a id="mobile-calendar-month-card-titles"></a>

### CAL-MOBILE-MONTH-TITLE-001 — Readable titles in compact iPhone Calendar cards

[Change contract](../changes/mobile-calendar-month-card-titles-2026-11-10.md). The source manifest SHA-256 is `97a20a59f2485c794d4a1d3d2586b4f372d636d9ca891ba84a15e7c01ca816ce`. All 665 Mac tests passed, and the release passed strict signature verification. The application change is in the iPhone presentation.

Ten focused simulator tests passed in light appearance with zero failures, skips or runtime warnings. The new workflow checked distinct card and grip targets, the full accessibility label and the correct task detail on tap in Month and Multi-Week. It passed again in dark appearance. The saved workspace bytes matched the initial fixtures in both appearances. Only switching from Month to Multi-Week saved a different mode. Adjacent tests exercised scrolling, zoom, details, drops, range capture and both resize endpoints. File audits confirmed the intended dates and unchanged unrelated records.

The R17 reference capture shows leading title text in narrow cards. The final screenshots show readable prefixes while retaining separate move and resize targets. Full titles remain available on the card's accessibility label and in task detail. Device and live VoiceOver checks remain open.


<a id="mobile-calendar-week-swipe"></a>

### CAL-MOBILE-WEEK-SWIPE-001 — Swipe between weeks on iPhone

[Change contract](../changes/mobile-calendar-week-swipe-2026-11-10.md). The iPhone source manifest SHA-256 is `c19249d98599bd4c35e7b121903c3006808ba329c93ecb467ad46c4f08b09cad`. Only the iPhone view and UI tests differ from the snapshot with 665 passing Mac tests and strict release signature verification. Mac verification manifest SHA-256 is `97a20a59f2485c794d4a1d3d2586b4f372d636d9ca891ba84a15e7c01ca816ce`.

Twelve focused iPhone simulator tests passed with zero failures, skips or runtime warnings. With one ruler, all seven days were visible. Swipes moved to the next and previous week, kept the vertical hour offset, and left vertical scrolling within the current week. With two extra rulers, the first swipe panned to Sunday, and a subsequent outward swipe paged to the next week. The swipe back returned to the previous week's trailing edge. Day and Multi-Day checks, a local task drop and Undo, both all-day resize edges, and drag-edge dwell passed.

The saved-file audits confirmed byte-identical tasks and settings for ordinary Week swipes and drag-edge dwell. The ruler workflow changed its explicitly saved visibility preference and the existing legacy alias for the first ruler. The source ruler list and adjacent settings bytes stayed intact. The exact resized dates and the restored schedule matched the fixture. The disposable simulator was removed. The reference changelog establishes the browse gesture and R20 establishes the one-ruler layout. The minimum column width and overflow behavior are Taskovsky choices. Physical-device, trackpad and right-to-left gesture checks remain open.


<a id="mobile-task-row-swipes"></a>

### TASK-MOBILE-SWIPE-001 — Quick actions from iPhone task rows

[Change contract](../changes/mobile-task-row-swipes-2026-11-10.md). The iPhone source manifest SHA-256 is `2d85b76b22249eb736dc97f592cd2a30286c70483f5d89455b50dbc1963f9e04`. The 665 Mac tests and strict release signature check used manifest SHA-256 `97a20a59f2485c794d4a1d3d2586b4f372d636d9ca891ba84a15e7c01ca816ce`. Mac inputs are source-identical.

Four focused simulator tests and ten neighboring workflow checks passed on the same binary, with zero failures, skips or runtime warnings. The focused tests covered both swipe directions, explicit taps, staged Schedule cancellation, Priority and Move, Complete, Reopen, Trash, Restore and task-detail Undo. The saved-file audit confirmed that Priority and Move changed only the selected task's priority, list and update timestamp. Completing, reopening, trashing and restoring the task left only the update timestamp changed. Settings were byte-identical in both workflows. The simulator was removed. The reference documents the action categories. The edge assignment and tap requirement are Taskovsky choices. Physical-device, VoiceOver and right-to-left checks remain open.

The same snapshot also passed the recurring Month reschedule, skip, Undo and relaunch test. [Full Month](../changes/mobile-calendar-month-scroll-2026-11-10.md) now holds its visible week while task detail, capture and schedule edits are active and while a schedule write or Undo is in progress. The saved-file audit matched the exact next occurrence, shifted reminder and unchanged settings. The task-list and task-detail action menus have separate accessibility identifiers. Conversion, duplication, archived-task Move, pinning, recoverable Trash and named purge passed. Batch edits changed only the selected records, and Month browsing left the workspace and settings byte-identical. The earlier full regression exposed one Month viewport failure and six menu-selection failures. All seven passed on this snapshot.


<a id="mobile-calendar-card-swipe"></a>

### CAL-MOBILE-CARD-SWIPE-001 — Swipe to open a recurring Calendar schedule

[Change contract](../changes/mobile-calendar-card-swipe-2026-11-10.md). The exact iPhone source manifest SHA-256 is `c98be5615327c8df593b5ac890077055915e13195eae7711ed8efcd62668efba`. Mac inputs match the snapshot with 665 passing Mac tests and strict release signature verification, manifest SHA-256 `97a20a59f2485c794d4a1d3d2586b4f372d636d9ca891ba84a15e7c01ca816ce`.

Eleven focused iPhone simulator tests passed with zero failures, skips or runtime warnings. A title swipe opened Schedule in Month and Agenda. The wrong direction, projected cards, nonrecurring tasks and terminal series did not open the editor. Month Cancel preserved the visible week and the exact fixture bytes. The title still opened task detail on tap and the context menu remained available. Agenda saved the next occurrence, restored the prior schedule through Undo and kept the saved next occurrence after relaunch. The selected checklist, grip and Tasks list workflows passed. Both Month resize handles still worked across week rows, and their saved ranges matched the expected civil dates. Saving and applying a styled task template passed on this snapshot after the older regression encountered the task-menu identifier collision. The Mac fixture reader verified the saved template workflow without writes.

The Agenda fixture kept the task ID and all unrelated fields and moved the manual reminder by the same seven days. Its sole settings change was the explicitly selected Agenda mode. The disposable simulator was removed. TickTick documents the right swipe and date popup. Taskovsky uses its own staged editor and direction mirrors in right-to-left layouts. Physical-device, right-to-left and VoiceOver gesture checks remain open.


<a id="mobile-task-schedule-skip"></a>

### TASK-MOBILE-SKIP-001 — Skip a recurrence from the iPhone Tasks schedule editor

[Change contract](../changes/mobile-task-schedule-skip-2026-11-10.md). The exact iPhone source manifest SHA-256 is `dedc11b03677cfff357e8e1a2428e91288f756eeb0b329ae3a6495a20156053e`. Mac inputs match the snapshot with 665 passing tests and strict release signature verification, manifest SHA-256 `97a20a59f2485c794d4a1d3d2586b4f372d636d9ca891ba84a15e7c01ca816ce`.

Eleven distinct focused iPhone simulator checks passed across two runs of the same application binary. The first run exposed two test issues. The relaunch test targeted the hidden All list, and the row test tapped a button partially covered by the home indicator. The second run used the fixture's Inbox and scrolled the entire button into view. All six rerun tests passed with zero failures, skips or runtime warnings. Only UI test source changed between runs, and both application executable hashes matched. The swipe and detail routes opened the same Schedule editor. Keep editing restored the draft time toggle. Cancel discarded the staged skip and the unsaved time change. A confirmed skip advanced the task and offered Undo. The detail path showed the new date after relaunch, and the terminal occurrence lacked the skip action. An injected write failure kept the stage retryable and left both files byte-identical. The Calendar, Board and Timeline schedule and Undo regressions and ordinary custom-repeat editing also passed.

The detail save moved the same task and manual reminder by seven days and preserved every unrelated field and setting. The swipe and Undo round trip left only the update timestamp changed. The disposable simulator was removed. The reference documents the swipe and date-popup action. Taskovsky uses its shared staged editor with separate Tasks and Calendar feedback. Physical-device and VoiceOver checks remain open.

<a id="mobile-calendar-month-titles-full-regression"></a>

### Earlier 304-test iPhone regression

The older Month-card title snapshot had 296 passes and eight failures. One failure followed a Month viewport shift after a recurrence move. The other seven hit the shared task menu identifier. All eight later passed in the focused [task-row swipe](#mobile-task-row-swipes) and [Calendar-card swipe](#mobile-calendar-card-swipe) snapshots. The older run remains recorded as failed.

Thirty-nine audit groups passed for the older run, including 75 round-trip file fixtures and 74 Mac reloads without writes. The separate failed-case audit confirmed byte-identical settings in all eight. Seven left their workspace files byte-identical. The Month case saved its intended one-occurrence move and protection format before the viewport failure. The disposable simulator was removed. The archived result SHA-256 is `c633e1639ee253baf344bfac314ad948c039f69e7b709422481dd65332b787f1`.


<a id="mac-task-skip-occurrence"></a>

### TASK-MAC-SKIP-001 — Skip a recurrence from Mac Tasks

[Change contract](../changes/mac-task-skip-occurrence-2026-11-10.md). The source manifest SHA-256 is `be5cad280cf16ed99b9453393bf1aa1c9afca83624178ee0eb38a56ebe830c30`. All 665 Mac tests passed, and the release passed strict signature verification on macOS 27.0.1 arm64. The guarded QA copy refused launch without the exact disposable paths. Copies of its executable and the release executable were byte-identical after removal of their local signatures.

The native row context menu and detail More actions opened a confirmation naming the task. Escape left the workspace and settings bytes unchanged. The detail command advanced the occurrence and offered Undo in the existing task toast. Undo restored the schedule and left only the selected task's update timestamp changed. A second skip from the row menu moved the same task's one-hour window and manual reminder by seven days. On relaunch the detail showed 17 November at 14:00 and its 13:30 reminder. Ordinary, archived and terminal tasks lacked the command. The terminal task was checked in both menus after relaunch. The stored task identity, unrelated decoded records and settings were preserved. Relaunch made no writes. The QA app was closed.

The reference documents the right-click command. Taskovsky adds the named confirmation, the task-detail shortcut and the existing five-second Undo behavior. The iPhone source and tests are identical to the previously verified snapshot, manifest SHA-256 `dedc11b03677cfff357e8e1a2428e91288f756eeb0b329ae3a6495a20156053e`. Mac dark appearance and VoiceOver were outside this native check.


<a id="foreign-html-paragraph-paste"></a>

### RICH-CLIPBOARD-004 — Preserve supported HTML paragraphs in pasted descriptions

[Change contract](../changes/rich-description-foreign-html-blocks-2026-11-10.md). The exact source manifest SHA-256 is `81e88718df8ee9af2d13b1f75815b067414f8e53b117f465f37fe317663af075`. All 669 Mac tests passed, including four new importer cases, and the Mac release passed strict signature verification. Five focused iPhone simulator tests passed with zero failures, skips or runtime warnings.

Mac native ordinary paste rendered a heading, quote, bullet and numbered list, and a three-paragraph code block with indentation and a blank line. Undo restored the old body, Redo restored the imported formatting and the formatted description reopened after relaunch without writing the files. Paste as Plain Text kept the same characters without styles. The iPhone workflow verified the two paste paths, Undo, Redo, Done and relaunch. Saved-file audits on both platforms confirmed exact text and paragraph ranges, the shared code block identity, the italic run, unrelated fields and byte-identical settings. Mac QA files, the prior guarded bundle and QA preferences were restored. Both disposable iPhone simulators were removed.

The iPhone simulator screenshot showed a replacement glyph for the heading emoji. The saved UTF-16 text was exact, and the Mac native capture rendered the emoji. Physical iPhone and VoiceOver were outside this check. The reference guide describes supported rich paste and editor formats. The semantic HTML mapping is a Taskovsky choice.


<a id="task-batch-postpone"></a>

### TASK-BATCH-002 — Postpone selected timed tasks

[Change contract](../changes/task-batch-postpone-2026-11-10.md). The tested source manifest SHA-256 is `37b01972ed034de5158a3d71a3f23acfb212e00a6c08963ea8005c0b8d815740`. All 671 Mac tests passed, including the new clock-change and source-filter cases. The Mac release passed strict signature verification. Five focused iPhone 13 Pro simulator tests on iOS 26.3 passed with zero failures, skips or runtime warnings.

On Mac, the Tasks selector reached the review stage and Cancel left the workspace and settings byte-identical. The Calendar selector showed two eligible Work tasks across different days and excluded the all-day Work task and timed Personal task. After Apply, the range moved from 13:00–14:00 to 14:00–15:00. The recurring task moved from 12:30 to 13:30, while its future Calendar previews stayed at 12:30. The iPhone tests covered the same source filter, the absence of Postpone for a mixed Tasks selection, Cancel, Apply and reopen. Neighboring batch metadata, Trash and Month navigation tests passed.

The saved-file audits confirmed the exact 3,600-second shifts, preserved range length, moved manual reminder, recalculated automatic reminder, preserved original recurrence schedule, unchanged unrelated fields and byte-identical settings. The prior Mac QA bundle and preferences were restored and the simulator was removed. The reference documents the action on Windows and web. The native selector and recurrence rules are Taskovsky choices.

<a id="docs-only-ci-filter"></a>
## Documentation-only CI filter — November 8, 2026

Requested change [CI-DOCS-001](../changes/skip-docs-only-ci.md) is based on main `6ee96eeb8f88e74a105c518de2202233ea528efa`, on separate branch `ci/skip-docs-only-updates`. The only workflow change adds identical `docs/**`, `README.md` and `AGENTS.md` exclusions to automatic PR/main-push events. This entry does not rewrite historical CI results above.

| Evidence | Result | Limits |
| --- | --- | --- |
| Local Python 3 / PyYAML 6.0.3 static acceptance | **Passed:** YAML parse, identical filter lists, structural comparison against base, and byte-for-byte equality from `permissions:` through the end of the workflow. All job steps, pins, manual dispatch, event types, branch restrictions, concurrency and permissions retained. | Linux cloud inspection, not a macOS test/build run or actionlint execution. |
| Event/path decision matrix | **Passed: 64 cases.** 28 path cases for each automatic event plus eight event/branch/manual cases. Covers nested docs, root README/AGENTS, evidence/assets, mixed source/workflow, source/test/build/resource/configuration paths, Markdown fixtures outside docs, case/prefix lookalikes, deletions and paired old/new rename paths. | A model of these simple patterns using the parsed workflow. Does not execute GitHub's diff construction or prove native rename handling, truncated diffs, queues or cancellation. |
| Documentation review | **Passed:** changed-document relative targets against the repository tree, whitespace and bounded diff scope. Current CI/workflow specifications and this change record updated. | Static documentation review is not runtime verification. |
| Repository policy reads | Main metadata reports unprotected, enforcement off and no required contexts; ruleset list empty. Detailed protection read returned integration-access 403. No settings write attempted. | Recheck before future required-check/merge-queue configuration. |
| Hosted workflow for final PR head | **Pending:** inspect this draft PR's checks and record its exact head, synthetic merge checkout and run URL in the PR description. The workflow file itself is a non-ignored change, so this PR must run full CI. | Application tests/build/signature/archive are not claimed passed until the exact run completes. |

Live documentation-only skipping, manual dispatch, main-push filtering, rename events, oversized diffs and merge queues are **not exercised** by the local matrix. No temporary PRs or changes to the existing iPhone PR were created for filter probes. No local macOS build, app execution or native UI checks were run. The new filter does not cancel existing runs or alter branch protection. See [CI-002](ci-cd.md#ci-002) for the operational contract and native limits.


<a id="task-duration-end-reminders"></a>

### TASK-REMINDER-001 — Timed duration end reminders on Mac and iPhone

[Change contract](../changes/task-duration-end-reminders-2026-11-10.md). The combined local verification branch starts from merged main `36a9e17ad1fac20e7d0c32eb5507f7d22b69b4b8` and carries forward the batch capture checkpoint. The 172-input source manifest SHA-256 is `f2a4b88f6abcebd02a2b7d84fbcbf657ac816103b2339b27e99c7f365eebfdca`. All 685 Mac tests passed on macOS 27.0.1 and the release passed strict signature verification. Five checks on the iPhone 13 Pro simulator with iOS 26.3.1 passed without failures, skips or runtime warnings.

Mac native QA staged the end reminder and pressed Escape. The workspace and settings matched their original bytes. Saving showed the 10:30 reminder in task detail. Tomorrow moved the range and the reminder to the following day. Dragging the Calendar end to 11:00 left the start at 09:00. Undo restored the 10:30 end, and the task still showed its 10:30 reminder after relaunch. Saved-file checks confirmed that the end anchor was present without a second stored reminder date, settings bytes matched, and unrelated records matched after accounting for default-field serialization.

The iPhone simulator verified cancelling the staged toggle, enabling it, relaunching and seeing the saved end time, and hiding the toggle when staging duration removal. A separate run in the same result bundle covered the existing manual reminder editor and Calendar start resize with Undo. The saved file retained only the new reminder preference and modification timestamp on the selected task, with its duration and settings intact. The shared and repository tests covered duplicate reminder instants, preserving manual dates on detail edits, following Calendar endpoint changes, protected file round trips, scoped Undo, and the next recurring occurrence.

The guarded Mac app, preferences and fixture files were restored. The disposable iPhone simulator was removed. Physical-device and notification-delivery verification remain outside this local feature. [TickTick reminder guide](https://help.ticktick.com/articles/7055782395743567872).

The feature-only Git branch was independently verified from the same main revision. Its 167-input source manifest SHA-256 is `ad92d90c0df8e90cf8d202e7d31c36404b99edffa0e5bd4c68bbc0d1b49b3db7`. It passed all 674 Mac tests, the signed release verification and five iPhone simulator checks without runtime warnings. Its saved-file audit confirmed the protected reminder preference and byte-identical settings.

<a id="task-countdown-labels"></a>

## Task countdown labels — November 10, 2026

[Change contract](../changes/task-countdown-labels-2026-11-10.md). Feature-only branch `codex/task-countdown-labels` starts from merged `main` at `36a9e17ad1fac20e7d0c32eb5507f7d22b69b4b8`. The 168-file source manifest has SHA-256 `5c8170b2e54b7181e992c81a2b69b7f8cf1c63496d32acb06504575ace63f9f4`.

| Evidence | Result |
| --- | --- |
| macOS 27.0.1, Xcode 27.0 | **672 passed** across all Swift package test suites. `scripts/build-app.sh` and strict `codesign` verification passed. |
| Native Mac QA | **Passed.** More → Show Countdown displayed `20m left` and `1 day overdue` in Today. The note and completed row kept their ordinary dates. Hide Countdown restored the two fixture dates. The choice survived quitting and relaunching. The live label changed to `19m left` without input. Both fixture files stayed byte-identical, and the prior guarded app and preferences were restored. |
| iPhone 13 Pro simulator, iOS 26.3.1 | **4 passed.** Covered enabling and cancelling the setting, toggling a date separately from detail navigation, relaunch behavior, ordinary Settings saves and row swipe actions, and shared deadline math. The countdown-only test left both fixture files byte-identical. The disposable simulator was removed after inspection. |

The shared unit test covers recalculation with a shifted clock, civil-day counting across daylight saving, a timed deadline across midnight and overdue display. The native pass used the Tasks list accessibility tree. Option-key precedence was checked in source. Other native destinations, VoiceOver and dynamic type were outside this pass.

<a id="rich-list-continuation"></a>

## Saved rich description lists — November 10, 2026

[Change contract](../changes/rich-list-continuation-2026-11-10.md). The feature-only branch starts from merged `main` at `36a9e17ad1fac20e7d0c32eb5507f7d22b69b4b8`. The 167-file source manifest has SHA-256 `b26a87c4ffc487d8d1ad6fb86c18aae939f6c1819b4550461b2c2032da0cd198`.

| Evidence | Result |
| --- | --- |
| macOS 27.0.1, Xcode 27.0 | **672 passed.** The shared regression covers bullets, numbering, checked state, exact Unicode and CRLF, first typing into a blank terminal item and exiting a blank item. Release build and strict signature verification passed. |
| Guarded native Mac | **Passed.** Return split a loaded numbered item, rendered 1–3 and preserved the bold span. In a separate saved checklist, Undo and Redo restored the checked original and the new unchecked item. Two Returns exited the list before plain prose. The guarded bundle and settings were restored. |
| iPhone 13 Pro simulator, iOS 26.3.1 | **5 passed.** The test saved a checked item, relaunched, continued it with an unchecked item and exited into plain prose. Existing checklist toggle, typed Markdown and code fence workflows passed. The disposable simulator was removed. |
| Saved fixture audit | Both platforms wrote the exact expected description text and rich ranges. Other records were semantically equal after accounting for decoded default fields. Both settings files were byte-identical. |

The first test pass exposed an end-of-document boundary guard that rejected Return at the last saved character. The recorded results use the corrected source. Native iPhone verification covered the end-of-list continuation, and the Mac pass covered the split within a numbered item. Physical iPhone and VoiceOver checks remain open.

<a id="list-emoji-icons"></a>

## Local list emoji icons — November 10, 2026

[Change contract](../changes/list-emoji-icons-2026-11-10.md). The feature branch starts from merged `main` at `36a9e17ad1fac20e7d0c32eb5507f7d22b69b4b8`. The Mac QA source manifest SHA-256 is `ce4163d6c34ea841be1434e5595793fd469d206250386e89a74f15616c59defb`. The final 167-file manifest SHA-256 is `ff8ed214d2c57f62bcaebe56813852a309ec38ef29e1a5cab89e1746ec48f98c`. Only the iPhone icon renderer changed between these manifests.

| Evidence | Result |
| --- | --- |
| macOS 27.0.1, Xcode 27.0 | **672 passed.** Release build and strict signature verification passed. Shared cases include a joined skin-tone emoji, flags, keycaps, ordinary digits, emoji-only names, legacy names and explicit system icon choices. |
| Guarded native Mac | **Passed.** Creating `👩🏽‍💻 Lab` showed `Lab` with the emoji in the sidebar. Reopening the editor showed the exact custom glyph. Resetting to the default icon and renaming to `🏳️‍🌈 Project Lab` saved `Project Lab` and rendered the flag. The prior QA app and preferences were restored. |
| iPhone 13 Pro simulator, iOS 26.5 | **3 passed.** Native tests covered name promotion, rejecting ordinary text as an emoji, discarding a replacement, saving it, relaunching and retaining existing folder workflows. `iphone-list-emoji.png` shows the joined emoji in one drawer icon slot. |
| Saved fixture audit | Both platforms stored exactly one new list with the expected name and exact UTF-16 icon. Other workspace records were semantically identical after known default-field normalization. Both settings files were byte-identical. |

On the iOS 26.3.1 simulator, persistence checks passed while the first screenshots showed placeholders. An independent Core Text probe returned only glyph 4 even when Apple Color Emoji was explicitly selected. The same probe on iOS 26.5 produced a single glyph for the joined emoji, and the final app screenshot confirmed it. The renderer reserves a bounded icon slot. No physical iPhone was available for this pass.

<a id="calendar-year-day-preview"></a>

## Calendar Year day preview — November 10, 2026

[Change contract](../changes/calendar-year-day-preview-2026-11-10.md). The feature branch starts from merged `main` at `36a9e17ad1fac20e7d0c32eb5507f7d22b69b4b8`. The 167-file source manifest SHA-256 is `fbd647b0742d472e2d77a0d10a24f8cc7601be527f23666b13d6cd6c381b9363`.

| Evidence | Result |
| --- | --- |
| macOS 27.0.1, Xcode 27.0 | **672 passed.** The shared case covers the final hour of a 25-hour day, the next-day boundary, saved list scope, completed items, forecasts and checklist visibility. Release build and strict signature verification passed. |
| Guarded native Mac | **Passed.** The Year context menu opened an empty date. Escape returned to Year. The date accessibility action opened a populated date under the Work-only filter and excluded Personal. Done returned to Year. A later date displayed its repeat as a Forecast. Open Week navigated to it, and ordinary date clicks still opened Week. |
| iPhone 13 Pro simulator, iOS 26.5 | **3 passed.** Verified empty and populated previews, dismissal without losing the Year position, explicit Week navigation and existing View Options persistence. `iphone-year-day-preview.png` records the populated preview. |
| Saved fixture audit | Mac task and settings files were byte-identical before and after the previews. Explicit Week navigation changed only the Calendar mode value. The iPhone workspace stayed byte-identical, and the final settings matched the original values after navigating Year → Week. The previous Mac QA app and preferences were restored, and the disposable simulator was removed. |

The native checks cover the default Year layout and the recorded fixtures. Compact split panes, large iPhone text sizes and physical iPhone gestures were outside this pass.

<a id="calendar-letter-shortcuts"></a>

## Mac Calendar letter shortcuts — November 10, 2026

[Change contract](../changes/calendar-letter-shortcuts-2026-11-10.md). The isolated branch `codex/calendar-letter-shortcuts` starts from merged `main` at `3c1204a14eccef61c2ff80c523a8fc53e1f4e558`. The source manifest for the build has SHA-256 `86a238c3e726bfbf53f8b24a0793b75d16a00524787892ba5796fcf57c14fb2d`. The Mac view source has SHA-256 `6f947950ff8a412f89c3d515189905406ee4727df08db7359c23b8efa0f8c190`.

| Evidence | Result |
| --- | --- |
| TickTick 8.2.20 build 922 on Mac | The selector advertised the five key pairs. From Month, W → Week, Y → Year, D → Day, A → Agenda and M → Month each changed the toolbar and view. Returned to Tasks with Month as the Calendar selection. |
| macOS 27.0.1, Xcode 27.0 | **678 passed.** Release build and strict signature verification passed. |
| Guarded native Mac | All five letter keys and all five number keys selected their advertised modes. Shift-M left Day selected. The Calendar task title received all ten characters, and Escape cancelled the draft with Day still selected. In the compact Tasks split, Y left Day selected and the selector omitted key hints. Tasks quick entry received all ten characters. |
| Saved fixture and restoration | W saved Week after returning to full Calendar. The workspace file was byte-identical. Calendar mode was the only changed value relative to the previously normalized settings for this fixture. The previous guarded app and its preferences were restored. |

The change touches only the Mac Calendar view. This pass covers the recorded keyboard interactions and saved settings file. It does not cover other keyboard layouts, a process relaunch after the shortcut, or iPhone execution.

<a id="mobile-calendar-arrange-drag"></a>

## iPhone Calendar Arrange drag — November 10, 2026

[Change contract](../changes/mobile-calendar-arrange-drag-2026-11-10.md). The isolated branch `codex/iphone-calendar-arrange-drag` starts at `3c1204a14eccef61c2ff80c523a8fc53e1f4e558`. The final 162-file build-input manifest has SHA-256 `5bce1225f572057e57dd6d32650b536c21ca32b1adbb4de40b6686d55c541d4e`.

| Evidence | Result |
| --- | --- |
| iPhone 13 Pro simulator, iOS 26.5, Xcode 27.0 | **Six workflows passed across two runs.** Day accepted an all-day drop and Undo, ignored an outside release, then saved a timed drop that appeared after relaunch and navigation back to the target day. Month and Multi-Week accepted visible date drops and Undo. Existing Arrange scoping and precise editing, Month card dragging and recurring Calendar card dragging passed. |
| Recurrence and cancellation | The Arrange scope chooser showed This occurrence, Series and Cancel. Cancel kept the panel, overdue filter and original task available. The second drop saved This occurrence. Five tests passed in the first run of this app build. The sixth passed after changing its assertion from the generic notice to the existing “This occurrence updated” message. The app build inputs were identical across those two runs. |
| Saved fixture audit | The timed task saved November 10 at 07:30–08:00 Europe/Moscow with its existing list and priority. The recurring record saved November 10 and retained its November 8 baseline. Day settings stayed byte-identical. Both date-grid Undo operations restored the undated task with only its modification timestamp advanced. The only date-grid settings change was the selected mode. Unrelated workspace records matched in all three audits. The disposable simulators were removed. |

The tests exercise drag from Arrange in Day, Month and Multi-Week. Week and Multi-Day reuse the hourly drop path. Physical-device and VoiceOver gestures remain outside this run.

<a id="iphone-manual-task-order"></a>

## iPhone manual task order — November 10, 2026

[Change contract](../changes/iphone-manual-task-order-2026-11-10.md). The isolated branch `codex/iphone-manual-task-order` starts at `3c1204a14eccef61c2ff80c523a8fc53e1f4e558`. The final 170-file build-input manifest has SHA-256 `ff457eeb89020594a3bd91dfcc3b21432bc2ccae2e993a7fa005986fd1996200`. The earlier manifest, SHA-256 `970c9d1f42c328644c12dda6678cf7c20ea1817820334468e68bda8f45e7fc8a`, differs only in the later iPhone section test.

| Evidence | Result |
| --- | --- |
| iPhone 13 Pro simulator, iOS 26.5, Xcode 27.0 | **Five workflows passed across two runs.** A drop before a Work row reordered it, a pinned-boundary drop preserved order, and switching to a computed sort hid the reorder grips. Returning to Default Order and relaunching both restored the saved order. In a sectioned list, the lower drop half moved a row after its sibling, a cross-section row drop preserved membership, and creation grouping suspended manual reorder. Existing timestamp sorting, creation grouping and Board section moves passed. The section test’s initial layout assertion assumed named sections preceded No Section. The rerun compared each row to the actual section heading. |
| Saved iPhone fixtures | Both fixtures changed only array order. Tasks, rich descriptions, timestamps, pin and section fields and unrelated records matched their controls. The section comparison matched the generated section IDs between sessions. Settings were byte-identical. |
| macOS 27.0.1, Xcode 27.0 | **680 tests passed**, including existing Mac batch reorder, duplicate stored ID refusal, and the workspace test for pinned, history, sibling and stale boundaries. The release build passed strict signature verification. |
| Guarded Mac smoke check | The release opened the Work fixture and exposed the manual reorder grip. Pointer drag attempts left order unchanged. The fixture workspace and settings were byte-identical, and the prior guarded app and its preferences were restored. Native Mac drop behavior remains unconfirmed in this run. |

The simulator checks cover the named fixtures and touch workflows. The Move earlier and Move later accessibility actions still need a VoiceOver interaction check.

<a id="template-search-order"></a>

## Local template search and order — November 10, 2026

[Change contract](../changes/template-search-order-2026-11-10.md). The feature was verified in isolation from `main` at `3c1204a14eccef61c2ff80c523a8fc53e1f4e558`.

| Evidence | Result |
| --- | --- |
| macOS 27.0.1, Xcode 27.0 | **679 tests passed.** The workspace test covers accent-insensitive matching, stale and invalid reorders and exact preservation of template records. The release build and strict signature check passed. |
| Guarded Mac UI | Search matched template descriptions in Settings and Apply Template and a checklist item in capture. Filtering hid the reorder grips. The card menu saved a new order and capture showed that order. Two pointer drag attempts left order unchanged, so Mac drag remains unconfirmed. |
| iPhone 13 Pro simulator, iOS 26.5, Xcode 27.0 | **Four workflows passed across two runs.** Manager search filtered by description, then native row dragging saved an order visible after relaunch. Capture found a checklist match and applied its title to the draft. The styled capture, styled Apply Template and plain manager workflows also passed. The rerun scrolled back to the title after returning from the capture picker. |
| Saved fixtures | The Mac order changed through the card menu and all template and other workspace records matched exactly. The iPhone order changed through native drag. Both phone sessions matched after comparing templates by name and excluding independently generated template and checklist IDs. Other workspace records matched and settings were byte-identical on both platforms. The previous guarded Mac app and preferences were restored. |

Physical iPhone and VoiceOver interactions are outside this run.

Final source-manifest SHA-256 `b1e0cc1f1133e75a96df5965e0cec6a0c031878fe68b199f49f7a49717f18e92`. Guarded Mac manifest SHA-256 `752d9ab6250dc5338023ff32902ceb647d84736163157d2c4ee490985e484f41`, captured before the later iPhone-only changes.

### Mac pointer follow-up on merged main

The signed Mac app from [PR #24 CI](https://github.com/Mental-NV/Taskovsky/actions/runs/42810287633) matches the source tree merged at `aba0b9b78a2b6af3dede10542234ba3eed0bc805`. In the guarded app, dragging Travel bag by its grip onto the open lower portion of the Weekly setup card moved Travel bag to the middle. Releasing outside the card grid preserved the new order. The saved workspace changed only in template order. Template IDs and values, unrelated workspace records and settings matched the fixture. The previous guarded app, preferences and disposable fixture were restored. Source-manifest SHA-256 `739579adb07c281ce836c591607bf4eca92d9f8f137504ab402ad48852419aa0`.

<a id="calendar-source-colors"></a>

## Local Calendar source colors — November 10, 2026

[Change contract](../changes/calendar-source-colors-2026-11-10.md). The isolated `codex/calendar-source-colors` branch starts from `main` at `aba0b9b78a2b6af3dede10542234ba3eed0bc805`. The source manifest has SHA-256 `bccb1b7d4314812aba0e2d7d0e1335c329408f6d1365402274be0ad5ae4ee57e`. The guarded Mac manifest has SHA-256 `6d68d498e236d223b55c8051da089fe79697cd9f505ff6584e1b40db1a6dc714`.

| Evidence | Result |
| --- | --- |
| TickTick 8.2.20 build 922 on Mac | View Options → Color showed List mode with swatches for Inbox and named lists. The prior list view was restored. No reference color was edited. The official guide documents editing both list and tag swatches. The effect on list and tag colors outside Calendar remains unverified. |
| macOS 27.0.1, Xcode 27.0 | **683 tests passed.** New cases cover round trips, Inbox/list/tag resolution, priority colors, invalid input and stale or failed Mac writes. The workspace preference test exercises the existing settings patch with a color override and preserves adjacent fields. The release build and strict signature verification passed. |
| Guarded native Mac | The editor aligned the Inbox and active-list swatches. Invalid hex disabled Apply. A valid hex color staged successfully and Cancel discarded it. Saving a preset recolored timed and all-day Calendar Work cards. Default restored the draft color, and cancelling that reset kept the saved preset. |
| iPhone 13 Pro simulator, iOS 26.5, Xcode 27.0 | **Three workflows passed on the final build.** The system picker saved an Inbox color, relaunch showed it, a cancelled reset kept it and a confirmed reset removed it. Priority hid the customization link, and Tag accepted a custom Planning color. The existing View Options persistence and failed-save retry workflows also passed. |
| Saved files and restoration | Mac and iPhone workspace files were byte-identical to their controls. The Mac save retained the seed's existing settings values and encoded defaults omitted by the seed. The iPhone comparison found only color preference changes after treating Smart List visibility pairs as an unordered dictionary. The original guarded Mac app and preferences were restored and the disposable iPhone simulator was removed. |

Physical iPhone, dark appearance, VoiceOver and other Calendar modes were outside the new native color checks.

<a id="iphone-task-action-layout"></a>

## iPhone Task Actions layout — November 10, 2026

[Change contract](../changes/iphone-task-action-layout-2026-11-10.md). The isolated `codex/iphone-task-action-layout` branch starts from merged `main` at `aba0b9b78a2b6af3dede10542234ba3eed0bc805`. The final iPhone source manifest has SHA-256 `a0e806d0ab74755026d2875a5f84db852aadb0bb4e4a53347ec0977c0fcc37b0`.

| Evidence | Result |
| --- | --- |
| TickTick guide | The [Task Details guide](https://help.ticktick.com/articles/7055782408586526720) documents the More → Edit interaction and the pin, unpin and drag controls. R04 shows the Edit entry. No new reference app interaction was needed. |
| iPhone 13 Pro simulator, iOS 26.5, Xcode 27.0 | **Four workflows passed on the final build.** A native grip moved Move to List ahead of Complete. Duplicate moved to More and the layout survived relaunch. Plus put Duplicate back in the pinned draft. Cancel kept the saved layout and Restore Defaults with Done restored the original placement and order. Duplicate from More opened the independent styled copy and its copied child. The named Trash confirmation and existing styled template workflow passed. |
| Saved fixture audit | The layout-only session's workspace and settings files were byte-identical to their seeds. Reset removed the active layout. A separate QA session stored Duplicate in More under its own preference key. The copy's rich body matched the original and its child had an independent ID. The disposable simulator was removed. |

The drag check exercised Pinned. The native More-section reorder control, VoiceOver and physical-device touch are outside this verification pass.
