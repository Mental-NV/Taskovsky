# Bounded capture-title recognition observation — November 12, 2026

Reference: installed TickTick macOS 8.2.20 (922). This is an owned-data Computer Use probe, not a general title-validation specification. Existing settings were read without changing them.

## Observed

- Date Recognition was off. Entering only `tomorrow` in the main list quick-entry field showed no recognition highlight and created a literal `tomorrow` task without a due date. This does not establish behavior with recognition enabled.
- Remove tags from task name was enabled. A tag-only token offered Create tag. The first Return selected/created the tag and changed the token to a recognized chip; the next Return created a task displayed as **No Title**, carrying that tag. Therefore an empty post-recognition title is not evidence that TickTick should reject the submission.
- The prior Calendar view and Tasks selection were restored. No settings or preexisting task records were modified. Two new owned test tasks and one owned tag were left in a previously verified QA list; they were not deleted.

## Taskovsky interpretation

The Mac creation pipeline can produce an empty title after recognized text removal. Its task row already displays **Untitled** for that value. This probe does not justify adding rejection or replacing persisted text. The label wording differs, but this is not a demonstrated missing workflow. Mobile capture currently has its own final-title validation; this desktop-only probe does not establish the correct iPhone behavior.

## Static evidence and limits

MacDisassembler class discovery found five AddTask-named classes. Selecting the AddTaskBarViewController declaration returned 24 methods. Its Add action and one direct internal callee both produced complete pseudocode within their selected extents. The action was a retain/call/release wrapper; its callee used Swift allocation/weak-reference and further calls. This was useful navigation evidence, not proof of the main list quick-entry validation policy or all reachable behavior. No engine change was needed.

No product change follows from this evidence. Date-only capture with recognition enabled, other entry surfaces, appearance/accessibility and mobile remain unverified.
