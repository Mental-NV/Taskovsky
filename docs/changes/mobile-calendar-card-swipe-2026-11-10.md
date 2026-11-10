# CAL-MOBILE-CARD-SWIPE-001 — Open recurring Calendar schedules with a swipe

TickTick's FAQ describes swiping right on a recurring task in Calendar List or Month and using the date popup to skip the current occurrence. Taskovsky maps Calendar List to its Agenda and uses the same Schedule editor in Agenda and Month. [TickTick Calendar FAQ](https://help.ticktick.com/articles/7055792921664028672).

Swipe right from the task title in left-to-right layouts. The gesture follows the leading edge in right-to-left layouts. The editor opens when the finger lifts after a horizontal swipe. The title tap still opens task detail. The card menu and accessibility action also open the editor. Vertical movement scrolls the Calendar. The completion control, drag grip and resize handles retain their own gestures.

The shortcut applies to current task cards whose series can advance according to the shared [skip rules](calendar-skip-occurrence-2026-11-10.md). Forecasts, terminal series and checklist previews are ineligible. Skip this occurrence stages the advance, Done saves, Cancel discards it and Calendar Undo restores the previous schedule. The swipe itself writes no data. Full Month keeps its visible week through the sheet and schedule changes.

The reference establishes the workflow and direction for left-to-right Calendar. Using the existing editor, mirroring the gesture and using a 36-point threshold are Taskovsky choices.

[Verification](../spec/verification.md#mobile-calendar-card-swipe).
