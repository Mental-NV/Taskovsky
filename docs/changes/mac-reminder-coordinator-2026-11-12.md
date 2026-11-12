# Mac local reminder coordinator: inert adapter boundary

Status: implemented inert boundary; fake-center tests, full local suite, Mac packaging and iPhone Simulator compile passed. Hosted exact-head CI remains a merge gate. This slice does not deliver notifications.

## Scope

Following the pure planner, add a Mac coordinator with injected center and durable snapshot reader. Do not connect it to app startup, settings, user interface, UNUserNotificationCenter, or iPhone. There is no permission prompt, OS registration, app-setting mutation or real user notification during this work. Actual adapter/UI integration requires a separate reviewed slice and explicit runtime authorization for a device test.

## Durable input

Read the selected workspace/settings files through a read-only repository operation. Reject missing/unreadable files, unrecognized data, duplicate keys, and a pending transaction journal; never recover a journal or write files just to plan notifications. Use the existing repository's full canonical compatibility check. Do not substitute TaskStore.data, default settings, nil document, or an empty workspace on failure. A successfully read compatible empty workspace is different from a read failure.

## Ownership and opt-in

One coordinator has an immutable workspace identity derived from length-delimited canonical workspace and settings URLs plus an explicit app/QA scope using SHA-256; separate workspaces and the QA bundle must never share a cancellation namespace. Real integration must ensure one coordinator per selected workspace and disable/retire the old coordinator before switching. This slice never switches workspaces internally. It starts disabled in memory. Only an explicit enable command may request alert/sound authorization; refresh never prompts. Denied authorization does not enable scheduling. Disable removes only that workspace's owned pending requests; unrelated namespaces are preserved. No remove-all API.

The first real integration must persist opt-in successfully before enabling and restore it on restart without asking authorization again. This inert boundary intentionally does not pretend to implement preferences persistence or UI.

## Reconciliation

Serialize complete operations, including awaited center calls, so refresh/enable/disable cannot interleave stale writes. Fetch current authorization and a validated persisted snapshot before any enabled reconciliation mutation. Invalid clock/load/pending-fetch failures keep pending requests unchanged and surface failure. Authorization denied suppresses new registrations and reports denied; it does not silently prompt. Disable is allowed independently of snapshot health.

Adapt planner IDs into the immutable workspace namespace. Store original task ID and exact fire-date bits in request metadata; decoding uses that metadata, not rounded trigger dates. Preserve foreign/malformed namespaces. Retained exact requests remain unchanged. Remove obsolete owned requests, then add missing/changed requests in deterministic order. A failure reports its stage, confirmed successful add calls and submitted removal count (not delivery/cancellation receipts); a throwing call may itself have partial external effects and is not counted as confirmed. A failed add is reported with partial progress; a later refresh retries against actual pending state. The protocol must not imply an atomic OS transaction or a delivery receipt.

The 32-request budget remains an app policy, generic notification title/body remains the privacy default, and only saved actual task occurrences are planned. No background replenishment guarantee, notification action buttons, Focus bypass, critical alert/time-sensitive entitlement, network service or external integration.

## Verification

Unknown/malformed pending metadata is preserved; a collision with a desired identifier fails before mutation rather than overwriting it. Disable switches in-memory off before cleanup, even if fetching/removing pending requests fails; it can be retried. The operation queue finishes authorized enqueued cleanup even when its waiting caller is cancelled. No read-only loader recovers a transaction; it rejects journals both before and after reading.

Use an in-memory fake center only. Cover default-off/no prompt, explicit authorization grant/deny/error, refresh without permission prompt, strict persisted-read failures and unknown data, stale optimistic TaskStore state exclusion, exact metadata roundtrip, workspace isolation/foreign IDs, serialized overlapping operations, failed add/retry, disable and valid-empty versus unavailable input. Build Mac and shared/mobile targets to preserve separation. Real OS authorization, signed-app identity, alert delivery, System Settings and physical-device behavior remain NOT RUN.
