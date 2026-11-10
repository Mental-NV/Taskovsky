# Taskovsky documentation

Taskovsky uses separate documents for product behavior, platform UI, implementation architecture, and TickTick comparison. Begin here before asking an agent to implement a feature.

## Current baseline and authority

The baseline is the source at [`cfdec454acff91285ac00beaa20c0cf0f0961ee1`](https://github.com/Mental-NV/Taskovsky/commit/cfdec454acff91285ac00beaa20c0cf0f0961ee1), inspected on November 8, 2026. Source is the authority for what currently exists. Test files alone are evidence of intended cases, not evidence they passed. The follow-up [macOS CI implementation](spec/ci-cd.md) supplies fresh automated test/build results; exact checkout/run evidence is in the [verification ledger](spec/verification.md). No new interactive app session or TickTick experiment was performed for this reconciliation.

A source-derived behavior can still be a bug. Known deviations are recorded separately instead of quietly being turned into desired requirements. The baseline includes [merged PR #2](https://github.com/Mental-NV/Taskovsky/pull/2): local Calendar plus fixes for the [five earlier findings](code-review-findings-2026-11-08.md) and [four Calendar findings](pr-2-calendar-review-findings-2026-11-08.md#resolutions--8-november-2026). The documentation records those merged fixes. Follow-up CI reruns existing regressions; a separately approved `TaskDetail` view-section extraction addresses a compiler limit without changing intended behavior, as recorded in the verification ledger.

The Calendar display follow-up in [PR #3](https://github.com/Mental-NV/Taskovsky/pull/3), source head `13a3a486153fc1217f6228cb8e6cd8266dffb366`, adds named secondary rulers, Year styles and item-icon visibility to this baseline while retaining main `b4216dec6ee2d95471038cf41ca6f92efcb94039` documentation, CI and the TaskDetail refactor. Prior local results and pending final integration CI are distinguished in the verification ledger. See the [display investigation](calendar-gap-investigation-2026-11-08.md) and [verification ledger](spec/verification.md#calendar-display-follow-up). No new native checks were run during the cloud integration.

For future work, an explicitly approved change specification defines the intended delta. If that proposal, code, and baseline disagree, record the mismatch and resolve the product decision before changing behavior. TickTick observations and archived progress reports never override Taskovsky requirements.

The later local [Calendar visual follow-up](changes/calendar-visual-parity-2026-11-08.md) is uncommitted on `codex/calendar-visual-parity`, based on merged PR #3 at `f85e2f6`. Its [comparison](calendar-visual-parity-audit-2026-11-08.md) and [verification](spec/verification.md#calendar-visual-follow-up) record fresh native checks, 471 passing tests and a signed release build, with remaining differences and unverified cases explicit. Historical baseline/CI statements above describe their original checkouts.

The subsequent [Tasks/Calendar comparison](tasks-calendar-comparison-2026-11-09.md) reconciles official guides with installed Mac behavior. Local source selection, Year navigation and four additional rulers are corrected on that same preserved working tree. [Latest verification](spec/verification.md#calendar-source-follow-up): 485 passing tests, signed release and bounded native checks; no commit/push or mobile implementation in this Desktop checkout.

The isolated mobile follow-up is based on merged PR #4 at `6ee96ee`, with the verified Desktop Calendar implementation explicitly integrated and preserved by hash record. [Mobile foundation](changes/mobile-foundation-2026-11-09.md) and [read-only preview](changes/mobile-preview-2026-11-09.md) are partial implementations; [local field editing](changes/mobile-local-editing-2026-11-09.md) now connects persistent app-container files, protected title/plain-body edits and resumable scratch drafts. [Local capture](changes/mobile-capture-2026-11-09.md) adds task/note creation and saved-template instantiation with durable retry and recovery. The phone now shares Mac lifecycle rules for status, pinning, movement and Trash. [Local scheduling](changes/mobile-task-scheduling-2026-11-09.md) adds staged schedule editing from Tasks and Calendar with shared duration, reminder and recurrence rules. The verification ledger separates Mac, simulator and file checks from open Calendar gestures, organization, accessibility and device work. [Current mobile evidence](spec/verification.md#mobile-task-scheduling). The original dirty Desktop checkout remains untouched.

## Read by purpose

| Purpose | Canonical document | Status |
| --- | --- | --- |
| Understand business behavior and rules | [Business specification](spec/business.md) | Source baseline |
| Reproduce macOS appearance and interactions | [macOS UI and UX](spec/ui-ux.md) | Source baseline, visual verification outstanding |
| Track progress against TickTick | [Feature parity tracker](parity-implementation-status.md) | One current comparison ledger |
| Prepare shared code for a second native interface | [Shared engine architecture](architecture/shared-engine.md) | Partial Domain/Workspace extraction; remaining command/editor seams proposed |
| Develop and test a component independently | [Component contracts](architecture/components.md) | Current boundaries plus proposed extraction |
| Design and implement the iPhone interface | [iPhone specification](spec/iphone.md) | Local creation, field editing, lifecycle, task schedules and Calendar views. Direct Calendar gestures and other capability gates remain open. |
| Ask an AI agent to implement a feature | [Workflow](spec/workflow.md) and [change template](spec/change-template.md) | Working process |
| Run hosted macOS testing | [macOS CI](spec/ci-cd.md) | Implemented on this PR branch; tests/build/package checks, no deployment |
| Check evidence and known deviations | [Verification ledger](spec/verification.md) | Static evidence and open verification |
| Understand reference observations | [TickTick research](ticktick-spec/README.md) | Dated evidence, not Taskovsky requirements |
| Find older research and status narratives | [Archive](archive/README.md) | Historical, non-authoritative |
| Understand this cleanup | [Documentation disposition](documentation-disposition.md) | Migration record |

## Requirement labels

- `BUS-*`: business behavior.
- `UX-*`: macOS UI and interaction contracts; each platform document defines its own additional labels.
- `TT-*`: comparison rows, not implementation requirements by themselves.
- `DEV-*`: known deviations and the required verification before closure.
- Architecture/component labels are defined beside their contracts.

Keep these labels stable once referenced. A change can touch several contracts; link them rather than duplicating their content. Component and iPhone proposals must be explicitly selected for implementation before future agents treat them as assigned work.


