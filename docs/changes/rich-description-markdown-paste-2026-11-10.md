# RICH-CLIPBOARD-002 — Format supported plain text on paste

Taskovsky recognizes common formatting when plain text is pasted into a Mac or iPhone description. The project’s local Tasks parity goal authorizes this change on the isolated line based at `6ee96ee`. It updates BUS-005, UX-009 and TT-002.

TickTick documents separate behaviors for rich copy, plain-text paste, and typing shortcuts. Its plain-text paste examples cover headings, lists, quotes, bold and web links. Single-asterisk italics stay literal in pasted plain text. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704)

Ordinary paste recognizes heading levels one through six, bullet lists, numbered lists starting at one, and quotes when their paragraphs stand on their own in the result. A marker that would join existing paragraph text stays literal. Bold markers are removed around supported spans, and standalone HTTP and HTTPS URLs acquire a link style. Single asterisks, escaped markers, fenced code, indented code, inline code spans and checklist markers stay in the text. The parser operates on bounded payloads and preserves original line endings and UTF-16 code units outside the recognized syntax.

The existing Paste as Plain Text action keeps the full original string. Taskovsky's own clipboard representation carries exact selections even when unstyled, so copying within the app preserves literal Markdown. Mac's native rich clipboard fallback and iPhone's plain fallback for unsupported foreign formats keep their existing priority. A rejected inferred formatting edit falls back to the original text through the platform's normal paste path. The shared rich body model and paired save format stay at their existing versions.

The Mac text view uses its existing per-document Undo stack. iPhone saves the paste as one rich draft edit with local Undo and Redo, and writes the body and companion together on Done. Live typing shortcuts, full Markdown source editing and foreign rich-text conversion remain separate work.

Verification uses synthetic content in private named pasteboards. The acceptance checks cover literal and formatted paste of the same payload, Undo, Redo, exact saved text, supported block and inline styles, and untouched records/settings. See the [verification ledger](../spec/verification.md#rich-description-markdown-paste) for the platform results.
