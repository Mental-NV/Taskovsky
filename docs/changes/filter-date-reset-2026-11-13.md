# FILTER-DATE-001 — Normal Date All reset

The retained [filter observation](../ticktick-spec/search-and-filters.md) exposes All and specific dates. Taskovsky's Normal editor toggled `.all` beside specific OR rules, making selected dates ineffective because `.all` always matches. This is an internal consistency repair, not a claim about TickTick's unverified combination semantics.

Reuse the Search date-selection helper as `DateRuleSelection`: explicit All clears the selection; specific actions discard `.all` and preserve other specific rules. Empty means unrestricted. Existing stored selections are not normalized on initialization or name-only save; custom bounds, other criteria and Advanced expressions are unchanged. Reset can hide inactive custom fields without clearing their draft; reselecting Custom restores them. All displays selected for either empty or legacy `.all` data.

Tests retain the actual matcher regression and specific/custom cases from Search. Native acceptance must check reset→specific narrows saved filter; Cancel leaves prior saved criteria; reopening retains new criteria; untouched legacy filter name-only save does not rewrite its date rules. No pixel/parity or screenshot claim. Tests/release/review/native/CI pending.
