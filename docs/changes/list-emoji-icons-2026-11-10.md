# LIST-ICON-001 — Emoji icons for local lists

This local list-organization change starts from merged `main` at `36a9e17`. The [TickTick list guide](https://help.ticktick.com/articles/7055782283059396608) documents choosing an emoji in the list editor and entering one at the start of the name.

On iPhone, select Custom Emoji under Icon and enter one emoji with the keyboard or paste. The list editor shows the chosen glyph, and the drawer and manager display the stored icon. Mac keeps the existing custom field. Both editors can promote an initial emoji to the icon when saving a new or renamed list with the default icon. The remaining name must contain text. An explicit icon takes precedence, and an unchanged name is left alone on an unrelated edit. An emoji-only name remains a name.

The editor preserves the complete Unicode grapheme, including joined emoji, skin tones and flags. The existing `symbol` string represents the icon on both platforms. Save and Cancel use the existing list transaction. Older list records and custom icons keep their existing values. [BUS-015](../spec/business.md#bus-015) covers list organization.
