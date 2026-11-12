# Timed Calendar card painted height

Status: draft; native regression verification required before merge.

## Observed defect

A November 12 native comparison of main `77b646c` and adaptive-checkbox PR65 `0a63ce74` showed the bottom resize grip detached from the painted body at both tested window widths: approximately 14 screenshot pixels for a 30-minute task and 40 for a 45-minute note. The 60-minute control remained attached. This defect predates PR65. Physical screenshot pixels are not a point-space specification.

## Source and bounded correction

`CalendarTimedBlock` assigns the duration height and overlays its bottom resize grip at that frame edge. `CalendarEntryView` currently leaves compact content at intrinsic height before drawing its background, so short-duration cards can paint less than their allocated duration. Add an explicit timed-only `fillsAllocatedHeight` input, default false; use flexible maximum height before the background when opted in. Preserve title position, compact typography/padding, colors, clipping, lane allocation, resize and move targets, actions and scheduling. Non-timed compact cards retain intrinsic height. There is no persistence or phone change and no claim of exact TickTick parity.

## Acceptance

- Compare base and candidate with the same isolated 15/30/45/60-minute task and note fixture, narrow/wide allocation, filled/outline style, light/dark appearance.
- Verify the painted bottom and resize grip align to the allocated event duration at compact/noncompact boundary, including top/bottom clipped entries.
- Move, start/end resize, title opening and context/accessibility actions remain usable; no hit-target expansion beyond the existing outer duration frame.
- Run `swift test --disable-sandbox` and `./scripts/build-app.sh` on the exact candidate, plus independent source review.
- Preserve stable QA identity and original dirty worktrees. Restore fixture/app and stop scoped Codex afterward. Do not resume deferred description recovery or notification permission work.

## Evidence so far

Cloud source inspection and `git diff --check` only. Swift is unavailable in this cloud executor. Native candidate behavior, tests and build have not yet been run. This document does not close a parity row or certify a fix. The large historical current-UI/parity documents remain unchanged; record the final verified delta before merging.
