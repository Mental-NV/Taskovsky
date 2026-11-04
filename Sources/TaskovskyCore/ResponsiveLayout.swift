/// Geometry policy for the three-panel workspace.
///
/// The rail is fixed at 62pt. The navigation sidebar is user-resizable in
/// 160...320pt and only hidden by the manual collapse toggle. The center task
/// pane needs at least 300pt and a docked detail pane at least 280pt, plus a
/// 1pt divider between them. When the window cannot fit both, the center keeps
/// its width and the detail becomes a 300pt right overlay drawer instead.
///
/// Threshold example with the default 215pt sidebar:
/// 62 + 215 + 1 + 300 + 1 + 280 = 860pt total to dock. Wider user sidebars
/// raise the requirement (up to ~964pt); narrower ones lower it (~804pt).
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

    /// Center width when docked; clamped so neither pane goes negative.
    public static func dockedListWidth(available: Double, fraction: Double) -> Double {
        guard available > dividerWidth + detailMin else { return max(0, available) }
        let upper = available - dividerWidth - detailMin
        return min(upper, max(listMin, available * fraction))
    }
}
