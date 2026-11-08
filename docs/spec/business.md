# Taskovsky business behavior

## Authority and scope

This document describes the behavior implemented in source baseline `cfdec454acff91285ac00beaa20c0cf0f0961ee1` (main), reviewed on 2026-11-08. Executable source takes precedence over old reports and source comments. These are current-behavior requirements, not a claim of complete TickTick equivalence or a promise that every path is correct.

Each stable `BUS-###` identifier names one behavior area. Acceptance cases below are review scenarios, not blanket pass claims. The follow-up CI implementation runs existing automated tests and release packaging on a hosted Mac; exact revisions, outcomes and limits are in the verification ledger. No new native macOS interaction or TickTick experiment was performed for this refresh. See the [verification ledger](verification.md), [UI/UX specification](ui-ux.md), and separate [TickTick parity tracker](../parity-implementation-status.md). The [iPhone scope](iphone.md) and [component proposals](../architecture/components.md) describe future work, not current functionality.

The Calendar display follow-up in [PR #3](https://github.com/Mental-NV/Taskovsky/pull/3), source head `13a3a486153fc1217f6228cb8e6cd8266dffb366`, adds named secondary rulers, Year styles and item-icon visibility to this baseline while retaining main `b4216dec6ee2d95471038cf41ca6f92efcb94039` documentation, CI and the TaskDetail refactor. Prior local results and pending final integration CI are distinguished in the verification ledger. See [Calendar display verification](verification.md#calendar-display-follow-up).

## Product and record model

<a id="bus-001"></a>

### BUS-001 — Local macOS product

**Current rule.** Taskovsky is a local task/note application. The package declares macOS 14+, an executable application and a Core target. A workspace contains tasks, lists, folders, tags, saved filters, templates, and lifecycle ledgers. No account, server sync, team permissions, or iPhone application is implemented in this package. The local Calendar workspace projects and schedules those same tasks; it adds no separate event database or external calendar integration (BUS-027–030).

**Acceptance.** Open an isolated workspace, create and edit a task, then reopen the same workspace and inspect its stored content. This is a persistence scenario, not a sync scenario. Proposed iPhone capability differences must be evaluated against the future iPhone scope rather than recorded as current macOS defects.

**Evidence.** [Package.swift](../../Package.swift); [WorkspaceData](../../Sources/TaskovskyCore/Models.swift); [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift).

<a id="bus-002"></a>

### BUS-002 — Tasks, notes and three distinct kinds of child content

**Current rule.** A `TaskItem` has a stable UUID, title, plain body, optional rich body, task/note kind, optional list, tags, priority, schedule, reminders, lifecycle timestamps and pin flag. A missing list ID means Inbox. An embedded `ChecklistItem` is a stored quick step with its own ID/title/checked flag. A linked subtask is another `TaskItem` with `parentID` and independent detail/schedule. A rich-body checklist is paragraph formatting inside the body. These three concepts are not interchangeable.

The UI presents notes without the task completion checkbox. List kind supplies a creation choice, not a storage constraint requiring every existing record in that list to have the same kind. The record model itself permits task-like schedule/status fields on notes; do not describe UI restrictions as universal store invariants.

**Acceptance.** Check a stored quick step without completing its parent; open a linked child's own detail; check a styled paragraph through the body toolbar. Each operation changes its own representation only. Inspect a mixed task/note list without silently converting its records.

**Evidence.** [Models](../../Sources/TaskovskyCore/Models.swift); [TaskDetail](../../Sources/Taskovsky/TaskDetail.swift); [TaskRow](../../Sources/Taskovsky/TaskRow.swift); [EntryAndListTests](../../Tests/TaskovskyCoreTests/EntryAndListTests.swift); [TaskHierarchyTests](../../Tests/TaskovskyCoreTests/TaskHierarchyTests.swift).

<a id="bus-003"></a>

### BUS-003 — Capture, defaults and recognition

**Current rule.** Main quick entry rejects a whitespace-only title and passes context plus user defaults to task creation. Defaults cover list, tag, priority, date, top/bottom position, reminders and timed duration. Explicit list context wins; an archived creation target falls back to Inbox. A tag destination adds that tag to the new record. Subtask creation is a separate path: it inherits the parent's list and creates an open task rather than applying the complete quick-entry default pipeline.

Date recognition is a limited English parser: today, tomorrow, day after tomorrow, next week, `in N days`, and weekday names, with supported times before/after the date phrase. A weekday matching today means the following week. `next week` means the next configured calendar-week boundary. Recognized dates can override the contextual date when requested by quick entry. Removal of recognized date text is optional. `#tag` and `#"multi word"` tokens reuse case-insensitive tag names or create a tag; removal from the title is optional. Ignoring a recognition suggestion leaves that entry's date text unparsed.

**Acceptance.** Create from Inbox with a default list configured and verify the explicit Inbox choice is retained. Try a recognized date, ignore it, and inspect the saved title/date. Create using a quoted tag name twice and verify one tag identity is reused. Test archived defaults and invalid time tokens separately.

**Evidence.** [TaskStore.createTask/recognizeDate](../../Sources/TaskovskyCore/TaskStore.swift); [QuickEntry](../../Sources/Taskovsky/QuickEntry.swift); [App quick-entry dispatch](../../Sources/Taskovsky/App.swift); [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift); [EntryAndListTests](../../Tests/TaskovskyCoreTests/EntryAndListTests.swift).

<a id="bus-004"></a>

### BUS-004 — URL titles are optional network enrichment

**Current rule.** With URL parsing enabled, creation of a title consisting of an HTTP(S) URL may asynchronously replace it with the page title. The original URL becomes the body only if the body is empty. A later user title edit or disabled setting prevents replacement. The fetch rejects embedded credentials, local/private address classes checked by the implementation, IPv6 results, redirects, non-success responses and non-HTML content; it uses bounded response/time limits. These checks are implementation facts, not a security certification or guarantee that every public URL resolves.

**Acceptance.** Use a controlled public HTML URL with and without an existing body; edit the title before the response; repeat with parsing disabled and with a redirect. A failed resolution must leave the original title usable. Network behavior was not exercised in this review.

**Evidence.** [URLTitle](../../Sources/TaskovskyCore/URLTitle.swift); [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift). No dedicated network integration test was identified in the checked-in test suite.

## Content and lifecycle

<a id="bus-005"></a>

### BUS-005 — Plain text and rich-body fidelity

**Current rule.** Plain body text remains authoritative for search, snippets and previews. The optional rich companion mirrors that exact UTF-16 text and carries bounded inline/block ranges. A companion for different code units is rejected instead of styling unrelated text. Formatting supports bold, italic, underline, strikethrough, highlight, inline code, links, H1–H6, quotes, bullet/numbered/checklist paragraphs and horizontal rules. List markers and quote bars render from metadata rather than literal prefixes stored in plain text. Formatting edits and typing use native editor undo with document-ID invalidation and per-view undo ownership.

**Acceptance.** Save styled text containing emoji, reopen it, and compare plain text plus styles. Independently replace the plain body and confirm stale style ranges do not carry over. Switch between different records with identical bodies and inspect undo isolation. Test Return continuation and exit for each block type.

**Corrections and limits.** Merged PR #2 fixes paragraph-selection spillover and the empty-document Quote toggle ([DEV-004/005](verification.md#known-deviations)); block expansion respects the exclusive UTF-16 selection end and a second empty-editor Quote toggle returns to plain typing state. [BlockRangeTests](../../Tests/TaskovskyCoreTests/BlockRangeTests.swift) and [QuoteToggleTests](../../Tests/TaskovskyCoreTests/QuoteToggleTests.swift) retain regressions; live Undo/Redo and selection checks remain limited. Body-box pointer toggling, attachments/images, tables, source-mode editing and arbitrary foreign rich-text fidelity are not implemented/claimed. Mid-list Return after reloading may start a plain paragraph. Large list numbers can exceed the fixed gutter. These limits are not a declaration that the entire rich editor is absent.

**Evidence.** [RichText](../../Sources/TaskovskyCore/RichText.swift); [RichTextRender](../../Sources/TaskovskyCore/RichTextRender.swift); [RichBodyEditor](../../Sources/Taskovsky/RichBodyEditor.swift); [ListLayoutManager](../../Sources/TaskovskyCore/ListLayoutManager.swift); [RichRenderTests](../../Tests/TaskovskyCoreTests/RichRenderTests.swift); [RichTextPinTests](../../Tests/TaskovskyCoreTests/RichTextPinTests.swift); [BlockCoherenceTests](../../Tests/TaskovskyCoreTests/BlockCoherenceTests.swift); [ListContinuationTests](../../Tests/TaskovskyCoreTests/ListContinuationTests.swift); [PendingListArmTests](../../Tests/TaskovskyCoreTests/PendingListArmTests.swift).

<a id="bus-006"></a>

### BUS-006 — Linked task hierarchy and movement

**Current rule.** Parenting rejects unknown/self/cyclic parents and note, trashed or archived parents. Linking across lists relocates the child's subtree into the parent's list. A moved parent carries descendants; a moved child detaches when its parent stays in another list. Selecting a child opens its own detail with parent navigation. Filtered children can appear as roots when their parent is absent from the view. Progress counts direct children completed or marked Won't Do, not embedded quick steps.

Bulk list moves validate the entire explicit batch before writing: empty, duplicate, unknown or deleted IDs and invalid/archived destinations refuse without a partial move. Descendants follow a valid parent move, including descendants whose deleted state is retained. Moving out of an archived list is allowed.

**Acceptance.** Move a parent with a grandchild, then move only the child to a different list; verify list membership and parent links. Reject a cycle without saving it. Filter to a child alone and verify it remains visible. Reject one invalid ID mixed into an otherwise valid move.

**Evidence.** [TaskStore parenting/moves](../../Sources/TaskovskyCore/TaskStore.swift); [TaskHierarchy](../../Sources/TaskovskyCore/Organization.swift); [TaskHierarchyTests](../../Tests/TaskovskyCoreTests/TaskHierarchyTests.swift); [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift); [ReorderTests](../../Tests/TaskovskyCoreTests/ReorderTests.swift).

<a id="bus-007"></a>

### BUS-007 — Completion, Won't Do and reopening

**Current rule.** Completion clears Won't Do on the root and completes its active, non-trashed descendants at one timestamp. Descendants already completed or Won't Do retain their prior stamps. A persisted cascade ledger records which descendants changed. Reopening the parent reopens only ledger entries whose completion stamps still match; independent earlier completions and later edits remain. Marking Won't Do changes that record only and does not run the completion recurrence path. Main task rows, search, top-level detail and board actions use shared completion/Undo feedback. The detail child-completion control calls the store directly and does not use that shared feedback path. Archived completion/status changes are refused by the store.

**Acceptance.** Complete a parent with one open, one completed and one Won't Do child, reload, then reopen it. Only the untouched cascaded child should reopen. Reopen one child before parent Undo and confirm the later parent action does not overwrite it. A child reopen does not itself consume the parent's ledger entry; the later parent action skips the changed stamp.

**Evidence.** [TaskStore.completeSubtree/undoCompletion/markWontDo](../../Sources/TaskovskyCore/TaskStore.swift); [DetailState](../../Sources/TaskovskyCore/DetailState.swift); [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift); [DetailStateTests](../../Tests/TaskovskyCoreTests/DetailStateTests.swift).

<a id="bus-008"></a>

### BUS-008 — Recurrence successors and conservative Undo

**Current rule.** Completion can spawn one successor for a dated recurring record when the series has not ended and no successor already references that occurrence. A recurring parent copies its currently open descendants under the successor once, with fresh task/checklist IDs, cleared states, remapped links and shifted schedules; already-finished descendants are not copied. When the parent has no successor, a recurring descendant may spawn its own successor under the old parent.

Undo removes a spawned record only when it can prove that record is unchanged from its in-memory creation snapshot. Edited successors and ancestors needed by surviving descendants remain. Snapshots do not survive a reload; reopening then conservatively retains successors even though the persisted completion ledger can still reopen children. This is Taskovsky policy, not recovered TickTick behavior.

**Acceptance.** Complete a repeating parent and verify one successor tree, not separate child trees. Edit one successor child, undo the original, and verify that child and its required ancestors remain. Repeat after reload and expect conservative successor retention.

**Reminder preservation.** All-day descendant reminders shift by calendar days without midnight normalization, preserving wall-clock times and relative days in the task zone. [DEV-002](verification.md#known-deviations) is fixed in merged PR #2; [CloneReminderTests](../../Tests/TaskovskyCoreTests/CloneReminderTests.swift) cover multiple times, previous-day reminders, DST and reload.

**Evidence.** [TaskStore.spawnSuccessor/cloneSubtreeIntoSuccessor/removePristineSpawns](../../Sources/TaskovskyCore/TaskStore.swift); [RecurrenceIntegrationTests](../../Tests/TaskovskyCoreTests/RecurrenceIntegrationTests.swift); [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift).

<a id="bus-009"></a>

### BUS-009 — Trash, restore and permanent deletion

**Current rule.** Moving to Trash stamps the record and its non-trashed descendants; a persisted trash ledger distinguishes them from separately trashed children. Restore clears the root's deletion and restores only descendants whose cascade deletion stamps still match. Status, body, schedule and other content survive; restore does not complete the record or create a recurrence. Deleted items are read-only in application UI. The single-record purge operation accepts only a trashed record, detaches surviving direct children and prunes related ledgers. The UI asks for confirmation before Delete Forever; there is no bulk Empty Trash flow specified here.

**Acceptance.** Trash a parent whose child was already trashed, restore the parent after reload, and verify the independently trashed child stays in Trash. Cancel Delete Forever without changes. Exercise purge only in disposable test data and confirm survivors have no dangling parent. Verify toast Undo is consumed once.

**Evidence.** [TaskStore.trashTask/restoreTask/purgeTask](../../Sources/TaskovskyCore/TaskStore.swift); [TaskDetail](../../Sources/Taskovsky/TaskDetail.swift); [App actions](../../Sources/Taskovsky/App.swift); [TrashTests](../../Tests/TaskovskyCoreTests/TrashTests.swift); [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift).

<a id="bus-010"></a>

### BUS-010 — Duplication, templates and pins

**Current rule.** Duplicating a task copies its non-deleted subtree with fresh IDs and remapped internal links; the root reopens, descendant statuses remain, and recurrence-source links are cut. Duplicating a list copies its non-deleted records, remaps parents within the copy, preserves content/schedule/status/view mode, and makes the new list unarchived and unpinned.

Templates capture one record's title, body/styles, quick steps, priority, valid tags, kind, custom rule and duration shape. They do not recursively capture linked children or the complete live record (for example, ordinary due/reminder settings and legacy recurrence are not a full template snapshot). Applying a template changes its supported fields on the current record and preserves existing hierarchy; custom-rule changes reset the occurrence index. Template creation/use regenerates quick-step IDs. Save as Template appends a new template; Settings cards open direct editing of that existing template. Built-ins include a travel checklist with five quick steps. Active task pins form a Pinned group; pin state survives completion/trash even though inactive records cannot be newly pinned.

**Acceptance.** Duplicate a nested task and check no copied child points to an original ancestor inside the copied subtree. Instantiate a template after deleting one of its tags; the missing tag must not return. Apply a template to a task with children and verify those links remain. Reopen a previously pinned task and inspect its grouping.

**Evidence.** [TaskStore duplicates/templates/pins](../../Sources/TaskovskyCore/TaskStore.swift); [TaskTemplate](../../Sources/TaskovskyCore/Settings.swift); [TaskDetail.applyTemplate](../../Sources/Taskovsky/TaskDetail.swift); [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift); [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift); [RichTextPinTests](../../Tests/TaskovskyCoreTests/RichTextPinTests.swift).

## Scheduling

<a id="bus-011"></a>

### BUS-011 — Date and duration coherence

**Current rule.** A schedule is an optional due date, a timed/all-day flag, optional task time-zone identifier and optional start/end duration. Valid duration endpoints determine the due date: `dueDate == scheduledDuration.end` and `hasDueTime == !scheduledDuration.isAllDay`. Reversed windows drop. All-day ranges normalize in the applicable calendar; timed ranges retain elapsed duration, while all-day shifts preserve whole-day spans. Creation, update, template instantiation and recurrence paths apply this normalization. A live record cannot keep a valid absolute window while remaining undated.

**Acceptance.** Create/update using mismatched due/end values and verify the valid window wins. Move a timed interval across DST and compare elapsed seconds; move an all-day range and compare calendar-day span. Reject a reversed range without preserving a contradictory window. Verify an absolute template window supplies a due date when instantiated without an explicit one.

**Evidence.** [TaskDurationRange](../../Sources/TaskovskyCore/CustomRecurrence.swift); [TaskStore.coherentSchedule](../../Sources/TaskovskyCore/TaskStore.swift); [DurationTests](../../Tests/TaskovskyCoreTests/DurationTests.swift); [TaskZoneDurationTests](../../Tests/TaskovskyCoreTests/TaskZoneDurationTests.swift).

<a id="bus-012"></a>

### BUS-012 — Schedule editing and cancellation

**Current rule.** The schedule editor stages dates, time, duration, reminders, recurrence and zone before outer OK. Cancel/dismiss does not invoke the save callback. Clear immediately commits removal of due date, duration, reminders, zone and recurrence state, then dismisses. A changed custom recurrence rule resets occurrence count to 1 and nominal date to the coherent due date; clearing removes nominal state. Ordinary date edits preserve the count but rebase nominal position, while unchanged saves preserve a rolled nominal date. The store enforces this normalization at its boundary. `ScheduleDraft` coordinates all-day/timed transitions, quick dates and wall-clock zone changes.

**Acceptance.** Change several schedule fields and cancel the outer editor; reopen and inspect the original. Apply a duration and inspect due/end coherence. Clear a repeating schedule and verify all related fields clear. Test nested Cancel separately from outer Cancel.

**Nested transaction.** Custom opens a sheet-local recurrence draft. Cancel or dismissal leaves the outer none/simple/custom rule unchanged; Done applies a valid draft and Clear Rule explicitly removes the custom rule. Merged PR #2 fixes [DEV-001](verification.md#known-deviations); [RepeatDraftTests](../../Tests/TaskovskyCoreTests/RepeatDraftTests.swift) and the retained live report cover these distinct paths.

**Evidence.** [ScheduleEditor](../../Sources/Taskovsky/ScheduleEditor.swift); [CustomRecurrenceEditor](../../Sources/Taskovsky/CustomRecurrenceEditor.swift); [ScheduleDraft](../../Sources/TaskovskyCore/ScheduleDraft.swift); [ScheduleDraftTests](../../Tests/TaskovskyCoreTests/ScheduleDraftTests.swift). Draft-unit tests alone do not verify the nested-sheet transaction.

<a id="bus-013"></a>

### BUS-013 — Recurrence rules and end conditions

**Current rule.** Legacy choices are None, Daily, Weekdays, Weekly, Monthly and Yearly, with optional inclusive end day. Valid custom rules supersede legacy recurrence and add interval/unit, due-date or completion-date anchor, weekdays, month days/last day, ordinal weekday, first/last workday, year-month choices, explicit dates, weekend rolling, inclusive end day and maximum occurrence count. Count includes the starting occurrence as position 1. Specific dates are sorted and deduplicated by exact instant. Invalid rules yield no occurrences; traversal is bounded.

Workday means Monday–Friday without a holiday calendar. Weekend skipping rolls forward to Monday. Completion-based cadence uses the completion date but the scheduled wall-clock time; preview assumes on-time completion because future completion is unknown. Short-month clamping, explicit original-day anchors, nonexistent fifth weekdays and DST follow the independent engine's rules.

**Acceptance.** Verify several successive occurrences, not just the first, for end counts, end days, short months, leap years, DST, explicit dates and completion anchors. A rule at its maximum count has no successor. Invalid interval/day input must not create an unbounded query.

**Nominal cadence.** Persisted `recurrenceNominalDate` separates the unadjusted cadence from the displayed weekend-rolled due date. Monthly/yearly weekend-rolling shapes chain nominal dates; daily/weekly shapes retain adjusted chaining and explicit dates remain verbatim. Completion anchors use actual completion rather than nominal state. Legacy decoded records fall back to due when the optional nominal field is absent. Shared `nextDueDateStep` enforces forward progress and adjusted end bounds without falling back after a nil result. Successor generation and Calendar forecasts use that position, occurrence count and end conditions; due/rule edits rebase nominal position without resetting the count merely for a date edit. Merged PR #2 fixes [DEV-003](verification.md#known-deviations); [NominalCadenceTests](../../Tests/TaskovskyCoreTests/NominalCadenceTests.swift) and [NominalSeriesIntegrationTests](../../Tests/TaskovskyCoreTests/NominalSeriesIntegrationTests.swift) cover multiple successors, month/year boundaries, persistence and legacy recovery.

**Evidence.** [CustomRecurrence](../../Sources/TaskovskyCore/CustomRecurrence.swift); [TaskStore.nextRecurrenceDate](../../Sources/TaskovskyCore/TaskStore.swift); [CustomRecurrenceTests](../../Tests/TaskovskyCoreTests/CustomRecurrenceTests.swift); [RecurrenceIntegrationTests](../../Tests/TaskovskyCoreTests/RecurrenceIntegrationTests.swift).

<a id="bus-014"></a>

### BUS-014 — Reminders and task zones

**Current rule.** Multiple reminder instants are stored as a sorted, deduplicated set through the `reminderDates` accessor. Defaults distinguish timed offsets from all-day reminders at 09:00 on selected relative days. Provenance distinguishes schedule-following defaults from manual reminders: schedule/zone changes recalculate defaults while manual choices remain explicit. Detail shows the earliest reminder and total count; dismiss clears all, and snooze replaces the earliest reminder. Archived lists suppress reminder presentation/eligibility; smart-list exclusion alone does not remove reminders.

Taskovsky stores these reminders and exposes in-app reminder information. There is no operating-system notification scheduling/delivery implementation in the inspected package. An optional zone ID is not a complete TickTick Fixed/Floating Time mode: an explicit floating-time model is absent.

**Acceptance.** Select multiple defaults, move the due date and inspect recalculated reminders; manually override one and repeat. Check all-day 09:00 and task-zone DST behavior. Archive/unarchive a list without deleting its reminder data. Do not use a stored reminder as proof that a notification will fire.

**Calendar edits and cloning.** Calendar moves shift manual reminders with the due date and recalculate automatic reminders through the store. All-day descendant cloning now preserves wall-clock components ([DEV-002 resolution](verification.md#known-deviations)); this does not add OS notification delivery.

**Evidence.** [Models.reminderDates](../../Sources/TaskovskyCore/Models.swift); [TaskStore reminder helpers](../../Sources/TaskovskyCore/TaskStore.swift); [TaskDetail](../../Sources/Taskovsky/TaskDetail.swift); [Organization](../../Sources/TaskovskyCore/Organization.swift); [ReminderTests](../../Tests/TaskovskyCoreTests/ReminderTests.swift); [TaskZoneDurationTests](../../Tests/TaskovskyCoreTests/TaskZoneDurationTests.swift).

## Organization and views

<a id="bus-015"></a>

### BUS-015 — Lists and folders

**Current rule.** Lists have name, color/symbol, task/note kind, optional folder, list/board mode, smart-list inclusion, archive and pin state. Folders group lists one level deep. List/folder names are validated in their editors; a store operation is not a substitute for UI validation. Ungroup preserves lists and tasks. Deleting a list moves its records to Inbox rather than deleting them, and keeps saved-filter references to the now-unavailable list instead of broadening that filter. List moves/reorders preserve task membership except when the operation explicitly moves tasks.

**Acceptance.** Create a list in a folder, rename it, move it to the root, then ungroup the folder and reload. Verify task IDs/content remain. Delete a list referenced by a filter and inspect both Inbox records and the unavailable filter selection.

**Evidence.** [Models](../../Sources/TaskovskyCore/Models.swift); [TaskStore list/folder operations](../../Sources/TaskovskyCore/TaskStore.swift); [TaskDetail entity editor](../../Sources/Taskovsky/TaskDetail.swift); [FoldersSmartOrderTests](../../Tests/TaskovskyCoreTests/FoldersSmartOrderTests.swift); [FilterHardeningTests](../../Tests/TaskovskyCoreTests/FilterHardeningTests.swift).

<a id="bus-016"></a>

### BUS-016 — Archive, exclusion and explicit-selection exceptions

**Current rule.** Archive preserves list content and placement, suppresses normal smart-list/reminder eligibility, and makes content read-only in its normal UI. Store-level `updateTask` freezes archived content except moving to a live list/Inbox; completion and pin operations also guard archive state. Smart-list exclusion only controls default view inclusion, not stored reminders. Neither flag deletes records.

Eligibility is **not universal**. In `Destination.includes`, All/Today/Tomorrow/Next 7 Days/Notes apply smart exclusion; Reminders checks archive only; Completed, Won't Do and tag navigation do not apply the same exclusion. Explicit list navigation shows that list. Filters/full search/summary may include an archived or excluded list when positively selected. Nonempty quick search finds matching non-deleted archived records. Unknown list references are kept visible. These exceptions are current source behavior and require their own parity decisions.

**Acceptance.** Compare the same archived/excluded task across All, Completed, tag navigation, quick search and a filter explicitly naming its list. Verify no global “hidden everywhere” assumption. Move out of archive and edit; unarchive without losing stored schedule or organization.

**Evidence.** [SmartListEligibility](../../Sources/TaskovskyCore/Organization.swift); [Destination.includes](../../Sources/Taskovsky/App.swift); [TaskFilter.matches](../../Sources/TaskovskyCore/Settings.swift); [SearchView](../../Sources/Taskovsky/SearchView.swift); [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift); [FilterIntentTests](../../Tests/TaskovskyCoreTests/FilterIntentTests.swift).

<a id="bus-017"></a>

### BUS-017 — Tags, hierarchy and merging

**Current rule.** Tags have name, color, parent, collapse and pin state. Creation trims leading `#` characters and reuses case-insensitive normalized names. Parent changes refuse unknown/self/cyclic links. Parent-tag navigation includes descendant tags; saved-filter tag predicates match selected IDs rather than automatically expanding the hierarchy.

Merge rewrites task/template/filter references, deduplicates IDs, follows the default tag and reparents children without cycles before deleting the source. Delete removes memberships from tasks/templates and clears a matching default, promotes children, but deliberately retains unavailable tag IDs in filter criteria/rules so deletion does not broaden the filter.

**Acceptance.** Merge a parent into a descendant with both tags already on a task; verify one target membership, acyclic hierarchy and updated filter predicates. Delete a referenced tag and inspect unavailable criteria. Compare parent-tag navigation with a filter selecting that parent ID.

**Evidence.** [TaskStore tag operations](../../Sources/TaskovskyCore/TaskStore.swift); [TagHierarchy](../../Sources/TaskovskyCore/Organization.swift); [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift); [FilterHardeningTests](../../Tests/TaskovskyCoreTests/FilterHardeningTests.swift).

<a id="bus-018"></a>

### BUS-018 — Smart destinations and visibility

**Current rule.** Configurable smart entries include All, Today, Tomorrow, Next 7 Days, Inbox, Summary, Tags, Filters, Completed, Won't Do and Trash. Settings support Show, Hide and Show if not empty, plus persisted ordering within the supported smart groups. Hiding the active destination selects a visible fallback. Notes and Reminders also exist as application destinations, not additional members of `SmartListKey`.

Today includes all active dated records before tomorrow, including overdue work. Next 7 Days includes all active dated records before the seventh day boundary, also including overdue work. Tomorrow is a same-day match. These destination predicates differ from the bounded Today/Next 7 filter rules. Counts and presentation should be reviewed against the actual destination, not assumed interchangeable with search criteria.

**Acceptance.** Give one task an overdue due date and inspect Today/Next 7 Days versus their saved-filter equivalents. Hide/show/reorder entries, reload and verify hidden slots and group boundaries remain meaningful.

**Evidence.** [Destination](../../Sources/Taskovsky/App.swift); [AppSettings](../../Sources/TaskovskyCore/Settings.swift); [FoldersSmartOrderTests](../../Tests/TaskovskyCoreTests/FoldersSmartOrderTests.swift); [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift).

<a id="bus-019"></a>

### BUS-019 — Ordering, pins and drag transactions

**Current rule.** None is stored manual order; legacy Manual maps to None. Date, Priority, Title and Created compute ordering instead. Active pinned rows form their own group above other active items; history is separate. Manual task reorder changes array order, not dates, status or priority; computed sorts reject task reordering with feedback. Task-to-list moves remain separate. Typed task/list/folder/smart/tag payloads and whole-batch validation prevent partial acceptance of malformed/mixed drops. Sidebar lists can move across folders/root, and supported entities persist pins.

**Acceptance.** Reorder manually across dates and inspect unchanged record fields; try the same under Date sorting and expect refusal. Drop malformed/mixed payloads and verify no partial changes. Cancel a sidebar drag and confirm there is no save. Native pointer fidelity must be verified on macOS separately from policy tests.

**Evidence.** [TaskStore reorder operations](../../Sources/TaskovskyCore/TaskStore.swift); [DragPayloads](../../Sources/TaskovskyCore/DragPayloads.swift); [DragReorder](../../Sources/Taskovsky/DragReorder.swift); [ReorderTests](../../Tests/TaskovskyCoreTests/ReorderTests.swift); [DragBatchTests](../../Tests/TaskovskyCoreTests/DragBatchTests.swift); [SidebarDragEngineTests](../../Tests/TaskovskyCoreTests/SidebarDragEngineTests.swift); [SidebarDragPolicyTests](../../Tests/TaskovskyCoreTests/SidebarDragPolicyTests.swift).

<a id="bus-020"></a>

### BUS-020 — Status board

**Current rule.** List/Board is persisted per list and copied by list duplication. The board projects all non-deleted records of its list regardless of the list-row Show Completed toggle, with fixed Open, Completed and Won't Do columns. Cards are flat rather than nested. UI status drops reuse shared task actions and refuse terminal-state drops for notes; archive remains read-only. There is no custom section/column model. The projection itself splits stored status flags, so UI note restrictions must not be mistaken for a model-wide normalization guarantee.

**Acceptance.** Use a list containing only completed tasks and verify the board still shows them. Complete/drop a recurring task and inspect the shared successor behavior. Switch another list's mode and confirm the first list's preference is unchanged. Attempt a note completion drop and inspect refusal.

**Evidence.** [BoardProjection](../../Sources/TaskovskyCore/BoardProjection.swift); [App board](../../Sources/Taskovsky/App.swift); [BoardProjectionTests](../../Tests/TaskovskyCoreTests/BoardProjectionTests.swift); [BoardIsolationGateTests](../../Tests/TaskovskyCoreTests/BoardIsolationGateTests.swift).

## Finding and reporting work

<a id="bus-021"></a>

### BUS-021 — Normal saved filters

**Current rule.** A named filter combines list IDs (including an explicit Inbox sentinel), priority values, date rules, task/note kinds, status, keyword and tag mode. Selected values within the ordinary list/priority/date/type field are OR; different fields are AND. Tags support Any selected, All selected, No Tags and Any Tagged. Empty selections generally remove that constraint; tag modes still apply their own semantics. Searchable text includes title, plain body and stored quick-step titles. Deleted tasks never match.

Dates include Today/Tomorrow, bounded Next 7, Overdue, No Date, this/next/last week/month, Repeating and day-inclusive custom bounds. Weeks follow the configured calendar. Timed overdue compares the instant; all-day overdue compares start of day. Explicit list selection overrides archive/exclusion. Deleted entity criteria remain unavailable selections rather than being silently removed.

**Acceptance.** Combine two priorities with two date choices and one list, check field OR/AND behavior, then save/reload. Check custom bounds on both endpoint days and across DST. Delete the selected list/tag and verify the filter does not expand to all items.

**Evidence.** [TaskFilter](../../Sources/TaskovskyCore/Settings.swift); [FilterEditor](../../Sources/Taskovsky/FilterEditor.swift); [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift); [FilterHardeningTests](../../Tests/TaskovskyCoreTests/FilterHardeningTests.swift).

<a id="bus-022"></a>

### BUS-022 — Advanced filters

**Current rule.** A non-nil AND/OR/NOT condition tree replaces normal criteria, including the normal keyword/status; the deleted guard and eligibility rules still apply. Both empty AND and empty OR evaluate true. NOT inverts its child. Conditions support list, tag, no tags, priority, date, kind, status, keyword and repeating. Only positive list references (including double negation) grant an explicit archive/exclusion override. Unconfigured list/tag conditions with no selected ID match nothing. Deleted-entity IDs remain stored and normally match nothing after membership cleanup; the matcher compares selected IDs directly rather than requiring the entity to exist. Editor conversions preserve existing conditions or refuse a lossy conversion; depth limits and stale-index guards apply.

**Acceptance.** Save a rule with nested NOT, reload, and compare its meaning. Verify NOT(list A) does not reveal archived list A just because it was mentioned. Test empty groups intentionally. Try collapsing a multi-child group to a single condition and verify constraints are not silently discarded.

**Evidence.** [FilterRule/TaskFilter.evaluate](../../Sources/TaskovskyCore/Settings.swift); [FilterRuleEdit](../../Sources/TaskovskyCore/FilterRuleEdit.swift); [FilterEditor](../../Sources/Taskovsky/FilterEditor.swift); [FilterIntentTests](../../Tests/TaskovskyCoreTests/FilterIntentTests.swift); [FilterHardeningTests](../../Tests/TaskovskyCoreTests/FilterHardeningTests.swift).

<a id="bus-023"></a>

### BUS-023 — Quick search and full search

**Current rule.** Local search is case-insensitive over title/body/quick-step text. Quick search also searches list, tag and filter names, displays up to five task results and eight per other category, and retains up to ten recent queries in preferences. Arrow navigation selects results; Return opens the selection or full search. Quick search excludes Trash but can include archived, completed and Won't Do matches.

Full search retains its query/filter state while opening detail and combines text matching with a `TaskFilter`-backed date/list/tag/type/status selection. It does not have cloud search. Save as Filter transfers the selected criteria and keyword to the editor. Full search applies archive/exclusion unless a list is explicitly selected, so its default scope can differ from quick search.

**Acceptance.** Search a quick-step title and a body match; open a result without losing the full-search query. Compare an archived match in quick versus full search. Save a filtered query, reopen the filter, and verify criteria round-trip.

**Evidence.** [TaskSearch](../../Sources/TaskovskyCore/Settings.swift); [SearchView](../../Sources/Taskovsky/SearchView.swift); [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift); [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift). Native keyboard/navigation paths are not established by matching-unit tests alone.

<a id="bus-024"></a>

### BUS-024 — Editable Summary reports

**Current rule.** Summary generates editable plain text for Today, This/Last Week, This Month or a custom inclusive day range. It includes non-deleted task records (not notes) whose due, completed or Won't Do date falls in the period, subject to selected lists/status and archive/exclusion rules. Grouping is by status/list/date; optional fields are date, list, description, tags and priority. Next Period Tasks appends open dated tasks in the following period. Changing options regenerates and replaces edits. Copy uses the clipboard. Save as Note creates an Inbox note from the current output and clears its date/reminders/tags/priority; it is not an external share or generated AI summary.

**Acceptance.** Include a completed undated task by completion date, exclude a note, adjust fields and observe regeneration. Edit the report, save as a note and inspect the saved text and cleared defaults. Explicitly select an archived list and compare the result with All Lists.

**Evidence.** [SummaryView](../../Sources/Taskovsky/SummaryView.swift); [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift). No dedicated Summary generation test file was identified; end-to-end generation/copy/save needs macOS verification.

## Settings, persistence and evolution

<a id="bus-025"></a>

### BUS-025 — Settings and durable local state

**Current rule.** Workspace and settings are separate JSON files. Normal storage is under the application-support Taskovsky directory; legacy Taskvovsky migration preserves the original if moving fails and does not overwrite an existing current directory. Workspace writes are atomic. A workspace decode failure preserves the original and blocks writes until explicit recovery backs it up; settings decode failure similarly prevents overwriting the unreadable settings. Calendar display options are stored in settings JSON with backward-compatible defaults: Week, five days/two weeks, sidebar/completed/repeat on, checklist off, List colors, Filled style, all active lists plus Inbox and unrestricted tags. Additional zone and list/tag scope persist too. Focus date and Arrange visibility are transient. Calendar View Options is separate from the four main Settings sections. Some UI state, including recent searches and layout preferences, uses UserDefaults rather than workspace JSON.

The four Settings sections are Smart Lists, Date & Time, More and About. Configurable behavior includes week start/numbers, time-zone/date/tag recognition, URL title parsing, default creation choices/reminders/duration, task/overdue position, completion sound and templates. Optional legacy fields decode with defaults; malformed hierarchy references are sanitized without intentionally deleting content. This is not arbitrary corrupt-file recovery or a cross-device synchronization system.

**Acceptance.** Reload settings and workspace after valid edits. Corrupt an isolated workspace and verify normal save does not replace it; recover only after a backup exists. Repeat with malformed settings and confirm those original bytes remain. Launch with a bare/invalid `--workspace` and verify isolation uses temporary storage rather than the normal workspace.

**Evidence.** [TaskStore storage](../../Sources/TaskovskyCore/TaskStore.swift); [AppMigration](../../Sources/TaskovskyCore/AppMigration.swift); [IsolatedLaunch](../../Sources/TaskovskyCore/IsolatedLaunch.swift); [Models decoding](../../Sources/TaskovskyCore/Models.swift); [SettingsView](../../Sources/Taskovsky/SettingsView.swift); [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift); [FoldersSmartOrderTests](../../Tests/TaskovskyCoreTests/FoldersSmartOrderTests.swift); [BoardIsolationGateTests](../../Tests/TaskovskyCoreTests/BoardIsolationGateTests.swift).

<a id="bus-026"></a>

### BUS-026 — Verification boundaries and future decisions

**Current rule.** Implemented source, existing tests, historical runtime reports and unverified behavior are different evidence classes. The five [earlier deviations](verification.md#known-deviations) now have merged corrections and prior regression evidence; their remaining live-check limits stay explicit. Documenting a desired outcome does not fix code. Historical test totals in the [archived implementation log](../archive/parity-implementation-history.md) are not a current gate.

**Future/proposed.** The [shared-engine proposal](../architecture/shared-engine.md), [component boundaries](../architecture/components.md) and [iPhone capability plan](iphone.md) may evolve independently of macOS presentation. In particular, rich editing can be developed/tested as a component with a smaller iPhone feature set, provided supported data is preserved and unsupported operations are explicit. External Calendar integrations, Focus/Pomodoro, Habits, Matrix, Countdown, accounts/sync/sharing and OS notification delivery are outside the current implementation baseline, not promised by this document.

**Acceptance for later changes.** Name affected BUS and parity IDs; distinguish intended behavior from an existing deviation; add relevant implementation/tests in the separately scoped change; record the exact revision, environment and checks actually run. Update this specification when source changes, rather than maintaining competing “current” behavior in chronological logs. Follow the [change workflow](workflow.md).

## Local Calendar

<a id="bus-027"></a>
### BUS-027 — Calendar projection and scope

**Current rule.** Calendar reads the existing workspace. Day, Week, Month, Year, Agenda, Multi-Day and Multi-Week use the configured week start. Agenda covers 30 days; Multi-Day accepts 2–14 days (default 5), Multi-Week 2–6 weeks (default 2). List/Inbox filters combine with any selected tag, including its descendants. Archived and deleted tasks are excluded regardless of scope; smart-list exclusion does not exclude a task from Calendar. Completed/Won't Do visibility, inherited checklist rows and repeat previews are optional. All-day dates float by civil date in the task zone; stored inclusive all-day ends become exclusive display ends. Timed intervals use absolute instants and exclude an ending midnight from the following day's fragments.

**Acceptance.** Project an excluded-but-active list, archived list, parent tag with a tagged descendant, multi-day span and midnight-ending timed window. Compare Today in opposite-side time zones for all-day points and ranges. Check each visible range around leap days and configured week starts.

**Evidence.** [TaskCalendar](../../Sources/TaskovskyCore/TaskCalendar.swift); [TaskCalendarProjection](../../Sources/TaskovskyCore/TaskCalendarProjection.swift); [TaskCalendarTests](../../Tests/TaskovskyCoreTests/TaskCalendarTests.swift); [CalendarReviewRegressionTests](../../Tests/TaskovskyCoreTests/CalendarReviewRegressionTests.swift).

<a id="bus-028"></a>
### BUS-028 — Read-only recurrence forecasts and Arrange

**Current rule.** Future cycles use the same recurrence engine as completion, but persist no records. Completion-based previews assume on-time completion. Current checklist rows retain actual checked state; future rows are unchecked, matching real successors, under either Show Completed setting. Projected occurrences and checklist rows cannot be independently scheduled. Each task's traversal is capped at 5,000 occurrences and truncation is surfaced. Arrange includes undated tasks and optionally tasks due before the current display day, grouped by list/first tag/priority. The Arrange chooser’s All option retains Calendar list/Inbox scope; choosing Inbox or one list replaces that portion of scope rather than intersecting it, while retaining Calendar tag filters. All-day overdue classification uses the task's displayed civil due/end date; timed classification retains an absolute prior-day cutoff.

**Acceptance.** Compare tomorrow's checklist preview with the actual generated successor; toggle completed visibility without hiding future unchecked items. Confirm projection leaves stored bytes unchanged. Check Tokyo/UTC and Auckland/Los Angeles yesterday/today/tomorrow classification and a bounded long-running series.

**Evidence.** [TaskCalendarProjection](../../Sources/TaskovskyCore/TaskCalendarProjection.swift); [TaskCalendarTests](../../Tests/TaskovskyCoreTests/TaskCalendarTests.swift); [CalendarReviewRegressionTests](../../Tests/TaskovskyCoreTests/CalendarReviewRegressionTests.swift).

<a id="bus-029"></a>
### BUS-029 — Atomic Calendar scheduling and guarded Undo

**Current rule.** Calendar creation is staged; Cancel creates nothing. Editing an existing task preserves point/range shape and exact endpoints. Unchanged Save emits no mutation, retaining timestamps, reminders, nominal recurrence position and persisted bytes. Turning Duration on is explicit; turning it off keeps the range's due endpoint. Grid snapping is 15 minutes. Existing timed moves preserve exact elapsed seconds, including zero/short/fractional durations; point moves stay points. Hourly header creation and an undated Arrange Schedule editor start at 09:00–09:30. Applicable drag moves that need a new timed duration use the configured duration or 30-minute fallback; existing timed point moves remain points. These defaults and explicit resize minima are separate policies. All-day movement preserves civil spans; month drops preserve an existing timed clock. Invalid, deleted or archived edits are refused.

Schedule changes go through `scheduleOnCalendar`; automatic reminders are recomputed and manual reminders shift with the schedule. Remove date clears the duration, reminders and repetition. Undo restores only scheduling fields and their recurrence anchors; text/tag/list edits survive, while a later schedule/rule/status change invalidates the token. This is a guarded in-memory operation, not a persisted history or native Cmd-Z/redo stack.

**Acceptance.** Unchanged Save on reminded repeating points and 0/5/10-minute ranges must preserve the full schedule and file bytes. Move short and fractional windows, then reload and Undo in separate scenarios. Confirm an unrelated text edit survives Undo and a later schedule/status edit blocks it. Cancel a new task; explicitly convert a point to a range and undo it.

**Evidence.** [CalendarScheduleDraft](../../Sources/TaskovskyCore/CalendarScheduleDraft.swift); [CalendarScheduling](../../Sources/TaskovskyCore/CalendarScheduling.swift); [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift); [CalendarReviewRegressionTests](../../Tests/TaskovskyCoreTests/CalendarReviewRegressionTests.swift); [TaskCalendarTests](../../Tests/TaskovskyCoreTests/TaskCalendarTests.swift).

<a id="bus-030"></a>
### BUS-030 — Local Calendar boundaries

**Current rule.** Calendar has no external account, EventKit access, subscription/feed, import/export, sync, sharing or external-event overlay. Additional time-zone display uses Foundation's installed data. Habit/focus/countdown overlays, repeating-series exceptions, independent checklist scheduling and all-day resize handles are absent. Multi-day fragments, Year Standard dots/Heatmap scaling and gesture policies are Taskovsky choices rather than recovered TickTick algorithms. Calendar's macOS implementation does not add an iPhone target or expand the iPhone proposal's scope.

**Display preferences.** Up to three additional time-zone rows store a valid Foundation time-zone identifier and an optional trimmed label of at most 32 characters. Normalization removes invalid IDs and duplicate identical IDs, preserves order and keeps the first three valid distinct rows. Equal current offsets do not collapse distinct IDs. Visibility is independent of the saved rows. A row matching the primary zone stays configured but its duplicate ruler is hidden. The primary zone and task schedules are unchanged. Named rulers apply to Day, Week and Multi-Day; their wall-hour conversions and blank-label abbreviations use the first displayed date, not independent per-column offsets across later DST transitions.

Time Zone Settings stages additions, replacements, labels, ordering and removal until Save; Cancel/Escape discards the draft. Its searchable child picker uses selection plus Choose/Return, and child Cancel preserves the parent draft. Turning visibility off retains rows; turning it on with none opens configuration. Saving while visibility is off leaves it off. Legacy `additionalTimeZoneID` migrates to an enabled unlabeled row only when valid. A new collection takes precedence, including an empty collection; a compatible first enabled ID is encoded for older readers.

Year Standard displays item dots; Heatmap uses visible-entry count shading and remains the default. Both preserve date drill-down. Year style is independent from Filled/Outline card style. Show Item Icons defaults on; hiding icons also hides task checkboxes on entry cards, while task context menus retain Complete/Reopen. These display preferences do not change projection, counts, task status, recurrence or reminders. Limits and rendering are Taskovsky policies, not full TickTick equivalence.

**Display acceptance.** Migrate legacy/empty preferences; reject invalid/duplicate IDs; reload hidden labeled rows in order; retain a configured primary-zone match; verify staged Save/Cancel and nested picker Cancel. Toggle Year style and icons without changing schedules or projection. Check multi-ruler narrow layouts and DST ranges separately from model tests.

**Acceptance.** Launch Calendar without account or permission prompts; verify records/options remain local. Do not interpret a stored reminder or additional ruler as network integration. Keep the deferred-integration table and the platform proposal explicit when requesting follow-up features.

**Evidence.** [CalendarTimeZones](../../Sources/TaskovskyCore/CalendarTimeZones.swift); [TaskCalendarOptions](../../Sources/TaskovskyCore/TaskCalendar.swift); [CalendarTimeZoneSettings](../../Sources/Taskovsky/CalendarTimeZoneSettings.swift); [CalendarDisplayOptionsTests](../../Tests/TaskovskyCoreTests/CalendarDisplayOptionsTests.swift); [display verification](verification.md#calendar-display-follow-up); [Calendar evidence and limits](../ticktick-spec/calendar.md); [deferred integrations](../parity-implementation-status.md#calendar-integrations-deliberately-deferred--8-november-2026); [iPhone proposal](iphone.md).

