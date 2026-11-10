# MOB-FOUNDATION-001 — Shared read-only mobile foundation

Status: Implemented for the bounded cases below; current evidence/limits are in [verification](../spec/verification.md#mobile-foundation-preview). Authorized under the user's autonomous local Tasks/Calendar desktop/mobile parity request. Based on merged mobile specification PR #4 at `6ee96eeb8f88e74a105c518de2202233ea528efa`. Isolated checkout `/private/tmp/TaskovskyMobile-1109`, branch `codex/mobile-local-prealpha`. No commit, push, deployment, signing-account changes, runtime download or real-data experiment.

## Outcome and scope

Implement the first bounded S1/S2 slice of IOS-012/014: a Foundation-only `TaskovskyDomain` library, shared destination predicates and recurrence stepping, plus deterministic characterization tests. Existing Core retains the macOS services/editor and re-exports domain types for compatibility. Preserve the exact desktop predicate defaults and cadence semantics; no schema change or live file migration. The read-only mobile shell and compatible writable repository are subsequent slices; this change alone does not complete either.

TaskovskyDomain owns the existing value models, settings/filter values, rich representation, hierarchy, recurrence, scheduling drafts/operations and Calendar/Board projections. Physical source paths may remain stable while explicit target source sets enforce the boundary. The domain must import no UI/observation/file/network service and depend on no TaskStore. Move only the pure legacy recurrence step out of TaskStore, keeping its static facade for existing callers. Extract the desktop destination predicate rather than duplicating Today/Next7/tag/history policy on iPhone. Sorting/grouping/search composition and mutation commands remain later seams and must be recorded as incomplete.

## Desktop reconciliation

The Desktop milestone was completed first on the separate dirty `codex/calendar-visual-parity` checkout, with 485 tests and signed release. It corrects Calendar source union/reset/group controls, Year date→Week/month-title→Month and four additional rulers. After an independently passing extraction against main (479 tests), the shared source-selection and four-zone changes plus their regressions were deliberately copied from the preserved Desktop tree. `desktop-domain-integration.json` in the private evidence folder records each source/destination hash. The only projection adaptation replaces TaskStore's static recurrence facade with the identical extracted pure helper. No Desktop files were edited or committed. The corrected Calendar controls call these commands, so the four verified Desktop Calendar UI/appearance files were then explicitly copied as the coherent dependency; leaving the old Mac controls beside the new source rules would be inconsistent. The integration record includes their exact hashes too. Desktop reports/contracts were carried forward while retaining PR #4’s canonical mobile specification and its verification entry. No original Desktop file was edited. The resulting mobile branch must rerun Mac checks after this integration; historical Desktop native evidence is not a new native pass on the extracted module graph. The Desktop source manifest is `d1cac1c075854c9b94b275c10b9487ed4f316dfda133e08b0dc05ce9fc596a36`; release SHA-256 `829388ecec6713a870a7f7942384f775760952d1836b52111734d184f27ca3fe`.

## Compatibility and safety

No writes from an iPhone UI are enabled in this slice. Existing whole-file Codable storage cannot preserve arbitrary unknown keys; unknown enums may block decoding. Future read-only readers must retain originals and never construct a writable empty fallback after failure. Styled/malformed/unknown bodies must not be flattened, and viewing must have no persistence callback. Field-scoped writes require the separate IOS-008/012 repository gate.

Keep iOS 17 as the deployment minimum for compilation, with current installed SDK. Available runtime inventory is iOS 26.3.1, 26.5 and 27.0; no iOS 17 runtime is installed, so compilation is not an iOS 17 runtime pass. No device signing or notification feasibility result is inferred from simulator availability. D04's physical-device gate remains pending; do not add a permission prompt or local alert promise in this foundation slice.

## Acceptance

1. Existing macOS suite passes before and after extraction; release build and signatures pass after shared changes.
2. Portable target builds for `arm64-apple-ios17.0-simulator` and contains only Foundation imports, with no Core dependency.
3. Frozen clock/workspace tests characterize overdue Today/Next7 versus bounded filters, archived/excluded history exceptions, tag descendants versus saved filters, missing filter IDs and recurrence month/leap/DST anchors.
4. Legacy TaskStore facade and Calendar projection call the same pure recurrence helper; no duplicate stepping implementation.
5. Stable schema and source links; document exact commands/environment/hashes, baseline/final outcomes and not-run simulator/device/UI cases.

No new product UI is introduced by this extraction. Future UI geometry follows the canonical mobile specification and user-supplied screenshot calibration; this change does not invent new visual requirements.
