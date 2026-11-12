# Atomic Summary Save as Note

## Source-backed defect

Summary creates a live note through legacy creation, performs a second update to remove task metadata, then shows Saved as note unconditionally. A failed write can publish a phantom note and false success.

## Bounded contract

Persist one final Inbox note with the exact edited report body, undated/untimed, without tags, priority, duration or reminders. Honor insertion order; no URL enrichment or changes to report generation, filters or presets. Publish only on successful persistence. Failure keeps report text and options, displays a wrapped red footer error, leaves Save as Note available for explicit retry and never displays a success message for that attempt. Successful save retains the editable report as before. On Summary only, the existing workspace-error banner reserves bottom layout space instead of overlaying the report footer. Other screens keep their existing banner placement. Further intentional saves may create further notes; no new deduplication policy.

## Verification

Reproduce failed write/retry against the old two-step path. Verify no phantom note and one durable retry, exact report text/Inbox/clean metadata under nonempty defaults, insertion order and reload. Native owned Summary failure/retry, full tests/build, independent review and exact-head CI before merge.
