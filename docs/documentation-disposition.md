# Documentation reconciliation record

This documentation-only change aligns current specifications to source commit `cfdec454acff91285ac00beaa20c0cf0f0961ee1` and separates future proposals from the baseline. Relative to that merged main commit, application source, tests, fixtures and package/build configuration are unchanged. Existing PR #1 is brought forward without reverting PR #2; all code fixes come from the merged baseline.

## What changed and why

| Previous document or area | Disposition | Reason |
| --- | --- | --- |
| Root README | Short setup/capability overview and canonical links | Removed duplicated detailed status and unqualified historical validation claims; source-derived detail now has a dedicated home |
| `docs/parity-implementation-status.md` | Keep path; replace with the one current feature-parity tracker | User wants a separate tracker; reference confidence, implementation and verification must remain distinct |
| Prior parity implementation narrative | Preserve in [archive](archive/parity-implementation-history.md) | Historical 80/258/370 test counts and successive QA passes are not simultaneous current gates |
| `docs/ticktick-spec/taskovsky-parity.md` | Navigation pointer, including the prior integration anchor | Keeps one tracker; the merged local-only integration decision table moves to that tracker |
| TickTick `coverage.md` | Reference research coverage only | Removes stale Taskovsky-status column; inspection gaps remain useful |
| Tasks, lists/tags, scheduling, search/filter reference pages | Retain evidence; remove obsolete Taskovsky comparisons | Code now contains features those paragraphs called absent; reference unknowns remain unknown |
| `docs/ticktick-spec/scheduling.md` | Preserve path | `CustomRecurrence.swift` cites it; no source comment/code change is needed |
| Matrix, Focus, Habit, Countdown and `modules.md` | Move to [excluded-module archive](archive/ticktick-modules/modules.md) | They are intentionally out of current scope, not accidental junk; unique research remains available |
| November 1 parity audit | Move to [archive](archive/ticktick-parity-audit-2026-11-01.md); repair machine-local links | Its implementation proposals/status are historical; the observations still have provenance value |
| November 8 REA findings | Keep dated report with historical notice | Preserves evidence, independent choices and limitations; absent local artifacts are not treated as committed proof |
| Calendar research/evidence | Restore active `docs/ticktick-spec/calendar.md`; remove the redundant archive copy | PR #2 implements local Calendar and adds dated UI/resource evidence; source paths and unique research are retained |
| November 8 review reports | Preserve both merged reports unchanged and link from [verification](spec/verification.md) | Five earlier and four Calendar findings have merged fixes, with regression evidence and explicit live limits |
| New business/UI/architecture/workflow documents | Add distinct canonical responsibilities | Establish spec-driven development without copying a second competing framework |

No research with unique observations was discarded merely because it is outside scope. No byte-identical duplicate warranted unconditional deletion. The overlapping module overview remains archived because it contains unique Habit quantity-editor observations. Old rewritten content remains recoverable in Git history; archives are not a second active backlog.

## Ongoing maintenance

Current behavior belongs in business/UI specifications, implementation progress against TickTick belongs only in the parity tracker, and experiment history belongs in dated evidence. Do not reintroduce current-looking implementation columns in reference pages. Update links when moving documents and preserve source provenance paths where code refers to them.

The architecture and iPhone documents are proposals. Merging this documentation must not be interpreted as completing the refactor, implementing an iPhone app, approving an unbounded implementation task, or fixing defects through prose. The ledger records only corrections already in the merged source.

The refresh also adds the requested [macOS CI/CD proposal](spec/ci-cd.md), covering hosted tests/builds, exact-revision evidence, permissions, costs and GUI/minimum-OS limits. No workflow or repository setting is implemented by this Markdown-only PR.
