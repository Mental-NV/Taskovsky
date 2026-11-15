# Mobile Calendar View Options navigation

Status: implemented candidate, local/native/review gates passed; exact-head hosted CI pending.

The observed mobile inventory C06–C11 places Color and Style on pushed pages, with Show Item Icons nested under Style. Taskovsky previously showed all of its appearance controls inline on the main options form. This presentation-only slice groups the existing Color by/source customization controls under Color, and the existing item/year styles and icon controls under Style → Show Item Icons.

All controls continue to edit the same parent draft. Navigation Back retains the draft, outer Cancel discards it, and outer Done uses the existing revision-checked save. Existing global and task/note icon switches remain functional. No persistence, domain, fixture, or Calendar rendering change is intended. Taskovsky Filled/Outline and Year style labels are retained: equivalence to reference Modern/Classic and Heatmap has not been established. Unsupported Calendar/Focus icon switches and external integrations are not invented.

Acceptance: source color save/relaunch/reset-Cancel; icon independence/global disabling/Cancel/relaunch; style and visibility save/relaunch. Full tests, release/signature, independent review, actual Simulator navigation and screenshots, and exact-head hosted CI are required before merge. This closes only the navigation hierarchy gap, not complete visual or style parity.

Verification: full 827 XCTest + 38 Swift Testing, release and signature passed. Initial three native tests passed for source colors, icons and style/visibility persistence. Independent review caught one old checklist test route; it was corrected. Final two native tests passed for checklist hidden-icon behavior and icon independence, with actual Style and Show Item Icons screenshots inspected. Only whitespace normalization followed production compilation. The owned Simulator shut down; user fixtures were untouched. Root title truncation remains a pre-existing typography gap, not a near-pixel-perfect claim. Hosted exact-head CI is still required before merge.
