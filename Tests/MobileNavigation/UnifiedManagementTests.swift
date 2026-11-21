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
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
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

    /// T10 popup flow: tap the row, tap the anchored choice, the popup
    /// dismisses itself. No pushed page and no back navigation remain.
    @MainActor private func stageTomorrowVisible(in app: XCUIApplication) {
        let row = app.buttons["smartListVisibility-tomorrow"]
        reveal(row, in: app)
        row.tap()
        let option = app.buttons["visibilityOption-tomorrow-show"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        waitGone(option)
        XCTAssertTrue(app.segmentedControls["managementTabs"].waitForExistence(timeout: 5))
    }

    @MainActor private func openVisibilityPopup(_ key: String, in app: XCUIApplication) {
        let row = app.buttons["smartListVisibility-" + key]
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.buttons["visibilityOption-" + key + "-show"].waitForExistence(timeout: 5))
    }

    @MainActor private func popupOptions(_ key: String, in app: XCUIApplication) -> [XCUIElement] {
        ["show", "showIfNotEmpty", "hidden"].map { app.buttons["visibilityOption-" + key + "-" + $0] }
    }

    /// Dismissing the management sheet returns to the still-open drawer, so
    /// reopening taps the drawer entry directly instead of the hamburger.
    @MainActor private func reopenManagement(_ app: XCUIApplication) {
        let manage = app.buttons["openManagement"]
        reveal(manage, in: app)
        manage.tap()
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
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
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

    // MARK: - T10 anchored visibility popup

    @MainActor func testVisibilityPopupOrderCheckAndBackdropDismiss() {
        let app = launch()
        openManagement(app)
        // Today is shown in the neutral fixture: the check sits on Show.
        openVisibilityPopup("today", in: app)
        let options = popupOptions("today", in: app)
        for option in options { XCTAssertTrue(option.exists) }
        XCTAssertTrue(options[0].label.contains("Show"))
        XCTAssertTrue(options[1].label.contains("Show if not empty"))
        XCTAssertTrue(options[2].label.contains("Hidden"))
        XCTAssertLessThan(options[0].frame.minY, options[1].frame.minY)
        XCTAssertLessThan(options[1].frame.minY, options[2].frame.minY)
        XCTAssertGreaterThanOrEqual(options[0].frame.height, 44)
        XCTAssertTrue(options[0].isSelected)
        XCTAssertFalse(options[1].isSelected)
        XCTAssertFalse(options[2].isSelected)
        attach(app, "Visibility popup exact order and check")
        // Backdrop tap: the navigation title is outside the anchored popup
        // and performs no management action.
        app.navigationBars.firstMatch.tap()
        waitGone(options[0])
        // Same Smart Lists tab, no mutation staged: Cancel closes directly.
        XCTAssertTrue(app.segmentedControls["managementTabs"].buttons["Smart Lists"].isSelected)
        XCTAssertTrue(app.buttons["smartListVisibility-today"].exists)
        app.buttons["managementCancel"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testVisibilityChoiceStagesCancelDiscardsDoneSaves() {
        let app = launch()
        openManagement(app)
        openVisibilityPopup("tomorrow", in: app)
        let options = popupOptions("tomorrow", in: app)
        XCTAssertTrue(options[2].isSelected)
        options[0].tap()
        waitGone(options[0])
        // The row detail reflects the staged choice while nothing is saved.
        XCTAssertEqual(app.buttons["smartListVisibility-tomorrow"].value as? String, "Show")
        // The staged choice survives a tab switch and back.
        selectTab("Tags", in: app)
        XCTAssertTrue(app.buttons["newTag"].exists)
        selectTab("Smart Lists", in: app)
        XCTAssertEqual(app.buttons["smartListVisibility-tomorrow"].value as? String, "Show")
        // Cancel discards: the row returns to the persisted value.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Discard Changes"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        reopenManagement(app)
        XCTAssertEqual(app.buttons["smartListVisibility-tomorrow"].value as? String, "Hidden")
        // Restage and save with Done; the value persists across relaunch and
        // the drawer shows Tomorrow after saving Show.
        openVisibilityPopup("tomorrow", in: app)
        app.buttons["visibilityOption-tomorrow-show"].tap()
        waitGone(app.buttons["visibilityOption-tomorrow-show"])
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
        openManagement(app)
        XCTAssertEqual(app.buttons["smartListVisibility-tomorrow"].value as? String, "Show")
        app.buttons["managementCancel"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        app.buttons["Open navigation"].tap()
        XCTAssertTrue(app.buttons["smartDrawer-tomorrow"].waitForExistence(timeout: 5))
    }

    @MainActor func testVisibilityPopupRepeatedOpenAndSelectedRowDismiss() {
        let app = launch()
        openManagement(app)
        // Open and dismiss via the already-selected row twice: no mutation.
        for _ in 0..<2 {
            openVisibilityPopup("today", in: app)
            let options = popupOptions("today", in: app)
            XCTAssertTrue(options[0].isSelected)
            options[0].tap()
            waitGone(options[0])
        }
        app.buttons["managementCancel"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        // A different choice from the same popup saves through Done.
        reopenManagement(app)
        openVisibilityPopup("today", in: app)
        let options = popupOptions("today", in: app)
        options[2].tap()
        waitGone(options[0])
        XCTAssertEqual(app.buttons["smartListVisibility-today"].value as? String, "Hidden")
        app.buttons["managementDone"].tap()
        waitGone(app.segmentedControls["managementTabs"])
        reopenManagement(app)
        XCTAssertEqual(app.buttons["smartListVisibility-today"].value as? String, "Hidden")
        app.buttons["managementCancel"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testTagsAndFiltersVisibilityRowsUsePopup() {
        let app = launch()
        openManagement(app)
        // Drawer-sections Filters row uses the same anchored popup.
        openVisibilityPopup("filters", in: app)
        var options = popupOptions("filters", in: app)
        XCTAssertTrue(options[0].isSelected)
        XCTAssertLessThan(options[0].frame.minY, options[1].frame.minY)
        XCTAssertLessThan(options[1].frame.minY, options[2].frame.minY)
        options[2].tap()
        waitGone(options[2])
        XCTAssertEqual(app.buttons["smartListVisibility-filters"].value as? String, "Hidden")
        // Tags tab Tags row: same three choices with the current check.
        selectTab("Tags", in: app)
        openVisibilityPopup("tags", in: app)
        options = popupOptions("tags", in: app)
        for option in options { XCTAssertTrue(option.exists) }
        XCTAssertTrue(options[0].isSelected)
        attach(app, "Tags visibility popup")
        // Backdrop dismiss keeps the staged Filters edit intact.
        app.navigationBars.firstMatch.tap()
        waitGone(options[0])
        selectTab("Smart Lists", in: app)
        XCTAssertEqual(app.buttons["smartListVisibility-filters"].value as? String, "Hidden")
        // Cancel discards both staged rows without a save.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Discard Changes"].tap()
        waitGone(app.segmentedControls["managementTabs"])
    }

    @MainActor func testVisibilityPopupKeepsNestedGuardsAndReorder() {
        let app = launch()
        openManagement(app)
        stageTomorrowVisible(in: app)
        // The dirty gate still guards nested entry after a popup-staged edit.
        selectTab("Tags", in: app)
        app.buttons["newTag"].tap()
        XCTAssertTrue(gateAlert(in: app).buttons["Save Changes"].waitForExistence(timeout: 5))
        gateAlert(in: app).buttons["Keep Editing"].tap()
        XCTAssertEqual(app.buttons["smartListVisibility-tags"].value as? String, "Show")
        selectTab("Smart Lists", in: app)
        XCTAssertEqual(app.buttons["smartListVisibility-tomorrow"].value as? String, "Show")
        // Reorder mode still replaces popup rows with move controls.
        app.buttons["managementReorder"].tap()
        XCTAssertFalse(app.buttons["smartListVisibility-tomorrow"].exists)
        XCTAssertTrue(app.buttons["smartListUp-tomorrow"].exists)
        app.buttons["managementReorder"].tap()
        // The popup still opens after leaving reorder mode; dismiss it via
        // the already-checked row with no further mutation.
        openVisibilityPopup("tomorrow", in: app)
        let dismissOptions = popupOptions("tomorrow", in: app)
        XCTAssertTrue(dismissOptions[0].isSelected)
        dismissOptions[0].tap()
        waitGone(dismissOptions[0])
        XCTAssertEqual(app.buttons["smartListVisibility-tomorrow"].value as? String, "Show")
        // Discard the staged popup choice; Cancel then closes cleanly.
        app.buttons["managementCancel"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 5))
        app.buttons["Discard Changes"].tap()
        waitGone(app.segmentedControls["managementTabs"])
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
