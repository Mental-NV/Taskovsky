# CAL-NAV-001 — Jump directly to a Calendar date

This local navigation change applies to BUS-027, UX-017, the iPhone Calendar screen and TT-033. TickTick's June 2 changelog describes opening a Calendar date picker from a custom shortcut. Taskovsky uses a standard View menu command and a default Shift-Command-J shortcut. The published reference establishes the feature, while the installed Mac shortcut and picker layout remain unverified. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

On Mac, the existing Calendar date header and the View menu's Jump to Date command open the same picker. The picker retains its month grid and adds a native field for entering a distant date. Clicking a grid date or confirming the field navigates immediately. Cancel, Escape and outside dismissal leave Calendar at its previous date. The menu command is available only in the active Calendar scene when its editors, dialogs and popovers are closed.

On iPhone, the Calendar month header opens a staged native date picker with Cancel and Go. Both platforms interpret the selected civil date in Calendar's configured time zone and keep the active view mode. A changed focus follows the existing navigation rules for temporary Agenda expansion. Date navigation does not write tasks or settings. Focus remains session state.

Verify distant date selection, confirmation and cancellation, preserved view mode, unchanged workspace and settings, and Mac shortcut scoping outside Calendar. The iPhone check uses a disposable simulator.

[Verification ledger](../spec/verification.md#calendar-date-jump).
