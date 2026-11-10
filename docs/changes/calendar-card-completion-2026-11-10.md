# CAL-COMPLETION-001 — Completion from Calendar cards

Status: implemented in the isolated Tasks and Calendar worktree. [Verification](../spec/verification.md#calendar-card-completion).

The [TickTick Calendar guide](https://help.ticktick.com/articles/7055782085826445312) describes showing check items and revealing task icons to complete tasks. The [August 28, 2019 Mac changelog](https://ticktick.com/public/changelog/en.html) describes checking a reminder-bearing subtask in Calendar. That older terminology leaves the current embedded checklist interaction and geometry open. Taskovsky applies the following rules to the embedded checklist rows it already projects. [TickTick's recurring-task FAQ](https://help.ticktick.com/articles/7055792921664028672) treats forecast occurrences as read-only.

- On Mac, the visible checkbox for a current checklist row completes or reopens that item. The card menu and accessibility action remain available when icons are hidden. Current task completion retains its existing action.
- On iPhone, Agenda supplies a separate 44-point completion button when icons are visible. The button, title and drag grip align vertically within the row. Current task and checklist cards in other views offer Complete or Reopen in their card menu and through accessibility actions. The title always opens the associated task. The menus retain their scheduling actions for eligible cards.
- Completing or reopening a checklist row changes only its item state and the task's modification timestamp. It preserves parent status, schedule, reminders, recurrence and the other checklist items. Show Completed controls whether the checked row stays visible. Show Checklist Items controls whether rows appear at all.
- iPhone task cards use the existing lifecycle action and its revision-bound Undo. Future previews and notes have no completion actions. Checklist rows continue to inherit their schedule. External integrations remain deferred.
