import XCTest

/// Unified Smart Lists/Tags management (T09/T11) native coverage.
///
/// Prepared for the parent-coordinated native slot: DO NOT RUN here.
/// Uses disposable `--qa-session` fixtures only; no personal data.
/// Stale compare-and-swap is covered by `UnifiedManagementTests` at the
/// repository level because the `stale-save` QA injection only affects
/// task/capture saves, not settings/tag/filter writes.
final class UnifiedManagementTests: XCTestCase {
    @MainActor private func launch(qaCase: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let id = UUID().uuidString
        app.launchArguments = ["--qa-session", id]
        if let qaCase { app.launchArguments += ["--qa-case", qaCase] }
        let session = XCTAttachment(string: id); session.name = "QA session"; session.lifetime = .keepAlways
        add(session)
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func openManagement(_ app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        let manage = app.buttons["openManagement"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        reveal(manage, in: app)
        manage.tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].waitForExistence(timeout: 5))
    }

    @MainActor private func selectTab(_ name: String, in app: XCUIApplication) {
        let tabs = app.segmentedControls["managementTabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        tabs.buttons[name].tap()
    }

    @MainActor private func stageTomorrowVisible(in app: XCUIApplication) {
        let row = app.buttons["smartListVisibility-tomorrow"]
        reveal(row, in: app)
        row.tap()
        let option = app.buttons["Show"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].waitForExistence(timeout: 5))
    }

    @MainActor func testManagementOpensWithSmartListsSelected() {
        let app = launch()
        openManagement(app)
        let tabs = app.segmentedControls["managementTabs"]
        XCTAssertTrue(tabs.buttons["Smart Lists"].isSelected)
        XCTAssertTrue(app.buttons["smartListVisibility-today"].exists)
        XCTAssertTrue(app.buttons["addFilter"].exists)
        XCTAssertFalse(app.staticTexts["Assigned to Me"].exists)
        XCTAssertFalse(app.staticTexts["Subscribed Calendars"].exists)
        attach(app, "Management Smart Lists tab")
        selectTab("Tags", in: app)
        XCTAssertTrue(tabs.buttons["Tags"].isSelected)
        XCTAssertTrue(app.buttons["smartListVisibility-tags"].exists)
        XCTAssertTrue(app.buttons["newTag"].exists)
        attach(app, "Management Tags tab")
        selectTab("Smart Lists", in: app)
        XCTAssertTrue(tabs.buttons["Smart Lists"].isSelected)
        app.buttons["managementDone"].tap()
        waitGone(tabs)
    }

    @MainActor func testStagedVisibilitySurvivesTabSwitch() {
        let app = launch()
        openManagement(app)
        stageTomorrowVisible(in: app)
        selectTab("Tags", in: app)
        XCTAssertTrue(app.buttons["newTag"].exists)
        selectTab("Smart Lists", in: app)
        // The staged edit survived both switches: Cancel must offer to discard it.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].exists)
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testAddTagSaveAndReopen() {
        let app = launch()
        openManagement(app)
        selectTab("Tags", in: app)
        app.buttons["newTag"].tap()
        let name = app.textFields["tagName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Neutral unified tag")
        app.buttons["tagDone"].tap()
        XCTAssertTrue(app.buttons["newTag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Neutral unified tag"].exists)
        attach(app, "Management Tags tab after Add Tag save")
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openManagement(app)
        selectTab("Tags", in: app)
        XCTAssertTrue(app.staticTexts["Neutral unified tag"].waitForExistence(timeout: 5))
    }

    @MainActor func testReorderResetsWhenSwitchingTabs() {
        let app = launch()
        openManagement(app)
        app.buttons["managementReorder"].tap()
        XCTAssertEqual(app.buttons["managementReorder"].label, "Finish")
        // Leaving the Smart Lists tab resets reorder: the Tags tab keeps its
        // own controls enabled and shows no Finish toolbar item.
        selectTab("Tags", in: app)
        XCTAssertFalse(app.buttons["managementReorder"].exists)
        XCTAssertTrue(app.buttons["newTag"].isEnabled)
        XCTAssertTrue(app.buttons["smartListVisibility-tags"].exists)
        // Returning shows a reset Reorder control, not a stuck Finish mode.
        selectTab("Smart Lists", in: app)
        let reorder = app.buttons["managementReorder"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 5))
        XCTAssertEqual(reorder.label, "Reorder")
        XCTAssertTrue(app.buttons["addFilter"].exists)
        app.buttons["managementCancel"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testAddFilterSaveAndReopen() {
        let app = launch()
        openManagement(app)
        XCTAssertTrue(app.buttons["addFilter"].exists)
        app.buttons["addFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Neutral unified filter")
        app.buttons["savedFilterDone"].tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].waitForExistence(timeout: 5))
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        app.buttons["Open navigation"].tap()
        XCTAssertTrue(app.buttons["Neutral unified filter"].waitForExistence(timeout: 5))
        attach(app, "Drawer Filters section after Add Filter save")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Open navigation"].tap()
        XCTAssertTrue(app.buttons["Neutral unified filter"].waitForExistence(timeout: 5))
    }

    @MainActor private func gateAlert(in app: XCUIApplication) -> XCUIElement {
        app.alerts["Unsaved visibility changes"]
    }

    @MainActor func testDirtyGateKeepEditingThenDiscardThenChildCancel() {
        let app = launch()
        openManagement(app)
        stageTomorrowVisible(in: app)
        selectTab("Tags", in: app)
        app.buttons["newTag"].tap()
        let gate = gateAlert(in: app)
        XCTAssertTrue(gate.buttons["Save Changes"].waitForExistence(timeout: 5))
        gate.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.buttons["newTag"].exists)
        XCTAssertFalse(app.textFields["tagName"].exists)
        // The staged parent draft is intact: Cancel still offers to discard it.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Keep Editing"].tap()
        // Discard the parent draft and continue into the child editor.
        app.buttons["newTag"].tap()
        XCTAssertTrue(gate.buttons["Discard Changes"].waitForExistence(timeout: 5))
        gate.buttons["Discard Changes"].tap()
        let name = app.textFields["tagName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Neutral discarded tag")
        app.buttons["tagCancel"].tap()
        let tagGate = app.alerts["Discard changes?"]
        XCTAssertTrue(tagGate.buttons["Keep Editing"].waitForExistence(timeout: 5))
        tagGate.buttons["Keep Editing"].tap()
        XCTAssertEqual(name.value as? String, "Neutral discarded tag")
        app.buttons["tagCancel"].tap()
        XCTAssertTrue(tagGate.buttons["Discard Changes"].waitForExistence(timeout: 5))
        tagGate.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.buttons["newTag"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Neutral discarded tag"].exists)
        // The parent was discarded clean, so Cancel closes without a prompt.
        app.buttons["managementCancel"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testDirtyGateSaveThenAddTag() {
        let app = launch()
        openManagement(app)
        stageTomorrowVisible(in: app)
        selectTab("Tags", in: app)
        app.buttons["newTag"].tap()
        let gate = gateAlert(in: app)
        XCTAssertTrue(gate.buttons["Save Changes"].waitForExistence(timeout: 5))
        gate.buttons["Save Changes"].tap()
        let name = app.textFields["tagName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Neutral gated tag")
        app.buttons["tagDone"].tap()
        XCTAssertTrue(app.buttons["newTag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Neutral gated tag"].exists)
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testSaveFailureRetainsDraftWithoutMutation() {
        let app = launch(qaCase: "save-failure")
        openManagement(app)
        stageTomorrowVisible(in: app)
        app.buttons["managementDone"].tap()
        XCTAssertTrue(app.staticTexts["managementError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["managementTabs"].exists)
        attach(app, "Management save failure retains draft")
        // The draft is still staged: Cancel must still offer to discard it.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].exists)
    }

    @MainActor func testFailedSaveThenDoneDoesNotOpenStaleChild() {
        // The Save-and-Continue boundary fails: no child editor may open, and
        // the pending intent must be cleared so an ordinary Done afterwards
        // retries the save instead of navigating to the previously requested
        // child.
        let app = launch(qaCase: "save-failure")
        openManagement(app)
        stageTomorrowVisible(in: app)
        selectTab("Tags", in: app)
        app.buttons["newTag"].tap()
        let gate = gateAlert(in: app)
        XCTAssertTrue(gate.buttons["Save Changes"].waitForExistence(timeout: 5))
        gate.buttons["Save Changes"].tap()
        XCTAssertTrue(app.staticTexts["managementError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["tagName"].exists)
        app.buttons["managementDone"].tap()
        XCTAssertTrue(app.staticTexts["managementError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["tagName"].exists)
        XCTAssertFalse(app.textFields["savedFilterName"].exists)
        XCTAssertTrue(app.segmentedControls["managementTabs"].exists)
        attach(app, "Management failed save then Done opens nothing")
        // The failed write kept the staged draft: Cancel still asks.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.segmentedControls["managementTabs"].exists)
    }

    @MainActor private func waitGone(_ element: XCUIElement) {
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    @MainActor private func reveal(_ row: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !row.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.48))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.23)))
        }
        XCTAssertTrue(row.isHittable)
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
