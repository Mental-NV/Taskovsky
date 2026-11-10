# CAL-MOBILE-WEEK-SWIPE-001 — Swipe between weeks on iPhone

The supplied R20 TickTick capture shows seven day columns and one time ruler on an iPhone. The TickTick 5.0 release notes describe swiping left and right to browse weeks. [iPhone reference register](../spec/iphone.md) · [TickTick changelog](https://ticktick.com/public/changelog/).

Week fits seven days in the available width when the time rulers leave room. Each day stays at least 46 points wide. Extra rulers can make the grid scroll horizontally, and all seven days remain reachable. A horizontal swipe toward the next or previous week pages immediately when the grid fits. With overflow, a swipe first pans within the current week. A subsequent outward swipe from the edge opens the adjacent week at the corresponding entry edge. Vertical scrolling stays within the week.

Navigation uses the existing civil-week calculation and writes neither tasks nor preferences. The arrows, Today, date headers, folded hours, range handles and drag-edge dwell keep their separate actions. Compact Week cards use leading title clipping and smaller move grips to preserve space in the narrower columns. The complete title remains on the card's accessibility label. Day and Multi-Day keep their existing widths.

[Verification](../spec/verification.md#mobile-calendar-week-swipe).
