import XCTest

/// Root informational-label removal.
///
/// The mobile root no longer renders the "Sample workspace · Local editing" /
/// "Local workspace · Early development" label. Readiness is the genuine
/// tab-bar container (`mobileRootReady`), which exists only once the workspace
/// document loads. Uses disposable `--qa-session` fixtures only.
final class RootLabelRemovalTests: XCTestCase {
    @MainActor private func launch(qaCase: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let id = UUID().uuidString
        app.launchArguments = ["--qa-session", id]
        if let qaCase { app.launchArguments += ["--qa-case", qaCase] }
        let session = XCTAttachment(string: id); session.name = "QA session"; session.lifetime = .keepAlways; add(session)
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func assertNoRootLabel(in app: XCUIApplication) {
        XCTAssertFalse(app.staticTexts["Sample workspace · Local editing"].exists)
        XCTAssertFalse(app.staticTexts["Local workspace · Early development"].exists)
    }

    @MainActor private func assertUniqueRootMarker(in app: XCUIApplication) {
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "mobileRootReady").count, 1)
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testRootShowsNoInformationalLabelInAnySection() {
        let app = launch()
        assertUniqueRootMarker(in: app)
        assertNoRootLabel(in: app)
        attach(app, "Tasks root without informational label")
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 5))
        assertUniqueRootMarker(in: app)
        assertNoRootLabel(in: app)
        attach(app, "Calendar root without informational label")
        app.buttons["Search"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 5))
        assertUniqueRootMarker(in: app)
        assertNoRootLabel(in: app)
        app.buttons["Tasks"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobileRootReady"].waitForExistence(timeout: 5))
        assertUniqueRootMarker(in: app)
        assertNoRootLabel(in: app)
    }

    @MainActor func testRootKeepsTasksCalendarNavigationAndControls() {
        let app = launch()
        let root = app.descendants(matching: .any)["mobileRootReady"]
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Tasks"].exists)
        XCTAssertTrue(app.buttons["Calendar"].exists)
        XCTAssertTrue(app.buttons["Search"].exists)
        XCTAssertTrue(app.buttons["Open navigation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["openCapture"].waitForExistence(timeout: 5))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarJumpToDate"].waitForExistence(timeout: 5))
        XCTAssertTrue(root.exists)
        assertNoRootLabel(in: app)
        app.buttons["Search"].tap()
        XCTAssertTrue(app.textFields["workspaceSearch"].waitForExistence(timeout: 5))
        XCTAssertTrue(root.exists)
        assertNoRootLabel(in: app)
        app.buttons["Tasks"].tap()
        XCTAssertTrue(app.buttons["Open navigation"].waitForExistence(timeout: 5))
        XCTAssertTrue(root.exists)
        assertNoRootLabel(in: app)
    }
}
