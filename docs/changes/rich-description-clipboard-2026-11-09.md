# Copy and paste formatted descriptions

TickTick documents preserving formatting and structure when copying within its editor. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704)

Taskovsky copies the selected text and its supported formatting. Paste into another Taskovsky description restores bold, italic, underline, strikethrough, highlight, inline code, HTTP and HTTPS links, and paragraph styles. Inline marks follow the copied characters. A complete paragraph can carry its heading, quote, list, checked state, or divider. A fragment that joins an existing destination paragraph keeps that paragraph’s style. Numbering follows the destination list.

The plain text representation stays available to other editors. Taskovsky validates its clipboard fragment against that exact text before using the ranges. Mac retains the normal paste behavior for other representations. iPhone uses plain text when a supported fragment is unavailable. The iPhone editor also offers a Paste as Plain Text button beside Undo and Redo. The draft stores a rich paste as a single edit that can be undone, redone, or resumed after relaunch.

The Mac QA bundle uses a unique named pasteboard. iPhone QA sessions each use a named pasteboard on the disposable simulator. The verification uses synthetic task descriptions. The later [plain-text paste change](rich-description-markdown-paste-2026-11-10.md) adds supported Markdown recognition to ordinary paste. The later [foreign rich-text change](rich-description-foreign-paste-2026-11-10.md) covers supported inline formats from HTML and RTF. Media remains a separate parity gap.

[Verification record](../spec/verification.md#rich-description-clipboard)
