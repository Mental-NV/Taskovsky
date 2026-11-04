# Workspace and shared interface: initial observations

## Shell

In the observed light appearance, a narrow full-height gray rail sits at the left, with an account image near the top, vertically stacked module icons, and sync, notification and help icons near the bottom. The selected module icon is blue; unselected icons are gray. The task workspace places a navigation sidebar to the right of that rail, a central task list, and a right detail pane separated by fine vertical rules. Sidebar navigation and task content scroll independently. The screenshot used for this observation measured 2440 × 1330 raster pixels: rail right edge about x=122, sidebar right edge about x=547, and detail pane left edge about x=1822. These are one layout sample, not measured defaults or resize limits.

The sidebar presented smart lists, a Lists heading with folder disclosure triangles and list rows, Filters and Tags headings, a calendar subscription section, and Completed, Won't Do and Trash destinations. A task-list header contains the current title, a sidebar control, sorting and an ellipsis menu; an add-task field precedes grouped rows. A selected row used a pale gray rounded background. Unselected rows used thin separators; completed rows were muted, with a filled checked square. Notes used a document-like leading icon. The right pane showed task completion, due-date and priority controls along the top; title and description occupied the body, and list and more actions appeared near the bottom.

## Task lifecycle and feedback

Observed completion moves an item immediately to history and presents a transient dark toast centered near the bottom, with a contrasting orange Undo arrow. The exact animation, time to expiry and sound waveform have not been measured. Won't Do moves an item to the combined history with a crossed checkbox; the full transition and recurrence semantics still require inspection.

Moving the disposable task to Trash presented `Task deleted` and the same style of Undo affordance. On a deleted row, the observed context menu offered **Restore** and **Delete Forever**. Restore returned the probe to its original Inbox, removed it from the Trash list, left Trash selected and briefly displayed `Restored to "Inbox"` with a right chevron. The chevron action, confirmation wording and any timing rules are unverified. Do not infer permanent-delete behavior from its label alone.

## Pending design-system measurements

Measure actual display scale and points before deriving constants. Capture normal, hover, pressed, focus, disabled, selected, empty and error states for rail icons, sidebar rows, task rows, checkboxes, section headers, text fields, menus, popovers, dialogs, toasts and resize dividers. Record font family, size, weight, baseline and line height; sample solid colors away from antialiasing; measure padding, border, radius, icon stroke and hit target. Record min/max panel widths and thresholds through controlled resize and drag sweeps, and animation timing in both directions including reduced-motion behavior. Existing samples are insufficient to specify exact values.
