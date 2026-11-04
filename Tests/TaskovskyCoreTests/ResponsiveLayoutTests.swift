import Testing
@testable import TaskovskyCore

@Suite struct ResponsiveLayoutTests {
    @Test func docksAtWideWidthWithDefaultSidebar() {
        #expect(ResponsiveLayout.shouldDockDetail(totalWidth: 1060, sidebarWidth: 215, collapsed: false))
        #expect(ResponsiveLayout.shouldDockDetail(totalWidth: 961, sidebarWidth: 215, collapsed: false))
    }

    @Test func overlaysAtCompactWidth() {
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 757, sidebarWidth: 215, collapsed: false))
    }

    @Test func manualCollapseKeepsDocked() {
        // Collapsing the sidebar frees width, so detail stays docked.
        #expect(ResponsiveLayout.shouldDockDetail(totalWidth: 780, sidebarWidth: 215, collapsed: true))
    }

    @Test func wideSidebarRaisesDockThreshold() {
        #expect(!ResponsiveLayout.shouldDockDetail(totalWidth: 900, sidebarWidth: 320, collapsed: false))
        #expect(ResponsiveLayout.shouldDockDetail(totalWidth: 980, sidebarWidth: 320, collapsed: false))
    }

    @Test func dockedListWidthRespectsMinBounds() {
        let available = 1200.0 - 62 - 215 - 1
        let list = ResponsiveLayout.dockedListWidth(available: available, fraction: 0.45)
        #expect(list >= ResponsiveLayout.listMin)
        #expect(available - list >= ResponsiveLayout.detailMin + ResponsiveLayout.dividerWidth)
        // Degenerate width never goes negative.
        #expect(ResponsiveLayout.dockedListWidth(available: 100, fraction: 0.45) >= 0)
    }
}
