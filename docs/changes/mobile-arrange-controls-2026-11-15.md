# Mobile Arrange control hierarchy — November 15, 2026

Read-only TickTick observation (Codex turn `01a1dc45-9ba2-74a3-a850-57bd35008e04`) showed List/Tag/Priority immediately below the Arrange Tasks title, overflow at top right and Filter pinned at the bottom. PR106 supplied the side panel but retained a large form section of controls.

This bounded presentation slice moves the existing grouping choices to a top segmented control, the existing source selector to a bottom Filter menu, and Include overdue to the overflow. Close remains visible at top left. Existing projection, source choices, nested editor, drag payloads, scheduling and recurrence behavior are unchanged. No task or preference writes are added by these controls.

Reference Filter uses a centered staged hierarchy dialog. This candidate deliberately retains the existing immediate single-source menu (Calendar sources/Inbox/active list); it does not label Calendar sources as All, introduce unsupported multi-selection, or claim full dialog parity. Overdue's placement is an implementation choice preserving existing functionality; its exact reference location was not observed. Width fraction and typography remain approximate.

Required gates: independent review, full suite/release/signature, actual Simulator top/footer controls, grouping/source/overdue state, nested schedule Cancel/save, drag/Undo and recurrence Cancel/occurrence/series. Inspect neutral screenshot and exact-head CI before merge. Preserve original worktrees and user QA fixtures; no accessibility-layout polish or personal reference image publication.

## Verification receipt
Full 826 XCTest + 38 Swift Testing, release and strict signature verification passed. Independent source/tests review and rereview passed. Four final native Simulator tests passed: grouping/source/overdue/nested schedule Cancel-save, drag/Undo, recurring scope Cancel/occurrence/series, and panel dismissal. Owned Simulator is shut down; original user QA data and worktrees unchanged.

Initial native run exposed a Menu AX value assertion that UIKit does not expose, plus screenshot-confirmed selected-source substitution for the Filter caption and title truncation. Corrected explicit Filter Menu label and compact accessible Close; overdue action explicitly says Include/Hide overdue, verified after reopening. Final screenshot `/private/tmp/TaskovskyArrangeControlsFinalScreens/A8410FEA-7F6E-40ED-8F59-78A8BA98F125.png` shows full title, grouping and footer label. Result `/private/tmp/TaskovskyArrangeControlsFinal.xcresult`. Native runtime logged a UIKit UIReparentingView hierarchy warning during menu interaction; all tested flows completed, no observed failure, not claimed warning-free.

Exact final-head hosted CI is required before merge. This remains partial hierarchy parity, not reference row density or centered Filter dialog.
