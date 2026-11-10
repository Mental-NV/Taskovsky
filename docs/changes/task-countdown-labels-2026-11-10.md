# TASK-DATE-003 — Countdown labels for dated tasks

The active local Tasks and Calendar parity objective authorizes this work on Mac and iPhone. The feature branch starts from merged main `36a9e17`.

On Mac, open More in a Tasks list and choose Show Countdown or Hide Countdown. The device remembers the preference. The Option key still reveals the full scheduled date or range. On iPhone, enable Countdown Mode under Settings → Date & Time. Tap an eligible task’s date to switch that row between its ordinary date and countdown. The setting survives relaunch. Row choices last for the current app session and clear when the setting is turned off. The title and swipe gestures retain their existing actions.

Open tasks with deadlines are eligible. An all-day task counts civil days in its task calendar. Timed tasks show elapsed hours and minutes within 24 hours, and otherwise show civil days where a day boundary separates the deadline and now. The current deadline shows Due now, and an all-day date on the current civil day shows Due today. Overdue labels name the elapsed or civil amount. While visible, countdowns refresh as time advances. Task data, settings files, list sorting and Calendar projections are unaffected by the display choice.

The [TickTick FAQ](https://help.ticktick.com/articles/7055792921664028672) establishes the separate desktop and mobile controls. The [web changelog](https://ticktick.com/public/changelog/) also describes switching the List View from due time to countdown. Rounding, refresh cadence and the device preference are Taskovsky choices. This is a task-date presentation feature under [UX-006](../spec/ui-ux.md#ux-006) and [IOS-004](../spec/iphone.md#ios-004).
