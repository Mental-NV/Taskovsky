# SCHEDULE-ZONE-005 — Preserve implicit Mac Schedule time zones

Status: Implemented, independently reviewed and locally verified for the cases below. Base `b82d6c0`; ongoing Tasks/Calendar correctness authorization. Affects BUS-012/014, UX scheduling and TT-012/016.

## Verified defect and bounded contract

Mac Tasks Schedule seeds its displayed zone from the task or host zone, then previously stored that display value even when the user did not edit it. Native untouched OK changed two owned nil-zone tasks to Europe/Moscow; the repeating task also lost its saved current-occurrence baseline because the store interpreted the new zone as a series edit.

Capture the original optional stored identifier and effective display identifier when the editor opens. Keep nil when the selected display identifier is unchanged or returns to that initial choice. Preserve an original explicit identifier exactly, including aliases. Persist a different selected identifier as an explicit zone. Existing wall-clock translation, date/recurrence editing and intentional series-change semantics remain unchanged. No new floating-time mode or implicit-zone control is introduced; iPhone already preserves its optional zone and is not changed.

This is not a completely write-free OK fix. Existing modification-time writes and inferred reminder-provenance normalization remain outside scope. Do not claim workspace bytes remain identical after an untouched save. No UI geometry, fonts, colors, icons, animation, storage schema or permissions change.

## Acceptance

- Nil unchanged/away-and-back, explicit unchanged/away-and-back and explicit new selections retain the intended optional identity.
- The opening fallback is captured once; later fallback changes do not silently pin a zone.
- Saving unchanged zone through TaskStore preserves a current-occurrence baseline; an intentional different zone remains an ordinary series edit.
- Exact schedule instants, including the second repeated DST hour, are unchanged when the zone is untouched. Existing rezone translation is not redesigned and arbitrary edited-away/back schedules are not promised byte-identical.
- Native before/after uses owned Plain and Occurrence tasks; audit stored zone and recurrence metadata, not just visible dates. Test Cancel and one explicit zone change separately where feasible.

Final tests, Mac/iPhone builds and independent review pass. Corrected native JSON audit preserves untouched nil/explicit zones, the occurrence baseline and exact schedules; intentional Tokyo selection persists and Cancel leaves Plain unchanged. [Verification evidence](../spec/verification.md#mac-schedule-implicit-zone-preservation). Exact-head hosted CI is checked before merge.

Follow-up observation corrected the initial display-discrepancy report: the visible Tokyo Time field and caption both showed 13:15; the Computer Use accessibility representation reported 07:15. A standalone AppKit probe found that the native date-picker cell exposes the absolute Date as its accessibility value, independently of its display zone. This does not establish a visual or VoiceOver defect. Minute editing through the probe was not reliably activated and remains unverified; no date-picker behavior change is included. See the [verification correction](../spec/verification.md#mac-schedule-field-observation-correction).
