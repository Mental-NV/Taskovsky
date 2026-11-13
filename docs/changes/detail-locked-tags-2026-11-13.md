# DETAIL-TAG-001 — Honest locked tag controls

TaskDetail already prevents removing tags when a task is deleted or its list is archived, but its chip buttons remained enabled and advertised “Remove tag.” This made a read-only detail offer an action that silently did nothing.

Disable those same chip buttons when locked and expose a read-only tag name in tooltip/accessibility label. Active chips keep Remove tag behavior and existing styling. Tags remain visible; restore/unarchive re-enables removal. The existing action guard remains defense in depth. No data/storage/permission changes or claim about TickTick visual layout.

Acceptance: active removal changes only chosen tag; Trash/archived chips are disabled/read-only and cannot alter tag IDs; restore/unarchive re-enables. Full tests/build/review/native/CI pending. No screenshot or capture retry.
