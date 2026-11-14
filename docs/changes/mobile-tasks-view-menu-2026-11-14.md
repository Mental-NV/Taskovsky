# Mobile Tasks menu-first layout

Status: Implemented; bounded native acceptance passed, exact-head hosted CI pending. Base: `ef25cb6`.

## Evidence and scope
The owner's six supplied November 14 screenshots show Taskovsky's permanent List/Board and Date/List controls, and TickTick's overflow View submenu with List View/Kanban View and a separate Group & Sort entry. The first two images have empty Taskovsky data; the reference images have populated TickTick data. This does not establish a filtering or sync defect.

This bounded iPhone change relocates existing smart-destination view and board grouping controls into the Tasks overflow. Concrete-list modes and management remain unchanged. It does not implement priority/tag Kanban grouping, new task cards, extra bottom tabs, backgrounds or unobserved menu actions. Native system menus approximate the observed interaction, not exact TickTick styling.

## Contract
- View offers only the destination's supported List View, Kanban View and Timeline View, with the current native Picker selection.
- Group & Sort exposes existing list sorting/date grouping or existing board Date/List grouping. No task matching, scheduling, drag/drop or persistence rules change.
- View/group choices remain session-local. Board grouping is retained per destination during the session. Switching grouping still resets selected column and drag session through the existing board observer.
- QA workspace marker remains visible. The redundant normal-launch development caption is absent only on Tasks. Recovery/error notices and local-storage information in Settings remain.
- Original batch selection and multiple-task capture remain reachable. Read-only/archived controls retain their original rules.

## Acceptance
Verify Today and folder/tag/filter paths: open/close overflow, current checkmark, List → Kanban → List, Date/List grouping, destination roundtrip, Timeline where supported, batch actions, sorting, small-screen and Dynamic Type layout, VoiceOver, interruption and no unexpected workspace changes. Use isolated QA fixture only. Preserve existing concrete-list UI.

## Evidence
Generic iPhone Simulator build-for-testing passed after the final accessibility correction. Independent review found one concrete-list accessibility announcement defect; it was corrected and rereviewed. Existing native tests were migrated and a return-to-List case added, but not executed. `swift test --disable-sandbox` passed: 824 XCTest cases (134+55+107+528) and 38 Swift Testing tests. No installed app, interactive/native visual pass, screenshot, CI pass or complete List/Kanban parity is claimed. Dark theme is deferred per current scope.

### Native acceptance on November 14
Source `056e50a` (unchanged in subsequent test/docs commits), iPhone 13 Pro disposable Simulator, iOS 26.3.1: five scoped XCTest UI cases passed: Today View and Group & Sort menus; List/Kanban return; Date move and Undo; folder/tag list movement; Timeline section/list headings. Fresh QA UUID per case; existing user QA device/app/data untouched, owned test device shut down afterward.

Simulator app screenshots inspected: List View checkmark and both mode choices visible; Date/List checkmark visible; permanent segmented controls absent from Today Kanban. Screenshots use neutral QA fixtures and retained QA banner, not normal-user data. Native menu styling is an approximation; broader Kanban structure remains open. VoiceOver traversal, larger Dynamic Type, all locales, and physical-device behavior were not manually verified.

Xcode emitted a UIKit `_UIReparentingView` hierarchy warning while presenting nested menus; all five tests completed successfully without blocked touch/navigation. Keep this diagnostic visible for follow-up; no visual equivalence claim or assertion that the warning is harmless in every environment.
