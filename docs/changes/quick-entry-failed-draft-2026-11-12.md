# Retain Mac QuickEntry drafts after rejected submission

## Source-backed defect

The section-aware store path already rejects failed writes without publishing a task. App.addTask returns early, but QuickEntry ignores this outcome and clears description, expanded description and the recognition override. Title survives while other draft state is lost.

## Bounded contract

Make the Mac submission callback acknowledge acceptance. Clear description, expansion and ignored-date state only on accepted submission; rejection keeps all draft fields and existing failure notice, ready for explicit retry. Preserve successful capture behavior and existing section targeting. No new shared editor or mobile view, and no claim to repair legacy ordinary quick-add persistence or the second-pass tag/reminder updates.

## Verification

Reproduce a rejected section submission with owned file obstruction before the fix. Verify retained title/body/expanded state/ignored-date choice after the fix; restore writable file and explicitly retry once, then audit one task and original section/body/date behavior. Full tests/build, source review and exact-head CI before merge.
