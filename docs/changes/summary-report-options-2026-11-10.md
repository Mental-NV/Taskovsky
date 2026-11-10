# TASK-SUMMARY-002 — Local Summary criteria and fields

Status: implemented on Mac and iPhone. [Verification](../spec/verification.md#summary-report-options).

The [TickTick Notes and Summary guide](https://help.ticktick.com/articles/7055780476358754304) documents tag and priority scope, report sorting, and optional completion date, status and progress fields. Exact sorting choices and generated punctuation were not observed in the installed reference.

- List, tag, priority and status criteria intersect. Multiple choices within a group are alternatives. An empty tag or priority selection includes all values. A selected parent tag includes its descendants. Explicit list selection keeps the existing archive and smart-list exclusion override.
- Sort applies within each report group and to Next Period Tasks. Workspace Order preserves existing behavior. Date uses due date, then completion or Won't Do date, with earlier dates first. Priority puts higher priorities first. Title uses localized alphabetical order. Ties preserve workspace order. Sorting never changes stored task order.
- Completion Date appears only when a task has a completion timestamp and uses the report's time zone. Status reports Undone, Completed or Won't Do. Progress uses the current task progress, including checklist-derived values. Selecting these fields changes output only, and all are off by default.
- Mac options regenerate in place. Its narrow Filter popover scrolls. iPhone stages filters, fields and sort until Done. Cancel preserves the existing text and options. Saving an edited report still creates an Inbox note with the exact text.
- Verify selection intersection, parent tags, sorting and ties, independent fields, and an edited report saved to the local workspace. [Local report presets](summary-report-presets-2026-11-10.md) are covered by the follow-up change. External sharing and third-party integrations remain deferred.
