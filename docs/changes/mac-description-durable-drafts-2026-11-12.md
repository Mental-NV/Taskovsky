# Mac description drafts and durable acknowledgement

Status: non-UI phase-1 foundation implemented after an owned failed-write regression confirmed optimistic body/rich publication. The current Mac editor is NOT wired to it; existing description autosave remains unchanged and the reported user-facing risk is not fixed. This is not a claim that current notes are recoverable after a failed save.

## Problem and boundary

TaskDetail.updateBody currently calls void updateTask, which publishes body/rich before a workspace write succeeds. Same-body callbacks then skip the write, while relaunch reads the old file. Simply reverting the model is unsafe: RichBodyEditor.reloadIfNeeded rebuilds NSTextStorage and removes Undo history when model input changes. App termination after the last window closes also makes session-only drafts insufficient.

Scope is Mac task/note description body plus rich metadata only, not title/checklist/schedule autosave and not the phone rich editor. Main, drawer and popup already share DetailDrafts, but their AppKit selections and Undo stacks are separate.

## Phased implementation gates

1. Non-UI snapshot/recovery foundation. A versioned record pairs exact UTF-16 body text and validated rich metadata with immutable workspace/task/editor identity and original body/rich baseline. Local sequence is monotonic; stale or conflicting writes refuse. Unknown/malformed recovery bytes must not be replaced or interpreted as an empty draft. Retain prior record on failed writes; acknowledge durable persistence only after successful write or exact readback. No workspace mutation, app lifecycle/UI wiring or automatic recovery acceptance in this phase.
2. Description-only saved-state command. Compare original body/rich against current persisted content, preserve unrelated current task fields, and refuse unknown affected metadata or deleted/archived tasks. Patch body/rich and timestamp atomically; no generic updateTask replacement. Success advances the draft baseline only after durable acknowledgement. Failed or ambiguous saves retain draft and surface explicit unsaved state.
3. Shared draft/UI integration and recovery. Feed the accepted draft pair back to AppKit synchronously without a storage rebuild on ordinary typing or a failed save. Older callbacks from another editor cannot overwrite newer shared content. Define conflicts rather than automatically rebasing rich text. Resume recovery only after workspace/task/baseline validation and explicit choice; permit copying/exporting conflict content, never silent discard. Save/Discard/Cancel and close/quit behavior must account for recovery-file failure before integration is called complete.

## Editor safety

IME marked text stays in its live composing view; no normalization, forced storage reload, save acknowledgement or cross-editor replacement may break composition. Committed composition is staged once with its paired rich value. Formatting, Undo/Redo and selection remain editor-owned; successful identical acknowledgements do not reset them. Switching documents, sibling editor changes and external disk changes require separate tests, including stale callbacks and returning to an unsaved draft. Do not treat restoring a snapshot after relaunch as restoring AppKit Undo history.

A stored rich snapshot is not the phone's replayable RichBodyEdit log. Reuse generic journal machinery only where its semantics are proven suitable; do not fabricate an edit history. Any unsupported future rich metadata is preserved and refused for mutation rather than normalized away.

## Evidence gates

Owned blocked-write reproduction, exact-body/rich pair validation, failure/after-write/retry, sequence and ownership collisions, corrupt/unknown records, reopen recovery, stale body vs concurrent schedule/title, removed task and archived list. Native checks must cover regular typing, formatting, IME composition, Undo/Redo, selection, popup/main switching, close/quit and relaunch. Unit tests/builds alone do not establish those native guarantees. No notification, launcher, signing-identity or existing user-data changes are part of this work.

## Implemented phase-1 boundary

`DescriptionSnapshot` validates the plain/rich pair using existing rich-edit source validation and compares exact UTF-16 text and rich encoding. `MacDescriptionDraft` holds caller-provided stable workspace/task IDs, draft UUID, immutable baseline and monotonic sequence. Recovery classifies already-saved, retry-eligible, conflict or unavailable without changing a task. Unrelated title/schedule edits do not become body conflicts; deleted/archived/missing/ambiguous task ownership is unavailable. This is not an AppKit Undo serialization.

`MacDescriptionJournal` reuses `LocalDraftStore` rather than introducing another storage engine. It requires a caller-owned dedicated file and existing parent directory. Successful writes are acknowledged by the writer; on a thrown write, exact readback may establish that bytes committed. Cleanup has a matching after-remove fallback. `close(expected:)` compares the exact latest offered record and disk within the journal actor, and in-session retired IDs prevent late callbacks from recreating a closed draft. Existing phone close APIs retain their interface. Corrupt/unknown/foreign records are refused, not silently replaced.

Workspace identity creation/persistence, path selection, symlink/root policy, app wiring and native lifecycle remain future integration responsibilities. The foundation does not scan folders, autoapply recovery, guarantee cross-process locking, or infer identity from a path. A moved file requires the same explicitly supplied workspace/task ownership to be exposed; that is not automatic relocation support. Do not call the editor fix complete until phases 2/3 and native gates are verified.
