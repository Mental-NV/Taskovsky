# SEARCH-WEEK-001 — Visible week-range context

Status: Approved bounded slice under autonomous light-theme Tasks/Calendar parity direction.
Base main `b054f8c`; isolated branch.

Retained [full-search reference](../ticktick-spec/search-and-filters.md) records displayed ranges for This Week, Next Week and Last Week. Taskovsky currently shows only labels. Add localized inclusive calendar-date captions to those three existing menu choices. Derive intervals from the same calendar/week-start/time-zone rules as the matcher, never fixed seconds or hard-coded Sunday. Other options, toggling/OR combinations, custom-range draft, saved filters and iPhone remain unchanged. Reference setting effects and exact pixel/text format are unverified; this closes visible context only, not whole date-menu parity.

Tests cover Sunday/Monday starts, previous/next week across year boundaries, DST and non-week choices; native AX verifies visible/accessibility labels and unchanged selection/Custom/Save as Filter. No screenshot retry/settings change. Existing capture limitation remains explicit.
