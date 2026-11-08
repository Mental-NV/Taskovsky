# Baseline evidence and known deviations

## Snapshot and evidence levels

Source baseline: [`30045bac5355b793a8c155b87ffe58584cb29fb8`](https://github.com/Mental-NV/Taskovsky/commit/30045bac5355b793a8c155b87ffe58584cb29fb8), inspected November 8, 2026. Its application code is unchanged from [`18732856fb3b9d2d5b9ca55a621dabbea3aeb761`](https://github.com/Mental-NV/Taskovsky/commit/18732856fb3b9d2d5b9ca55a621dabbea3aeb761); the later commit adds the static review report.

| Evidence | What it establishes | What it does not establish |
| --- | --- | --- |
| Source at the baseline commit | Implemented fields, branches, constants and command paths | Runtime correctness, visual equivalence or successful builds |
| Existing named tests linked by the specs | Cases represented by test source | Execution or a current pass |
| Prior implementation/QA narratives | Historical reported results | A current reproducible gate; several logs/captures are not committed |
| TickTick observed controls/actions | That observation in the recorded state | Unexercised semantics or blanket parity |
| Proposed contracts | Intended future design | Existing implementation, product approval or assigned work |

The documentation reconciliation ran no application build, test suite, native UI session or fresh TickTick experiment. Documentation checks cover links, source references and changed-file scope only. The prior reported 370-test pass remains [historical](../archive/parity-implementation-history.md), not a new result. There is no committed `.github` workflow configuration or separate native UI-test target in this baseline.

<a id="known-deviations"></a>
## Known deviations carried forward

These are the five prior **static source findings**, not newly reproduced bugs. The review links pin their original evidence. Code remains the description of current behavior, while the expected outcome below is a proposed corrective acceptance condition. This documentation change does not perform fixes or close findings.

| ID | Observed source deviation | Acceptance condition for a separately authorized fix | Evidence |
| --- | --- | --- | --- |
| DEV-001 | Opening Custom seeds the outer schedule draft; canceling its sheet can leave that rule available for outer OK | Nested Cancel/dismissal preserves prior none/simple/custom recurrence; Done and Clear have distinct explicit effects | [Finding 1](../code-review-findings-2026-11-08.md#1-canceling-a-new-custom-recurrence-can-still-save-a-weekly-rule) |
| DEV-002 | Recurring-parent subtree cloning normalizes all-day descendant reminder instants to midnight before shifting | Preserve reminder wall-clock times and relative days, including multiple reminders and DST boundaries | [Finding 2](../code-review-findings-2026-11-08.md#2-cloning-an-all-day-subtask-resets-its-reminder-time-to-midnight) |
| DEV-003 | A weekend roll across month boundary can change an every-N-month cadence anchor | Keep nominal cadence independent of the adjusted occurrence; verify the documented March/May/July case and further successors | [Finding 3](../code-review-findings-2026-11-08.md#3-weekend-adjustment-can-change-an-every-n-month-recurrences-cadence) |
| DEV-004 | Block formatting can include the unselected paragraph when a selection ends at its start | Respect the exclusive UTF-16 selection end when expanding block ranges; cover newline boundaries, emoji, undo and reload | [Finding 4](../code-review-findings-2026-11-08.md#4-block-formatting-can-include-the-paragraph-after-a-selection) |
| DEV-005 | Empty-editor quote handling can re-arm a quote instead of toggling it off | A second quote toggle returns empty typing state to plain and stays plain on input, toolbar read, extraction and undo | [Finding 5](../code-review-findings-2026-11-08.md#5-quote-formatting-cannot-be-toggled-off-in-an-empty-editor) |

Do not mark a feature `Verified` just because a fix branch exists. When another agent's fix is merged, inspect that exact commit, refresh affected baseline descriptions and parity rows, and attach the actual regression/visual results. Keep original review provenance; record resolution commit and verified acceptance cases here instead of rewriting historical evidence.

## Evidence record for future changes

For each affected acceptance case, record requirement/case ID, platform, source/PR commit, test or manual procedure, environment, fixture, command, date, result (`passed`, `failed`, `not run`) and durable artifact. Include explicit limits. A result for one platform or state does not verify another.

Visual evidence additionally needs OS version, window content dimensions versus frame dimensions, screenshot scale, light/dark appearance, locale/timezone, text size, contrast and reduced-motion settings. Use disposable data. Check the affected component state matrix and interruption paths, not only a happy-path screenshot.

Until a case has such evidence, the source-derived baseline is **implemented, runtime unverified in this reconciliation**. Individual specifications and parity rows provide the relevant source/test links; avoid duplicating every link in this ledger.
