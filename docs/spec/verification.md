# Baseline evidence and known deviations

## Snapshot and evidence levels

Source baseline: [`cfdec454acff91285ac00beaa20c0cf0f0961ee1`](https://github.com/Mental-NV/Taskovsky/commit/cfdec454acff91285ac00beaa20c0cf0f0961ee1), inspected November 8, 2026. This is main after [PR #2](https://github.com/Mental-NV/Taskovsky/pull/2) merged; its implementation head is [`b9de0dfe4522a818c5d08674dfbe04a396ad330a`](https://github.com/Mental-NV/Taskovsky/commit/b9de0dfe4522a818c5d08674dfbe04a396ad330a). PR #1 retains its documentation structure while incorporating that baseline. Application source, tests, fixtures, build/package files and dependencies are identical to main in the resulting documentation tree.

| Evidence | What it establishes | Limit |
| --- | --- | --- |
| Exact merged source and regression files | Implemented Calendar behavior and corrective code paths | Static inspection is not runtime execution |
| [Final PR #2 correction report](../pr-2-calendar-review-findings-2026-11-08.md#verification-after-fixes) | Prior reported 464 tests passed (430 XCTest + 34 Swift Testing), release build and strict codesign verification | Not rerun for this documentation task; logs are in ignored local build directories, not durable CI artifacts |
| [Calendar verification history](../ticktick-spec/calendar.md#verification-status--8-november-2026) | Earlier 453-test snapshot and bounded isolated live checks, followed by final 464-test correction evidence | Earlier totals are historical stages, not separate current gates; UI checks span release and identified debug fixtures |
| [Earlier review resolution](../code-review-findings-2026-11-08.md) | Reminder/cadence/editor regressions and selected live nested-Cancel/Quote checks | Native app Undo/Redo, quote/list switching and live paragraph-selection reproduction were not verified |
| TickTick observations/resource extract | Bounded reference UI/action/structure evidence | Not recovered scheduling algorithms or blanket parity |
| Proposed architecture, iPhone and CI contracts | Intended future design | No implementation or successful workflow run implied |

This documentation refresh ran no Swift suite, macOS build, native UI session or new TickTick experiment. Its verification is static source review, Markdown links/anchors, whitespace and exact documentation-only tree comparison. No `.github` workflow or separate native UI-test target exists in the merged baseline. The [CI proposal](ci-cd.md) describes how to add hosted macOS verification in a separate implementation change.

<a id="known-deviations"></a>
## Review deviations and merged resolutions

Stable IDs are retained. These original source findings are fixed in the merged baseline; original reports are preserved rather than rewritten. “Fixed” here means corrective source and regression evidence are present, with prior execution reported below, not that this documentation task independently reran every acceptance case.

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

Record requirement/case ID, platform, exact source/checkout SHA, test or manual procedure, environment, fixture, command, date, result (`passed`, `failed`, `not run`) and durable artifact. A GitHub PR event may test a synthetic merge SHA rather than its head; record both explicitly. Prior local results and a future CI run are distinct evidence.

Visual records additionally need OS, logical content versus frame size, screenshot scale, appearance, locale/zone, text size, contrast and reduced motion. Use disposable data and cover interruption/repeated actions. The source-derived baseline remains **implemented, not independently runtime-verified by this documentation refresh**. Preserve live limitations even when unit/store checks pass.
