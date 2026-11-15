# T15 Add Tag palette

Observed reference: Add Tag title, blank name, Color swatches, Parent Tag None and a disabled empty-name confirmation check. Exact reference color values were not observed.

| Element | Placement/wording | Behavior |
| --- | --- | --- |
| Add Tag | Creation title and manager action | Opens existing frozen-revision tag draft |
| Name | First row | Existing normalization/validation, blank disables confirmation |
| Color | Inline adaptive swatches | Existing Taskovsky desktop palette, real draft writes and current selection check |
| Custom Color | Below swatches | Existing system picker retained; arbitrary current colors never normalized on open |
| Parent Tag / Pin | Existing rows | Existing hierarchy, cycle validation and pin semantics |
| Check / Cancel | Existing toolbar | Existing save/discard/write failure handling |

Palette is local to this phone editor, not shared with Calendar source-color work. Edit Tag keeps Done and existing merge/delete behavior. No reference-color or near-pixel claim. Existing accessibility selection semantics and 44-point targets are retained.

Verification: integrated main a875e05 with both additive test groups preserved and independently reviewed. Full 864 XCTest + 38 Swift tests, release and iPhone compile passed. Native 3/3 passed with exit 0 and completed parsed xcresult (no failures/skips/warnings): every swatch, parent/color save/relaunch/cancel, nonpalette color retained through unrelated pin save, and existing nested-tag creation/assignment. Actual neutral screenshot inspected; exact-head hosted CI pending. No personal data used.
