# Shared engine and platform architecture

This document proposes a small shared engine with separate macOS and iPhone interfaces. It records the current source boundaries first, then defines a staged extraction that preserves behavior and stored data. The proposal does not require identical editors, navigation, or feature coverage on both platforms.

**Baseline:** static inspection of `main` at `cfdec454acff91285ac00beaa20c0cf0f0961ee1`, dated 2026-11-08. Linked source and test files establish implementation and test intent. The follow-up hosted [CI results](../spec/verification.md#hosted-macos-ci) are separate execution evidence, not verification of the proposed architecture or native UI flows. Everything labeled **Proposed** requires a later implementation task. This change adds no packages, application code, test harness, or iPhone app.

Related documents: [business rules](../spec/business.md), [macOS UI and UX](../spec/ui-ux.md), [iPhone proposal](../spec/iphone.md), [component contracts](components.md), [implementation workflow](../spec/workflow.md), and [parity status](../parity-implementation-status.md).

## Local implementation follow-up — November 9, 2026

<a id="platform-presentation-boundary"></a>

The user directed that Desktop and iPhone keep separate presentation implementations whenever isolated visual parity cannot be guaranteed. Desktop owns its SwiftUI/AppKit views, layouts, editor and interaction state. iPhone owns its SwiftUI/UIKit screens, layouts and interaction state. Domain shares platform-neutral models and business rules. Workspace shares compatible local storage operations. A shared rule change needs Mac regression tests, a verified release build and focused isolated Desktop UI checks when it affects a visible workflow. Record the concrete Desktop risk before expanding a change that could alter its appearance or interaction.

The rich editor has distinct platform implementations. Desktop retains its AppKit editing surface. iPhone uses a selectable UIKit styled preview and an independent plain editor. Keep the original rich payload for unrelated edits and refuse task writes when the storage adapter cannot prove preservation. The [capability matrix](components.md#rich-003) records authoring, rendering, fallbacks and evidence for each platform.

[MOB-FOUNDATION-001](../changes/mobile-foundation-2026-11-09.md) partially implements the proposed seams on `codex/mobile-local-prealpha`, based on merged mobile spec `6ee96ee`. Stable source paths are retained: explicit source lists in Package.swift assign Foundation value/rule files to **TaskovskyDomain**, with no UI, observation, persistence or networking dependency. TaskovskyCore excludes those files, imports/re-exports Domain and retains desktop services plus AppKit editor code. **TaskovskyWorkspace** supplies immutable decoded read sessions retaining original bytes; a conservative actor repository now supports tested title/plain-body patches only for fully known round-trip-safe documents. The phone model now calls that writer through [MOB-EDIT-001](../changes/mobile-local-editing-2026-11-09.md), restricted to its own Application Support directory. `WorkspaceBootstrap` stages a new pair without replacing existing/partial files. `FieldDraftStore` serializes a separate versioned exact-text draft with compact SHA-256 document fingerprints, sequence/closed-identity guards and unknown-file preservation. Phone state publishes repository success only after the atomic replacement, and an operation ticket rejects obsolete refresh completions. This is single-process local storage; independent processes must not share live files, and settings/workspace are not a multi-file atomic transaction. **Mobile/TaskovskyMobile.xcodeproj** consumes Domain/Workspace rather than Core.

`TaskDestination.includes` and `matchingTasks` now own destination membership, history expansion and saved-filter routing; macOS calls them. Sorting, localized groups, full-search composition and the wider command family still need incremental extraction. The Mac schedule view still owns its presentation and assembly of the staged fields. Durable mobile writes cover task/note capture, title and plain-body patches, lifecycle commands and detail schedule transactions. TaskScheduleEdit scopes changes to scheduling fields, while the Mac store and phone share reminder provenance and series reconciliation. `TaskCreation` and `TaskSchedulePolicy` now supply the existing quick-entry, recognition, template and default schedule policies to both platforms. The Mac facade retains its persistence and existing URL-title dispatch; the phone adds no enrichment calls. The Mac facade and phone repository both use TaskLifecycle for graph mutations. Each host owns transient snapshots of pristine successors. The phone repository publishes its snapshot state after confirming the atomic write and binds Undo to the resulting workspace revision. `LegacyRecurrence.nextDate` owns the existing legacy cadence; TaskStore's static method delegates and Calendar projection calls the same helper. No recurrence policy/schema change is intended. The Mac rich controller/adapter is not yet independently extracted, so S2 is partial even though the mobile dependency graph contains no AppKit.

The phone's Calendar adapter uses the shared arrangement projection, grouping, command preparation and schedule Undo validation. Calendar transactions shift manual reminders, while detail date edits preserve those explicit instants. Each host persists through its own store. The phone serializes writes in its repository and holds an in-memory Undo token scoped to one task schedule. [Arrange verification](../spec/verification.md#mobile-calendar-arrange).

Calendar preferences use a dedicated atomic settings command with the same revision check. The command replaces only the recognized Calendar JSON value, preserving the exact bytes of adjacent settings and all workspace bytes. Sparse older Calendar settings and the known single-zone alias decode through Domain defaults. Unknown or ambiguous Calendar settings stay intact. [Preference verification](../spec/verification.md#mobile-calendar-preferences).

The corrected Desktop Calendar union/commands, four-zone cap and coherent controls/visual files were explicitly carried into this isolated branch; `desktop-domain-integration.json` records exact hashes and the projection's pure-helper adaptation. The original dirty Desktop tree was not edited or committed. [Current verification](../spec/verification.md#mobile-calendar-preferences) supersedes the original baseline's target/portability statements; historical tables below identify the original inspection, and proposed command/storage/editor contracts remain unimplemented unless stated here.

<a id="arch-001"></a>
## ARCH-001 Current boundaries and coupling

### Package structure

[`Package.swift`](../../Package.swift) declares macOS 14, a `TaskovskyCore` target, the `Taskovsky` executable depending on Core, and one `TaskovskyCoreTests` target depending on Core. Swift tools version is 6.0 with Swift language mode 5. There is no iOS target, independent editor product, or platform-neutral engine product today.

Core is a useful starting point, but its name does not establish portability:

| Current code | Responsibility and boundary issue |
| --- | --- |
| [Models.swift](../../Sources/TaskovskyCore/Models.swift), [Organization.swift](../../Sources/TaskovskyCore/Organization.swift), [Settings.swift](../../Sources/TaskovskyCore/Settings.swift) | Foundation value models, hierarchy helpers, eligibility, settings, filter evaluation, templates, and text matching already provide reusable logic. Settings also mixes product defaults with UI preferences; these need classification rather than wholesale movement. |
| [TaskStore.swift](../../Sources/TaskovskyCore/TaskStore.swift) | `@MainActor ObservableObject` combines commands, recurrence spawning, lifecycle/cascade ledgers, ordering, JSON persistence, settings persistence, migration, and error reporting. It is not a pure domain engine. Combine is an Apple dependency, not the AppKit blocker, but observation need not define the domain API. |
| [CustomRecurrence.swift](../../Sources/TaskovskyCore/CustomRecurrence.swift), [ScheduleDraft.swift](../../Sources/TaskovskyCore/ScheduleDraft.swift) | Foundation recurrence/duration calculations, nominal-position helpers and `RepeatDraft` transaction state have separable seams. Complete detail-editor save/clear decisions still live in a view; Calendar has its own shared store commands. |
| [RichText.swift](../../Sources/TaskovskyCore/RichText.swift) | `RichBody`, UTF-16 safety, and document-reset policy are Foundation-based. The same file also contains task pin grouping, which is unrelated to editor representation. |
| [RichTextRender.swift](../../Sources/TaskovskyCore/RichTextRender.swift) | Imports AppKit and operates on `NSTextView`, `NSTextStorage`, `NSFont`, paragraph styles, typing attributes, and toolbar state. Rendering and many editing policies are mixed. |
| [ListDecorations.swift](../../Sources/TaskovskyCore/ListDecorations.swift), [ListLayoutManager.swift](../../Sources/TaskovskyCore/ListLayoutManager.swift), [RichEditorSizing.swift](../../Sources/TaskovskyCore/RichEditorSizing.swift) | All import AppKit. Even the marker projection uses `NSTextList.MarkerFormat`. The layout manager lives in Core so existing tests can exercise the real drawing computation; moving it must preserve that test access. |
| [URLTitle.swift](../../Sources/TaskovskyCore/URLTitle.swift) | Extends TaskStore with URLSession networking, DNS checks through Darwin, and an asynchronous record update. This is a service adapter, not a deterministic task rule. |
| [AppMigration.swift](../../Sources/TaskovskyCore/AppMigration.swift), [IsolatedLaunch.swift](../../Sources/TaskovskyCore/IsolatedLaunch.swift) | Desktop data/preferences migration and command-line isolation are currently in Core. Their file paths and launch policy should not become iPhone domain requirements. |
| [DragPayloads.swift](../../Sources/TaskovskyCore/DragPayloads.swift), [ResponsiveLayout.swift](../../Sources/TaskovskyCore/ResponsiveLayout.swift), [DetailState.swift](../../Sources/TaskovskyCore/DetailState.swift) | Testable drag, geometry, selection, due-label, and undo helpers have different owners. Share useful value policies, but keep mouse geometry and desktop layout separate from task semantics. CoreGraphics here is not the same as an AppKit dependency. |

### Rules still owned by views

The extraction must inspect implementations, not infer behavior from type names or comments. Examples:

- [`Destination.includes`, `filteredTasks`, and `grouped` in App.swift](../../Sources/Taskovsky/App.swift) decide smart-destination membership, show-history expansion, sorting, grouping, pinned placement, and date buckets. `TaskItem.scheduleCalendar` is also defined there. They are not all available by importing Core.
- [`applyKanbanDrop` in App.swift](../../Sources/Taskovsky/App.swift) checks board membership, archived state, and note/status restrictions before choosing store operations. Core's [BoardProjection](../../Sources/TaskovskyCore/BoardProjection.swift) supplies the dataset and status split, not this entire command policy.
- [`ScheduleEditor.apply` and `clear`](../../Sources/Taskovsky/ScheduleEditor.swift) assemble recurrence, reminders, time zone, duration, occurrence index, and due state into a task. Core's `ScheduleDraft` is not a complete schedule transaction.
- [`TaskDetail.applyTemplate` and `updateBody`](../../Sources/Taskovsky/TaskDetail.swift) implement existing-task template application and paired plain/rich commits. Template creation in [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift) is a separate path.
- [`SearchPane` and `SearchDialog`](../../Sources/Taskovsky/SearchView.swift) compose search scope and criteria around [TaskFilter and TaskSearch](../../Sources/TaskovskyCore/Settings.swift). Highlighting and snippets are presentation; result eligibility should not be independently re-created on iPhone.
- [`RichBodyController` and the representable coordinator](../../Sources/Taskovsky/RichBodyEditor.swift) own important selection, pending-style, Return, undo, and callback behavior. Core-only helper tests do not by themselves exercise this host wiring.

These are extraction candidates, not a claim that every rule must become its own module. The [existing code review](../code-review-findings-2026-11-08.md) retains those original issues and their fixes, now in merged PR #2. Extraction must preserve the new recurrence, nested-draft, reminder-cloning and native text-policy regressions. This documentation PR does not alter those implementations.

<a id="arch-002"></a>
## ARCH-002 Proposed target and dependency direction

**Proposed:** retain one repository and one package where practical. Begin with logical boundaries and only introduce build targets when they enforce a useful dependency or enable independent tests. Suggested names below describe ownership, not modules that already exist.

| Boundary | Owns | Must not own |
| --- | --- | --- |
| Shared domain and use cases, evolving from `TaskovskyCore` | Codable values; task/list/tag/filter/template invariants; hierarchy lifecycle; command validation; recurrence/scheduling; query projections; rich-body value contract | AppKit/UIKit/SwiftUI types, focus, windows, navigation, files, network requests, platform prompts |
| Workspace services | Local repository and settings persistence, migrations, load/save/recovery outcomes, optional URL-title service; implementations satisfy interfaces consumed by the application session | UI presentation, date-picker state, alternative copies of business rules |
| macOS editor adapter | Current AppKit renderer, mutation adapter, controller/coordinator, drawing, measurement, selection/typing/undo integration | TaskStore, workspace paths, task lifecycle, recurrence, navigation |
| macOS application | Composition, observation, window/sidebar/detail/search surfaces, menus, keyboard and mouse interaction, platform service setup | A second implementation of authoritative task rules |
| iPhone application and editor adapter | Touch navigation, compact forms, keyboard/selection, iOS accessibility, supported editor subset and read-only fallbacks | Importing AppKit, reimplementing recurrence, converting unsupported data to a smaller schema |

Dependency direction:

1. Each app composes platform UI, platform editor adapter, application session, and service implementations.
2. Application session/use cases depend on domain values and narrow repository/service interfaces. Service implementations depend on those interfaces and values, not the other way around.
3. Both editor adapters depend on the shared rich-body contract. Neither depends on the other adapter or the task store.
4. Domain code has no dependency on either app or on concrete file/network adapters.
5. Tests import the smallest relevant unit; macOS adapter tests remain macOS-specific. A portable domain is not a requirement for a Linux build in this proposal.

A pragmatic first split is the existing Core plus a macOS editor target. The repository/service implementation can initially remain with the app composition layer while its contract is extracted. Recurrence, queries, hierarchy, rich values, and filters can remain folders or types inside Core. Do not create one package per feature. A dedicated rich-model target is optional only if a truly standalone editor consumer needs it without the broader Core dependency.

<a id="arch-003"></a>
## ARCH-003 Proposed state ownership and side effects

### One mutation path

The shared engine should receive explicit commands and return a changed snapshot or a typed refusal. Both UIs call the same commands for completion/reopen, Won't Do, trash/restore/purge, hierarchy moves, ordering, scheduling, templates, and paired body updates. Names and signatures are a later design choice.

Preserve the existing lifecycle semantics, including cascade ledgers, recurrence successors, and the distinction between embedded checklist items and linked child tasks. A UI hiding a control is not a substitute for validation at the command boundary. Keep typed reasons for failures such as archived destination, missing record, invalid parent, unsupported document, or stale edit so each platform can explain the same outcome in its own UI.

Initially, a compatibility facade can retain `TaskStore` calls while delegating individual policies. Do not replace the whole store in one change. Whole-record `updateTask` callers need careful migration: a platform that exposes fewer fields must not construct a fresh task and reset the rest to defaults.

### Editing and publication

- An editor owns transient text/selection/undo state; the host owns the persisted body. Commit plain text and its matching rich companion as one logical change. Reopening a record uses that pair, not attributed storage as a second database.
- A schedule editor owns a local draft until explicit apply; nested draft acceptance and cancellation have separate boundaries. The complete scheduling command must validate the pair of duration and due date, recurrence, reminders, and time zone together.
- An application session serializes commands and publishes observable snapshots on the UI actor. Inject a clock, ID source, calendar/time-zone context, repository, and optional URL-title service where required. They need not each become a separate package.
- Proposed edit commands carry document/task identity and a base revision or equivalent expected-state token. A callback from a closed editor must not overwrite a different or newer document. This token is local edit protection, not a server-sync protocol.
- Distinguish in-memory changes from durable save success. Do not display a successful save merely because a command mutated an observed value. Define error, retry, and recovery behavior in the application session without silently reverting or discarding edits.

Current behavior is narrower: [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift) mutates in-memory state and saves JSON synchronously; `storageError` reports failures, and a load failure blocks writes. The proposed result/revision/service APIs do not exist yet.

### Service boundaries

[Storage](components.md#cmp-004) should retain explicit workspace/settings URLs, atomic replacement, original-file protection after failed load, and backup-before-recovery. A failed load must not be interpreted as an empty writable workspace. Desktop migration from the old app name remains a desktop adapter concern.

[URL-title lookup](../../Sources/TaskovskyCore/URLTitle.swift) is the only existing network feature documented in the [README](../../README.md). Move it behind a service contract without widening network behavior or losing the current checks: HTTP(S), no URL credentials, public-host screening, no redirects, time/size bounds, the setting recheck, and the original-title recheck before applying a response. Use fake responses in tests. Do not add network calls to pure command tests.

Reminder calculations belong to the shared schedule policy; reminder delivery belongs to the platform. The present app has in-app reminders, not an OS-notification/background service. An iPhone notification implementation is a separate future decision, not implied by extracting this boundary.

<a id="arch-004"></a>
## ARCH-004 Proposed shared queries and platform presentation

Extract [destination membership and result composition](../../Sources/Taskovsky/App.swift) into pure query functions before implementing a second UI. Inputs should include a workspace snapshot, a query value, sort/history options, and explicit `now`/calendar context. Outputs should contain ordered IDs, semantic groups, counts, and available actions, not `View`, `Color`, or localized display strings.

Preserve differences already in source instead of collapsing all surfaces into one universal filter. In particular, [BoardProjection](../../Sources/TaskovskyCore/BoardProjection.swift) includes non-deleted history independently of the list view's Show Completed option, while smart-list eligibility and saved-filter scope have their own policies in [Organization](../../Sources/TaskovskyCore/Organization.swift) and [Settings](../../Sources/TaskovskyCore/Settings.swift).

Share the meaning of Today, Next 7 Days, active/history, pinning, archive exclusions, tag descendants, and filter rules. Let platforms choose navigation, date formatting, group headers, row density, touch versus mouse interaction, and whether a board is offered at all. Sharing a query must not force desktop geometry or all desktop features onto iPhone.

A characterization test should capture any source disagreement before extraction. An extraction PR must not silently change a date boundary, scope, or sort tie-breaker while labeling the change architectural. Product corrections and known bug fixes need their own approved behavior change and validation record.

<a id="arch-005"></a>
## ARCH-005 Proposed migration stages

These stages are a future implementation sequence, not work performed by this PR. Start from the merged corrections and preserve their regressions; do not reintroduce the prior defects during extraction.

| Stage | Smallest useful change | Acceptance gate before advancing |
| --- | --- | --- |
| 0. Establish baseline | Record exact source revision, existing behavior/known issues, representative saved workspaces, and test results on a suitable Mac. | Fixtures and current test outcomes are recorded; failures are not relabeled as successes. Scope and ownership of concurrent fixes are clear. |
| 1. Isolate the macOS editor | Move AppKit editor/rendering/geometry into one importable adapter target; keep Foundation rich values shared. Retain the production controller/coordinator as the implementation under test. | Existing editor tests run against their new owner; macOS app behavior and persistence stay unchanged. Adapter tests do not depend on the main executable. No new body schema or formatting behavior is introduced. |
| 2. Extract shared decisions | Move one command/query family at a time from views/store into testable domain use cases; keep the facade working. Prefer schedule apply/clear, template application, and query composition seams. | Shared cases match captured behavior; both callers and tests use the same policy; no duplicated mutable source of truth. Differences and separate fixes are explicitly tracked. |
| 3. Isolate local services | Introduce repository/settings and URL-title interfaces; move paths, filesystem and network details behind them; retain current local file format unless a separately reviewed migration is required. | Temporary-store tests prove load/save/retry/recovery; pure command tests use deterministic fakes; unreadable originals and unsupported data survive. |
| 4. Build a minimal iPhone client | Compile shared domain for iOS and connect a native app to the same commands, query contracts and a sandbox-local repository. Implement [limited body editing](components.md#rich-004). | No AppKit dependency enters the iOS graph. iPhone fixtures prove equivalent domain outcomes and lossless unsupported-content preservation. Touch/accessibility and cancellation are tested on iOS. |
| 5. Expand by capability | Add optional iPhone rich-format editing or other features only when their contracts and acceptance cases are met. | Every newly editable format has model, adapter, persistence and cross-platform round-trip tests. Unsupported features remain preserved and honestly labeled. |

No stage requires live cross-device data sharing. An iPhone prototype can use local synthetic or explicitly transferred test fixtures. Sync, account identity, conflict resolution, encryption, schema distribution, and background transport need a separate design and authorization; none is specified or implemented here.

<a id="arch-006"></a>
## ARCH-006 Proposed architecture acceptance gates

- **Dependency gate:** shared domain imports no AppKit, UIKit, or SwiftUI; editor adapters import no workspace store; concrete disk/network services do not leak into command/query inputs. Verify actual build dependencies, not just filenames.
- **Behavior gate:** archived-state, lifecycle, ordering, recurrence, filters, and text invariants remain covered by the same shared policies. Keep UI composition tests for rules extracted from views.
- **Data gate:** legacy fixtures decode with the intended defaults. Read-only viewing and unrelated metadata edits do not erase rich data or fields unsupported by a platform. Newer or malformed formats follow [RICH-005](components.md#rich-005), rather than optimistic decoding and rewriting.
- **Editor gate:** tests exercise the production controller and coordinator in addition to helpers, including native callbacks, IME/marked text, document switches, cancellation, and undo. See [RICH-006](components.md#rich-006).
- **Persistence gate:** no tests or demos touch the real workspace; failed reads preserve the original; failed writes surface an error; recovery requires a successful backup first. Existing isolation support is not a substitute for fixture ownership.
- **Verification gate:** future implementation PRs record exact commands, revision, platform and results. Source/test presence, automated execution, native UI checks, and reference parity are distinct evidence levels in the [tracker](../parity-implementation-status.md).

Relevant existing suites include [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift), [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift), [RecurrenceIntegrationTests](../../Tests/TaskovskyCoreTests/RecurrenceIntegrationTests.swift), [FilterIntentTests](../../Tests/TaskovskyCoreTests/FilterIntentTests.swift), [BoardProjectionTests](../../Tests/TaskovskyCoreTests/BoardProjectionTests.swift), and [BoardIsolationGateTests](../../Tests/TaskovskyCoreTests/BoardIsolationGateTests.swift). These are starting evidence, not proof of the proposed boundaries.

<a id="arch-007"></a>
## ARCH-007 Decisions deferred to implementation

1. Final target names and whether repository services need a separate target. Prefer the smallest graph that enforces the boundaries above.
2. The iOS deployment target and native editor API. UIKit or SwiftUI integration may differ from AppKit; data and editing guarantees matter more than identical implementation.
3. Workspace/rich-format version envelopes, opaque payload retention, migrations, and compatibility with older writers. Agree and test these before sharing files between versions; the current source has no version negotiation.
4. Scope and timing of richer iPhone editing after the conservative first release. Each capability can be added independently without promising full desktop parity.
5. Any sync, notifications, accounts, or unrelated modules. These remain outside this proposal, not hidden dependencies of the shared engine.

## Merged Calendar seams

The current baseline already contains pure Core [Calendar projection/options/date helpers](../../Sources/TaskovskyCore/TaskCalendarProjection.swift), alongside BoardProjection. [CalendarScheduling](../../Sources/TaskovskyCore/CalendarScheduling.swift) and [CalendarScheduleDraft](../../Sources/TaskovskyCore/CalendarScheduleDraft.swift) separate schedule operations and point/range preservation from the macOS panels. Store commands apply automatic/manual reminder policy and guarded scheduling-only Undo. Reuse these seams rather than proposing to recreate Calendar logic inside either native UI.

This does not make the entire existing Core iOS-portable: AppKit rich rendering and other dependencies described above still require separation, and detail schedule apply/clear plus destination composition remain partly in views. See [CMP-005](components.md#cmp-005), [BUS-027–030](../spec/business.md#bus-027), and [UX-017](../spec/ui-ux.md#ux-017). Local Calendar adds no account, EventKit or cross-device service and does not expand the initial iPhone proposal.
