# Mac organization dialogs and Calendar split verification

These are bounded Taskovsky checks in disposable signed Mac QA builds. They do not establish fresh TickTick parity.

## MAC-12 Organization dialogs

- On the [#199](https://github.com/Mental-NV/Taskovsky/pull/199) product tree at 382×584, **Tasks sidebar overlay → folder context menu → Add List** opened with blank List name focused. The first Escape dismissed the sheet and left the sidebar open. That exact case did not reproduce the older failure in [draft #184](https://github.com/Mental-NV/Taskovsky/pull/184); neither draft attempt was integrated. A separate passive diagnostic also saw dismissal from typed Name, after Tab to Custom emoji, and at wide blank Name. It did not establish the original failure's cause or any TickTick key behavior.
- On the same product tree at 382×584, **Lists heading context menu → New Folder** focused blank Folder name and disabled Save. Typing enabled Save; Escape closed the form without closing the Lists overlay or writing. Reopen was blank, and explicit Cancel also wrote nothing. Folder Save was not tested.
- On the same product tree at 382×584, **parent tag context menu → Add Sub-tag** focused the blank name, disabled Create and preselected the parent. Explicit Cancel of a typed draft wrote nothing. A fresh Create saved exactly one child with the chosen name, color and parent, confirmed in Edit and in the saved workspace. No top-level Add Tag or Tag Escape was tested.
- The [#200](https://github.com/Mental-NV/Taskovsky/pull/200) regression case used temporary write rejection only in the disposable workspace. Before the fix, Create dismissed the editor and displayed a tag that was not saved. The corrected compact Add Sub-tag kept its focused draft, color and parent with an error and unchanged saved bytes. Restoring the path and pressing Create once in the same sheet saved exactly one child. The unit regression checks that failure does not publish a tag in memory; the native modal obscured the sidebar during the failed attempt. Edit Tag and broader recovery were not part of the fix.

## MAC-16 Calendar beside Tasks

At 1060×700 with the Tasks sidebar hidden, **Show with Calendar → Week → Next → Hide Calendar** removed the Calendar pane; reopening returned to the current week. No workspace data changed. This was an explicit toggle, not transient-state retention across the outer split width threshold.

Opening the split previously kept the Quick Entry title but discarded the description. [#199](https://github.com/Mental-NV/Taskovsky/pull/199) retained title, body and expanded Description through two Show/Hide round trips at that width. No write occurred until an explicit Add saved exactly one undated Inbox task with both fields, and then cleared the composer. Focus moved back to the main window on remount. The ignored-date flag and failed capture were not checked natively in this run.
