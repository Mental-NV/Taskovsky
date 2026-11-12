# Local reminder planning foundation (not notification delivery)

## Purpose and authority

Stored reminder editing exists, but no OS scheduler/permission flow exists. This slice adds a pure shared plan only. It does not request permission, register notifications, change device settings, subscribe the user or change Mac/iPhone views. Future adapters remain separate and off until explicit opt-in.

Apple documents device-local scheduling and cancellation independently of APNs. It requires notification authorization and checking current settings before scheduling user-facing alerts. Sources inspected November 12, 2026:
- [Local scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Personal Team installation limitations](https://developer.apple.com/help/account/basics/about-your-developer-account)

These support investigating a local adapter, not a claim that the current ad-hoc Mac build or physical iPhone has delivered a notification. No push service, account sync or paid service is introduced. Physical-device signing and runtime delivery remain independent gates.

## Pure plan contract

The caller supplies a verified persisted workspace snapshot and a finite reference instant. Never plan from an optimistic unsaved TaskStore.data update. The pure function cannot prove where its input came from; adapters must enforce that boundary. Invalid reference instants fail closed and cannot produce a reconciliation that cancels existing requests.

Only actual stored task records that are open, not Won't Do, not trashed and not in archived lists are eligible. Notes are excluded. Smart-list exclusion, parent visibility, Calendar source filters and view settings do not suppress an otherwise eligible reminder. Missing-list records use existing SmartListEligibility behavior. No recurrence forecasts or synthetic successors are generated; materialized successors are independent records. Repeating tasks use their existing saved effectiveReminderDates exactly like other tasks.

Use sorted/deduplicated effective reminder instants, including a valid enabled timed-duration endpoint. Drop nonfinite dates and instants at or before now; no catch-up barrage. Stored absolute instants are not reinterpreted in the current timezone. Distinct repeated-hour instants across DST remain distinct. Do not infer a reminder merely from a due date.

Select the earliest 32 future reminders across the workspace, ordered by instant then stable task UUID. This is a conservative app policy, **not a claimed OS limit**. A caller may lower the budget to 0...32; larger/negative input clamps. Report eligible/deferred counts so truncation is visible. A later adapter must replenish on activation/verified durable writes; this finite plan alone promises no indefinite background coverage.

Each descriptor has a stable namespaced ID from task UUID and exact normalized absolute-instant bits, task ID, fire instant, generic title `Taskovsky reminder` and generic body `A task reminder is due.`. No private task title/body/list/tag is included in the notification content. Identical task/instant pairs deduplicate even if input records duplicate; distinct tasks at the same instant remain distinct. This deduplication does not repair malformed workspace records.

## Pure reconciliation

Compare desired descriptors with supplied currently pending descriptors. Add missing/changed owned descriptors and remove only obsolete IDs in the exact planner namespace. Preserve unrelated pending requests; never use remove-all. Retained unchanged requests are not rescheduled. Invalid-clock plans produce no operations. An empty valid plan may cancel obsolete owned requests. This describes a diff, not an atomic OS transaction or delivery receipt. Future adapters must handle request errors, concurrency, authorization revocation and partial reconciliation explicitly.

## Verification and later slices

Foundation-only tests: eligibility and smart/archive differences, endpoint dedupe, stored recurrence only, exact DST instants, stable IDs/order, generic content, capacity/deferred counts, past/nonfinite inputs, no-op/change/removal/foreign-request reconciliation and invalid-clock safety. Compile shared model through Mac and iPhone targets. No native permission/registration test in this slice.

Later Mac adapter proposal must read acknowledged persisted snapshots, remain opt-in/default-off, use explicit contextual authorization (not silent provisional authorization), expose disabled/denied/errors/deferred counts and preserve stable QA identity. iPhone UI/adapter stays separate. Focus, OS settings and system scheduling can delay/suppress alerts; no exact delivery guarantee. Critical alerts, time-sensitive privilege, background agents, network integrations and notification action buttons are outside this first plan.

## Adapter review prerequisites

The pure diff describes one selected workspace, not a multi-workspace namespace. Before enabling registration, define workspace switching and isolated-QA ownership explicitly so one workspace cannot accidentally reconcile another's requests. Pending-request decoding must round-trip the exact descriptor instant/task ID in metadata; comparing against a rounded calendar trigger alone would cause repeated replacement of fractional-date requests. Any later precision conversion must be specified and tested rather than inferred here.

A failed/unreadable/unsupported workspace load must not be converted into a valid empty plan: the adapter must retain existing pending requests and report the load failure instead. Likewise, transient nil document state during reload is not evidence that all reminders were deleted. This provenance/failure distinction cannot be inferred from a bare WorkspaceData value and belongs at the adapter boundary.
