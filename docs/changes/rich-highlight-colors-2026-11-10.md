# RICH-HIGHLIGHT-001 — Highlight descriptions with multiple colors

The active local Tasks and Calendar parity goal authorizes this Mac and iPhone change. It refines [BUS-005](../spec/business.md#bus-005), [UX-009](../spec/ui-ux.md#ux-009) and [TT-002](../parity-implementation-status.md#tt-002). TickTick documents multiple highlight colors. Yellow, green, blue, pink and purple are Taskovsky’s named palette. [TickTick release notes](https://help.ticktick.com/articles/7082552170989486080).

Keep the existing yellow toggle and typed Markdown highlight. The Highlight Colors menu applies a named color to the selection and Remove Highlight clears only its highlight. The Mac editor also accepts a color at a collapsed caret for subsequent typing. Existing rich marks, code styling and text remain intact. Recoloring and removal use the current editor’s Undo/Redo. A highlight takes precedence over the code background. Removing it restores that background when code styling is present.

Legacy yellow ranges retain their existing encoding. Non-yellow colors persist in bounded UTF-16 ranges, survive supported rich clipboard and template operations, and are protected against downgrade writes. The plain body stays identical. Older clients can receive the plain clipboard text. Verify legacy yellow, exact selection and unrelated range preservation, native recoloring, removal, Undo/Redo, local clipboard and relaunch on both platforms.

[Verification record](../spec/verification.md#rich-highlight-colors).
