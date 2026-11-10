# CAL-MOBILE-MONTH-TITLE-001 — Readable titles in compact Calendar cards

The supplied TickTick iPhone Month screenshot R17 shows the start of task titles inside the seven-column grid. Taskovsky's current text truncation can reduce a comparable card to an ellipsis when the icon and move grip are visible.

iPhone Month and Multi-Week give the title the remaining width after the color stripe, enabled icon and existing edit controls. The title renders one line and clips at the trailing edge, so the available space shows the beginning of the name. The one-day card uses the compact move grip already used on a one-day range. Completion still uses the existing strikethrough, card action and accessibility action. The accessibility label and task detail retain the full title. Show Details continues to use its separate line.

The card is still a button. The move grip and each available range endpoint remain separate targets. Colors, row heights, capacity, source filters and saved data follow their existing rules. The change applies only to the iPhone grids. [iPhone evidence register](../spec/iphone.md#measured-visual-baseline).

[Verification](../spec/verification.md#mobile-calendar-month-card-titles).
