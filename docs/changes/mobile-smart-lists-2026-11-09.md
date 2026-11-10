# MOB-SMART-LISTS-001 Smart List preferences on iPhone

The November 9 local Tasks scope includes [BUS-018](../spec/business.md#bus-018), [IOS-009](../spec/iphone.md#ios-009) and [TT-020](../parity-implementation-status.md#tt-020). The iPhone drawer uses saved Smart List visibility and order. Smart Lists opens from the drawer toolbar and stages Show, Hidden, or Show if not empty for supported destinations and the Tags and Filters sections.

The top task group and bottom history group retain their Desktop boundary. The reorder controls move rows within those groups. Hidden rows remain in the settings order and can be edited there. When the active destination disappears, the phone opens the first visible Smart List or Inbox if none remains. Default visibility follows the shared settings. Filters and tags remain searchable independently of drawer visibility.

The repository checks the saved revision and replaces only the changed Smart List members. Calendar settings, unrelated preference bytes, and the workspace file are preserved. Cancel can discard the form, and a failed write leaves the draft available. The Summary report and its controls remain a separate phone delivery slice. Existing Summary settings stay in the file. External integrations remain deferred. [Verification](../spec/verification.md#mobile-smart-lists).
