# Shared domain source layout

`ARCH-DOMAIN-LAYOUT` · Approved in the November 21, 2026 request · Builds on the [iPhone project layout](iphone-project-layout.md)

The existing `TaskovskyDomain` module gets its own [source directory](../../Sources/TaskovskyDomain). Move the 36 exact files from the manifest's domain list and let SwiftPM discover them under that directory. The remaining desktop files stay in [`Sources/TaskovskyCore/`](../../Sources/TaskovskyCore). Module and product names, dependency edges, and Core's Domain re-export carry forward.

Task and scheduling behavior, presentation, and workspace formats are outside the change. Application data needs no migration. Verify that each target owns the same source files and has the same dependencies, rerun Mac tests and release packaging, and compile and exercise the existing iPhone scheme. See the [verification ledger](../spec/verification.md#shared-domain-source-layout).
