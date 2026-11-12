# iPhone local reminder adapter proposal

Status: proposed; source/architecture assessment only. No iPhone notification implementation or OS effects in this change. Mac PR53 remains a separately unverified candidate, not evidence of phone delivery.

## Authority and current architecture

IOS-007 / D04 conditionally authorize straightforward local notifications for saved reminder dates. The iPhone target is iOS 17 and imports TaskovskyDomain and TaskovskyWorkspace, not TaskovskyCore/AppKit. PhoneWorkspaceModel publishes a WorkspaceDocument only after repository reads or acknowledged transactions; its directory is fixed per model. MobileRootView already refreshes on scenePhase.active. PhoneLocalSettings is a separate staged native form. Existing capture/field drafts must never schedule notifications.

Shared LocalReminderPlan is available on current main: eligible actual saved tasks, exact instants, generic content, 32-request conservative app budget, namespaced diff. WorkspaceFileRepository.loadReadOnlyForReminders rejects unavailable/incompatible snapshots and pending journals without recovering/writing them. Reuse these shared rules. Do not duplicate the application, import Mac views, or copy Mac-only store observation into the phone.

## Bounded proposed implementation

Add a phone-specific transport/coordinator and a separately owned notification settings section. Keep shared business planning in Domain and persisted validation in Workspace. Do not extract or refactor the unverified Mac transport as a prerequisite. Keep the adapters independently testable using injected notification centers, clocks and local preference stores. Shared orchestration extraction may follow verified platform behavior; it must not weaken ownership boundaries or couple views.

Default off, no center access or file creation when preferences are absent. Only an explicit Enable on This iPhone action may request alert/sound authorization. Persist intent atomically before requesting or scheduling. Startup/reload/activation/document-revision updates never prompt. Restore enabled intent without repeating authorization. Denied authorization is visible, with no background retry prompt.

Use only a newly read compatible saved snapshot from the current directory; never use a draft, nil load fallback or optimistic presentation state. Treat document revision publications only as refresh signals: reloads/refusals may also publish a document. Reconcile on startup/activation, nonnil saved revision changes and a bounded foreground timer. Never convert a nil failure publication into an empty cancellation plan. Stop the timer while backgrounded. Pending OS notifications may still deliver while the app is not running, but there is no indefinite background replenishment guarantee. No background execution entitlement, push server, APNs, account sync or external integration.

## Stable iPhone ownership

Do not key ownership solely by an absolute sandbox path: a container relocation across installation/update can otherwise strand old pending requests or invalidate saved opt-in. Serialize first opt-in so concurrent actions cannot mint competing identities. On first explicit opt-in, atomically create a versioned preference record containing a random workspace UUID and enabled intent. Scope request identifiers by app identity plus that persisted workspace UUID. Keep that record in the model's own Application Support directory, with the same local file-protection policy as the workspace. Normal data and each QA UUID directory are independent. Absent/invalid directory cannot create a notification service.

Missing preferences are off. Corrupt, duplicate-key, unknown-version or unreadable preferences fail closed and remain byte-preserved. Never silently generate a replacement identity for unreadable data. Relocation tests move one owned fixture, not clone an active identity into two workspaces. A compatible moved container retains the same workspace UUID; a different QA directory does not inherit production opt-in. Future import/clone semantics require a separate identity decision and are not introduced here.

Disable stops new scheduling and attempts cleanup only for its canonical owned requests, even if saving off fails. Report failure and latch the process off so activation cannot reload an old true preference and silently resume. Persisted false remains a cleanup marker so a failed cancellation can retry on restart. Never remove all notifications or alter another workspace's requests.

## Transport, precision and failure contract

Keep generic title/body, exact task UUID and original fire-date metadata. Use one-shot Gregorian UTC calendar triggers, rounding fractions upward to whole seconds; validate representability before constructing a trigger. Inject the notification clock independently: PhoneWorkspaceModel.now intentionally uses a historical fixture clock in QA and is not a scheduling clock. Re-read current time after queued waits and before additions; expired reminders do not become immediate catch-up alerts. Authorization and system Focus/settings may suppress delivery. No exact banner/sound timing guarantee.

Serialize complete reconciliation operations across awaits. Read pending requests, then a fresh compatible saved snapshot and clock. Unknown/malformed foreign requests remain untouched; an owned-ID collision fails before overwrite. Report failure stage and completed add/removal-submission counts; retry against actual pending state. Delegate foreground presentation only for canonical owned requests while enabled, never arbitrary incoming notifications.

## Phone UI contract

Provide a distinct local-notifications section in the existing Settings sheet. Its explicit action is immediate and separate from the form's staged Done/Cancel preferences: keep it outside the staged draft and explicitly label that Cancel does not undo notification changes, so Cancel cannot appear to roll back an OS permission decision. No custom switch that prompts while initializing. Use native Section, multiline leading Text and Button with at least a 44-point touch target, system Dynamic Type and semantic primary/secondary/error colors. Labels: Local Notifications; Enable on This iPhone / Disable on This iPhone; Updating…; explicit authorization/error/plan-limit status. No custom icon/animation. Native VoiceOver labels distinguish the action from task reminder defaults. Other settings remain staged until Done.

## Verification gates

1. Fake center + owned file tests: default off/no prompt/no file; explicit grant/deny/error; restore without prompting; malformed/duplicate/version/key/write failures; session-off latch and cleanup retry; sandbox relocation retaining identity; QA isolation; saved revision versus draft/nil failure; queued clock/snapshot changes; partial failure/retry and foreign ownership.
2. Pure trigger tests: DST repeated-hour instants, timezone independence, subsecond upward rounding, exact metadata, expired/nonfinite/out-of-range refusal. Never instantiate the real center in these tests.
3. Compile iOS 17 target with available SDK; preserve Mac build/tests and separate views. An SDK build is not an iOS 17 runtime check.
4. Simulator UI checks on an owned QA session only after the intended harness is reviewed; do not enable real notifications as an incidental UI test.
5. Separately approved physical-device Personal Team smoke test remains required by D04 before claiming notification delivery readiness. Record actual iPhone/OS/signing, request permission explicitly, schedule one generic owned reminder, observe/cancel and restore test preferences. A paid account is not assumed necessary, but signing/device feasibility is unverified. Do not silently remove this gate because fake/simulator tests pass.

No implementation or permission/registration action is authorized by the status of this proposed document alone. Continue only under the user's standing task scope and the coordinator's bounded assignment; real device effects still require explicit approval.
