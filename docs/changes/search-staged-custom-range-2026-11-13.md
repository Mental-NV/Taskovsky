# SEARCH-DATE-001 — Staged Search custom range

Status: Approved bounded interaction slice under the user’s autonomous Tasks/Calendar light-theme parity direction.
Base: main `a941153`, isolated branch. No original working tree changes.

## Evidence and outcome
[Retained TickTick observation](../ticktick-spec/search-and-filters.md) records Custom opening Due from and Due to fields, Cancel and disabled Confirm when both bounds are absent. Current Taskovsky immediately toggles Custom and exposes live inline date controls. Stage custom bounds in a popover: opening/editing does not change results, Confirm applies both optional bounds together and enables Custom, Cancel/Escape/outside dismissal discards. Confirm is disabled with neither bound. Existing selected date rules and inclusive date matcher stay unchanged; unknown TickTick date-combination behavior is not invented.

Custom always reopens the applied bounds for editing. An explicit Remove Custom Range menu action disables only Custom, retaining inactive dates for the next opening. Existing noncustom choices retain their current toggle behavior. No data schema, persistence, iPhone, shared matcher, relative-date choice or rich-editor change.

## UI and checks
Use native optional Due from/Due to date fields, 320pt popover, standard Cancel/Confirm footer. Preserve enabled-but-inverted range behavior (no matching dates); no new normalization. Two absent bounds cannot confirm even via Return. Native keyboard, repeated edit/cancel, Escape, outside dismissal, one-sided/two-sided ranges, remove and saved-filter mapping require checks. Light theme only. Tests/source review do not prove visual parity; capture denial is respected.
