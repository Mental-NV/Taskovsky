# Atomic Mac template creation

## Source-backed defect

The unsectioned Mac `TaskStore.createTaskFromTemplate` publishes the new task before attempting a workspace write and returns its ID even when saving fails. The sectioned path already stages through `persistCreatedTaskAtomically`. A failed save can therefore appear successful and disappear on reload.

## Intended bounded change

Use the existing staged creation helper for the unsectioned path too. Return nil and leave published workspace data unchanged when writing fails or recovery protection blocks writing. Return the created ID only after persistence succeeds. Keep existing top/bottom insertion, destination/default-list rules, task/template contents and section behavior. Do not trigger URL enrichment. No schema, phone implementation or template preview UI change; no new TickTick parity claim.

## Verification plan

First reproduce failure with a disposable directory obstructing only the owned workspace file. Verify unchanged published data and failure result, restore the original bytes, retry and verify exactly one durable task at each insertion position. Cover sectioned creation and existing recovery protection. Run the complete Mac test suite, release build, independent review and exact-head CI. No new visual behavior is claimed.

## Results and limits

The original regression failed six assertions; the corrected full suite passed 670 XCTest and 37 Swift tests. Signed Mac release build and independent source review passed. The test retry explicitly invokes template creation again after restoring the writable destination; the generic storage Retry action does not replay the rejected operation. Template management saves and other store APIs are outside this fix. Exact-head hosted CI is checked before merge.
