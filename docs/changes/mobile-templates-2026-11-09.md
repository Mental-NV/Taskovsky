# MOB-TEMPLATES-001 Local template editing and application

The [template contract](../spec/business.md#bus-010) covers creating, editing, deleting, capturing and applying a saved template. The iPhone drawer opens a native template manager. Task Actions can save the current record as a template or apply a saved template to the current record after confirmation. The Add sheet uses the same templates for new items.

The reduced editor owns the name, task title, plain description, checklist and priority. Styled descriptions remain protected on iPhone. Edits retain formatting and fields outside the editor. On Mac, intentionally replacing a styled description clears its former styles. Renaming a template preserves the repeat rule, duration and unchanged checklist items, including their identities and check state.

Applying a template updates its owned fields on the task, gives copied steps fresh identities and keeps linked tasks in place. The write uses the existing compatibility and revision checks. Existing capture semantics continue to re-anchor a template duration when Add supplies a new due date.

See the [verification record](../spec/verification.md#mobile-templates) for the native workflows and file evidence.
