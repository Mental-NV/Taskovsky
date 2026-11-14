# iPhone contextual progress summary

Status: implemented; local review/tests/native acceptance passed, exact-head hosted CI pending. Base `9783fa7`.

## Evidence and bounded decision

The user requested visible Tasks/Calendar parity and specifically questioned always-visible zero progress. The live mobile audit saw an ordinary blank-body task without a visible progress row and a checklist task showing 33%. This does not establish a universal TickTick progress-visibility rule. A fresh November 14 read-only reference check stopped at locked iPhone Mirroring; no login, task mutation or permission change was attempted.

For this bounded Taskovsky slice, checklist-free tasks at zero progress omit the permanent progress row. Nonzero manual progress and checklist-derived progress (including zero) retain existing display and editing behavior. This is a conservative presentation choice informed by observed states, not a claim of exact TickTick behavior. Notes continue to omit task progress. No stored values, completion rules, schema or persistence change.

The completion control retains its existing long-press **Set Progress** menu. Eligible tasks additionally expose a named accessibility action and touch-and-hold hint, so hiding a zero row does not remove the editing route. Completed, Won't Do, deleted and otherwise refused lifecycle targets retain their existing refusal/read-only boundaries.

Description editing, rich payloads, formatting controls and editor recovery are unchanged. Their exact mobile reference behavior remains unverified; do not use this change to close those gaps. Dark mode, synchronization and notification work remain deferred.

## Acceptance

Ordinary zero-progress idle screenshot; detail checkbox Set Progress reachability; nonzero draft Cancel leaves zero hidden; existing row-checkbox route saves 100 without completing task; relaunch shows nonzero; resetting to zero hides row immediately and on reopen; checklist zero and completed-derived values visible; styled-description regression unchanged. Source review, full suite, release/signature, native Simulator checks, actual screenshots and exact-head hosted CI are separate gates.

Actual VoiceOver action invocation, locked-state exhaustive combinations, physical-device and pixel matching remain unverified unless recorded in the final receipt.

## Local verification receipt

Independent source/test review clean. Full 826 XCTest +38 Swift Testing passed; release build and strict signature verification passed. Two native tests passed on the owned iPhone 13 Pro Simulator: progress flow including detail long-press entry, Cancel, row entry, save100/relaunch/reset0/reopen and checklist0/100; styled-description preview/protection regression. The initial progress test query matched both background and detail checkboxes; scoping it to the detail ScrollView corrected the test ambiguity without a production change.

Actual ordinary/no-row and nonzero/visible-row screenshots were inspected; no unrelated description/formatting layout improvement is claimed. The owned Simulator was already shut down after testing; original user QA device and data were untouched. Reference Computer Use stopped at the lock screen and did not interact with task data.

Exact-head hosted CI remains pending. Named accessibility action is source-reviewed; actual VoiceOver invocation and exhaustive locked-state combinations remain unverified. This is not a complete detail or pixel-parity claim.
