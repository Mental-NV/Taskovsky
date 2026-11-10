# Taskovsky iPhone development preview

This partial local implementation stores JSON in its own Application Support container. Normal Debug/Release launches start empty. Existing known-format tasks support title and description edits. Styled descriptions have a selectable preview and a separate Format description editor with Inline and Paragraph controls. Unknown/unsupported workspace data blocks rewriting. Add creates tasks/notes with list/Inbox, date/time, priority, existing tags and saved templates. Task rows and detail support completion, reopening, Won’t Do, pinning, list moves, Trash and restoration. Delete Forever requires a named confirmation for one trashed task. Existing-task detail edits priority, existing tags and embedded checklist items. Linked subtasks have their own details and completion. Lists and folders can be managed from the drawer. Smart List visibility and ordering are editable in the drawer. Manage Filters supports Normal and Advanced saved filters. Manage Tags supports nesting, pinning, reorder, merge and deletion.

The target consumes `TaskovskyDomain` and `TaskovskyWorkspace`, not the macOS `TaskovskyCore` facade. Explicit Done saves one owned field after revision/compatibility checks. Dirty Cancel offers Discard/Keep Editing; unchanged Done preserves workspace bytes. A separate exact-text scratch draft saves after 250 ms and on background opportunities. Relaunch offers Resume/Discard without submitting. A force kill before an acknowledged scratch write can lose the newest characters. Unknown scratch data is kept and blocks replacement; stale edits retain their text without rebasing.

Capture uses the shared Mac creation policy. It previews the destination and schedule, lets users ignore recognized date/tag suggestions, and preserves template rich text, checklist, recurrence and duration. An acknowledged prepared draft is stored separately before writing. Retry checks the same stable ID; a confirmed failure retains editable input, and an uncertain result retains the submitted payload. Recovery never submits by itself. Calendar Add uses the focused day, with all-day entries reachable in hourly views and Month overflow linked to Day.

The Mac store and phone repository share lifecycle and recurrence rules. Completion and Trash offer Undo for the revision that saved the action. Reopening after relaunch uses the saved cascade ledger and retains recurrence successors. Archived tasks can move to Inbox or an active list.

Priority and direct checklist checkmarks save immediately. Tag and checklist editors stage changes until Done and prompt before discarding edits. Checklist drafts live in the open editor. Calendar shows saved checklist items when that option is enabled.

The drawer groups lists, folders, pinned shortcuts and archives. Manage Lists creates, renames, reorders, pins, moves, archives and restores lists or folders as applicable. It confirms duplication, deletion and ungrouping.

Smart Lists stages drawer visibility and order. The phone uses saved visibility for the top destinations, history, and Tags and Filters sections. Done saves the preferences and switches away from a destination that became hidden.

Manage Filters stages criteria and rule edits. AND, OR and NOT headers distinguish groups, and a contextual action sheet holds structural edits. The editor shows the match count and confirms replacing an advanced tree or deleting a filter. Unavailable list and tag selections remain explicit.

Formatted task descriptions can fold heading sections while reading. Format description always opens the full body.

Tasks lists can sort by Created or Modified in either direction. The choice stays on the device. Concrete lists support their own List/Board mode. Board status tabs support card drops and a status menu. Archived boards are read-only.

Search matches tasks and notes by title, description and embedded steps and opens matching lists, tags and filters. Criteria stage until Done. Recent queries stay in the app’s preferences, and Save as Filter opens the existing filter editor.

Task Actions can duplicate a task or note. The copy opens in detail and keeps the copied subtree, formatted description, checklist and schedule. Convert to Note and Convert to Task change the kind in place while preserving the original content and links.

Manage Templates opens from the drawer. Task Actions saves a record as a template or applies a saved template after confirmation. The reduced editor preserves styled descriptions, repeat rules, duration and unedited checklist items.

Settings opens from the drawer toolbar. Calendar week start and new-task defaults stage until Done. The app saves the changed settings members and retains unrelated settings and task data.

Summary generates an editable local report. Filters stage until Done. The report supports regeneration, Copy and saving the exact edited text as an Inbox note. A failed note save can resume through capture recovery.

Manage Tags stages name, color, parent and pin edits. Sibling order and drawer disclosure persist. Merge updates references and deletion retains unavailable filter criteria.

The Subtasks section creates children, opens their details and changes or removes the parent link. A cross-list link previews the destination and moves the subtree together. Task lists show nesting within each group.

Tasks and Calendar share a detail Schedule sheet. Date, time, duration, task zone, manual or default reminders, and simple or custom recurrence all stage until Done. Cancel or dismissal leaves the task file unchanged. Remove schedule also waits for Done. Untouched saves preserve the original schedule bytes, including precise times and rolled recurrence positions.

Calendar actions include Arrange Tasks, with the shared list, grouping and overdue rules. A task can be scheduled from Arrange or edited from its Calendar card. Long-press commands and the direct drag and resize affordances use the same local write and scoped Undo. Recurring cards stage This occurrence or Series and support restoring their original schedule. The timed handle also opens the resize editor when tapped. Agenda starts with 30 days, and Show more extends its local horizon by six months. Day, Week and Multi-Day default to 07:00–21:00. Expand both bands to drag the cutoff markers, or use View Options to adjust or reset the saved hours. Early hours and Late hours reveal the folded time bands and show how many timed items overlap them. View Options can hide task and note icons independently. In Month, pinch or use the zoom buttons to show fewer weeks with more tasks per day. In the hourly views, View Options can set a fixed number of visible all-day rows.

Calendar mode, source scope, and View Options save inside the phone's local settings file. The settings transaction replaces only the Calendar options object. Preferences support the seven local views, display styles, repeat/checklist/completion visibility, range counts, and up to four named secondary rulers.

Files request iOS protection until first unlock and retain ordinary Application Support backup eligibility under device settings. No backup/restore guarantee, sync, import, account or notification permission flow is provided. Bootstrap preserves existing, partial, unreadable and orphan-staged files; no repair/overwrite UI exists. The repository is single-process, with no shared live files or multi-file transaction.

Build with installed Xcode:

```sh
xcodebuild -project Mobile/TaskovskyMobile.xcodeproj \
  -scheme TaskovskyMobile -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TaskovskyMobileBuild CODE_SIGNING_ALLOWED=NO build
```

For samples, add **Debug-only** launch arguments `--qa-session <fresh UUID>`. This selects `TaskovskyMobile/QA/<UUID>` inside the app container and loads bundled [Mac-written neutral fixtures](Fixtures/README.md), never desktop data. Relaunching with the same UUID preserves that QA session. Invalid QA/path arguments fail closed; Release refuses QA arguments. Fault cases `--qa-case summary|summary-save-failure|save-failure|stale-save|unknown-workspace|unknown-draft|capture-empty|capture-template|capture-after-write|lifecycle|arrange|calendar-options|rich-preview|malformed-rich|task-metadata|organization|saved-filter` also require a valid QA UUID. They are test fixtures, not user-facing settings.

Choose an installed iPhone simulator for tests. The evidence run uses a separately created **Taskovsky QA iPhone 13 Pro**, iOS 26.3.1 (23D8133). Replace the destination if unavailable:

```sh
xcodebuild -project Mobile/TaskovskyMobile.xcodeproj \
  -scheme TaskovskyMobile \
  -destination 'platform=iOS Simulator,name=Taskovsky QA iPhone 13 Pro' \
  -derivedDataPath /tmp/TaskovskyMobileBuild \
  -resultBundlePath /tmp/TaskovskyMobileTests.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=NO test
```

The scheme currently runs 38 shared-domain tests, 81 workspace tests, one hosted UIKit test and 94 native UI tests. Each UI case owns a fresh QA UUID, retained as a result attachment; relaunch tests reuse it. The read-only audit in `scripts/verify-mobile-qa-roundtrip.py --capture --lifecycle --schedule --arrange --preferences --rich-preview --metadata --hierarchy --organization --smart-lists --saved-filters --tags --boards --summary --search --templates --local-settings --rich-editor` checks the saved files against their Mac-written baseline, then invokes the explicit-path Mac fixture helper to reload known data without writes. See [exact evidence and limits](../docs/spec/verification.md#calendar-all-day-rows). Full Mac tests/build are separate checks.

Regular lists with named sections group rows and Board cards by section. Use Manage Sections to edit the order and Add task in a section to open capture with that destination. [Section verification](../docs/spec/verification.md#task-list-sections).

The target compiles for iOS 17; only the installed iOS 26.3.1 runtime was exercised. iOS 17 runtime, physical-device/signing/notification checks, IME, VoiceOver, Dynamic Type, rotation, broad appearance and performance coverage remain open. Rich editor hardware Undo/Redo, system IME candidate selection and gestures require separate verification. All seven Calendar modes, Work/All source reset, Calendar Add visibility and Month overflow have native coverage; remaining gesture combinations and reference visual matching are still open. Dirty swipe dismissal is blocked with explicit Cancel available; no swipe-attempt confirmation callback is implemented. No inert controls for missing workflows are included.
