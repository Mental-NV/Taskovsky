# SEARCH-DATE-003 — All Dates is a reset

Status: approved bounded source-backed UI correction under autonomous Tasks/Calendar direction.
Base main `40c09ba`.

Full Search reused a generic toggle for `.all`, allowing `.all` plus Next Week/Custom. The shared matcher ORs selected rules and `.all` always succeeds, so later specific choices appear selected but do not narrow results. This is a reproducible source-state defect, not a guessed TickTick combination rule. Retained reference calls the broad control All Dates.

Make All Dates clear selected date rules; use empty set as the canonical unfiltered state. Selecting a specific rule or confirming Custom removes any `.all` sentinel, while preserving existing OR combinations among specific rules. Custom cancellation stays inert, All Dates retains inactive custom bound values and clears only date criteria, and Save as Filter sees the applied normalized selection. Other filters, shared matching/storage and iPhone unchanged. Display All Dates instead of Any date for the Search reset item and show its checkmark when no date rules are selected.

Require regression of Any/All reset → Next Week narrowing, broad reset after a specific/custom choice, cancellation and unchanged other filters. Source/test/native evidence kept separate, light theme only; no settings/capture retry.
