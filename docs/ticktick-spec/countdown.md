# Countdown: observed behavior

This module is outside the original Taskovsky implementation scope. Observations are from the installed macOS app in light appearance on 3 November 2026; account settings can affect defaults and available styles. Personal data is omitted.

## Workspace and cards

The Countdown title dropdown switches between Active and Archived. Active displays rounded cards containing an icon and title, a large centered blue value, and a muted date caption. On the observed date, a future card showed a number with `Days until`, a past card showed a number with `Days since`, and a newly created card dated that day showed **Today** and its date. The layout showed three cards in one row before creation and four smaller cards in one row after creation at the same wide window size; exact size constraints and breakpoints are unmeasured.

The plus menu offers **Countdown**, **Anniversary**, **Birthday**, and **Holiday**. The workspace overflow offered **Show Group** in the observed state; its effect was not tested. Right-clicking an active card offers **Edit**, **Style**, **Notes**, **Archive**, and **Delete**. Notes opens a dialog with the card icon and name, a multiline `Add a note...` field, a small clock-like control, Cancel and Save. The empty note was canceled; the small control and save behavior remain unverified.

## Add and style

Choosing Countdown opens an **Add** dialog. It contains icon editing, a name field, separate year/month/day fields, Reminder, Repeat, Type, Day Calculation Mode and Show controls. Initially the date was the current date, Repeat was None, Type was Countdown, calculation was Standard, and Show read `Show on the day in the Smart List`. Next was disabled while the name was empty and enabled after text was entered. These observations do not establish all validation rules or factory defaults.

- Reminder showed None, On the day, 1 day early, 2 days early, 3 days early and 1 week early; the time displayed alongside each was 09:00 in this account. On the day and 3 days early were simultaneously checked. The menu also had Recents, Cancel and OK.
- Repeat offered None, Daily, Weekly with the selected weekday, Monthly with the selected day of month, Yearly with the selected date, and Custom. Custom was not opened.
- Type offered Countdown, Anniversary, Birthday and Holiday. Type-dependent changes were not tested.
- Day Calculation Mode offered **Standard**, described as day 1 starting the day after the selected date, and **Standard +1 day**, described as day 1 starting on the selected date.
- Show opened an `In the Smart List` menu with On the day checked. The rest of the menu extended beyond the captured dialog, so its options are not established.

Next opens a **Style** step with a large live card preview, a horizontally scrollable strip of styles, a row of color swatches, Back and Save. Some style thumbnails carried a Premium crown. A disposable countdown using the current date and initial style was saved, producing the Today card described above. Other style, color, premium and persistence behavior was not exercised.

## Archive

Archiving the disposable card removed it from Active and showed an **Archived** toast. It appeared with the same title and Today display under **Archived Countdowns**. Right-click there offered **Restore** and **Delete**; neither action was invoked. The probe remains archived.

## Remaining evidence

Inspect each type, custom repeat, all reminder and visibility choices, time and date edge cases, Smart List integration, edit and note persistence, grouping, style interactions, restore and deletion confirmations. Measure card layout across window widths, colors, fonts, hover, keyboard and motion; the examples above do not establish general formulas or geometry.
