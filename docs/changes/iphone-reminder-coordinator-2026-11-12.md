# Phone reminder coordinator: fake-only foundation

Status: implemented fake-only non-UI coordinator. No concrete OS transport, phone lifecycle/settings UI, permission request or notification registration is added. Mac native authorization remains deferred.

Bind one coordinator to one existing phone directory (`workspace.json`, `settings.json`, `local-notifications.json`) and app scope. Reuse the merged stable UUID preferences and shared persisted planner. The center is mandatory injected abstraction; only test fakes implement it in this slice. One coordinator owns the directory, with no external concurrent writers or runtime workspace switching.

Serialize whole enable/refresh/disable operations across suspension points. A queued disable follows an in-flight enable and then cancels its owned requests; it cannot interleave and be overtaken by a stale enable. Missing preferences stay off without center access. Explicit enable persists intent before checking/requesting fake authorization; restore/refresh never requests authorization. A denied request retains intent but reports denied. Expired reminders never become catch-up notifications; check the independent clock after pending/snapshot waits and before each addition.

Read pending state before a fresh compatible saved snapshot, never a draft. Snapshot errors/journals preserve pending state. Reconcile only canonical IDs plus exact task/instant metadata in the persisted UUID namespace; malformed/foreign requests remain untouched, and a desired ID collision fails before writes. Count acknowledged additions and submitted removals, not deliveries. On partial failure retry against actual pending state. Generic content and shared budget 32 remain unchanged.

Disable first latches scheduling off for this process, attempts durable false intent, then cleans only known canonical owned requests even if saving false fails. Report all failure stages, including both persistence and cleanup when applicable. Refresh cannot silently reload old true intent after a failed disable. An explicit successfully persisted enable may clear the latch. Persisted false is a cleanup marker across restart. Missing/corrupt/identity-changed preferences never mint a replacement during refresh; with a previously known identity, disable may clean that namespace while reporting the preference failure. No claim of cross-process isolation or race-proof filesystem access.

Tests: no-record/no-effects, explicit grant/deny/error, no-prompt restore, saved vs draft/invalid snapshots, preference failure and session latch, partial add/remove failure, foreign/malformed collision, delayed operation ordering and clocks. Builds are not physical-device delivery evidence.

Foreground presentation gating, concrete trigger/metadata conversion, UI integration and physical device checks remain deferred adapter work; this coordinator alone cannot deliver notifications.
