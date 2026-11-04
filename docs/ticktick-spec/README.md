# TickTick macOS reference specification

This is a working, evidence-led specification of the installed TickTick desktop app. Its goal is to make the product and its interface reproducible, including modules deliberately excluded from Taskovsky. It is not yet comprehensive: see the coverage ledger before relying on any section as complete.

## Reading the evidence

- **Observed** means the running app displayed the control or performed the action in the stated environment. An observation of a screen does not establish the behavior of every control on it.
- **Inferred** means a plausible interpretation that still requires an experiment. **Unknown** is a deliberate gap, not permission to guess.
- Screenshots in this pass were 2440 × 1330 raster pixels. The capture scale and macOS logical point dimensions have not been independently measured. Pixel positions in this pass describe that screenshot only, not a universal layout constant. Do not equate raster pixels with points.
- The reference data and account configuration affect visible counts, dates, sections, access to premium features, and results. Personal task contents are intentionally omitted from this specification.
- Original Taskovsky non-goals remain non-goals for implementation. The wider reference inspection documents them because the specification goal explicitly covers every TickTick tab; documenting a feature does not authorize implementing it.

## Documents

- [Coverage and parity ledger](coverage.md): inspected surfaces, gaps, and Taskovsky scope.
- [Workspace and common components](workspace.md): observed shell and task lifecycle, including Trash.
- [Visual measurements](design-measurements.md): initial settings geometry and sampled capture colors, with measurement limits.
- [Other modules](modules.md): Calendar, Eisenhower Matrix, Pomodoro, Habit, and Countdown initial observations.
- [Settings inventory](settings.md): navigation and initial Features/Notifications observations.
- [Task scheduling](scheduling.md): picker, duration and source-based comparison.
- [Task context and hierarchy](tasks.md): observed menu, pinning, child tasks and completion.
- [Lists, folders and tags](lists-and-tags.md): menus, editors and initial parity gaps.
- [Search and saved filters](search-and-filters.md): result states, criteria controls and model differences.
- [Calendar module](calendar.md): observed views, sidebar and options, with outstanding experiments.
- [Pomodoro and focus](focus.md): timer lifecycle probe, dialogs, settings and record management.
- [Habit module](habit.md): creation, check-in, logs, statistics and archive observations.
- [Countdown module](countdown.md): creation, card styles, context actions and archive observations.
- [Eisenhower Matrix](eisenhower-matrix.md): priority mapping, task menu and completed visibility.
- [Taskovsky parity baseline](taskovsky-parity.md): feature-by-feature implementation evidence and known gaps.
- [Earlier parity audit](../ticktick-parity-audit-2026-11-01.md) and [implementation status](../parity-implementation-status.md) contain additional observations and Taskovsky verification; an audit proposal is not itself proof of current parity.

## Environment and limitations

Inspection: macOS, installed TickTick application, light appearance, 2 November 2026. No version number, display scaling, system font metrics, motion measurements, or color sampling were verified in this pass. A complete specification requires controlled window-size sweeps, measured color and typography, hover and keyboard checks, screenshots with no private data, all menus and dialogs, error and empty states, and separate verification of every action and data transition.
