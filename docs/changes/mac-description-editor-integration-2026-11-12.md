# Mac description editor integration (in progress)

Status: draft implementation, not release-ready. The Mac disconnected after the unused recovery foundation merged. Work continues in an isolated cloud checkout. Native editor safety gates cannot run until it reconnects.

The first boundary adds a description-only acknowledged write. It compares exact paired body/rich baseline with current saved content, preserves unrelated current task fields, patches only body/rich/timestamp and publishes only after durable acknowledgement. Raw unrelated fields remain unchanged; unknown affected rich metadata refuses. Known protected task-envelope transitions follow supported rich-feature encoding without silently dropping unknown envelope keys. This is not wired into TaskDetail yet and does not fix current autosave by itself.

Remaining integration:
- Load owned recovery before enabling editing; malformed or foreign recovery is not empty.
- Shared per-task draft is fed synchronously to the editor, while one serialized persistence loop journals exact revisions before attempting the body-only write.
- Older acknowledgements cannot mark newer typing saved; cleanup waits for exact latest content and subsequent editing gets a fresh identity.
- Coordinator callbacks carry the last accepted rendered snapshot, not a refreshed SwiftUI closure. Stale sibling edits remain copyable conflicts.
- Marked text must survive composition and be captured before document/window teardown. Ordinary save acknowledgement must not rebuild NSTextStorage or erase Undo/selection.
- Explicit recovery Resume/Keep Saved actions, failed-cleanup notices, memory-only quit protection and relaunch checks are required.

Recovery ownership will use the canonical workspace path namespace and a dedicated adjacent directory; automatic relocation is unsupported. Symlink/root validation and journal failure handling must be implemented before product wiring. No real user data or notification settings may be used for testing.

Six first-boundary owned tests target write failure/retry, current title/schedule preservation, stale body refusal, exact Unicode, unknown raw preservation, unsupported rich metadata and rich envelope transitions. They passed macOS CI at 7691aa2 (run 43256469358), including release packaging. Cloud has no Swift/Xcode. CI is the compile/test gate; native IME/Undo/sibling/close/relaunch remains a separate release gate. Do not merge this integration as a completed editor fix before those gates pass.

## Shared draft checkpoint (not wired)

The next checkpoint adds an app-owned path namespace, read/write/remove link checks, and a shared session with serialized journal-before-workspace persistence. Stale editor candidates are retained for copying. Workspace write failure leaves saved task data unchanged while a successful journal provides recovery; cleanup must complete before a new journal identity is written. Link checks are not a cross-process filesystem race guarantee.

Basic owned tests cover failure/retry/reopen, stale sibling candidates, namespace ownership and replacing a journal path with a link. These new tests await macOS CI. Delayed-operation tests, orphan recovery discovery, AppKit callbacks, composition/Undo protection, explicit review controls and close/quit protection are still incomplete. Neither this checkpoint nor the earlier CI success means the current user-facing autosave issue is fixed.
