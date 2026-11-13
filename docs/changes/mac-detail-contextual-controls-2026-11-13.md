# MAC-DETAIL-CHROME-001 — Contextual task-detail controls

Status: implemented; source review, Mac tests/release, hosted CI and scoped native accessibility interaction passed. Visual reference comparison remains limited as recorded below. Approved by the user's November 13 request to fix the always-visible progress row and rich formatting bar. Mac only; iPhone presentation is unchanged.

## Evidence and boundary

The source baseline `77b646c` rendered a progress row for every task and a formatting toolbar above every editable description. The user reports that both should be hidden by default.

On November 13, the current [Task Details guide](https://help.ticktick.com/articles/7055782408586526720) explicitly says to hover over the line below Due Date to set progress. Its image depicts a thin separator/progress line and contextual percentage. The [Editing and Formatting guide](https://help.ticktick.com/articles/7507338582718152704) depicts a bottom toolbar with an A-style footer toggle. These public images were inspected directly.

A bounded accessibility-only observation of installed TickTick compared the existing plain QA task and two-item checklist task. Focusing the description did not expose named formatting controls; neither sample exposed a named progress control. Unlabeled controls mean this does not prove visual visibility. The original selection was restored and records preserved. Prior denied screen capture was not retried. Exact reference hover dimensions, nonzero idle-progress appearance and toolbar persistence remain unverified; the geometry and per-selection reset below are explicit Taskovsky choices, not recovered measurements.

## Contract

- Replace the permanent progress row with the header separator: a 1-point line, accent fill proportional to the existing progress value. At zero, only the separator is visible. A 12-point transparent hit surface does not reserve vertical layout space. Hover, keyboard focus or an open progress editor reveal the whole-number percentage; leaving hides the label. The existing editable progress popover, Cancel/Done, stale-save handling and checklist-derived value remain unchanged. Locked/checklist tasks expose their progress read-only. Notes retain an ordinary separator.
- Formatting starts collapsed and is revealed by a labeled `textformat` footer button. The horizontally scrollable toolbar appears immediately above the footer, below the task's scrolling content; toggling does not focus/rebuild the native editor or mutate content. Button label/value communicates expanded state. Switching tasks or entering a locked detail collapses it; returning starts collapsed. No preference/schema is added.
- Bold/italic/underline shortcuts belong to the focused editable native description, not the presence of the toolbar. Keep native selection, pending styles, IME safety and Undo. Do not redirect a title-field shortcut to the body.
- Keep existing task title, schedule, tags, checklist/subtask layout, data semantics and reader behavior. This does not redesign the entire detail panel or fix deferred description-save recovery.
- Light-theme acceptance only at the user's latest direction. Dark appearance is explicitly deferred, not a merge gate for this change.

## Acceptance

Plain task zero-progress idle; hover/focus reveal and leave; set nonzero progress/Cancel/Done; automatic checklist progress; note/archived/Trash; default-hidden formatting, reveal/hide, narrow scrolling tools, selection changes, field focus and formatting shortcuts, Undo, identical-body task switches, popovers and existing formatted content. Build/unit/native interaction evidence must be recorded separately. Screen-capture denial is not permission to replace missing app interaction evidence with render-only checks.

## Verification receipt

PR69 source `4071083` and documentation head `a85208d` passed hosted run `43380149914`: Mac tests/package and iPhone Simulator compilation. Local Mac validation passed 769 XCTest +38 Swift Testing tests, release packaging and strict signature verification. Independent source review found no blocker.

Scoped accessibility-only native QA on the same source verified default-collapsed formatting, reveal, selected-word Bold, Undo, title-focus Command-B exclusion, and collapse after switching tasks. Progress Cancel preserved zero; Done saved 1%; a checklist exposed read-only 50%; a note exposed no task-progress control. Narrow-window task detail opened by double-click, with working formatting toggle and progress popover. The QA app quit, and original bundle, disposable fixture and preferences were restored byte-for-byte; Codex stopped.

No screen capture was retried. Idle percentage appearance, exact toolbar placement, pointer hover, narrow-toolbar scrolling and visual TickTick comparison remain unverified. Dark appearance is deferred. The bounded functional fix is not a claim of pixel-perfect layout, exhaustive native accessibility/focus coverage, or complete task-detail parity.
