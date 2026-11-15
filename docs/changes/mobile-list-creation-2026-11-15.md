# T12 mode-aware Add List

Reference inventory T12 observed Add List with name, color swatches, View Type previews List/Kanban/Timeline, More advanced settings, disabled confirmation for empty name, and cancellation. This bounded slice implements actual initial layout choice, not merely decorative previews.

| Element | Placement/wording | Behavior |
| --- | --- | --- |
| Header | Add List | Existing Cancel and Done retained; reference ×/checkmark presentation still differs |
| Name | First field | Existing IME-aware input, icon inference, empty-name guard and dirty cancellation |
| List Color | Before View Type | Existing native color chooser; reference swatch arrangement deferred |
| View Type | Three adjacent schematic previews: List, Kanban, Timeline | Local selection and checkmark; actual initial list mode saved atomically |
| More | Below previews | Existing type/icon/placement/smart inclusion/pin controls, collapsed for creation only; edit remains expanded |
| Save | Existing Done | Single expected-revision organization transaction, no second mode-setting write |

Domain `saveList` gains defaulted `initialViewMode` argument. Existing callers still create List mode; new caller explicitly passes selected mode. Creation still rejects invalid name/folder/duplicate ID and discards injected sections. Existing edits preserve stored mode and sections regardless of incoming initial mode. No task mutation, persistence schema or global destination mode changes.

Unknowns/deviations: exact preview dimensions, reference Timeline badge meaning, swatch palette, advanced wording and granular smart-inclusion semantics unverified. No copied badge, fake subscription gate or superficial option alias. Schematic previews represent existing Taskovsky modes, not screenshots or pixel certification.

Verification added but not run here: three portable domain tests for atomic mode selection/roundtrip/default/edit preservation/invalid input; native create-all-three/relaunch and selection-cancel coverage. Parent runs native/review/full/CI and existing D06 nested creation regressions after integration. Latest main `ccfd0a5` integrated; D06 editor success callback and Tags changes retained. Native nested creation regression remains a validation gate. No personal assets.
