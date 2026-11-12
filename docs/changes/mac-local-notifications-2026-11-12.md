# Mac local notifications: explicit opt-in integration

Status: draft implementation, native delivery blocked and deferred at the user’s direction. Fake/pure tests, full local suite and Mac/iPhone builds passed. Two approved bounded native attempts verified Off/Enable/error/Disable and failed at OS authorization without a prompt; delivery remains unverified. Do not treat this branch as a released notification feature.

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

Deferred future native test, requiring a new agreed diagnostic plan and explicit approval: stable Taskovsky QA app, disposable isolated workspace/settings/preference files, one generic future reminder, explicit Enable and macOS authorization prompt if needed; observe one banner, then Disable/cancel owned request and restore fixture/app. No existing personal task/settings changes. Build signing was checked; native authorization failed as recorded below. Actual macOS delivery, Focus behavior and physical iPhone delivery remain unverified.


## Deferred native blocker — November 12

On macOS 27.0.1, the stable isolated Taskovsky QA app’s explicit authorization action failed without presenting an OS prompt. The first attempt reported authorization failure; one approved diagnostic retry on source `6b341449` exposed sanitized `UNErrorDomain (1)`. Apple’s `UNErrorCode.notificationsNotAllowed` identifies lack of authorization, not its underlying cause. See [Apple’s error documentation](https://developer.apple.com/documentation/usernotifications/unerror/code/notificationsnotallowed).

Both attempts submitted zero additions/removals at failure. After explicit Disable, scoped system logs reported zero pending notifications. The app was quit before the owned test reminder’s due time. Disposable workspace/settings, test preference absence, QA defaults and the prior guarded app bundle were restored and verified. No notification delivery or successful authorization is claimed. No system notification permission reset was performed.

Read-only inspection found a launch-provenance difference: QA’s signed bundle main executable is a guarded shell launcher that executes a separate Mach-O payload; normal packaging uses a Mach-O main executable. This is a hypothesis for future investigation, not a demonstrated cause of error 1. No native-entry replacement, permission workaround, signing change or further retry was performed. The user explicitly deferred this blocker and requested fake notification evidence for now.

Revisit only with a separately reviewed plan preserving stable QA identity and strict owned-fixture isolation, explicit approval for any changed native test effects, and verified disabled/zero-pending initial state. Keep delivery readiness blocked until authorization, one generic owned reminder and cleanup are observed. Fake-center, pure trigger and persistence tests remain useful but cannot establish OS delivery. The draft real transport must not silently replace those tests with a claim of readiness.
