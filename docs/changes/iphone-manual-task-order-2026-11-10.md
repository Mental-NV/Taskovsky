# TASK-ORDER-001 — Manually order task rows on iPhone

In Tasks List view, choose Default Order and turn off Group by Created Date. Drag a row grip to the upper or lower half of another eligible row to place it before or after that row. The row offers Move earlier and Move later as accessibility actions. Rows reorder among visible siblings in the same pinned, ordinary or named section group. Active rows in read-only lists and history rows stay outside manual ordering. Existing drops on section headers keep their section-assignment behavior.

Only the stored task array changes. The task retains its title, rich description, list, section, parent, schedule, timestamps, status and other fields. The rest of the array keeps its relative order. Computed sorting and creation grouping suspend row reordering, and switching back restores the saved order. Releasing outside an eligible row preserves the saved order. The shared ordering operation rejects ambiguous stored IDs. iPhone saves through its revision-checked local workspace writer.

TickTick documents manually dragging notes and tasks to change their order. Taskovsky uses its existing stored order, visible groups and dedicated row controls. [TickTick sorting guide](https://help.ticktick.com/articles/7055780476358754304) · [Taskovsky business rule](../spec/business.md#bus-019)

[Verification record](../spec/verification.md#iphone-manual-task-order)
