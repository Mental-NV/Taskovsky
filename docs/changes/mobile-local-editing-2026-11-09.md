# MOB-EDIT-001 — Local phone storage and protected field editing

Status: Implemented as a bounded local field-editing slice under the autonomous local Tasks/Calendar desktop/mobile request. This extends MOB-FOUNDATION/PERSIST/PREVIEW in the isolated mobile worktree; the original Desktop checkout stays untouched. No commit/push, signing-account change, device deployment, notification prompt or external service.

## Outcome and scope

Connect the tested repository to the iPhone's own Application Support container. Normal Debug/Release starts with a new empty local workspace, not sample content. An explicit validated `--qa-session <UUID>` uses a separate sandbox-local QA directory and neutral fixtures. Invalid QA arguments fail closed; no arbitrary file path or Mac workspace can be selected. Opening existing files never reseeds or repairs them. New-file bootstrap stages a workspace/settings pair without overwriting existing files; a partial/unreadable pair is blocked and preserved.

Add title and eligible plain-body editing to existing task detail. Title remains editable for known styled tasks; styled/malformed rich bodies stay read-only with their notice. Unknown/unsupported data anywhere locks writing under the conservative repository gate. Missing, archived and trashed records remain guarded. Other metadata/lifecycle/capture/schedule editors are later slices, not removed scope.

## Transactions and interruption

The editor copies field text, task/document identity and an expected revision. Done commits one owned field, Cancel/dismissal on a dirty edit asks Discard/Keep Editing; unchanged Done produces no workspace write. Disable duplicate submissions and Done during IME marked composition. Save refusal/failure retains the draft and offers a useful reason/retry without claiming success. Reload after an external change must not silently rebase a draft.

Persist a resumable field draft separately with schema version, editor/task/field identity, original/current exact text, a sequence number and a compact revision fingerprint. Do not copy an authoritative workspace into the draft. Debounce scratch writes (250 ms), flush on background opportunities and explicitly report draft-save failure. Relaunch offers Resume/Discard; it never submits. A force kill before the debounce/flush can lose the latest scratch characters, which must be measured and recorded. Unknown/malformed draft files are preserved and block replacement. A closed draft identity rejects late saves so callbacks cannot recreate an abandoned editor. Successful workspace save and draft cleanup are separate outcomes.

## UI and data

Use the existing half/large detail presentation and an expanded editing sheet, system body/title typography, 16–20 point content insets, 44-point action targets and explicit Cancel/Done. A native plain UITextView host provides selection/undo/IME and document-scoped reset; no rich extraction or flattening path. The draft notice/error is readable above the editor; larger text/keyboard layouts scroll. These editor states are desktop-derived adaptations, not screenshot-matched sign-off.

Workspace and scratch data stay in the phone container with ordinary iOS file protection until first unlock where supported. Bootstrap settings then workspace with no replacement; failure after the first move is a preserved partial set, not a writable empty fallback. Repository writes stage before publishing durable state. Compact SHA-256 revision fingerprints replace in-memory raw-byte revision storage; no workspace schema change and no sync protocol.

## Verification

Test bootstrap no-overwrite/partial failures; compact revisions; scratch round-trip/unknown data, sequencing/closed identity, failures and stale recovery; metadata/body preservation, no-op, Cancel/discard, duplicate Done, failed/stale saves and reload. On the simulator use a fresh QA session per test, plus a fixed session for relaunch/recovery, with neutral content only. Retain Calendar/popover/filter regressions. Run affected Mac suites/release build, iOS compilation and native checks; keep physical device, notifications and unexercised accessibility/IME cases explicit. Update current business/mobile/architecture/parity and exact verification evidence together.

## Implementation disposition

The app now uses the repository, guarded bootstrap and separate versioned scratch service. A read-operation ticket prevents obsolete foreground refresh completions from replacing later operations; native text delegates carry editor identity and Done first commits the keyboard responder. Scratch identities close before cleanup, and failed cleanup is distinct from durable task success. A retained cleanup candidate permits removal retry without reopening the identity for callbacks. The native editor returns the proposed width and aligns its minimum-height wrapper to the top so short text uses the same inset as long text. Actual cross-platform QA starts from resources written through Mac TaskStore, edits through the native phone UI, audits unowned fields/settings/no-op bytes, then reloads with Mac TaskStore without writes.

Default Application Support backup eligibility is deliberately retained under device settings. No backup/restore has been exercised and no cloud/sync API was added. Dirty swipe dismissal is blocked; Cancel offers the explicit alert, with no swipe-attempt prompt. Physical-device IME, accessibility, native Undo edge cases and the pre-acknowledgment force-kill window remain unverified. Recovery overwrite/import UI and capture/lifecycle/metadata/schedule/organization editors are later slices. The normal empty app currently has no creation flow, so this milestone is not a complete usable pre-alpha. See the [exact verification record](../spec/verification.md#mobile-local-editing); prior preview reports remain historical.
