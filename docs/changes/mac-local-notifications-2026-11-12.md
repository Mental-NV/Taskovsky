# Mac local notifications: explicit opt-in integration

Status: implemented; fake/pure tests, full local suite and Mac/iPhone builds passed. A separately approved native attempt verified Off/Enable/error/Disable and failed at OS authorization without a prompt; delivery remains unverified. See verification evidence.

## User outcome and scope

Enable local reminders on this Mac explicitly in Settings → Date & Time. No network, APNs, account sync, critical/time-sensitive privileges, actions, background agent or iPhone adapter. Reuse the tested planner/coordinator; do not change stored task reminder semantics. This adds actual transport/UI code but is not evidence of a delivered OS alert.

## Opt-in and ownership

Default off. A versioned local preference file is bound to the canonical workspace/settings/app scope, outside the shared settings schema. Missing file means off and performs no OS notification access. Malformed/unreadable/incompatible or duplicate-key preferences fail closed and are never overwritten automatically. Persist enable intent atomically before requesting authorization or scheduling. Only the explicit Enable action may request authorization. Startup, activation and saved-write refresh never prompt.

Disable stops in-memory scheduling and attempts owned cleanup even if preference persistence fails; clearly report that it was not saved and may remain enabled on restart. Successfully persisted off intent also triggers owned-request cleanup, retryable on activation/restart if cleanup failed. Preserve unknown/foreign pending requests. Current application owns one immutable workspace per process; another workspace/app/QA instance has an independent namespace. No runtime workspace switching is introduced.

## Saved input, clocks and precision

Refresh on launch/activation and acknowledged successful workspace/settings writes, not optimistic published data. Read fresh compatible persisted snapshots. Missing/unreadable/unknown data or transaction journals retain pending requests and report failure. Serial queues re-read the clock after waits; system trigger creation checks time again. No catch-up alerts for expired instants.

Use one-shot Gregorian UTC calendar triggers. Round fractional instants upward to the next whole second, never earlier than the stored instant; keep the original exact instant/task metadata for stable reconciliation. This is trigger precision, not an exact delivery guarantee. Test DST repeated-hour instants, timezone changes, subsecond inputs and queued delays. Generic notification title/body only; default sound requested only with authorization. Foreground presentation uses the same generic banner/sound policy, subject to system settings and Focus.

The 32-request app budget remains bounded. Replenish at startup/activation, each minute while the workspace window runs and after successful writes; no promise of indefinite replenishment while quit. Report pending-plan/deferred counts and explicit errors rather than claiming delivery.

## Mac settings UI

Add a dedicated local-notifications card after existing Date & Time controls, using existing card/row styling. Title “Local Notifications” and body explanatory text use existing 14-point row / 12-point secondary typography, leading alignment, semantic colors and no custom animation. Reuse 8-point card corners, minimum 40-point row height, 18-point horizontal padding and 10-point lower padding on explanatory text. Explicit native button reads “Enable on This Mac” when off and “Disable on This Mac” when opted in. Disable the action while an operation runs, show “Updating…” status, and retain readable inline error/denied/status text. No hidden automatic prompt, repeated-click races, bespoke icon or change to existing reminder-default menus. Keyboard focus/accessibility come from native controls.

## Verification and native test gate

Unit/fake tests use owned temporary preference/workspace files and injected centers/clocks. Cover missing/corrupt/write-failed opt-in; restart without prompting; explicit enable/deny/error; disable failure/retry; failed saved snapshot; exact metadata/UTC trigger conversion; no early alert and expired rejection; successful-write signals only; serialized delayed operations. Compile/package Mac and compile iPhone without launch or real center calls. Independent review before merge.

Proposed later native test, requiring explicit approval: stable Taskovsky QA app, disposable isolated workspace/settings/preference files, one generic future reminder, explicit Enable and macOS authorization prompt if needed; observe one banner, then Disable/cancel owned request and restore fixture/app. No existing personal task/settings changes. Signing, actual macOS delivery, Focus behavior and physical iPhone remain NOT RUN until separately verified.
