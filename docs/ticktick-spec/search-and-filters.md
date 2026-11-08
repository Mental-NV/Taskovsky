# Search and saved filters

Evidence: installed TickTick macOS app, light appearance, 2 November 2026, in an account with existing tasks, lists and tags. Search queries can enter recent-search history; no existing task, tag or filter was changed. The filter-creation dialog was canceled without saving. Examples below describe control behavior, not the user's private task content.

## Quick search

Selecting the search rail icon opens a centered floating search dialog over the current workspace, with a focused Search field, magnifier, close control, blue focus underline and empty-state illustration. Its explanatory copy is `Search tasks, tags, lists and filters`. Entering a query updates the contents without submitting. An unmatched query displayed `Not found yet? Try Cloud Search.`; Cloud Search was not invoked.

For a query matching task titles, bodies and a list name, the dialog grouped results under **Tasks** and **Lists**. The first five task results were displayed followed by **View more**. Rows displayed a task checkbox or note icon, title, muted list context and, where applicable, a body snippet. Matched substrings were highlighted in yellow/orange in both title and snippet. The observed results included a completed task. The query matched regardless of capitalization in the observed title/body examples. A query matching several known trashed probe titles showed no local result in this particular experiment; this does not establish all Trash/cloud search semantics.

Pressing Return with the field focused opened a full search view headed `Search` plus the query in blue, an edit-pencil icon and **Save as filter**. Initial results were loaded asynchronously: the accessibility count rose from 11 to 21 without another user action. Tests must allow results to settle before comparing counts. The full view displayed result rows with title, optional excerpt, list context and dates, and included active tasks, notes, completed and Won't Do records under **All Status**. Search term highlights remained visible. The right pane had an empty illustration until a result was selected. The behavior of result selection, the keyboard result navigator, View more, pagination and cloud search still needs independent verification.

## Full-search controls

Four compact, right-chevron menus were visible beneath the header:

| Control | Observed choices / behavior |
| --- | --- |
| All Dates | All Dates, This Week (with displayed date range), Next Week (range), Last Week (range), This Month, Last Month, Custom. Custom opened `Due from` and `Due to` fields, Cancel and a disabled Confirm while both fields were empty. The displayed weeks started Sunday in this account; the effect of week-start settings is untested. |
| All Lists | All, Inbox and a nested, expandable folder/list tree. Selecting two lists produced a checkmark on each and an indeterminate mark on their parent folder; selection remained staged until OK or Cancel. Cancel was used. |
| All Tags | All, No Tags and individual tags. Two tags could be checked simultaneously; OK and Cancel appeared at the bottom. Cancel was used. The matching rule for multiple tags is not established. |
| All Status | All Status, Uncompleted, Completed and Won't Do. Selecting Completed replaced the result set with muted checked rows in the observed query; the menu label changed to Completed. |

These are **full-search** date choices. The saved-filter Date menu has a different set of criteria; do not conflate the two. Relative dates, custom-range boundary inclusion, list/tag combinations, No Tags semantics, and the interaction between status and date remain untested.

## Add Filter dialog

Save as filter opened **Add Filter** with Normal and Advanced segments, a required Filter Name field, and Cancel/Save; Save was disabled while the name was empty. Normal mode showed Lists, Tags, Date, Priority, Include and Type controls. The keyword from the search appeared in Include. Priority offered All or checkboxes for High, Medium, Low and None; Type offered All or Task/Note checkboxes. The accessibility tree also exposed an Assignee row, which was not visible in the captured portion of this dialog; its display condition requires investigation.

The Normal Date selector's accessibility tree listed All, No Date, Overdue, Repeat, Today, Tomorrow, This Week, Next Week, This Month, Next Month and a Duration range. Selecting No Date and Overdue showed selection indicators on both before the selector was dismissed with Escape. Their logical combination and persistence were not tested.

Advanced mode displayed a sequence of `Filter`, `Logic`, `Filter` placeholders and a plus button. Clicking plus added another Logic/Filter pair. The placeholders appeared disabled in the observed account state; the reason and the expression semantics have not been established. No filter was saved, so whether all current full-search criteria transfer to the saved filter is unknown.

## Taskovsky implementation status

Use the [dedicated parity tracker](../parity-implementation-status.md) for current search/filter support and differences. The earlier model comparison in this reference document is superseded. TickTick combination semantics above remain unverified; Taskovsky's AND/OR/NOT rules are independent implementation choices, not proven reference equivalence. Cloud Search remains outside the current Taskovsky scope.
