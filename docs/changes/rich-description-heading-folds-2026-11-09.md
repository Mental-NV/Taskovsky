# RICH-FOLD-001 — Collapsible description headings

The description reader shows a disclosure button next to a heading with content. Collapsing a heading hides everything up to the next heading of the same or a higher level. A collapsed parent also hides its child controls. Expanding the parent retains any nested fold choices for that reading session. Headings with no following content have no disclosure control.

On iPhone, these controls appear in the selectable task description. On Mac, Read Description opens a separate selectable sheet and keeps the existing editor mounted. The editor always opens the full text. Hidden content is outside the selectable reading projection, and visible formatting, links and paragraph decorations keep their text offsets. Fold choices are temporary and do not change task data, search, or settings.

The [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704) describes heading-level disclosure next to headings. Taskovsky implements that interaction in the reader. [Verification](../spec/verification.md#rich-description-heading-folds).
