# Taskovsky / TickTick parity audit — 1 November 2026

Taskovsky implements the requested feature set, but several everyday interactions and much of the visual presentation still differ from the installed TickTick app. The most useful next pass would address task-row compression, entry feedback, search results, and settings consistency before smaller decorative differences.

This is an inspection and proposal. No application source, settings, tasks, or lists were deliberately changed during this audit. A temporary TickTick quick-entry draft was cleared without submitting it. Search navigation may update TickTick's recent-search history.

**Scope and evidence**

Compared the installed apps through Computer Use: main workspace, selected task/note presentation, quick search, TickTick full search, Smart Lists settings, More settings, task scheduling, and live date/tag recognition. Reviewed Taskovsky's source for the corresponding behavior. The five supplied settings screenshots remain reference material.

“Observed” means visible in the running apps or the supplied screenshots. “Source” means established from Taskovsky's implementation. “Needs verification” means a reference interaction or measurement remains outstanding. Different screenshot capture scales were encountered, so raw screenshot pixels are not treated as logical UI points.

The Mac locked near the end of inspection. Advanced search controls in the installed TickTick also opened a Premium prompt. Those limits affect the remaining measurements and behavior checks listed below; no purchase or account change is proposed.

**Confirmed differences and proposed changes**

| Priority | Area | Finding | Proposal |
| --- | --- | --- | --- |
| High | Task rows | Observed: the Focus tag can shrink to a tiny fragment between the checklist count and date, even at a normal window size. Fixing vertical alignment did not fix horizontal compression. | Define which metadata remains visible as space shrinks. Hide lower-priority metadata as a whole instead of squeezing it into unreadable fragments; retain full values in the detail pane and tooltips. Compare with TickTick at matching task-pane widths. |
| High | Quick entry | Observed: TickTick colors recognized date text, previews “Tomorrow, 16:00,” and offers `Create tag "audit"` while typing `Review tomorrow at 4pm #audit`. Taskovsky's plain TextField has none of this preview. Source: recognition runs when the task is created. | Add live recognition preview and tag suggestions, with a way to inspect or reject the recognized date before submission. Continue respecting the existing recognition/removal settings. |
| High | Search results | Observed: TickTick highlights matches in both title and description, shows snippets around the match, displays the list, and offers “View more.” Taskovsky quick search displays titles and generic circle icons; it gives no explanation when only the description/checklist matched. Its full search uses the beginning of the body rather than a match-centered snippet. | Share one search-result presentation between quick and full search: highlighted matches, relevant plain-text snippets, task/note/status icons, and list context. Match the reference's result expansion affordance. |
| High | Search interactions | Observed/source: TickTick search results expose task checkbox controls. Taskovsky uses the entire result as an open-item button; the leading circle is an image. Full-search controls are native boxed pickers in a horizontal scroller, unlike TickTick's compact text dropdowns. | Make completion a separate result action, preserving the existing Undo behavior. Restyle date/list/tag/status controls. Verify keyboard selection and multi-selection semantics against the reference before changing them. |
| High | Scheduling presentation | Observed: TickTick uses a compact date popover, an icon shortcut strip, time/reminder/repeat rows with chevrons, and Clear/OK. Taskovsky presents a “Schedule” heading, labeled shortcut cards, Due date/Time/Reminder checkboxes, a Repeat picker, and Clear/Cancel/Save. | Rebuild the existing scheduling controls around the reference layout and wording, retaining plain-text task content and the configured week-start/week-number/time-zone behavior. This concerns task scheduling only, not the excluded Calendar tab. |
| High | Repeating schedules | Observed: TickTick shows a weekday-specific repeat label, highlights future occurrences in the date grid, and exposes an “Endlessly” row. Source: Taskovsky has only none/daily/weekdays/weekly/monthly/yearly and no recurrence end condition. | Add a recurrence editor and preview for the observed task scheduling behavior, including an end condition. Inspect the remaining repeat choices first; do not assume all reference options from the current menu snapshot. |
| Medium | Sidebar sections | Observed: TickTick exposes Lists, Filters, and Tags as expandable sections. Source: Taskovsky's headings are static labels with always-visible add buttons. | Make these sections collapsible, preserve their state, and match disclosure/add-button placement and hover behavior. |
| Medium | Inline task editing | Observed: TickTick task titles in the list expose editable text fields. Source: Taskovsky rows render static Text and require the detail pane for edits. | Add the equivalent inline rename gesture and keyboard behavior, keeping selection and checkbox clicks independent. Verify the reference's precise click/keyboard trigger first. |
| Medium | Notes placement | Observed: TickTick's existing note appears beside tasks within “Getting Started.” Source: Taskovsky always puts notes into a separate “Notes” group. | Preserve notes in the appropriate mixed task/list order instead of forcing a Notes group. Keep notes inside lists; do not add a Notes sidebar tab. |
| Medium | Settings controls | Observed: Taskovsky uses raised native popup controls with blue arrow blocks; TickTick uses right-aligned gray values and small unobtrusive chevrons. Taskovsky has blue selected settings navigation, larger headings, and a visible titled window bar; the reference uses a more restrained selection and different window/header treatment. | Match the settings shell, heading hierarchy, value controls, spacing, and selection colors for the four requested tabs only. |
| Medium | More settings grouping | Observed: TickTick places Date Recognition, Tag Recognition, and URL Parsing inside one Smart Recognition card. Taskovsky makes three separate sections/cards, repeats “URL Parsing” as both heading and row, and adds a “More” page heading. Task Default is one long card rather than the three reference groups, with Reset Default inside it. | Use the supplied grouping: one recognition card, three task-default cards, and Reset Default below them. Restore the supplied explanatory text and labels where behavior agrees. |
| Medium | Date & Time settings | Source plus supplied reference: Taskovsky combines week start and week numbers into one card. The reference separates week start, week numbers, and time-zone groups after the excluded Additional Calendar row is removed. Wording also differs, such as “Show Week Numbers” versus “Show Week Numbers(W).” | Align the grouping and copy with the reference, omitting Additional Calendar as requested. Verify each setting's effect in the task date picker. |
| Medium | Icons | Observed: several symbols differ semantically, not just in stroke. In Settings, Taskovsky uses a bar chart for Summary, `#` for Tags, a circled check for Completed, and a circled minus for Won't Do. Reference icons are a text/document symbol, tag outline, checked square, and crossed square. Taskovsky's sidebar and Settings also use inconsistent symbols for the same destination. | Establish one icon mapping across sidebar, settings, search, and detail controls. Match outline weight, optical size, and alignment. Match the intended meanings before polishing individual glyphs. |
| Medium | Task/list typography | Observed: the hierarchy, density, and icon-to-text proportions differ between the apps. Source: Taskovsky fixes task/sidebar text at 16 points, task rows at 40, sidebar rows at 38, and workspace titles at 20. Search results use a separate 14-point treatment. | Measure a common reference window on the same display scale, then use shared sizes and spacing across matching surfaces. Avoid treating screenshots from different capture scales as proof of point-size differences. |
| Medium | List symbols | Observed: TickTick's lists can display distinct pictorial/emoji symbols; Taskovsky displays the same colored three-line symbol for every list. Source: its list model/editor provides color, but no separate icon choice. | Support a list symbol within the existing list editor and use it consistently in navigation, task context, and search. |
| Low | Detail spacing and placeholders | Observed/source: Taskovsky uses “Description,” “Checklist,” and “Add checklist item,” whereas the inspected reference uses “Write something or use a template” and “Add Subtask.” Its minimum 150-point task editor / 300-point note editor can leave a large gap before tags and checklist content. | Match applicable plain-text placeholders and content spacing. Offer template insertion from the empty detail area if the reference interaction is retained. Keep rich formatting deferred. |
| Low | Template presentation/content | Supplied reference/source: the gallery concept is present, but card proportions, preview text, and built-in wording differ. For example, the reference begins “Reflection on y…” while the built-in Taskovsky entry is “Reflect on yesterday.” | Match the three supplied cards and their text/layout, then verify their edit/use/menu interactions in TickTick. Preserve custom templates. |
| Low | Empty states and rail | Observed: Taskovsky uses its own checklist illustration/text, a decorative checkmark logo above another Tasks checkmark, and a separate Settings gear. These produce different visual balance from the reference. | Refine only the in-scope empty states and Tasks/Search/Settings navigation. Keep Taskovsky branding and continue excluding account and unrelated module controls. |

**Animation and completion: partially matched, not established as exact**

- The sidebar now animates. Source: its easing curve is `(0.4, 0, 0.2, 1)` over 0.22 seconds. This was an approximation, not a measured TickTick duration. A timed comparison is still required before claiming identical motion.
- Source: the sidebar automatically disappears below 860 points; its adjustable width is clamped to 160–320 points. Task pane width is based on a stored fraction, with minimum task/detail widths. The exact TickTick defaults, drag limits, auto-collapse thresholds, and restored widths have not been established under equivalent conditions. Compare them with normalized window and panel sizes.
- Source: task-group disclosure changes, completion regrouping, checkbox changes, and the feedback toast have no explicit matching animation. Their timing, interruption, and reduced-motion behavior should be checked together after the Mac is unlocked.
- The five-second Undo mechanism exists. Source: completion and Won't Do update immediately, and feedback is a bottom-right message with an icon-only Undo button. The exact TickTick toast wording, position, row-removal delay, and multiple-completion behavior were not retested in this audit. These are verification items, not confirmed failures of Undo.
- The completion sound is an original generated 0.22-second chime, not a verified sound match. Compare its duration, level, and interaction timing by listening; do not report sound identity from source inspection.
- Won't Do exists and can reopen tasks. Its current toast says “Task abandoned,” while the UI destination says “Won't Do.” Confirm the reference's wording and transition before standardizing the feedback.

**Other behavior requiring reference verification**

Taskovsky stores one reminder per task and offers a limited set of timed/all-day defaults. The remaining TickTick reminder choices and custom-default interactions were not inspected before the lock. Similarly, Taskovsky's Summary currently means items updated in the last seven days; its equivalence to TickTick's Summary has not been demonstrated. Both deserve a focused check within the already requested scheduling and Smart Lists scope.

Advanced search filtering is available locally in Taskovsky, but the reference app gates its controls behind Premium. Keep Taskovsky's local filtering available. Do not copy purchase prompts or claim that all filter semantics were validated. Its full-search view currently selects one list and one tag, while the saved-filter editor supports multiple; that inconsistency should be resolved after verifying the desired reference interaction.

**Proposed implementation order**

1. Fix unreadable row metadata and normalize the task-row layout across ordinary lists, saved filters, and search.
2. Add live quick-entry feedback and bring search result content/actions into line with the observed reference.
3. Align settings structure, wording, icon mappings, typography, and controls with the supplied screenshots.
4. Align task scheduling UI and complete verified recurrence/reminder behavior, with persistence/migration coverage for any model additions.
5. Finish sidebar disclosures, inline editing, mixed note placement, templates, and plain-text detail spacing.
6. Measure panel geometry and motion, then tune completion, Won't Do, Undo, and sound together.

For acceptance, use equivalent data and logical panel sizes in both apps, including the 780×500 minimum Taskovsky content size. Check long titles, emoji, tags, checklist counts, dates/times, notes, empty states, keyboard navigation, Undo, and reduced motion. Test settings through their resulting behavior, not only their saved values.

**Excluded from the proposal**

Calendar tab, Eisenhower Matrix, Pomodoro, Habit Tracker, countdowns, accounts/statistics/sign-in, server sync, OS notifications, help, voice dictation, rich formatting, and Premium/account flows. About remains “Taskovsky Pre-Alpha.”

**Implementation references**

- [Workspace, panel layout, sidebar, rows and feedback](/Users/mental/Projects/Taskovsky/Sources/Taskovsky/App.swift:150)
- [Search presentation and actions](/Users/mental/Projects/Taskovsky/Sources/Taskovsky/SearchView.swift:4)
- [Settings layout and icon mappings](/Users/mental/Projects/Taskovsky/Sources/Taskovsky/SettingsView.swift:51)
- [Task detail and scheduling](/Users/mental/Projects/Taskovsky/Sources/Taskovsky/TaskDetail.swift:140)
- [Schedule model](/Users/mental/Projects/Taskovsky/Sources/TaskovskyCore/Models.swift:4)
- [Defaults, filters and built-in templates](/Users/mental/Projects/Taskovsky/Sources/TaskovskyCore/Settings.swift:1)
- [Original completion sound generator](/Users/mental/Projects/Taskovsky/scripts/make-sound.py:1)

**Follow-up inspection during implementation**

The unlocked reference app confirmed that default reminders support multiple selections, and Summary generates an editable period report rather than a list of recently updated tasks. Both have been implemented locally. It also clarified the earlier notes observation: date grouping has a separate Note section, while a custom section can mix notes and tasks. The implementation retains the Note section when grouped by date. Completion moves immediately to history with a bottom-center Undo toast; Won't Do moves to the combined history with a crossed checkbox. See the [implementation status](/Users/mental/Projects/Taskovsky/docs/parity-implementation-status.md) for verification and remaining access-dependent checks.
