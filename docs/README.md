# Taskovsky documentation

Taskovsky uses separate documents for product behavior, platform UI, implementation architecture, and TickTick comparison. Begin here before asking an agent to implement a feature.

## Current baseline and authority

The baseline is the source at [`30045bac5355b793a8c155b87ffe58584cb29fb8`](https://github.com/Mental-NV/Taskovsky/commit/30045bac5355b793a8c155b87ffe58584cb29fb8), inspected on November 8, 2026. Source is the authority for what currently exists. Tests are evidence of intended cases, not evidence they passed. No app launch, build, test execution or fresh TickTick experiment was performed for this reconciliation.

A source-derived behavior can still be a bug. Known deviations are recorded separately instead of quietly being turned into desired requirements. The [five prior static findings](code-review-findings-2026-11-08.md) are not fixed by these documents. Another implementation workstream owns fixes.

For future work, an explicitly approved change specification defines the intended delta. If that proposal, code, and baseline disagree, record the mismatch and resolve the product decision before changing behavior. TickTick observations and archived progress reports never override Taskovsky requirements.

## Read by purpose

| Purpose | Canonical document | Status |
| --- | --- | --- |
| Understand business behavior and rules | [Business specification](spec/business.md) | Source baseline |
| Reproduce macOS appearance and interactions | [macOS UI and UX](spec/ui-ux.md) | Source baseline, visual verification outstanding |
| Track progress against TickTick | [Feature parity tracker](parity-implementation-status.md) | One current comparison ledger |
| Prepare shared code for a second native interface | [Shared engine architecture](architecture/shared-engine.md) | Proposal, not an extraction already made |
| Develop and test a component independently | [Component contracts](architecture/components.md) | Current boundaries plus proposed extraction |
| Design the iPhone interface | [iPhone proposal](spec/iphone.md) | Proposal, no iOS app implemented |
| Ask an AI agent to implement a feature | [Workflow](spec/workflow.md) and [change template](spec/change-template.md) | Working process |
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
