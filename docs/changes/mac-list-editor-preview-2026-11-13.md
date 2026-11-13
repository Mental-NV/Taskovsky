# LIST-VIS-001 — Mac List editor live preview

Status: **Published as draft PR #73 after explicit user approval. Automated and bounded native AX checks passed; actual visual fit/fallback and failed-save interaction remain unverified.**

The user requested macro-area parity planning and implementation on November 13. This is the first P-ORG slice in [UI-MAP-001](ui-macro-parity-plan-2026-11-13.md), after finishing in-flight feedback fixes. The paragraphs below retain the original candidate history. Light theme is the active gate; historical Dark probe results are supplemental, not a requirement.

## Evidence and outcome

Source baseline: `77b646c` (main, inspected November 13, 2026). The original checkout was clean and left untouched. `EntitySheet` in `Sources/Taskovsky/TaskDetail.swift` renders a single 360-point content column, with 28-point outer padding, editable local state and a segmented List/Board/Timeline selector. It has no preview pane. Its save callback already acknowledges success; Cancel dismisses without saving.

Recorded live reference evidence: [Lists, folders and tags](../ticktick-spec/lists-and-tags.md), November 2, 2026. TickTick's Add/Edit List dialog has a form on the left and a tinted preview pane on the right. Selecting List versus Board changes the preview immediately without dismissing the form. Cancel discards the pending choice. The recorded 1640 × 932 dimensions are screenshot pixels, **not established points**. No exact panel size, typography, animation, Timeline preview or custom-color semantics were measured.

User outcome: see which existing local List or Board presentation is being selected before saving a new or edited list. This is independent of the narrow Calendar card changes, PR65/66, description recovery and notification work.

Related contracts: [macOS UI](../spec/ui-ux.md), [business rules](../spec/business.md), [parity tracker](../parity-implementation-status.md). This proposal does not update their current-baseline claims before implementation.

## Scope and non-goals

- Mac New/Edit **List** only; Tag, Folder and iPhone editors remain unchanged.
- Add a side-by-side, non-interactive preview for the existing List and Board choices. Do not add a new view mode, field, color, task or action.
- Keep Timeline selection available. Its preview must be explicitly described as Taskovsky's existing Timeline, not a recovered TickTick design. An initial bounded implementation may show an honest explanatory placeholder for Timeline instead of inventing a reference layout.
- No persistence, schema, store command, Save/Cancel, navigation or validation changes. No use of real task titles or other personal data in sample content.
- No unrelated Calendar, storage or notification work. No denied capture retry or system settings changes. Preserve the stable QA launcher/signing contract.

## Presentation contract for a candidate

Retain all form controls, order, bindings, symbols, colors and existing name focus. Keep the form's existing 360-point overall width, including its 28-point padding. A trailing preview is an additional pane, not a narrowing of the existing form. Choose its bounded width using an owned layout probe before implementation acceptance; record it as a Taskovsky design value, **not a measured TickTick constant**. Keep buttons in the existing form so Return/Escape and tab order are unchanged.

Use existing semantic backgrounds and label colors for both appearances. A subtle separator distinguishes the preview, whose sample header reflects the current draft name (fallback `List preview`), selected icon and list color. List preview uses static sample task rows; Board uses static sample columns/cards. Use existing supported row/card typography and color tokens rather than introducing a new design system. Do not instantiate an observed TaskStore or reuse interactive rows requiring real data; a small pure presentation component is sufficient.

Preview selection follows the local draft `viewMode` synchronously. Do not add animation or transition timing absent reference evidence. Name/color/icon draft changes may update the sample header, but preview updates must never write to disk. Mark the sample content as illustrative; expose one concise accessibility summary instead of adding fake tasks to keyboard traversal. Decorative glyphs are not buttons.

If the available sheet/window cannot contain both panes without clipping existing controls, use a tested constrained arrangement or omit the preview at that size. Do not guess a platform minimum width or change app-wide window limits. Record the chosen fallback and actual fit evidence before completion.

## Implementation boundary

1. Extract the existing EntitySheet form without changing modifiers, binding semantics or its submit function.
2. Add a dedicated pure `ListEditorPreview` view receiving draft name, symbol, color and view mode.
3. Wrap the form plus preview for list editors only; leave the tag editor on its existing path.
4. Keep the original Save callback result handling, failed-save message and draft retention exactly intact. No fixes to unrelated persistence code.
5. Update current UI specification and verification ledger only after implementation exists, distinguishing test renders from interactive native evidence.

## Acceptance and verification

- Source review: no store/write/notification calls in preview; no new model fields; unchanged submit/Cancel logic and tag form behavior.
- Owned pure preview fixtures: empty and long names, custom icon, selected colors, List/Board/Timeline, light/dark, compact proposed container and regular container. No glyph/control overflow or unreadable inherited colors. Offscreen rendering is not a substitute for native focus/interaction QA.
- Editing view mode changes only draft and preview. Cancel, Escape or window dismissal leaves saved list and view unchanged. Save retains the existing acknowledged callback behavior.
- Return in name, default Save, Escape Cancel and repeated mode changes preserve form focus. Fake preview rows never receive keyboard focus or activate commands.
- Failed Save retains the form and preview draft, using the existing error behavior; no persistence redesign.
- Existing tag parent selector and cycle exclusion remain unchanged.
- Run `swift test --disable-sandbox`, `./scripts/build-app.sh`, and independent diff review against the final source head. Keep hosted CI unchanged.
- Native interaction checks remain a separate gate. **Screen capture was denied in the unrelated Calendar QA session; do not retry or bypass that denial for this proposal.** No native checks were performed for this plan.

## Work completed for this checkpoint

Read-only inspection confirmed the reference evidence and source gap. Searched current UI spec and list-related change records; no implemented live-preview contract was found. Created this plan in an isolated checkout. No application source, user data, original worktree, QA app, system settings or remote repository changed. No tests/builds were run because this checkpoint changes documentation only.

## Local candidate (not ready to merge)

A presentation-only candidate now exists on this isolated branch. The existing form and submit implementation are retained; list sheets try a 360-point form plus a 280-point preview, with the unchanged form as the horizontal `ViewThatFits` fallback. The preview uses intrinsic vertical size, not an infinite height request. These are Taskovsky candidate dimensions, not measured TickTick dimensions. Actual sheet proposal/fallback and native focus still require permitted native verification.

List and Board samples respond to draft name/icon/color/type/view. Board headings derive from `BoardProjection.Column`; notes appear only in Open, and task terminal states use matching glyphs. Timeline displays an explicit preview-unavailable explanation. Samples are decorative and combined into one accessibility summary. They do not save or instantiate a store. The preview has no animation, focus or gestures.

Independent review found and corrected initially misleading Board sample labels and note placement. Review also verified the original form and submit were unchanged except moving the existing tint and onAppear focus modifier to the wrapper. Native focus and dismissal remain unverified. Tests, release build and final owned rendering results will be recorded separately when available; do not infer completion from this candidate.

### Candidate verification — source `5e7fd47`

- Final `swift test --disable-sandbox`: **766 XCTest** (134 Domain, 104 Workspace, 528 Core) plus **38 Swift Testing** passed with no failures on the Mac. This is the existing regression suite, not native preview interaction coverage.
- Owned standalone offscreen probe rendered the exact preview view source in 24 combinations: List/Board/Timeline × Task/Note × light/dark × empty/long draft name, each in a 280 × 480 container. All produced correctly sized images. The probe supplies small matching type declarations and the existing symbol view, not a complete EntitySheet or application. Inspected light/dark Board samples; shortened only illustrative card labels after initial samples unnecessarily truncated them. No screen capture or live application was involved.
- Independent source review confirmed unchanged form and submit implementation and no preview persistence/gesture/notification actions. Initial Board label/note-placement findings were fixed; no further concrete source defect reported. Native sheet sizing, fallback focus, keyboard, Save/Cancel and interaction remain unverified.
- Final `./scripts/build-app.sh` passed; `codesign --verify --deep --strict build/Taskovsky.app` passed. The app was not launched. No native interaction/CI or merge success is claimed. Original checkout remains clean and unchanged. No branch or PR was published.

## Current integration — November 13

Reused the preserved candidate without overwriting it; integrated onto `3c2db92` plus the merged UI macro map. Source review found no blocking defect and confirmed unchanged form/submit/Tag behavior. Two new hosted Mac tests render List/Board/Timeline task/note, short/long-name variants, bound the preview pane, retain the original Tag width and ensure rendering never invokes Save. These tests do not certify real sheet proposal/fallback or interactive focus.

The full Mac suite passed **771 XCTest plus 38 Swift Testing**. Release build and native AX-only sheet acceptance are pending at this checkpoint. Historical 24 owned renders above remain bounded supplemental evidence; no new production screenshot or exact pixel parity is claimed.

### Current native acceptance receipt — source `517816b`

Release build and strict signature verification passed. Scoped native light-theme **accessibility-only** QA verified normal and compact window openings, initial List name focus, List/Board/Timeline selection updating the preview accessibility label, and no preview-row focus in sampled Tab traversal. Empty Return kept the draft open; named Return created a disposable Board list. Reopening retained Board; Escape discarded an unsaved draft, Cancel discarded a pending Timeline change, and later Save retained Timeline across reopening. Tag controls remained and saved tags matched the original fixture. Original QA bundle, fixture and preferences were restored byte-for-byte; Codex stopped.

Exact sheet dimensions, visual fit/fallback, failed-save interaction and production screenshot remain unverified. No capture retry or permission/settings change occurred. Prior regression tests cover save failure at the store boundary, not this native sheet case. Publication was blocked pending explicit user approval for this branch; no remote branch or PR exists at this checkpoint.

### Publication and integration update

After explicit user approval, published [PR #73](https://github.com/Mental-NV/Taskovsky/pull/73). Integrated main `442b87b`; conflicts were documentation-only and both List preview and Mac/iPhone feedback receipts were preserved. Source is unchanged from the native-tested candidate. Exact-head hosted checks and integration review are pending. Earlier unpublished/pending statements above describe historical checkpoints, not the current publication state.
