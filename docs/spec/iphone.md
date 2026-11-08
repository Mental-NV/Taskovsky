# Proposed iPhone experience

<a id="ios-001"></a>

## IOS-001 — Status, goals, and limits

**Proposal only. Nothing in this document is a claim of current iOS support.** The inspected baseline is main commit `cfdec454acff91285ac00beaa20c0cf0f0961ee1`, as of 2026-11-08. [Package.swift](../../Package.swift) currently declares macOS 14 and a macOS executable; the [current UI specification](ui-ux.md) describes that implementation.

The proposed iPhone product should retain Taskovsky's tasks/notes, scheduling, organization, and data meaning while using a native touch interface. A shared business engine is the target. Shared AppKit screens, a 382-point-wide Mac window, and complete desktop editor feature parity are not requirements. This document adds no app target, shared package, UIKit editor, migration, sync service, OS notification integration, or tests.

Use stable `IOS-xxx` IDs in implementation tickets and acceptance tests. “Must” below is a proposed requirement for the eventual feature, not a statement about existing source. Release sequencing and minimum iOS version still require an implementation decision. Follow [shared-engine boundaries](../architecture/shared-engine.md#arch-002), [component contracts](../architecture/components.md), [business behavior](business.md), and the [verification/deviation register](verification.md). Merged PR #2 resolves the five earlier source-review findings; preserve their regression contracts when extracting the engine. This proposal adds no iPhone implementation.

Goals:

1. Capture and complete a task quickly with one hand.
2. Reach tasks, notes, lists, tags, filters, and history without a desktop sidebar.
3. Preserve existing data even when a phone cannot edit all of it.
4. Keep date/recurrence/hierarchy/archive behavior consistent through shared commands and policies, rather than duplicating rules in views.
5. Use readable native navigation, accessible targets, explicit destructive choices, and predictable interruption handling.

Non-goals for the initial proposal: full rich-text authoring, drag parity, boards/custom board columns, advanced-filter authoring, desktop pane-resizing behavior, desktop settings chrome, account/sync infrastructure, widgets/watch app, system notifications, background processing, calendar/habit/focus/countdown modules, or reproducing the reference product pixel for pixel. Stored features omitted from the phone UI must remain intact.

<a id="ios-002"></a>

## IOS-002 — Information architecture and navigation

Use a native tab container with independent navigation stacks:

- **Tasks** (`checkmark.circle`): launches into Today; destination title identifies Today, Inbox, Next 7 Days, a list, tag, or saved filter. A leading “Browse” navigation control opens the navigation root.
- **Search** (`magnifyingglass`): native search field and results, scoped-filter sheet, and preserved query/result state when visiting task details.
- **Settings** (`gearshape`): grouped native forms and About. No second fixed sidebar or floating Mac settings window.

Tasks → Browse is a full-screen hierarchical list rather than a 220-point popover. It contains configured smart destinations, pinned shortcuts, Lists/folders, Tags, Filters, history, and Archived Lists. Smart-list visibility/order and hierarchy come from the shared data/presentation projection. Do not reconstruct them by scraping macOS UI or by independently guessing counts.

A task opens as a pushed detail page, not a right overlay or independent window. Standard back navigation returns to the exact prior destination, query, scroll position, and group expansion when possible. Parent/child task navigation must keep a sensible back path without duplicating the same task indefinitely. Destination changes should not erase unrelated unsent capture drafts.

Notes remain a task kind in lists, as on Mac. A separate Notes tab is not required. The current Mac source contains an internal Reminders destination but does not expose a normal sidebar row; adding an iPhone Reminders entry is a future product decision, not inherited behavior.

For horizontally compact layout, always use one column. Landscape can increase line width but must not automatically introduce desktop panel widths. Any future iPad adaptation needs its own design; this document specifies iPhone only.

<a id="ios-003"></a>

## IOS-003 — Proposed visual and accessibility tokens

These are **new design targets**, not measured source values or validated screenshots. Retain recognizable symbols and accent where accessible; do not copy desktop font sizes or hit areas.

| Role | Proposed iPhone token |
| --- | --- |
| Typography | Native semantic `.largeTitle`/`.headline`/`.body`/`.subheadline`/`.caption`, supporting all Dynamic Type sizes; no fixed 14-point body requirement |
| Main text/background | Platform semantic label, secondary label, system background, grouped background, separator colors |
| Accent | Start with Mac `#5171F2`; validate contrast before shipping, including selected text and dark/high-contrast variants |
| Destructive/overdue | Native red plus explicit text/icon, never color alone |
| List/tag colors | Preserve stored user color values; use dot/pill plus text, do not recolor the whole row or make color the sole identifier |
| Interactive target | At least 44 × 44 points, including completion and toolbar controls |
| Page/form horizontal margin | Native system margins; 16-point minimum custom-content inset at ordinary widths; respect safe areas |
| Task row | Minimum 56 points at ordinary text size, expands for text/metadata; 12-point custom inter-element gap where needed |
| Task title | Up to two lines at ordinary size; allow expansion at accessibility sizes; no partial-glyph hard clipping |
| Card/sheet styling | Native grouped rows, sheets, and material rather than a mandatory desktop radius/shadow recipe |
| Animation | Native navigation/sheet transitions; any custom move/fade must respect Reduce Motion and never carry information available only in motion |

Do not assert fixed pixel values for native tab height, navigation bars, text metrics, picker rows, safe-area inset, or sheet height. These depend on OS, device, text size, and content. Native UI can change while the semantic contract stays stable.

At accessibility text sizes, move metadata below the title, stack form labels/values, replace dense horizontal tool rows with labeled menus, and retain all actions without horizontal clipping. Right-to-left layout must follow leading/trailing semantics. Long localized dates/tags/list names must remain reachable in detail even when a row truncates.

<a id="ios-004"></a>

## IOS-004 — Task list and completion

The list consumes shared eligibility, sort/grouping, hierarchy, due-label, and pin projections. Initial phone view is a native vertical list; a Mac list's persisted Board mode must not be overwritten merely because the phone renders rows. If needed, show “Board view is available on Mac” in view options, without blocking task access.

Row structure:

1. Independent completion control with a 44-point hit region, or a note symbol for a note. Show state in icon and accessibility value, not only color.
2. Title in body text, normally up to two lines; completed/Won't Do styling stays legible.
3. Optional secondary line for date, list context, subtask/checklist progress, and one tag with overflow indication. Full metadata is available in detail.
4. Optional disclosure/navigation affordance following native conventions. Tapping title/background opens detail; tapping completion does not navigate.

Use a trailing menu or context menu for secondary actions. Swipe actions may be conveniences but must have visible alternatives and avoid full-swipe irreversible deletion. Proposed leading swipe: Complete/Reopen for tasks; trailing swipe: Move to Trash. Notes do not offer completion. Keep Won't Do as an explicit menu action, distinct from Complete.

Pinned active tasks stay in a separate group and history remains separate. Archived lists permit reading and a deliberate Move to active list/Inbox, but not inline edits or drag. Trash rows offer Restore and an explicitly confirmed Delete Forever. Confirmation names the item and explains subtree consequences as established by the shared engine; do not guess cascading behavior in UI.

Manual reordering is optional after initial release. If added, use native Edit/Reorder controls with VoiceOver Move Up/Down equivalents and the same None-sort/pinned/group policy. Other sorts must explain why manual reorder is unavailable; they must never silently change dates, priorities, or status to simulate a move. Desktop grip-only drag is not a phone requirement.

<a id="ios-005"></a>

## IOS-005 — Capture sheet and contextual creation

A labeled Add action in the Tasks toolbar presents a native sheet with task/note mode, title, optional description, list, date, priority, and tags. The native keyboard focuses title. Add commits one item through the shared create command; Cancel dismisses without creating a task. Empty/whitespace title disables Add with accessible explanation where needed.

- Carry destination context deliberately: list/tag scope, Today/Tomorrow defaults, and task/note default come from shared policies. Show the actual selected list and date before Add.
- Recognized date/tag candidates must be visible and dismissible. Recognition changes a preview/draft until submission; it must not silently commit background records while the user explores choices.
- Multiword tag selection must not require typing the desktop quoted-token syntax. The same tokenizer can support typed tokens, while a native picker supplies resolved tag IDs.
- Notes have no completion control. Capture must preserve the source distinction between a task and note rather than treating a note as a completed task.
- “Use Template” opens a native template list with title, excerpt/checklist preview, and an explicit use action. Applying a template updates the capture draft, not an unrelated existing item.
- URL-title parsing, if supported, follows the shared setting and a supported network adapter. Slow/failing parsing must not block saving the user-entered title or replace a newer title with a stale fetch result.

Initial plain description entry must obey IOS-008. A template containing styles can still create an item losslessly without being fully editable on the phone. Do not convert the template's styled body to plain text in the capture field.

A draft may survive interactive sheet dismissal/backgrounding only if the chosen draft-storage policy supports it. Before implementation, choose whether canceled drafts are discarded or explicitly saved, and make the user-visible copy consistent. The minimum correctness requirement is no unrequested task creation and no partial store mutation from Cancel. A nonempty unsaved draft should require a Discard/Keep Editing choice on explicit cancellation or attempted interactive dismissal.

<a id="ios-006"></a>

## IOS-006 — Task and note detail

Use a single scrollable native detail page with a clear title, status, body, schedule, list/priority/tags, checklist, and subtasks. Keep frequently used status/schedule actions near the top; move duplicate/template/conversion/trash actions into an accessible More menu. Use a labeled Save indicator or nonblocking error state if persistence is asynchronous; never show “Saved” before confirmation from the persistence boundary.

Proposed edit transactions:

- Title/body edit sessions have explicit Done/Cancel when an editor is opened; the rest of detail remains read-only presentation while that edit draft exists. This intentionally need not mirror Mac's per-keystroke title/body writes.
- Single metadata actions such as Complete or Move commit through one shared command, respecting locks and hierarchy policy.
- Schedule/recurrence uses the staged transaction in IOS-007.
- Checklist title/addition and subtask creation use local drafts and explicit submission. Entering text must not create empty records. Checklist is embedded data; subtask is a separate linked task.

Navigating back must resolve an outstanding edit draft through a clear save/discard flow rather than overwrite stored content implicitly. Backgrounding retains the current draft when possible; forced termination recovery requires a deliberate draft-persistence design, not reliance on an in-memory view model.

Completed and Won't Do states expose Reopen. Archived detail clearly says read-only and explains how to unarchive/move; Trash shows its status and Restore. Edit buttons unavailable due to lock must not remain silently interactive. Metadata changes to a styled/unsupported body are allowed only through the lossless path in IOS-008.

Parent/child links expose meaningful accessibility labels and own task details. Completing a parent should show feedback consistent with the shared subtree operation. The phone must not implement its own naive “toggle every child” loop or create duplicate recurring successors.

<a id="ios-007"></a>

## IOS-007 — Date, duration, recurrence, and reminders

Use a native schedule sheet with a navigation title, Cancel, and Done. Dates, time, zone, multiple reminders, and optional duration are one staged draft; neither Cancel nor interactive dismissal changes the task. Clear schedule is an explicit action that stages clearing until Done, or uses a separately labeled immediate confirmation. Choose one and test it consistently; copying Mac's immediate Clear is not mandatory.

Use platform date/time pickers and readable shortcut labels rather than desktop 28 × 26 calendar hit cells. Shared calendar policy controls week start, due-label classification, timezone interpretation, DST behavior, recurrence, and the duration end/due invariant. Every picker change must produce a valid intermediate draft or a visible validation error. Keep Done disabled when a required constraint is unmet; explain the actual reason.

Initial supported authoring scope:

- Date-only or date/time due date; remove due date; Today/Tomorrow/Next week shortcuts.
- No repeat and existing simple recurrence choices. Editing a date alone must not reset custom series position or replace a custom rule with a simple default.
- Explicit reminders and timed/all-day duration can be added when the shared draft engine is extracted and tested. Until supported, render them with a summary and preserve them; do not drop them on unrelated date edits. If a date edit would require an unsupported transformation, disable that edit with a reason rather than saving incoherent data.
- Custom recurrence may initially be **view/preserve only**: show its human-readable rule, remaining count, and supported preview. “Edit on Mac” is guidance, not a promise of a handoff/sync feature. An explicit replacement with a supported simple rule must clearly name the replacement and require the user's deliberate choice.

Advanced recurrence authoring can later use a dedicated native screen for anchor, cadence, weekday/month/year selectors, specific dates, and endings. Its Cancel must restore the entire prior outer draft. Reuse the merged Mac correction: sheet-local Cancel preserves outer recurrence, due edits rebase nominal cadence without resetting occurrence count, and all-day descendant reminders keep their clocks. Carry the existing regressions into the shared implementation and verify the native phone transactions separately.

Reminder presentation and system notification delivery are separate. Initial iPhone scope must not promise notifications while the app is closed. Adding notifications later needs a platform adapter, explicit authorization UX, permission-denied state, time-zone/background delivery tests, and a policy for rescheduling/canceling notifications after edits. Storing reminder dates alone is not notification support.

<a id="ios-008"></a>

## IOS-008 — Limited body editing without data loss

This is the central cross-platform constraint. See [rich component overview](../architecture/components.md#cmp-001), [data contract](../architecture/components.md#rich-001), [capability matrix](../architecture/components.md#rich-003), [limited editing](../architecture/components.md#rich-004), and [unknown formats](../architecture/components.md#rich-005).

The initial phone body editor may be a small native plain-text component. It must not import AppKit text views or share the desktop toolbar implementation. The shared document contract, exact body text, identifiers, and preserved styling matter more than feature parity.

| Existing body | Initial phone behavior | Permitted save |
| --- | --- | --- |
| Plain body, no rich payload | Native multiline editor, text selection, keyboard, document-scoped undo | Updated body through validated command |
| Known supported rich version with genuinely empty formatting data | Treat as editable plain only after capability/validity classification | Preserve representation as required by the component contract; no speculative reconstruction |
| Valid styled body | Best-effort native read-only rich rendering, or clearly labeled read-only plain preview when unsupported | Unrelated metadata edits preserving the original body and rich payload unchanged |
| Styled template | Show preview and instantiate through engine; body remains read-only if styled | Preserve the complete template body/style data when creating the task |
| Unknown version/unsupported content/malformed style payload | Read-only content preview with explanation; preserve original payload | Metadata-only edit only if transport/store can retain unknown fields and original content unchanged; otherwise lock writes |
| Future partial rich editor | Out of initial scope | Enable only after proving supported edits preserve all unsupported runs/blocks and identity/ranges |

Required invariants:

1. Opening, previewing, navigating, or editing a date/title/tag must not serialize the displayed body back as a replacement document. Metadata edits must preserve fields they do not own.
2. No automatic stripping of formatting, list prefixes inserted into stored text, HTML round-trip, Unicode normalization, or lossy rich-to-plain conversion. Exact UTF-16 identity/range semantics in the model must survive.
3. An unsupported paragraph must remain intact even when the renderer can only show plain text. “Read-only preview” is a display capability, not authorization to flatten on save.
4. A future destructive “convert to plain text” action is not part of initial scope. If introduced, it needs explicit user choice, a reviewable consequence, undo/backup behavior, and its own tests.
5. Read-only styled body does not mean the entire task is always locked: supported metadata remains editable only when a field-preserving update path has been verified. The current whole-record Codable/save path is not automatically that guarantee, particularly for unknown fields/versions.
6. Native undo belongs to the current task/document. Switching tasks with identical text must not allow undo to paste another task's history. Use the same document-identity contract as the proposed component, not a global editor undo stack.
7. Return, text selection, IME composition, emoji/combining characters, and accessibility editing are native input behaviors to validate. AppKit-specific font attributes and painted markers are not portable contracts.

A read-only banner should say what remains possible: for example, “Formatting is view-only on iPhone. You can still change this task's date, list, priority, and tags.” Only show that wording when those writes are actually lossless and available. If exact preservation cannot be guaranteed, say the item is read-only rather than pretending edits are safe.

<a id="ios-009"></a>

## IOS-009 — Browse, lists, folders, tags, filters, and templates

Browse rows use native list disclosure and clear counts. Folder disclosure expands inline; it is not a task destination. Tag hierarchy is a navigable/expandable tree with bounded visual indentation and full accessible ancestry. Pinned shortcuts are references to existing entities, not duplicated data.

Initial management scope should prioritize create/rename lists and tags, choose list/tag color, assign tags, move tasks, archive/unarchive lists, and read saved filters. More advanced actions (folder reordering, tag reparent/merge, list duplication, advanced filter editing) can arrive as separate components after basic capture/detail safety. Unsupported management must not disable viewing existing content.

Simple list/tag/folder edits should use native sheets with Cancel/Save, validation for nonempty names, and shared cycle/reference/archive guards. Deleting a list must explain that tasks move to Inbox; deleting/merging tags must use shared reference rewrite behavior rather than only updating visible rows. Destructive entity actions require clear confirmation where their consequences would otherwise be surprising.

Saved filters use the shared evaluation engine, including unavailable references, positive explicit archive inclusion, NOT semantics, kind/status, inclusive dates, and custom rules. A read-only advanced filter is acceptable initially. Do not replace it with a simplified editable filter or discard unknown conditions when renaming. Authoring Normal filters can follow after the same lossless update constraint is satisfied.

Templates use a native single-column list/grid that adapts to text size. Use Template copies through the engine; Save as Template captures supported data without flattening rich body, discarding checklist state, or replacing recurrence/duration accidentally. A separate plain template editor must follow the same capability restrictions as task bodies.

<a id="ios-010"></a>

## IOS-010 — Search and history

Search uses native `.searchable` or equivalent, with cancel/clear actions and keyboard dismissal. Blank search can show local recent queries; nonempty query shows task/note results and organization matches. Match emphasis must preserve text legibility in both appearances; color is supplemental.

Each result distinguishes open/complete/Won't Do/note status and list context, supports opening detail, and keeps completion a separate accessible control. A snippet is optional; do not make body formatting changes merely to construct it. Search text and snippets consume authoritative plain body/checklist content through the shared search policy.

A filter sheet supports date/list/tag/status/type as implemented by the shared criteria model. Return/back from detail restores query, selected criteria, results, and scroll. Preserve unavailable/deleted list/tag references in saved filters rather than broadening results. If saved-filter creation is deferred, omit its button; do not show an inert “Save as Filter” control.

Completed, Won't Do, and Trash are explicit history destinations accessible from Browse. Restore and permanent deletion are separate commands. An item that disappears after completion or trash should provide a clear explanation/undo opportunity. History access must not depend on a swipe gesture or hidden desktop context menu.

<a id="ios-011"></a>

## IOS-011 — Settings, feedback, errors, and interruption

Settings should use native grouped forms for smart-list visibility, date/time display, recognition/defaults, templates (supported management only), and About. Mac-only pane sizes, window mode, hover controls, and desktop keyboard shortcuts do not belong in phone settings. Device-specific presentation preferences should remain local; sharing business defaults needs explicit schema/ownership decisions.

A completion/trash feedback component should acknowledge the result without covering Add or navigation. If retaining the Mac five-second Undo semantics, use one shared action token and prevent double-consumption across screens; provide an accessible announcement and a reachable alternative before claiming accessibility parity. No success feedback should appear when the command/persistence failed. System haptics are optional and must not replace visual/spoken state.

Required screen states:

- **Loading:** show progress only for actual asynchronous work; keep existing data visible where safe. A local in-memory screen should not gain a fake loader.
- **Empty:** distinguish no tasks, no search matches, no templates, and an empty Trash; offer only actions valid in that context.
- **Read-only:** archived list, deleted item, unsupported body, or unknown schema state explains the restriction and available safe actions.
- **Recoverable failure:** keep the edit draft, show a specific save/retry error, and allow cancel/navigation without falsely claiming persistence.
- **Unreadable workspace:** never overwrite the original silently. Recovery must preserve a backup and require a deliberate choice through the persistence component.
- **Background/foreground:** restore navigation/draft state where available, refresh time-relative labels and stale data, and invalidate stale edit versions before save. Do not submit a draft just because the app backgrounds.
- **External edit/conflict:** a proposed command should use record/revision identity and return a conflict instead of overwriting a newer record. The current local Mac store does not establish cross-device conflict handling.

<a id="ios-012"></a>

## IOS-012 — Shared engine, platform adapters, and persistence boundary

Current `TaskovskyCore` is not automatically portable just because it is named Core. [RichTextRender.swift](../../Sources/TaskovskyCore/RichTextRender.swift), [ListDecorations.swift](../../Sources/TaskovskyCore/ListDecorations.swift), and [ListLayoutManager.swift](../../Sources/TaskovskyCore/ListLayoutManager.swift) import AppKit; [TaskStore.swift](../../Sources/TaskovskyCore/TaskStore.swift) also mixes persistence/observation and operations. Extraction and compilation boundaries must be implemented before claiming a shared iOS engine.

The phone should call the proposed shared commands/projections for creation, status/hierarchy, task/list/tag/filter changes, schedules/recurrence/reminders, templates, eligibility, and persistence validation. UI owns navigation, focus, native sheets, touch targets, and accessible presentation. Rich editor, URL-title retrieval, haptics, notification scheduling, lifecycle, and platform storage access sit behind explicit platform-appropriate boundaries.

Preserve task/list/tag/filter/template identity and schema version. Shared semantics must not depend on reusing macOS AppStorage keys for mobile navigation state. Do not allow a narrow phone editor to overwrite a complete record with fields it never loaded or understood.

A shared engine does **not** imply shared live storage. There is no existing server/account sync to reuse. Initial testing may use deterministic fixtures/imported test workspaces. Any real transfer, file-sharing, iCloud, or synchronization design requires its own explicit architecture and permission/conflict/recovery specification. “Edit on Mac” must not be described as automatic continuity until a transfer mechanism exists.

<a id="ios-013"></a>

## IOS-013 — Component state and capability matrix

This is the proposed minimum contract, not implementation status. All iPhone cells are unimplemented and unverified.

| Component | Initial capability | State/edge cases | Release evidence required |
| --- | --- | --- | --- |
| Navigation/Browse | Native tabs, stacks, hierarchy, destination selection | Deep link to missing item; back; repeated selection; interrupted sheet; long names | Native UI navigation tests + VoiceOver/focus inspection |
| Task list | Read/open, complete/reopen, trash, context actions | Empty/filter-empty, notes, pin/history boundaries, archived/trash | Shared command tests + independent checkbox/navigation hit tests |
| Capture | Plain task/note, context, supported metadata/template | Empty title, cancel/discard, keyboard/IME, double submit, save failure | One command per Add; no record on Cancel; no lost styled template data |
| Detail metadata | Supported field edits | Stale record, locked task, unsupported body, persistence failure | Lossless field preservation including unowned data; conflict tests |
| Body editor | Plain only; styled read-only | Unknown/malformed/versioned rich body, identical-text task switch, emoji/IME | Component preservation tests + native text-input/undo/UI tests |
| Scheduling | Native staged sheet; supported capability subset | Cancel including nested editors, duration invariant, timezones/DST, custom rule | Shared golden fixtures + UI transaction tests |
| Organization/filter management | Browse all, edit supported subset | Dead references, cycles, archived targets, advanced rules | Cross-platform evaluation equivalence; no implicit simplification |
| Feedback | Shared action result/undo, native error presentation | Double undo, expiration, offscreen result, failure, slow VoiceOver user | Token/time tests + accessibility/usability verification |
| Persistence | Platform-specific repository using shared contract | Unknown fields, corrupt file, retry, backgrounding, external edits | Backup/recovery/round-trip/conflict tests |

<a id="ios-014"></a>

## IOS-014 — Acceptance scenarios and rollout gates

**Gate A: extract and verify contracts.** Before an iPhone UI writes production data, platform-neutral targets compile without AppKit, field-preserving update APIs are implemented, known review deviations are tracked separately, and fixture round-trips prove that a phone read/write does not damage Mac data. Existing macOS tests are starting evidence, not proof of iOS support.

**Gate B: native read/capture/detail.** Validate on at least a small and large supported iPhone size, portrait and landscape, light/dark, large accessibility text, VoiceOver, Reduce Motion, hardware/software keyboards where supported, and multiple locales/timezones. The exact deployment/version/device matrix must be recorded with the implementation; this proposal does not invent one.

**Gate C: optional feature expansion.** Add rich authoring, custom recurrence editor, advanced filters, boards, drag/reorder, OS notifications, or sync only with dedicated contracts and tests. Feature omission is acceptable; silent data loss is not.

Minimum end-to-end scenarios:

1. Create task and note in Inbox/list/date/tag contexts; cancel populated capture; try rapid repeated Add; verify one or zero intended records.
2. Complete/reopen a recurring parent with children, observe shared-engine results, undo exactly once, navigate away/back, and inspect persistent state.
3. Open a styled Mac document on phone; change title/date/list/tag where safe; return it to Mac and compare exact body, rich metadata, recurrence, duration, checklist, hierarchy, and identifiers. No format stripping.
4. Open unknown-version/malformed styled content; verify readable safe preview, explanatory lock, and unchanged original payload. If metadata writes are unsupported, verify they are blocked.
5. Edit plain Unicode text with emoji, combining sequences, multiline paste, IME composition, and undo; switch between two same-text tasks; ensure no undo/history leakage.
6. Stage date/time/zone/duration, cancel by button and gesture, reopen, then save. Verify end/due coherence, DST boundaries, custom series position, and unsupported-field preservation.
7. Search, set filters, open a result, navigate to child/parent, return; query/criteria/position remain coherent. Renaming a saved filter with missing references does not broaden it.
8. Browse an archived list, select an item, attempt forbidden edits, then deliberately move it to active scope. Read Trash, restore, and separately confirm permanent deletion.
9. Simulate save failure, unreadable workspace, background/foreground, and stale external edits. Preserve draft/original data and show no false success.
10. Complete primary flows using VoiceOver and large text without swipe-only actions, clipped controls, color-only status, or hidden focus; audit feedback expiry and keyboard obstruction.

Record actual results, OS/device/build, fixture, and remaining gaps in the [verification ledger](verification.md). Documentation approval alone does not satisfy any implementation gate.

