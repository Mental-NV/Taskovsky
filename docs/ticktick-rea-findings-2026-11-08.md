# TickTick investigation and Taskovsky implementation

**Historical investigation and implementation report.** Preserve this document as provenance, not a current acceptance gate. Implementation and validation statements below describe that investigation. The [current parity tracker](parity-implementation-status.md) and [code-derived specifications](README.md) supersede its status summaries. No runtime checks were repeated for the documentation reconciliation.

Investigation date: 8 November 2026 (Europe/Moscow). Target: installed TickTick 8.2.20, ARM64 slice of `/Applications/TickTick.app/Contents/MacOS/TickTick`. Universal executable SHA-256: `e76d6757e4a1e71fd16814443bb3b02d15d0d547ac69abb67306d8dfa3ee35af`.

This investigation reads shipped application artifacts. No TickTick task database, account credentials, or private task contents were imported. Decompiled pseudocode is analysis evidence, not recovered original source. Taskovsky's implementation is independently written. The user's current request brings rich formatting into scope and supersedes its exclusion in older parity documents. Account/sync, Calendar, Focus, Habits, Matrix, and Countdown remain outside this task.

## How these features fit together

Tasks and notes are content records inside lists. Folders group the lists; they do not replace a task's list membership. Tags form a separate hierarchy, so a task can carry multiple tags while belonging to one list. Task hierarchy is a separate relationship again: a full child task has its own content and schedule, unlike an embedded checklist item. Those distinctions are visible in the packaged model's separate project, tag, parent/child, and checklist fields.

Smart lists and saved filters select existing records. Moving, tagging, completing, archiving, or excluding a list changes whether an item matches those views; it does not create another task. The archive and smart-list-exclusion fields are separate because their reminder policies differ. Taskovsky follows that distinction and keeps archived content recoverable.

The decompiled filter framework evaluates typed conditions combined into logic groups. Normal multi-select criteria and an advanced rule builder are two interfaces to that idea. The evidence establishes AND/OR/NOT implementations and individual predicates; it does not prove every combination policy in the reference editor. Taskovsky's selected-value and empty-group policies are therefore documented and tested as independent choices.

Rich editing has both content and presentation state: TickTick exposes separate change, selection, heading-presentation, mode-switch, and persistence callbacks. Taskovsky uses native attributed editing and its own persisted style ranges tied to the exact UTF-16 body text. That preserves ordinary text search and gives formatting a safe round trip without assuming TickTick's private Markdown/block serialization.

## Evidence and what it establishes

| Area | Observation | Evidence and limits |
| --- | --- | --- |
| Rich task/note editing | `TTSingleTaskDetailViewController` declares `markdownTextDidChange:isInput:`, `markdownTextViewDidChangeSelection:`, `markdownPresentationDidChange:anchorHeadingLocation:`, `showMarkdownEditBar`, `synchronizeMarkdownContentBeforeModeSwitch`, and `completeMarkdownPersistenceWithRequestID:succeeded:`. The shipped English UI contains Bold, Italic, Underline, Strikethrough, Heading 1–6, Bulleted List, Numbered List, Quote, and Text Format labels. | Native metadata `ev_a88a7afef79542922c2137b14bc0ed94b5d565c65c45ed4f9b3a701b10db4a07`; resource plist `ev_48050af91ae24b14ce35c047308ff34283cd4b525d984723099a21767e492850`. Change handler implementation address `0x1005a390c`, selection handler `0x1005a3b0c`, mode-switch synchronization `0x10026deac`. These establish dispatch/control surfaces, not execution or exact serialization. |
| Task pinning and hierarchy | The detail controller declares `togglePinnedState` at `0x1002700cc`. The packaged Core Data model defines `TTTask.pinnedDate`, `parentId`, `childIds`, `collapsed`, `checklistItems`, `startDate`, `endDate`, `content`, `dezcription`, `notionBlockString`, and `notionBlocks`. | Metadata above; model archive `ev_18eb5450deec266cc1fdf065ef880b18d534a758251b1c72c3f49bcc21e72ce2`, `NSEntityDescription` object 743. Separate checklist and task-parent fields corroborate the previously observed independently selectable children in [tasks](ticktick-spec/tasks.md). Field names do not establish cascades, recurrence semantics, or rich-text encoding. |
| Lists and folders | `TTProject` defines `groupID`, `group`, `kind`, `closed`, `showsInSmartList`, `viewMode`, `kanbanMode`, `sortType`, and `sortOrder`. `TTProjectGroup` defines `projects`, `expanded`, `sortOrder`, and `name`. | Model archive above, entity objects 294 and 269. Confirms stored grouping, archive/exclusion, and view state. The earlier observed list/folder controls are in [lists and tags](ticktick-spec/lists-and-tags.md). |
| Smart-list exclusion | The shipped explanatory text says that excluded lists' tasks do not appear in All, Today, Tomorrow, Next 7 Days or other smart lists, but still receive reminders. | Resource plist above, key beginning `If enabled, tasks within this list won't be shown`. Describes intended behavior; actual custom-filter exceptions were not exercised. |
| Archiving | `archive_confirm_message` says an archived list appears in Archived Lists and its tasks/notes no longer receive reminders or appear in smart lists. `cannot_edit_archived_list` describes archived content as uneditable. Unarchive guidance restores a list from Archived Lists. | Resource plist above. Distinguish archive from smart-list exclusion: both hide tasks from smart destinations; only archive suppresses reminders. No existing list was archived during investigation. |
| Tags | `TTTag` defines `parent`, `children`, `parentName`, `collapsed`, name, color, and sort state. `TTTagMergeViewController` exists with a selected-tag control and Save action. UI labels include Parent Tag, Add Sub-tag, Merge Tags. | Model archive above, entity object 633; native metadata and resource plist above. Confirms hierarchy and merge surfaces. Exact descendant and saved-filter handling during merge remains unobserved. |
| Saved filters | `TTFilter` stores a `rule` field. `TTFilterKit` contains `AndLogicFilter`, `OrLogicFilter`, `NotLogicFilter`, `PriorityLogicFilter`, `TagLogicFilter`, `TaskTypeLogicFilter`, date and repeat predicates, and normal-rule parsing. | Model archive entity object 859; search evidence `ev_662c6cef5466217c74aaa3e61cee5219752414761c2afeefbcea97b4073bdf19`. Framework universal SHA-256: `c559591e8dc7dbc98e99d09fb2afd342fa09b755aea197560129b8690a7d6810`. |
| AND / OR / NOT evaluation | At `0x2238`, AND loops over child predicates and stops on a false result; an empty collection returns true. At `0x31018`, OR combines child predicate results with bitwise OR; its empty collection also returns true. At `0x30f20`, NOT stops on the first true child then inverts the result. | Pseudocode evidence AND `ev_b302fc3bef150e148cfeb799c6230b5863675ac2f7eadbbc5e976c4686f005ae`, OR `ev_2fb225f0c45349275fd00496c56e690acc639f832bb4987029eeeda91a040d37`, NOT `ev_8d8eb3b433a0db8a7a8bb40a91c5011264bc5c0b01cf12ddda5307397fb8f057`. This is static control-flow evidence, not a runtime test. |
| Priority / task type / No Tags | Priority code at `0x3b870` compares a stored priority after other guards. Task-type code at `0x546b0` scans selected types for a match. Tag code at `0x52c24` contains Swift small-string constants representing `all`, `!tag`, and `*withtags`; the latter two branches inspect the tag collection count. | Priority `ev_3737067562b004a33424f14816025e6eeb01b92a91b8c3cf92f2440b5e9b896c`; type `ev_df1c7485a42e91a35b2b4c9aa55a910ba5aede20a0b2616650ce073578f49cf8`; tags `ev_15d4bea0c98f73b44119394083432abc737f3b533a4c5ee47c78108def3b93ca`. Some tag pseudocode contains unresolved condition-code instructions: general tag-match semantics are not claimed fully recovered. |

## Artifact ledger

The original investigation recorded these local artifact locations. They are not committed to this repository, and their continued availability was not checked during documentation reconciliation:

- Main metadata and English resources (`rea-evidence/ticktick-main-bundle.json`, local artifact not committed).
- Filter symbols and decompiled predicates (`rea-evidence/ticktick-filter-bundle.json`, local artifact not committed).
- Packaged Core Data model (`rea-evidence/ticktick-model-bundle.json`, local artifact not committed).

The `.mom` file was inspected as a keyed-archive reference graph, without deserializing executable classes. Entity/property names above were projected by following recorded UIDs in `NSEntityName` and `NSProperties.NS.keys`. REA labels unfamiliar archived classes `unknown-class`; that limits semantic decoding, not the recorded raw fields. Main native metadata has partial ivar coverage and does not recover all Swift declarations.

The model archive has SHA-256 `76ae5ab4a2ba6dfdbef11cb4528036ddb8a5e9dc479af532236fcae39b460767`; all 1,470 object-table entries were returned (`truncated: false`). Code addresses in this report are static provider addresses, not live process/ASLR addresses. The task editor callbacks and model describe a Markdown/block-oriented editing surface, but the exact mapping among `content`, `dezcription`, `notionBlocks`, and `notionBlockString` remains unknown. Taskovsky deliberately keeps a plain searchable body plus its own Codable rich-text companion instead of assuming TickTick's private storage format.

## Historical implementation checklist

This ledger distinguishes implemented behavior from complete TickTick parity. Taskovsky uses its own models and policies.

| Area | Gap at start | Intended independent implementation | Status |
| --- | --- | --- | --- |
| Task/note bodies | Plain-text editor; rich formatting excluded in older documentation | Native attributed editing: bold, italic, underline, strike, H1–H6, links, highlight, inline code, quotes, bullets, numbered/checklist paragraphs, horizontal rules; searchable plain text plus persisted styles | Implemented; native input, rendering, and save/reopen regressions covered |
| Tasks | No pin state; embedded checklist only | Pin grouping; independently selectable nested tasks; cycle-safe links; subtree duplication/moves; completion/trash cascades with reload-safe child ledgers | Implemented; hierarchy, lifecycle, and persistence tests pass |
| Lists | No archive, pin, smart-list exclusion, or duplicate-list action | Recoverable archive/unarchive, read-only archived content, smart-list inclusion, pin shortcuts, duplicate-list hierarchy remapping | Implemented |
| Folders | Basic folders already implemented | Pin shortcut while preserving folder/list moves and Ungroup semantics | Implemented; folders remain one level |
| Smart lists | Visibility/order already implemented; ignores per-list exclusions | Shared eligibility for rows/counts; archive suppresses reminders, smart-list exclusion keeps them | Implemented |
| Tags | Flat tags; no merge or pin | Parent selector, sub-tags, cycle-safe hierarchy, merge with reference rewrites, pin shortcuts | Implemented |
| Filters/search | One priority/date; no type, No Tags, ranges, or logic | Multi-priority/date/type, tag matching modes, inclusive custom dates, AND/OR/NOT groups, legacy-safe decoding; unavailable criteria remain visible instead of broadening silently | Implemented |
| Task scheduling | One due date and six fixed recurrence presets | Timed/all-day duration windows; custom cadence, weekday/month-day/ordinal/workday/specific-date rules and end conditions, based on the observed [scheduling controls](ticktick-spec/scheduling.md) | Implemented; recurrence, duration, task-zone and DST regressions pass |
| List presentation | List view only | Persisted per-list List/Board mode; Open, Completed, Won't Do status columns | Implemented; custom sections/columns are outside this implementation |

Where the binary evidence does not establish a detail (merge cleanup, empty-filter editor behavior, parent cascades, or selection combination semantics), tests and documentation must identify Taskovsky's chosen policy rather than claiming exact TickTick equivalence.

## Independent behavior choices

Rich styles are attached to exact UTF-16 text, so independently replacing the body cannot apply stale ranges to a different string. Each native body editor owns its undo manager and uses the task ID to invalidate history on document switches, even when two bodies are identical. Empty-block Return exits a list, heading, or quote. Styled checklist paragraphs are distinct from the task's embedded checklist and full child tasks; interactive click-to-toggle boxes in body text, attachments/images, tables, and a full Markdown source editor are not implemented.

The TextKit 1 editor draws list markers and quote bars from paragraph metadata in a reserved gutter; they are absent from the saved plain text. Visual inspection caught both a load-time height error and missing native list-marker painting, which the implementation now handles explicitly. Numbered runs restart after a non-numbered paragraph. Very large item numbers (beyond roughly three digits) can exceed the fixed 24-point gutter.

Editing after reopening mid-list has a remaining limitation: starting a new paragraph may begin as plain text, requiring the list toolbar action again. Full fidelity for arbitrary foreign rich-text paste is not claimed. These limits do not change the saved text or existing list formatting.

Completing a parent completes active descendants while preserving children already completed or marked Won't Do. Undo reopens only children whose cascade completion timestamp is unchanged. Trash/Restore follows the same principle for independently trashed children. Linked tasks move as a subtree; moving a child independently detaches it when its parent stays in another list. Children remain independently filterable, so a child whose parent does not match can appear as a root in that view. Recurrence-successor cleanup uses conservative in-memory pristine snapshots; after reloading, reopening retains successor records rather than risking deletion of later work. This is Taskovsky policy, not a recovered TickTick algorithm.

Normal filters OR selected values within a field and AND the different fields. Advanced mode replaces the normal criteria with a rule tree. Empty AND and OR match all non-deleted eligible records, reflecting the retained framework control flow; NOT inverts its child. Only positive list references grant an explicit archive/exclusion override. Deleted list/tag criteria stay as unavailable selections until deliberately cleared or replaced; an editor save does not silently turn a now-empty constraint into Any. Tag merges rewrite both ordinary references and rule-tree tag predicates.

Parent-tag navigation includes descendants, while filter tag selections match the selected IDs. Explicit selection of an archived or smart-list-excluded list in filters/search/summary is permitted; archived results stay read-only. Boards organize statuses, with flat cards rather than nested rows or custom columns. The custom recurrence engine is independently written and does not claim TickTick's holiday calendars, cloud behavior, or complete recurrence equivalence.

## Implementation entry points

| Feature | Code |
| --- | --- |
| Body model, attributed conversion, formatting commands | [RichText](../Sources/TaskovskyCore/RichText.swift), [RichTextRender](../Sources/TaskovskyCore/RichTextRender.swift), [native editor](../Sources/Taskovsky/RichBodyEditor.swift) |
| Visible list/quote markers and body sizing | [ListLayoutManager](../Sources/TaskovskyCore/ListLayoutManager.swift), [ListDecorations](../Sources/TaskovskyCore/ListDecorations.swift), [RichEditorSizing](../Sources/TaskovskyCore/RichEditorSizing.swift) |
| Task/list/tag lifecycle and persistence | [TaskStore](../Sources/TaskovskyCore/TaskStore.swift), [models](../Sources/TaskovskyCore/Models.swift), [hierarchy/eligibility](../Sources/TaskovskyCore/Organization.swift) |
| Filters, matching and rule conversion | [matching models](../Sources/TaskovskyCore/Settings.swift), [rule transforms](../Sources/TaskovskyCore/FilterRuleEdit.swift), [filter editor](../Sources/Taskovsky/FilterEditor.swift) |
| Duration/custom repeat and board projection | [CustomRecurrence](../Sources/TaskovskyCore/CustomRecurrence.swift), [ScheduleDraft](../Sources/TaskovskyCore/ScheduleDraft.swift), [BoardProjection](../Sources/TaskovskyCore/BoardProjection.swift) |

## Tool limitations

The initial main-executable Hopper analysis took 2 minutes 9 seconds, exceeding REA's default 120-second bridge startup limit. Its retained MCP session could not authenticate cleanup even after the owned temporary document was manually closed. A separate investigation-only REA connection used a 450-second startup allowance without changing Codex configuration. It successfully decoded native metadata/resources/model and decompiled the smaller `TTFilterKit` framework; that connection was exported and closed. Hopper's demo disallows saving its analysis database. These facts do not invalidate the retained static Evidence, but complete main-executable decompilation and controlled runtime behavior remain unverified.

## Historical validation

The original report recorded **370 passing tests: 336 XCTest and 34 Swift Testing checks**, with no failures or build warnings, and a passing release build and local code-signature verification. See test log (`../build/verification/swift-test.log`, local artifact not committed), release build log (`../build/verification/build-app.log`, local artifact not committed), and built app (`../build/Taskovsky.app`, local artifact not committed). At the time of that report, changes remained in the working tree and the pre-existing focus-effect changes in `App.swift` were recorded as preserved.

The tests cover legacy decoding, exact UTF-16 identity, rich-style roundtrips and stale-marker removal, native list input and marker geometry, empty-block Return, pending formatting, hierarchy cascades and reload-safe ledgers, edited-successor retention, tag merges, archive/reminder eligibility, filter intent and logic transforms, board projection, recurrence, duration endpoints and task-zone/DST behavior. List-event regressions include the selection refresh that previously stripped AppKit's native list metadata, using the same continuation policy as the production coordinator.

Parent visual checks on disposable fixtures verified the 300-point rich-body layout without overlap; headings, inline styles, links, code, quote bars, rules, bullets, numbers and checked/unchecked boxes; child/parent detail navigation; parent completion and its Undo; board status changes and Undo with independent per-list modes; disabled archived editing; descendant-tag navigation; and the nested filter editor. A styled first heading followed by an exited plain paragraph retained the correct appearance after switching tasks and reopening.

The final uniquely named **Taskovsky QA Final** copy was launched with explicit workspace/settings arguments against the disposable fixture. The live list sequence passed: an empty body became a bulleted first item; one Return produced a second bulleted item; two Returns exited the empty item; subsequent text was plain, with no extra blank paragraph. Switching to another task and reopening preserved both bullets and the plain paragraph. The saved body contains text and newlines only, with decorations supplied by its rich companion.

Native drag/resize gestures and a complete keyboard body-Undo cycle could not be driven reliably through the UI tool; they are not claimed as live-verified. Completion Undo was verified through its toast. Document-ID isolation, including identical bodies, has automated coverage. All interactive mutations used a separate test workspace; no TickTick account or task data was imported.
