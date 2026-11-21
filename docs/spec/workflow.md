# Parity workflow

Work one bounded change at a time. Taskovsky source at the exact checkout describes what exists; a scoped, approved change defines what should change. Running TickTick on the relevant platform is the authority for its **observed** behavior. Official documentation supplements it; static analysis can suggest experiments but cannot prove runtime behavior. Record a conflict with a Taskovsky product decision instead of silently overriding it.

## Scope and delivery

- Local **Tasks and Calendar** on Mac and iPhone. Compare light appearance first; preserve existing Dark and accessibility support. Dark parity and dedicated accessibility-layout polish are deferred, not passed. See the [appearance decision](../changes/light-theme-priority-2026-11-13.md).
- Mobile **Share / Print (T05)** and **Background (T06)** remain deferred until core forms are done. Sync, external integrations, real notification authorization, storage-recovery polish and App Store release are not reopened by parity work.
- On iPhone, work one tracked form at a time in the requested order. The current pass is Calendar; use the [46-state tracker](../mobile-visual-parity.md), not an older dated rollout queue. Keep local progress separate from integrated status. On Mac, use the [feature gaps](../parity-implementation-status.md) and affected UI region; the [dated Mac layout map](../changes/ui-macro-parity-plan-2026-11-13.md) is a starting inventory, not current acceptance.

## 1. Observe and record

Pin the Taskovsky base, platform and affected BUS/UX/IOS and TT or C/D/T IDs. Open the actual TickTick state and exercise the relevant transitions, not just its settled appearance. Record entry path, labels, state, interaction and resulting data or visible effect. Record app/OS, appearance, viewport in points if known, image scale/crop, text size, locale/time zone and fixture differences. Label observed, inferred, unknown and deliberate differences separately. Prefer neutral fixtures and a dedicated reference account; use iPhone Mirroring only when needed. Publish only reviewed, authorized captures; record masks or withhold the image.

## 2. Specify and implement

Use the [change template](change-template.md) for one decision, observation, intended delta and receipt. List each relevant control and conditional state, its geometry, color, wording, transitions and underlying business rule. Keep UI separate per platform and put shared rules in the shared engine. Preserve unrelated behavior and unsupported data. Do not add cosmetic controls that cannot perform the action. Mark the contract approved only when the user has authorized the delta or their request specifies it unambiguously.

## 3. Verify independently

- **Behavior:** use neutral, isolated fixtures. Verify relevant success, repeated/dismissed interactions, Cancel/Undo, persistence/relaunch and platform regressions. Check domain tests, affected native flows and build/CI separately.
- **Visual:** freeze the element inventory, each axis denominator and tolerances before tuning. Compare calibrated captures under matched conditions when possible. Score iPhone **size, position and color separately** and report counts, tolerances and significant unmatched conditions. Keep every reference element in the recorded inventory and explain absences, unknowns, masks and approved scope exclusions. Count unverified matches as non-passes in the frozen denominator; report any separately scoped subset as such. Do not infer text or colors from a mask. Use unscaled measurements only where the capture supports them.
- **Move on:** target at least **90% on each axis** with working behavior. Set a bounded iteration budget before tuning. If it stalls, keep the best behavior-verified result, record the measured scores or why an axis could not be measured and the remaining gaps, then advance. Do not label below-target results as parity passed. A reference, a similar screenshot and a native test prove different things.

### Reuse the guarded Mac QA app

For Computer Use on the development Mac, keep the existing **Taskovsky QA** bundle at `/private/tmp/TaskovskyNativeQA/Taskovsky QA.app` with identifier `local.taskovsky.native-qa`. The executable entry is `Contents/MacOS/Taskovsky`. It is a launcher that requires an explicit, canonical pair of disposable workspace and settings paths. It rejects missing or mismatched arguments, symlinks and hard-linked fixture files, then runs `Contents/MacOS/TaskovskyQAReal`.

When testing a new build, prepare the replacement payload and fixture in staging. Preserve the app name, identifier, stable path, launcher contract and existing ad hoc signing mode. Verify the guard and strict signature before using the staged bundle. Keep the signed prior bundle intact so it can be restored after the run. Launch with the exact fixture paths accepted by the guard. A rebuilt ad hoc bundle can have a different code hash, so approval reuse depends on the actual Computer Use request.

## 4. Review and integrate

Record exact head, fixture, commands, environment, passed/failed/not-run checks, reference and resulting Taskovsky captures, and the next gap. Link the receipt from the affected tracker row and record integration separately. Keep durable rules in the canonical specs, not copied into trackers or overwritten to explain a defect. Retain completed change records as evidence. Open a draft PR unless requested otherwise; opening a PR does not authorize a merge.

## Hosted macOS verification

Use the [CI specification](ci-cd.md#ci-002) for triggers and limits. Review the exact PR head, relevant build and tests; automation does not replace affected native checks. Paths restricted to `docs/`, root `README.md`, or root `AGENTS.md` skip automatic macOS CI; validate links, anchors, IDs and the Markdown-only diff instead. A filtered run is not a runtime pass.
