# Parity implementation status

The implementation follows the order in the [audit](/Users/mental/Projects/Taskovsky/docs/ticktick-parity-audit-2026-11-01.md). The existing exclusions remain in force; task and note content is plain text.

| Priority group | Implemented |
| --- | --- |
| Task rows | Whole metadata items fall back by available width, without fragmenting tags or dates. Titles remain centered, with double-click inline renaming. Task/sidebar type is normalized to 14 points. |
| Quick entry | Recognized dates are highlighted in the text field, with a date preview and ignore action. Tag suggestions support existing/new tags and names with spaces. Shift-Return opens and focuses a plain-text description. Rejected date recognition remains rejected for that draft. |
| Search | Yellow match highlighting, relevant body/subtask snippets, task/note/state icons, list symbols/context, independent completion controls, View more, keyboard selection with scrolling, compact filters, multiple lists/tags, and Inbox selection. Save as Filter preserves those criteria. Dates use the task time zone. |
| Settings | Requested card grouping, supplied recognition and time-zone copy, borderless gray value menus, neutral navigation selection, corrected icons, smaller headings, and template previews. Only the four requested tabs are present. |
| Scheduling | Compact shortcut strip and expandable time/reminder/repeat rows, Clear/OK, Escape cancellation, multiple timed/all-day defaults and editable task reminders, recurring-day preview, Endlessly/Until date. The end date is inclusive in the task time zone. |
| Lists and details | Persisted collapsible sidebar sections, list symbols/custom emoji, notes retained inside lists, with a separate Note section for date grouping, anchored tag picker, smaller expanding description editor, template insertion from an empty editor, and Add Subtask wording. Existing/custom templates are retained. |
| Motion and feedback | Sidebar animation retained; disclosure, regrouping, and feedback transitions added with Reduce Motion support. Won't Do moves immediately into history with a crossed checkbox; the completion toast is centered 60 points above the bottom. Five-second completion Undo and the existing generated completion chime remain. |
| Persistence fixes | Optional fields preserve legacy records. Default reminder provenance is recorded; automatic reminders follow schedule edits, while manual reminders remain explicit. All-day recurring reminders preserve wall time across daylight-saving changes. Applying a template filters deleted tags. |

**Verification completed**

- Twenty-two automated tests passed with zero failures. They cover existing persistence, migration and recovery, plus recognition rejection and descriptions, list symbols/legacy records, Inbox filters, recurrence end boundaries/Undo, reminder provenance, and daylight-saving transitions.
- Debug compilation and release packaging are checked separately. The app is built at [build/Taskovsky.app](/Users/mental/Projects/Taskovsky/build/Taskovsky.app).

**Live verification after unlocking**

Quick entry date highlighting/preview, tag insertion, Shift-Return description focus and saving, ignored recognition, inline rename, search snippets/highlights/arrow-key selection, Smart List visibility changes, the local Summary pane, multiple default reminders applied to a new task, completion Undo, and Won't Do/history have been checked through Computer Use. Both temporary Taskovsky tasks were moved to recoverable Trash. The disposable TickTick task was also moved to Trash, and TickTick's temporarily exposed Summary was restored to Hidden. Reference reminder selections were cancelled without changing defaults.

The live pass corrected the date-chip layout, floating tag suggestions, settings value controls, extra top safe-area spacing, Note grouping, Summary semantics, multiple reminders, and completion-toast position. The final build also includes a title-selection gesture fix and Note ordering adjustment.

**Final verification status**

The temporary Taskovsky preferences have been restored and confirmed in the saved settings: Summary = Hidden, timed default = On time, all-day default = None. Both temporary Taskovsky test tasks and the TickTick probe remain recoverable in Trash. The final bundle has been relaunched; clicking a task title selects its detail correctly. Release build and code-signature/Info.plist checks pass.

The final UI was checked at the exact 780×500 content size using a debug-only resize shortcut after Computer Use could not operate the native resize handles reliably. Task rows stayed centered with whole metadata fallbacks, and detail text/controls wrapped without overlap. Window dimensions were restored. Sidebar section and whole-panel collapse/restore passed. The temporary QA bundle was removed, and the canonical release app is open. The debug resize command is absent from the release executable.

Exact TickTick panel drag limits/automatic-collapse thresholds, animation easing/duration, and audio identity/level are not claimed as measured matches. The 0.22-second sidebar curve and original generated completion chime remain approximations. Core recurrence, multiple-reminder persistence/defaults, daylight-saving, legacy decoding, and Undo are covered by 22 passing tests. The local Summary, multi-reminder settings applied to a new task, completion Undo, and Won't Do/history have also passed live checks.
