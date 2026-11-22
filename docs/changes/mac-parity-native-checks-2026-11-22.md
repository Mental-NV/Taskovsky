# Bounded native checks: Search, Duration, and Calendar tags

November 22, 2026. Disposable, isolated Taskovsky fixtures on Mac, light appearance. No personal records or captures were published. These are local runtime checks against separately dated observations, not new TickTick sessions, geometry scores, or approval of whole families.

## MAC-11 Search staging

The guarded Search build used the tested Search source in [#180](https://github.com/Mental-NV/Taskovsky/pull/180), unchanged in the later Mac baseline. In Full Search → All Lists, two of three children displayed a mixed folder mark. Staging did not change results. Cancel discarded the draft at normal and minimum width; in a separate wide local check, OK returned only those two lists and retained selection on reopening the picker. In All Tags at 1060×700 and 382×584, All, No Tags, and both synthetic tags were present. Two tags staged together without changing results, and Cancel restored All Tags. A separate local No Tags → OK returned just the untagged record and retained the choice on reopen. Task fixture bytes were unchanged.

[The dated TickTick observation](../ticktick-spec/search-and-filters.md#full-search-controls) establishes list/tag staging, a mixed folder mark, and Cancel. It does not establish equivalent results on OK, multi-tag matching, or mixed-predicate save/reopen semantics.

## MAC-13 Duration

On the native product tree in [#189](https://github.com/Mental-NV/Taskovsky/pull/189), the Tasks popover at 1060×700 and 382×584 kept the month grid visible while exposing inline Start/End fields and Add Duration. In the staged Today 00:00 path the initial fields were 23:00 on the previous day to 00:00 on Today. Escape discarded the draft without changing fixture bytes. A separate stored Moscow overnight range loaded correctly at both widths: November 21 at 23:00 to November 22 at 01:00, 2h, All-day off. It was not edited or resaved.

[The dated TickTick sample](../ticktick-spec/scheduling.md#duration-mode-and-time-zones) replaced its date grid after switching to Duration and showed 00:00→01:00 in that particular after-Time path. That does not establish fresh defaults, mode-switch retention, persisted conversion behavior, or exact geometry. The compact app-only capture omitted the expanded Taskovsky footer even though accessibility exposed it; it came into view after collapsing Duration. A separate compact check on the merged [exact revision](https://github.com/Mental-NV/Taskovsky/commit/d636bbd3c84292ab45d13d8bed31b2d2f969af24) reproduced that evidence limit: the tool returned one app raster and no separately targetable popover image. No guessed out-of-bounds pointer action was attempted. Escape again closed the popover with no write. The available capture cannot establish physical clipping or pointer reach while expanded.

## MAC-15 Calendar tags

On the same guarded [#189 product tree](https://github.com/Mental-NV/Taskovsky/pull/189), Week at 1060×700 and compact 780×584 had three synthetic all-day tasks: tagged directly with the parent, tagged with its child, and untagged. Parent-only selection included the direct and descendant cases, child-only showed the child case, and All reset the tag selection and restored all three. The task data matched the seed after testing.

[The dated TickTick sidebar observation](../ticktick-spec/calendar.md#sidebar-and-creation) establishes All, Lists and Tags controls, not descendant membership or the same filter combination rules. This supplements the earlier disclosure-only resize check in [#170](https://github.com/Mental-NV/Taskovsky/pull/170).
