# RICH-TYPING-001 — Format descriptions with Markdown keystrokes

The active local Tasks and Calendar parity goal authorizes this change on Mac and iPhone. It updates BUS-005, UX-009, TT-002 and TT-003. TickTick documents typing a space after heading, list, quote and inline formatting markers, and typing three hyphens for a divider. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704).

Typing a space after a paragraph-leading heading marker (one to six hashes), dash, 1., greater-than sign, or Markdown checkbox starts the corresponding paragraph style. In a bullet paragraph, typing brackets and a space upgrades that bullet to a checklist. Empty paragraph styles are armed in the live editor and become part of the rich description when text arrives. Typing the third hyphen on a line containing only two hyphens inserts a divider and moves the caret to the next paragraph.

Typing a space after a simple matched bold, italic, highlight or strikethrough span removes its delimiters, applies the style and leaves a plain separating space. Existing supported inline formatting inside the span is preserved. A noncollapsed selection, escaped delimiters, code content, and unsupported nested syntax retain literal input. A failed formatting operation falls through to native typing.

The transformation is one editor edit. Undo restores the marker text that preceded the trigger. Existing plain paste, internal rich paste, composition, and paired description persistence keep their current paths. The workspace schema remains at its current version. Fenced code blocks need a new paragraph representation and remain outside this change.

Verify the exact UTF-16 body and rich companion, native trigger and Undo/Redo, checklist conversion after a bullet shortcut, unchanged unrelated fields, and iPhone draft safety using disposable fixtures.

On Mac, The editor follows the system’s Smart Dashes preference for ordinary prose. When the user types the second leading hyphen of an otherwise empty line, the editor keeps that keystroke literal so the third can create a divider.

[Verification ledger](../spec/verification.md#rich-description-markdown-typing).
