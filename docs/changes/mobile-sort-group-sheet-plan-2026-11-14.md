# iPhone Sort & Group sheet parity plan

## Identity and decision
- Change ID: **MOB-SORT-GROUP-002**.
- Status: **Planned; implementation not started by this documentation change**.
- Owner request: November 14, 2026, “make sure Sort & Group menu … look like this (plan this work item).” Planning and screenshot-backed visual target are requested; unobserved semantics below remain decisions to resolve before implementation.
- Source baseline: `2b255ece8c31f6913530c97a1abaf6e9db6ac3e8` (PR94); iPhone light theme only. Mac behavior and schema are unchanged by this plan.
- Related: [iPhone specification](../spec/iphone.md), [menu-first controls](mobile-tasks-view-menu-2026-11-14.md), [macro-area map](ui-macro-parity-plan-2026-11-13.md), [timestamp sorting](task-timestamp-sorting-2026-11-09.md).

## Evidence: observed pixels, not inferred actions
The owner supplied a 591 × 1280 JPEG of TickTick on Today, inspected directly on November 14. Reference identifier: owner's Sort & Group attachment from that date. Do not commit the screenshot or its personal task text to the repository.

Observed:
- A white bottom sheet with rounded upper corners over a dimmed Today list. Its top is about 59% of this image height; this is an image proportion, **not** a device-point detent or exact radius specification.
- No visible navigation title, Save, Cancel, Done or drag indicator in this state.
- Muted, left-aligned **Group by** heading; six pill controls in two rows of three: **List / Date / Created Time**, then **Tag / Priority / None**.
- **Priority** is selected with blue fill and white text; other pills have a very pale gray fill and gray text.
- A second **Sort by** heading, with **Ascending ↑** aligned at its right; six pills: **Date / Created Time / Modified Time**, then **Title / Tag / Priority**.
- **Tag** is selected independently of the Priority grouping.
- Centered bottom action label **Restore default tag order**, preceded by a curved undo-style icon, is visually subdued. Its disabled/enabled state cannot be concluded from color alone.

This establishes independent grouping and sorting axes in the shown **List** state. It does not prove that Tag is a secondary grouping axis, that every option exists in Kanban, or any tap/dismiss/persistence/reset behavior.

## Current source and gap
[`TaskovskyMobileApp.swift`](../../Mobile/App/TaskovskyMobileApp.swift), `taskActions`, currently exposes nested native menus called Group & Sort. Scoped Board offers Date/List; List combines `PhoneTaskSort` and creation/due-date grouping in menu entries. [`PhoneWorkspaceModel.swift`](../../Mobile/App/PhoneWorkspaceModel.swift), `PhoneTaskSort`, supports Priority and Created/Modified timestamp directions, persisted in local preferences. Board grouping/view are session-local in the destination view. [`BoardProjection.swift`](../../Sources/TaskovskyCore/BoardProjection.swift), `ScopedBoardGrouping`, is shared with Mac and has Date/List.

Therefore the gap is not a label-only rename: the reference has a dedicated sheet, independent axes, direction presentation and additional criteria. A concurrent mobile-only Priority Board slice may supply backing functionality; it is not completion of this sheet or permission to change shared Mac grouping.

## Proposed implementation breakdown
1. **Reconcile presentation state and capability mapping.** Introduce a mobile-specific group/sort/direction presentation contract, mapping existing behavior without task mutations. Record which destinations and view modes support each choice. Separate selected criterion from direction instead of duplicating timestamp direction labels in the grid. Preserve old preference interpretation; choose and document migration/fallback before adding a new preference key. Unknown stored values must not destroy existing preferences or task payloads.
2. **Build reusable sheet and wire supported choices.** Use a dedicated iPhone sheet component rather than nested Menu controls. At standard text size, reproduce the two 3-column pill grids and the visual ordering above. Keep grouping and sorting independently selected. Selecting one must not silently reset the other. Preserve current supported sorting/grouping behavior through an adapter. A partial implementation must identify unsupported choices honestly; do not ship enabled no-op pills or mark full parity achieved.
3. **Fill missing projection/sort criteria in separate bounded slices.** Reuse the concurrent Priority work once reviewed. Add List/Date/Created Time/Tag/None grouping and Date/Title/Tag sorting only with documented semantics and tests. Preserve scoped matching, note behavior, pinned/finished sections and current task identity rules. Do not infer multi-tag duplication or ownership from this image. No new drag-to-priority/tag writes merely because a display grouping is added.
4. **Direction and restore action.** Implement direction as its own accessible control after criterion eligibility is specified. Implement context-sensitive restore only after defining the exact affected preference/order and default. A reset must not rewrite task tags, organization order, unrelated criteria or another destination's preferences accidentally.
5. **Native acceptance and delivery.** Verify owned fixtures at normal/compact widths, standard and accessibility text sizes, VoiceOver and repeated navigation. Capture an actual Simulator sheet screenshot and compare against the supplied visual reference. Report remaining deviations, not global parity; use the existing Codex screenshot-display fallback if Library delivery is unavailable.

## UI contract to specify in the implementation
- Use existing mobile semantic typography, light background, muted secondary text and tint tokens; measure the reference against known simulator point dimensions before choosing exact spacing/radius/color values. The JPEG alone does not establish font size or point scale.
- Equal-width pills in the standard 3-column layout, generous separation between Group by and Sort by, direction aligned to the Sort by heading, footer above bottom safe area. Preserve minimum 44-point hit targets and full accessible labels even if a visual pill is shorter.
- At accessibility text sizes, allow a scrollable/adaptive layout rather than clipping long labels. Keep logical row-major traversal: grouping, sorting/direction, restore. Selection must be announced, not conveyed only by color.
- Restore focus to the originating overflow control after dismissal. Avoid a popover and sheet simultaneously competing for focus. Use native/reduced-motion-aware presentation; exact animation timing remains unmeasured.
- Keep current Tasks action availability, source/destination filters, concrete-list management, recovery notices and read-only guarantees. This change must not alter Mac, Calendar, synchronization or local-file recovery policy.

## Decisions and observation still required
- Immediate apply versus staging; whether selection keeps sheet open; outside tap/swipe dismissal behavior; destination change while open; app background/relaunch behavior.
- Preference scope: per list, destination, mode, or global. Preserve current behavior until an intentional, tested change is specified; do not imply reference persistence from a screenshot.
- Date/Created Time bucket definitions, undated placement, time zone boundaries and priority order/direction eligibility.
- Tag sorting key, multi-tag ties, untagged placement, nested tag ordering, and what “Restore default tag order” resets. Check whether the footer changes for other criteria.
- Mode/destination eligibility for None, List and other options in Kanban/Timeline, and interaction with pinning, finished groups and named list sections.
- Whether Ascending is a toggle or opens another menu, availability of descending for each criterion, and displayed reset enablement.

## Acceptance matrix (planned, not passed)
| ID | Case | Required result |
| --- | --- | --- |
| SG-01 | Open sheet in the reference Today/List state | Two distinct grids, correct order, independent selected states, direction and contextual restore; no permanent segmented rows return. |
| SG-02 | Change grouping repeatedly, then sorting and direction | Correct supported projection/order; other axis preserved; no task edits or lost records. |
| SG-03 | Dismiss/reopen, switch destination/mode, background/relaunch | Follows documented state scope; no stale selection, duplicate sheet, unintended preference reset or focus loss. |
| SG-04 | Empty, notes, pinned/finished, undated, multi-tag, equal-key and legacy-state fixtures | Deterministic, explicitly specified results; no duplicate/lost tasks or inferred mutation semantics. |
| SG-05 | Restore then repeat/dismiss/reopen | Only intended order/preferences reset; actual default state shown; unrelated data unchanged. |
| SG-06 | Compact width, long localized labels, largest text, VoiceOver, hardware keyboard | No clipping/unreachable controls; selected states announced; touch targets and focus restoration remain usable. |
| SG-07 | Existing Date/List Board movement, status Board, List sorting and task actions | Existing writes/Undo/filter behavior unchanged by new sheet; unsupported modes are truthful. |

## Verification record
Planning only: actual reference image inspected; current symbols and enum choices read; Markdown-only diff/relative links to be checked before publication. No app code, test fixtures, workflows or dependencies changed. No runtime/visual acceptance or implemented menu is claimed. Implementation PRs must update the iPhone specification, parity ledger and verification ledger with exact source, CI/native evidence and screenshots. Dark parity remains deferred.
