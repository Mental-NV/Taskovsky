# CAL-SAVE-017: lossless acknowledged Mac scheduling writes

Status: Implemented; hosted verification passed, native interaction unrun.

## Evidence and outcome

On base `ddef08a`, draft assessment PR63 (`a59dfff`) reproduced stale independent-store writes and loss of an unknown ordinary-task field. Hosted macOS run 43271155062 ran the two owned tests twice; both failed while the existing tests passed. This is not evidence that ordinary shared-store app windows have independent stores.

Calendar drag, resize, commands and scoped Undo must not silently replace independently saved fields or erase unsupported data. Explicit Schedule Save/Clear uses the same narrow persistence boundary; its existing schedule preparation remains unchanged.

## Contract

- Stage one existing task's schedule without publishing it. Preserve task order, lifecycle, linkage, title/body/rich content, tags, list and all other fields.
- Read fresh disk data, require the known baseline to match the current store by deterministic encoded bytes (including exact Unicode), and refuse stale writes with an actionable storage error. No automatic rebase or reload of unsaved app state.
- Patch only changed owned schedule members and `updatedAt` in the original JSON. Preserve unrelated raw bytes, including unknown members. If a changed nested schedule member contains data the model cannot reproduce, refuse rather than erase it.
- Preserve known protected collection envelopes and support necessary format upgrades/downgrades. Refuse ambiguous duplicate keys/IDs or unsupported envelope data rather than dropping it. Existing protected-data compatibility restrictions remain.
- Recheck exact disk bytes immediately before the atomic file replacement. This narrows a stale-write window; it is **not** cross-process locking or compare-and-swap. Concurrent processes remain unsupported.
- Publish only after an acknowledged write (or exact readback of the intended bytes after an ambiguous write result). Failure leaves the task, visible schedule and Undo result unchanged; existing Schedule sheet retry behavior remains.
- Exact unchanged prepared task returns success without rewriting bytes. Actual changes retain existing timestamp, reminder, duration, recurrence and occurrence semantics.

## Scope and verification

Mac store scheduling persistence only, a separate Workspace raw patch helper, owned tests and docs. No editor/journal/PR61 changes, iPhone view changes, OS notification calls, permissions, integrations or visual parity claims. Existing UI geometry, layout, input and dismissal contracts stay unchanged.

Test stale independent-store move/Undo/explicit Save, exact Unicode baseline, unchanged save, raw unknown members, changed nested unknown refusal, duplicate IDs/keys, protected envelope transitions and save failure/retry. Run hosted macOS tests and iPhone compile gate; native interaction remains unrun while the Mac is offline.

## Hosted result

Code head `22e1222`, run 43273408292, synthetic merge `cf84f6a` into `ddef08a`: macOS 15 ARM64 / Xcode 26.3 passed all 766 XCTest and 38 Swift Testing cases on the first attempt, release/signature/archive gates; independent iPhone generic ARM64 Simulator build-for-testing passed with SDK 26.2. No Simulator tests or native UI were run. Independent source review found no remaining blocker. The final documentation-only delta does not change code or workflow.
