# Settings: initial inventory

The account avatar menu in the observed shell contained Settings, Statistics and Sign Out. Settings opened a separate window with a left navigation sidebar and a scrollable right content area. The sidebar listed Account, Premium, Features, Smart Lists, Notifications, Date & Time, Appearance, AI Features, More, Integrations & Import, Collaborate, Sticky Note, Hotkeys and About. Items were grouped with vertical gaps. The selected item had a rounded light-gray highlight; labels and outline icons were gray. The Account page included a profile image and identity, Premium status, Sign Out and a red Delete Account control. No account action was exercised; personal values are deliberately omitted.

## Features

The observed page presented a two-column grid of feature cards with a heading, description, illustration and switch. The visible entries were Calendar, Eisenhower Matrix, Pomodoro, Habit Tracker, Countdown and AI. Focus Settings and Habit Settings links appeared under the corresponding cards. The switches were not changed, so their effects and persistence are unverified.

Focus Settings opened a separate window. Its visible controls included Sync Across Devices (marked with a Premium crown), Timer Option fields for Pomo Duration `25` minutes, Short Break Duration `5` minutes, Long Break Duration `15` minutes, and Pomos per long break `4`, followed by Auto-Start settings. These values are observed current values, not established factory defaults. The dialog is scrollable; other controls, validation and timer interactions remain uninspected.

## Notifications

The page contained a Notification row with a **Go to System Preferences** link and a Completion Sound selector. The observed sound menu contained **None**, **Jingle**, **Drip**, **Knock** and **Spiral**, with Jingle selected in this account. No sound setting was changed. A second card contained an Email Notifications switch, explanatory text saying the daily reminder limit is 50, and an Email row. The visible switch was off. Enabling the switch, notification delivery and additional content choices remain untested.

## Other pages

**Appearance** has Theme, App icons and Display segments. Theme displayed Interface Style and Follow System Dark Mode, color swatches named Default, Sky, Turquoise, Teal, Matcha, Sunshine, Peach, Lilac, Ebony, Navy, Gray and Dark, followed by illustrated seasonal and city series with Premium badges. Display showed Font Size (Normal, Large, Extra-Large), Sidebar Count (Show(All), Show(Hide Note), Hide(All)), List Color (Show/Hide), and Completed Task Style (Default/Strikethrough). Selected choices used a blue circular check. Effects, values and other scroll content have not been systematically tested.

**AI Features** showed Usage / Monthly Limit, a Privacy card with Help Improve AI, and Integration cards for MCP Servers and TickTick CLI. No setting or integration was changed.

**Integrations & Import** listed an existing integration separately, then Calendar options Local Calendars, Google Calendar, Outlook Calendar, Exchange Calendar, iCloud Calendar, CalDAV and URL; Integrate options Google Calendar, Notion, Zapier and IFTTT; Email options Gmail, Spark and Outlook Email; and Others including Subscribe to TickTick, Add tasks via email, Shortcuts, Slack, Amazon Alexa and Chatmind. No connection or import was initiated.

**Sticky Note** explains that a task's context menu can open it as a desktop sticky note. The page showed color swatches (many with Premium badges), Font Size, Pin by Default, Restore Default Size and Default Grid Spacing choices None, Normal, Large and Extra-Large. No values were changed.

**Hotkeys** contains Hotkeys and Shortcuts segments and grouped rows for General, Global Action, Task, Quick Add, Edit Tasks, Navigation, Switch Views and Sticky Note. The displayed entries include Sync `⌘S`, Undo `⌘Z`, Redo `⇧⌘Z`, Command Menu `⌘K`, task delete `⌘⌫`, Quick Add tokens `*` for date, `!` priority, `#` tag, `~ / ^` list, and `@` assignment; navigation sequences include `G` then `T` for Today and `G` then `G` for Trash. Calendar view rows show `D / 1`, `W / 2`, `M / 3`, and `T` for Today. User-configurable hotkey values may differ; this inventory is not a test of actual key handling.

## Smart Lists

The page presents three rounded groups: All, Today, Tomorrow, Next 7 Days, Assigned to Me, Inbox and Summary; Tags and Filters; Completed, Won't Do and Trash. Each row has a left icon/name and right-aligned current visibility with a small selector. In the observed account, All's selector offered **Show** and **Hidden**; Won't Do's offered **Show if not empty**, **Show**, and **Hidden**. This does not establish the options of every other row. No visibility was changed in this pass. The user's requested Taskovsky subset excludes Assigned to Me.

## Date & Time

Start Week on offers all seven weekdays, Sunday through Saturday. The page also shows Additional Calendar, Show Week Numbers(W), and Time Zone; the latter explains that enabling it permits a timezone selection when setting a task's time. Additional Calendar offered None, Chinese Lunar, Hebrew, Hijri (Civil), Hijri (Kuwaiti), Hijri (Saudi), Indian, Korean Lunar, Persian Calendar and Vietnamese Lunar. The user's requested Taskovsky subset excludes Additional Calendar. Values are account-specific; options were inspected without changing them.

## More: recognition and task defaults

More includes Language, window launch options, Smart Recognition, Task Default and Task Template. Smart Recognition contains Date Recognition, a dependent remove-text checkbox when available, Remove tags from task name, and URL Parsing. The page says date recognition detects date/time in added tasks and sets reminders, while URL parsing uses a URL's title as the task name. The observed account had Date Recognition off, tag removal checked and URL Parsing on; these are current values, not established factory defaults.

Task Default exposes Default Date, Default Date Mode, Default Duration, separate timed and all-day reminder defaults, priority, tag, list, insertion position and overdue section position, plus Reset Default. Observed menus:

- Default Date: None, Today, Tomorrow, Day after Tomorrow, Next Week.
- Default Date Mode: Date or Duration.
- Default Duration: 10, 15, 30 or 45 minutes; 1 hour; 1 hour 30 minutes; 2 hours; 2 hours 30 minutes; 3 hours; 1 day; Custom.
- Timed reminder selector: On time, 5 minutes early, 30 minutes early, 1 hour early, 1 day early, Recents, Cancel and OK.
- All-day reminder selector: On the day, 1, 2 or 3 days early, 1 week early, Recents, Cancel and OK; each displayed 09:00 in this account.
- Default Add to and Overdue Section shows at each offered Top of List and Bottom of List.

The reminder selectors were canceled without changing values. Selection semantics, custom duration, default application, Reset Default and persistence need controlled tests. The reference app's date-mode and duration defaults extend beyond the supplied Taskovsky settings screenshot and should be tracked separately from that originally requested subset.

### Task Template

The section displays cards with a title and a truncated preview of checklist content, plus a `How to create a template` link. Clicking a card opened a **Preview** popover with a scrollable checklist, **How to edit a template** guidance and a blue **Apply** button. Applying the observed checklist template closed the preview and created a new item in Inbox with the template title and checklist entries; the account's default list was Inbox. The resulting item's detail exposed each checklist entry separately. The created test item was subsequently moved to recoverable Trash. The behavior with a different default list, notes, due dates or other properties remains unverified.

The in-app creation guidance directs the user to the task/note detail's lower-right ellipsis and **Save as Template**. The editing guidance says to apply a template, modify the resulting item, and use **Save as Template** to replace the original. These are displayed instructions, not yet independently verified save/replace behavior. Card overflow, deletion, ordering, duplication and template persistence also remain untested.

Other Smart Lists, Date & Time and More evidence appears in the [parity audit](../archive/ticktick-parity-audit-2026-11-01.md). A complete spec still needs each row's choices, initial defaults versus current values, dependent controls, persistence and observable effect, plus the uninspected pages and nested dialogs. Taskovsky implements only the requested subset of settings; documenting additional reference pages does not change that scope.

