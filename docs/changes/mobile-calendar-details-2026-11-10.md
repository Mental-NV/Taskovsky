# CAL-MOBILE-DETAILS-001 — Show Details in iPhone Calendar

The supplied R22 TickTick screenshot shows Show Details off and describes its scope as the mobile List and Month views. The official guide identifies time and list as examples. Taskovsky applies the switch to its equivalent Agenda view and Month. [Reference screenshot](../spec/iphone.md) · [TickTick Calendar View Options](https://help.ticktick.com/articles/7055782085826445312).

- Calendar → View Options → Show Details stages a local preference. Done applies and saves it. Cancel keeps the previously saved choice. Existing settings start with it off.
- Agenda shows the time and source list under the title. All-day entries show All day. Timed points show one clock value and timed ranges show start and end in the display time zone. A range crossing midnight shows dates with its two clocks. Inbox and missing list references have distinct labels.
- Month preserves the same number of visible cards per zoom level and increases row height to fit a second line. Narrow cards use a compact start clock or list label, and the card’s accessibility value retains both details. The metadata does not claim an additional touch target or displace the move and resize controls.
- This iPhone preference affects Agenda and Month only. Other modes, Mac presentation, filters, projection, schedules, recurrence, card actions and the workspace file retain their existing behavior. The optional setting uses the existing scoped settings write.
- Verify staged Cancel, saved relaunch, display-zone clock labels, Agenda and Month rendering, and unchanged workspace and adjacent settings. External Calendar capabilities remain deliberately deferred in the parity record.

[Verification](../spec/verification.md#mobile-calendar-show-details).
