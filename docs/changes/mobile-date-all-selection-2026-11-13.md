# MOB-DATE-ALL-001 — Effective date selection on iPhone

Status: in implementation under the user's autonomous Tasks/Calendar UI mandate. Base main `d476267`. iPhone Search and Normal saved-filter forms only; this is a source-proven selection bug, not a claim of measured TickTick iPhone layout parity.

## Evidence and contract

The shared `PhoneNormalFilterFields` used a generic multi-toggle for Dates. Choosing Any date then Today retained both rules. The matcher ORs date rules, so `.all` silently neutralized Today. Desktop already handles this with explicit reset semantics; the mobile Search and saved-filter specifications require the same predicates.

- Any date is an explicit reset to no date restrictions. Selecting a specific rule removes `.all` while preserving other specific rules and their order. Toggling a selected specific rule removes it.
- Empty selection shows Any and checks Any date. Legacy mixed `.all` state remains untouched until an explicit date action; its summary truthfully says Any. No load/save migration or global matcher change.
- Keep custom bounds, staged Done/Cancel, unrelated criteria, advanced filters, layout/44-point rows and existing accessibility selection traits. Share the desktop pure selection helper via Domain, with an array API for mobile; no desktop behavior change.
- No data schema, persistence/recovery, notification or appearance changes.

## Acceptance and evidence

Test Any→Today narrows matcher results; multiple specific rules retain OR behavior; reset restores unrestricted; custom bounds/other fields persist; legacy draft stays unchanged before action. Verify Search and saved-filter UI, Cancel versus Done/reopen, empty Any checkmark and repeat toggles. Run full Swift tests, Mac release, iPhone compile/test gates and independent review. Native touch/screenshot acceptance remains pending; do not call compile proof of UI behavior.

Source review found no blocker; its requested array-backed matcher and unrelated-criteria regressions were added. Full Swift regression execution passed; native Search/Normal form QA and hosted exact-head CI are still pending. No screenshot or actual visual-parity acceptance is claimed.
