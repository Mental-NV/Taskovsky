# Compact mobile Kanban card captions

Status: Implemented; bounded native checks passed, exact-head CI pending. Base `b8fa66b`.

The owner's mobile TickTick screenshots show title and date in one compact card row, with long titles truncated. Current Taskovsky Board cards always stack date below title. This presentation-only change moves the existing date caption beside the title at standard Dynamic Type sizes and uses a one-line, tail-truncated title. Accessibility text categories retain the original wrapping/stacked layout. Minimum 44pt title target and complete accessibility title remain.

Existing date text, time-zone semantics, colors, completion, opening, move menus and drag targets remain unchanged across scoped, status and section boards. This is not full Kanban parity: grouping, section hierarchy, date/time/color matching and extra move affordances remain open. No business/persistence behavior changes.

Acceptance: verify standard and accessibility text layouts, long titles, dated/undated tasks/notes, open/completion/move/Undo, no overlap or lost actions. Use disposable simulator fixtures; no desktop capture or system-settings changes. Independent review, compile, native tests and hosted CI pending.

**Initial checkpoint, before expanded run:** isolated iPhone13Pro/iOS26.3.1 native test passed: standard card retains 44pt open target and full accessibility title; opening detail works; largest accessibility size expands stacked title/date. Expanded standard-size/drag/note/status/Undo regression run pending. Independent source review found no confirmed regression; broader native matrix remains required before merge.

## Expanded native evidence
Source `d535fab`, disposable iPhone13Pro Simulator iOS26.3.1: six XCTest UI cases passed. Standard 44pt title open target and full accessibility label; largest standard text title truncation with trailing date; largest accessibility text wrapping/stacking; scoped cross-list drag; per-list Board mode/relaunch; recurring completion/Undo; archived read-only board; task drag and note refusal. Standard screenshot also shows undated card with no blank date placeholder. All screenshots use neutral QA data. Existing user QA device unchanged; disposable device verified Shutdown after run.

Three actual simulator screenshots inspected: standard and largest non-accessibility text show separated title/date without overlap; accessibility size uses original stacked wrapping. This is not a complete app accessibility certification: oversized header/QA caption and bottom navigation still reduce the visible area at the largest accessibility category. Smaller device widths/locales and full VoiceOver traversal not manually tested. No new desktop capture/settings changes. A UIKit nested-menu hierarchy warning inherited from the menu flow remains recorded, with sampled actions passing.
