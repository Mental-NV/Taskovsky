# Scope compact sidebar Escape to its Mac window

On the `890f5bb` Mac product with checked synthetic fixtures at 382×584, opening Settings with the Tasks sidebar overlay visible and pressing Escape closed the sidebar behind Settings. Closing Settings without that Escape preserved it. In the main window, Escape and outside click correctly dismissed the sidebar.

Only the compact overlay’s owning key window handles its unblocked Escape. Events in another window or during an attached sheet or modal session pass through. The invisible event bridge is mounted only with the overlay; layout, focus policy, row navigation and selection are unchanged.

Verify the same Settings versus main-window Escape paths, preferably a known dismissible sheet too, and check selection and no task writes. Dated TickTick evidence does not establish this behavior.
