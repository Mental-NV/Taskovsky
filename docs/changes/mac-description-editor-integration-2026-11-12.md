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

## Draft AppKit integration and outstanding release gates

The working branch now wires one shared session across task detail main/drawer/pop-up views. Only task description editors use the acknowledged bridge; template/read-only callers keep their prior API. Coordinator revisions describe the actual rendering. Ordinary acknowledgement does not rebuild text storage. Recovery errors pause editing, and global recovery can expose valid records whose task was removed. A malformed directory entry currently blocks directory-wide discovery with a visible error; it is not treated as empty.

The global panel exposes saved recovery, conflicts and memory-only composition snapshots for copying. Quit awaits pending persistence and asks explicitly before abandoning memory-only text. Clean editor teardown does not normalize or save an untouched description. When navigation destroys an editor with marked text, the current snapshot is retained as a copyable conflict, and the old input context is discarded before replacing storage; this is **not** seamless restoration of input-method composition. Each task has a distinct AppKit view identity. These behaviors require native verification and are not yet release evidence.

Owned deterministic tests cover delayed journal acknowledgement with newer typing, typing during failed cleanup with fresh-ID rotation on retry, removed-task recovery discovery, and a concurrent saved-body change during recovery review. Active failed-save drafts now have an explicit discard confirmation guarded by reviewed content and revision. Exact abandonment intent is retained separately from an older durable cleanup candidate, so failed cleanup can be retried without permitting a stale dialog or removing an external file. New typing during discard becomes a retained conflict. These tests and native IME/Undo/caret/sibling/window-close/quit/relaunch verification, plus any compile/test findings, must pass before merge. No notification settings, real user tasks or original dirty worktrees were changed.

CI checkpoint 8a0e331 (run 43260200360) failed application compilation on missing main-actor annotations in the AppKit coordinator. The separately executed already-built test suite passed 768 XCTest cases, but this is not a passing build. The follow-up adds explicit main-actor isolation to the coordinator/controller. New discard/quit overlap tests and final release packaging still require the next exact-head CI run.

Further static concurrency review added explicit exclusion between recovery Resume and Keep Saved, preserved early native conflict candidates across awaited recovery loading, and required the displayed conflict snapshot for discard. Controlled held-load/held-cleanup tests cover these orderings. These are draft corrections, not native behavioral evidence.
