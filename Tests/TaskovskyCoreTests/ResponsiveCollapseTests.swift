import Testing
@testable import TaskovskyCore

/// Regression tests for the responsive collapse policy behind WorkspaceView.
///
/// Reference facts vs approximations: the 382x580 minimum (rail 62 + center
/// 320, nav/detail hidden, detail drawer right-aligned at x=82) and the ~220pt
/// navigation popover anchored under the toggle are measured Computer Use
/// observations. The dock/collapse thresholds below are derived from the
/// minimum content plus the docked panels, not measured TickTick values, and
/// stay documented as such.
@Suite struct ResponsiveCollapseTests {
    @Test func tasksCalendarSplitRequiresRoomForBothPanesAndDivider() {
        #expect(!ResponsiveLayout.canShowTasksWithCalendar(availableWidth: 911))
        #expect(ResponsiveLayout.canShowTasksWithCalendar(availableWidth: 912))
        let withSidebar = ResponsiveLayout.availableWidth(totalWidth: 1280, sidebarWidth: 215, collapsed: false)
        #expect(ResponsiveLayout.canShowTasksWithCalendar(availableWidth: withSidebar))
        let narrowWithSidebar = ResponsiveLayout.availableWidth(totalWidth: 961, sidebarWidth: 215, collapsed: false)
        #expect(!ResponsiveLayout.canShowTasksWithCalendar(availableWidth: narrowWithSidebar))
    }

    @Test func minimumWidthMatchesMeasuredCompactReference() {
        #expect(ResponsiveLayout.railWidth == 62)
        #expect(ResponsiveLayout.compactCenterWidth == 320)
        #expect(ResponsiveLayout.minWindowWidth == 382)
        #expect(ResponsiveLayout.validatesMeasuredMinimum())
        // The 300pt drawer right-aligns at x=82 inside the 382pt minimum.
        #expect(ResponsiveLayout.minWindowWidth - ResponsiveLayout.drawerWidth == 82)
    }

    @Test func sidebarCollapseThresholdDerivedFromMinimumContent() {
        // rail 62 + sidebar + divider 1 + center 300.
        #expect(ResponsiveLayout.sidebarCollapseThreshold(sidebarWidth: 215) == 578)
        #expect(ResponsiveLayout.sidebarCollapseThreshold(sidebarWidth: 160) == 523)
        #expect(ResponsiveLayout.sidebarCollapseThreshold(sidebarWidth: 320) == 683)
    }

    @Test func detailHidesBeforeSidebar() {
        // With the default sidebar the detail needs 859pt to dock
        // (62 + 215 + 1 + 300 + 1 + 280) while the sidebar survives down to
        // 578pt: shrinking hides detail first.
        #expect(ResponsiveLayout.shouldDockDetail(totalWidth: 859, sidebarWidth: 215, collapsed: false))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 858, sidebarWidth: 215, collapsed: false))
        #expect(858 > ResponsiveLayout.sidebarCollapseThreshold(sidebarWidth: 215))
    }

    @Test func detailNeverReappearsWhileShrinking() {
        // Monotonic detail-first collapse with the manual preference expanded:
        // sweeping down from wide, once the detail overlays it must never
        // dock again, and once the sidebar hides it must never return.
        // This is the 683/682 regression guard: at custom sidebar 320,
        // width 683 shows nav with overlay detail and 682 hides nav while
        // the detail stays overlaid (auto-collapse frees no dock room).
        for sidebar in [160.0, 215.0, 320.0] {
            var seenOverlay = false
            var seenHidden = false
            var width = 1400.0
            while width >= 382 {
                let docked = ResponsiveLayout.shouldDockDetail(totalWidth: width, sidebarWidth: sidebar, collapsed: false)
                if !docked { seenOverlay = true } else { #expect(!seenOverlay, "detail re-docked while shrinking at \(width)pt, sidebar \(sidebar)pt") }
                let navShown = ResponsiveLayout.isSidebarDocked(totalWidth: width, sidebarWidth: sidebar, manualCollapsed: false, searchActive: false)
                if !navShown { seenHidden = true } else { #expect(!seenHidden, "sidebar returned while shrinking at \(width)pt") }
                width -= 1
            }
        }
    }

    @Test func wideCustomSidebarCollapseBoundary() {
        // Sidebar 320: collapse threshold is 683. At 683 the nav is visible
        // with overlay detail; at 682 the nav hides and the detail must stay
        // overlaid; 643/642 stay overlaid. Only an explicit manual collapse
        // frees dock room (682 then docks; 642 still cannot fit).
        #expect(ResponsiveLayout.isSidebarDocked(totalWidth: 683, sidebarWidth: 320, manualCollapsed: false, searchActive: false))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 683, sidebarWidth: 320, collapsed: false))
        #expect(!ResponsiveLayout.isSidebarDocked(totalWidth: 682, sidebarWidth: 320, manualCollapsed: false, searchActive: false))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 682, sidebarWidth: 320, collapsed: false))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 643, sidebarWidth: 320, collapsed: false))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 642, sidebarWidth: 320, collapsed: false))
        #expect(ResponsiveLayout.shouldDockDetail(totalWidth: 682, sidebarWidth: 320, collapsed: true))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 642, sidebarWidth: 320, collapsed: true))
    }

    @Test func sidebarAutoCollapseAndReverseRestore() {
        // Narrow: auto-hidden even with the manual preference untouched.
        #expect(!ResponsiveLayout.isSidebarDocked(totalWidth: 500, sidebarWidth: 215, manualCollapsed: false, searchActive: false))
        #expect(ResponsiveLayout.shouldAutoCollapseSidebar(totalWidth: 500, sidebarWidth: 215))
        // Expanding restores the same remembered preference in reverse.
        #expect(ResponsiveLayout.isSidebarDocked(totalWidth: 600, sidebarWidth: 215, manualCollapsed: false, searchActive: false))
        #expect(!ResponsiveLayout.shouldAutoCollapseSidebar(totalWidth: 600, sidebarWidth: 215))
    }

    @Test func manualPreferenceSurvivesTransitions() {
        // Manually collapsed stays hidden at every width; manually shown is
        // only hidden by the automatic collapse, never flipped by it.
        for width in [382.0, 500, 578, 860, 1280] {
            #expect(!ResponsiveLayout.isSidebarDocked(totalWidth: width, sidebarWidth: 215, manualCollapsed: true, searchActive: false))
        }
        #expect(ResponsiveLayout.isSidebarDocked(totalWidth: 1280, sidebarWidth: 215, manualCollapsed: false, searchActive: false))
        // Full search always hides the docked sidebar, as before.
        #expect(!ResponsiveLayout.isSidebarDocked(totalWidth: 1280, sidebarWidth: 215, manualCollapsed: false, searchActive: true))
    }

    @Test func compactMinimumKeepsBothPanesHidden() {
        // At the 382pt minimum neither pane can dock: sidebar auto-collapses
        // and the detail overlays, leaving rail + center only.
        #expect(!ResponsiveLayout.isSidebarDocked(totalWidth: 382, sidebarWidth: 215, manualCollapsed: false, searchActive: false))
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 382, sidebarWidth: 215, collapsed: false))
        #expect(ResponsiveLayout.drawerWidth == 300)
        // The narrow-width reveal is a ~220pt popover anchored under the
        // toggle, not a full-height drawer.
        #expect(ResponsiveLayout.sidebarPopoverWidth == 220)
        #expect(ResponsiveLayout.minWindowHeight == 580)
    }

    @Test func windowFloorMathSeparatesTotalAndContent() {
        // The 580pt minimum is the TOTAL window reference. With ~28pt of
        // hidden-titlebar chrome the content floor is 552: setting 580 as the
        // content minimum is what landed the 608 frame.
        #expect(ResponsiveLayout.contentMinHeight(totalHeight: 580, chromeHeight: 28) == 552)
        #expect(ResponsiveLayout.contentMinHeight(totalHeight: ResponsiveLayout.minWindowHeight, chromeHeight: 0) == ResponsiveLayout.minWindowHeight)
        #expect(ResponsiveLayout.contentMinHeight(totalHeight: 10, chromeHeight: 28) == 0)
        // Frame floor identity: content plus chrome reconstructs the total.
        let content = ResponsiveLayout.contentMinHeight(totalHeight: ResponsiveLayout.minWindowHeight, chromeHeight: 28)
        #expect(content + 28 == ResponsiveLayout.minWindowHeight)
    }

    @Test func dockBoundaryAtMinAndMaxSidebarWidths() {
        // Dock threshold = rail 62 + sidebar + divider 1 + center 300 +
        // divider 1 + detail 280: 804 / 859 / 964 at the width extremes.
        for (sidebar, threshold) in [(160.0, 804.0), (215.0, 859.0), (320.0, 964.0)] {
            #expect(ResponsiveLayout.shouldDockDetail(totalWidth: threshold, sidebarWidth: sidebar, collapsed: false))
            #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: threshold - 1, sidebarWidth: sidebar, collapsed: false))
        }
    }

    @Test func dockedSidebarMaxProtectsDetailMinimum() {
        // At each dock boundary the dock-safe maximum equals the current
        // sidebar width: dragging wider must clamp instead of squeezing the
        // center below 300 or stealing the detail's 280.
        for (sidebar, threshold) in [(160.0, 804.0), (215.0, 859.0), (320.0, 964.0)] {
            #expect(PanelDrag.dockedSidebarMax(totalWidth: threshold) == sidebar)
            let clamped = PanelDrag.clampedSidebarWidth(start: sidebar, delta: 200, maxWidth: PanelDrag.dockedSidebarMax(totalWidth: threshold))
            #expect(clamped == sidebar)
            #expect(clamped <= ResponsiveLayout.sidebarMax)
        }
        // Away from the boundary the maximum still caps at the 320 user max.
        #expect(PanelDrag.clampedSidebarWidth(start: 215, delta: 500, maxWidth: nil) == ResponsiveLayout.sidebarMax)
        #expect(PanelDrag.clampedSidebarWidth(start: 215, delta: -500, maxWidth: nil) == ResponsiveLayout.sidebarMin)
    }

    @Test func panelDragClampsSidebarWidth() {
        #expect(PanelDrag.clampedSidebarWidth(start: 215, delta: 40) == 255)
        #expect(PanelDrag.clampedSidebarWidth(start: 215, delta: 500) == ResponsiveLayout.sidebarMax)
        #expect(PanelDrag.clampedSidebarWidth(start: 215, delta: -500) == ResponsiveLayout.sidebarMin)
    }

    @Test func panelDragCollapseBoundaryDoesNotFlap() {
        // Collapse is decided once, on release; mid-drag values stay clamped.
        #expect(PanelDrag.shouldCollapseSidebar(start: 215, delta: -80.1))
        #expect(!PanelDrag.shouldCollapseSidebar(start: 215, delta: -80))
        #expect(!PanelDrag.shouldCollapseSidebar(start: 160, delta: 0))
    }

    @Test func paneFractionClampsBothPanes() {
        // Center never drops below its minimum, detail keeps its minimum.
        let low = PanelDrag.paneFraction(startListWidth: 300, delta: -500, available: 900)
        #expect(abs(low * 900 - ResponsiveLayout.listMin) < 0.001)
        let high = PanelDrag.paneFraction(startListWidth: 300, delta: 500, available: 900)
        #expect(900 - high * 900 >= ResponsiveLayout.detailMin + ResponsiveLayout.dividerWidth - 0.001)
        // Degenerate width never produces NaN or a negative fraction.
        #expect(PanelDrag.paneFraction(startListWidth: 300, delta: 0, available: 0) == 0)
    }
}
