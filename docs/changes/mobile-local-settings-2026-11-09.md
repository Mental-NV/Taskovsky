# MOB-SETTINGS-001 Local Calendar and capture preferences

The iPhone drawer opens a tall, grouped Settings sheet with a centered title and blue confirmation control. Changes stage until Done. Cancel can discard the draft, and a failed save leaves the choices open for review or retry.

Settings expose the Calendar week start and defaults for new tasks. These include date, list, tag, priority, timed duration, insertion position, task time zone and timed or all-day reminder choices. Recognition settings control whether dates are recognized and whether recognized date and tag text is removed. Date labels and weekdays follow the device locale. Smart Lists and Calendar View Options retain their own screens.

A saved change replaces only the selected JSON members in the settings file. Workspace bytes and sibling preferences stay intact. An existing unavailable default can remain selected, and newly chosen defaults must refer to available lists or tags. About shows local workspace status and the compatibility lock when present.

The reminder choices affect saved task data. OS reminder delivery remains a separate gate, and external integrations remain deferred. See the [verification record](../spec/verification.md#mobile-local-settings) for the tested workflows.
