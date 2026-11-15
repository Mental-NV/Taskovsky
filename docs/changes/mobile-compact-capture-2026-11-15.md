# Compact mobile capture shell

Wide-first core slice based on observed T17: blank task capture is a low composer with title and date/priority/tag/list/more affordances, not a full editor of every field. Introduce a medium/large capture shell with title and those core navigation routes, plus More opening the existing full form. Exact geometry, keyboard and populated reference semantics remain unverified; no microphone imitation or external feature added.

All fields edit the existing capture draft. More retains text and metadata; existing full form retains note kind, description, sections, date ranges, recognition, templates, recovery/failure messages, Cancel/discard and frozen Retry. Prepared, template or nonempty-description drafts open expanded so protected/submitted contents remain visible. No capture domain or persistence change.

Acceptance pending: compact creation/metadata/More/Cancel, Calendar context, template and note handling, interrupted/recovered/failure flows, source review, full tests/release, actual Simulator screenshots and exact-head CI. Do not merge or claim reference equivalence before passing.

Verification: initial native Priority navigation failed because multiple NavigationLinks competed in one Form row. Explicit route buttons corrected it. Review also identified title editor replacement risk; title is now one stable view outside the expanding metadata branch. Full 827 XCTest + 38 Swift Testing, release/signature and corrected source review passed. Two native compact/Calendar cases and six range/recovery/template/note/retry regressions passed. Actual screenshot inspected; exact low-sheet geometry and IME behavior remain unverified. Current main integration preserves PR116 tests and docs; final integration checks and exact-head CI pending.
