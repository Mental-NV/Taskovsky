# Remove composer recovery success area

User requested removal of the full “Recovery copy saved” composer area, including its empty spacing. Ordinary capture now starts with the title section. A warning section exists only for actual save/recovery failure, stale draft or protected retry state. Background scratch saves, draft resume, Cancel/discard, IME handling and persistence remain unchanged. This is a requested presentation change, not new recovery work or a claim of full composer parity.

Acceptance: ordinary/expanded composer has no success status, draft resume still restores content and range, failed save remains visible/editable, direct save and relaunch still work.

Verification: independent source review clean; reviewer found a range-recovery test still referencing removed UI, corrected without dropping recovery assertions. Full 827 XCTest + 38 Swift Testing, signed release and signature verification passed. Native compact metadata/More/Cancel/save/relaunch and actual save-failure checks passed. Ordinary and Calendar range recovery initially failed an added pre-quit offscreen-title assertion; upward scroll correction (test-only) passed both final native regressions. Resume content, date range and save-once checks retained. Actual neutral Simulator screenshot inspected and attached to tracker. Exact-head hosted CI pending.
