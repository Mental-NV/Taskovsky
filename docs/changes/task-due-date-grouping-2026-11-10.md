# TASK-GROUP-002 — Group Tasks by Due Date

The active local Tasks and Calendar parity goal covers this Mac and iPhone List feature. The original prototype was verified on a local snapshot based on the one-hour Postpone revision at `e92e0b8`. The November 12 recovery ports this slice onto merged main `411f0ef123b8bc15bfa6af75cdac4c6307674489`. [Business rule](../spec/business.md#bus-019) and [macOS List](../spec/ui-ux.md#ux-005).

TickTick documents grouping by time and ordering by priority in its release notes. The exact date buckets and persistence policy of the installed reference remain unverified. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

## Behavior

- In eligible Task Lists, the Sort menu offers Group by Due Date alongside Group by Created Date. The grouping choices are mutually exclusive. Selecting the active option again restores the platform's default grouping. Sort and grouping can be changed independently. iPhone adds Priority to its existing order options.
- The due-date groups are Overdue, Today, Tomorrow, one heading for each later civil day, and No Date. Empty groups are omitted. Overdue honors the existing top or bottom setting. The active sort determines row order within a group, subject to the existing parent-child presentation. Pinned and history rows retain their separate groups.
- Grouped row captions use the same day as their headers. Timed deadlines and expanded timed ranges use the display zone. All-day deadlines and both endpoints of an expanded all-day range retain their original civil dates. Group identities use dates, so days with the same month and day in different years stay separate. Notes use the same date rules in this explicit grouping.
- The grouping preference is device-local. Existing creation-grouping preferences remain readable. Grouping or sorting makes no change to task, section or Calendar data. Computed date groups temporarily replace named sections in the List renderer. Returning to default restores the named sections. Board, Timeline, search, reminders, completed history and Trash retain their own presentation. Manual reordering remains unavailable inside computed date groups.

## Acceptance

- Combine Due Date grouping with Priority and a timestamp sort. Verify the same buckets with different row order and check stable equal-priority ordering on iPhone.
- Change grouping, relaunch and verify that the chosen grouping and sort return. Switch back to Created Date and then default. Exercise the old creation preference and verify preservation of the workspace and settings files.
- Check all-day dates across time zones, timed deadlines around local midnight, overdue position, pinned and history separation, named sections, and dates in different years. Build both apps and exercise the local controls in disposable QA workspaces.
