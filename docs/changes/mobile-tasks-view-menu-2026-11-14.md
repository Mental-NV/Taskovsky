# Mobile Tasks menu-first layout

Status: Implemented, verification pending. Base: `ef25cb6`.

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
