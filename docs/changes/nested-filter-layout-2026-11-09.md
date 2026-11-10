# FILTER-LAYOUT-001 Nested filter editors

The user asked to improve Taskovsky's nested-filter layout after reviewing TickTick's documentation. The Mac and iPhone editors own their own layout, controls and draft state. This change reuses the existing filter model, matching and tree transformations. The rich-description editors keep their existing platform boundaries.

| Reference | Direct observation | Application |
| --- | --- | --- |
| [TickTick filter help](https://help.ticktick.com/articles/7055782240994721792) and its [iPhone illustration](https://pull.ticktick.app/hc/all/82be400076886dfaa1e563bb7f13f8ff.png) | The example shows a Normal/Advanced control, vertical criteria, a distinct AND row, Add, Examples and Preview. It shows a flat expression. | The iPhone editor uses a mode control near the name, separate operator headers and condition rows, and one Add control for each group. |
| [TickTick's 2020 article](https://blog.ticktick.com/2020/10/30/ticktick-premium-101/) and [Mac illustration](https://blog.ticktick.com/wp-content/uploads/2020/11/3-1024x613.png) | The historical desktop example shows a compact sheet, inline criteria and operator, and a contextual priority menu. | The Mac keeps compact native controls in a single row and gives each group an operator badge and a contextual menu. |
| [Installed Mac observation](../ticktick-spec/search-and-filters.md#add-filter-dialog) | The November 2 session saw a sequence of Filter and Logic placeholders and an add control. A November 9 read-only session confirmed the Filters section and restored the initial collapsed section and Calendar view. | Reference evidence supports compact criteria and visible operators. Taskovsky's nested group surfaces, guides and contextual actions are its own layout. |

The old iPhone form showed grouping, negation and removal actions next to each condition. The new form separates groups with AND, OR and NOT headers, shaded group backgrounds and short indent guides. A condition shows its type and current value with an ellipsis that opens the row’s action sheet. The keyboard's Done key dismisses it while keeping the draft. The match count, pin control, unavailable references, Normal-mode confirmation and failed-save draft behavior remain available.

The old Mac sheet repeated an If row and a removal button for every condition. The new sheet uses a compact type/value row, a short operator label, a group Add menu and one ellipsis for structural actions. The tag or list value remains visible as unavailable when its saved reference cannot resolve. Escape and Cancel discard the draft. Save retains the existing filter behavior.

See the [verification record](../spec/verification.md#nested-filter-layout) for native evidence, exact source identity and the guard used for disposable Mac files.
