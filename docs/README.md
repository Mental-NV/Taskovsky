# Taskovsky parity specifications

Start with the [parity workflow](spec/workflow.md). The active scope is local **Tasks and Calendar** on **macOS and iPhone**, with light appearance first. The workflow owns delivery order and deferrals.

| Question | Canonical answer |
| --- | --- |
| What does the checkout actually implement? | [Source and baseline](current-baseline.md); inspect the exact revision. |
| What should the feature do? | [Shared business behavior (BUS)](spec/business.md). An approved change defines a future delta. |
| How should it look and behave on each platform? | [macOS UI/UX (UX)](spec/ui-ux.md) · [iPhone UI/UX and limits (IOS)](spec/iphone.md). |
| What did TickTick actually do? | [Desktop and iPhone reference index](ticktick-spec/README.md); observations are evidence, not product decisions. |
| What is still missing? | [Feature parity (TT)](parity-implementation-status.md) · [46-state iPhone visual tracker (C/D/T)](mobile-visual-parity.md). These measure different things. |
| How do I make and verify a change? | [One change record](spec/change-template.md) under `docs/changes/` · [Verification ledger](spec/verification.md) · [CI rules](spec/ci-cd.md). |
| Where are design boundaries or old decisions? | [Shared engine](architecture/shared-engine.md) · [Components](architecture/components.md) · [Historical archive](archive/README.md). |

For one feature, read only the applicable BUS rule, platform contract, tracker row and reference evidence. Record the intended delta and tests once in the change record; link to it rather than repeating it in every document.
