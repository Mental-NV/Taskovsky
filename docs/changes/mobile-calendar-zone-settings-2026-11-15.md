# C12 — consolidated Time Zone Settings

## Evidence and scope

The original mobile inventory observed View Options → Additional Time Zone → Time Zone Settings, with an Additional Time Zone toggle, Current Time Zone value and Add Time Zone. This bounded presentation change consolidates those existing controls. It does not infer reference zone limits, selection behavior or persistence timing.

| Element | Placement / wording | Behavior |
|---|---|---|
| Additional Time Zone | View Options entry, On/Off summary | Opens staged settings; no persistence on entry |
| Additional Time Zone toggle | First child row | Changes child-local enabled state; disabling retains configured zones |
| Current Time Zone | Next read-only row | Shows existing Calendar primary zone, does not change system settings |
| Configured zones / Add Time Zone | Below current zone | Existing labels, replacement, delete/reorder, limit and duplicate exclusion retained |
| Cancel / Done | Child toolbar | Cancel discards both child fields; Done updates enabled and normalized zones together in parent draft |
| Parent Cancel / Done | View Options toolbar | Cancel discards draft; Done uses original revision-checked persistence |

Taskovsky retains explicit Cancel/Done instead of assuming TickTick Back saves. Existing secondary ruler semantics and domain/storage schema are unchanged. Additional time zones remain editable while disabled. This is structural similarity, not pixel certification.

## Verification

Pending: full suite/release, independent source review, isolated native staging/persistence/ruler regressions, exact-head hosted CI and safe screenshot. Do not interpret test source as a passed run.
