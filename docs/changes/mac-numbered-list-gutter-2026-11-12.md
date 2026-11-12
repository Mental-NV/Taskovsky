# RICH-GUTTER-001 — Preserve readable long numbered-list markers

Status: implemented and bounded Mac verification passed. Hosted checks and integration are tracked in [PR #33](https://github.com/Mental-NV/Taskovsky/pull/33). Base `5783072`.

## Problem and scope

The Mac description renderer reserves a fixed 24pt gutter with 4pt trailing clearance. At the existing 13pt font, markers such as 100. and 1000. exceed that space and paint left of the gutter, risking clipping. This is a source-derived Taskovsky defect, not a claim of measured TickTick geometry.

## Contract

Use a presentation-only gutter for each contiguous decimal run: at least 24pt, otherwise the maximum measured marker width plus 4pt, rounded upward to a whole point. Align number markers on the right, 4pt before the text. Reserve that same width on first and wrapped lines for every paragraph in the run. Retain the existing 13pt font, semantic label color, body typography, selection and scrolling behavior. Recompute after rendering, editing, list-format changes and Undo/Redo, shrinking again when the run shortens. Plain paragraphs separate runs. Bullet/checklist/quote geometry remains unchanged. No new animations.

Do not change body text, UTF-16 ranges, rich metadata, storage schemas, domain rules, iPhone rendering or rich-editor Undo ownership. Derive geometry from storage outside the draw/layout callback; avoid mutation during layout.

## Acceptance

- Long 100/1000-item runs keep all marker rectangles within their reserved gutters, including nonzero drawing origins, wrapped text and a visible middle-of-run subset.
- 99→100→99 edits and Undo/Redo recompute widths; separated runs reset numbering and widths.
- Inline styles, paragraph metadata, exact text and rich-body extraction remain unchanged; bullet/checklist/quote baselines still pass.
- Run Mac automated tests and signed build, then isolated native rich-editor checks using stable Taskovsky QA identity. Report native cases not exercised.

[Verification record](../spec/verification.md#mac-numbered-list-gutter).
