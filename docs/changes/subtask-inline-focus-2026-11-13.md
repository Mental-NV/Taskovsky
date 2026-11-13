# Mac Add Subtask inline focus

Base: main `993679c`. Isolated branch `fix/subtask-inline-focus`.

## Scope and evidence

The Tasks middle-panel Add Subtask command currently creates `New subtask`, selects it, and leaves its title in reading mode. The observed reference in [Tasks research](../ticktick-spec/tasks.md#child-task-creation-and-completion) starts inline editing immediately. This bounded change requests inline title editing after successful creation when the child is included in the current list projection. It reveals the child group and scrolls to its row. Existing task creation, title default, hierarchy, storage, selection, rename commit and Escape behavior remain unchanged.

This does not implement automatic next-child creation, blank-title persistence/cleanup, filtered-view navigation, Board/Timeline, or the right-panel child composer. In date/tag/filter views an undated untagged child may be excluded; do not change filter semantics or switch destinations merely to focus it. Explicit creation editing works in pop-up detail mode without changing ordinary double-click behavior.

## Contract

A one-shot request targets only the newly created, selected, editable row. Failure to create emits no request. Leaving the destination, selecting another task, or removing/locking the child must not steal focus later. Existing double-click rename and existing rename protection against collapsing subtasks are preserved. Enter commits through the current title path; Escape retains the already-created default-title child and cancels only the rename. No data/schema or file persistence redesign.

## Acceptance

- Create under an expanded/collapsed parent; row appears indented and inline title receives typing immediately.
- Offscreen child scrolls into view, including named-list section/group layouts.
- Type then Enter, type then Escape, repeated creation, navigation interruption, popup-detail mode, read-only/Trash and failed creation.
- Preserve selection, IME composition and existing row rename/drag/disclosure controls.

## Verification

Implementation, automated tests, independent review, hosted CI and scoped native QA pending. No screenshot or complete TickTick parity claim. Light theme is the active target.
