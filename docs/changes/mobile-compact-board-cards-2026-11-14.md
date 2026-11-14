# Compact mobile Kanban card captions

Status: Implemented, verification pending. Base `b8fa66b`.

The owner's mobile TickTick screenshots show title and date in one compact card row, with long titles truncated. Current Taskovsky Board cards always stack date below title. This presentation-only change moves the existing date caption beside the title at standard Dynamic Type sizes and uses a one-line, tail-truncated title. Accessibility text categories retain the original wrapping/stacked layout. Minimum 44pt title target and complete accessibility title remain.

Existing date text, time-zone semantics, colors, completion, opening, move menus and drag targets remain unchanged across scoped, status and section boards. This is not full Kanban parity: grouping, section hierarchy, date/time/color matching and extra move affordances remain open. No business/persistence behavior changes.

Acceptance: verify standard and accessibility text layouts, long titles, dated/undated tasks/notes, open/completion/move/Undo, no overlap or lost actions. Use disposable simulator fixtures; no desktop capture or system-settings changes. Independent review, compile, native tests and hosted CI pending.

Initial isolated iPhone13Pro/iOS26.3.1 native test passed: standard card retains 44pt open target and full accessibility title; opening detail works; largest accessibility size expands stacked title/date. Expanded standard-size/drag/note/status/Undo regression run pending. Independent source review found no confirmed regression; broader native matrix remains required before merge.
