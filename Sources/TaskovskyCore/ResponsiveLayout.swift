/// Geometry policy for the three-panel workspace.
///
/// The rail is fixed at 62pt. The navigation sidebar is user-resizable in
/// 160...320pt, hidden by the manual collapse toggle, and additionally
/// auto-hidden below the collapse threshold while the manual preference is
/// remembered. The center task pane needs at least 300pt and a docked detail
/// pane at least 280pt, plus a 1pt divider between them. When the window
/// cannot fit both, the center keeps its width and the detail becomes a
/// 300pt right overlay drawer instead.
///
/// Detail-first collapse is monotonic: the dock decision keys off the manual
/// collapse preference (or full search), never off the automatic sidebar
/// visibility. Auto-hiding the sidebar on further shrink must NOT re-dock
/// the detail — at custom sidebar 320, width 683 shows nav with overlay
/// detail, width 682 hides nav and must keep the overlay, and only an
/// explicit manual collapse (or search) frees room for a docked detail.
///
/// Threshold example with the default 215pt sidebar:
/// 62 + 215 + 1 + 300 + 1 + 280 = 859pt total to dock. Wider user sidebars
/// raise the requirement (up to 964pt); narrower ones lower it (804pt).
/// Parent measurements bracket the reference transition between 757pt
/// (overlay) and 961pt (docked), consistent with this derived rule, but the
/// exact TickTick threshold remains an approximation.
public enum ResponsiveLayout {
    public static let railWidth: Double = 62
    public static let sidebarMin: Double = 160
    public static let sidebarMax: Double = 320
    public static let sidebarDefault: Double = 215
    public static let listMin: Double = 300
    public static let detailMin: Double = 280
    public static let drawerWidth: Double = 300
    public static let dividerWidth: Double = 1
    /// Measured compact reference: 382x580 smallest in both dimensions (parent
    /// manually resized TickTick; rail 62 at apparently 1px/pt, nav/detail
    /// hidden, detail drawer right-aligned at x=382-300=82). Both minima are
    /// measured reference values.
    public static let compactCenterWidth: Double = 320
    public static let minWindowWidth: Double = 382
    public static let minWindowHeight: Double = 580
    /// Navigation popover revealed by the toggle at compact widths: ~220pt
    /// wide, anchored under the header toggle (measured about x77 y56),
    /// with native rounded corners and shadow. Not a full-height drawer.
    public static let sidebarPopoverWidth: Double = 220

    /// Width the navigation sidebar occupies, or zero when manually collapsed.
    public static func navWidth(sidebarWidth: Double, collapsed: Bool) -> Double {
        guard !collapsed else { return 0 }
        return min(sidebarMax, max(sidebarMin, sidebarWidth))
    }

    /// Width left for the center/detail area after rail and sidebar.
    public static func availableWidth(totalWidth: Double, sidebarWidth: Double, collapsed: Bool) -> Double {
        let nav = navWidth(sidebarWidth: sidebarWidth, collapsed: collapsed)
        return totalWidth - railWidth - nav - (nav > 0 ? dividerWidth : 0)
    }

    /// Whether the detail pane can dock beside the center pane.
    public static func shouldDockDetail(totalWidth: Double, sidebarWidth: Double, collapsed: Bool) -> Bool {
        availableWidth(totalWidth: totalWidth, sidebarWidth: sidebarWidth, collapsed: collapsed)
            >= listMin + dividerWidth + detailMin
    }

    /// Sanity: the measured minimum exactly fits rail plus compact center.
    public static func validatesMeasuredMinimum() -> Bool {
        minWindowWidth == railWidth + compactCenterWidth
    }

    /// Content height available inside a total window height given the native
    /// chrome height (frame minus content rect). The hidden-titlebar chrome
    /// adds ~28pt, so a 580pt content floor landed a 608pt frame; the window
    /// floor bridge subtracts measured chrome so the 580pt minimum stays the
    /// TOTAL reference, never a mislabeled content value.
    public static func contentMinHeight(totalHeight: Double, chromeHeight: Double) -> Double {
        max(0, totalHeight - chromeHeight)
    }

    /// Center width when docked; clamped so neither pane goes negative.
    public static func dockedListWidth(available: Double, fraction: Double) -> Double {
        guard available > dividerWidth + detailMin else { return max(0, available) }
        let upper = available - dividerWidth - detailMin
        return min(upper, max(listMin, available * fraction))
    }

    /// Total width below which the sidebar can no longer stay docked next to
    /// a minimum center pane: rail + sidebar + divider + center minimum.
    /// With the default 215pt sidebar this is 578pt (narrower sidebars lower
    /// it to ~523pt, wider ones raise it to ~683pt). These are derived from
    /// the measured 382pt minimum (62 rail + 320 center) plus the sidebar,
    /// not from a measured TickTick threshold, and stay documented as such.
    public static func sidebarCollapseThreshold(sidebarWidth: Double) -> Double {
        railWidth + navWidth(sidebarWidth: sidebarWidth, collapsed: false) + dividerWidth + listMin
    }

    /// Whether a docked sidebar still fits. Below this the sidebar hides
    /// automatically; the manual collapse preference is remembered separately
    /// and restored when the window grows back.
    public static func shouldAutoCollapseSidebar(totalWidth: Double, sidebarWidth: Double) -> Bool {
        totalWidth < sidebarCollapseThreshold(sidebarWidth: sidebarWidth)
    }

    /// Effective docked-sidebar visibility. Detail hides (overlays) before the
    /// sidebar: the dock-detail threshold (~860pt default) sits well above the
    /// sidebar-collapse threshold (~578pt default), and expanding restores in
    /// reverse. Full search always hides the docked sidebar, as before.
    public static func isSidebarDocked(totalWidth: Double, sidebarWidth: Double, manualCollapsed: Bool, searchActive: Bool) -> Bool {
        if searchActive || manualCollapsed { return false }
        return !shouldAutoCollapseSidebar(totalWidth: totalWidth, sidebarWidth: sidebarWidth)
    }
}

/// Stable panel-drag math, kept pure so the gesture layer stays a thin shell.
///
/// Dividers report absolute positions in the stable window/global coordinate
/// space; the view captures the start position and start size on the first
/// event and derives the delta from those, so local translation accumulation
/// can never feed jitter back into the layout.
public enum PanelDrag {
    /// Dragging the sidebar below this width collapses it on release instead
    /// of clamping. Checked only on end so the boundary never flaps mid-drag.
    public static let collapseBelow: Double = 135

    public static func clampedSidebarWidth(start: Double, delta: Double, maxWidth: Double? = nil) -> Double {
        let upper = min(ResponsiveLayout.sidebarMax, maxWidth ?? ResponsiveLayout.sidebarMax)
        return min(upper, max(ResponsiveLayout.sidebarMin, start + delta))
    }

    /// Widest the sidebar may grow while the detail stays docked: widening
    /// past this would squeeze the center below its minimum or steal the
    /// detail's minimum. The divider clamps live widths to this while docked
    /// so a drag can never violate the detail minimum mid-gesture.
    public static func dockedSidebarMax(totalWidth: Double) -> Double {
        totalWidth - ResponsiveLayout.railWidth - ResponsiveLayout.dividerWidth
            - ResponsiveLayout.listMin - ResponsiveLayout.dividerWidth - ResponsiveLayout.detailMin
    }

    public static func shouldCollapseSidebar(start: Double, delta: Double) -> Bool {
        start + delta < collapseBelow
    }

    /// Center-pane fraction for a pane-divider drag, clamped so the center
    /// never drops below its minimum and the detail keeps its minimum.
    public static func paneFraction(startListWidth: Double, delta: Double, available: Double) -> Double {
        guard available > 0 else { return 0 }
        let limit = max(ResponsiveLayout.listMin, available - ResponsiveLayout.dividerWidth - ResponsiveLayout.detailMin)
        return min(limit, max(ResponsiveLayout.listMin, startListWidth + delta)) / available
    }
}
