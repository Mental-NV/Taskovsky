# TASK-BOARD-DISPLAY-001 — Desktop Board display settings

Status: implemented for Mac status, section and grouped Boards. [Verification](../spec/verification.md#board-display-settings).

The [TickTick Kanban guide](https://help.ticktick.com/articles/7055782353376903168) documents Small, Medium and Large widths in the desktop Board's Display Settings. The [TickTick changelog](https://ticktick.com/public/changelog/en.html) also describes choosing whether to display the task input. The guide does not establish the installed Mac build's exact dimensions or persistence scope.

Mac Board More → Display Settings offers Small, Medium and Large at 210, 250 and 320 points. Medium preserves Taskovsky's existing width. All Mac Board columns share the locally saved width, including status, named section, date and list columns. Scrolling and drop targets follow the new geometry. Short Boards keep the header and columns at the top of the pane. Done saves the choices. Cancel and Escape leave them as they were.

Show Task Input is on by default. Turning it off hides the empty idle quick entry in Board. An active or populated draft stays visible. New Task, New Note and a section's add button can reveal the input even when the option is off. List and Timeline retain their own input behavior.

Both settings are Mac presentation preferences in the existing local defaults store. They change neither tasks nor workspace JSON settings. The iPhone continues to use the width available for its paged Board. Grouping defaults, section/card ordering, exact reference dimensions, and external services are separate.
