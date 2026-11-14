# Mobile schedule Date month grid — November 14, 2026

Live reference inventory D07 shows a visible month grid in Date scheduling, with nested Time/Reminder/Repeat controls. This core presentation slice replaces Taskovsky's compact single-date picker with the system graphical month picker for non-Duration schedules. It retains the same `due`/`edit.chooseDay` binding, calendar/time zone, shortcut actions, outer Cancel/Done and existing duration/time/reminder/repeat logic. Duration schedules retain the prior compact Date and Start/End presentation.

This is partial parity: native system grid styling, existing form/toolbars and toggles remain. Date/Duration tabs and reference popup styling are not implemented here. No new persistence behavior, notification permission, integration or accessibility-layout polish. Preserve existing support; target core ordinary light-theme scheduling.

Acceptance gates: full Swift suite, release/signature, independent review; native visible-grid selection, outer Cancel, save/reopen/relaunch, existing shortcuts and nested/Duration cancellation; inspect actual Simulator screenshots and exact hosted CI before merge. Original worktrees and user device data remain untouched. No calibrated pixel or physical-device parity claim.
