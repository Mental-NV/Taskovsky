# Taskovsky iPhone product and implementation specification

**Status:** Early pre-alpha specification, version 0.5, 8 November 2026. User decisions incorporated; partial implementation follow-up recorded below. The separate iPhone target and many local workflows are now merged; full parity and acceptance remain incomplete. See the [current integration baseline](../current-baseline.md).

**Implementation follow-up, November 9:** The user subsequently authorized autonomous local desktop/mobile Tasks and Calendar work. The isolated `codex/mobile-local-prealpha` checkout is based on merged PR #4 at `6ee96eeb8f88e74a105c518de2202233ea528efa`. [Named list sections](../changes/task-list-sections-2026-11-09.md) adds the list organizer, grouped rows, Board sections, scoped capture and drag moves. [MOB-FOUNDATION-001](../changes/mobile-foundation-2026-11-09.md) adds a portable Domain product and characterized destination/recurrence seams; [MOB-PREVIEW-001](../changes/mobile-preview-2026-11-09.md) adds immutable read sessions and an iPhone read-only sample preview. [MOB-PERSIST-001](../changes/mobile-compatible-writes-2026-11-09.md) adds conservative title/plain-body repository patches. [MOB-EDIT-001](../changes/mobile-local-editing-2026-11-09.md) connects them to app-container storage and native field sheets with separate recovery drafts. [MOB-CAPTURE-001](../changes/mobile-capture-2026-11-09.md) adds local task/note creation and saved-template capture. Normal launches start empty and now have Add; explicit UUID-isolated Debug sessions use neutral fixtures. Desktop Calendar corrections are explicitly integrated by file/hash record; the original Desktop tree is preserved. This implements part of S5, alongside the earlier S1–S4 work. MOB-LIFECYCLE-001 adds completion, reopening, Won’t Do, pinning, movement and Trash through the shared domain. [Existing-task scheduling](../changes/mobile-task-scheduling-2026-11-09.md), [Calendar Arrange and direct edits](../changes/mobile-calendar-arrange-2026-11-09.md) and [Calendar preferences](../changes/mobile-calendar-preferences-2026-11-09.md) extend the same isolated checkout. [Rich description rendering](../changes/mobile-rich-description-preview-2026-11-09.md) adds the native read-only preview. The [task metadata editor](../changes/mobile-task-metadata-checklists-2026-11-09.md) covers priority, existing tags and embedded checklist items. [Linked-subtask controls](../changes/mobile-task-hierarchy-2026-11-09.md) add task hierarchy navigation and edits. [List and folder management](../changes/mobile-list-organization-2026-11-09.md) adds a drawer organizer and native editors. [Smart List settings](../changes/mobile-smart-lists-2026-11-09.md) add saved drawer visibility and ordering. [Saved filter authoring](../changes/mobile-saved-filters-2026-11-09.md) adds native Normal and Advanced editors. [Tag management](../changes/mobile-tag-management-2026-11-09.md) adds nested tags, pins, reorder, merge and delete. [Board](../changes/mobile-board-2026-11-09.md) adds per-list modes and status moves. The [filter layout follow-up](../changes/nested-filter-layout-2026-11-09.md) uses separate Mac and iPhone layouts. [Editable Summary](../changes/mobile-summary-2026-11-09.md) adds a native local report editor with exact-text Inbox note creation and capture recovery. [Local Search](../changes/mobile-search-2026-11-09.md) adds staged criteria, saved filters and recent queries. [Local Templates](../changes/mobile-templates-2026-11-09.md) adds management and task Save/Apply actions. [Local Settings](../changes/mobile-local-settings-2026-11-09.md) adds staged Calendar and capture preferences. [Current verification](verification.md#mobile-local-settings). Earlier documentation-only statements and source-freeze tables below describe the specification review, not the later implementation checkout.

**Current local editing contract:** Existing known-format tasks support title edits and plain-description edits when `richBody == nil`. Format description edits eligible task and note bodies using validated text and formatting transactions. The whole-document compatibility gate blocks rewriting unknown, malformed or implicitly sanitized payloads. Dirty Cancel offers Discard/Keep Editing; Done is explicit, duplicate submissions and IME-marked composition are guarded. Unchanged Done does not rewrite task files. A versioned, sequenced scratch file saves after 250 ms and on background opportunities; relaunch offers Resume/Discard without submitting. A force kill before an acknowledged scratch write can lose recent characters. Unknown scratch files are retained and block replacement. Stale revisions keep text and require an explicit discard/reload rather than automatic rebasing.

The normal root is the app's own Application Support `TaskovskyMobile/Local`; there is no path picker or real-data import. Only Debug accepts validated `--qa-session <UUID>` beneath `TaskovskyMobile/QA`. Invalid isolation arguments fail closed. Bootstrap never reseeds an existing pair and preserves partial/staged initialization failures. Files use iOS protection until first unlock; ordinary Application Support backup eligibility is retained under device settings, without a sync service or a tested backup/restore guarantee. Reader details use medium/large sheets; field editors expand. Dirty interactive dismissal is blocked with explicit Cancel available; a swipe-attempt prompt is not implemented. Native undo/selection exist, but physical-device IME, accessibility and keyboard edge cases remain unverified.

**Current capture contract:** Add opens a focused native task/note draft with description, explicit list/Inbox, date/time, priority, existing tags and saved templates. Shared policy shows defaults/context before submission and accepts removable recognition candidates; unknown tag text stays in the title. Templates retain styled bodies, checklist, recurrence and duration without implicit flattening or new tags. Changing the date re-anchors a template window's end; clearing the date clears its window. A kind change retains the displayed date choice. Calendar Add supplies the focused local day. Hourly lanes expose every all-day entry; Month overflow opens the corresponding Day. These are native adaptations, not reference visual sign-off.

Capture recovery is separate from field editing and never submits automatically. The prepared payload is stored before writing; a fixed task UUID identifies retries, with no extra workspace schema. Confirmed no-write failures unlock editing; uncertain outcomes keep the prepared payload and allow Retry to check the same ID. Context changes fail with a retained draft rather than silent rebasing. Successful creation opens the saved detail, including records outside the current filter. Checklist authoring during capture, template management and organization editors remain open.

**Purpose:** Define a native iPhone client that shares Taskovsky's Swift business engine with macOS, follows the supplied TickTick iOS screenshots closely in its visual layout, and can offer less rich-text editing without damaging desktop content. This specification combines pre-alpha delivery slices, concrete interactions, data gates and acceptance cases with a screen-by-screen visual reference. This update changes documentation only; it is not a claim that an iPhone app or notification implementation already exists.

**Current decisions:** Keep local JSON files and defer cross-device sync until later. Build an early pre-alpha for local development and device testing, with no App Store release. Use iOS 17.0 as a provisional conservative deployment target and prioritize the iPhone 13 Pro reference device. Plan basic on-device reminder notifications if the narrow implementation passes an early signing/device check; do not assume paid membership is required or add APNs. Desktop features still define functional scope except for this explicitly requested local-notification extension, and reduced rich-editor functionality remains permitted.

**Source freeze:** Read-only inspection of the current desktop working tree at `/Users/mental/Projects/Taskovsky`, branch `codex/calendar-visual-parity`, HEAD [`f85e2f6a9c538f36829961961a0749197f29c4e2`](https://github.com/Mental-NV/Taskovsky/commit/f85e2f6a9c538f36829961961a0749197f29c4e2), including three modified Calendar Swift files and untracked `CalendarAppearance.swift`. Section 14 records source locations and hashes. Feature scope comes from this implementation, not proposed `IOS`, `ARCH`, `CMP` or `RICH` documents. No builds, tests or native iPhone sessions were run for this revision.

**Visual evidence:** All 24 JPEGs in the user-supplied `MobileScreeshots` folder were visually inspected. They show TickTick iOS, not Taskovsky. Each is 591 × 1280 source pixels in sRGB. The user confirmed iPhone 13 Pro. The About row shows v8.2.41; iOS version, Display Zoom, Dynamic Type and the exact resize/compression pipeline remain unknown. Section 9 calibrates a standard 390 × 844 pt reconstruction baseline without treating it as recovered capture metadata. Section 9 identifies each file and separates observed pixels, proposed Taskovsky behavior and missing evidence. Private task text, names and profile information are not reproduced here.

**What changed in this revision:** Record local-only storage with sync planned later, a provisional iOS 17 floor, early pre-alpha testing and no App Store release. Add the conditional local-notification plan, permission and failure states, official Apple evidence and new acceptance cases. Preserve the desktop scope register, screenshot exclusions, iPhone 13 Pro calibration and no-loss editor requirements. No application code or desktop files are changed.

<a id="ios-001"></a>

## 1 Scope and authority

This specification is for **iPhone**. Android and an iPad-specific interface remain undecided. The shared Swift engine is an Apple-platform architectural direction, not a promise of Android portability. iPad compatibility mode must not be confused with an approved iPad product.

The current desktop implementation is the source of truth for feature scope, with the user's later conditional request for basic local notifications as an explicit exception. Proposed documentation and third-party screenshots do not add other features. The repository remains the canonical specification system for documenting those contracts. The existing `IOS-001` through `IOS-014` IDs are preserved as explicit anchors in this canonical specification. Section references below describe refinements to those contracts, rather than creating a competing current-behavior document. Business behavior remains in `BUS-*`; desktop appearance remains in `UX-*`; editor representation remains in `RICH-*`.

The original specification assignment updated documentation and published the mobile specification in a separate review PR, as requested. It changes no application code, local desktop worktree or live workspace data. Desktop polishing can continue independently. Before implementation, reconcile its final source revision against the evidence snapshot and record any changed shared contracts.

### Stable requirement index

The existing requirement IDs remain stable. Numbered Sections 1–14 retain their own references; they are not replacement requirement IDs. Related acceptance cases remain in Section 13.

| Requirement | Canonical location |
| --- | --- |
| [IOS-001](#ios-001) | Status, goals and limits |
| [IOS-002](#ios-002) | Information architecture and navigation |
| [IOS-003](#ios-003) | Visual and accessibility contracts |
| [IOS-004](#ios-004) | Task list and completion |
| [IOS-005](#ios-005) | Capture and contextual creation |
| [IOS-006](#ios-006) | Task and note detail |
| [IOS-007](#ios-007) | Date, duration, recurrence and reminders |
| [IOS-008](#ios-008) | Limited body editing without data loss |
| [IOS-009](#ios-009) | Browse and organization |
| [IOS-010](#ios-010) | Search and history |
| [IOS-011](#ios-011) | Settings, feedback and interruption |
| [IOS-012](#ios-012) | Shared engine and persistence boundary |
| [IOS-013](#ios-013) | Component states and capabilities |
| [IOS-014](#ios-014) | Acceptance and rollout gates |

### Existing implementation and proposed changes

| Area | Verified current state | Proposed mobile delta |
| --- | --- | --- |
| App target | Swift tools 6, Swift language mode 5, macOS 14 package; Core plus a macOS executable and tests | Provisional iOS 17.0 target, subject to toolchain/API validation; separate native phone UI |
| Shared code | Foundation models and useful scheduling/query policies exist; Core also includes AppKit rendering and desktop concerns | A platform-neutral domain and command layer with separate native adapters |
| Data | Local `workspace.json` and separate `settings.json`; whole-workspace Codable encoding | iOS sandbox-local repository, explicit compatibility states and field-preserving writes |
| Bodies | Authoritative plain body plus optional exact-text rich companion using UTF-16 ranges | Plain-only authoring initially; styled and unsupported bodies view-only |
| Scheduling | Dates, duration, reminders, custom recurrence and nominal series position are implemented on Mac | Phone controls for the same capabilities and shared rules; incomplete mobile authoring is a staged gap, not a scope change |
| Calendar | Seven Mac views, Calendar commands, projections and display settings exist | Port desktop-backed modes and settings using matching visual evidence; retain all stored fields and semantic distinctions |
| Continuity | Local files, no account/server sync or external calendar integration | Keep local files now; cross-device sync is explicitly planned later, not implemented in pre-alpha |
| Notifications | Stored reminders and in-app presentation, no OS/background delivery | User-requested basic local-notification adapter is planned conditionally; no APNs/server and no claim of current support |

Sources: [Package][src-package], [models][src-models], [store][src-store], [rich model][src-rich], [AppKit renderer][src-render], [business specification][spec-business], [architecture][spec-architecture].

## 2 Desktop scope and mobile delivery boundary

**Scope authority:** The currently implemented Taskovsky desktop features define mobile product scope, plus the explicit conditional local-notification extension in D04. The screenshots supply visual layout only. A TickTick control is not a Taskovsky requirement, pending feature decision or future roadmap item merely because it appears in R01–R24. A functional requirement needs either a desktop source in the scope register or an explicit later user decision recorded here. Local notifications qualify through that user decision; screenshot-only controls do not.

**Allowed platform difference:** iPhone has a separate touch interface and may have fewer rich-editor features, as the user explicitly allowed. Limited editing must still preserve all desktop data. Other differences described below are implementation sequencing, phone interaction adaptations or unresolved design details, not silent removal or expansion of desktop scope. If a desktop feature cannot yet be ported safely, record a mobile implementation gap and stage it explicitly; do not claim full feature parity.

### Product and implementation decisions

| Decision | Current constraint or unresolved implementation detail | Needed before |
| --- | --- | --- |
| D01 Platforms | iPhone client using the existing Swift engine with a separate UI. Android and dedicated iPad work are outside this assignment | Target creation |
| D02 Minimum iOS and devices | Recommend iOS 17.0+ provisionally. Prioritize iPhone 13 Pro; roughly five-year-old hardware coverage is a preference, not a promise. Audit required APIs, installed Xcode and available runtimes before fixing support claims | Target creation and compatibility validation |
| D03 Storage and continuity | User decision: keep the current temporary local-file approach. Each app has its own persistent container. Cross-device sync is planned later; no sync, accounts or shared live file now | Storage adapter implementation |
| D04 Reminder delivery | User decision: include notifications if straightforward; defer on a real implementation blocker. Plan ordinary on-device local notifications for existing reminder dates, gated on a Personal Team physical-device smoke test. Paid membership is not an assumed prerequisite. No APNs or advanced alerts | Early notification feasibility check, then implementation verification |
| D05 Editor scope | Reduced iPhone rich editing is permitted. Compatible bodies support paired transactions, and unknown or malformed bodies retain their saved representation | Write capability gate |
| D06 Calendar | Desktop Calendar belongs to the desktop-derived scope. Use matching screenshot layouts only for its implemented modes, commands and settings; staging the port does not turn Calendar into an optional screenshot feature | Calendar mobile design and delivery sequence |
| D07 Editing safety | Choose explicit save/discard, interruption handling and draft recovery mechanics suitable for iPhone. These support safe editing and do not introduce new business entities or cloud services | Capture/detail implementation |
| D08 Organization | Preserve the implemented desktop list/tag/filter/template capabilities. Missing phone editors are delivery gaps, not a screenshot-driven feature backlog | Organization design and staging |
| D09 Destructive actions | Use only implemented desktop lifecycle operations and exact subtree semantics, with appropriate phone confirmation and accessible alternatives | Lifecycle UI implementation |
| D10 Distribution | User decision: early pre-alpha only. Use Xcode local development, physical iPhone testing and optional Designed for iPhone/iPad Mac runs. No App Store submission/release or TestFlight rollout in this scope | Development signing and device testing |
| D11 Reference capture | iPhone 13 Pro is confirmed. Use standard 390 × 844 pt at 3× as a qualified reconstruction baseline; OS, Display Zoom, Dynamic Type and resize/compression settings remain unverified | Final visual sign-off |
| D12 Navigation | Use only desktop-backed destinations. Match the screenshot's capsule, drawer and selection styling while removing unsupported destinations and redistributing space | Navigation freeze |
| D13 Feature provenance | Screenshot-only controls remain excluded. Record explicit user exceptions separately; D04 local notifications is the only newly requested functional extension here | Every functional requirement and acceptance case |

The deliverable is an early pre-alpha, not a public-ready product. It may contain clearly recorded implementation gaps while features and UI/UX are polished. Begin with read-only navigation and the smallest safe write slice, then add desktop-backed capabilities and the narrow local-notification adapter if feasible. Do not make later sync, accounts, App Store readiness or screenshot-only features prerequisites for a pre-alpha. Data safety and honest capability labels are required at every stage.

### Conservative compatibility and pre-alpha testing

**Provisional deployment target: iOS 17.0+.** This is an engineering recommendation under the user's request for conservative assumptions, not an Apple requirement or a tested compatibility claim. Apple lists iPhone 13 Pro among [iOS 17 compatible devices](https://www.apple.com/qa/ios/ios-17-preview/). The device launched in [September 2021](https://www.apple.com/newsroom/2021/09/iphone-13-lineup-new-ipad-mini-and-ninth-generation-ipad-arrive-worldwide/), so it is approximately five years old at this specification date. Hardware age and installed iOS are different: the reference device's current OS is not known.

There is no stated functional requirement that by itself demands an iOS 18-or-later floor. Foundation local files, ordinary local notifications and a conventional SwiftUI interface do not justify raising the target merely for visual effects. Before implementation, audit the actual shared Swift code, required APIs, Xcode/SDK deployment support and available simulator runtimes. The current package remains macOS-only and needs platform separation; successful iOS 17 compilation is not assumed. If a required API or toolchain blocks the provisional floor, report the specific dependency and choose a compatible fallback before proposing a higher minimum.

Keep core workflows available at the baseline. Guard newer-OS APIs and provide standard SwiftUI/material or custom-rendered styling fallbacks. Newer glass effects are optional polish, not a reason to exclude older supported hardware. Do not promise identical system chrome across OS releases.

| Test target | Purpose | Status |
| --- | --- | --- |
| Physical iPhone 13 Pro on its actual recorded OS | Primary touch, keyboard, safe-area, persistence and local-notification behavior; reference geometry | Planned; installation and OS version unverified |
| iOS 17 baseline simulator or supported physical device | Build/API availability and core-flow coverage at the provisional minimum | Planned; confirm usable runtime/toolchain first |
| A smaller/older compatible iPhone where available | Practical older-phone and compact-layout coverage | Best-effort goal, not a release requirement or universal five-year-device promise |
| A newer available iOS runtime/device | Availability fallbacks and regression checks | Planned; record exact version rather than claiming “latest” |
| Apple-silicon Mac using Designed for iPhone/iPad | Additional native development smoke test without converting to Catalyst | Optional; not a substitute for physical iPhone or notification verification |

Apple documents [building and running on simulated or physical devices](https://developer.apple.com/documentation/xcode/building-and-running-an-app) and [running iOS apps on Apple silicon](https://developer.apple.com/documentation/apple-silicon/running-your-ios-apps-in-macos). The Mac route is a useful local development option, not proof of phone touch, lifecycle or OS-alert behavior.

**Development distribution only:** Apple's [account overview](https://developer.apple.com/help/account/basics/about-your-developer-account) permits personal-device testing with a free Xcode Personal Team. Current documented limits include ten App IDs, three devices and three apps per device; provisioning expires after seven days and requires rebuilding/reinstalling. Paid membership is not assumed for basic local installation. Actual account/signing/device setup and notification feasibility still require verification. Do not promise durable distribution or uninterrupted use after provisioning expires.

Use synthetic or explicitly isolated local-file fixtures during pre-alpha. Reinstallation/provisioning work must not put the desktop's live workspace at risk. No App Store submission, review, public release, TestFlight rollout or paid-program enrollment is part of this task. Those decisions can wait until required features and UI/UX polishing are complete.

### Scope classification

| Classification | Meaning |
| --- | --- |
| Desktop implemented | Present in current inspected desktop code; eligible for the mobile port with the same business semantics |
| Mobile adaptation | Layout, touch/navigation, accessibility or persistence-safety work necessary to deliver the same desktop capability on iPhone |
| Explicit user extension | Basic local reminder notifications, conditional on straightforward implementation and an early device/signing check; not yet implemented |
| Permitted reduced editor | The user's explicit allowance for fewer rich-editor features, subject to the no-loss gate |
| Reference evidence only | Visible in TickTick but not implemented in Taskovsky desktop; retain descriptive observations only and exclude controls/routes/tests that would implement it |
| Unverified | Source evidence is incomplete or behavior is not established; do not promote it to scope or claim parity until verified |

The desktop feature register in Section 14 is the traceability checkpoint. Section 9's reference inventory is intentionally broader because it documents the supplied images, but it cannot override that register. Existing Board, Summary or other desktop features without screenshots still need mobile layouts derived from their implemented behavior; absence from the reference set does not remove them from scope.

<a id="ios-002"></a>

## 3 Navigation and screen contracts

Refines **IOS-002, IOS-009 and IOS-010**. This revision supersedes the previous proposal for Tasks, Search and Settings tabs, full-screen Browse, pushed-only task detail and a labeled navigation-bar Add button.

### Main navigation

**Observed reference:** A floating, rounded, glass-like bottom capsule contains five icon-only destinations in this order: **Tasks, Calendar, Eisenhower Matrix, Search, More**. Selected-screen pairs establish the first four identities. More opens a compact tray with two additional unlabeled icons whose meaning is not established. Settings is reached through the drawer rather than a dedicated tab. See R01, R08, R13–R24.

**Taskovsky navigation target:** Desktop has Tasks, Calendar and Search in its primary rail. Use these three destinations in the phone capsule, in that order. Matrix and the screenshot-only More tray are excluded. Preserve the capsule shape, selected treatment, icon weight and relationship to the floating Add control, but redistribute the three supported items rather than copying five icon centers. Use accessible names even where the visible reference has no labels. Tasks uses the observed circular menu/overflow controls, destination title and blue Add affordance. Settings remains a supported utility route, not a substitute for the desktop Calendar destination.

**Scope boundary:** The three-destination adaptation is required by desktop scope, not an optional reduced version of a five-tab Taskovsky target. Compare near-pixel-perfect styling only for retained components. A staged build that has not yet implemented a desktop-backed destination must report that implementation gap and cannot claim full mobile parity. Never leave inert or screenshot-only routes in the navigation.

Launch a fresh session into Today as a proposed product default; the reference set directly shows Inbox, not launch behavior. Restore the last valid destination within an ongoing/restored session. If its entity is missing or hidden, fall back to a visible smart destination or Inbox with a brief explanation. Each functional destination preserves its navigation and scroll state. Switching destinations must not erase a draft.

### Drawer and organization routes

Match the dark-indigo drawer and its lighter selected-row treatment in R08 and R10. Preserve the observed hierarchy of top identity/utility area, smart destinations, organization sections and bottom utility controls. Replace reference account/profile content with a neutral Taskovsky workspace identity unless accounts are separately approved. Do not copy the person's name, avatar, list titles or private task data from the screenshots.

Map supported smart destinations, pins, Lists/folders, Tags, Filters and history routes to the shared engine. A visible desktop preference cannot make an unsupported module a working phone destination. Folder rows expand their one-level list group. Tags may be nested more deeply; cap visible indentation and show full ancestry in picker accessibility labels. Pinned entries reference the original entity. Counts come from shared destination projections.

The drawer Add popover presents **List, Filter, Tag** in the reference. List, Filter and Tag creation must use the corresponding implemented desktop commands and validation. Retain the popover entries that have those desktop counterparts. Existing filters remain browsable, executable and editable according to desktop semantics; an unfinished phone editor is a delivery gap, not permission to narrow the specification. Smart Lists and Tags management use the tall, rounded sheet-form appearance shown in R11 and R12. No swipe, drag or reordering behavior is established by the still images alone.

<a id="ios-006"></a>

### Task detail and editor presentation

Task selection presents a rounded detail overlay above the retained list, matching the settled half-sheet state in R02. Its top edge is near source y646; this is an observed resting position, not proof of a fixed detent API. At the top are the list selector label/chevrons and circular flag and ellipsis controls. Below are the completion square and due label, optional parent breadcrumb, and task title/body. The reference has tag, checklist and attachment affordances near the lower leading edge. Taskovsky retains only desktop-backed tag/checklist actions; it omits the paperclip because attachments are not implemented.

The expanded editing states in R05 and R06 have a circular back chevron before the list label, an onscreen keyboard and editor controls above the keyboard. Match the observed geometry at the reference viewport. The implementation may use native presentation and text components where they reproduce it, but default system styling is not an acceptable substitute for the measured layout. Static screenshots do not establish the gesture or animation that moves between settled states.

**Proposed behavior:** Opening detail selects the task without writing. Entering an eligible field editor expands the presentation enough to expose input and keyboard controls. Closing, Back, interactive dismissal and destination switching follow Section 5 draft-retention rules. Parent/child navigation keeps the originating destination, query, criteria, scroll anchor and expansion state; avoid indefinitely stacking repeated task IDs. Return to an existing route when possible.

Keep one content column on iPhone. A wider phone does not become the three-pane Mac interface. The reference controls retain their relative geometry at the matching default-text viewport; safe areas, keyboard, rotation and accessibility text adapt. Notes remain a task kind in these destinations and do not require a separate Notes tab.

### Screen inventory

| Screen family | Reference | Taskovsky contract and required states |
| --- | --- | --- |
| Tasks destination | R01 | Header, group card, rows, completion, FAB and bottom capsule; empty, filtered-empty, missing/archived destination and persistence-blocked states need additional design |
| Task detail and editor | R02, R05, R06 | Settled half-sheet and expanded keyboard states; plain edits, styled preview, missing task, stale draft, discard and save failure |
| Task menus | Supported rows within R03 and R04 | Match desktop-backed actions and grouping; R07 and unsupported rows are evidence only and excluded |
| Drawer and organization | R08, R10–R12 | Indigo navigation, selected row, Add popover and management sheets; empty sections, hidden/missing entities and long names |
| Settings | R09 | Tall grouped sheet entered from drawer; supported display/default/data/About settings, compatibility and failed-save status |
| Calendar | R14–R22 where mapped in Section 9 | Desktop day/week/month/year/agenda/multiDay/multiWeek only; R13 Week card mode is evidence only and excluded |
| Matrix and More | R23 | Reference evidence only, excluded from Taskovsky routes and acceptance targets |
| Search | R24 | Search field, query-history state, keyboard and selected bottom icon; result/no-result/error states are not shown |
| New capture and schedule editor | No direct reference | Retain proposed transaction rules in Sections 5 and 6; derive styling from observed controls without claiming screenshot parity |

The reference screenshots are a visual baseline, not evidence of a Taskovsky prototype, working navigation, animations or tested interactions.

<a id="ios-004"></a>

## 4 Task list and lifecycle

Refines **IOS-004 and IOS-006**; preserves **BUS-002, BUS-006 through BUS-009, BUS-016, BUS-018 and BUS-019**.

A task row uses the reference's **rounded-square completion outline**, not a generic circular checkbox. Separate its hit region from detail navigation. R01 shows an approximately 24 × 24 source-pixel outline with roughly 5 px corners, text beginning near x94, a 73 px ordinary row pitch, and indented children with control near x109/text near x140. The visual square and the accessible touch area are different dimensions. Section 9 defines the coordinate limits.

Match reference title weight, metadata placement, indentation, truncation and faded completed treatment using neutral fixture content. Metadata can include due label, list context, checklist/child progress and one tag with overflow. The reference includes red due/overdue labels and child chevrons; their Taskovsky meaning comes from the shared engine. A note uses a note icon and offers no completion action. The proposed ordinary-text title limit is two lines where the reference state permits it; full text is available in detail. Do not conflate embedded checklist progress with linked child-task progress.

Tapping completion must not open detail. The detail ellipsis opens the reference-style primary action sheet; its More row opens the secondary action surface. Section 9 maps the exact visible actions and capability gaps. On iPhone Tasks rows, the leading swipe reveals Complete, Reopen or Restore when eligible. The trailing swipe reveals the applicable Schedule, Priority, Move and Trash actions. Tap an action to apply it. [Task swipe contract](../changes/mobile-task-row-swipes-2026-11-10.md). Provide reachable non-gesture actions. Do not allow full-swipe Delete Forever. Won't Do is explicitly named and remains distinct from completion. Reference label **Delete** maps to Taskovsky **Move to Trash** unless a distinct permanent-purge context is active; visual copying must not change its safety semantics.

Settings → Date & Time → Countdown Mode enables a separate date control on eligible Tasks list rows. Tap it to switch between the ordinary due label and a countdown. Tap the title to open detail. The device remembers the mode. Individual row choices reset at relaunch or when the mode is turned off. [Countdown contract](../changes/task-countdown-labels-2026-11-10.md).

Use the shared destination query rather than a phone-specific date filter. In current source, Today and Next 7 Days include overdue active dated work; their saved-filter date predicates are different. Parent-tag navigation includes descendants while a saved-filter tag predicate matches selected tag IDs. A UI simplification must not alter either result set.

Pinned active work remains in a separate group in the list presentation. Concrete lists honor the saved `viewMode`. The Board pages the Open, Completed and Won't Do columns, with drops onto status tabs and card actions as another way to move. Only changing the List/Board/Timeline control writes the mode. Timeline shows a horizontal project schedule with Day, Week and Month scales, with undated arrangement and the existing schedule editor. Folders open from a separate drawer action and show active member lists. Folders and saved filters offer Timeline for the current session. All, Today, Tomorrow, Next 7 Days, Inbox, folders, and tags also offer Board in the same view picker. Choose Date or List grouping above the board. Tap a column header or swipe to see its cards. Drag a card’s grip onto another eligible column tab or use the card’s Move menu. Date moves use the Calendar recurrence and Undo flow. [Grouped Board change contract](../changes/scoped-boards-2026-11-09.md). Press and hold a blank date to stage capture. Drag a scheduled mark to move it or its end grip to resize. The normal recurrence and Undo controls apply. The chart shows nonempty sections in saved order, with source list names in folder and filter views. Drag an undated task from Arrange onto the date axis to schedule it, then use Undo to revert. The palette changes the current Timeline’s task colors by list, tag, or priority. Pinch the date axis to zoom around the gesture, or use the percentage controls. See the [change contract](../changes/task-timeline-2026-11-09.md).

The phone currently uses a separate 44-point row completion target, a single task action sheet and distinct Pinned, Completed and Won’t Do groups. List, search and Calendar detail share the action sheet. The sheet exposes Inbox and active lists as move targets and confirms a purge using the task name. Completed and Trash actions offer Undo for the saved revision. The reference's second action sheet, exact swipe customization and child editing remain open. [Implementation and evidence](verification.md#mobile-task-lifecycle).

Task detail shows progress below Schedule. Tap the 44-point progress row or long-press a task's completion checkbox and choose Set Progress to edit a manual value. The editor opens as a medium-height sheet with room to expand. Cancel can discard the draft. Checklist progress is displayed as a read-only percentage. Progress and the completion action remain separate. [Progress contract](../changes/task-progress-2026-11-10.md).

### Mutation contracts

- **Complete:** invoke one shared subtree command. Preserve pre-existing child completion/Won't Do stamps, recurrence successor deduplication and the cascade ledger. Never loop over visible rows to implement completion.
- **Reopen or Undo:** use the shared stamp/identity guards. Do not resurrect descendants changed independently or remove edited successor trees. Reopen and Undo are not assumed to have identical effects.
- **Won't Do:** keep its existing one-record behavior and do not run the completion recurrence path.
- **Move list:** move descendants consistently and detach a child when its former parent remains in another list. Validate the entire requested operation before applying it.
- **Move to Trash:** preserve body, schedule, identity and subtree ledger. A separately trashed descendant stays separately trashed after a parent restore.
- **Restore:** restore only the shared-policy eligible descendants; no recurrence creation.
- **Delete Forever:** per-item only, available in Trash, explicit confirmation naming the item. Use actual purge semantics: surviving direct children are detached, not automatically purged. The UI must not describe a whole-subtree purge unless that is separately implemented and approved.
- **Archive:** archived content is readable, with an explicit move to an active list/Inbox or list-unarchive path. Reject mutation at the command boundary, not merely by disabling UI controls.

Inaccessible or disappearing rows need understandable feedback. A transient Undo must consume one token at most; it cannot be the sole accessible recovery route. Keep persistent history/reopen/restore paths, but do not mislabel them as complete reversals of every side effect. An accessibility review must verify that transient feedback does not make an action impossible for a slow screen-reader user.

<a id="ios-005"></a>

## 5 Capture and editing transactions

Refines **IOS-005, IOS-006 and IOS-011**.

### Capture

The reference establishes a floating Add affordance but supplies no new-task capture screenshot. The following is proposed Taskovsky behavior: Add opens a sheet and focuses title. Use the reference detail/editor typography, controls and keyboard styling; show Task/Note, title, optional description, selected list and date, priority and tags. An empty or whitespace-only title disables Add. Capture is a draft until explicit submission; entering a tag token or opening a template must not create tags, tasks or other records in the live workspace. A new capture design requires its own visual approval rather than being marked matched to R05.

Contextual defaults come from shared policy. Explicit Inbox must stay Inbox rather than resolving through a configured default list. Show the resolved destination and date before submission. A target archived or removed while the draft is open must produce a clear validation result or an explicit, visible fallback consistent with the approved create contract. Do not silently put the record somewhere unexpected.

Tasks Actions → Add Multiple Tasks opens multiline entry and an explicit review. Each nonblank line uses the shared creation rules. One save adds the full batch to the reviewed list. The text stays in the sheet while retrying a save. [Batch text capture](../changes/task-batch-text-capture-2026-11-10.md).

Date/tag recognition displays removable candidates. Native pickers resolve IDs, including multiword tag names, without requiring knowledge of the desktop quoted-token syntax. Applying a template updates the capture draft and preserves its complete rich body, checklist and schedule representation. A styled template may be instantiated while its body stays read-only on phone.

Submission produces a stable command ID and at most one creation transaction. Disable repeated submission while it is pending. Retry after uncertain completion must query that command outcome or use an idempotent path, not create a second task. A durable success dismisses capture and gives feedback. A failed write keeps the draft and offers Retry or Keep Editing without claiming the task is saved.

### Edit sessions

Opening title or eligible body editing copies the current field into a local draft with task ID and base revision. **Done** commits; **Cancel** discards that field draft. These save semantics are a proposed Taskovsky contract, not behavior proven by the screenshots. Fit the actions into the reference editor chrome without sacrificing an explicit discard route. Metadata changes such as priority or completion are discrete commands. Schedule has its own staged transaction. These phone transactions intentionally need not copy the Mac's per-keystroke writes.

A nonempty new capture or changed editor draft cannot disappear through Cancel, Back, interactive dismissal or tab switching without a clear **Discard / Keep Editing** choice, except when state is deliberately retained in the background. A completed no-change edit produces no mutation. App backgrounding never submits an unfinished draft.

Proposed D07 behavior: persist resumable drafts locally, separate from the authoritative workspace, on change with a bounded debounce and on supported lifecycle opportunities. Store document ID, base revision, changed fields and enough compatibility information to validate recovery. On relaunch, offer Resume or Discard. Do not store a second authoritative workspace in draft files. If the target changed meanwhile, show a conflict and keep the draft; do not automatically apply it to the new record.

Draft-persistence failure must be distinguishable from workspace-save failure. Forced termination immediately after a keystroke may outrun a debounce; test and document the bounded loss window instead of claiming zero-loss recovery. Never advertise a recovered draft until its bytes were durably stored and read successfully.

### Checklist and child tasks

Task List rows with children in their current group have a separate trailing 44 × 44 disclosure target, secondary semibold caption chevrons and named Show/Hide accessibility actions. Opening or folding preserves nested state during the phone session and does not change task selection or data. Search and batch selection ignore folds; children independently matching another group remain visible. Existing row swipe, countdown, section and manual-order controls remain separate. Relaunch expands all branches. [Disclosure contract](../changes/task-subtree-disclosure-2026-11-10.md).

Embedded checklist item edits operate on embedded item IDs. Linked subtasks are separate TaskItems with their own detail and schedule. Rich-body checklist paragraphs are formatting and remain read-only when the body is styled. Each UI uses the correct representation. R06 shows a rounded-square placeholder and a keyboard instruction to use Next for another checklist item. Proposed Taskovsky Next adds a nonempty item to the draft and advances focus; it does not create an empty durable item or submit the entire edit. Creating a linked child uses the shared child-creation defaults, not the full top-level quick-entry pipeline.

R05 shows tag entry in a rounded accessory pill above the keyboard, with a leading tag icon, separate keyboard-dismiss control and a four-row suggestion popover. Match that presentation for existing-tag selection. Resolve IDs through shared policy; typing a tag or accepting an existing suggestion must not silently create a new tag. Whether inline creation is offered remains D08.

<a id="ios-007"></a>

## 6 Scheduling and reminders

Refines **IOS-007**, **CMP-002**, and **BUS-011 through BUS-014**.

No due/repeat picker is included in the screenshot set. The following schedule interaction is proposed, with visual styling to follow Section 9 and a separate reference approval needed. The native schedule sheet owns a complete staged draft containing due date, timed/all-day shape, task zone, duration, recurrence, nominal position and reminders, even if some fields are view-only. It exposes Cancel and Done. **Remove schedule** stages removal until Done in this proposal. This is a deliberate phone interaction difference from the current Mac detail editor's immediate Clear action.

Desktop scheduling capabilities remain the scope, including custom recurrence, duration and reminder controls where implemented. A first safe write slice may start with date-only/date-time and simple repeat choices (None, Daily, Weekdays, Weekly, Monthly, Yearly), but missing advanced phone authoring must remain an explicit implementation gap. Display existing custom rules and preserve their occurrence count/nominal position until equivalent authoring is ready. Never turn a custom rule into a simple rule because a picker default was loaded. Explicit replacement is a separate deliberate action describing the consequence.

All changes pass through one shared schedule transaction. Required invariants include:

1. A valid duration uses `dueDate == scheduledDuration.end` and `hasDueTime == !isAllDay`.
2. Timed spans preserve exact elapsed duration where the operation requires it; all-day spans use calendar days in the task zone.
3. Ordinary date edits preserve occurrence count and rebase nominal cadence through existing policy. Unchanged saves preserve rolled nominal state and produce no write.
4. Manual and default-following reminders retain their different semantics. Do not copy Calendar move behavior into the detail editor without choosing the command's intent explicitly.
5. A duration, custom recurrence, reminder or zone that the phone cannot transform safely blocks the affected schedule action with a reason. Unsupported fields cannot be dropped to make validation pass.
6. All-day labels show the intended civil date, not a date shifted by the device's current zone. Invalid/missing zone handling follows one shared policy and is visible when relevant.
7. Nested editor Cancel restores the complete outer draft. Outer Cancel or gesture dismissal changes no schedule fields.

Display Today/Tomorrow/Next week shortcuts from shared policy and use native date/time controls. In Tasks, Repeat offers Skip this occurrence when the saved series can advance. The swipe Schedule action and task-detail Schedule open the same editor. Done saves the skip, Keep editing returns to the draft, and Tasks shows schedule Undo. [Tasks skip contract](../changes/mobile-task-schedule-skip-2026-11-10.md). Preserve precise existing values even when the picker displays rounded minutes; merely opening and saving must not snap a short, fractional or zero-length supported window to a default interval.

### Local task metadata

Existing active task detail has controls for priority, existing tags and embedded checklist items. Priority and detail checkmarks save immediately. Tag selection and checklist text, order, additions, removals and draft checkmarks save on Done. The tag picker can search existing tags and preserves unavailable saved references until explicitly removed. Checklist Next advances through existing entries or adds the pending nonempty entry. Cancel asks whether to discard changes or keep editing. The staged draft lives in the open editor and has no relaunch recovery. Stale revisions and write failures keep the draft visible.

Calendar reads the saved checklist titles and status using the existing checklist display option. The metadata commands preserve the description, schedule and linked subtasks. Notes support tags and priority. Checklist editing is available on tasks. [Metadata verification](verification.md#mobile-task-metadata).

### Linked subtasks

Task detail adds and opens linked tasks, shows direct-child progress and offers independent completion through the existing lifecycle command. Parent and Previous Task links navigate among details. Task rows nest within their visible group and keep children visible when a parent is outside the group. The parent picker searches active tasks by title or list and excludes the task itself and its descendants. Done saves the selected parent. A cross-list link previews the destination and moves the subtree together. Top level detaches the task in its current list. Cancel can discard the open sheet's draft. [Hierarchy verification](verification.md#mobile-task-hierarchy).

### Local schedule editor

The isolated phone build opens Schedule from the same task detail in Tasks and Calendar. Date, time, duration, searchable task zone, multiple reminders and simple or custom repeat are staged together. The nested custom editor offers due or completion anchors, explicit dates, weekly selection, monthly day/ordinal/workday patterns, yearly month/day/ordinal patterns, weekend handling and date/count limits. A shared-engine preview shows the next occurrences. Replacing a custom rule with a simple one requires an explicit confirmation. Remove schedule waits for outer Done. Cancel closes the staged editor without a workspace write.

The phone keeps an implicit device zone until a task zone is chosen. Enabling duration for an all-day date starts with a same-day all-day window. Point time starts at 09:00, and an existing timed point seeds a window with the configured duration. A task zone change keeps the schedule's wall-clock values and the legacy repeat end's civil date. Existing custom rule values and manual reminder instants are preserved. Calendar move and resize use the separate Calendar commands described below. [Schedule verification](verification.md#mobile-task-scheduling).

### Basic local notifications for pre-alpha

**Decision and current state:** The user wants notifications if implementation is straightforward, and deferral if a genuine blocker makes them impractical now. Plan a small **on-device local-notification adapter** for existing Taskovsky reminder dates. This is an explicit mobile exception to desktop scope authority. Desktop currently stores and presents reminders but does not deliver OS notifications; no iPhone notification code or successful device test is claimed by this document or its documentation PR.

Apple documents local scheduling through UserNotifications and delivery by the system when the app is not running. This is distinct from APNs remote notifications, device tokens and a provider server. See [UserNotifications](https://developer.apple.com/documentation/usernotifications), [local scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app) and [Apple's detailed local-notification guide](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html).

**Feasibility gate:** Do not defer merely because a paid Apple Developer Program membership is not set up. Apple supports free Personal Team on-device development, and ordinary local scheduling does not use the APNs server/entitlement flow. However, these facts are not a direct official guarantee that this particular app will deliver notifications under its actual free-signing configuration. Before committing to notification support in a pre-alpha build, install a minimal signed build on a physical iPhone, obtain runtime permission, schedule one future fixture reminder and verify foreground/background/not-running behavior. Record account type, OS, device, signing result and actual delivery. If a genuine signing/capability/toolchain blocker appears, report its evidence and defer local alerts while keeping stored and in-app reminders. Do not buy membership, add a server or raise deployment requirements merely to avoid investigating the local path.

A [source-backed phone adapter proposal](../changes/iphone-local-notifications-2026-11-12.md) now defines the next boundary: reuse the merged planner/read-only repository, separate phone views/transport, persisted stable workspace identity across sandbox relocation, default-off explicit intent, independent notification clock and no-prompt revision refresh. Owned repository/fake-center contract probes are architecture evidence only, not a shipped phone adapter or device delivery receipt. The physical-device feasibility gate above remains in force.

### Authorization and user-visible states

Alerts and sounds need [runtime notification authorization](https://developer.apple.com/documentation/UserNotifications/UNUserNotificationCenter/requestAuthorization%28options%3AcompletionHandler%3A%29?changes=_6). Ask in context when the user enables local alerts or first requests a delivered reminder, not silently at launch or while merely opening a task. Request only the presentation options actually used. Ordinary alerts and optional sound are sufficient for the first adapter; critical alerts, special interruption privileges and remote push are outside scope.

| State | Required behavior and truthful copy |
| --- | --- |
| Adapter not yet implemented or deferred | Keep reminder data/in-app list. Say “Reminder times are saved. Local notifications are not available in this build.” No OS permission prompt |
| Permission not yet requested | Explain local alerts, let the user enable them, then request authorization in context |
| Permission granted and request accepted by iOS | Confirm scheduling, not guaranteed visible delivery. Respect the actual allowed alert/sound settings |
| Permission denied or later disabled | Preserve reminder data, explain that notifications are off, offer a route to system settings; do not repeatedly prompt or report a failed task save |
| Scheduling/reconciliation failed | Task data remains durable; say the alert could not be scheduled, retain retry/reconciliation state and avoid a false “notification set” message |
| Pending-request budget exceeded | Queue the nearest eligible reminders, explain that later ones are not yet scheduled and will be reconsidered when the app runs; do not imply unlimited background coverage |

Focus, notification settings and Scheduled Summary may silence or delay presentation; [Apple's notification controls](https://support.apple.com/guide/iphone/view-and-respond-to-notifications-iph6534c01bc/26/ios/26) describe those user choices. This feature is not an alarm-grade or exact-time delivery guarantee. Foreground presentation requires an explicit policy; avoid a duplicate banner plus duplicate in-app alert for the same reminder. Opening a notification routes to an existing task when possible, with a safe missing-item fallback. No lock-screen mutation actions are required in pre-alpha. Respect system preview privacy and avoid including task-body excerpts by default.

### Scheduling and reconciliation contract

- Schedule **one-shot local requests for existing persisted reminder instances**. Do not create new tasks, infer reminder times from due dates, add a recurrence feature or use an OS repeating trigger to bypass Taskovsky's completion-driven recurrence rules.
- Derive delivery instants from the shared reminder model, including task timezone, all-day clock and manual/default-following provenance. Test DST and timezone changes. A [calendar notification trigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger?changes=_1_7) matches date components; supply the intended zone rather than accidentally interpreting them in the current device zone.
- Give requests stable, app-owned identifiers tied to task/reminder identity. Read pending requests and reconcile against the authoritative local snapshot on launch/foreground and after relevant durable commands. Repeated reconciliation must not create duplicates.
- Replace or cancel affected requests after reminder/date/zone/default changes, completion/Won't Do, trash/purge, archive eligibility changes and explicit reminder removal. Reopen/restore/undo and recurrence successors re-evaluate eligible future reminders through the same shared rules. Do not deliver already elapsed reminders as a surprise burst unless a future user-facing policy explicitly permits it.
- Commit task data durably before deriving OS requests. Workspace persistence and notification scheduling are not one transaction: retain a device-local pending reconciliation state and surface failures without rolling back or corrupting the task. Do not claim alert state is updated before the scheduler acknowledges it.
- Keep a bounded nearest-reminder queue. A proposed app-owned budget of **50 pending one-shot requests** is a conservative pre-alpha policy, not a statement of a current UserNotifications API limit. Apple documents 64 for the [deprecated UILocalNotification API](https://developer.apple.com/documentation/UIKit/UILocalNotification?changes=_9_5), which must not be presented as a verified modern guarantee. Inspect actual pending requests, handle scheduling errors and expose overflow. No background replenishment service or unlimited future recurrence horizon is promised.
- Keep existing in-app reminders usable regardless of permission or scheduling state. Do not change task recurrence, completion or calendar semantics to make notification delivery easier.

**Excluded from this extension:** APNs, notification provider servers, cross-device coordination, remote payloads, accounts, guaranteed background execution, critical alerts, location reminders and new calendar/event sources. Free-signing feasibility and real delivery remain tests to run, not facts established by writing the specification.

<a id="ios-008"></a>

## 7 Rich text compatibility and the no-loss gate

Refines **IOS-008**, **RICH-001 through RICH-006**. This gate is mandatory even when the phone editor has very few features. The phone and Desktop retain separate rich editing implementations and native acceptance criteria. The [platform capability matrix](../architecture/components.md#rich-003) distinguishes rendering, authoring and preservation.

### Body capabilities

| Incoming body | Phone display | Body write | Other field writes |
| --- | --- | --- | --- |
| Valid plain body, no companion | Native selectable text/editor | Allowed through validated paired-body command | Allowed through field-scoped commands |
| Known empty rich representation | Classify using full parsed features and exact mirrored text | Format description validates the complete representation before a paired write | Preserve untouched representation |
| Valid styled body | Selectable native preview | Format description applies supported, validated transactions | Preserve untouched representation |
| Unknown rich version/feature/field | Safe preview if available, with unsupported-format notice | Not allowed | Preserve complete opaque content exactly, or block writes |
| Malformed ranges or plain/rich mismatch | Authoritative plain text if safely readable; no dubious range application | Not allowed | Preserve original and allow only proven-safe field patches, otherwise lock |
| Unreadable enclosing workspace | Recovery/error screen; do not promise per-item preview | Not allowed | Not allowed until deliberate recovery |

**Native preview.** Task and note detail and protected template capture use a selectable UIKit description. Known inline formats, headings, quotes, lists, rich checklist markers and rules render from the shared UTF-16 projection. Markers and rules are painted outside the text. HTTP and HTTPS links use the platform's user-initiated link behavior. Malformed or mismatched ranges fall back to the saved plain description. [Rich preview verification](verification.md#mobile-rich-description-preview).

**Native authoring.** Tap a checkbox in the editable description gutter to toggle that paragraph in the active draft. Paragraph → Check Item and Uncheck Item remain available. Done commits the draft. Cancel can discard it. [Checkbox verification](verification.md#rich-checklist-toggle). Format description uses the [paired transaction contract](../changes/mobile-rich-editor-2026-11-09.md#edit-transaction-contract) with Inline and Paragraph menus, a named Highlight Colors submenu, rich paste from Taskovsky descriptions and [supported HTML or RTF](../changes/rich-description-foreign-paste-2026-11-10.md), Markdown recognition on ordinary plain-text paste, [typed Markdown shortcuts](../changes/rich-description-markdown-typing-2026-11-10.md), Paste as Plain Text, draft Undo/Redo and explicit Done. [HTML paragraph paste](../changes/rich-description-foreign-html-blocks-2026-11-10.md) preserves matching semantic headings, quotes, lists and code blocks and keeps the literal plain alternative. The task identity and workspace revision gate the save. Unsupported boundary changes are refused. [Rich editor verification](verification.md#mobile-rich-editor).

Return continues a saved description list. A new checklist item starts unchecked. Return on an empty item exits the list. Edits remain in the rich description draft until Done. [List continuation](../changes/rich-list-continuation-2026-11-10.md).

Read-only preview retains the stored rich companion. Code Block in the Paragraph menu formats existing paragraphs. Ordinary paste recognizes closed, standalone three-backtick fences. Typing three backticks and Return opens a code paragraph. Return continues the block and the closing fence resumes plain text. The description reader copies visible code blocks as exact plain text. [Code block contract](../changes/rich-code-blocks-2026-11-10.md). The disclosure button next to a formatted heading collapses its section while reading. Format description opens the full body even when the reading section is collapsed. [Heading fold verification](verification.md#rich-description-heading-folds). Opening a task, selecting text, copying, scrolling, changing focus, leaving the screen or backgrounding must not call an extraction/save path that replaces its body.

The shared model uses exact UTF-16 identity. Paired saves preserve code units and carry formatting as range metadata. Incoming plain-text paste can apply the [supported recognition rules](../changes/rich-description-markdown-paste-2026-11-10.md) before the model receives the edit. Rich-body checklist paragraphs remain separate from embedded checklist items. Known body mutations commit plain text and its matching rich companion as one logical pair. Retaining old offsets after a text change is not safe preservation.

Undo belongs to a specific document identity and edit session. Switch between different tasks with identical text and verify that neither selection callbacks nor Undo can modify the other task. Cancel and external replacement clear or invalidate the relevant editing history according to the document gate.

### Why field-scoped commands are necessary but insufficient

The current `TaskStore.updateTask` accepts a complete TaskItem and `save()` encodes the complete WorkspaceData. Current keyed Codable models do not keep unknown JSON keys, and RichBody/WorkspaceData have no explicit schema version. An unknown enum value may fail the entire decode. Therefore, “we changed only the title in memory” does not prove the write preserves data on disk.

Before phone metadata writes are enabled, the repository must either:

- retain the original unowned and opaque fields through a proven lossless update strategy, including every rewritten record and settings object; or
- refuse writes to a document/workspace whose complete preservation cannot be guaranteed.

The exact raw-envelope implementation and version fields require a focused design. Adding a version integer alone is insufficient: an older Mac writer may ignore it and erase newer fields on its next whole-workspace save. Compatibility rollout must account for the old writer, backup/rollback and any barrier preventing an incompatible write. Do not introduce new portable data fields and then tell the user to continue opening the same file with an unsafe old build.

For unchanged opaque payloads, compare their retained exact content, not merely the understood subset. For intentional edits to fully known rich representations, semantic run normalization may be acceptable only as documented in RICH-005; it must retain exact text code units. No destructive “Convert to plain text” action is in this release.

**Required fixture round trip:** Mac fixture → phone open → title/date/list/tag change → phone durable save → Mac reopen. Compare identity, exact body/rich content, checklist, child links, recurrence fields, reminder provenance, duration, lifecycle ledgers, templates, filter rules and unowned settings. Also exercise an unsupported payload elsewhere in the same workspace to catch loss caused by whole-file encoding.

<a id="ios-009"></a>

## 8 Organization search and settings

Refines **IOS-009 through IOS-011**.

Task lists have a Sort tasks menu with Default Order, Priority, and both directions for Created and Modified. Ordinary List views also offer Group by Created Date and Group by Due Date. The active grouping temporarily replaces named section headers and keeps its own device preference. Sort and grouping survive relaunch independently. Pinned and history groups remain visible and subtasks nest within their visible group. [Sort verification](verification.md#task-timestamp-sorting) and [due-date grouping verification](verification.md#task-due-date-grouping). The drawer groups above-folder, member and below-folder lists, with pinned shortcuts and a separate archive section. Manage Lists creates and edits lists and folders, exposes within-group reorder controls and stages placement, archive and smart-list inclusion. It confirms list deletion, duplication and folder ungrouping. The list organizer keeps the saved view mode. A concrete list can change its mode from its own List/Board selector. [List and folder verification](verification.md#mobile-list-organization).

The Smart Lists sheet stages Show, Hidden and Show if not empty for supported destinations and the Tags and Filters sections. The top group and history group reorder independently. Hiding the active destination falls back to the first visible Smart List or Inbox. The settings write preserves other preferences and the workspace. [Smart List verification](verification.md#mobile-smart-lists).

List/tag create and rename use native sheets with explicit Save/Cancel and shared validation. Keep list kind, symbol, view mode, folder, archive, smart visibility and pins unless the action owns that field. The phone may reorganize these controls, but any implemented desktop operation omitted from a delivery slice remains a tracked mobile gap.

List deletion moves its records to Inbox and retains unavailable filter references. If offered, confirmation must say so. Tag deletion removes its memberships and promotes children while preserving unavailable filter criteria; merge/reparent must follow the implemented desktop command semantics when ported. Existing advanced filters remain executable/readable and cannot be converted to a simpler filter merely to expose an editor.

Manage Lists → Icon → Custom Emoji uses the native keyboard or paste. The editor previews the glyph, and the drawer and manager display the saved list icon. A leading emoji in a new or changed name can also supply the default icon. Done saves the choice, while Cancel can discard it. [List emoji contract](../changes/list-emoji-icons-2026-11-10.md).

Manage Filters in the drawer toolbar creates, edits, pins and deletes saved filters. A mode selector stays near the name. Advanced condition rows show their type and value. Tinted AND, OR and NOT headers and short guides distinguish groups. Structural edits use contextual action sheets. The keyword keyboard has a Done key. The native editor shows the match count, preserves unavailable selections and asks before replacing an advanced tree with Normal criteria. [Filter verification](verification.md#nested-filter-layout).

Manage Tags in the drawer toolbar creates and edits tags with staged name, color, parent and pin changes. Sibling reorder and branch disclosure persist on each accepted action. Merge and delete require confirmation and use the shared reference rules. [Tag verification](verification.md#mobile-tag-management).

<a id="ios-010"></a>

The Search destination uses **full-search task scope**, not the Mac quick-search overlay's broader scope. R24 provides the search/history/keyboard layout, with Task, Tag, List and Event filter pills. Desktop search supports tasks/notes, lists, tags and filters. Port all those result categories and existing criteria; Event has no desktop counterpart and is excluded, not deferred. Omit its pill and add supported filter access in a phone-appropriate layout. Default task results observe archive/exclusion policy; positive explicit list selection may include that list according to the shared filter engine. Organization matches can be grouped separately. Include an archived/list context label when a result is shown through an explicit selection. This choice must be characterized against the current full-search implementation before extraction.

Search includes title, authoritative plain body and embedded checklist titles. It does not call a cloud service or mutate content to generate snippets. Query and criteria survive detail navigation. Empty search shows device-local recent queries with the desktop rules: clearable, case-insensitive de-duplication and at most ten entries. Avoid using desktop UserDefaults keys or writing history as workspace data. Deleted/unavailable saved-filter IDs must not become “All lists/tags.” Save as Filter opens the existing phone editor with the query and selected criteria. The [Search implementation](../changes/mobile-search-2026-11-09.md) uses a native criteria sheet and an organization-results strip. The [verification record](verification.md#mobile-search) describes the checked behaviors and layout limits.

<a id="ios-011"></a>

Settings use the rounded, tall grouped-sheet appearance in R09, entered from the drawer utility control, with a centered title and blue circular confirmation control. Use native components where their rendering matches; generic grouped-form defaults do not replace the visual measurements. The reference's account, premium badges, AI and integrations remain excluded. A narrow notification setting is justified only by the user's D04 clarification, not by TickTick's settings screen. Section 9 records the observed labels and mapping limits.

Distinguish device presentation state from business defaults. Phone navigation, row density, local draft state and search history remain device-local where supported; screenshot-only history controls are not added without a desktop counterpart. Existing Mac pane geometry, Calendar display settings and board mode are not overwritten. Synchronization is planned later and excluded from the current pre-alpha; preserve the ownership of existing desktop settings when designing local phone preferences.

The [local Settings implementation](../changes/mobile-local-settings-2026-11-09.md) exposes week start, new-task defaults, date and tag text handling, and saved reminder choices. Date display follows the device locale. About identifies the local workspace and compatibility lock. Failed saves leave the draft open and show the error. Account, premium and external integration controls remain outside the local scope.

### Desktop features without direct screenshot matches

These features remain in scope even though the supplied TickTick images do not show equivalent screens:

- **Board:** Preserve the per-list List/Board choice and three fixed status columns Open, Completed and Won't Do. Notes stay in Open and archived boards are read-only. A phone layout may page or scroll columns, but must not replace status columns with Matrix urgency/importance quadrants. Use the existing board projection and characterize move/drop behavior before adapting it to touch.
- **Summary.** The Tasks drawer uses Smart List visibility and order. The native editor generates plain text with shared period, list, status, grouping and field rules and offers Regenerate, Copy and Save as Note. Summary Filter opens a dedicated preset screen for creating, applying and managing named configurations. Filters and device-local preset changes stage until Done. Cancel retains the existing report edits and discards preset changes. [Report presets](../changes/summary-report-presets-2026-11-10.md). A failed note save uses the capture recovery flow. [Implementation record](../changes/mobile-summary-2026-11-09.md).
- **Organization:** Preserve flat folders containing lists, create/rename/ungroup/reorder/move operations, list duplicate/archive/delete and tag subtags/reparent/merge. Use accessible phone menus and pickers for existing commands; do not invent arbitrary nested folder structure.
- **Filters:** Provide the current advanced condition editor and its existing unavailable-reference behavior. Screenshot Add Filter is visual evidence for an already implemented feature, not an argument for a new simplified filter language.
- **Templates.** The drawer opens template management. Search is available in the manager, capture chooser and Apply Template. Clear the query and choose Reorder to expose native drag controls. [Template search and order](../changes/template-search-order-2026-11-10.md). Task Actions offers Save as Template and confirmed Apply Template, and Add can instantiate a template. The reduced editor changes name, task title, plain description, checklist and priority while preserving styled content and fields outside the editor. [Implementation record](../changes/mobile-templates-2026-11-09.md).
- **Manual task order.** In Tasks List view with Default Order and date grouping off, drag an active row grip above or below a visible sibling. Move earlier and Move later are available as accessibility actions. Pin and section groups keep their boundaries. [Manual order contract](../changes/iphone-manual-task-order-2026-11-10.md).

**Local batch editing.** Tasks Actions → Select Tasks opens the current List scope. Choose an action and review the draft before applying date, priority, tags, list, completion or recoverable Trash changes. [Batch editing contract](../changes/task-batch-editing-2026-11-10.md). Tasks and Calendar can [postpone timed tasks by one hour](../changes/task-batch-postpone-2026-11-10.md). Calendar offers eligible tasks from the saved sources across dates.

These layouts need phone-specific design and acceptance checks. Record them as desktop-derived adaptations rather than screenshot matches. Section 14 supplies the implementation traceability.

<a id="ios-003"></a>

## 9 Screenshot reference and visual acceptance

Refines **IOS-003, IOS-013 and IOS-014**. The requested direction is near-pixel-perfect visual correspondence to the supplied TickTick iOS screenshots for matched screen states. This is more specific than using generic iOS controls or a similar blue accent. Match composition, component size, spacing, text hierarchy, icon alignment, surface colors and overlay layering. Keep Taskovsky business rules and safety gates intact.

### Evidence and coordinate rules

The source is `/Users/mental/Projects/ReaTickTick/MobileScreeshots/`. All 24 files are 591 × 1280 JPEGs with sRGB metadata. They are scaled/compressed reference images. Coordinates below are approximate **source pixels**, with the origin at the top-left of the complete image; they are not points, device pixels at a known scale, CSS pixels or recovered Auto Layout constants.

Use three evidence labels throughout implementation notes:

- **Observed:** Visible content, ordering, geometry, colors or a settled state in an identified reference image.
- **Proposed:** A Taskovsky interaction, feature mapping, native implementation choice or QA tolerance chosen to reproduce the appearance safely.
- **Unknown:** A property that the images cannot establish, including the interaction that led to a state.

The user identified the device as iPhone 13 Pro; the aspect ratio alone did not establish it. Do not use 591 as a logical-point width. For reference comparisons, record the crop and use a single uniform scale. Normalized anchors x/591 and y/1280 remain useful for locating source components, not independently stretching the app on two axes. On another aspect ratio, keep safe areas and layout responsive. Exact near-pixel-perfect sign-off remains subject to the unverified capture/display settings in D11.

The images contain private tasks, names, tags, history and profile content. Use sanitized fixture text with similar line lengths, wrapping, hierarchy, item counts and completion states. Never use those personal strings as app defaults, test fixtures or public assets. No screenshot is embedded in or uploaded with this specification.

### iPhone 13 Pro calibration

**Verified hardware:** Apple lists the iPhone 13 Pro portrait display as **1170 × 2532 pixels** in its [technical specifications](https://support.apple.com/en-us/111871). The standard full-screen reconstruction baseline is **390 × 844 logical pt at 3×**. Microsoft's maintained [Playwright device definitions](https://github.com/microsoft/playwright/blob/main/packages/isomorphic/deviceDescriptorsSource.json) corroborate that screen size and scale; its separate browser viewport is not the native app canvas. Apple's hardware specification does not itself document the logical-point size.

**Capture qualification:** Assume standard display scaling and an uncropped full-screen image when using this baseline. The user confirmed the model, not Display Zoom or text settings. [Apple's display guidance](https://support.apple.com/guide/iphone/make-text-easier-to-read-iph3c076905a/ios) confirms that Display Zoom and text/Bold Text settings affect appearance. Device identification cannot recover exact fonts, weights, original colors or compressed detail.

| Calibration | Calculation | Meaning |
| --- | --- | --- |
| Horizontal native-to-file factor | 591 / 1170 = 0.505128205 | About 50.5128% of native pixel width |
| Vertical native-to-file factor | 1280 / 2532 = 0.505529226 | About 50.5529% of native pixel height |
| File pixels per standard logical point | 591 / 390 = 1.515384615 horizontally; 1280 / 844 = 1.516587678 vertically | Approximately 1.516 supplied-image px per point |
| Aspect ratio difference | File 0.461718750 versus native 0.462085308; relative difference about −0.07933% | Too small to infer nonuniform stretching or cropping |
| Uniform height-fit check | 1170 × 1280 / 2532 = 591.469194 px, rounded to 591 | Ordinary integer rounding explains the observed dimensions |

Use a **390 × 844 pt artboard** as the primary reconstruction target and a uniform height-based factor of approximately **1.51659 source px/pt** for initial measurements. This is an estimated inverse of the resize, not proof of the original export pipeline. Prefer re-rendering a native 1170 × 2532 capture and uniformly resizing it to the reference canvas with recorded rounding; do not introduce anisotropic scaling to force exact edge equality.

| Observed component | Source measurement | Approximate standard-display point estimate |
| --- | --- | --- |
| Main card leading inset and corner radius | 24 px each | 15.8 pt; 16 pt is a candidate to test |
| Top circular toolbar control | 69 px diameter | 45.5 pt visual diameter |
| Task completion square | 24 px, roughly 5 px radius | 15.8 pt square, 3.3 pt radius; still needs a 44 pt hit target |
| Ordinary row pitch | 73 px | 48.1 pt |
| Floating Add button | 94 px diameter | 62.0 pt |
| Bottom capsule | approximately 534 × 88 px | approximately 352.1 × 58.0 pt |
| Drawer width | 516 px | approximately 340.2 pt |
| Detail settled top | y646–647 px | approximately y426.0–426.6 pt |
| Primary action and More top | y431 / y537 px | approximately y284.2 / y354.1 pt |
| Tall sheet top | y72 px | approximately y47.5 pt |
| Search keyboard top | y824 px | approximately y543.3 pt in this captured state |

These are calibration candidates, not exact design tokens. Do not infer font point sizes by dividing approximate visible glyph heights, and do not freeze safe-area or keyboard dimensions from this one state. Keep the source-pixel table below as the actual measurement record.

### Reference register

Each file name below is exact. R identifiers are local evidence references for this draft, not new repository requirement IDs.

| ID | File | Visible state |
| --- | --- | --- |
| R01 | `2026-11-08 23.02.39.jpg` | Inbox grouped task list, nested task, FAB and bottom tab capsule |
| R02 | `2026-11-08 23.03.10.jpg` | Task detail at a settled half-sheet height |
| R03 | `2026-11-08 23.03.14.jpg` | Primary task action sheet with four action tiles and grouped rows |
| R04 | `2026-11-08 23.03.18.jpg` | Secondary More sheet |
| R05 | `2026-11-08 23.03.23.jpg` | Expanded task editor with tag entry, suggestions and keyboard |
| R06 | `2026-11-08 23.03.26.jpg` | Expanded task editor with checklist placeholder and keyboard |
| R07 | `2026-11-08 23.03.31.jpg` | Attachment-source popover over task detail |
| R08 | `2026-11-08 23.03.36.jpg` | Dark-indigo navigation drawer |
| R09 | `2026-11-08 23.03.42.jpg` | Settings sheet |
| R10 | `2026-11-08 23.03.47.jpg` | Drawer Add popover |
| R11 | `2026-11-08 23.03.52.jpg` | Smart Lists management |
| R12 | `2026-11-08 23.03.55.jpg` | Tags management |
| R13 | `2026-11-08 23.03.59.jpg` | Calendar Week as a two-column card grid with mini-month |
| R14 | `2026-11-08 23.04.03.jpg` | Calendar mode menu with Week selected |
| R15 | `2026-11-08 23.04.07.jpg` | Calendar List agenda |
| R16 | `2026-11-08 23.04.11.jpg` | Calendar Year heatmap |
| R17 | `2026-11-08 23.04.15.jpg` | Calendar Month grid |
| R18 | `2026-11-08 23.04.19.jpg` | Calendar 3 Day time grid |
| R19 | `2026-11-08 23.04.23.jpg` | Calendar Day time grid |
| R20 | `2026-11-08 23.04.27.jpg` | Calendar Week time grid, distinct from R13 |
| R21 | `2026-11-08 23.04.31.jpg` | Calendar overflow menu |
| R22 | `2026-11-08 23.04.35.jpg` | Calendar View Options sheet |
| R23 | `2026-11-08 23.04.38.jpg` | Eisenhower Matrix with bottom More tray open |
| R24 | `2026-11-08 23.04.42.jpg` | Search history, filters and keyboard; no result list |

### Measured visual baseline

Values are rounded observations from the decoded JPEGs, not exact source-design constants. Preserve a record of the sampling/measurement method when turning them into implementation tokens.

| Element | Observed source-pixel geometry | Reference |
| --- | --- | --- |
| Top circular toolbar controls | Leading x23–92, trailing x499–568, y70–139; approximately 69 px diameter | R01 |
| Inbox group card | x24–565, y253–908; roughly 24 px corner radius; leading margin about 4.1% of image width | R01 |
| Ordinary row rhythm | Row centers y363, 435, 508, 581, 654, 727, 799, 872; roughly 73 px pitch | R01 |
| Completion and indentation | Rounded square about 24 × 24 px, radius about 5 px; main text x94; nested control near x109, text x140 | R01 |
| Floating Add button | x469–562, y1040–1133; approximately 94 px diameter | R01 |
| Bottom capsule | x29–562, y1162–1250; approximately 534 × 88 px; strongly rounded ends | R01 and Calendar |
| Bottom selection and spacing | Selected bubble about 98 × 78 px; icon centers x86, 190, 295, 400, 505 | R01 and Calendar |
| Drawer | Approximately 516 px wide, 87.3% of reference width; darkened underlying content visible to the right | R08 |
| Detail and action overlay top edges | Detail y646–647; primary actions y431; secondary More y537 | R02–R04 |
| Tall sheet top edge | y72, rounded upper corners, previous surface visible above | R09, R11, R12, R22 |
| Matrix cards | Left x24–288, right x303–566; upper y169–646; lower cards start y662 | R23 |
| More tray | x29–562, y960–1250; ordinary bottom tab row remains inside lower area | R23 |
| Search field and close | Field x24–483, y171–239; separate circular X x499–568 | R24 |
| Search filter and history layout | Filter pills y262–312; history heading around y356; history card x24–566, y396–688; Clear History around y760 | R24 |
| Search keyboard | Starts near y824, no prediction row in this state, blue Search key | R24 |

Native-looking sans-serif typography appears consistent with the SF family, but the actual face, point size, weight, tracking and line-height settings are unknown. Visual estimates are roughly 26–27 source px for ordinary body/menu text and 46 source px for display titles. Use system typography as an implementation candidate and calibrate against line breaks and baselines; do not record those estimates as recovered font settings.

| Sampled surface | Approximate decoded JPEG color | Interpretation |
| --- | --- | --- |
| Main page background | `#F2F3F8` | Light cool-gray page surrounding white content |
| Content cards | `#FFFFFF` | White card interiors |
| Navigation drawer | `#242B57` | Dark-indigo surface |
| Selected drawer row | `#2C3A78` | Lighter blue-indigo selection |
| Floating action/modal blue | `#4670FA` | Reference accent candidate |
| Enabled switch blue | approximately `#4872FA` | Similar but not assumed to be an identical source token |
| Action-sheet body | approximately `#FAFAFA` | Near-white action surface |

These replace the earlier unmeasured `#5171F2` suggestion for reference matching. Re-sample clean interior regions and test contrast before fixing production tokens. Text colors, task tints, outlines, shadows, blur/material parameters and every status color were not fully recovered. Native semantics should provide accessible light/dark variants, but must not silently alter the default reference appearance.

In R02 an underlying white area reads near RGB153, consistent with roughly 40% effective black dimming. In R03/R04 it reads near RGB92, roughly 64% effective dimming. The latter may be compounded overlays. Treat those as observed composite results; do not hard-code a universal 64% scrim or assume a particular stacking implementation.

### Task action and editor mapping

R03 has four equal top action tiles: **Pin** in yellow, **Share** in green, **Won't Do** in blue, **Delete** in red. Its grouped rows are **Add Subtask, Link Parent Task, Convert to Note, Attachment, Tags, Task Activities, Add to Live Activity**, followed by a separate **More** row. R04 has a centered More title, circular X at upper left, grouped **Comment, Location Reminder, Copy Link, Duplicate, Save as Template, Search, Print**, and a blue **Edit** action below.

Match the grid/row hierarchy, dividers, corner treatment, leading symbols, typography and sheet layering for the actions Taskovsky actually supports. The following is a proposed capability map, not a claim that these phone commands exist:

| Reference action | Taskovsky mapping or release rule |
| --- | --- |
| Pin, Won't Do, Delete | Shared pin/lifecycle commands; Delete is labeled Move to Trash for ordinary tasks; purge remains a distinct confirmed Trash action |
| Add Subtask, Link Parent Task | Shared child/hierarchy commands with cycle, list and archive validation; no ad hoc view-only relationship writes |
| Convert to Note | Task Actions converts between task and note in place, clears completion status and preserves content and existing links. [Verification](verification.md#mobile-task-actions) |
| Tags | Existing-tag picker with reference editor/suggestion presentation; new-tag creation is separately validated |
| Duplicate | Task Actions invokes the shared Mac copy rules for active-list and Inbox items. It opens the independent copy on success. [Verification](verification.md#mobile-task-actions) |
| Save as Template | Implemented Save/Apply Template and Settings template management remain in scope; preserve desktop field limits and body safety |
| Search | Search within the supported scope; exact task-local versus global meaning is not established by the image |
| Share, Copy Link, Print | Excluded: no implemented desktop task-sharing, task-deep-link or print action found |
| Attachment, Comment, Task Activities, Live Activity, Location Reminder | Excluded: absent from inspected desktop model/UI/services; a created timestamp is not an activity stream |
| Edit and customizable action order | More → Edit moves supported local actions between Pinned and More, and reorders each group. Done saves the iPhone presentation preference. Cancel discards the draft. Restore and Delete Forever retain their existing placement and confirmation. [Action layout contract](../changes/iphone-task-action-layout-2026-11-10.md) |

R07 lists **Camera, Photo, Record, Files, Scan Documents, Scan Text** in that order. This is evidence only. Desktop has no attachment model or these capture/import flows, so the paperclip and entire menu are excluded from mobile scope, including permissions and acceptance targets. Do not render a dead paperclip for resemblance.

R05 and R06 are existing-task editing states. Preserve the keyboard-adjacent tag pill and separate keyboard-dismiss control, the rounded four-row suggestion popover, checklist outline and placeholder spacing. The images do not prove autosave, tag creation, keyboard-dismiss semantics or which rich-text features are editable. Section 7 defines the compatible authoring subset and the lossless preview.

### Drawer and management mapping

R08 shows a profile photo/name and premium crown, an upper-right shared pill with bell/settings symbols, smart destinations, ordinary lists with trailing counts, an expanded folder with indented children, Archived Lists, and bottom circular Add and management controls. The smart entries visible include Today, Next 7 Days, Inbox selected and Subscribed Calendars. Preserve composition and supported hierarchy, but replace identity/premium content and omit calendar subscriptions and account/premium utilities that desktop does not implement. The existing local reminder list is a separate desktop-backed capability and must not be confused with an external notification service.

R11 has a Smart Lists/Tags segmented control and upper-right confirmation check. Visible settings are All Hidden; Today Show; Tomorrow Hidden; Next 7 Days Show; Assigned to Me Show if not empty; Inbox Show; Subscribed Calendars Show; and a separate history group with Completed Hidden, Won't Do Show if not empty, Trash Hidden. Add Filter follows. These are observed **example settings**, not Taskovsky defaults. Desktop implements Show/Hidden/Show if not empty, but its smart keys are All, Today, Tomorrow, Next 7 Days, Inbox, Summary, Tags, Filters, Completed, Won't Do and Trash. Assigned to Me and Subscribed Calendars are absent and excluded. Preserve desktop Summary/Tags/Filters access even where this captured panel does not show the same rows.

R12 shows Tags with Show if not empty, an Add Tag action and four personal tag rows. Preserve the layout and row-length variation using neutral fixture names. Existing tag semantics and hierarchy remain those in Section 8.

R09 Settings shows Tab Bar; Appearance; Sounds & Notifications; Date & Time; Widgets; AI Features; General; Integrations & Import; Help & Feedback; Follow Us; About v8.2.41. The header includes profile/level/badge material. Keep supported Taskovsky settings in this visual form, use Taskovsky's actual version in About, and omit premium/profile, AI, widgets, account or integration claims that are not implemented. Child-setting screens and the exact settings commit behavior are unobserved.

### Calendar layout mapping to desktop

Desktop Calendar is in scope because it is already implemented, not because the screenshots contain Calendar. Its seven modes are **Day, Week, Month, Year, Agenda, Multi-Day, Multi-Week**. The reference menu instead lists List, Year, Month, Week, 3 Day, Day and also shows two different Week presentations. These are different product taxonomies. Use desktop mode identity and semantics; adapt labels/controls without adding the extra screenshot mode or losing Multi-Week.

| Desktop mode or capability | Matching reference evidence | Mobile requirement and limits |
| --- | --- | --- |
| Day | R19 | Full seven-day header, selected/current-day distinction, all-day strip and single-day hourly grid, backed by the desktop Day projection |
| Week | R20 | Seven-day hourly timeline with timezone gutter, all-day strip and shared task scheduling semantics. Grid x78–576 and all-day y253–289 are reference geometry, not new data rules |
| Month | R17 | Seven-column month grid with task bars and muted adjacent-month dates; row count follows the actual month, not the five rows visible in one screenshot |
| Year | R16 | Three-by-four mini-month arrangement and heatmap appearance can inform the desktop-backed Year view. Preserve the standard and heatmap options. Tap a date to preview the scheduled items without changing views. Done returns to the same Year position. Open Week navigates to that date. [Year preview contract](../changes/calendar-year-day-preview-2026-11-10.md) |
| Agenda | R15 | Adapt the reference List layout: date strip, relative month label, timeline gutter and white task cards. Show more extends the local range by six calendar months and Today resets it |
| Multi-Day | R18 | Three-day screenshot is one configuration of the existing Multi-Day timeline, not a distinct 3 Day mode. Preserve the desktop 2–14 day range and timezone behavior |
| Multi-Week | No direct screenshot | Required desktop-backed calendar grid, configurable from 2–6 weeks with default 2. Derive styling from Month and use the actual projection; do not remove it because TickTick's menu omits it |
| List/tag Calendar filters | R21 Filter View Range is only a visual menu reference | Port desktop list/tag/Inbox/show-only-list scope. Do not infer extra temporal filter semantics from the screenshot wording |
| Arrange tasks | R21 menu affordance and the [TickTick FAQ](https://help.ticktick.com/articles/7055792921664028672) | Arrange retains its grouping, list and overdue controls. Drag a task grip from the half-height panel into a visible date or time. The precise editor remains available. [Arrange drag contract](../changes/mobile-calendar-arrange-drag-2026-11-10.md) |
| Task detail/schedule/undo | R02 and calendar task bars | Use the desktop task records, detail route, schedule commands and undo. No external-event entity is introduced |

**Timed duration reminders.** Task Schedule offers At the end under Reminders for a timed range. The staged end instant is shown there. Done saves the preference, and Cancel discards it. [Duration end reminder](../changes/task-duration-end-reminders-2026-11-10.md).

**Local follow-up.** Calendar stages This occurrence or Series when moving or resizing an eligible recurring card. Future cycles stay read-only. An edited occurrence can restore its baseline after relaunch. The timed start and end handles support direct drag where their endpoints and controls fit. Tapping a handle opens its staged editor. [Start resize contract](../changes/calendar-timed-start-resize-2026-11-10.md). In Week, Multi-Day, Month and Multi-Week, each true all-day endpoint has its own handle. Drag a handle to another date or tap it for the staged resize editor. A week-row continuation exposes only the endpoint it contains. [All-day start resize](../changes/calendar-all-day-start-resize-2026-11-10.md). In Week, hold a dragged Calendar task at the left or right edge to browse one week in that direction. Release over a date or time to schedule through the normal drop path. Releasing on the edge leaves the schedule alone. [Week edge paging](../changes/calendar-week-edge-paging-2026-11-09.md). [All-day resize](../changes/calendar-all-day-resize-2026-11-09.md). Show more extends Agenda without changing workspace or settings files. Pinch the Month grid or use its zoom buttons to show fewer weeks and more tasks per date. Zoom is temporary and preserves the focus week. Month and Multi-Week render all-day ranges as one segment per covered week row. Hidden cards count toward the date’s overflow link, which opens Day. Hold an empty cell and drag to another date to stage an inclusive all-day range in Month or Multi-Week. The capture sheet offers Start, End, and Use end date only. Recovery preserves the selected range until Add or discard. [Range capture](../changes/mobile-calendar-range-capture-2026-11-09.md). In Day, Week and Multi-Day, View Options can use Automatic or a fixed number of all-day rows. Overlapping all-day ranges occupy separate rows and extend across their visible dates. The shared strip scrolls as a unit when ranges span dates. Dates with only single-day entries keep their own scroll area. [All-day ranges](../changes/calendar-all-day-spans-2026-11-09.md). [Month zoom verification](verification.md#mobile-calendar-month-zoom). [Verification](verification.md#calendar-current-occurrence-agenda). Day, Week and Multi-Day show 07:00–21:00 by default and offer independent Early hours and Late hours controls. A count indicates items in each folded band. Revealing or folding either band changes the view only. Expand both bands to drag either cutoff in the primary ruler. View Options stages the whole-hour cutoffs and reset. Saved cutoffs survive relaunch. [Cutoff verification](verification.md#calendar-adjustable-cutoffs). [Folded hours verification](verification.md#calendar-folded-hours).

**Recurring Calendar card swipes.** In Agenda and Month, swipe right from an eligible recurring card title to open Schedule. Select Skip this occurrence and tap Done to advance it. Cancel discards the staged action. The card menu remains available, and Calendar Undo restores the previous schedule. [Calendar card swipe contract](../changes/mobile-calendar-card-swipe-2026-11-10.md).

**Week swiping.** Week fits seven day columns when the rulers leave room. A horizontal swipe browses to the next or previous week. When extra rulers make the grid wider than the viewport, pan to the edge first and swipe again to page. Vertical swipes scroll the hours. [Week swipe contract](../changes/mobile-calendar-week-swipe-2026-11-10.md).

**Compact Calendar titles.** Month and Multi-Week show the leading text of a title within the space beside the icon and scheduling controls. The card opens the full title and the move grip remains separate. [Compact title contract](../changes/mobile-calendar-month-card-titles-2026-11-10.md).

**Continuous Month.** Swipe vertically in Full Month to browse across months. The top visible week drives the header, and each first day is marked with its month. Previous, Next, Today and Jump to Date work in the same grid. Zoomed one-, two- and three-week views keep their existing paging. Browsing changes only the session focus. [Month scroll contract](../changes/mobile-calendar-month-scroll-2026-11-10.md).

**Local Calendar commands.** Tap the month header to open Jump to Date. The date wheel stages the selection until Go and preserves the active view mode. Cancel and sheet dismissal keep the current date. [Date jump contract](../changes/calendar-date-jump-2026-11-10.md). The phone's Calendar actions menu opens Arrange Tasks with Calendar sources, Inbox or an active list, optional overdue inclusion, and list/tag/priority grouping. The scheduling button stages a point or range for the focused day. Hourly views seed an undated task at 09:00–09:30. An actual task card exposes Edit Calendar Schedule, Move Schedule and Resize Schedule in its long-press menu and accessibility actions. Hourly and month grids accept task-card drops. Sufficiently tall hourly segments provide start or end handles at their visible endpoints. Resize Start in the card menu and accessibility actions is available for timed and all-day ranges, including compact cards. Recurrence and checklist previews are outside the scheduling affordances. Calendar Schedule can stage Skip this occurrence for an eligible repeating task. Done advances the same task and offers Undo. [Skip occurrence verification](verification.md#calendar-skip-occurrence).

**Calendar completion.** Agenda has a separate 44-point checkbox for current tasks and checklist items when task icons are visible. The card menu and accessibility actions offer Complete or Reopen even with icons hidden and in compact views. The title opens the task. Task completion uses the regular lifecycle and revision-bound Undo. Checklist completion retains the parent schedule and status. [Completion contract](../changes/calendar-card-completion-2026-11-10.md).

The phone uses an Arrange sheet for browsing and staged placement. The half-height sheet exposes the Calendar grid for dragging in Day, Week, Multi-Day, Month and Multi-Week. Expand the sheet for browsing and collapse it to drag. The Schedule button works at either height and in Agenda and Year. Arrange and Calendar card gestures apply the same operations as the desktop and use a session-scoped payload. A Calendar save shifts manual reminders under the shared Calendar rules, refreshes automatic reminders, and offers schedule-only Undo. Cancel and untouched Done leave the workspace bytes intact. [Arrange verification](verification.md#mobile-calendar-arrange).

**Excluded Week card mode:** R13 shows a two-column Week card grid with a mini-month in the upper-left cell, Sunday upper-right, subsequent weekday pairs and dividers near y406, 658 and 909. It is retained as observed evidence only. Desktop has no separate Week card mode or corresponding toggle, so Taskovsky must not add one, a mode-switch button for it, or an acceptance test requiring it. Its decorative task-bar styling may inform existing grid cells without changing the mode structure.

Desktop Week and Multi-Day use hourly timelines; Month and Multi-Week use calendar grids. Calendar task bars may use the reference's pale fills, saturated leading stripe, rounded-square completion, truncated title, trailing time and faded completed treatment, while retaining desktop coloring/style settings and projection semantics. The source's dates, GMT+3 label and current-time position are fixtures, not hard-coded defaults.

R21 includes Filter View Range, View Options, Arrange Tasks, Calendar Subscription, Share and Print. The Taskovsky menu includes only desktop-backed filtering, view options and Arrange functions. Calendar Subscription, Share and Print are excluded. A reference label does not override the real command; choose wording that accurately describes the desktop operation.

R22's captured values are not Taskovsky defaults. Map each visible setting to actual desktop code:

| Reference setting | Desktop-backed Taskovsky scope |
| --- | --- |
| Color | Implemented list/tag/priority coloring; preserve that option set |
| Style | Implemented filled/outline rendering; preserve that option set |
| Show Completed | Implemented task visibility toggle; do not include habits or subscribed events mentioned in TickTick helper text |
| Show Checklist Item | Map only to the implemented desktop checklist display setting and its actual semantics |
| Show All Repeat Cycles | Map to existing projected recurrence/preview setting; do not imply unbounded new recurrence generation |
| Additional Time Zone | Implemented named secondary Calendar rulers; retain existing timezone validation |
| Show Details | R22 limits the switch to mobile List and Month. Taskovsky displays time and source list in Agenda and Month as a distinct staged preference. [Show Details contract](../changes/mobile-calendar-details-2026-11-10.md) |
| Show Declined Events, Show Focus Records, Apple Health Data | Excluded: no desktop external-event, focus-record or Health implementation |

Also retain desktop View Options absent from the shown TickTick panel: Year standard/heatmap, item icons and configurable Multi-Day/Multi-Week ranges. Missing mobile controls are implementation gaps, not grounds to drop these desktop features. Source links and exact local snapshot evidence are in Section 14.

**Local display preferences.** The phone saves the selected Calendar mode. Filter and View Options sheets stage changes until Done. Filters provide All, Inbox, list and tag group controls, show-only-list actions and explicit recovery for unavailable saved sources. Cancel leaves saved scope intact. A failed mode save can still open the view for the current session. Focus date and Arrange visibility remain transient.

The View Options sheet controls list/tag/priority color, filled/outline style, master and independent task/note icon visibility, completed/checklist/repeat visibility, Show Details for Agenda and Month, Year Standard/Heatmap, Multi-Day 2–14 days and Multi-Week 2–6 weeks. Secondary rulers can be searched, named and reordered within their own staged editor. Up to four appear beside the primary ruler in hourly views. Ruler time conversions use the first displayed date, as on Mac. The phone presents source selection in a sheet and preserves the Mac-only sidebar preference. [Calendar preference verification](verification.md#mobile-calendar-preferences). The List and Tag choices open a source-color page. Its picker and Default actions edit the View Options draft, which saves on Done. [Color editor contract](../changes/calendar-source-colors-2026-11-10.md).

No screenshot demonstrates task creation, dragging, resizing, scrolling, pagination, keyboard shortcuts or undo. Mobile versions of operations already implemented on desktop require their own touch designs and behavior tests. Unsupported gestures are not added from assumption, and desktop-backed operations are not removed because a still image cannot show them.

### Excluded Matrix and supported Search reference

R23 uses four white rounded cards in a two-by-two layout. Header order is **I Urgent & Important**, **II Not Urgent & Important**, **III Urgent & Unimportant**, **IV Not Urgent & Unimportant**, with pink, yellow, blue and green header treatments. Long headings truncate. Rows use rounded-square checks, wrapped titles, faded checked content, red due lines and optional child chevrons. Long quadrants show **View More**.

This paragraph records visual evidence only. Matrix is absent from the inspected desktop routes and is excluded from Taskovsky mobile scope. No quadrant algorithm, Matrix tab, Matrix data model or Matrix acceptance target is to be added. The More tray overlays the reference Matrix and shows More, blue Edit and two unlabeled sparkle/hexagon icons; it is also excluded. Neither an unknown icon nor a plausible interpretation supplies feature scope.

R24 shows a rounded search field with a separate circular X, Task/Tag/List/Event filter pills, Search History, a four-row white history card, Clear History, a leading tag control, trailing keyboard-dismiss control and native keyboard with blue Search key. Match the source geometry and hierarchy with neutral prior queries. Desktop already implements recent-search persistence, clear history, case-insensitive de-duplication and a ten-entry cap; retain those semantics in device-local phone state. Supported search includes tasks/notes, lists, tags and filters, not events. Replace the Event pill with desktop-backed filter access where appropriate, or omit it; do not add event search. The reference-only leading tag control and X behavior are not established by the image, so provide only actions grounded in desktop search or necessary phone dismissal. Search results need a mobile layout for the existing desktop result categories, including filters that the screenshot does not show.

### Visual verification workflow

Near-pixel-perfect is an acceptance target, not a statement that the current app matches. No Taskovsky iPhone screenshots or visual comparison runs were produced for this revision.

1. Freeze reference metadata, screen ID, source crop, captured state and neutral fixture. Record app commit, OS, device, logical viewport, display scale, appearance, locale, font category, time and keyboard state for each Taskovsky capture.
2. Reproduce only the reference components mapped to implemented desktop features: drawer, task sheet, supported action rows, tag/checklist editor states, management, mapped Calendar modes/options and Search. Exclude R07 attachment menus, R13 Week cards, R23 Matrix/More, and unsupported rows within other images. Add mobile snapshots for desktop-backed features without screenshots, including Multi-Week and filter editing, but label them design adaptations rather than reference matches. A single Inbox comparison is insufficient.
3. Compare at equivalent crop and uniform scale. Keep a masked whole-frame comparison for structure and unmasked component crops for control details. Exclude changing system status information and private text, but do not mask whole cards or areas that would hide layout defects. Use equal-length neutral fixtures for text wrapping checks.
4. Review overlays and difference images for major edges, gutters, row pitch, corner curves, icon centers, baselines, line breaks, opacity and surface colors. Automated image metrics may support this review but cannot prove parity across JPEG artifacts, unknown font rasterization or native OS material differences.
5. Proposed initial tolerance at 591 × 1280: major measured anchors within about 2 source px and repeated spacing within about 1–2 px, with matching title/metadata wrapping for the neutral fixture. Calibrate against measurement uncertainty and obtain approval before making these release thresholds. Flat-region color comparisons must allow JPEG variation; avoid a zero-error pixel requirement.
6. Record every deliberate deviation, its reference ID, reason and approval status: desktop-scope exclusions, safer destructive wording, accessibility layout, unsupported viewport, different system chrome, unresolved glyph or missing reference. Keep visual, behavioral and data-safety verdicts separate.

Exact icons, SF Symbols names, font settings, blur radii and touch-hit sizes cannot be recovered reliably from these JPEGs. Use legal platform glyphs or original vectors that match the visible shape and weight; do not claim an exact symbol identity without verifying it. Native framework choice is an implementation decision, not evidence about how TickTick was built.

### Accessibility and missing states

At the proposed default-text reconstruction baseline, preserve the compact composition. In accessibility modes, usability takes precedence over literal fixed geometry. Minimum interactive targets remain **44 × 44 logical pt**, including completion, Add, menus, picker controls and tab icons. Visual glyph dimensions may be smaller. Neighboring hit regions cannot overlap or steal row navigation.

Use semantic text styles with calibrated default rendering, scalable rows/cards, leading/trailing layout and native text input. Large text may stack metadata, expand sheets, replace dense icon rows with labeled actions and allow scrolling. No title, action or validation message may become unreachable beneath the keyboard or bottom capsule. Account for safe areas and keyboard changes using platform information, not fixed source-pixel heights.

VoiceOver order follows visual order. Announce task title and state, independently label completion, identify parent/child links and checklist values, and provide names for every icon-only tab/button. Covered screens must not retain focus. Restore focus after dismissal, validation failure and disappearing rows. Every swipe action has a non-gesture equivalent. Haptics are supplemental. Custom transitions honor Reduce Motion.

Audit at least 4.5:1 contrast for ordinary text and 3:1 for large text and meaningful control boundaries, including light, dark and Increase Contrast. Test Bold Text, Reduce Transparency, color-independent state interpretation, RTL, long localized labels, selection, emoji, combining characters, multiline paste, dictation, software/hardware keyboards and IME marked text. Do not commit half-composed input on a refresh.

Use the qualified 390 × 844 pt iPhone 13 Pro baseline for reference reconstruction. Add 375 pt and 430 pt portrait layouts as provisional responsive stress fixtures, plus landscape and all accessibility categories; those extra widths are not a supported-device declaration. A 320 pt stress check may reveal fragile assumptions but does not establish device support. D02 defines the actual matrix.

**Missing reference evidence:** new capture, due/repeat picker, priority menu, actual search results, list/tag creation, detailed Settings child pages, drag/swipe animations, keyboard transitions, dark appearance, empty/error/offline/loading/conflict states, accessibility text and iPad. Specify and test these states independently; never label them screenshot-matched. Save failures, stale edits and incompatible data retain the behavior in Sections 7 and 10 even where the reference does not show them.

<a id="ios-013"></a>

## 10 State persistence errors and conflicts

Refines **IOS-011, IOS-012 and CMP-004**.

| State | User-visible behavior | Data rule |
| --- | --- | --- |
| Loading actual data | Progress only when asynchronous load is in flight | No empty writable replacement while load status is unknown |
| Ready empty | Context-specific empty message and valid Add action | Empty is a known successfully loaded workspace |
| Filtered empty | Explain no matching tasks; allow criteria change | Do not alter the filter to manufacture results |
| Editing | Local draft and explicit Done/Cancel | No partial store writes |
| Saving | Prevent duplicate command; keep input | Do not claim durability before repository acknowledgment |
| Save failed | Specific error, draft retained, Retry/Keep Editing | Preserve last durable file and pending command identity |
| Compatibility read-only | Explain unsupported data and safe available actions | Preserve original bytes; no automatic downgrade |
| Workspace unreadable | Clear blocked state and recovery choice | Original retained; backup must succeed before replacing |
| Stale edit | Explain source changed; keep draft; offer review/reload | Expected revision prevents silent overwrite |
| Task removed while open | Item unavailable with Back/history route | Stale callback cannot recreate it |
| Background/foreground | Retain draft, restore route, refresh time-relative labels | Backgrounding does not submit; revalidate before commit |
| Local alert unavailable or out of sync | Separate permission/scheduler status and retry guidance | Task data remains durable; scheduler failure is not a failed or rolled-back task save |

Proposed command results distinguish durable success, no change, validation refusal, stale state, compatibility lock and persistence failure. For the initial single-device repository, either stage a change until durable write succeeds or publish an explicitly unsaved state with retry semantics. Select one behavior during the storage design; do not let each screen invent its own optimistic rollback.

Workspace and settings are separate files today, not one transaction. Any command needing both must document ordered writes and recovery from partial failure. File atomic replacement protects one file from partial bytes; it does not supply cross-file consistency, multi-writer locking or synchronization.

The iOS app uses its sandbox and injected test directories. Never point a simulator, test harness or recovery experiment at the user's Mac workspace. Choose appropriate platform file protection and backup inclusion as part of the storage adapter. Do not promise encryption, account recovery, audit logs or telemetry that have not been designed. Diagnostic logs must avoid task bodies, private titles and payload dumps by default.

<a id="ios-012"></a>

## 11 Shared engine and platform architecture

Keep the iPhone SwiftUI/UIKit views separate from the Desktop SwiftUI/AppKit views where isolated visual parity is uncertain. Each platform owns its layout, rendering, gestures and view state. Share model, storage and business rules through the [platform architecture boundary](../architecture/shared-engine.md#platform-presentation-boundary).

Refines **ARCH-002 through ARCH-006 and IOS-012**.

Use one repository with the smallest practical target graph. Proposed ownership:

1. **Shared domain and use cases:** value models, hierarchy/lifecycle, command validation, recurrence and schedule intent, queries/counts, rich-body representation and capability classification. No AppKit, UIKit, SwiftUI, concrete disk access or networking.
2. **Application session:** command serialization, observable snapshots, edit revisions, durable-result state, injected clock/ID/calendar/repository/services. A compatibility facade can keep the Mac app working during extraction.
3. **Workspace repository and services:** local files, compatibility/migration/recovery, settings and optional URL-title adapter. Keep platform paths outside domain rules.
4. **macOS app/editor adapter:** existing SwiftUI/AppKit interface, native controller/coordinator, rendering, selection, undo and layout.
5. **iPhone app/editor adapter:** SwiftUI navigation/forms with an appropriate native text host, touch, keyboard/lifecycle, accessibility and conservative body capabilities.
6. **Conditional local-notification adapter:** UserNotifications authorization, request identifiers, scheduling/cancellation and reconciliation remain platform services outside the shared domain. Derive requests from durable shared reminder state; no APNs/network service or new recurrence engine.

Core's current name is not a portability certificate. Move AppKit rich rendering, list decoration/layout and sizing behind a Mac adapter target. Keep Foundation RichBody values shared. The production editor controller/coordinator must be importable by its harness; tests that reproduce callbacks separately are not sufficient host coverage.

Extract the still-view-owned task destination composition, schedule apply/clear, existing-task template application and search scope before reproducing them on phone. Reuse existing Calendar schedule/projection seams where their semantics match, but do not assume the Calendar command replaces every detail schedule operation.

### Proposed command and query families

These are behavioral contracts, not final Swift signatures:

- Create task/note from validated capture intent; instantiate a template.
- Patch owned metadata fields with task identity and expected revision.
- Commit a paired plain/rich body with document identity and capability check.
- Complete, reopen, Won't Do, trash, restore and purge through shared graph policy.
- Create/edit embedded checklist and linked child tasks without conflating them.
- Apply/clear a complete schedule draft with explicit operation intent.
- Create/rename/move/archive organizational entities through shared validation.
- Query a destination/search/filter from snapshot plus explicit clock/calendar, returning ordered IDs, groups/counts and permitted actions.

Domain output uses semantic IDs and typed refusal reasons, not localized strings, colors, views or gesture objects. Platform presentation chooses wording and geometry. Pure tests supply explicit time, zone, IDs and network fakes. Do not require one package per family or a complete store rewrite before a first vertical slice.

### Network and optional services

URL-title recognition is the existing network enrichment. When porting it, preserve HTTP(S), no credentials, public-host screening, redirect and time/size restrictions and the final title/setting recheck. It returns a candidate and never owns task creation. Failure leaves the user's title intact. Do not silently add analytics, uploads, cloud AI parsing or account requests to this scope.

Local edit revision protection is not synchronization. The user plans cross-device sync later; accounts, sync transport and shared mutable-file access are excluded from this pre-alpha. Keep phone data in its own persistent container and retain the local JSON approach; do not let two independent whole-file writers point at the live desktop workspace. Temporary architecture does not mean storing authoritative data in an OS-purgeable temporary directory.

<a id="ios-014"></a>

## 12 Delivery sequence and desktop coordination

Refines **ARCH-005 and IOS-014**. Each step is independently reviewable; none authorizes deployment or production-data experiments.

| Stage | Work product | Exit gate |
| --- | --- | --- |
| S0 Specification review | Record user decisions, desktop scope, conditional local notifications, provisional iOS 17 target and pre-alpha sequence | Source map reconciled; documentation PR reviewed; no implementation claimed |
| S1 Characterization and feasibility | Deterministic workspaces plus early iOS 17 build/API audit and Personal Team notification smoke test | Actual outcomes recorded; any notification deferral names the real blocker |
| S2 Portable seams | Move Mac editor adapter; extract command/query families incrementally | Mac regression checks pass; iOS domain dependency graph contains no AppKit |
| S3 Compatibility repository | Capability classification, field preservation, revisions, durable outcomes and failure/recovery | Mac–phone fixture round trips pass; unknown data is preserved or writes refused |
| S4 Read-only iPhone shell | Desktop-backed Tasks/Calendar/Search capsule, drawer, lists/detail and styled previews; no Matrix or screenshot-only routes | Screenshot comparisons for implemented states, navigation, small/large text, VoiceOver and no-write viewing checks pass |
| S5 Safe write and local alerts | Capture, permitted body edits, metadata, lifecycle, checklist/children and schedules; add narrow local notifications if feasibility gate passes | Durable writes and truthful scheduler states; cancellation, permission and reconciliation checks pass |
| S6 Local pre-alpha | Xcode-run physical iPhone build, optional Designed for iPhone/iPad Mac smoke test, usability and implemented-state visual checks | Exact device/OS/signing matrix and gaps recorded; no data-loss blockers or false notification claims |
| S7 Pre-alpha iteration | Continue required features and UI/UX polishing; keep sync and App Store release for later | Build limitations remain explicit; no screenshot-only additions, sync promise or Store submission |

Desktop work owns current Mac UI polishing. Mobile specification work owns no Mac implementation files. When implementation begins, use an isolated branch/worktree and assign ownership for shared files explicitly. Sequence shared-engine refactors in small PRs so unrelated desktop improvements are not accidentally reverted. Recheck the exact integration head and macOS tests after each shared change. Neither stale documents nor historical green CI authorize assuming the latest desktop build is safe.

Suggested first implementation ticket: **Characterize shared mobile contracts**, limited to deterministic fixtures and tests for destination scope, schedule apply/clear, rich/unknown payload retention and lifecycle. Follow with **Isolate the macOS editor**. Do not start with a wide phone UI that calls the current whole-record store and postpones data integrity.

## 13 Acceptance scenarios

These are proposed tests to implement and execute. Every row is **not run** for this specification update, including the new notification and deployment checks. Record exact commit, command/build, OS/device, fixture, expected/actual result and artifacts. A test source file is not evidence of a passing run.

| ID | Scenario and required outcome | Traceability |
| --- | --- | --- |
| A01 | Build shared domain for macOS and the provisional iOS 17 target using the recorded toolchain; dependency inspection finds no AppKit/UIKit/SwiftUI in domain and no unguarded later-OS API in baseline paths | IOS-012, ARCH-006, D02 |
| A02 | Same frozen workspace/query/time gives matching Mac and phone IDs/groups/counts, including overdue Today and smart/filter differences | IOS-004, BUS-016/018/021/023 |
| A03 | Capture from Inbox, list, tag, Today and a note-kind list; defaults and visible resolved values agree with shared policy | IOS-005, BUS-003 |
| A04 | Cancel populated capture by button, gesture and Back; no tasks/tags created. Double Add/retry yields one record | IOS-005, IOS-011 |
| A05 | Complete recurring parent with open/completed/Won't Do children; one successor tree, correct ledgers and independent stamps | BUS-007/008 |
| A06 | Reload then reopen/undo; later descendant edits and edited successors are retained according to shared guards | BUS-007/008, IOS-004 |
| A07 | Trash/restore parent with separately trashed child; child's independent deletion remains. Cancel purge changes nothing | BUS-009 |
| A08 | Confirm single-item purge in fixture; surviving direct children detach with no dangling parent IDs | BUS-009, IOS-004 |
| A09 | Move parent subtree, then child alone; lists and links follow shared rules. Cycle/archived target refused atomically | BUS-006/016 |
| A10 | Mac styled body → phone view/title/tag/list change → Mac reload; exact text/rich content and unowned fields preserved | IOS-008, RICH-004/005 |
| A11 | Unknown field/version/enum or malformed rich payload on edited and unrelated records; preserve original or block whole write | RICH-005, CMP-004 |
| A12 | Emoji, composed/decomposed text, long paste and IME; valid body pair, no premature marked-text commit or range trap | BUS-005, RICH-006 |
| A13 | Switch two tasks with identical bodies; Undo, delayed callback and external replacement cannot cross document identity | IOS-008, RICH-006 |
| A14 | Staged due/zone/repeat/clear then Cancel; all fields unchanged. Done applies one coherent transaction | IOS-007, BUS-012 |
| A15 | Edit custom-series due without changing rule; count preserved, nominal position rebased. No-change save preserves precise fields | BUS-012/013/029 |
| A16 | DST gap/fold, leap day, month-end, opposite-side zones and all-day range; dates, duration and successor cadence match engine | BUS-011/013/014 |
| A17 | Existing short/fractional/zero duration and manual/default reminders survive no-op picker save and unrelated metadata edits | BUS-011/014/029 |
| A18 | Template create/edit/delete/use and task Save/Apply match desktop field limits; styled instantiation retains complete body/checklist/schedule and unsupported body stays read-only | BUS-010, IOS-005/008, F11 |
| A19 | Embedded step, linked subtask and rich checklist each change only their own representation | BUS-002, IOS-006 |
| A20 | Search tasks/notes, lists, tags and filters; preserve query/criteria/position through detail→child→parent→Back and match archive/explicit-list scope. Recent queries retain clear, case-insensitive de-duplication and ten-entry cap | IOS-010, BUS-016/023, F05 |
| A21 | Delete list/tag referenced by saved filter; filter does not broaden. Advanced rules stay unchanged on supported metadata edits | BUS-015/017/021/022 |
| A22 | Board has Open/Completed/Won't Do with notes in Open and archived read-only behavior; mobile navigation/save does not overwrite Mac view mode or Calendar preferences. Rows-only staging is reported as incomplete Board support | IOS-004/011/012, F09 |
| A23 | Atomic-write failure, disk/protection error, corrupt workspace/settings and failed recovery backup; no false success or overwrite | BUS-025, CMP-004 |
| A24 | Background/terminate/relaunch during edit; recovered draft is offered, never auto-submitted; source conflict is preserved | IOS-011 |
| A25 | Item deleted/changed while editing; expected revision rejects stale commit, draft remains reviewable | ARCH-003, IOS-011 |
| A26 | Small/large supported iPhone, both orientations, all text sizes, light/dark/contrast and RTL; actions remain reachable | IOS-003/013/014 |
| A27 | VoiceOver completes capture, schedule, completion, search, restore and discard without swipe-only actions or focus traps | IOS-003/013/014 |
| A28 | View-only screens and malformed previews produce zero persistence callbacks and zero background network enrichment | IOS-008, RICH-006 |
| A29 | Trace every functional requirement to desktop code or the explicit D04 local-notification decision; reject screenshot-only additions, then establish capture viewport, crop, scale and system-chrome masks | IOS-002/003/014, Sections 2, 9 and 14 |
| A30 | Render each desktop-mapped reference state with neutral fixtures; compare geometry, typography, colors and icons. Exclude attachment menus, Matrix/More and Week cards; include separate adaptation snapshots for desktop-only views | IOS-003/014, Sections 9 and 14 |
| A31 | Verify Tasks/Calendar/Search routes and supported menus; use desktop fixtures for Board, Summary report filters/regenerate/Copy/Save as Note, advanced filters, flat folders, tag reparent/merge and existing move/reorder operations. Verify the separately documented local List batch selector and staged actions | IOS-002/003/014, F03/04/09/10/14 |
| A32 | Present task detail and supported editing states with the keyboard; editor, accessory controls, safe areas and scroll reachability remain correct without draft loss | IOS-005/006/011/013, Sections 5 and 9 |
| A33 | Verify desktop Calendar mode/settings parity: Day, Week, Month, Year, Agenda, Multi-Day 2–14 and Multi-Week 2–6; no Week card mode, event source, Matrix, attachment, account, collaboration, APNs/remote push, habit or focus feature is added; D04 local notifications are tested separately | IOS-002/009/011/014, Sections 2, 9 and 14 |
| A34 | Compare default-size visual fidelity separately from accessibility layouts; larger text, VoiceOver, contrast and touch targets remain usable even where they deliberately diverge from the reference | IOS-003/013/014, Section 9 |
| A35 | On a physical iPhone with recorded signing/account type, verify local-notification not-requested, allowed, denied and later-disabled states. Permission occurs in context; refusal preserves tasks/in-app reminders; no APNs entitlement/server is introduced | IOS-007/011/014, D04 |
| A36 | Schedule one existing future reminder; verify foreground policy, background and not-running behavior. Repeat with sound disabled, Focus and Scheduled Summary; distinguish accepted scheduling from actual presentation and never promise exact-time alarm delivery | IOS-007/014, D04 |
| A37 | Edit/remove reminders, change date/zone/defaults, complete/Won't Do/trash/archive, then reopen/restore/undo and create a recurrence successor. Reconcile stable request IDs without duplicates, stale alerts or new recurrence semantics; exercise DST and timezone changes | IOS-007/011/014, D04 |
| A38 | Inject scheduler failure, persistence/scheduling interruption and more reminders than the app-owned pending budget. Durable task data survives, nearest reminders and pending requests reconcile, overflow/retry is visible and no false alert-success state appears | IOS-007/011/014, D04 |
| A39 | Record the iOS 17 baseline build/runtime check, actual iPhone 13 Pro or available-device result, optional older-device/Mac tests and free-signing provisioning limits. App containers stay isolated local files; no sync, paid enrollment, TestFlight or App Store release is performed or claimed | IOS-012/014, D02/03/10 |

The scope register also serves as a coverage checklist: F01/F02 → A03–A09/A19; F03/F04 → A02/A09/A21/A31; F05 → A20; F06/F07/F08 → A14–A17/A22/A33; F09/F10/F14 → A22/A31; F11 → A18; F12 → A10–A13/A17/A18/A27/A28; F13 → A01/A11/A23–A25/A39; explicit D04 extension → A35–A38; deployment/storage decisions D02/D03/D10 → A39. Expand broad A31 and A33 into named deterministic feature fixtures before execution. This mapping is planned coverage, not evidence that every flow has been characterized or that any check passed. Missing source behavior, mobile layout and execution results remain explicit gaps; they cannot be filled with TickTick assumptions.

Retain relevant existing suites, including `TaskStoreTests`, `HierarchyLifecycleTests`, `TrashTests`, `OrgScopeTests`, `FilterIntentTests`, `FilterHardeningTests`, `ScheduleDraftTests`, `RepeatDraftTests`, `CloneReminderTests`, `NominalCadenceTests`, `NominalSeriesIntegrationTests`, `RichTextPinTests`, `BlockRangeTests`, `QuoteToggleTests` and `CalendarReviewRegressionTests`. Some remain macOS-adapter tests after extraction; relocating them does not make them iOS tests.

### Performance and reliability evidence

Measure cold launch, time to editable capture, query latency, list scrolling and durable save with deterministic small and large fixtures. A proposed fixture set is 100 tasks for interaction checks and 10,000 tasks with nested/recurring/styled cases for scale characterization; these are test workloads, not advertised capacity. Agree latency/memory budgets on the oldest supported real device after D02. Report measured p50/p95 and any blocking main-thread work rather than inventing performance results now. Data loss, silent compatibility downgrade and duplicate lifecycle effects block pre-alpha use with real data regardless of latency.

## 14 Repository integration and sources

The user requested a separate PR for this specification. Update canonical `docs/spec/iphone.md`, preserve `IOS-001` through `IOS-014` anchors, add the repository-required bounded `docs/changes/iphone-mobile-spec.md` record, and add a static documentation-verification entry. Do not create a competing mobile specification or include uncommitted desktop visual implementation files. PR #4 was documentation only and was merged at `6ee96ee`. Its publication did not itself authorize implementation; the subsequent autonomous local parity request authorizes the bounded implementation changes linked above. App Store release remains excluded.

Architecture and business documents remain linked sources. Any implementation-stage changes to them require reconciliation with the then-current source; this documentation PR must not imply portable targets, notification code, builds or device tests already exist.

### Current desktop implementation register

This register controls feature scope. It is based on a read-only inspection of `/Users/mental/Projects/Taskovsky` on the user's Mac, branch `codex/calendar-visual-parity`, HEAD `f85e2f6a9c538f36829961961a0749197f29c4e2`, including its uncommitted source changes. “Implemented” means statically present and reachable in inspected source, not newly runtime-tested by this specification review. Local line references below refer to that working-tree snapshot; paths are relative to `Sources/`.

| ID | Desktop implementation evidence | Scope consequence for iPhone |
| --- | --- | --- |
| F01 Tasks and notes | `TaskovskyCore/Models.swift:5–39`; `TaskovskyCore/Organization.swift:49–61`; `Taskovsky/TaskDetail.swift:211,258,350–357` | Tasks, notes, embedded checklist and linked child tasks remain distinct and in scope |
| F02 Lifecycle and task actions | `TaskovskyCore/TaskStore.swift:600,615,630–637,659,678,697–709,737`; `Taskovsky/TaskDetail.swift:271–295,320–331` | Pin, Won't Do, trash/restore, per-item purge, conversion, duplication and Save/Apply Template. Select Tasks provides the separately specified local batch actions |
| F03 Lists folders and tags | Store create/update list/tag `766,845,866,880`; tag parent/merge `913,1008`; folder operations `1160–1213`; `Taskovsky/App.swift:923–962,993,1007,1038–1122`; `TaskDetail.swift:436–459` | Preserve list edits/duplicate/archive/delete, flat folders with member lists, tag hierarchy/subtags/reparent/merge; do not add arbitrary nested folders |
| F04 Filters and smart visibility | `TaskovskyCore/TaskStore.swift:627–629`; `Taskovsky/FilterEditor.swift:4,276`; `TaskovskyCore/Settings.swift:3–14`; `TaskovskyCore/Organization.swift:11–32` | Saved-filter create/edit/query and Show/Hidden/Show if not empty remain in scope. Assigned to Me and Subscribed Calendars are excluded |
| F05 Search and history | `Taskovsky/SearchView.swift:94–121,237,240–245,260–261,304–305`; `TaskovskyCore/Settings.swift:474–475` | Tasks/notes, lists, tags and filters; date/status/list/tag/kind criteria; title/body/checklist text search; clearable recent searches, case-insensitive de-duplication, maximum ten. No event/comment/attachment search |
| F06 Navigation and Calendar modes | `Taskovsky/App.swift:174–175,763–768`; `TaskovskyCore/TaskCalendar.swift:3–11,61–62`; `Taskovsky/TaskCalendarWorkspace.swift:193–208,336–337` | Primary Tasks/Calendar/Search; Calendar Day/Week/Month/Year/Agenda/Multi-Day/Multi-Week. Multi-Day 2–14, Multi-Week 2–6 default 2. No Matrix or separate Week card mode |
| F07 Calendar options and time zones | `TaskovskyCore/TaskCalendar.swift:13–50`; `Taskovsky/TaskCalendarWorkspace.swift:310–341`; `Taskovsky/CalendarTimeZoneSettings.swift:14–51,88–98`; `TaskovskyCore/CalendarTimeZones.swift` | List/tag/priority colors, filled/outline, Year standard/heatmap, item icons, completed/checklist/repeat-preview toggles, range counts and named secondary zone rulers. The iPhone-only Show Details option adds local Agenda and Month metadata. Declined events, focus records and Health remain excluded |
| F08 Calendar filters Arrange and schedule | `Taskovsky/CalendarPanels.swift:158–193,251,286–293`; `Taskovsky/TaskCalendarWorkspace.swift:44–46,59–63,83–89,104–118,174,195–207,269–306`; `Taskovsky/CustomRecurrenceEditor.swift:9` | Workspace-task projections, list/tag/Inbox filters, show-only-list, Arrange grouping/list/overdue controls, detail/schedule/undo and legacy/custom recurrence. No external-event source or subscription |
| F09 Board | `Taskovsky/App.swift:308–312,1330–1361,1674–1709`; `TaskovskyCore/BoardProjection.swift`; `Taskovsky/TaskDetail.swift:466–472` | Per-list List/Board selector; fixed Open/Completed/Won't Do columns; notes in Open; archived boards read-only. Board is not Eisenhower Matrix |
| F10 Summary | [Mac Summary](../../Sources/Taskovsky/SummaryView.swift) and [iPhone Summary](../../Mobile/App/PhoneSummaryView.swift) | Local editable text report with period/list/tag/priority/status criteria, grouping, sort, optional fields, named presets, regenerate, Copy and Save as Note. Not an AI feature |
| F11 Templates | `Taskovsky/SettingsView.swift:111,241–248,361–395`; `Taskovsky/TemplatePicker.swift:35`; `Taskovsky/TaskDetail.swift:279–283` | Create/edit/delete/use existing template types. Settings editor exposes name, task title, plain body, checklist lines and priority; do not silently expand it into a richer template designer |
| F12 Rich bodies and reminders | `TaskovskyCore/RichText.swift:17–25,62–72,102`; `Taskovsky/RichBodyEditor.swift`; `Taskovsky/TaskDetail.swift:333–343`; `TaskovskyCore/Models.swift:25–36`; `Taskovsky/App.swift:1350,1525,1547` | Preserve rich/plain pairing and reminder dates/controls/in-app list. Fewer editor controls are permitted. Desktop has no OS delivery; D04 separately plans a conditional local iPhone adapter |
| F13 Local storage | `TaskovskyCore/TaskStore.swift:25–55,69–85`; `TaskovskyCore/Models.swift:350–365` | Keep JSON workspace/settings in each platform container for pre-alpha; sync planned later, no account/backend now |
| F14 Task-list batch editing | [Selection sheet](../../Sources/Taskovsky/TaskBatchSheet.swift) and [batch command](../../Sources/TaskovskyCore/TaskBatchEdit.swift) | Existing batch-capable move/reorder/drop operations remain available. Select Tasks provides the documented local batch date, priority, tag, list, completion and Trash commands |

Source scans and the inspected models/routes/detail UI found no product implementation for Matrix, attachments/camera/scanning, comments/activity stream, task link sharing/printing, Live Activities, location reminders, Focus/Pomodoro, habits, Health, AI, event subscriptions, accounts or sync. These are excluded. Absence findings are limited to the inspected source; if later code implements a feature, update this register from that code rather than from a screenshot label.

### Working tree identity and verification limits

The source review found three modified tracked Swift files and one untracked Swift file, plus documentation changes. The tracked-source diff hash and all four relevant file hashes were unchanged on final recheck:

- SHA-256 of `git diff HEAD -- Sources`: `4c3de1acf31005b3d353f1904901a1edcc9406160c0b5970c807090768d4fdab`. This digest excludes untracked files, so it is not sufficient alone.
- `Sources/Taskovsky/CalendarAppearance.swift` (untracked): `511284bad0388d8e9e260af6fa1bef18614be460b1f3bc8d312bd4f96a9fbd38`.
- `Sources/Taskovsky/CalendarPanels.swift`: `920b786790c09a555b5f2ba62515eeaf2c097aa8b00a2b8cd419b92c2ab3cac7`.
- `Sources/Taskovsky/CalendarViews.swift`: `ae366944c03cdf051e5ab29d7253176f8291e45462924bcccdf88be59a54c375`.
- `Sources/Taskovsky/TaskCalendarWorkspace.swift`: `f6ca354b84288f4f97116b7de8484238b411ffaf9be936df12f8c4f940bb30f8`.

No files were changed, user datasets read, app launched, build run or test executed during this source check. Earlier desktop test reports are separate evidence and are not promoted to a fresh validation of this spec or iPhone implementation. Local line numbers can drift after edits; use the hashes to identify this snapshot and recheck before implementation. Uncommitted local changes have no verified GitHub permalink. The pinned links below describe HEAD, not the dirty working-tree additions.

### Source register

Repository links below are pinned to the inspected commit to make the original source review reproducible. Later implementation must reconcile changes on main. The screenshot source is the exact user-supplied folder and filename register in Section 9; its images were inspected read-only and are not repository or implementation evidence. No reference images are redistributed in this artifact.

| Source | Used for |
| --- | --- |
| [Prior iPhone proposal at the source freeze][spec-iphone] | Historical IOS requirements and capability baseline; superseded by this canonical revision |
| [Business specification][spec-business] | Task/note, lifecycle, schedule, organization, search and storage contracts |
| [Shared engine architecture][spec-architecture] | Current couplings and proposed extraction |
| [Component contracts][spec-components] | Rich-body identity, opaque preservation and independent harness |
| [macOS UI specification][spec-ui] | Platform distinctions and existing source-derived interaction limits |
| [Development workflow][spec-workflow] | Approval states, small changes and evidence requirements |
| [Verification ledger][spec-verification] | Existing evidence boundaries and unverified areas |
| [Package.swift][src-package] | Current platform and target graph |
| [Models.swift][src-models] | Task/workspace identity and stored fields |
| [TaskStore.swift][src-store] | Whole-record updates, complete encoding, lifecycle and recovery |
| [RichText.swift][src-rich] | UTF-16 representation and document identity |
| [RichTextRender.swift][src-render] | Actual AppKit coupling |
| [ScheduleDraft.swift][src-schedule] | Existing staging and recurrence seams |
| [Settings.swift][src-settings] | Preferences, templates and filter semantics |

[spec-iphone]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/spec/iphone.md
[spec-business]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/spec/business.md
[spec-architecture]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/architecture/shared-engine.md
[spec-components]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/architecture/components.md
[spec-ui]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/spec/ui-ux.md
[spec-workflow]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/spec/workflow.md
[spec-verification]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/docs/spec/verification.md
[src-package]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Package.swift
[src-models]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Sources/TaskovskyCore/Models.swift
[src-store]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Sources/TaskovskyCore/TaskStore.swift
[src-rich]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Sources/TaskovskyCore/RichText.swift
[src-render]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Sources/TaskovskyCore/RichTextRender.swift
[src-schedule]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Sources/TaskovskyCore/ScheduleDraft.swift
[src-settings]: https://github.com/Mental-NV/Taskovsky/blob/f85e2f6a9c538f36829961961a0749197f29c4e2/Sources/TaskovskyCore/Settings.swift


The separately tested [phone reminder ownership record](../changes/iphone-reminder-identity-2026-11-12.md) now provides a non-UI persistence boundary in Workspace. It is not wired to the phone app: no Enable action, OS notification center or delivery is added by this boundary. Missing records stay off; explicit intent can persist a stable workspace UUID without depending on the sandbox path.

A [fake-only phone coordinator](../changes/iphone-reminder-coordinator-2026-11-12.md) now composes that identity boundary with saved snapshots and the shared planner. All center effects are injected; no concrete OS implementation or phone UI/lifecycle wiring exists. Explicit intent, no-prompt restore, queued ordering, scoped cleanup and partial failure behavior are exercised with test fakes only.
