# Independently testable components

The strongest first component boundary is the rich body editor: its document representation can be shared, while its macOS and iPhone editing surfaces can differ. Scheduling and queries also deserve explicit contracts, but do not need separate packages merely to be testable.

**Baseline:** static source inspection at `30045bac5355b793a8c155b87ffe58584cb29fb8` on 2026-11-08. **Current** describes code present at that revision. **Proposed** describes future work, not implementation in this documentation PR. No application or tests were run for this document. Component IDs and requirement anchors are stable references for future work and the [parity tracker](../parity-implementation-status.md).

See [shared-engine architecture](shared-engine.md), [business rules](../spec/business.md), [macOS UI](../spec/ui-ux.md), and the [iPhone proposal](../spec/iphone.md).

<a id="cmp-001"></a>
## CMP-001 Rich body editor

### Purpose and ownership

**Proposed:** make the editor usable with a document ID, plain body, optional rich payload, edit permissions/capabilities, and a commit callback, without constructing TaskStore or a workspace. The host remains responsible for saving, task/note identity, archive restrictions, and error presentation. The editor owns text interaction, selection, pending typing formats, and document-scoped undo.

The boundary has three parts, not necessarily three packages:

1. Shared values and validation: `RichBody`, run/block data, UTF-16 identity, format support classification, and platform-independent editing rules where justified.
2. A macOS adapter containing the existing AppKit rendering, extraction, controller/coordinator, measurement and decoration logic.
3. A separate iPhone adapter with a smaller supported editing surface and the same preservation contract. It need not recreate AppKit or every desktop toolbar command.

**Current:** [RichBodyEditor.swift](../../Sources/Taskovsky/RichBodyEditor.swift) lives in the executable. [RichText.swift](../../Sources/TaskovskyCore/RichText.swift), [RichTextRender.swift](../../Sources/TaskovskyCore/RichTextRender.swift), [ListDecorations.swift](../../Sources/TaskovskyCore/ListDecorations.swift), [ListLayoutManager.swift](../../Sources/TaskovskyCore/ListLayoutManager.swift), and [RichEditorSizing.swift](../../Sources/TaskovskyCore/RichEditorSizing.swift) are in Core. No standalone editor target or demonstration app exists in [Package.swift](../../Package.swift).

<a id="rich-001"></a>
### RICH-001 Current persisted representation and safety rules

These existing rules are compatibility constraints for an extraction, not a proposal to replace the format with HTML, Markdown, RTF, or an attributed-string archive.

| Value | Current representation |
| --- | --- |
| `TaskItem.body` | Authoritative plain `String`. Search, snippets and summaries use plain text rather than reconstructing it from formatting. |
| `TaskItem.richBody` | Optional `RichBody` companion. Legacy task records without this field decode with `nil`. Templates have the same optional companion. |
| `RichBody` | `text`, `runs: [RichInlineRun]`, `blocks: [RichBlockRun]`. There is no schema-version field or unknown-field bag. |
| Inline run | UTF-16 `location`/`length`; `bold`, `italic`, `underline`, `strikethrough`, `highlight`, `code`; optional `link` string. Missing decoded booleans default to false. |
| Block run | UTF-16 `location`/`length`; optional `heading`, `quote`, optional `list`, optional `checked`, `rule`. Valid heading levels are 1 through 6. List cases are bullet, numbered, checklist; checked state is meaningful for checklist. |
| No persisted formatting | Rich extraction returns `nil` when no styling remains. An empty body has no persisted runs, although a live editor can hold a pending typing style. |

Sources: [Models](../../Sources/TaskovskyCore/Models.swift), [RichText](../../Sources/TaskovskyCore/RichText.swift), [TaskTemplate in Settings](../../Sources/TaskovskyCore/Settings.swift), [RichRender.extract](../../Sources/TaskovskyCore/RichTextRender.swift), [TaskSearch](../../Sources/TaskovskyCore/Settings.swift), [SearchView](../../Sources/Taskovsky/SearchView.swift), and [SummaryView](../../Sources/Taskovsky/SummaryView.swift).

Required safeguards inherited from source:

1. **Exact identity:** `RichBody.sameCodeUnits` compares `utf16.elementsEqual`, not Swift `String ==`. Canonically equivalent composed/decomposed Unicode can compare equal as strings while having different UTF-16 offsets. `valid(for:)` returns a rich value only when its mirrored text has the exact code-unit sequence of `body`.
2. **Stale formatting is never relocated:** rendering uses `rich?.valid(for: text)?.sanitized()`. A mismatch renders plain. `TaskStore.updateTask` clears stale rich data when the body changed and the companion no longer matches. This is conditional, not a universal validation or repair on every save.
3. **Range safety:** `sanitized()` intersects runs/blocks with `[0, textUTF16Length)`, discards nonpositive or nonintersecting ranges and unstyled values, and sorts survivors by location. It uses overflow-safe arithmetic. For example, `(-2, 4)` covers only `0..<2`; clamping the start and keeping length 4 would wrongly style new characters.
4. **Do not overstate sanitation:** it does not establish a version contract, preserve unknown fields, validate grapheme boundaries, or resolve all overlapping-run semantics. Valid heading interpretation and paragraph rendering are additional concerns.
5. **One paired commit:** the macOS coordinator extracts `(text, rich)` together; [`TaskDetail.updateBody`](../../Sources/Taskovsky/TaskDetail.swift) validates the companion and skips unchanged plain/rich commits. Template apply/create and duplication carry valid formatting with matching text, rather than applying old ranges to a replacement body.
6. **Decorations are not body prefixes:** the renderer draws list markers, quote gutters and horizontal rules. It must not synthesize `•`, `1.`, `[ ]`, or `>` into stored body text to imitate these formats. A user can still type those characters as ordinary content. A horizontal rule is represented on an otherwise empty newline paragraph, not as a line of replacement characters.
7. **Three different concepts stay distinct:** rich-body checklist blocks are formatting; `TaskItem.checklist` contains embedded checklist items; child tasks are linked `TaskItem` records through `parentID`. Editor formatting must not complete a task or mutate its embedded checklist/hierarchy.

Existing evidence: [RichTextPinTests](../../Tests/TaskovskyCoreTests/RichTextPinTests.swift) covers legacy decode, matching text, stale styles, persistence, templates and duplication; [RichRenderTests](../../Tests/TaskovskyCoreTests/RichRenderTests.swift) covers hostile ranges, UTF-16 identity, headings, composition, lists and rules; [ListDecorationsTests](../../Tests/TaskovskyCoreTests/ListDecorationsTests.swift) covers prefix-free output and geometry. These files are not a claim of newly executed verification.

<a id="rich-002"></a>
### RICH-002 Proposed editor interface and lifecycle

Use a small value/callback interface. The following are conceptual fields and outcomes, not existing public types:

- **Input:** document ID; base revision or expected-state token; authoritative body; original rich payload; support classification; enabled edit capabilities; read-only reason; platform presentation configuration.
- **Output on accepted edit:** same document ID and expected-state token; new body and matching rich value as one change; validation result. A proposed format mutation must not produce a companion whose text differs from the body in UTF-16.
- **No-change and cancellation:** emit no persistence mutation. Viewing, focus, selection, resizing, leaving a screen, or opening/closing a toolbar must not normalize and rewrite the stored payload.
- **Failure:** unsupported document, invalid range, stale revision, or invalid edit returns a refusal without replacing the original. The host surfaces save failures separately; the editor must not invent durable-success state.
- **Host callbacks:** focus, selection/toolbar state and measured size may be platform-specific. None is an implicit save command.

Existing document isolation is a behavior to retain. [EditorDocumentGate](../../Sources/TaskovskyCore/RichText.swift) compares document identity in addition to text/styles. The [macOS editor](../../Sources/Taskovsky/RichBodyEditor.swift) owns a per-view `UndoManager`; a document switch or external model rebuild clears its undo actions, and a document reset drops the pending list arm and typing state. Two tasks with identical bodies must not share undo history. Ordinary echoed keystrokes should not rebuild storage and jump the caret.

The future revision check extends that behavior to late callbacks and multiple editing surfaces. It is not present as a versioned editor command today. IME/marked-text edits must also be tested in the actual native adapter so model refreshes do not prematurely commit or cancel text composition.

<a id="rich-003"></a>
### RICH-003 Platform capability matrix

The macOS column records code present, with known issues and no new runtime verification. The iPhone column is the proposed first-release minimum, not a claim of existing support. “Preserve” means retaining the original payload without re-extracting it from a lower-fidelity view. Reading a format and authoring it are separate capabilities.

| Capability | macOS current | iPhone proposed minimum |
| --- | --- | --- |
| Plain body view/create/edit | Native NSTextView with paired commits | Native plain editor for eligible plain documents only |
| Bold, italic, underline, strike, highlight, inline code | Toolbar and typing/selection commands | No authoring initially. Read-only styling where renderer supports it; otherwise plain preview with a formatting notice. Preserve all original data. |
| Links | Stored inline link string; selection-based edit, collapsed link edit is a no-op | Read-only display; link activation may be offered independently. Preserve target/ranges; no authoring initially. |
| Heading levels 1–6 | Block commands and heading/inline composition | Read-only rendering or labeled plain preview; no block editing initially |
| Quotes | Block/typing commands and drawn gutter | Read-only rendering or labeled plain preview; no quote editing initially |
| Bulleted and numbered lists | Paragraph commands, continuation/exit, drawn markers | Read-only display; no list creation, continuation or numbering edits initially |
| Rich-body checklist and checked state | List formatting and toolbar checked-state command; direct marker click-to-toggle is not implemented | Preserve and display read-only; do not convert to task checklist items or child tasks |
| Horizontal rule | Empty paragraph marker and custom drawing | Preserve; read-only rendering or notice. Do not insert replacement text. |
| Clear formatting | Desktop command exists | No implicit conversion or destructive “edit as plain” path in the minimum scope |
| Undo and redo | Per-view editor undo, reset on document/model replacement | Native undo within eligible plain document; reset on switch/replacement; no cross-document undo |
| External rich paste | Closed render/extract mapping normalizes to known attributes; graphics import disabled | Plain-text paste into eligible plain document only; no claimed rich-paste fidelity |
| Unsupported/newer payload | No explicit version/opaque-preservation mechanism today | Read-only body and retained original payload; editable metadata only after lossless storage gate |
| Fonts, layout, selection and controls | AppKit/TextKit, desktop toolbar, deterministic height helper | Native iPhone layout and accessible touch controls; desktop fonts/geometry are not requirements |

Known desktop editor findings are recorded in the [code-review report](../code-review-findings-2026-11-08.md), including paragraph-boundary selection and empty-editor quote toggling. “Implemented” above does not close those findings. Extracting the component must not duplicate their separately owned fixes.

<a id="rich-004"></a>
### RICH-004 Proposed limited iPhone edit semantics

The first implementation should be deliberately conservative:

1. **Classify before making the body editable.** An ordinary plain document has no rich companion. A known-empty-rich document may also qualify only after successful decoding, exact mirrored-text identity, no meaningful formatting, and no unrecognized fields/features. Do not use `isEmpty` after a lossy decode as proof that a payload is plain.
2. **Edit eligible plain text only.** Typing, deletion and plain paste may update the body. Commit with no rich companion, or a documented equivalent empty companion; use one canonical choice consistently. An existing companion is not silently discarded just because a renderer ignores it.
3. **Styled bodies remain body-read-only initially.** Render known features if convenient, otherwise show authoritative plain text and a notice that formatting is preserved. Do not pass a read-only preview back through an extractor on Save, Back, focus loss or backgrounding.
4. **Allow unrelated changes only without touching body data.** Title, scheduling, priority and other permitted metadata may use field-scoped commands that retain the original body/rich payload. Re-encoding an entire reduced `TaskItem` is not a preservation strategy. If storage cannot preserve unsupported fields/payloads, block the write rather than claim safe metadata editing.
5. **No destructive round trip.** Opening a macOS-styled record on iPhone, changing a title, and reopening on macOS must retain text code units and all original styles. A plain preview must never be used as the saved representation of a styled body.
6. **Do not disguise an unsupported action.** Disable body editing with an explanation, or offer a separate plain-text copy only in a separately scoped feature. The initial proposal does not automatically flatten, migrate or delete rich content.

A later selective rich editor may support text edits or selected formats without exposing every toolbar command, but only after an edit-transaction contract is agreed. Such a contract must specify UTF-16 replacements, insertion affinity at style boundaries, style inheritance, split/merge behavior, paragraph changes, and handling of unknown annotations. Every unaffected known and unknown field must survive. If the adapter cannot transform affected unsupported ranges safely, refuse that edit. Retaining old offsets after changing the text is not preservation; neither is clearing all styles to satisfy the identity check.

<a id="rich-005"></a>
### RICH-005 Proposed unknown-format and version handling

**Current limitation:** `RichBody`, its runs/blocks, and `WorkspaceData` have no explicit schema version. Swift keyed decoding does not retain unrecognized keys for a later encode; an unknown `RichListStyle` enum value can throw. Through [TaskStore's load path](../../Sources/TaskovskyCore/TaskStore.swift), a decoding failure blocks workspace saves and preserves the original file. That is useful failure protection, not forward-compatible per-document editing.

Before a limited-capability client can write shared-format documents, introduce an explicit compatibility policy at the repository/document boundary:

| Incoming state | Proposed read behavior | Proposed write behavior |
| --- | --- | --- |
| Recognized legacy unversioned plain payload | Read as existing format | Permit eligible plain edits; no forced migration merely from opening |
| Recognized legacy rich payload or explicitly supported future version | Validate mirrored text and ranges; render only understood features | Permit only capabilities proven safe for the entire affected payload; minimum iPhone release keeps styled body read-only |
| Unknown newer version, unknown format kind or unrecognized fields | Preserve raw payload; show safe plain-body preview when its field is readable, plus an unsupported-format notice | No body rewrite or automatic downgrade. Field-scoped metadata writes only if the complete unsupported payload can be retained losslessly; otherwise the document/workspace is read-only |
| Malformed payload or plain/rich text mismatch | Do not apply questionable offsets; show authoritative plain text when available and an explanatory state | Preserve original for recovery. Do not silently sanitize-and-save, replace with an empty body or treat it as eligible plain content |
| Malformed enclosing workspace | Existing fail-closed behavior remains the baseline | Preserve original file and block overwrites; explicit recovery remains a separate action |

A future envelope must declare the supported version/features and retain opaque content rather than dropping it during decoding. The exact field names, raw-storage strategy and migration format are deferred decisions. The acceptance requirement is exact retention of an untouched opaque payload and UTF-16 identity of its mirrored text; semantic equivalence of a subset is insufficient. If the chosen storage cannot meet that guarantee, keep the containing document or workspace read-only.

Adding a `version` field alone does not protect against older clients: the present decoder may ignore it and later strip new data. Any format rollout must therefore include older-writer compatibility, backup/rollback and migration tests, or prevent incompatible writers from rewriting the file. No sync or migration implementation is included here.

For known data, a render/extract round trip may normalize run segmentation or omit empty runs. Tests should compare the documented semantic representation and exact text code units, not JSON whitespace or incidental run fragmentation. This normalization allowance does not apply to unknown payloads, untouched previews, or unrelated metadata edits.

<a id="rich-006"></a>
### RICH-006 Proposed independent development and acceptance harness

The component should be developable without launching the full task manager. A future harness would host the **same production adapter/controller/coordinator**, use synthetic documents and an in-memory commit recorder, and expose document switching, width changes, read-only mode, capabilities, external replacement and save failure simulation. It must not instantiate a default TaskStore or access the user's real files, settings, network or task data.

This is a proposal. Existing tests often construct NSTextView or storage and reproduce production sequences, but do not import the main executable's `RichBodyController` or coordinator. For example, [ListContinuationTests](../../Tests/TaskovskyCoreTests/ListContinuationTests.swift) explicitly mirrors callback ordering. Preserve that valuable coverage, then add tests that invoke the actual production host so copied test logic cannot drift from the implementation.

| Test layer | Required coverage and acceptance |
| --- | --- |
| Shared representation | Legacy JSON; paired text/style identity; composed/decomposed Unicode; emoji, combining marks and non-Latin text; negative/overflow/extreme ranges; empty text; malformed and unknown formats. No traps or applying ranges to different text. |
| Shared edit contract | For any newly supported edit, verify insertion/replacement/deletion, overlapping styles, paragraph boundaries, unchanged unsupported fields and whole-pair validation. Test rejection as well as success. |
| macOS native adapter | Real selection/typing callbacks; toolbar and collapsed-caret formats; native Return continuation/exit; trailing empty paragraphs; list pending arms; paste; IME/marked text; undo/redo; external body replacement and document switches, including identical bodies. |
| Rendering and layout | Headings with mixed inline attributes, list/quote/rule drawing, wrapping and narrow widths, no inserted marker text, no gutter overlap, deterministic height. Verify real platform rendering as well as model projections. |
| iPhone native adapter | Touch/keyboard lifecycle, eligible plain editing, read-only styled preview, safe Back/cancel/background behavior, Dynamic Type and VoiceOver, document switching and no callback rewrite while viewing. |
| Persistence and compatibility | Save/reload on isolated stores; macOS fixture → iPhone view/metadata edit → macOS preserves rich data; explicit new-style edits remain coherent; unknown fields/versions remain untouched or writes are refused. |
| Host integration | Archived task lock, task/note switch, template replacement, stale callback, save failure and retry; actual app wiring uses the tested component. No editor action mutates task completion or embedded checklist state. |

Existing suites to retain and relocate where appropriate:

- [RichTextPinTests](../../Tests/TaskovskyCoreTests/RichTextPinTests.swift) and [RichRenderTests](../../Tests/TaskovskyCoreTests/RichRenderTests.swift): value and persistence safety, render/extract behavior.
- [PendingListArmTests](../../Tests/TaskovskyCoreTests/PendingListArmTests.swift), [ListContinuationTests](../../Tests/TaskovskyCoreTests/ListContinuationTests.swift), [ReturnExitTests](../../Tests/TaskovskyCoreTests/ReturnExitTests.swift), [BlockCoherenceTests](../../Tests/TaskovskyCoreTests/BlockCoherenceTests.swift): typing, block state and native storage interaction.
- [ListDecorationsTests](../../Tests/TaskovskyCoreTests/ListDecorationsTests.swift) and [RichEditorSizingTests](../../Tests/TaskovskyCoreTests/RichEditorSizingTests.swift): drawing geometry and measurement.
- [DocumentUndoGateTests in BoardIsolationGateTests](../../Tests/TaskovskyCoreTests/BoardIsolationGateTests.swift): identity/reset policy, not a full native undo integration test.

**Extraction exit gate:** macOS behavior remains equivalent except for separately approved fixes; the adapter compiles and can be tested independently of the task manager; the production controller is the unit under test; the current body format remains readable. **iPhone editing exit gate:** capability classification, non-destructive metadata writes, unknown-data handling, and cross-platform fixture checks pass before body writes are enabled. Test cases listed here are requirements for future work, not newly added or passing tests.

<a id="cmp-002"></a>
## CMP-002 Scheduling and recurrence

**Current seam:** [CustomRecurrence](../../Sources/TaskovskyCore/CustomRecurrence.swift) contains rules, validation and occurrence/duration calculations; [ScheduleDraft](../../Sources/TaskovskyCore/ScheduleDraft.swift) stages due/time/window changes; [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift) owns save coherence and successor creation; [ScheduleEditor](../../Sources/Taskovsky/ScheduleEditor.swift) and [CustomRecurrenceEditor](../../Sources/Taskovsky/CustomRecurrenceEditor.swift) still own apply/clear and nested draft interactions.

**Proposed contract:** explicit task schedule, recurrence position, draft intent, calendar/time zone and current/completion time in; validated schedule change or refusal out. Keep pure occurrence calculation separate from workspace lifecycle effects, but in the same Core target initially. A recurrence calculation must not write a task, schedule a notification, or read the clock implicitly when tests require an explicit instant.

Retain end-anchored duration (`due == window.end`), timed/all-day coherence, legacy/custom recurrence precedence, occurrence counting, reminders, and per-task time-zone handling from source. Shared application use cases own the final transaction; each platform owns picker presentation. The iPhone UI can omit advanced rule creation while retaining an existing custom rule, rather than resetting it on an unrelated date edit.

Independent tests should use explicit calendars/zones and fixed dates for short months, leap years, DST, multiple successive occurrences, end counts, invalid drafts, nested Cancel/Done/outer Apply, and subtree successor/reminder interactions. Existing evidence: [CustomRecurrenceTests](../../Tests/TaskovskyCoreTests/CustomRecurrenceTests.swift), [ScheduleDraftTests](../../Tests/TaskovskyCoreTests/ScheduleDraftTests.swift), [DurationTests](../../Tests/TaskovskyCoreTests/DurationTests.swift), [TaskZoneDurationTests](../../Tests/TaskovskyCoreTests/TaskZoneDurationTests.swift), [RecurrenceIntegrationTests](../../Tests/TaskovskyCoreTests/RecurrenceIntegrationTests.swift), and [ReminderTests](../../Tests/TaskovskyCoreTests/ReminderTests.swift). Known recurrence/cancellation issues remain in the [separate review](../code-review-findings-2026-11-08.md); this proposal neither fixes nor claims to validate them.

<a id="cmp-003"></a>
## CMP-003 Queries and projections

**Current seam:** [TaskFilter and TaskSearch](../../Sources/TaskovskyCore/Settings.swift), [SmartListEligibility and hierarchy helpers](../../Sources/TaskovskyCore/Organization.swift), and [BoardProjection](../../Sources/TaskovskyCore/BoardProjection.swift) are reusable. [App.swift](../../Sources/Taskovsky/App.swift) and [SearchView.swift](../../Sources/Taskovsky/SearchView.swift) still compose membership, ordering, grouping and result scope.

**Proposed contract:** workspace snapshot + typed destination/search/filter criteria + sort/history options + explicit temporal context in; ordered record IDs, semantic groups/counts and permitted actions out. Query evaluation is read-only and deterministic for those inputs. No UI framework, filesystem, or network dependency is needed. Localized labels and highlight rendering remain platform presentation.

Use the same functions for visible rows and counts where their documented scope is the same. Keep intentional board/list/history differences explicit. An iPhone view must not re-create filter matching or return a different task set just because it uses a different screen layout. Existing tests include [OrgScopeTests](../../Tests/TaskovskyCoreTests/OrgScopeTests.swift), [FilterIntentTests](../../Tests/TaskovskyCoreTests/FilterIntentTests.swift), [FilterHardeningTests](../../Tests/TaskovskyCoreTests/FilterHardeningTests.swift), [BoardProjectionTests](../../Tests/TaskovskyCoreTests/BoardProjectionTests.swift), and [ReorderTests](../../Tests/TaskovskyCoreTests/ReorderTests.swift). Add characterization cases for the currently view-owned composition before moving it; these component seams can stay inside Core.

<a id="cmp-004"></a>
## CMP-004 Local storage and optional services

**Current seam:** [TaskStore](../../Sources/TaskovskyCore/TaskStore.swift) accepts explicit workspace/settings URLs, uses atomic JSON writes, reports errors, blocks workspace writes after failed decoding, and backs up the unreadable workspace before recovery. [AppMigration](../../Sources/TaskovskyCore/AppMigration.swift) and [IsolatedLaunch](../../Sources/TaskovskyCore/IsolatedLaunch.swift) address macOS paths/launch policy. [URLTitle](../../Sources/TaskovskyCore/URLTitle.swift) performs optional network enrichment.

**Proposed contract:** a local repository loads a snapshot plus compatibility/load state and saves a validated change with an explicit success/failure result. Unsupported data must either be preserved by field-scoped lossless writes or block rewriting, as specified in [RICH-005](#rich-005). Workspace and settings are separate files today, not a transactional multi-file database; do not imply atomicity across both. Memory-only edits, durable success, blocked load, and recoverable write failure must be distinguishable to the host.

Keep the first backend local JSON. Test with temporary directories and injected failures, including unreadable JSON, failed backup, failed atomic write, explicit settings paths and preserved unrelated fields. [TaskStoreTests](../../Tests/TaskovskyCoreTests/TaskStoreTests.swift), [FoldersSmartOrderTests](../../Tests/TaskovskyCoreTests/FoldersSmartOrderTests.swift), and [BoardIsolationGateTests](../../Tests/TaskovskyCoreTests/BoardIsolationGateTests.swift) contain relevant current cases. Do not run a demonstration or test against the real workspace.

The URL-title interface should return a candidate result without owning task lifecycle; an application use case rechecks current title/settings before applying it. Use deterministic fake fetchers for independent tests and retain existing network restrictions. Clock/ID providers and platform reminder delivery are other small service seams, not a justification for many new packages. Accounts, server sync, multi-device conflict resolution and OS notifications are separate future decisions, not part of this component extraction.
