# macOS UI and interaction specification

<a id="ux-001"></a>

## UX-001 — Authority, scope, and evidence

This is the **code-derived baseline** at main commit `30045bac5355b793a8c155b87ffe58584cb29fb8`, inspected on 2026-11-08. It describes Taskovsky's implementation, not a new TickTick parity target. Source takes precedence over older README claims, reference measurements, comments about intended behavior, and this document when they disagree.

- **Current / code-derived:** declarations and control flow in the linked Swift files. Dimensions below are logical points, not measured device pixels. Numeric colors are literals in source; semantic colors, system fonts, native menus, sheets, and SF Symbol shapes resolve through macOS and appearance settings.
- **Runtime-unverified in this documentation task:** actual rendered sizes, focus order, pointer arbitration, keyboard routing, VoiceOver announcements, contrast, animation appearance, and OS-specific control sizing. No app, build, automated tests, or UI tests were run for this task. Existing tests are evidence of specified cases, not a claim of a fresh passing run.
- **Proposed:** the [iPhone specification](iphone.md) and [component boundaries](../architecture/components.md). They are not shipped features.
- The five [static review findings](../code-review-findings-2026-11-08.md) remain explicit deviations. Their fixes are outside this documentation change. A description of an intended interaction must not be read as proof that a known deviation is fixed.

The current package declares macOS 14 and an executable UI using SwiftUI/AppKit. There is no current iOS target or support claim. See [Package.swift](../../Package.swift).

Stable `UX-xxx` IDs identify the sections below for implementation, tests, and design review. Keep IDs stable when wording changes. Tests linked at the end cover domain/presentation helpers; they are not end-to-end screen tests.

<a id="ux-002"></a>

## UX-002 — Visual vocabulary and typography

Sources: [App.swift](../../Sources/Taskovsky/App.swift), [WorkspaceSymbols.swift](../../Sources/Taskovsky/WorkspaceSymbols.swift), [SettingsView.swift](../../Sources/Taskovsky/SettingsView.swift).

All explicitly configured UI type is the system font. Unspecified font, spacing, control size, or native chrome remains a framework default, not a hidden design token. Do not replace semantic fonts such as `.headline` or `.caption` with an asserted fixed size without runtime evidence.

| Role | Source setting |
| --- | --- |
| Workspace/Summary title | 20, bold, one line for workspace destination |
| Detail title | 20, semibold, vertically growing plain text field |
| Sidebar/row title, body editor, settings row | 14, regular |
| Quick-search field | 16, regular |
| Sidebar/group headings | 12, medium for sidebar; 12, semibold for task groups |
| Sidebar counts | 11, regular, monospaced digits |
| Task metadata | 10, regular, one line |
| Task body-preview / checklist-preview text | 13, regular |
| Detail section headings / progress | 11 semibold / 10 regular |
| Settings title / section title | 16 bold / 15 semibold for More subsections |
| Settings explanation | 12, regular |

| Token | Light appearance | Dark appearance / qualification |
| --- | --- | --- |
| App `accent` | `#5171F2` | Same literal |
| User-selectable list/tag palette | `#526BF5`, `#EC6574`, `#E7A548`, `#58A58B`, `#9C7BD5`, `#5BA7CC`, `#8A8F98` | Same user colors; not remapped through neutral palette |
| `Palette.card` | `#FAFAFA` | primary at 0.025 opacity |
| `Palette.bodyText` | `#191919` | primary |
| `Palette.values` | `#737373` | secondary |
| `Palette.explanatory` | `#A0A0A0` | secondary |
| `Palette.checkboxOutline` | `#C8C8C8` | secondary; helper token, not the actual settings checkbox stroke below |
| Task open/no-priority outline | `#9C9C9C` | secondary |
| Finished row title | `#A0A0A0` | `tertiaryLabelColor` |
| Rail background | RGB `(0.961, 0.961, 0.961)` | `windowBackgroundColor` |
| Main/sidebar/detail background | `textBackgroundColor` | adaptive native color |
| Selected row / hovered row | primary at 0.055 / 0.032 | Same opacity expressions |
| Icon hover | primary at 0.07, radius 8 | Same expression |
| Priority | High: semantic red; medium: `#F59E0B`; low: app accent; none: secondary | Semantic red/secondary are not fixed hex colors |

Some components explicitly use `Color.accentColor`, while others use the global `accent` or `.tint(accent)`. The source does not establish that every resolved accent pixel is identical across all native surfaces.

`TaskCheckbox` draws a 14 × 14 rounded rectangle, radius 2.5, one-point open stroke. Completed state uses primary at 0.12 with a white bold tick sized `size × 0.64`; Won't Do uses a secondary fill with a white bold x sized `size × 0.6`. It has a rectangular hit shape. Checklist previews use size 12. This is not an SF square glyph, and row titles are dimmed rather than struck through when complete.

<a id="ux-003"></a>

## UX-003 — Workspace, panel geometry, and transitions

Sources: [App.swift](../../Sources/Taskovsky/App.swift), [ResponsiveLayout.swift](../../Sources/TaskovskyCore/ResponsiveLayout.swift), [PanelDivider.swift](../../Sources/Taskovsky/PanelDivider.swift), [WindowFloor.swift](../../Sources/Taskovsky/WindowFloor.swift), [WindowChrome.swift](../../Sources/Taskovsky/WindowChrome.swift).

| Dimension | Current declaration |
| --- | --- |
| Main default window | 1280 × 740 |
| Main content floor | width 382; height 552 |
| Total-window height floor | 580, enforced by AppKit bridge using measured frame/content chrome |
| Rail | 62 fixed |
| Sidebar | default 215; clamped 160…320; saved preference |
| Center task pane minimum | 300 |
| Docked detail minimum | 280 |
| Detail drawer | 300 fixed, right aligned |
| Divider | 1 visible; 9-wide invisible hit region |
| Compact navigation panel | 220 wide; x 77 / y 56 within workspace; maximum height `max(200, contentHeight − 68)` |
| Pop-up detail default | 464 × 630 |
| Settings default and view minimum | 800 × 680 |

Layout rule: docked detail requires available center/detail width ≥ `300 + 1 + 280`. When the sidebar is manually expanded, available width is total content width minus rail 62, clamped sidebar width, and sidebar divider 1. With the default sidebar, detail docks at 859; at sidebar 160 it docks at 804; at sidebar 320 it docks at 964. Manual sidebar collapse or full Search makes the dock threshold 643.

Sidebar auto-collapse is a separate rule: hide it below `62 + sidebarWidth + 1 + 300`, which is 578 at the default width, 523 at the minimum, and 683 at the maximum. At exactly the threshold it remains docked. **Auto-hiding must not free space for re-docking detail while shrinking:** the detail decision uses the manual-collapse preference, not automatic sidebar visibility. These are implementation formulas, not measured TickTick thresholds.

A pristine layout gives detail 300 and center the remaining space. After customization, the persisted center fraction is used and clamped to both pane minima. The declaration initializes that fraction to 0.45, but the pristine path overrides its use. A zero-sized bridge updates the main window's minimum on attachment; only a restored frame approximately 382 × 608 gets the special correction to 382 × 580. Settings/pop-ups do not host that bridge.

Panel resizing:

- Pointer positions are absolute/global. Start position and size are captured once; live sizes are transient and save on release.
- Sidebar/dock decisions are frozen for sidebar drags. While detail is docked, sidebar growth also respects the dock-safe maximum.
- Dragging the sidebar's raw width below 135 collapses on release rather than saving an out-of-range width. Divider double-click toggles the sidebar. Cursor changes to left/right resize.
- Manual collapse retains expanded content width, slides it behind the rail, clips it, and removes hit testing/accessibility while hidden.
- At compact widths the toggle opens the floating navigation panel without changing the remembered manual preference. It has radius 10, primary 0.12 one-point outline, black 0.2 shadow/radius 14/y 4. It closes on navigation, outside click, Escape, toggle, or expansion back above the auto-collapse threshold.

Detail presentation:

- Wide: docked detail or placeholder always occupies its panel. No close x is shown.
- Narrow, Side peek: selecting a row opens the 300-point drawer, without a scrim or list reflow. Leading border is primary 0.08/1 point; black 0.18 shadow has radius 12 and x −4. Close x or blank list/header-space click hides it. Only an open drawer is rendered.
- Narrow, Pop-up: single click selects; double-click title or row opens a separate detail window. Inline rename is disabled on this narrow pop-up route. Wide detail still docks regardless of this choice.
- Shrinking from docked to overlay keeps selection but closes the drawer. It does not auto-open the drawer. Expanding re-docks the selected task. Schedule-popover visibility is canceled on docking-mode change; unsaved schedule state is not reconstructed.
- The pop-up uses the shared store and per-task draft object. Child/parent links swap its task in place. Closing it does not clear main selection. A missing record displays “This item is no longer available.”

Sidebar/manual drawer transitions use cubic timing `(0.4, 0, 0.2, 1)`, 0.22 seconds. Animation is disabled while panel dragging or Reduce Motion is on. Sidebar-section and task-group/list identity changes use 0.18-second ease-in-out, also respecting Reduce Motion. The workspace refreshes time-dependent presentation every 30 seconds.

<a id="ux-004"></a>

## UX-004 — Rail, navigation, and sidebar organization

Sources: [App.swift](../../Sources/Taskovsky/App.swift), [WorkspaceSymbols.swift](../../Sources/Taskovsky/WorkspaceSymbols.swift), [Settings.swift](../../Sources/TaskovskyCore/Settings.swift).

The rail contains **Tasks**, **Search**, and a bottom **Settings** control, not all reference-product modules. Its vertical stack spacing is 26 with top 12 and bottom 18 spacer elements. Each rail button occupies 38 × 38. Active Tasks is a 20 × 20 accent tile, radius 4.5, white bold 14-point `checkmark`. Search uses a 22-point `magnifyingglass`, 34 × 34 background/radius 8, accent fill at 0.12 when active. Settings is `gearshape` 22 with padding 8. Tasks routes to Today and closes the drawer; Search opens quick search.

Sidebar scroll content has horizontal 8 and top 12 padding. Organization order is: top smart destinations; divider; optional Pinned; Lists; optional Archived Lists; Filters; Tags; divider; bottom smart destinations. Dividers have vertical 16/horizontal 8 padding. Filters, Tags, and Archived headings have top 20 spacing. Section expansion persists. The Lists plus menu offers New List/New Folder; Filters/Tags plus actions open their editor. Add controls reveal on heading hover while retaining their layout slot.

Navigation rows are height 38, horizontal padding 10, radius 9, HStack spacing 10. Glyph slot is 20 wide, default glyph font 16; title is 14/one line; nonzero count is trailing 11 with monospaced digits. List/tag color is a 7-point dot after the title, rather than recoloring the leading glyph. Archived rows are opacity 0.75 with an 11-point `archivebox` marker. Full-row click, Return, Space, and accessibility action select the destination. Explicit focus effect is disabled.

| Destination | Glyph / label |
| --- | --- |
| All | `tray.full` |
| Today | Custom 16 × 16 calendar with current day number |
| Tomorrow | `sun.horizon` |
| Next 7 Days | Custom calendar with first two letters of current short weekday |
| Inbox | `tray` |
| Summary | `doc.plaintext` in workspace; `doc.text` in Settings |
| Completed | `checkmark.square` |
| Won't Do | `xmark.square` |
| Trash | `trash` |
| List | Stored symbol or emoji; fallback `line.3.horizontal` |
| Tag / Filter | `tag` / `line.3.horizontal.decrease` |

The calendar symbol has a radius-3 1.3-point outline, 1.1-point horizontal divider with top padding 4, and 7-point semibold text. `ListSymbol` renders text if the string is not a recognized SF Symbol; default font size is 16 with a `(size + 4)` square frame.

Fresh visibility defaults: All, Tomorrow, Summary hidden; Today, Next 7 Days, Inbox, Tags, Filters, Completed, Trash shown; Won't Do shown if nonempty. Top/bottom smart groups reorder separately. Smart context actions are Edit, Show if not empty, Hide. Edit opens/retargets Settings → Smart Lists. Hiding the active row chooses the first remaining visible smart destination, else Inbox. Summary never shows a count. The internal `Destination` enum also has Notes and Reminders, but the current sidebar construction exposes no corresponding standalone navigation row; do not claim dedicated Notes/Reminders tabs.

Folders are single-level disclosure containers, not task destinations. Folder rows use spacing 8, chevron 8 medium, folder glyph 14, title 14, count 11, height 38. Children indent 16. Ordinary folder counts show active member lists. Tag children use recursively applied `depth × 12` leading padding; an empty disclosure slot is 16 × 20, so effective nested indentation accumulates. Parent tag navigation includes descendant-tagged tasks.

Pinned shortcuts appear in Lists/Folders/Tags/Filters subgroups with 10-point semibold tertiary captions. Pins retain the normal navigation identity; pinned folders expand inline. Archived Lists are separate read-only destinations and refuse drops. The explanatory text directs users to unarchive before editing.

Context menus:

- List: Pin/Unpin; Edit; Duplicate; Move to Folder; Hide/Show in Smart Lists; Archive/Unarchive; Delete List. Delete keeps tasks by moving them to Inbox.
- Folder: Pin/Unpin; Add List; Rename; Ungroup. Ungroup keeps lists/tasks.
- Tag: Pin/Unpin; Edit; Add Sub-tag; Merge Tags; Delete Tag.
- Filter: Pin/Unpin; Edit; Delete Filter.

<a id="ux-005"></a>

## UX-005 — Task pane, quick entry, and list state

Sources: [App.swift](../../Sources/Taskovsky/App.swift), [QuickEntry.swift](../../Sources/Taskovsky/QuickEntry.swift).

Header: 58 high, horizontal padding 20, first-baseline HStack spacing 5. The sidebar control combines `line.3.horizontal` at 12 and `chevron.left` at 8 bold, spacing 1/padding 3. Sort is `arrow.up.arrow.down` at 15/padding 6. More is `ellipsis` at 15/padding 6. Actual lists additionally show a 130-wide List/Board segmented picker. Header controls use neutral hover treatment.

Sort choices are None, Date, Priority, Title, Created. The saved legacy string Manual normalizes to None. None follows stored array order within active/history buckets. Other sorts compute order rather than mutating dates or priorities. Active tasks precede completed/Won't Do. Date sorts due dates (reminder dates for the internal Reminders route), then priority, then creation direction from Default Add to. Title uses localized standard comparison; Created is newest first. Grouping remains date/status based except Priority grouping, None grouping, and special destinations.

Groups include Pinned, active manual tasks, Overdue, Today, Tomorrow, dated weekday/month/day, No Date, Note, Completed / Completed & Won't Do, Deleted, and internal reminder groups. Overdue can be placed near the bottom by preference. Parent/child rows nest only within the same group; children whose parent is filtered out remain visible at top level. Group headers have spacing 7, chevron 9 semibold, title 12 semibold, count 11 tertiary, vertical padding 10. Overdue/Due reminders are red. The list uses horizontal padding 16/bottom 24 and zero LazyVStack spacing.

“Show Completed & Won't Do” defaults to true in view state; task sort persists but this toggle and collapsed task groups do not use persistent storage. More contains Show/Hide Completed, Show/Hide Details, Show/Hide Checklist Items, and View Options. The last two display toggles persist. Turning checklist display on without matching checklist data shows “No matching checklist item.”

Quick entry appears below the header except in Trash, Completed, Won't Do, Summary, archived lists, and the separate Search pane. Outer padding is horizontal 20/bottom 16. The entry bar is height 38, internal horizontal padding 12/HStack spacing 8, radius 9/card background, one-point accent outline when focused. The native text field is 14, minimum width 60/height 22, no border/background/focus ring, tail truncation.

- Leading `plus` / `doc.text` at 16/padding 4 opens Task, Note, Add from Template.
- Return submits non-whitespace title; Shift-Return reveals a description field and focuses it. Description is 14, vertical 2…5 lines, padding 10/radius 6/primary 0.025. Add is disabled for an empty trimmed title. A focused nonempty collapsed entry shows “⇧↩ Add description” in tertiary 10.
- Recognized date text is native `systemBlue`; a calendar/date menu in app accent at 12 previews it and offers Ignore recognized date. Ignoring affects that submission, not the saved global preference.
- A final `#` token opens up to five tag matches plus a create option. Suggestions are 13, row padding 7, container padding 4, maximum width 260, regular material/radius 8, shadow black 0.12/radius 8/y 3, offset y 44. Multiword names insert a quoted token. Actual task/tag persistence occurs through submission.
- Successful creation clears title/body/recognition suppression and keeps quick-entry focus. Contextual date is today for Today/Next 7 Days, tomorrow for Tomorrow. List/type/default-tag/default-priority/recognition semantics come from the store. Tag destinations assign the selected tag. Creating a note in date-oriented smart destinations navigates to Inbox; a task that does not belong in the current ordinary destination can navigate to its actual list.

Empty rows view: centered 40-point ultralight `checkmark.circle` (or `trash`) in accent 0.5, spacing 12, 17 medium “All clear”/“Trash is empty”, 12 secondary explanation, flexible spacers. Today says “Enjoy the space. Add something for today.” Empty-space clicks close the drawer. Nonempty scroll views add measured blank filler below the rows for the same dismissal behavior.

View Options is width 472/padding 24, title 17 semibold, card radius 8/padding 16, two 140 × 114 silhouettes separated by 24. Options Side peek/Pop-up update the saved layout immediately; Done dismisses. This is not a transaction with Cancel.

<a id="ux-006"></a>

## UX-006 — Row composition and editing

Source: [TaskRow.swift](../../Sources/Taskovsky/TaskRow.swift).

The normal row is at least 40 high. Leading padding is `12 + min(max(depth, 0), 6) × 14`, trailing 7. Main HStack spacing is 4. A 14 × 20 grip slot is always reserved; task checkbox or note glyph occupies 18 × 20. The body-preview/checklist variant changes the main line from 40 to 24 high, uses outer vertical padding 8 and VStack spacing 4. A bottom one-point primary-0.045 separator is inset 40 leading/7 trailing.

Title is 14 regular, single-line, leading aligned, with hard clipping at its allotted width, **not ellipsis**. Metadata is measured first, pinned to the exact trailing edge, and receives at most `min(190, max(0, paneWidth − 32) × 0.48)`. A four-point gap separates it from the title. It progressively falls back from all metadata → no tag → due only → calendar icon → zero width. Long list/tag text separately truncates at 70/96 widths. These are source layout rules; glyph-edge clipping has not been visually checked here.

Metadata order: contextual list, body `doc.plaintext`, checklist done/total, subtask `list.bullet.indent` plus done/total, first matching tag, `repeat`, `bell`, due label. It uses spacing 6/font 10. List context is omitted for Inbox or the task's own selected list. The first body line is a 13-point secondary, tail-truncated preview; optional checklist rows use spacing 5 and 12-point boxes with 13-point titles. Both sections indent 20 from their containing row content.

Due labels use the task's zone: Yesterday/Today/Tomorrow or localized day/month. Timed tasks due today show time only in the row. Only dates before the start of the current day become red; same-day lateness is not red. Other active due text is accent; finished metadata is tertiary. A due reminder bell is orange. Details append a nonlocal time-zone abbreviation where applicable.

Interactions:

- Single click selects. Checkbox/checklist clicks avoid selecting the row by consuming only that click.
- Double-click title starts inline rename unless the narrow Pop-up route owns double-click. Return or focus loss commits a changed nonempty trimmed value; Escape exits without saving the draft. An accessibility Rename action follows the same permission checks.
- Trash disables completion and rename. Archived list rows also disable checklist edits and drag while retaining selection. Archived context menus retain an explicit Move to Inbox/active-list escape hatch.
- Active task menu offers completion/reopen, Won't Do, pin (only active), priority, move, duplicate, save template, add subtask, make subtask of a valid same-list parent, move to top level, and trash. Notes omit completion/subtask actions. Trash menus offer Restore/Delete Forever.

<a id="ux-007"></a>

## UX-007 — Drag feedback and board mode

Sources: [DragReorder.swift](../../Sources/Taskovsky/DragReorder.swift), [DragPayloads.swift](../../Sources/TaskovskyCore/DragPayloads.swift), [App.swift](../../Sources/Taskovsky/App.swift), [BoardProjection.swift](../../Sources/TaskovskyCore/BoardProjection.swift).

Task row drag starts only from the reserved grip, not the whole title/row. Six 3-point dots form two columns and three rows with three-point spacing in a 14 × 20 frame; opacity reveals them on whole-row hover or selection. The drag preview uses 13-point single-line title, optional count 11 semibold in an accent capsule, padding 10 horizontal/6 vertical, radius 8, black 0.2 shadow/radius 8/y 2, max width 260. The task insertion line is accent/2 high/radius 1, horizontal inset 10, overlaid at a row half's edge without layout changes.

None-sort drops reorder within the same visible group. Cross-group/self/invalid drops do not reorder; crossing Pinned explains the boundary. Other sorts reject with a notice rather than rewriting computed sort fields. Inbox and active list rows accept task moves under any sort. Typed task payloads are process-local, not generic file/text drops.

Sidebar lists/folders/tags/smart rows use a separate in-app drag session, start threshold 8, shared by docked and compact navigation. Sidebar insertion markers are a 2-point line with an 8-point hollow leading ring/stroke 1.5, leading inset 28/trailing 10, centered at row edges with ±4 offsets. Whole-row assignment highlights use accent 0.15. The Lists heading is a top-root target; its highlight is accent 0.12/radius 7. The expanded Lists section ends with a visually empty 14-high trailing-root target, with marker inset 10 on hover. Folder targets work when collapsed. Filters are not drag destinations.

The sidebar floating preview mirrors source width (minimum 80), height 38, radius 9, adaptive opaque background plus accent 0.12 tint, assembled opacity 0.7, black 0.22 shadow/radius 10/y 3; its center follows pointer offsets x +14/y −24. It is not interactive or accessible. Escape and window key-loss cancel the session. Domain drag policy validates type, target, hierarchy, ordering scope, and the entire decoded batch before corresponding store operations. Native task-drop decoding and sidebar-engine gestures are distinct mechanisms, not interchangeable implementations.

Board is available only for a concrete list and is saved on that list. Fixed columns are Open, Completed, Won't Do; no custom sections or column editing. Projection includes every nondeleted status independently of Show Completed, so completed drops stay visible. Notes created/converted through the normal UI are open, and terminal-column drops for notes are refused. The board projection itself groups stored completed/Won't Do flags without a kind check; it does not normalize note records. Hierarchy is flat.

- Horizontal scroll hides its indicator. Columns have spacing 12, container horizontal 16/bottom 24 padding.
- Each column is 250 wide, padding 8, VStack spacing 8, radius 10/primary 0.03 background. Drop highlight uses `accentColor` 0.08 with 0.4 one-point outline. Header is 12 semibold/11 count with vertical padding 6.
- Cards have padding 8, radius 8, one-point primary-0.09 outline, native text background or selected primary 0.055. Title is 13/up to three lines. Checkbox slot is 16 × 16; note glyph is `doc.text`. Due/repeat line is 10, secondary. Entire active card is a drag source.
- Dropping on status columns invokes existing complete/reopen/Won't Do actions; recurring completion can produce a successor. Notes refuse finished columns with an explanatory notice. Foreign IDs outside the current board are ignored. Archived boards permit selection only and reject edits/drops.

<a id="ux-008"></a>

## UX-008 — Detail, drafts, hierarchy, and reminders

Sources: [TaskDetail.swift](../../Sources/Taskovsky/TaskDetail.swift), [DetailState.swift](../../Sources/TaskovskyCore/DetailState.swift).

Detail is a header, divider, optional locked-state banner, outer scroll view, divider, fixed footer. Header is 58 high (standalone pop-up: 52), horizontal padding 24 (compact: 16), HStack spacing 15 (compact: 8). Drawer-only x is 14 medium/padding 4. Task completion is followed by a 20-high divider. Schedule uses `calendar`, 12-point date text, optional repeat 11, padding 4, gap 6 (compact 4). Priority uses `flag`/`flag.fill` at 16/padding 4. No-priority scheduling text is secondary, dated text accent or overdue red.

Content padding: horizontal 24/top 20/bottom 24; VStack spacing 14; trailing spacer minimum 40. Title edits and body edits save immediately through bindings. There is no whole-detail Save/Cancel transaction. A completion timestamp or Won't Do label appears below title in caption style. The placeholder for unselected detail is a bottom-trailing ultralight `list.bullet.rectangle`, size `min(260, panelWidth × 0.6)`, rotation −16°, primary 0.035, x 20/y 15 offset and padding 24.

Drafts for new checklist item, new subtask, tag name, and tag/template/schedule presentation flags are keyed by task ID and shared across detail surfaces. They are in-memory drafts, not promised across relaunch. Schedule content is locally staged and does not survive presentation reconstruction merely because a visibility flag exists.

Trash banner says “This item is in Trash.” with Restore, padding 14/orange 0.07. Archived banner says the list is read-only, padding 14/primary 0.05. Locked detail disables metadata/title/checklist/subtask mutations; hides formatting/add controls; rich body remains selectable. Reminders are hidden in archived detail.

The first reminder appears in an 11-point row with `bell`, day/time, optional total-reminder count, spacing 8/padding 10/radius 6/primary 0.03. Due reminders are orange and expose snooze choices 10 minutes, 1 hour, Tomorrow. Snooze removes the first reminder and appends its replacement. The x dismisses all reminders. This is in-app presentation; there is no implemented notification authorization UI, OS notification delivery, or background reminder service.

Tags are 11-point `#name` colored capsules with horizontal 8/vertical 5 padding and color 0.08 background. Clicking removes an unlocked tag. A 12-point `number` button opens a 300-wide/padding-24 tag picker, native checkboxes, recursive hierarchy, new-tag field, and Create & add. Recursive leading padding is `depth × 16` at each nested view. These are fixed horizontal stacks, not a documented wrapping layout.

Checklist and subtasks are distinct:

- Checklist is embedded data on the current task. Rows use spacing 10, 14-point plain text fields (struck through when checked), checkbox, and 11-point tertiary `minus.circle`. Add Checklist Item submits with Return and retains focus; nonempty text reveals a return button.
- Subtasks are linked full task records with their own status/schedule. Parent breadcrumb uses `arrow.turn.up.right`, “Subtask of”, linked title, optional Change and Remove; child titles navigate in the current host. Child completion calls the store directly. Add Subtask is another focused Return field. Do not promise the shared toast/sound for every child toggle: that path does not call `TaskActionCenter`.
- Section headings are 11 semibold/secondary; progress is 10 tertiary. Subtask-title completion uses strikethrough for completed children, unlike ordinary row titles.

Footer has horizontal 24/vertical 14 padding. A 12-point `tray` menu moves to Inbox or active list. Trailing `ellipsis` is 17/padding 4, with leading padding 12. More includes creation time, Won't Do/reopen, active pin, templates, duplicate, task/note conversion, and trash. Conversion clears completed/Won't Do status. Locked detail changes to archived explanation or restore/permanent-delete actions.

<a id="ux-009"></a>

## UX-009 — Rich body editor baseline

Sources: [RichBodyEditor.swift](../../Sources/Taskovsky/RichBodyEditor.swift), [RichTextRender.swift](../../Sources/TaskovskyCore/RichTextRender.swift), [ListDecorations.swift](../../Sources/TaskovskyCore/ListDecorations.swift), [ListLayoutManager.swift](../../Sources/TaskovskyCore/ListLayoutManager.swift). Proposed independent ownership/test seams are in [components.md](../architecture/components.md).

This is an AppKit `NSTextView` with rich text on, graphics import off, undo on, transparent background, no automatic quote substitution, vertical growth, no horizontal resize, container width tracking, and text-container inset `(0, 4)`. The detail's outer scroll view scrolls; the editor reports its height rather than supplying a nested scroller. Minimum height is 60 for tasks/120 for notes. Empty unfocused editable body offers “Write something” and “use a template” at 14, top padding 4/leading 1.

Rendering tokens:

- Body: system 14 / native label color. Heading 1…6: 20, 18, 17, 16, 15, 14 semibold. These are Taskovsky choices, not established reference-app measurements.
- Inline code: monospaced system at `max(11, currentFontSize − 1)`, preserving supported bold/italic traits. Code wash is native quaternary-label color at 0.35; highlight is native system yellow at 0.28.
- List first/wrapped lines reserve 24 points; quote indent is 16 with a two-point bar. Bullets/numbers/checks/quote gutters are drawn decorations, not literal prefixes stored in body text. Numbering restarts after a nonnumbered paragraph. Horizontal rules are marked empty paragraphs with paragraph spacing 6 before and after.

Toolbar horizontally scrolls, hides indicators, uses spacing 2/vertical padding 2. Standard tool glyphs are 13 in 26 × 24 frames, radius 5 active background at `accentColor` 0.16; active foreground accent, inactive secondary. Dividers are 16 high. Heading is 12 semibold. Disabled toolbar opacity is 0.5, although locked detail omits the toolbar entirely.

Ordered tools: `bold` (⌘B), `italic` (⌘I), `underline` (⌘U), `strikethrough`; heading None/H1…H6; `link`; `highlighter`; `chevron.left.forwardslash.chevron.right` (inline code); `text.quote`; `list.bullet`; `list.number`; `checklist` menu (Checklist / Mark Checked / Mark Unchecked); `eraser` (clear formatting); `minus` (horizontal rule). Link popover is width 300/padding 14/spacing 10; URL field width 260; Remove when applicable, Cancel, Apply disabled for empty trimmed URL.

Edits commit the plain body and mirrored rich metadata together. Styling is optional; plain body remains the input for search/snippets/summary/previews. Selection changes refresh tool state. Empty documents/trailing empty paragraphs can hold pending formatting for next input. Return in empty list/heading/quote blocks follows block-exit logic; ordinary Return continues supported lists. Pasted attributes normalize to the supported render/extract mapping, not arbitrary HTML or attachments.

The editor owns document-scoped undo. Switching task IDs, even with identical text, resets that editor's history and pending state; it does not clear title-field/window history. External body replacement rebuilds text storage and invalidates stale undo. Normal keystrokes avoid rebuilding storage and disturbing the caret. These mechanisms are code-derived, not evidence of all native text-input paths having been exercised.

**Deviations:** the review records block selection ending at the next paragraph boundary affecting an extra paragraph, and quote formatting failing to toggle off in an empty editor. Preserve those as open deviations, not desired contract or accepted cross-platform behavior.

<a id="ux-010"></a>

## UX-010 — Schedule transaction, calendar, and custom recurrence

Sources: [ScheduleEditor.swift](../../Sources/Taskovsky/ScheduleEditor.swift), [CalendarGrid.swift](../../Sources/Taskovsky/CalendarGrid.swift), [CustomRecurrenceEditor.swift](../../Sources/Taskovsky/CustomRecurrenceEditor.swift), [ScheduleDraft.swift](../../Sources/TaskovskyCore/ScheduleDraft.swift).

Schedule popover: width 300, padding 14, VStack spacing 8, native text background. Top shortcut icons evenly share width and height 30: `sun.max` Today, `sun.horizon` Tomorrow, `calendar.badge.clock` Next week, `moon.stars` This evening, `calendar.badge.minus` No date. Next week chooses the next configured week boundary, not simply seven elapsed days; This evening chooses 18:00. No date stages removal; Clear commits removal and dismisses immediately.

Calendar grid: width 234 (260 with week numbers), padding 10, six weeks always, row/day spacing 2, VStack spacing 5. Month header is 13 semibold with chevron navigation, horizontal padding 5/bottom 3. Weekday labels are 11 medium in 28 × 22; week number slot 24 × 26/font 10. Day text is 12 in 28 × 26. Selection uses white text on a 25-point accent circle; future occurrences use accent 0.15 circles; today, when not selected, has a one-point accent ring. Adjacent-month text is secondary. Day accessibility labels contain full localized weekday/day/month/year and selected trait. Selection preserves current time components.

Expandable rows are 12, vertical padding 5, 18-wide icon, trailing one-line secondary value/9-point chevron: Time (`clock`), Reminder (`bell`), Duration (`hourglass`), Repeat (`repeat`), and conditional End (`calendar.badge.clock`). Only one expanded row is tracked. Time/date-dependent rows disable when no date.

- Time supports add/remove time and native time picker; a zone picker appears only when time is enabled and the Time Zone setting is on.
- Reminder supports multiple explicit date/time entries with minus buttons and Add reminder. Manual edits stop automatic following. Defaults follow staged effective due date/time until manually overridden.
- Duration stages timed/all-day start and end; invalid range shows orange “End must not precede start.” and disables OK. The due date is the range end, not the start. Day changes translate the range; zone changes preserve intended wall-clock components through `ScheduleDraft`.
- Repeat supports simple none/daily/weekdays/weekly/monthly/yearly or a valid custom rule. A valid custom rule supersedes the simple choice. The custom preview and count are displayed; changing only date does not reset custom occurrence index.
- Legacy simple recurrence End offers Endlessly/Until date. Clear removes due/time/zone/reminders/repeat/custom rule/end/anchors/duration and resets occurrence index.

Outer OK commits and dismisses; Escape/outside dismissal does not invoke save. This does **not** imply every nested Cancel path is correct: opening Custom currently preassigns a weekly draft and the existing review identifies Cancel → outer OK persisting it. That remains a deviation.

Custom Repeat sheet is width 380/padding 16/VStack spacing 10, native headline. It has due-date/completion-date anchor, day/week/month/year unit, interval Stepper 1…999 (width 120/font 11), weekday buttons 34 × 24/font 11/radius 5/accent 0.18 selected, monthly Each/On the/Workday, yearly month/day/ordinal, weekend roll, explicit dates, date/count endings, and up to six preview occurrences. Ordinal controls are widths 110/130; year month/day fields 150 each. Specific-date input includes date/time. Count UI starts at 2 and allows up to 999,999; existing initialization clamps the initial displayed count to 999. Clear Rule returns nil; Cancel dismisses; Done returns a valid draft and is disabled otherwise. The invalid-state copy is always “Pick at least one weekday for a weekly rule.” even when another validation cause exists; do not describe it as a precise per-error explanation.

The recurrence/reminder deviations concerning all-day descendant reminder shifts and month-end weekend cadence remain tracked in the review. Date previews here are not a guarantee those engine paths are corrected.

<a id="ux-011"></a>

## UX-011 — Search and saved filters

Sources: [SearchView.swift](../../Sources/Taskovsky/SearchView.swift), [FilterEditor.swift](../../Sources/Taskovsky/FilterEditor.swift).

Quick-search sheet is 550 × 420. Header is padding 18, spacing 10, 16-point plain field, magnifying glass, conditional clear x, close x/Escape. Body has padding 18/VStack spacing 16 and group spacing 4. Empty query shows Recent Searches plus Clear. Recent terms are case-insensitively deduplicated, newest first, max ten, saved in standard UserDefaults. Query edits clear keyboard selection.

Results are grouped Tasks (first five), Lists/Tags/Filters (first eight each). Tasks exclude deleted records but otherwise use `TaskSearch`; matching titles and snippets highlight case/diacritic-insensitive substrings with yellow 0.35/primary text. Snippets choose the first matching body/checklist text and include up to 45 preceding/70 following characters, flattening newlines. Task title is 14/one line; snippet 12/up to two lines; contextual list/date are 12. Result row vertical padding 6 and hover primary 0.032/radius 9. Selected quick result uses primary 0.08/radius 5. Completion is a separate button from opening.

Up/Down move a bounded selection and scroll it into view. Return opens selection; without selection it opens full results. View more also opens full results. Recent-term selection fills the query. The footer says “Press Return to see all results.” Closing dismisses; full search close routes to Inbox.

Full Search replaces center content and hides the docked sidebar. Selected results open detail without removing query/results. It has padding 28; 20-bold heading or editable rounded search field (max 350); close, pencil and Save as Filter (disabled for empty trimmed query). Criteria row scrolls horizontally, spacing 18: dates, lists including Inbox, tags with Any/All/No Tags/Any Tag, task/note kinds, status. Custom range adds From/To enabled date bounds and an explanatory prompt if neither is set. Results use vertical padding 20/spacing 4. “No results found” has top padding 50. It uses saved-filter eligibility, unlike the quick dialog's broader nondeleted task lookup.

Filter editor: width 520/padding 24/spacing 16, title 18 bold, name field, Normal/Advanced segments. Normal grouped form is height 300: keyword, multi-list/tag/priority/date/type, status, inclusive custom range. Missing referenced lists/tags stay selected as Unavailable rather than being silently removed. Saving a name-only edit must not broaden dead-reference intent.

Advanced scroll height is 340 with nested AND/OR/NOT/conditions. Nodes use padding 10/radius 8/primary 0.03; child indent 12 with two-point secondary-0.25 guide; node label 13 semibold/chevron 9. Conversion preserves conditions; empty AND and OR groups explicitly match everything; removing a NOT child removes the wrapper. UI group addition is depth-limited and existing stored trees can be deeper. Save requires a nonempty name and advanced root; normal custom dates require at least one bound. Cancel dismisses without writing. Save as Filter carries the full current query/criteria into its draft.

<a id="ux-012"></a>

## UX-012 — Entity dialogs, templates, settings, and summary

Sources: [TaskDetail.swift](../../Sources/Taskovsky/TaskDetail.swift), [TemplatePicker.swift](../../Sources/Taskovsky/TemplatePicker.swift), [SettingsView.swift](../../Sources/Taskovsky/SettingsView.swift), [ReferenceValueMenu.swift](../../Sources/Taskovsky/ReferenceValueMenu.swift), [SummaryView.swift](../../Sources/Taskovsky/SummaryView.swift).

| Surface | Current layout and interaction |
| --- | --- |
| New/Edit List or Tag | Width 360/padding 28/spacing 22; title 20 semibold; rounded name field initially focused; palette circles 24 with 11-bold white selected tick, gap 12. Save/Create disabled for empty trimmed name; Return submits, Escape cancels. |
| List-specific fields | Nine 27 × 27 SF-symbol choices (`line.3.horizontal`, `house`, `briefcase`, `book`, `star`, `cart`, `heart`, `folder`, `list.bullet`), gap 8, selected accent 0.16/radius 5; custom emoji input takes first Character; Tasks/Notes default, folder, smart-list inclusion, List/Board. |
| Tag-specific field | Parent picker excludes self/descendants; edits use cycle-safe store operation. |
| New/Rename Folder | Width 320/padding 28/spacing 18; title 20 semibold; name only, initially focused; Cancel/Save. |
| Merge Tags | Width 420/padding 24/spacing 16; title 18 bold; source description; distinct indented target choices; explains reference/default/child rewrites; Merge disabled until selected; Cancel leaves unchanged. |
| Template gallery | 600 × 420/padding 24/spacing 16; title 16 bold; three flexible columns min 160/gap 12; card min height 170/padding 14/radius 8/primary 0.035; 14 semibold name, first five checklist titles or four-line 12-point description/title; Use Template and Close. |
| Template editor | Width 480/padding 24/spacing 14; title 18 bold; template name/task title; plain description and line-per-checklist TextEditors each height 90 with secondary-0.25 border; priority; Cancel/Save. Save requires name and title. Body styling is retained only if body is unchanged; edited plain body clears it. This is not the rich body editor. |

Settings uses native hidden/transparent title chrome, left navigation width 220, horizontal 16/top 32 padding, 16-bold Settings label with bottom 24. Four sections: Smart Lists, Date & Time, More, About. Navigation rows are 14, spacing 12, icon width 20, horizontal 12/vertical 10, selected primary 0.08/radius 7. Content scroll has horizontal 40/vertical 32, section spacing 24. Cards are radius 8, generally zero row spacing. Standard rows are 14/min height 40/horizontal 18, with spacer minimum 16; explanatory rows 12, bottom 10. Checkbox rows are 13/min height 44.

- Smart Lists mirrors effective saved ordering in top/sections/bottom groups, group spacing 20, and offers Hidden / Show / Show if not empty for each.
- Date & Time: week start, week numbers, Time Zone.
- More: date recognition/removal, tag-text removal, URL parsing; default date, multiple timed/all-day reminders, priority/tag/list/duration, add position/overdue position; Reset Default; template cards and New Template. These settings update as bound; there is no global Save. Completion sound exists in settings data and action logic, but this view does not expose a sound toggle.
- About says Taskovsky Pre-Alpha and “A quiet place for your tasks.” in a padded card.
- Flat switch is 26 × 16/radius 8 with 14 white knob/padding 1, accent on / `#D9D9D9` off (dark: separator), black 0.2 shadow with radius 1/y 1. Toggle animation is 0.12 ease-out unless Reduce Motion. Flat checkbox is 14 × 14/radius 2.5, accent/white 9-bold tick on; `#CCCCCC` one-point outline off (dark: secondary). Both expose native Toggle accessibility representations.
- Value menus show 8-point up/down chevrons, spacing 6, trailing max width 190. Their popover rows are 14 with horizontal 12/vertical 8, checkmark gap 20; highlighted row primary 0.05/radius 4; container padding 5. Up/Down/Return/Escape are implemented. Reminder-default menus stage multiple selections with Cancel/OK instead of immediate commit.

Summary is a separate full center surface, not the `Destination.summary` seven-day count predicate. Its actual report defaults to This Week and includes tasks selected by due/completed/Won't Do timestamps in the chosen interval. Header is 58 high/horizontal 24, title 20 bold, regenerate icon. At content width ≥650 the options rail is 220 wide plus divider; below 650 Filter opens a 250-wide/padding-16 popover. Report uses editable 14-point plain TextEditor/padding 16; footer padding 14 with Save as Note and Copy. Options use spacing 14/font 12, headings 14 semibold, range 11.

Summary supports This Week/Last Week/This Month/Today/Custom; list/status selection; grouping by status/list/date; Date/List/Description/Tags/Priority fields; next-period tasks. Changing any option regenerates and replaces local report edits; edits are not a durable saved report until Save as Note. Save creates an undated Inbox note with no reminders/tags/priority and displays “Saved as note”; Copy uses the native pasteboard. Archived/excluded lists are omitted unless explicitly selected. This is local plain-text generation, not AI summarization or account sync.

<a id="ux-013"></a>

## UX-013 — Feedback, destructive actions, errors, and shortcuts

Source: [PanelDivider.swift](../../Sources/Taskovsky/PanelDivider.swift), [App.swift](../../Sources/Taskovsky/App.swift).

`TaskActionCenter` is shared across main window, drawer, pop-up, and search. Completing an open task can play bundled completion.wav (fallback native Glass) when `completionSound` is true, then show “Task completed.” Trash shows “Task deleted.” Restore shows `Restored to "<list>"` (Inbox fallback). Notices have no extra action. Won't Do currently calls the store without a toast, despite the feedback type having a Won't Do case.

Toast is bottom centered with bottom padding 60, HStack spacing 14, white 14-medium text, orange 16-semibold Undo arrow or restore navigation chevron. Container padding 16 horizontal/12 vertical, white value 0.15 background, radius 9, shadow black 0.2/radius 12/y 4. It transitions bottom-move + opacity with 0.15 ease-out unless Reduce Motion. There is one shared five-second slot; the next feedback replaces the previous, expiry clears it, and Undo consumes once. Restore navigates to the original list; it is not a restore-Undo button.

Permanent deletion is an individual-item Delete Forever alert naming the item and stating that it cannot be undone, with destructive Delete Forever and Cancel. There is no bulk Empty Trash surface. Recoverable trash and ordinary entity deletion are distinct operations; do not present all deletion as permanent.

A storage error overlays the bottom as a caption row with filled warning triangle, padding 12, red-0.12 rounded background/radius 10 and outer padding. Retry calls save when recovery is unnecessary; otherwise Recover opens “Recover workspace?” with Cancel / Back up and recover and an explanation of the backup/new workspace. Runtime visibility or overlap between this banner and a toast has not been verified.

| Shortcut / input | Action |
| --- | --- |
| ⌘N | Focus new task; redirect history/search/summary creation to Inbox |
| ⇧⌘N | Focus new note; route unsuitable smart destinations to Inbox |
| ⇧⌘L | New List |
| ⌘F | Quick Search |
| ⌥⌘S | Toggle sidebar / compact navigation |
| ⌘, | Native Settings scene |
| Return in quick entry/checklist/subtask | Submit that item |
| Shift-Return in quick entry | Expand description |
| Escape in staging dialogs/popovers | Dismiss where implemented; nested recurrence deviation still applies |
| ⌘B / ⌘I / ⌘U | Rich-editor formatting toolbar actions |

Debug-only window commands exist in source but are not production feature requirements. Native system undo/redo behavior belongs to the active editor and is separate from the five-second action toast.

<a id="ux-014"></a>

## UX-014 — Accessibility baseline and open validation gaps

Implemented source affordances include labels/help on major icon controls, complete/reopen labels with task titles, calendar full-date labels and selected trait, sidebar/folder Return/Space/AX activation, explicit checkbox hit shapes, native Toggle accessibility representations, hidden offscreen sidebar/drag-preview accessibility, scrollable rich toolbar, and Reduce Motion-aware explicit animations.

These are **not** a conformance claim. Review/validation gaps to carry into later UI work:

1. Small macOS controls (14-point checkboxes, 14 × 20 drag grip, 26 × 24 toolbar tools) have varied hit regions. Pointer usability and keyboard-only alternatives need runtime checking. The accessible “Reorder” grip action selects/explains; it does not supply a keyboard reorder command.
2. Many controls have help text but not explicit labels/selected/value traits. Verify VoiceOver announcements for status, tags, heading/checklist mode, template icons, and nested structures. SF-symbol fallback names are not guaranteed to be meaningful spoken names.
3. Sidebar focus effects are explicitly disabled. Verify visible keyboard focus and predictable focus restoration after dismissing sheets, changing detail presentation, or navigating parent/child tasks.
4. Fixed typography, one-line clipped titles, narrow cards, fixed dialog widths/heights, horizontal tag stacks, and recursively accumulated indentation need large-text, long-name, localization, and RTL checks. No Dynamic Type implementation is established by this macOS source.
5. Literal pale/gray text, color-coded priorities and tags, completion fill/white ticks, and overlays need measured light/dark/Increase Contrast checks. No numeric contrast compliance is claimed.
6. Toast timing/announcements and error banners need screen-reader and slow-interaction checks. The source uses a five-second timer; there is no documented persistent action history or adjustable timeout UI.
7. Custom drawing of rich list markers/quotes/rules does not itself prove accessible list structure. Inspect native text selection, IME, keyboard, dictation, pasted Unicode, and VoiceOver navigation separately.
8. Explicit animations respect Reduce Motion where coded, but native popover/sheet/hover behavior remains OS-controlled. Do not infer reduced motion coverage from one environment flag.

<a id="ux-015"></a>

## UX-015 — Evidence and verification map

All cases below are **to be executed on a suitable macOS environment**, not passed by this documentation change. Use isolated fixture storage for future manual runs as documented in the repository; do not seed or mutate a real user workspace just to inspect UI.

| UX coverage | Existing test evidence | Required later runtime checks |
| --- | --- | --- |
| UX-003, UX-008 | [ResponsiveLayoutTests](../../Tests/TaskovskyCoreTests/ResponsiveLayoutTests.swift), [ResponsiveCollapseTests](../../Tests/TaskovskyCoreTests/ResponsiveCollapseTests.swift), [DetailStateTests](../../Tests/TaskovskyCoreTests/DetailStateTests.swift) | 382 × 580 floor; threshold equality; resize in both directions; manual collapse and compact overlay; drawer/pop-up draft/focus behavior |
| UX-004, UX-007 | [SidebarDragEngineTests](../../Tests/TaskovskyCoreTests/SidebarDragEngineTests.swift), [SidebarDragPolicyTests](../../Tests/TaskovskyCoreTests/SidebarDragPolicyTests.swift), [FoldersSmartOrderTests](../../Tests/TaskovskyCoreTests/FoldersSmartOrderTests.swift), [ReorderTests](../../Tests/TaskovskyCoreTests/ReorderTests.swift), [DragBatchTests](../../Tests/TaskovskyCoreTests/DragBatchTests.swift) | Native drag initiation, edge feedback, cancellation, no click/rename interference, compact/docked scope, keyboard alternatives |
| UX-005, UX-006 | [EntryAndListTests](../../Tests/TaskovskyCoreTests/EntryAndListTests.swift), [DetailStateTests](../../Tests/TaskovskyCoreTests/DetailStateTests.swift), [RichTextPinTests](../../Tests/TaskovskyCoreTests/RichTextPinTests.swift) | Focus/Return/Shift-Return, recognition and tag popover, long title hard clipping and metadata fallbacks, preview/checklist row height |
| UX-007 | [BoardProjectionTests](../../Tests/TaskovskyCoreTests/BoardProjectionTests.swift), [BoardIsolationGateTests](../../Tests/TaskovskyCoreTests/BoardIsolationGateTests.swift) | Board status drops, note refusal, completed-only list, archived interactions, same-list saved view mode |
| UX-008, UX-013 | [TaskHierarchyTests](../../Tests/TaskovskyCoreTests/TaskHierarchyTests.swift), [HierarchyLifecycleTests](../../Tests/TaskovskyCoreTests/HierarchyLifecycleTests.swift), [TrashTests](../../Tests/TaskovskyCoreTests/TrashTests.swift) | Child navigation, read-only archive/trash surfaces, exact action-specific feedback, restore navigation, purge confirmation |
| UX-009 | [RichRenderTests](../../Tests/TaskovskyCoreTests/RichRenderTests.swift), [RichEditorSizingTests](../../Tests/TaskovskyCoreTests/RichEditorSizingTests.swift), [BlockCoherenceTests](../../Tests/TaskovskyCoreTests/BlockCoherenceTests.swift), [ListDecorationsTests](../../Tests/TaskovskyCoreTests/ListDecorationsTests.swift), [ListContinuationTests](../../Tests/TaskovskyCoreTests/ListContinuationTests.swift), [PendingListArmTests](../../Tests/TaskovskyCoreTests/PendingListArmTests.swift), [ReturnExitTests](../../Tests/TaskovskyCoreTests/ReturnExitTests.swift) | All formatting selection boundaries, same-body document switch/undo, empty/trailing paragraph, wrapping/list painting, paste/IME, narrow toolbar reachability; review deviations remain |
| UX-010 | [ScheduleDraftTests](../../Tests/TaskovskyCoreTests/ScheduleDraftTests.swift), [TaskZoneDurationTests](../../Tests/TaskovskyCoreTests/TaskZoneDurationTests.swift), [CustomRecurrenceTests](../../Tests/TaskovskyCoreTests/CustomRecurrenceTests.swift), [RecurrenceIntegrationTests](../../Tests/TaskovskyCoreTests/RecurrenceIntegrationTests.swift), [ReminderTests](../../Tests/TaskovskyCoreTests/ReminderTests.swift) | Cancel/OK/Clear including nested cancellation, invalid ranges, timezone/DST and preview correctness; review deviations remain |
| UX-011, UX-012 | [FilterIntentTests](../../Tests/TaskovskyCoreTests/FilterIntentTests.swift), [FilterHardeningTests](../../Tests/TaskovskyCoreTests/FilterHardeningTests.swift), [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift), [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift) | Quick/full search eligibility difference, keyboard navigation, unavailable references, template edits, summary regeneration, settings persistence |

No exact test count, test-pass status, pixel-perfect match, native drag verification, or accessibility certification is asserted here. Existing reference observations under `docs/ticktick-spec/` remain historical comparison material, not authority for unimplemented screens.


<a id="ux-016"></a>

## UX-016 — Component state coverage

This matrix describes source branches, not runtime results. “Native” means the framework supplies behavior; it is not a claim that focus/hover/disabled appearance has been verified. The verification map in UX-015 names the associated evidence and outstanding checks.

| Component | Normal / interaction | Empty / disabled / special state | Verification focus |
| --- | --- | --- | --- |
| Workspace/rail/sidebar | Destination selection, row/icon hover, keyboard activation, resize/collapse | Hidden sidebar removed from hit/AX scope; compact overlay; missing selection placeholder | Thresholds, focus restoration, narrow layout, source/live widths |
| Task row/checkbox | Select, complete, rename, metadata fallbacks, optional previews | Note icon; complete/Won't Do dimming; archive/trash lock; empty title fallback | Independent click targets, clipping, metadata priority, rename cancellation |
| Quick entry | Native focus, recognition, tag suggestions, Return/Shift-Return | Empty submission refused; description collapsed/expanded; no entry in history/archive | IME/focus, contextual creation, dismissal and recognition override |
| Drag/board | Grip/task and sidebar-engine paths; edge or whole-row highlights; card status drops | Invalid/cross-scope/archived rejection; sorted-mode notice; empty board columns | Pointer arbitration, cancellation, batch policy, existing status flags |
| Detail/drafts | Immediate title/body writes; per-task add-item/tag drafts; child navigation | No selected task; unavailable record; read-only archive/trash | Draft retention versus schedule cancellation, lock behavior, scroll/focus |
| Rich body/toolbar | Selection/format state; native text input; document undo; height growth | Empty placeholder/pending formatting; styled body; locked selectable view | UTF-16, block boundaries, empty quote deviation, identical-body document switch |
| Schedule/calendar/recurrence | Staged draft, expanded row, selected/today/occurrence day, nested editor | No date; invalid duration/rule; custom/simple choice; disabled Done | Cancel/Clear/OK paths, accurate validation copy, known recurrence deviations |
| Quick/full search | Query focus, keyboard result selection, criteria, highlighted matches | Recents/no results; cleared query; no selectable result; Save Filter disabled | Result eligibility differences, navigation return, highlight/snippet fit |
| Filter editor | Normal/advanced, recursive rules, conversion and selection | Empty/dead references; missing custom bounds; missing advanced root | Fail-closed references, nested layout, mode switching and Cancel |
| Entity/folder/merge sheets | Focused name, color/symbol choice, native pickers, Save/Cancel | Empty names; no merge target; excluded parent candidates | Correct disable states, cycle-safe selection, retained unrelated fields |
| Template gallery/editor | Use/edit/create, native text draft | No templates; invalid name/title; plain edit of previously styled body | Body-preservation limits, checklist and other unedited template fields |
| Settings/value controls | Immediate single preferences; staged reminder multi-choice; native AX representation | Selected/hovered value, disabled date-text option, archived default list | Keyboard/focus, switch/checkbox hit shape, persistence and Reset scope |
| Summary | Editable output, regenerated options, compact/full options rail | Empty report body beyond header; Saved as note status | Unsaved edits replaced on regeneration, Copy/Save routing, narrow width |
| Toast/error/recovery | One five-second shared feedback slot; retry/recover/purge alert | No toast for direct Won't Do/subtask paths; persistent storage error | Timing/announcements, one-time Undo, no false success, banner overlap |

No general loading spinner or network-error screen is established for these local views. URL-title fetching is a separate optional data operation; do not infer an app-wide loading state from it. Component state tests should exercise their actual inputs instead of adding unsupported screens to the baseline.
