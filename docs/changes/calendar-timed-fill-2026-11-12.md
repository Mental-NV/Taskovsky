# Timed Calendar card painted height

Status: light-theme scope verified; final exact-head checks required before merge. On November 13 the user explicitly deferred Dark-theme work and directed completion of the white/light-theme UI.

## Observed defect

A November 12 native comparison of main `77b646c` and adaptive-checkbox PR65 `0a63ce74` showed the bottom resize grip detached from the painted body at both tested window widths: approximately 14 screenshot pixels for a 30-minute task and 40 for a 45-minute note. The 60-minute control remained attached. This defect predates PR65. Physical screenshot pixels are not a point-space specification.

## Source and bounded correction

`CalendarTimedBlock` assigns the duration height and overlays its bottom resize grip at that frame edge. `CalendarEntryView` currently leaves compact content at intrinsic height before drawing its background, so short-duration cards can paint less than their allocated duration. Add an explicit timed-only `fillsAllocatedHeight` input, default false; use flexible maximum height before the background when opted in. Preserve title position, compact typography/padding, colors, clipping, lane allocation, resize and move targets, actions and scheduling. Non-timed compact cards retain intrinsic height. There is no persistence or phone change and no claim of exact TickTick parity.

## Acceptance

- Compare base and candidate with the same isolated 15/30/45/60-minute task and note fixture, narrow/wide allocation, filled/outline style, light appearance. Dark-theme interaction is deferred by the user's November 13 direction; do not treat historical offscreen renders as a native Dark pass.
- Verify the painted bottom and resize grip align to the allocated event duration at compact/noncompact boundary, including top/bottom clipped entries.
- Move, start/end resize, title opening and context/accessibility actions remain usable; no hit-target expansion beyond the existing outer duration frame.
- Run `swift test --disable-sandbox` and `./scripts/build-app.sh` on the exact candidate, plus independent source review.
- Preserve stable QA identity and original dirty worktrees. Restore fixture/app and stop scoped Codex afterward. Do not resume deferred description recovery or notification permission work.

## Evidence so far

Code head `b8c0d5ebe79d97cc21bea60e1991a0f348224c70` passed independent source review and hosted macOS CI run `43307260413`, including macOS tests/release packaging and iPhone Simulator compile-only. Native light-mode QA reported 766 XCTest and 38 Swift Testing checks, app build, 15/30/45/60-minute tasks and notes, narrow/wide allocation, Filled/Outline, clipping and move/resize coverage. No scheduling or persistence behavior was changed.

A separate offscreen dark-rendering harness used the exact production Calendar column/card code from that head with test-only appearance inputs. It verified 72 renders across the same durations, task/note kinds, widths, styles and folded-hour clipping. Against base `77b646c`, the 30/45-minute cards had 15/41 screenshot-pixel gaps below their painted bodies at standard zoom; the candidate closed both gaps and kept the grips within their visible frames. These are fixture measurements, not universal point-space specifications.

**Known pre-existing limitation:** the bottom Outline stroke of minimum-height 15-minute cards was clipped in both base and candidate. This bounded change fixes compact duration-body underfill; it does not certify complete outline/clipping parity or fix that minimum-height stroke issue. The observation is not a regression introduced here and remains open for separate UI work.

**Verification boundary:** offscreen dark rendering is not production-app Dark interaction testing. No system appearance/defaults, QA launcher/signature or notification settings were changed. Native interaction was covered in light appearance; dark-specific interactive behavior remains unverified. The harness opened no desktop window and exited. Original QA bundle, fixture and preferences matched recorded checksums, and scoped Codex stopped.

## November 13 scope decision

The user explicitly changed the current goal to white/light-theme UI and deferred Dark-theme work. Production Dark interaction is therefore a tracked future verification task, not a current merge gate for this bounded light-verified correction. No OS appearance or permissions are changed. Hosted run `43319212818` passed for documentation head `2afc3c1`; a new documentation head must receive its own checks. The separate minimum-height Outline correction is tracked in PR67. Existing narrow-card title-hit/focus limitations remain separate and are not claimed fixed here.

The large historical current-UI/parity documents remain unchanged. This evidence closes neither full Calendar parity nor PR65's independent focus gate. Any documentation-only follow-up must receive its own exact-head CI result before merging under the current workflow.
