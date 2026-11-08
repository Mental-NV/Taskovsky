# Lists, folders and tags

Evidence: the installed macOS TickTick app, light appearance, 2 November 2026. Existing list and tag editors were opened only for inspection and canceled. The folder's Add List dialog was also canceled without creating a list. Captured dimensions below are screenshot raster pixels, not verified macOS points.

## List hierarchy and context menu

The sidebar displays folder rows with a folder icon and disclosure triangle; expanded folders contain indented list rows. Ungrouped lists can appear alongside folders. The right-aligned gray count is visible on populated entries. Right-clicking an existing ordinary list exposed **Edit**, **Pin**, **Share**, **Duplicate**, **Archive**, and **Delete**, in that order. No action besides opening Edit was exercised, so the effect of archive, deletion, sharing and duplication remains unverified.

The folder context menu contained **Add List**, **Edit**, **Pin**, and **Ungroup**. Selecting Add List opened the creation dialog with that folder already selected. Folder selection and disclosure are distinct controls; the consequences of Ungroup and folder deletion have not been tested.

## Add/Edit List dialog

The wide dialog is split into a left form and a right live visual preview. At the observed 1640 × 932 screenshot, the form occupied roughly the left half, with the preview on a subtly tinted background to its right. This single capture does not establish minimum/maximum size or display scaling. The form presented:

1. Focused name field with a list icon and placeholder `Name` for creation.
2. **List Color** swatches: a no-color symbol, red, orange, yellow, yellow-green, green, blue, purple, and a multicolor selector.
3. **View Type** icon buttons. The first showed a list preview; choosing the second changed the right preview to columns of cards and the accessibility image name to a Kanban preview. The third had a Premium crown; its behavior was not exercised.
4. **Folder** menu with `None`, available folders, and `New Folder`. A checkmark marked the current selection.
5. **List Type** menu offering `Task List` and `Note List`.
6. **Show in Smart List** menu offering `All tasks` and `Do not show` for the inspected list.
7. Cancel and blue Save buttons. Save was disabled for an empty new-list name. In Edit, changing the preview selection updated the preview without closing the dialog; Cancel discarded the pending choice.

Actual effects of each list type, smart-list exclusion, folder changes and view modes need controlled save/reopen experiments. The list-icon editing interaction, custom-color picker, validation rules, accessibility, resizing and hover states also remain open.

## Tag hierarchy and editor

Right-clicking a top-level tag showed **Edit**, **Pin**, **Add Sub-tag**, **Merge Tags**, and **Delete**. The Edit Tag dialog showed a name field, Color swatches, a **Parent Tag** selector, Cancel and Save. The parent selector listed `None` and other available tags, with a checkmark on the current choice. The editor was canceled. This establishes the presence of hierarchical tags and merge/pin controls; selection effects, uniqueness, merge semantics, depth and delete behavior remain untested.

## Taskovsky implementation status

Use the [dedicated parity tracker](../parity-implementation-status.md) for current implementation and remaining differences. The earlier comparison in this reference document is superseded. Presence of these TickTick controls does not establish their full semantics or authorize expanding Taskovsky scope.
