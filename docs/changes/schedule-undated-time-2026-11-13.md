# SCHEDULE-TIME-001 — Undated Time entry

Reference: [native scheduling observation](../ticktick-spec/scheduling.md), Opening and structure: activating Time on an undated task selected today and exposed 00:00. Taskovsky disabled the Time row for undated tasks, preventing that path.

Bounded change: Time remains enabled with no date. Activation seeds the schedule calendar's today/start-of-day, enables time, opens the existing time editor and refreshes existing default reminder logic. The change is staged: Escape/outside dismissal does not save; OK uses the unchanged schedule save path. An inactive duration is not revived by this explicit undated choice. Existing dated-task expansion and time values remain unchanged. Other undated rows retain current behavior.

No focus, half-hour dropdown, precise layout, or full date-picker parity claim. Native acceptance: undated activation/time editor; Escape leaves undated; OK persists today's timed date; dated time preserved; No date then Time resets to today. Tests cover calendar zone/day seed, DST and dated no-op. Release, native AX and CI are pending. No capture/settings or notification permission changes.
