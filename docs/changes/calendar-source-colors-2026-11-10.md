# CAL-COLOR-001 — Customize local Calendar source colors

The active local Tasks and Calendar parity goal authorizes this change on Mac and iPhone. The starting revision is `aba0b9b78a2b6af3dede10542234ba3eed0bc805`. This extends [BUS-027](../spec/business.md#bus-027), [UX-017](../spec/ui-ux.md#ux-017) and [TT-033](../parity-implementation-status.md#tt-033).

TickTick's Calendar guide describes editing list and tag swatches in Calendar View Options. The installed Mac 8.2.20 build 922 showed the Color dialog, a List selector and swatches for Inbox and named lists. The reference session returned to its prior list after viewing the dialog. The save effect on colors elsewhere in TickTick remains unverified. [Reference guide](https://help.ticktick.com/articles/7055782085826445312)

In View Options, choose List or Tag under Color by, then open the corresponding color editor. Each source has a labeled swatch and a Default action when customized. Mac offers presets and exact hex entry in a popover. iPhone uses the system color picker. List mode includes Inbox and active lists. Tag mode shows existing tags. Priority retains its fixed palette. Choose Done to apply the Mac editor or return to the iPhone View Options draft and choose Done there. Cancel discards staged edits. Mac save errors keep the color editor open and iPhone uses the existing preference revision and retry rules.

Overrides belong to Calendar settings and use stable source IDs. Existing settings without overrides use the workspace list and tag colors. Choosing Default removes an override and resumes following the current workspace color. Tag mode chooses the first existing assigned tag and otherwise uses the Calendar list color. The same result colors scheduled cards, check items and repeat previews. Year heatmap and Timeline retain their existing color rules. Settings edits do not change task, list or tag records, filter membership, or schedules.

Verification covers legacy decoding, JSON round trips, defaults, source selection and fixed priority, the settings transaction, and choosing, resetting or cancelling on disposable platform fixtures.

[Verification record](../spec/verification.md#calendar-source-colors)
