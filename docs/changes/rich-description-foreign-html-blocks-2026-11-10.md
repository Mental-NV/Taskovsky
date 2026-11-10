# RICH-CLIPBOARD-004 — Preserve supported HTML paragraphs

Ordinary description paste on Mac and iPhone imports semantic HTML headings, block quotes, bullet lists, numbered lists and preformatted code. Inline styles follow the [foreign paste rules](rich-description-foreign-paste-2026-11-10.md). When HTML supplies paragraph structure and a matching RTF flavor supplies inline styles, the paste retains both. The reference documents supported rich paste and paragraph formats. The HTML element mapping is Taskovsky’s extension to that behavior. [TickTick formatting guide](https://help.ticktick.com/articles/7507338582718152704).

An accompanying plain representation remains the exact saved text. A block applies only to a complete paragraph whose visible content aligns. Joining or splitting lines can leave that paragraph without an imported style. The code path matches a complete block, including indentation and blank lines, and permits different line endings. HTML-only content uses the existing safe text extraction. Paste as Plain Text saves the literal text without styles.

List paragraphs use the existing flat markers and numbering. Nested indentation, custom numbering, RTF paragraph inference, media and layout-specific styling remain outside the supported conversion. The existing rich-body storage format handles the imported styles. A paste is one editor transaction and works with the platform’s Undo, Redo and normal save behavior.

[Verification](../spec/verification.md#foreign-html-paragraph-paste).
