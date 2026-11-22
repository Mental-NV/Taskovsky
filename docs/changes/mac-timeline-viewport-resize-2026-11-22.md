# Keep the Mac Timeline period and zoom on resize

Scope: local desktop Tasks Timeline, [MAC-09](../mac-parity-acceptance.md#acceptance-matrix).

On the current product source at `42f9613`, guarded Mac QA set Day, advanced the date range and zoomed to 125% at 1060×700. Resizing to 382×584 reverted to Week, the current period and 100%; compact-to-docked also reset a deliberately changed period and zoom. The eligible list still rendered scheduled rows and undated Arrange correctly. Reference behavior for resizing was not established.

Keep scale, focus period and zoom in the Mac workspace while the same Timeline scope remains active. Switching to a different scope or leaving Timeline returns to the existing defaults. The shared chart uses its existing local state when not supplied with a desktop binding. Do not persist these fields to workspace/settings, change date or task semantics, or claim exact pixel scroll anchoring, color mode retention, or iPhone runtime parity.

Verify exact native normal→minimum→normal, and mode exit/reentry and the deliberate scale change resetting zoom. Verify unchanged task bytes around resize and navigation, preserving normal capture, editing and gestures by leaving those paths unchanged.
