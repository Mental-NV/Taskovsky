import XCTest

/// Drawer footer Add (T07/T08) native coverage.
///
/// Prepared for the owned native slot: uses disposable `--qa-session`
/// fixtures only; no personal data. Covers the bottom-anchored footer, the
/// List/Filter/Tag menu in reference order, direct blank creation routes with
/// disabled empty saves, Cancel/outside-tap dismissal with no writes, blank
/// reset on reopen, successful neutral creation with drawer reachability and
/// relaunch persistence, footer reachability after scrolling, popup touch
/// blocking/restoration (underlying controls non-hittable while open, popup
/// rows/dismiss reachable), the disabled Add entry when editing is
/// unavailable, and the existing management return path. VoiceOver focus
/// traversal/focus transfer and Escape behavior are explicitly not covered.
final class DrawerAddTests: XCTestCase {
    @MainActor private func launch(qaCase: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let id = UUID().uuidString
        app.launchArguments = ["--qa-session", id]
        if let qaCase { app.launchArguments += ["--qa-case", qaCase] }
        let session = XCTAttachment(string: id); session.name = "QA session"; session.lifetime = .keepAlways
        add(session)
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func openDrawer(_ app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        XCTAssertTrue(app.buttons["drawerDone"].waitForExistence(timeout: 5))
    }

    @MainActor private func drawerAddButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["drawerAdd"]
    }

    @MainActor private func openAddMenu(_ app: XCUIApplication) {
        let add = drawerAddButton(app)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.descendants(matching: .any)["drawerAddList"].waitForExistence(timeout: 5))
    }

    @MainActor private func menuRow(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    @MainActor private func reveal(_ row: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !row.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.48))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.23)))
        }
        XCTAssertTrue(row.isHittable)
    }

    @MainActor private func waitGone(_ element: XCUIElement) {
        let value = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [value], timeout: 5), .completed)
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testDrawerFooterAddMenuOrderAndOutsideDismissal() {
        let app = launch()
        openDrawer(app)
        XCTAssertTrue(app.descendants(matching: .any)["drawerFooter"].waitForExistence(timeout: 5))
        XCTAssertTrue(drawerAddButton(app).isHittable)
        XCTAssertTrue(app.buttons["openManagement"].isHittable)
        attach(app, "Tasks drawer footer with Add and management")
        openAddMenu(app)
        let list = menuRow("drawerAddList", in: app)
        let filter = menuRow("drawerAddFilter", in: app)
        let tag = menuRow("drawerAddTag", in: app)
        XCTAssertTrue(list.isHittable)
        XCTAssertTrue(filter.isHittable)
        XCTAssertTrue(tag.isHittable)
        XCTAssertLessThan(list.frame.minY, filter.frame.minY)
        XCTAssertLessThan(filter.frame.minY, tag.frame.minY)
        attach(app, "Drawer Add menu with List Filter Tag")
        app.buttons["drawerAddBackdrop"].tap()
        waitGone(list)
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        XCTAssertTrue(drawerAddButton(app).exists)
        XCTAssertFalse(app.navigationBars["Add List"].exists)
        XCTAssertFalse(app.navigationBars["New Filter"].exists)
        XCTAssertFalse(app.navigationBars["Add Tag"].exists)
    }

    @MainActor func testDrawerAddPopupModalIsolation() {
        let app = launch()
        openDrawer(app)
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        XCTAssertTrue(app.buttons["smartDrawer-today"].exists)
        XCTAssertTrue(app.buttons["drawerBackdrop"].exists)
        openAddMenu(app)
        XCTAssertTrue(app.descendants(matching: .any)["drawerAddMenu"].exists)
        XCTAssertTrue(menuRow("drawerAddList", in: app).isHittable)
        XCTAssertTrue(menuRow("drawerAddFilter", in: app).isHittable)
        XCTAssertTrue(menuRow("drawerAddTag", in: app).isHittable)
        XCTAssertTrue(app.buttons["drawerAddBackdrop"].isHittable)
        // The underlying drawer stays visible but unreachable: on this stack
        // accessibility-hidden views remain listed yet never hittable while
        // the modal dismiss layer covers them.
        XCTAssertFalse(app.buttons["drawerDone"].isHittable)
        XCTAssertFalse(app.buttons["smartDrawer-today"].isHittable)
        XCTAssertFalse(app.buttons["drawerBackdrop"].isHittable)
        XCTAssertFalse(drawerAddButton(app).isHittable)
        app.buttons["drawerAddBackdrop"].tap()
        waitGone(menuRow("drawerAddList", in: app))
        XCTAssertFalse(app.descendants(matching: .any)["drawerAddMenu"].exists)
        XCTAssertTrue(app.buttons["drawerDone"].isHittable)
        XCTAssertTrue(app.buttons["smartDrawer-today"].exists)
        XCTAssertTrue(app.buttons["drawerBackdrop"].isHittable)
        XCTAssertTrue(drawerAddButton(app).isHittable)
    }

    @MainActor func testDrawerAddDisabledWhenEditingUnavailable() {
        let app = launch(qaCase: "unknown-workspace")
        openDrawer(app)
        let add = drawerAddButton(app)
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(add.isEnabled)
        XCTAssertFalse(menuRow("drawerAddList", in: app).exists)
        XCTAssertFalse(menuRow("drawerAddFilter", in: app).exists)
        XCTAssertFalse(menuRow("drawerAddTag", in: app).exists)
    }

    @MainActor func testDrawerAddBlankRoutesDisabledSaveAndCancel() {
        let app = launch()
        openDrawer(app)
        openAddMenu(app)
        menuRow("drawerAddList", in: app).tap()
        XCTAssertTrue(app.navigationBars["Add List"].waitForExistence(timeout: 5))
        let listName = app.textViews["organizationName"]
        XCTAssertTrue(listName.waitForExistence(timeout: 5))
        XCTAssertEqual(listName.value as? String, "")
        XCTAssertFalse(app.buttons["organizationSave"].isEnabled)
        attach(app, "Blank Add List from drawer")
        app.buttons["organizationCancel"].tap()
        waitGone(app.navigationBars["Add List"])
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        openAddMenu(app)
        menuRow("drawerAddFilter", in: app).tap()
        XCTAssertTrue(app.navigationBars["New Filter"].waitForExistence(timeout: 5))
        let filterName = app.textFields["savedFilterName"]
        XCTAssertTrue(filterName.waitForExistence(timeout: 5))
        XCTAssertTrue(["", "Filter name"].contains(filterName.value as? String))
        XCTAssertFalse(app.buttons["savedFilterDone"].isEnabled)
        attach(app, "Blank Normal Filter from drawer")
        app.buttons["savedFilterCancel"].tap()
        waitGone(app.navigationBars["New Filter"])
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        openAddMenu(app)
        menuRow("drawerAddTag", in: app).tap()
        XCTAssertTrue(app.navigationBars["Add Tag"].waitForExistence(timeout: 5))
        let tagName = app.textFields["tagName"]
        XCTAssertTrue(tagName.waitForExistence(timeout: 5))
        XCTAssertTrue(["", "Tag name"].contains(tagName.value as? String))
        XCTAssertFalse(app.buttons["tagDone"].isEnabled)
        attach(app, "Blank Add Tag from drawer")
        app.buttons["tagCancel"].tap()
        waitGone(app.navigationBars["Add Tag"])
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        XCTAssertFalse(app.buttons["Neutral drawer list"].exists)
        XCTAssertFalse(app.buttons["Neutral drawer filter"].exists)
        XCTAssertFalse(app.buttons["Neutral drawer tag"].exists)
    }

    @MainActor func testDrawerAddReopenResetsBlankDraft() {
        let app = launch()
        openDrawer(app)
        openAddMenu(app)
        menuRow("drawerAddList", in: app).tap()
        let name = app.textViews["organizationName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Unsaved drawer draft")
        app.buttons["organizationCancel"].tap()
        XCTAssertTrue(app.alerts["Discard changes?"].waitForExistence(timeout: 5))
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.navigationBars["Add List"])
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        XCTAssertFalse(app.buttons["Unsaved drawer draft"].exists)
        openAddMenu(app)
        menuRow("drawerAddList", in: app).tap()
        let reopened = app.textViews["organizationName"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 5))
        XCTAssertEqual(reopened.value as? String, "")
        XCTAssertFalse(app.buttons["organizationSave"].isEnabled)
        app.buttons["organizationCancel"].tap()
        waitGone(app.navigationBars["Add List"])
        openAddMenu(app)
        menuRow("drawerAddFilter", in: app).tap()
        let filterName = app.textFields["savedFilterName"]
        XCTAssertTrue(filterName.waitForExistence(timeout: 5))
        filterName.tap()
        filterName.typeText("Unsaved drawer filter")
        app.buttons["savedFilterCancel"].tap()
        XCTAssertTrue(app.alerts["Discard changes?"].waitForExistence(timeout: 5))
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.navigationBars["New Filter"])
        openAddMenu(app)
        menuRow("drawerAddFilter", in: app).tap()
        let reopenedFilter = app.textFields["savedFilterName"]
        XCTAssertTrue(reopenedFilter.waitForExistence(timeout: 5))
        XCTAssertTrue(["", "Filter name"].contains(reopenedFilter.value as? String))
        XCTAssertFalse(app.buttons["savedFilterDone"].isEnabled)
        app.buttons["savedFilterCancel"].tap()
        waitGone(app.navigationBars["New Filter"])
        XCTAssertTrue(app.buttons["drawerDone"].exists)
    }

    @MainActor func testDrawerAddCreatesListFilterTagPersistAndReach() {
        let app = launch()
        openDrawer(app)
        openAddMenu(app)
        menuRow("drawerAddList", in: app).tap()
        let listName = app.textViews["organizationName"]
        XCTAssertTrue(listName.waitForExistence(timeout: 5))
        listName.typeText("Neutral drawer list")
        XCTAssertTrue(app.buttons["organizationSave"].isEnabled)
        app.buttons["organizationSave"].tap()
        waitGone(app.navigationBars["Add List"])
        let createdList = app.buttons["Neutral drawer list"]
        reveal(createdList, in: app)
        openAddMenu(app)
        menuRow("drawerAddFilter", in: app).tap()
        let filterName = app.textFields["savedFilterName"]
        XCTAssertTrue(filterName.waitForExistence(timeout: 5))
        filterName.tap()
        filterName.typeText("Neutral drawer filter")
        XCTAssertTrue(app.buttons["savedFilterDone"].isEnabled)
        app.buttons["savedFilterDone"].tap()
        waitGone(app.navigationBars["New Filter"])
        XCTAssertTrue(app.buttons["Neutral drawer filter"].waitForExistence(timeout: 5))
        openAddMenu(app)
        menuRow("drawerAddTag", in: app).tap()
        let tagName = app.textFields["tagName"]
        XCTAssertTrue(tagName.waitForExistence(timeout: 5))
        tagName.tap()
        tagName.typeText("Neutral drawer tag")
        XCTAssertTrue(app.buttons["tagDone"].isEnabled)
        app.buttons["tagDone"].tap()
        waitGone(app.navigationBars["Add Tag"])
        let createdTag = app.buttons["Neutral drawer tag"]
        reveal(createdTag, in: app)
        app.buttons["drawerDone"].tap()
        waitGone(app.buttons["drawerDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
        openDrawer(app)
        reveal(app.buttons["Neutral drawer list"], in: app)
        XCTAssertTrue(app.buttons["Neutral drawer filter"].waitForExistence(timeout: 5))
        reveal(app.buttons["Neutral drawer tag"], in: app)
    }

    @MainActor func testDrawerFooterAfterScrollAndManagementReturns() {
        let app = launch(qaCase: "organization")
        openDrawer(app)
        for _ in 0..<4 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.30)))
        }
        XCTAssertTrue(drawerAddButton(app).isHittable)
        XCTAssertTrue(app.buttons["openManagement"].isHittable)
        attach(app, "Drawer footer reachable after scrolling")
        app.buttons["openManagement"].tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].waitForExistence(timeout: 5))
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        XCTAssertTrue(app.buttons["drawerDone"].exists)
        XCTAssertTrue(app.buttons["drawerBackdrop"].exists)
        app.buttons["drawerDone"].tap()
        waitGone(app.buttons["drawerDone"])
        XCTAssertTrue(app.buttons["openCapture"].waitForExistence(timeout: 5))
    }
}
