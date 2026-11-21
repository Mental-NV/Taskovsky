# iPhone Tasks left-drawer shell

Status: **Implemented; local review/native verification passed, exact-head hosted CI pending.** Base `7a05e615`.

## Outcome and scope

The user requested implementation after the live mobile audit. [T07](../ticktick-spec/mobile-surface-inventory-2026-11-14.md#tasks-and-organization) confirms a leading indigo drawer with dimmed content to its right, backdrop dismissal, and a neutralizable identity/utility region. This is the first bounded structural slice of the [live parity plan](mobile-live-parity-plan-2026-11-14.md), not full drawer or pixel parity.

Replace the current large modal navigation sheet with an in-place leading panel. Retain all current destinations, ordering, counts, hierarchy, settings and management actions. Keep the neutral Taskovsky name; remove development-only explanatory copy from this navigation surface. Do not add fake account, subscription or external integration controls. Bottom Add/manage hierarchy, destination icons, row ordering and exact typography remain separate observed gaps.

## Presentation and behavior

- Leading panel uses the existing indigo token and white content; current selected-row treatment remains.
- Width starts at 87.3% of the viewport from the documented R08 calibration candidate, capped at 440 points for wider layouts. The cap is an adaptive implementation choice, not observed TickTick behavior. The live screenshot ratio was not calibrated.
- Underlying content remains visible through a 28% black backdrop, has disabled controls behind the full-screen backdrop while the drawer is open, and is not recreated on dismissal.
- Backdrop, existing Done control, a selected destination and accessibility escape dismiss. Child management sheets remain attached to the drawer and return to it.
- Leading transition lasts 0.22 seconds; Reduce Motion suppresses animation. Existing ScrollView handles content overflow and larger text. At accessibility text sizes the four utility actions consolidate into a named menu, preserving a visible Done action. Navigation counts stack below labels at those sizes to avoid crowding in the narrower panel.
- No file format, business commands, persistence, calendar behavior or Mac UI changes.

## Acceptance and evidence

Native gates: repeated open/backdrop/Done, destination change, nested manager return/reopen, underlying control isolation, normal and largest Dynamic Type, safe areas and narrow-panel toolbar fit. Capture owned neutral Simulator screenshots. Source review, native interaction, visual fit, exact-head hosted CI and full Swift/release checks are distinct evidence.

Local full tests/release/signature, three native tests and screenshot review passed; exact-head hosted CI remains pending. Independent source review found no blocking defect. The drawer declares modal accessibility semantics and supports accessibility escape. Actual VoiceOver traversal isolation, focus transfer/escape, reduced-motion device interaction and landscape remain unverified unless recorded below. No near-pixel-perfect claim or general parity percentage.

## Verification corrections

Initial native acceptance caught Done collapsing into toolbar overflow at the largest text size; the named utility menu fixes this without changing standard-size toolbar actions. A controlled native comparison also found that blanket root `accessibilityHidden(drawer)` left Add enabled but non-hittable after dismissal. Removing that modifier restored Add. The accepted design retains the drawer modal trait, underlying control disabling and full-screen backdrop; actual VoiceOver traversal/focus behavior is explicitly unverified, not claimed from source review.

## Final local acceptance

- `swift test --disable-sandbox`: 826 XCTest + 38 Swift Testing passed. Isolated release build and strict signature verification passed.
- Three owned iPhone 13 Pro Simulator UI tests passed on final source: repeated open/backdrop close, Done, Inbox destination, actual Add/open/Cancel after each dismissal; nested organization return/reopen; largest Dynamic Type utility menu/Tags/return, Done and navigation.
- Final normal and largest-text screenshots were inspected. Leading indigo panel and exposed dimmed backdrop fit the sampled viewport; Done remains visible, and accessibility title/count crowding is corrected. These are bounded fit checks, not calibrated TickTick pixel parity.
- Independent final source review found no blocking defect. Original checkout and user QA Simulator/data were not changed. The owned test simulator was shut down after testing; no Codex Computer Use was started by this implementation verification.
- Still unverified: real VoiceOver traversal/focus/escape, actual Reduce Motion device setting, landscape/smaller devices, physical-device behavior and complete observed drawer hierarchy. Exact dimensions, token/typography and bottom add/manage parity remain future work.
