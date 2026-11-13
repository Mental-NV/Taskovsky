# FILTER-ALL-001 — Priority and Type reset choices

Reference: [Add Filter observation](../ticktick-spec/search-and-filters.md) explicitly lists All alongside High/Medium/Low/None and All alongside Task/Note. Taskovsky's Normal editor provided individual toggles only, requiring multiple deselections to reset.

Add All as the first action with a checkmark for empty selection in both menus. All clears only that draft set; it does not select all enumerated values or alter other criteria. Individual toggles retain existing semantics. Empty selection already means unrestricted in the shared matcher. Initialization, persistence, Advanced and Save/Cancel remain unchanged.

Acceptance: multiple priorities→All clears selection and broadens matching after Save; Type Task→All admits notes; Cancel preserves saved filter; another criterion survives both resets; reopening displays All selected. No screenshot/pixel claim. Native, full tests/release/review/CI pending.
