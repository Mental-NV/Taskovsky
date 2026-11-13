# Current integration baseline

**Current milestone scope — November 13, 2026:** The user explicitly deferred Dark mode and prioritized the white/light theme for Tasks and Calendar on Mac and iPhone. Light-theme visual and interaction verification is the active acceptance target; Dark-mode matching and native Dark-mode QA are deferred, not passed. Preserve existing semantic colors and appearance support; this decision does not remove Dark-mode code or force a system appearance. Other affected functional, gesture, keyboard and accessibility checks remain required. Historical dark results and unchecked cases remain evidence with their original limits. See [the appearance-scope decision](changes/light-theme-priority-2026-11-13.md).

Checked November 12, 2026 at main [`dc6c7ab`](https://github.com/Mental-NV/Taskovsky/commit/dc6c7ab0e2ef2303e17d31fe8ff79a19a1daa0ac). This is a source/integration pointer, not a new full feature or visual-parity certification. Future work must inspect the latest source and working-tree state rather than assume this pinned revision remains the newest.

## Implemented versus proposed

- [Package.swift](../Package.swift) declares macOS 14 and iOS 17, the Mac executable, and separate Domain, Workspace and Clipboard libraries. The Mac Core target retains AppKit services and rendering.
- The separate [iPhone Xcode project](../Mobile/TaskovskyMobile.xcodeproj/project.pbxproj) and [phone views](../Mobile/App) exist in main. The iPhone app is not merely a design proposal. [Mobile instructions](../Mobile/README.md) cover its local build and simulator workflows.
- Both platforms use local files. Cross-device sync, external Calendar integrations and App Store release are outside this pre-alpha baseline. Separate platform representations and reduced mobile components remain intentional.
- [Business requirements](spec/business.md), [Mac UI](spec/ui-ux.md) and [iPhone specification](spec/iphone.md) have been maintained incrementally through feature changes. Their dated introductory snapshots and historical rollout notes are not evidence that later code is absent. Individual proposals and unverified acceptance cases are not automatically implemented.

## Latest integrated checkpoints

| Change | Integration | Evidence scope |
| --- | --- | --- |
| Due-date task grouping | [PR30](https://github.com/Mental-NV/Taskovsky/pull/30), `6ad11b4` | [Local/native/CI record](spec/verification.md#task-due-date-grouping); no full TickTick grouping claim |
| Linked-subtask List disclosure | [PR31](https://github.com/Mental-NV/Taskovsky/pull/31), `5783072` | [Mac and iPhone bounded checks](spec/verification.md#task-subtree-disclosure) |
| Calendar keyboard Undo observation | [PR32](https://github.com/Mental-NV/Taskovsky/pull/32), `6302601` | [One all-day Month drag](ticktick-spec/calendar-keyboard-undo-2026-11-12.md); documentation only, not a new Undo implementation |
| Mac long numbered-list gutters | [PR33](https://github.com/Mental-NV/Taskovsky/pull/33), `dc6c7ab` | [Geometry, tests and native editing](spec/verification.md#mac-numbered-list-gutter); Mac presentation only |

Earlier integrated features and their limits remain in the [verification ledger](spec/verification.md) and [parity tracker](parity-implementation-status.md). Do not reimplement them from an old checkout or old absence statement. Preserved dirty desktop/mobile worktrees are historical drafts, not the release baseline; never reset or discard them merely to match main.

## Evidence discipline

This documentation correction checked source manifests, platform targets, the cited merge commits and linked verification records. It did not rerun application tests, perform a whole-codebase audit, or certify every old sentence in the specifications. Full visual/interaction parity, accessibility and physical-device verification remain incomplete. New changes must reconcile the affected contracts with source, record observed TickTick behavior separately, and pass their own review/tests.
