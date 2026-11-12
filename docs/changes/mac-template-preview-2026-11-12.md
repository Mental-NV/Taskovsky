# Mac Settings template Preview and Apply

## Evidence and scope

The current Mac Settings card opens Edit immediately. A read-only TickTick 8.2.20 (922) check on November 12 confirmed a card opens Preview: fixed heading/footer, scrollable title/checklist content, Apply and editing guidance. Escape closed it. Apply was not executed in this check; an earlier documented reference observation created an Inbox task. MacDisassembler class discovery and the selected Preview controller's 16 declarations identify its title, scroll/content, Apply and editing-help controls; declarations do not prove runtime behavior.

Implement the existing Mac Tasks template workflow only. Do not change iPhone representation, template replacement semantics, template contents/defaults, schema or external integrations. Retain explicit Edit in the card options menu and New Template.

## Presentation and behavior

- Card activation opens a read-only 560×400-point sheet. This is Taskovsky's chosen geometry, not an exact reference measurement (the reference estimate was captured-window pixels).
- Fixed centered Preview heading, 14-point semibold; top-right Close control with accessible label and Escape. Divider separates header from a vertically scrolling region with 20-point horizontal padding.
- Inside the scroll region: template task title, 18-point bold, left aligned, wrapping; description in the existing disabled Mac rich renderer when valid styled data exists, otherwise selectable 13-point plain text. Checklist rows are read-only symbols plus wrapping 13-point text with 8-point spacing; checked state is represented, not editable. No truncation of content.
- Fixed bottom divider/footer, 14-point horizontal and 12-point vertical padding. Secondary 11-point editing guidance button opens local instructions describing the existing Edit menu, not unverified TickTick replacement behavior. Accent prominent Apply, Return shortcut. Semantic colors follow system appearance; no custom animation.
- Apply creates one new task through the existing template creation/default destination policy, then closes only after success. Repeated activation must not duplicate. A changed/deleted template is rejected rather than applying content different from the displayed snapshot. A write failure leaves Preview open with an accessible error and permits explicit retry. Cancel/Close/Escape and scrolling do not mutate workspace/settings/template data.

## Verification

Test expected-template guards (changed, deleted, unchanged), exact one-task persistence and existing write-failure behavior. Run full Mac tests/release build and independent review. Native isolated QA: open/scroll/close with unchanged bytes; rich/plain/checklist content; Apply and reopen; explicit Edit still available; keyboard dismissal and safe failure where feasible. Do not claim exact pixels, VoiceOver or untested iPhone parity. Exact-head CI before merge.

## Verified checkpoint

Full local tests, signed release build, independent review and scoped native preview/apply audit passed; [verification and limits](../spec/verification.md#mac-template-preview). Exact-head hosted CI is verified before merge.
