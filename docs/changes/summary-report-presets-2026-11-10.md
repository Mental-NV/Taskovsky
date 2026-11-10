# TASK-SUMMARY-003 — Local Summary presets

Implemented on Mac and iPhone. [Verification](../spec/verification.md#summary-report-presets).

The TickTick guide documents saving a Desktop Summary configuration as a template for reuse. The exact preset management interface and iPhone behavior were not observed in the installed reference. [Notes and Summary](https://help.ticktick.com/articles/7055780476358754304).

- A named preset captures period, custom dates, list and tag IDs, priorities, status, grouping, sort, fields and Next Period Tasks. It does not include generated or edited text. Relative periods resolve against the current report calendar when used. Custom dates retain their saved endpoints. Missing list and tag IDs remain in the preset, so their absence cannot silently broaden a report to all lists or tags.
- Mac exposes Presets in the wide Summary options rail and the compact Filter popover. Save Current Options names a preset. Selecting one applies its options. Manage Presets supports renaming and confirmed deletion. Saving, renaming and deleting leave the current report text intact.
- iPhone exposes Summary Presets in Summary Filter. Applying a preset changes the filter draft. Creating, renaming and deleting presets change the staged collection. Done publishes changes, and Cancel or interactive dismissal discards them without regenerating the report.
- Presets are device-local preferences, isolated in QA and separate from workspace JSON, workspace settings and task/note templates. Names are trimmed and unique without regard to case. Rename preserves identity and options. Unreadable preset data is preserved, with preset controls unavailable until the data can be read. The existing initial Summary options and explicit Save as Note behavior are retained.
- Verify complete encoding, names and identity, relative versus custom date evaluation, reuse after relaunch, edits and cancellation, and workspace/settings file preservation. External reporting, account sync and third-party integrations remain deferred.
