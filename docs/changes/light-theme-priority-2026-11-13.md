# UI-SCOPE-001 — Light-theme parity priority

Status: Approved scope decision; documentation only.

## User direction and goal

On November 13, 2026, the user directed: “defer dark them, focus on the white theme only (update the specs / goals)”. Apply this direction to the current local Tasks and Calendar parity milestone on Mac and iPhone.

The active visual target is the white/light reference appearance. Compare layout, typography, spacing, colors, icons, responsive behavior, animation and interactions in that appearance. This is a scoped acceptance goal, not a claim of completed or pixel-perfect parity.

## Deferred versus preserved

- Defer Dark-mode visual matching, palette refinement and native Dark-mode interaction verification. Record these as deferred, not passed or complete.
- Preserve existing Dark-mode and semantic-color code. Do not force the app or OS into light appearance, remove settings, or change notification/signing/permission behavior as part of this documentation decision.
- Existing historical Dark-mode render or native evidence retains its original scope. Offscreen renders are not proof of production interaction.
- No new Dark-mode gate is required for this milestone solely because a general historical checklist included both appearances. This scope change alone does not certify any PR as ready: review the other applicable acceptance cases before merging.
- Keep affected light-theme functional, pointer/touch, keyboard/focus, VoiceOver, Increase Contrast, reduced-motion, interrupted-flow, automated-test and independent-review gates. Do not waive an unrelated defect or claim an unrun check passed.
- Keep Mac/iPhone presentation separation, the allowed reduced phone editor, local-only Tasks/Calendar scope, deferred sync/integrations, deferred description recovery/persistence polishing and deferred notification authorization unchanged.

## Acceptance and reporting

1. A change record states its exact revision and the light-theme cases run, failed or not run.
2. Dark-mode cases are explicitly labelled deferred when relevant; they do not count as verified parity.
3. Code and layout changes still require the applicable tests and independent review. Docs-only changes retain the existing CI path filters and do not trigger unnecessary native builds.
4. Revisit Dark-mode goals and verification when the user reprioritizes them; no automatic date is implied.

## Validation of this documentation change

The canonical Mac/iPhone specifications, workflow, baseline index, parity tracker and verification ledger now point to this decision. No application source or CI configuration is changed. Historical verification entries are retained. This update does not certify implementation or resolve other open PR gates.
