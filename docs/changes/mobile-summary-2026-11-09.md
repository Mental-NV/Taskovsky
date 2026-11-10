# MOB-SUMMARY-001 Editable local Summary on iPhone

The [TickTick audit](../archive/ticktick-parity-audit-2026-11-01.md) observed an editable period report. [Taskovsky’s Summary contract](../spec/business.md#bus-024) defines the report scope and output. Desktop and iPhone share the Foundation report generator and keep separate editors and filter controls.

Summary follows Smart List visibility and order. Smart List save errors stay above the scrolling list so they remain visible with Summary enabled. The iPhone presents editable plain text, Regenerate, Copy and Save as Note. Its filter sheet stages the period, lists, status, grouping, fields and next-period option. Done regenerates when options change. Cancel preserves the previous options and edited report. All Lists excludes archived and opted-out lists. An explicit selection includes the chosen list. Period boundaries and date headings use the report calendar. A due field uses the task’s own time zone when set and the report time zone otherwise.

Save as Note writes the current report to an Inbox note with no schedule, reminders, tags or priority. It uses the existing capture recovery and durable identity. A failed write leaves a recoverable draft that does not submit on relaunch. The report editor itself keeps text for the current view session.

See the [verification record](../spec/verification.md#mobile-summary) for report boundary tests, fixture comparisons, and separate native checks.
