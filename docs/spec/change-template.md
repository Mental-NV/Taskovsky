# Feature change template

Copy this template only for an actual requested change. Place the result under `docs/changes/` and replace every placeholder before marking it approved. This file does not itself propose a feature.

## Identity and decision

- Change ID and title:
- Status: Proposed / Approved / In implementation / Implemented, verification pending / Verified / Integrated / Deferred.
- Owner or requesting instruction:
- Approval source and date:
- Base commit and affected platforms:
- Related business, UI, component, parity and deviation IDs:

## Outcome and scope

Describe the user outcome, what changes, and what explicitly remains unchanged. List exclusions. Separate product decisions from TickTick observations or assumptions.

## Current behavior and intended delta

Link the current source symbols and relevant contract. Describe each changed rule, input, output, side effect and failure result. Mark unknowns rather than guessing. Identify known defects this change is authorized to address; unrelated defects remain out of scope.

## Data and component contract

Specify persisted state, optional/unknown fields, versions, backward compatibility, migration and rollback. State command ownership, component input/output, cancellation and conflict behavior, service dependencies and platform adapters. For limited clients, state exactly which unsupported content survives reads, edits, copy, undo, save and reload.

## UI and UX contract

For every affected component or screen record:

| Aspect | Required detail |
| --- | --- |
| Layout | Alignment, padding/gaps, width/height constraints, wrapping/truncation, scrolling, resize and keyboard/safe-area behavior |
| Typography | Semantic role or font family, size, weight, line treatment and scaling policy |
| Color | Semantic token or current literal, light/dark/contrast states and user-selected color behavior |
| Icon | Exact SF Symbol or asset, size, rendering and meaningful accessible label |
| Motion | Trigger, duration, curve, interruption/reversal and reduced-motion fallback |
| Interaction | Pointer/touch, keyboard shortcuts, focus order and restoration, selection and dismissal |
| State | Empty, idle, hover, pressed, focused, selected, disabled/read-only, editing, invalid, saving and save failure as applicable |
| Accessibility | Role, label/value, announcements, keyboard alternative, contrast and hit area |
| Platform difference | Shared business behavior versus macOS/iPhone-specific presentation and capability limits |

Mark inherited values by linking the existing UI spec; do not copy a competing token table. Unspecified reference measurements remain unknown, not invented exact values.

## Acceptance cases

For each case record a stable case ID, preconditions, action, expected visible result, persisted result, and platform. Include success, invalid input, cancellation, repeated actions, navigation away, lifecycle interruption, undo, reload and any migration/cross-client round trip. State negative cases and non-goals.

## Verification and release

List planned tests/checks and durable evidence locations. Record actual command, environment, commit, outcome and untested limitations separately. Include UI fixtures and display settings. State rollout/migration restrictions and any remaining decision needed before implementation or release.

## Completion record

Link implementation PR/merge commit, updated canonical specifications, final acceptance evidence and remaining deviations. Remove placeholders; never mark a case verified solely because source or a test exists.
