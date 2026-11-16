# T10 Smart-list visibility popup — 2026-11-16

Status: implemented and independently reviewed at source `5dff850`; exact-head CI pending.

Base: `bca277c` (merged PR157). PR158 drawer changes are unmerged and untouched
by this branch: no drawer source, CI or merge actions here. No Mac changes, no
persistence-logic rewrite. Standalone legacy Smart List settings
(`PhoneSmartListSettings`) are intact; the new control lives in
`PhoneUnifiedManagement` and its shared popup only.

Related: [inventory](../ticktick-spec/mobile-surface-inventory-2026-11-14.md)
(T10), [BUS-018](../spec/business.md#bus-018),
[IOS-009](../spec/iphone.md#ios-009),
[TT-019](../parity-implementation-status.md#tt-019),
[TT-020](../parity-implementation-status.md#tt-020),
[unified management receipt](mobile-unified-management-2026-11-16.md) (T09/T11).

## Per-form element inventory (T10)

Reference: inventory T10 — from T09 management, tapping Today visibility opens
an anchored popup reading **Show ✓ → Show if not empty → Hidden** top to
bottom; a backdrop tap closed it without a new choice. The reference capture
remains in the Computer Use trace (no durable portable image); wording, order,
check and backdrop behavior below are the observed contract. Unobserved: exact
popup metrics, typography, animation, and selection write timing.

| Element | Reference (observed) | Taskovsky implementation and behavior |
|---|---|---|
| Entry row | Visibility row inside management sheet opens the popup | Same `smartListVisibility-<key>` row button in `PhoneUnifiedManagement` (Smart Lists tab rows, `Drawer sections` Filters row, Tags tab Tags row); tap opens the popup anchored to the row. Row keeps its identifier, label, current-value detail and 44pt target. Reorder mode still replaces rows with move controls. |
| Choices | Show, Show if not empty, Hidden in that order | Same wording via existing `SmartListVisibility.phoneLabel`, explicit fixed order `[.show, .showIfNotEmpty, .hidden]` (not `allCases`, whose enum order is show/hidden/showIfNotEmpty). One control shared by Smart Lists, Tags and Filters rows. No unsupported external sources added. |
| Current check | Checkmark on the current choice (Show ✓ in the sampled state) | Checkmark on the live staged value; row detail text also shows the staged value. `.isSelected` trait on the checked option. |
| Position/size | Anchored compact popup near the row | Native SwiftUI popover anchored to the tapped row (`arrowEdge` automatic), `minWidth 250`, 48pt rows, `.presentationCompactAdaptation(.popover)` so compact width keeps the anchored popup (same policy as the D05 priority popup). No calibrated pixel claim. |
| Backdrop dismiss | Backdrop tap closed the popup with no new choice | Native outside-tap dismissal runs no staging closure: same management tab, staged draft byte-identical, no write, no navigation. |
| Selection | Tap stages the choice (write timing unobserved in reference) | Tap stages into the existing `UnifiedManagementSession` draft only and dismisses the popup. Outer Cancel discards, outer Done saves via the unchanged CAS path; staged choice survives tab switches before save, and persists across app relaunch after Done. Tapping the already-selected row dismisses with no mutation. |
| Guards | Nested Add/Edit Tag and Add Filter behind dirty gate; reorder within group | Unchanged: dirty gate, within-group reorder, stale/error banners and row identifiers all preserved. The popup stages through the same `session.stage` closure, so dirty detection is identical. |
| Excluded | Assigned to Me / Subscribed Calendars rows exist in reference | Absent as before, not faked. |

## Data contract

No new persisted state. The popup reads `session.staged.smartListVisibility[key]`
and writes through `session.stage`, so baseline pinning, dirty detection, tab
preservation, child gating, stale CAS failure and clean-baseline adoption are
unchanged production paths. Legacy `PhoneSmartListSettings` keeps its
navigationLink pickers untouched.

## Native coverage (`Mobile/UITests/UnifiedManagementTests.swift`)

Neutral fixtures only (`--qa-session` disposable IDs). Existing
`stageTomorrowVisible` helper updated to the popup flow (tap row → tap option →
popup dismisses; no pushed page, no back navigation) with assertions kept, not
weakened. New cases:

- `testVisibilityPopupOrderCheckAndBackdropDismiss`: opens the Today popup,
  asserts the three options exist in exact top-to-bottom order with the check
  on the current value, taps the backdrop (coordinate outside the popup),
  asserts the popup closed, the same Smart Lists tab is showing, and Cancel
  closes without a discard prompt (no mutation staged).
- `testVisibilityChoiceStagesCancelDiscardsDoneSaves`: stages a new choice,
  asserts the row detail updates, switches tabs and back (draft survives),
  Cancel → Discard Changes → row back to original; restages, Done, relaunches,
  and the saved value persists in management and in the drawer.
- `testVisibilityPopupRepeatedOpenAndSelectedRowDismiss`: opens and dismisses
  the same popup twice via the selected row (no mutation either time), then
  picks a different choice and confirms Done saves it.
- `testTagsAndFiltersVisibilityRowsUsePopup`: Tags tab Tags row and Drawer
  sections Filters row each open the same three-choice popup with a current
  check; a staged change on one survives a tab switch; Cancel discards.
- `testVisibilityPopupKeepsNestedGuardsAndReorder`: stages a popup choice,
  asserts the nested Add Tag dirty gate still appears (Keep Editing keeps the
  staged choice), and reorder mode still hides popup rows behind move controls.

Accessibility beyond identifiers/selected-state (VoiceOver focus, traversal,
Escape) is untested; no VoiceOver certification is claimed. Standard-size targets and popover adaptation are implemented; large-text fit remains unverified without a dedicated native run.

## Verification receipt

Source `5dff850`, isolated Mac checkout, owned iPhone13Pro Simulator iOS26.3.1:
- Package tests: 934 XCTest +38 Swift Testing passed, zero failures (`swift-test.log`).
- Release: `./scripts/build-app.sh` and strict `codesign --verify` passed (`build-app.log`).
- iPhone compile: `TEST BUILD SUCCEEDED`, no tests launched by compile gate (`ci-ios.log`).
- Native: 16/16 passed, zero failures, 414.693s; 14 unified-management cases including5 new popup cases, plus2 adjacent cases. `run.log` and `visibility-popup.xcresult`; explicitly targeted B263E8E7, nonparallel, diagnostics never.
- All logs/exports retained under `/private/tmp/TaskovskyVisibilityPopupNative/`. Two popup screenshots independently pixel-inspected; Today popup placed in tracker,1170×2532, neutral fixture only, SHA-256 manifest validated.
- Independent source/test review: no blocking findings. Final full checks completed directly after provider retries stalled the worker; no behavior changed after native run. Exact-head CI remains required.

Known open items unrelated to this change: fold timeline, Agenda precision and
Week filter failures remain open; PR158 pin-switch intermittent is retained
honestly if observed.
