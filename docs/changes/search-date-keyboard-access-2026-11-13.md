# SEARCH-DATE-002 — Explicit local keyboard access

Status: bounded follow-up implementation; scoped native keyboard acceptance passed, final CI pending.

PR76 fixes staged custom-date interaction but its SwiftUI focus root and native Tab traversal left checkbox/footer access unresolved. Matched baseline/candidate AX traces reached date segments but not ordinary buttons/toggles under unchanged macOS preferences. This is not proof of a regression or of complete accessibility.

Replace only the custom-date form presentation with native checkboxes, date fields and footer buttons. Explicit local circular key-view chain includes toggles and footer independent of the OS ordinary keyboard-navigation preference, excludes disabled date fields/Confirm, and retains native date-segment editing. Initial focus is set once, not on every state update. Return validates date editing then applies only nonempty bounds; Escape cancels. No OS/window-wide setting, permission or capture changes. Existing date model/matcher/state semantics unchanged. This is Taskovsky keyboard accessibility, not a new TickTick parity claim.

Require actual forward/reverse traversal, Space toggle/footer activation, native date editing and Return/Escape/reopen/outside dismissal. Tests of key-loop wiring do not establish native event behavior. Light-only; screenshots remain unavailable under existing capture restriction.

Verification: source `2649147` native key loop/activation/edit/apply/cancel passed. Owned exact-size native layout checks establish control containment/non-overlap only; actual screenshot/visual parity unavailable. See [verification receipt](../spec/verification.md#search-custom-date-keyboard-access-follow-up).
