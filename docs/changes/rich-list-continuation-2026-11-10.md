# RICH-LIST-001 — Continue saved description lists

This local Mac and iPhone feature starts from merged `main` at `36a9e17`. It addresses the mid-list Return gap recorded in [TT-003](../parity-implementation-status.md#tt-003). The [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704) documents typed rich-list formatting. The Return and Undo rules below are Taskovsky's editing contract.

With a collapsed caret in a saved bullet, numbered item or checklist item, Return splits the paragraph and continues that list. Splitting at the start inserts a new item above. Numbering is derived from the contiguous paragraphs. The original checklist fragment retains its checked state. A new fragment starts unchecked. Return on a blank item exits the list without changing adjacent items.

A newly opened blank terminal item temporarily stores a paragraph terminator, as styled paragraphs need a real text range. Typing into the blank terminal item replaces that terminator with the new item text. Exiting it leaves one separator after the previous item. This makes the blank marker replayable in Undo and Redo and compatible with the current file format. Changes use the existing rich-body transaction and preserve the searchable text and formatting of other paragraphs. Native selection replacement, composition and clipboard commands retain their existing paths.
