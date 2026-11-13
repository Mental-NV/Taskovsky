# T-R contextual-control observation — 13 November 2026

Status: reference evidence recorded; implementation decision deferred, not a parity completion.

## Bounded native observation

Existing Taskovsky Codex thread performed AX-only TickTick observation, completed turn `01a1d58a-bd2a-7fd3-b9fa-d322a614f7eb`. Existing owned QA tasks were used without modification. No capture, permission or system-setting change was attempted. Taskovsky QA was not launched.

- Ordinary empty task exposed a title, empty description and **Add Subtask**.
- Checklist task additionally exposed two editable checklist rows and a trailing empty row; **Add Subtask** remained separate.
- No named Checklist/Subtasks heading, progress control or formatting toolbar appeared in these accessibility trees. This establishes only AX exposure, not visual absence.
- Focusing the empty description exposed the editor; its context menu showed standard text commands. Unlabeled buttons prevented identifying the embedded-checklist entry action.
- Prior [task evidence](../ticktick-spec/tasks.md) distinguishes linked child tasks from embedded checklist rows; these must not be conflated.

Transient dialogs were closed and the worker stopped. Previous Calendar selection could not be restored using a named accessibility control: TickTick was left on the QA search results. No task data changed.

## Taskovsky source comparison

At main `88f9e57`, `TaskDetail.swift` renders both embedded Checklist and linked Subtasks sections for every task, including empty editable tasks. Both entry fields are immediately available. Notes omit these sections. This is a concrete difference in exposed controls, but is not sufficient evidence to delete or relocate an entry point.

## Next acceptance gate

Before a contextual-visibility implementation, identify the reference's explicit embedded-checklist entry action and observe its empty/populated transitions using supported UI access. Record whether existing content can be cleared without losing the entry action, and preserve Taskovsky's separate checklist and linked-subtask functionality. Do not infer hidden visual controls from missing AX labels, guess pointer coordinates or bypass capture denial.

Until then, keep existing functionality unchanged. No screenshot, pixel layout, toolbar/progress visibility, or complete detail parity claim is made. Dark theme, local-file recovery and notifications remain deferred.
