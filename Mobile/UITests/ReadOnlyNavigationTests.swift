import XCTest

final class ReadOnlyNavigationTests: XCTestCase {
    @MainActor private func launch(qaCase: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let id = UUID().uuidString
        app.launchArguments = ["--qa-session", id]
        if let qaCase { app.launchArguments += ["--qa-case", qaCase] }
        let session = XCTAttachment(string: id); session.name = "QA session"; session.lifetime = .keepAlways; add(session)
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor func testCompactCaptureOpensMetadataAndKeepsDraftThroughMoreAndCancel() {
        let app = launch()
        app.buttons["openCapture"].tap()
        let title = app.textViews["captureTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["captureDescription"].exists)
        XCTAssertTrue(app.buttons["captureMore"].exists)
        XCTAssertFalse(app.staticTexts["captureRecoveryStatus"].exists)
        XCTAssertFalse(app.staticTexts["Recovery copy saved"].exists)
        attach(app, "Compact task composer without recovery notice")
        title.tap(); title.typeText("Compact composer draft")
        app.buttons["capturePriorityPicker"].tap()
        XCTAssertTrue(app.navigationBars["Priority"].waitForExistence(timeout: 5))
        app.buttons["High"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["captureTagsPicker"].tap()
        XCTAssertTrue(app.navigationBars["Tags"].waitForExistence(timeout: 5))
        app.buttons["Planning"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["captureDatePage"].tap()
        XCTAssertTrue(app.switches["captureDateToggle"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["captureMore"].tap()
        XCTAssertTrue(app.textViews["captureDescription"].waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Compact composer draft")
        app.buttons["captureCancel"].tap()
        app.buttons["Keep Editing"].tap()
        XCTAssertEqual(title.value as? String, "Compact composer draft")
        app.buttons["captureCancel"].tap(); app.buttons["Discard"].tap()
        waitGone(title)
        XCTAssertFalse(app.buttons["Compact composer draft"].exists)
        app.buttons["openCapture"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Saved compact task")
        app.buttons["captureAdd"].tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 8))
        app.buttons["taskDetailDone"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Saved compact task"].waitForExistence(timeout: 10))

    }

    @MainActor func testEmptyDescriptionActionsStayCompactAndPlainSaveSurvivesRelaunch() {
        let app = launch()
        let input = openCapture(app)
        input.tap(); input.typeText("Compact empty description")
        app.buttons["captureAdd"].tap()
        let menu = app.buttons["emptyDescriptionActions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["taskDescription"].exists)
        XCTAssertFalse(app.buttons["Edit description"].exists)
        XCTAssertFalse(app.buttons["editRichDescription"].exists)
        attach(app, "Compact empty description detail")
        menu.tap()
        XCTAssertTrue(app.buttons["Edit description"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["editRichDescription"].exists)
        app.buttons["Edit description"].tap()
        let editor = app.textViews["fieldEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        app.buttons["fieldEditorCancel"].tap()
        waitGone(editor)
        XCTAssertTrue(menu.exists)
        menu.tap(); app.buttons["Edit description"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText("A saved description")
        app.buttons["fieldEditorDone"].tap(); waitGone(editor)
        XCTAssertFalse(menu.exists)
        XCTAssertEqual(app.staticTexts["taskDescription"].label, "A saved description")
        app.buttons["taskDetailDone"].tap()
        app.terminate(); app.launch()
        let task = app.buttons["Compact empty description"]
        XCTAssertTrue(task.waitForExistence(timeout: 10)); task.tap()
        XCTAssertEqual(app.staticTexts["taskDescription"].label, "A saved description")
        XCTAssertFalse(menu.exists)
    }

    @MainActor func testEmptyDescriptionFormattedRouteCanCancelWithoutCreatingBody() {
        let app = launch()
        let input = openCapture(app)
        input.tap(); input.typeText("Empty formatted route")
        app.buttons["captureAdd"].tap()
        let menu = app.buttons["emptyDescriptionActions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap(); app.buttons["editRichDescription"].tap()
        let editor = app.textViews["richFieldEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String ?? "", "")
        app.buttons["fieldEditorCancel"].tap(); waitGone(editor)
        XCTAssertTrue(menu.exists)
        XCTAssertFalse(app.staticTexts["taskDescription"].exists)
        menu.tap(); app.buttons["editRichDescription"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText("Unsaved text")
        app.buttons["fieldEditorCancel"].tap(); app.buttons["Discard"].tap()
        waitGone(editor)
        XCTAssertTrue(menu.exists)
        XCTAssertFalse(app.staticTexts["taskDescription"].exists)
    }

    @MainActor func testCompactListDatesRemainAccessibleAndOpenDetail() {
        let app = launch()
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(task.frame.height, 44)
        XCTAssertFalse((task.value as? String ?? "").isEmpty)
        attach(app, "Compact Tasks rows with trailing dates")
        task.tap()
        XCTAssertTrue(app.buttons["editTitle"].waitForExistence(timeout: 5))
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        let input = openTitle(app)
        let suffix = " with a deliberately long descriptive title to verify trailing date fit"
        input.typeText(suffix)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        app.buttons["taskDetailDone"].tap()
        let longTask = app.buttons["Review the project outline" + suffix]
        XCTAssertTrue(longTask.waitForExistence(timeout: 5))
        XCTAssertFalse((longTask.value as? String ?? "").isEmpty)
        attach(app, "Compact Tasks long title retains date")
    }

    @MainActor func testListDatesReflowAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-session", UUID().uuidString,
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        let task = app.buttons["Review the project outline"]
        reveal(task, in: app)
        XCTAssertGreaterThanOrEqual(task.frame.height, 44)
        XCTAssertFalse((task.value as? String ?? "").isEmpty)
        attach(app, "Tasks rows accessibility stacked dates")
        task.tap()
        XCTAssertTrue(app.buttons["editTitle"].waitForExistence(timeout: 5))
        app.buttons["taskDetailDone"].tap()
    }

    @MainActor func testDrawerShellBackdropAndDestination() {
        let app = launch()
        func verifyCaptureRestored() {
            let capture = app.buttons["openCapture"]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isHittable == true"), object: capture)], timeout: 5), .completed)
            capture.tap()
            let cancel = app.buttons["captureCancel"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 5))
            cancel.tap()
            waitGone(cancel)
        }
        verifyCaptureRestored()
        for _ in 0..<2 {
            app.buttons["Open navigation"].tap()
            let backdrop = app.buttons["drawerBackdrop"]
            XCTAssertTrue(backdrop.waitForExistence(timeout: 5))
            let today = app.buttons["smartDrawer-today"]
            XCTAssertTrue(today.isHittable)
            XCTAssertLessThan(today.frame.maxX, app.frame.width * 0.9)
            XCTAssertFalse(app.buttons["openCapture"].isEnabled)
            attach(app, "Tasks left drawer")
            backdrop.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            waitGone(backdrop)
            verifyCaptureRestored()
        }
        app.buttons["Open navigation"].tap()
        app.buttons["smartDrawer-inbox"].tap()
        waitGone(app.buttons["drawerBackdrop"])
        XCTAssertTrue(app.staticTexts["Inbox"].firstMatch.waitForExistence(timeout: 5))
        verifyCaptureRestored()
        app.buttons["Open navigation"].tap()
        app.buttons["drawerDone"].tap()
        waitGone(app.buttons["drawerBackdrop"])
        verifyCaptureRestored()
    }

    @MainActor func testDrawerNestedManagerReturnsToDrawer() {
        let app = launch(qaCase: "organization")
        openOrganization(app)
        app.buttons["organizationManagerDone"].tap()
        XCTAssertTrue(app.buttons["drawerDone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["drawerBackdrop"].exists)
        app.buttons["drawerDone"].tap()
        XCTAssertTrue(app.buttons["openCapture"].waitForExistence(timeout: 5))
        openOrganization(app)
        app.buttons["organizationManagerDone"].tap()
        app.buttons["smartDrawer-today"].tap()
        waitGone(app.buttons["drawerBackdrop"])
    }

    @MainActor func testDrawerLargeTextCanDismissAndNavigate() {
        let app = XCUIApplication()
        app.launchArguments = ["--qa-session", UUID().uuidString,
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Open navigation"].tap()
        XCTAssertTrue(app.buttons["drawerBackdrop"].waitForExistence(timeout: 5))
        attach(app, "Tasks drawer accessibility text")
        app.buttons["Navigation utilities"].tap()
        app.buttons["manageTags"].tap()
        app.buttons["tagManagerDone"].tap()
        XCTAssertTrue(app.buttons["drawerDone"].waitForExistence(timeout: 5))
        app.buttons["drawerDone"].tap()
        waitGone(app.buttons["drawerBackdrop"])
        app.buttons["Open navigation"].tap()
        let today = app.buttons["smartDrawer-today"]
        reveal(today, in: app)
        today.tap()
        XCTAssertTrue(app.buttons["openCapture"].waitForExistence(timeout: 5))
    }

    @MainActor func testStyledDescriptionIsProtected() {
        let app = launch()
        attach(app, "Tasks")
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 5)); task.tap()
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, "Project overview\nKeep the key decisions together.\nA composed e\u{301} and an emoji 🧩 remain unchanged.")
        XCTAssertFalse(app.buttons["Edit description"].isEnabled)
        XCTAssertTrue(app.buttons["editTitle"].isEnabled)
        attach(app, "Styled task preview")
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["openCapture"].isEnabled)
    }
    @MainActor func testCalendarViews() {
        let app = launch(); app.buttons["Calendar"].tap()
        for mode in ["Day", "Week", "Month", "Year", "Agenda", "Multi-Day", "Multi-Week"] {
            app.buttons["Calendar view"].tap(); app.buttons[mode].tap()
            XCTAssertTrue(app.staticTexts[mode].exists)
            if mode == "Year" { attach(app, "Calendar Year") }
        }
        app.buttons["Calendar view"].tap(); app.buttons["Month"].tap()
        attach(app, "Calendar Month")
    }

    @MainActor func testCalendarJumpToDistantDateCancelAndKeepMode() {
        let app = launch()
        app.buttons["Calendar"].tap()
        let jump = app.buttons["calendarJumpToDate"]
        XCTAssertTrue(jump.waitForExistence(timeout: 5))
        let initial = jump.value as? String
        XCTAssertTrue(initial?.contains("November") == true)
        XCTAssertTrue(initial?.contains("2026") == true)
        XCTAssertTrue(app.staticTexts["Week"].exists)

        func stageDistantDate() {
            jump.tap()
            let month = app.pickerWheels.matching(NSPredicate(format: "value == %@", "November")).firstMatch
            let year = app.pickerWheels.matching(NSPredicate(format: "value == %@", "2026")).firstMatch
            XCTAssertTrue(year.waitForExistence(timeout: 5))
            year.adjust(toPickerWheelValue: "2027")
            month.adjust(toPickerWheelValue: "March")
        }
        stageDistantDate()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(jump.value as? String, initial)
        stageDistantDate()
        app.buttons["Go"].tap()
        XCTAssertTrue((jump.value as? String)?.contains("March") == true)
        XCTAssertTrue((jump.value as? String)?.contains("2027") == true)
        XCTAssertTrue(app.staticTexts["Week"].exists)
        attach(app, "Week after jumping to a distant date")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertEqual(jump.value as? String, initial)
        XCTAssertTrue(app.staticTexts["Week"].exists)
    }

    @MainActor func testCalendarMonthScrollBrowsesBothDirectionsAndHonorsDateNavigation() {
        let app = launch(qaCase: "month-browse")
        app.buttons["Calendar"].tap()
        let grid = app.scrollViews["calendarMonthGrid"]
        let jump = app.buttons["calendarJumpToDate"]
        let level = app.staticTexts["calendarMonthZoomLevel"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertEqual(level.label, "Full Month")

        func shows(_ title: String) -> Bool {
            let card = app.buttons[title]
            return card.isHittable && (grid.frame.minY + 10...app.frame.maxY - 130).contains(card.frame.midY)
        }
        func expectMonth(_ name: String) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", name), object: jump)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
        }
        func scroll(towardFuture: Bool, until title: String, month name: String) {
            func reached() -> Bool { shows(title) && (jump.value as? String)?.contains(name) == true }
            let upper = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.39))
            let lower = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.56))
            for _ in 0..<14 {
                if reached() { return }
                let before = jump.value as? String
                (towardFuture ? lower : upper).press(forDuration: 0.05, thenDragTo: towardFuture ? upper : lower,
                                                     withVelocity: .slow, thenHoldForDuration: 0.05)
                print("Month scroll from \(before ?? "?") to \(jump.value ?? "?")")
            }
            XCTAssertTrue(reached(), "Expected a visible \(title) in \(jump.value ?? "an unknown month")")
        }
        XCTAssertTrue(shows("November plan"))
        expectMonth("November")
        scroll(towardFuture: false, until: "October review", month: "October")
        expectMonth("October")
        attach(app, "Month after scrolling back into October")
        app.buttons["Today"].tap()
        expectMonth("November")
        XCTAssertTrue(shows("November plan"))
        scroll(towardFuture: true, until: "December plan", month: "December")
        scroll(towardFuture: true, until: "January review", month: "January")
        expectMonth("January")
        attach(app, "Month after scrolling forward into January")

        app.buttons["Today"].tap()
        expectMonth("November")
        app.buttons["Next Calendar period"].tap()
        expectMonth("December")
        XCTAssertTrue(shows("December plan"))
        app.buttons["Previous Calendar period"].tap()
        expectMonth("November")
        XCTAssertTrue(shows("November plan"))
        jump.tap()
        let month = app.pickerWheels.matching(NSPredicate(format: "value == %@", "November")).firstMatch
        let year = app.pickerWheels.matching(NSPredicate(format: "value == %@", "2026")).firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        year.adjust(toPickerWheelValue: "2027")
        month.adjust(toPickerWheelValue: "March")
        app.buttons["Go"].tap()
        expectMonth("March")
        XCTAssertTrue(shows("March planning"))
        XCTAssertEqual(level.label, "Full Month")
        attach(app, "Month after jumping directly into March")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        expectMonth("November")
        XCTAssertTrue(shows("November plan"))
    }

    @MainActor func testAgendaShowMoreRevealsFutureTaskAndTodayResetsWindow() {
        let app = launch(qaCase: "agenda")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Agenda"].tap()
        let future = app.buttons["Read a chapter"]
        XCTAssertFalse(future.exists)
        let showMore = app.buttons["agendaShowMore"]
        reveal(showMore, in: app)
        showMore.tap()
        reveal(future, in: app)
        attach(app, "Agenda with extended schedule")
        app.buttons["Today"].tap()
        waitGone(future)
        reveal(showMore, in: app)
        XCTAssertFalse(future.exists)
    }
    @MainActor func testCalendarThreeDayModePersistsAndPagesThreeDays() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["calendarThreeDay"].tap()
        let headers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDay-"))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 3"), object: headers)], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["calendarDay-2026-11-9"].exists)
        XCTAssertTrue(app.buttons["calendarDay-2026-11-11"].exists)
        attach(app, "Calendar explicit three-day view")
        app.buttons["Next Calendar period"].tap()
        XCTAssertTrue(app.buttons["calendarDay-2026-11-12"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["calendarDay-2026-11-14"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertEqual(headers.count, 3)
        app.buttons["Calendar view"].tap()
        XCTAssertEqual(app.buttons["calendarThreeDay"].value as? String, "Selected")
        app.buttons["Week"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 7"), object: headers)], timeout: 5), .completed)
    }

    @MainActor func testCalendarThreeDayFillsViewportAndDayRemainsUsable() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["calendarThreeDay"].tap()
        let first = app.buttons["calendarDay-2026-11-9"]
        let middle = app.buttons["calendarDay-2026-11-10"]
        let last = app.buttons["calendarDay-2026-11-11"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        let grid = app.scrollViews["calendarHourlyGrid"]
        let pitch = middle.frame.midX - first.frame.midX
        XCTAssertGreaterThan(pitch * 3, grid.frame.width * 0.8)
        XCTAssertEqual(last.frame.midX - middle.frame.midX, pitch, accuracy: 2)
        XCTAssertEqual(last.frame.midX + pitch / 2, grid.frame.maxX, accuracy: 3)
        attach(app, "Three Day fills hourly viewport")
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDay-")).count, 1)
        attach(app, "Day fills hourly viewport")
        app.buttons["Next Calendar period"].tap()
        XCTAssertTrue(middle.waitForExistence(timeout: 5))
        app.buttons["Previous Calendar period"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
    }

    @MainActor func testCalendarWeekOverviewNavigationDoesNotReschedule() {
        let app = launch()
        app.buttons["Calendar"].tap()
        let toggle = app.buttons["calendarWeekOverviewToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let monday = app.buttons["calendarOverviewDay-2026-11-9"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarOverviewDay-")).count, 7)
        attach(app, "Week overview mini-month and day tiles")
        monday.tap()
        XCTAssertTrue(app.buttons["calendarDay-2026-11-9"].waitForExistence(timeout: 5))
        app.buttons["calendarDaySelector-2026-11-10"].tap()
        XCTAssertTrue(app.buttons["calendarDay-2026-11-10"].waitForExistence(timeout: 5))
        app.buttons["calendarWeekOverviewBack"].tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        app.buttons["calendarOverviewMini-2026-11-24"].tap()
        XCTAssertTrue(app.buttons["calendarOverviewDay-2026-11-23"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        app.buttons["Today"].tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.buttons["calendarDay-2026-11-9"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Review the project outline"].exists)
        XCTAssertFalse(app.buttons["calendarWeekOverviewBack"].exists)
    }

    @MainActor func testCalendarWeekOverviewDetailFilterAndRelaunch() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["calendarWeekOverviewToggle"].tap()
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "calendarOverviewEntry-", "Review the project outline")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        let work = app.buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        reveal(work, in: app); work.press(forDuration: 1)
        let onlyWork = app.buttons["Show only Work"]
        reveal(onlyWork, in: app)
        XCTAssertTrue(onlyWork.isHittable)
        onlyWork.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        waitGone(task)
        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        app.buttons["All"].tap()
        app.buttons["calendarPreferencesDone"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        app.buttons["calendarOverviewDay-2026-11-9"].tap()
        XCTAssertTrue(app.buttons["calendarWeekOverviewBack"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["calendarWeekOverviewToggle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["calendarWeekOverviewBack"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDay-")).count, 7)
    }

    @MainActor func testCalendarDayWeekStripSelectsWithoutRescheduling() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let monday = app.buttons["calendarDay-2026-11-9"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertTrue(monday.isSelected)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDaySelector-")).count, 6)
        let sunday = app.buttons["calendarDaySelector-2026-11-15"]
        XCTAssertTrue(sunday.isHittable)
        attach(app, "Day seven-date selector")
        sunday.tap()
        XCTAssertTrue(app.buttons["calendarDay-2026-11-15"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["calendarJumpToDate"].value as? String, "Sunday, 15 November 2026")
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        app.buttons["Next Calendar period"].tap()
        XCTAssertTrue(app.buttons["calendarDay-2026-11-16"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["calendarDaySelector-2026-11-22"].exists)
        app.buttons["Today"].tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Review the project outline"].exists)
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        XCTAssertFalse(app.buttons["calendarDaySelector-2026-11-15"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDay-")).count, 7)
    }

    @MainActor func testCalendarThreeDaySaveFailureKeepsPriorView() {
        let app = launch(qaCase: "save-failure")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["calendarThreeDay"].tap()
        let notice = app.staticTexts["calendarPreferenceNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertTrue(notice.label.contains("Could not switch to 3 Day"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDay-")).count, 7)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendarDay-")).count, 7)
    }

    @MainActor func testCalendarHeaderModeAndOverflowPlacement() {
        let app = launch()
        app.buttons["Calendar"].tap()
        let mode = app.buttons["Calendar view"]
        let month = app.buttons["calendarJumpToDate"]
        let actions = app.buttons["Calendar actions"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertLessThan(mode.frame.maxX, month.frame.minX)
        XCTAssertLessThan(month.frame.maxX, actions.frame.minX)
        XCTAssertFalse(app.buttons["Open navigation"].exists)
        attach(app, "Calendar leading mode and month header")
        mode.tap()
        XCTAssertTrue(app.buttons["Week"].waitForExistence(timeout: 5))
        attach(app, "Calendar mode menu")
        app.buttons["Week"].tap()
        actions.tap()
        let filter = app.buttons["Filter View Range"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertLessThan(filter.frame.minY, app.buttons["View Options"].frame.minY)
        XCTAssertLessThan(app.buttons["View Options"].frame.minY, app.buttons["Arrange Tasks"].frame.minY)
        attach(app, "Calendar overflow filter hierarchy")
        filter.tap()
        XCTAssertTrue(app.buttons["calendarPreferencesCancel"].waitForExistence(timeout: 5))
        app.buttons["calendarPreferencesCancel"].tap()
        app.buttons["Tasks"].tap()
        XCTAssertTrue(app.buttons["Open navigation"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarFilterReset() {
        let app = launch()
        app.buttons["Calendar"].tap()
        let task = app.buttons["Review the project outline"]
        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        let work = app.buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        reveal(work, in: app); work.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarPreferencesCancel"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))

        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        reveal(work, in: app); work.press(forDuration: 1)
        let onlyWork = app.buttons["Show only Work"]
        reveal(onlyWork, in: app); onlyWork.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse(task.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertFalse(task.exists)
        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["All"].tap()
        app.buttons["calendarPreferencesDone"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        attach(app, "Calendar Week after saved All reset")
    }
    @MainActor func testSearchResultsStayReadOnly() {
        let app = launch(); app.buttons["Search"].tap()
        let field = app.textFields["workspaceSearch"]; XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText("project")
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["previewNotice"].exists)
        XCTAssertTrue(app.buttons["openCapture"].isEnabled)
        attach(app, "Search result")
    }

    @MainActor func testSearchExplicitArchiveCriteriaAndSavedFilterRoundTrip() {
        let app = launch(qaCase: "lifecycle")
        app.buttons["Search"].tap()
        let query = app.textFields["workspaceSearch"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("design")
        XCTAssertFalse(app.buttons["Collect design references"].exists)
        app.buttons["clearWorkspaceSearch"].tap()
        query.tap()
        query.typeText("walk")
        XCTAssertTrue(app.buttons["Book time for a walk"].waitForExistence(timeout: 5))
        app.buttons["clearWorkspaceSearch"].tap()
        query.tap()
        query.typeText("studio")
        XCTAssertTrue(app.buttons["Arrange the studio"].waitForExistence(timeout: 5))
        app.buttons["clearWorkspaceSearch"].tap()
        query.tap()
        query.typeText("chapter")
        let result = app.buttons["Read a chapter"]
        XCTAssertFalse(result.exists)
        app.buttons["searchCriteria"].tap()
        XCTAssertTrue(app.buttons["applySearchCriteria"].waitForExistence(timeout: 5))
        app.buttons.containing(.staticText, identifier: "Lists").firstMatch.tap()
        app.buttons["Personal"].tap()
        app.navigationBars["Lists"].buttons.firstMatch.tap()
        app.buttons["cancelSearchCriteria"].tap()
        XCTAssertFalse(result.exists)

        app.buttons["searchCriteria"].tap()
        app.buttons.containing(.staticText, identifier: "Lists").firstMatch.tap()
        app.buttons["Personal"].tap()
        app.navigationBars["Lists"].buttons.firstMatch.tap()
        app.buttons["applySearchCriteria"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        attach(app, "Explicit archived search result")
        result.tap()
        let close = app.buttons["taskDetailDone"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Archived"].exists)
        close.tap()
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertEqual(query.value as? String, "chapter")

        app.buttons["saveSearchAsFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Archived chapter")
        reveal(app.textFields["savedFilterKeyword"], in: app)
        XCTAssertEqual(app.textFields["savedFilterKeyword"].value as? String, "chapter")
        app.buttons["savedFilterDone"].tap()
        XCTAssertTrue(app.staticTexts["searchFilterSaved"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Search"].tap()
        query.tap()
        query.typeText("Archived chapter")
        let saved = app.buttons["Filter Archived chapter"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(result.waitForExistence(timeout: 5))
    }

    @MainActor func testSearchBodyMatchAndCaseInsensitiveHistorySurviveRelaunch() {
        let app = launch()
        app.buttons["Search"].tap()
        let query = app.textFields["workspaceSearch"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        let result = app.buttons["Review the project outline"]
        for term in ["decisions", "DECISIONS"] {
            query.tap()
            query.typeText(term)
            XCTAssertTrue(result.waitForExistence(timeout: 5))
            result.tap()
            let close = app.buttons["taskDetailDone"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            close.tap()
            XCTAssertEqual(query.value as? String, term)
            app.buttons["clearWorkspaceSearch"].tap()
        }
        XCTAssertEqual(app.buttons.matching(identifier: "DECISIONS").count, 1)
        XCTAssertFalse(app.buttons["decisions"].exists)
        app.terminate()
        app.launch()
        app.buttons["Search"].tap()
        XCTAssertTrue(app.buttons["DECISIONS"].waitForExistence(timeout: 5))
        app.buttons["DECISIONS"].tap()
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        app.buttons["clearWorkspaceSearch"].tap()
        app.buttons["clearSearchHistory"].tap()
        XCTAssertFalse(app.buttons["DECISIONS"].exists)
    }

    @MainActor func testSearchChecklistAndOrganizationRoutes() {
        let app = launch(qaCase: "task-metadata")
        app.buttons["Search"].tap()
        let query = app.textFields["workspaceSearch"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("first step")
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        let child = app.buttons["openSubtask-00000000-0000-0000-0000-000000000004"]
        reveal(child, in: app)
        child.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, Arrange the studio")
        let back = app.buttons["relatedTaskBack"]
        back.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, Review the project outline")
        reveal(child, in: app)
        child.tap()
        let parent = app.buttons["openParentTask"]
        reveal(parent, in: app)
        parent.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, Review the project outline")
        XCTAssertFalse(back.exists)
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertEqual(query.value as? String, "first step")
        attach(app, "Checklist search after related task navigation")

        app.buttons["clearWorkspaceSearch"].tap()
        query.tap()
        query.typeText("work")
        let list = app.buttons["List Work"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.tap()
        let weekly = app.buttons["Prepare the weekly plan"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 5))

        app.buttons["Search"].tap()
        app.buttons["clearWorkspaceSearch"].tap()
        query.tap()
        query.typeText("planning")
        let tag = app.buttons["Tag Planning"]
        let filter = app.buttons["Filter Planning"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        XCTAssertTrue(filter.exists)
        attach(app, "Distinct tag and filter search results")
        tag.tap()
        XCTAssertTrue(weekly.waitForExistence(timeout: 5))
        app.buttons["Search"].tap()
        filter.tap()
        XCTAssertTrue(weekly.waitForExistence(timeout: 5))
    }

    @MainActor private func openTitle(_ app: XCUIApplication, task: String = "Review the project outline") -> XCUIElement {
        let row = app.buttons[task]; XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["editTitle"].tap()
        let input = app.textViews["fieldEditor"]; XCTAssertTrue(input.waitForExistence(timeout: 5)); return input
    }
    @MainActor private func waitGone(_ element: XCUIElement) {
        let value = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [value], timeout: 5), .completed)
    }
    @MainActor func testStyledTaskTitleSavesAndSurvivesRelaunch() {
        let app = launch(), original = "Review the project outline"
        let input = openTitle(app)
        input.typeText(" saved locally")
        XCTAssertEqual(input.value as? String, original + " saved locally")
        app.buttons["fieldEditorDone"].tap(); waitGone(input)
        XCTAssertFalse(app.buttons["Edit description"].isEnabled)
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(app.buttons[original + " saved locally"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[original + " saved locally"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Resume saved edit?"].exists)
        attach(app, "Persisted title")
    }
    @MainActor func testDirtyCancelKeepsOrDiscardsWithoutSavingTask() {
        let app = launch(), original = "Review the project outline"
        let input = openTitle(app); input.typeText(" unsaved")
        app.buttons["fieldEditorCancel"].tap(); app.buttons["Keep Editing"].tap()
        XCTAssertEqual(input.value as? String, original + " unsaved")
        app.buttons["fieldEditorCancel"].tap(); app.buttons["Discard"].tap(); waitGone(input)
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Resume saved edit?"].exists)
    }
    @MainActor func testRichDescriptionDraftRecoversAndCommitsTextWithFormatting() {
        let app = launch()
        let title = "Review the project outline"
        app.buttons[title].tap()
        let format = app.buttons["editRichDescription"]
        reveal(format, in: app)
        format.tap()
        let input = app.textViews["richFieldEditor"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = input.value as? String ?? ""
        input.typeText(" Rich update")
        let expected = original + " Rich update"
        XCTAssertEqual(input.value as? String, expected)

        let paragraph = app.buttons["richParagraphMenu"]
        XCTAssertTrue(paragraph.isHittable)
        paragraph.tap()
        app.buttons["Quote"].tap()
        app.buttons["richUndo"].tap()
        XCTAssertEqual(input.value as? String, expected)
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, expected)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Recovery copy saved"),
                                               object: app.staticTexts["draftRecoveryStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.alerts["Resume saved edit?"].waitForExistence(timeout: 10))
        app.buttons["Resume"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, expected)
        attach(app, "Recovered formatted description")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let result = app.textViews["richTaskDescription"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertEqual(result.value as? String, expected)
        attach(app, "Saved formatted description")
    }

    @MainActor func testRichDescriptionFormatsNativeSelectionAndAddsLink() {
        let app = launch()
        app.buttons["Review the project outline"].tap()
        let format = app.buttons["editRichDescription"]
        reveal(format, in: app)
        format.tap()
        let input = app.textViews["richFieldEditor"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = input.value as? String
        let firstWord = input.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 27, dy: 11))
        let inline = app.buttons["richInlineMenu"]
        firstWord.doubleTap()
        XCTAssertTrue(inline.isEnabled)
        XCTAssertTrue(inline.isHittable)
        XCTAssertLessThanOrEqual(inline.frame.maxX, app.frame.maxX - 12)
        inline.tap()
        app.buttons["Italic"].tap()
        firstWord.doubleTap()
        XCTAssertTrue(inline.isEnabled)
        inline.tap()
        app.buttons["Link"].tap()
        let alert = app.alerts["Edit link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let url = alert.textFields.firstMatch
        url.tap()
        url.typeText("https://example.test/project")
        alert.buttons["Apply"].tap()
        XCTAssertEqual(input.value as? String, original)
        attach(app, "Edited inline selection")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        XCTAssertEqual(app.textViews["richTaskDescription"].value as? String, original)
        attach(app, "Saved inline selection")
    }

    @MainActor func testRichDescriptionPlainPasteClearsFormattingFromIdenticalText() {
        let app = launch(qaCase: "rich-plain-paste")
        app.buttons["Review the project outline"].tap()
        let format = app.buttons["editRichDescription"]
        reveal(format, in: app)
        format.tap()
        let input = app.textViews["richFieldEditor"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = input.value as? String
        let firstWord = input.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 27, dy: 11))
        firstWord.doubleTap()
        XCTAssertTrue(app.buttons["richInlineMenu"].isEnabled)
        let plain = app.buttons["richPastePlain"]
        XCTAssertTrue(plain.waitForExistence(timeout: 5))
        XCTAssertTrue(plain.isHittable)
        plain.tap()
        XCTAssertEqual(input.value as? String, original)
        let undo = app.buttons["richUndo"]
        let redo = app.buttons["richRedo"]
        func waitUntilEnabled(_ button: XCUIElement) {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        }
        waitUntilEnabled(undo)
        undo.tap()
        waitUntilEnabled(redo)
        XCTAssertFalse(undo.isEnabled)
        redo.tap()
        waitUntilEnabled(undo)
        XCTAssertFalse(redo.isEnabled)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let description = app.staticTexts["taskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.label, original)
        attach(app, "Saved identical text without formatting")
    }

    @MainActor func testRichDescriptionClipboardPreservesFormattingAcrossDescriptions() {
        let app = launch(qaCase: "rich-preview")
        let format = app.buttons["editRichDescription"]
        let input = app.textViews["richFieldEditor"]
        let source = "Review the project outline"
        let target = "Prepare the weekly plan"
        app.buttons[source].tap()
        reveal(format, in: app)
        format.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let copied = input.value as? String
        input.typeKey("a", modifierFlags: .command)
        input.typeKey("c", modifierFlags: .command)
        app.buttons["fieldEditorCancel"].tap()
        waitGone(input)
        app.buttons["taskDetailDone"].tap()

        XCTAssertTrue(app.buttons[target].waitForExistence(timeout: 5))
        app.buttons[target].tap()
        reveal(format, in: app)
        format.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = input.value as? String
        input.typeKey("a", modifierFlags: .command)
        input.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(input.value as? String, copied)
        app.buttons["richUndo"].tap()
        XCTAssertEqual(input.value as? String, original)
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, copied)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Recovery copy saved"),
                                               object: app.staticTexts["draftRecoveryStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.alerts["Resume saved edit?"].waitForExistence(timeout: 10))
        app.buttons["Resume"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, copied)
        attach(app, "Recovered description with pasted formatting")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, copied)
        attach(app, "Saved pasted description")
    }

    @MainActor func testRichDescriptionRecognizesMarkdownOnlyInOrdinaryPaste() {
        let app = launch(qaCase: "rich-markdown-paste")
        let format = app.buttons["editRichDescription"]
        let input = app.textViews["richFieldEditor"]
        let undo = app.buttons["richUndo"]
        func selectPrior(in task: String) {
            let row = app.buttons[task]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            reveal(format, in: app)
            format.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            XCTAssertEqual(input.value as? String, "Prior")
            let firstWord = input.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: 18, dy: 11))
            firstWord.doubleTap()
            XCTAssertTrue(app.buttons["richInlineMenu"].isEnabled)
        }

        let source = "## Plan **e\u{301} 🧩**\n- First\n1. Open\n2. Review\n> Reference\nhttps://example.test/task *literal*"
        let formatted = "Plan e\u{301} 🧩\nFirst\nOpen\nReview\nReference\nhttps://example.test/task *literal*"
        selectPrior(in: "Review the project outline")
        app.buttons["richPastePlain"].tap()
        XCTAssertEqual(input.value as? String, source)
        undo.tap()
        XCTAssertEqual(input.value as? String, "Prior")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        app.buttons["taskDetailDone"].tap()

        selectPrior(in: "Prepare the weekly plan")
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        XCTAssertEqual(input.value as? String, formatted)
        undo.tap()
        XCTAssertEqual(input.value as? String, "Prior")
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, formatted)

        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, formatted)
        attach(app, "Saved Markdown paste")
    }

    @MainActor func testRichDescriptionImportsHTMLAndKeepsExactPlainAlternative() {
        checkForeignRichPaste(qaCase: "rich-foreign-paste", expected: "Bold 🧩 italic e\u{301}\nReview safe **literal**")
    }

    @MainActor func testRichDescriptionImportsForeignHTMLParagraphs() {
        checkForeignRichPaste(qaCase: "rich-foreign-html-blocks",
                              expected: "Review 🧩\nA quoted e\u{301}\nOne bullet\nFirst number\n  let value = 1\n\n  print(value)\nPlain end")
    }

    @MainActor func testRichDescriptionImportsRTFWithoutPlainAlternative() {
        checkForeignRichPaste(qaCase: "rich-foreign-rtf-paste", expected: "Bold italic")
    }

    @MainActor private func checkForeignRichPaste(qaCase: String, expected: String) {
        let app = launch(qaCase: qaCase)
        let input = app.textViews["richFieldEditor"]
        let format = app.buttons["editRichDescription"]
        let target = "Prepare the weekly plan"

        func selectBody(of title: String) {
            let row = app.buttons[title]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            reveal(format, in: app)
            format.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            XCTAssertEqual(input.value as? String, "Prior")
            input.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: 18, dy: 11)).doubleTap()
            XCTAssertTrue(app.buttons["richInlineMenu"].isEnabled)
        }

        selectBody(of: "Review the project outline")
        app.buttons["richPastePlain"].tap()
        XCTAssertEqual(input.value as? String, expected)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        app.buttons["taskDetailDone"].tap()

        selectBody(of: target)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        XCTAssertEqual(input.value as? String, expected)
        app.buttons["richUndo"].tap()
        XCTAssertEqual(input.value as? String, "Prior")
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, expected)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        attach(app, "Saved foreign rich description")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons[target].tap()
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, expected)
    }

    @MainActor func testRichDescriptionCodeBlockPasteCopyAndRelaunch() {
        let app = launch(qaCase: "rich-code-paste")
        let format = app.buttons["editRichDescription"]
        let input = app.textViews["richFieldEditor"]
        let undo = app.buttons["richUndo"]
        let source = "```\n  let value = **e\u{301} 🧩**\nprint(value)\n```"
        let code = "  let value = **e\u{301} 🧩**\nprint(value)\n"
        let target = "Prepare the weekly plan"
        let other = "Review the project outline"
        func openPrior(_ title: String) {
            let row = app.buttons[title]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            reveal(format, in: app)
            format.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            XCTAssertEqual(input.value as? String, "Prior")
            input.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: 18, dy: 11)).doubleTap()
            XCTAssertTrue(app.buttons["richInlineMenu"].isEnabled)
        }
        openPrior(target)
        app.buttons["richPastePlain"].tap()
        XCTAssertEqual(input.value as? String, source)
        undo.tap()
        XCTAssertEqual(input.value as? String, "Prior")
        input.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 18, dy: 11)).doubleTap()
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        XCTAssertEqual(input.value as? String, code)
        undo.tap()
        XCTAssertEqual(input.value as? String, "Prior")
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, code)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let copy = app.buttons["copyRichCodeBlock-0"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        attach(app, "Saved code block without fences")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons[target].tap()
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        reveal(copy, in: app)
        copy.tap()
        XCTAssertTrue(copy.label.contains("Copied"))
        app.buttons["taskDetailDone"].tap()
        openPrior(other)
        app.buttons["richPastePlain"].tap()
        XCTAssertEqual(input.value as? String, code)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        XCTAssertFalse(copy.exists)
        attach(app, "Exact plain text copied from the code block")
    }

    @MainActor func testRichDescriptionFormatsTypedMarkdownWithUndoAndChecklist() {
        let app = launch()
        app.buttons["Prepare the weekly plan"].tap()
        let format = app.buttons["editRichDescription"]
        reveal(format, in: app)
        format.tap()
        let input = app.textViews["richFieldEditor"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = "A neutral sample description."
        XCTAssertEqual(input.value as? String, original)
        input.typeText("\n##")
        XCTAssertEqual(input.value as? String, original + "\n##")
        input.typeText(" ")
        XCTAssertEqual(input.value as? String, original + "\n")
        input.typeText("Plan **bold**")
        XCTAssertEqual(input.value as? String, original + "\nPlan **bold**")
        input.typeText(" ")
        XCTAssertEqual(input.value as? String, original + "\nPlan bold ")
        app.buttons["richUndo"].tap()
        XCTAssertEqual(input.value as? String, original + "\nPlan **bold**")
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, original + "\nPlan bold ")

        input.typeText("\n-")
        input.typeText(" ")
        input.typeText("[ ]")
        input.typeText(" ")
        input.typeText("Check")
        XCTAssertEqual(input.value as? String, original + "\nPlan bold \nCheck")
        input.typeText("\n\n--")
        XCTAssertEqual(input.value as? String, original + "\nPlan bold \nCheck\n--")
        input.typeText("-")
        let expected = original + "\nPlan bold \nCheck\n\n"
        XCTAssertEqual(input.value as? String, expected)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, expected)
        attach(app, "Saved typed Markdown heading and checklist")
    }

    @MainActor func testSavedRichChecklistContinuesAfterRelaunchAndExits() {
        let app = launch(), title = "Prepare the weekly plan"
        let input = app.textViews["richFieldEditor"]
        let description = app.textViews["richTaskDescription"]
        func openEditor() {
            app.buttons[title].tap()
            let format = app.buttons["editRichDescription"]
            reveal(format, in: app)
            format.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
        }
        openEditor()
        input.typeText("\n- ")
        input.typeText("[x] ")
        input.typeText("First")
        let saved = "A neutral sample description.\nFirst"
        XCTAssertEqual(input.value as? String, saved)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openEditor()
        input.typeText("\n")
        XCTAssertEqual(input.value as? String, saved + "\n\n")
        input.typeText("Second")
        XCTAssertEqual(input.value as? String, saved + "\nSecond")
        input.typeText("\n\nAfter")
        let final = saved + "\nSecond\nAfter"
        XCTAssertEqual(input.value as? String, final)
        app.buttons["richUndo"].tap()
        XCTAssertEqual(input.value as? String, saved + "\nSecond\nAfte")
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, final)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        XCTAssertEqual(description.value as? String, final)
        attach(app, "Saved list continued and exited")
    }

    @MainActor func testRichDescriptionTypesCodeFenceAndResumesProse() {
        let app = launch(), title = "Prepare the weekly plan"
        app.buttons[title].tap()
        let format = app.buttons["editRichDescription"]
        reveal(format, in: app)
        format.tap()
        let input = app.textViews["richFieldEditor"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = "A neutral sample description."
        XCTAssertEqual(input.value as? String, original)
        input.typeText("\n```")
        XCTAssertEqual(input.value as? String, original + "\n```")
        input.typeText("\n")
        XCTAssertEqual(input.value as? String, original + "\n\n")
        app.buttons["richUndo"].tap()
        XCTAssertEqual(input.value as? String, original + "\n```")
        app.buttons["richRedo"].tap()
        XCTAssertEqual(input.value as? String, original + "\n\n")

        let code = "  let x = 1\n# literal\n"
        input.typeText("  let x = 1\n# literal\n```\n")
        XCTAssertEqual(input.value as? String, original + "\n" + code)
        input.typeText("# Plain after")
        let expected = original + "\n" + code + "Plain after"
        XCTAssertEqual(input.value as? String, expected)
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, expected)
        XCTAssertTrue(app.buttons["copyRichCodeBlock-0"].exists)
        attach(app, "Typed code block followed by a heading")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons[title].tap()
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, expected)
        XCTAssertTrue(app.buttons["copyRichCodeBlock-0"].exists)
    }

    @MainActor func testRichChecklistTapsSaveAndCancelOnlyTheirParagraphs() {
        let app = launch(qaCase: "rich-checklist-toggle")
        let task = app.buttons["Review the project outline"]
        let format = app.buttons["editRichDescription"]
        let input = app.textViews["richFieldEditor"]
        let undo = app.buttons["richUndo"]
        let redo = app.buttons["richRedo"]
        let expected = "First 🧩\nSecond e\u{301}\nOrdinary text\nBullet"
        func openEditor() {
            XCTAssertTrue(task.waitForExistence(timeout: 5))
            task.tap()
            reveal(format, in: app)
            format.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            XCTAssertEqual(input.value as? String, expected)
            let keyboardIntro = app.buttons["Continue"]
            if keyboardIntro.exists && keyboardIntro.isHittable { keyboardIntro.tap() }
        }
        func tap(_ x: CGFloat, _ y: CGFloat) {
            input.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
        }

        openEditor()
        tap(75, 10)
        tap(13, 52)
        tap(13, 73)
        XCTAssertFalse(undo.isEnabled)
        // The two nearby text taps can open the system selection menu over the first marker.
        // Tap in the trailing empty space to collapse the selection and keep the keyboard open.
        tap(input.frame.width - 16, 73)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let selectionMenu = app.buttons["Select All"].firstMatch
        if selectionMenu.exists {
            tap(input.frame.width - 16, 31)
            waitGone(selectionMenu)
        }
        tap(13, 10)
        XCTAssertTrue(undo.isEnabled)
        tap(13, 31)
        undo.tap()
        XCTAssertTrue(redo.isEnabled)
        redo.tap()
        XCTAssertEqual(input.value as? String, expected)
        attach(app, "First checked and second unchecked")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openEditor()
        tap(13, 10)
        XCTAssertTrue(undo.isEnabled)
        app.buttons["fieldEditorCancel"].tap()
        app.buttons["Discard"].tap()
        waitGone(input)
        XCTAssertEqual(app.textViews["richTaskDescription"].value as? String, expected)
    }

    @MainActor func testRichHighlightColorsRecolorRemoveCopyAndRelaunch() {
        let app = launch(qaCase: "rich-highlight-colors")
        let source = "Review the project outline", target = "Prepare the weekly plan"
        let format = app.buttons["editRichDescription"]
        let input = app.textViews["richFieldEditor"]
        let inline = app.buttons["richInlineMenu"]
        func edit(_ title: String) {
            let task = app.buttons[title]
            XCTAssertTrue(task.waitForExistence(timeout: 5))
            task.tap()
            reveal(format, in: app)
            format.tap()
            XCTAssertTrue(input.waitForExistence(timeout: 5))
        }
        func chooseColor(_ title: String) {
            XCTAssertTrue(inline.isEnabled)
            inline.tap()
            let palette = app.descendants(matching: .any)["Highlight Colors"].firstMatch
            XCTAssertTrue(palette.waitForExistence(timeout: 5))
            palette.tap()
            let action = app.buttons[title]
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            action.tap()
            waitGone(action)
        }

        edit(source)
        XCTAssertEqual(input.value as? String, "Alpha Beta")
        input.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 22, dy: 11)).doubleTap()
        chooseColor("Blue")
        chooseColor("Pink")
        chooseColor("Remove Highlight")
        app.buttons["richUndo"].tap()
        XCTAssertTrue(app.buttons["richRedo"].isEnabled)
        app.buttons["richRedo"].tap()
        app.buttons["richUndo"].tap()
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, "Alpha Beta")
        attach(app, "Pink and legacy yellow highlights")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        edit(source)
        let sourceWord = input.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 22, dy: 11))
        sourceWord.doubleTap()
        let trailing = input.otherElements["com.apple.text.grabber.trailing"]
        guard trailing.waitForExistence(timeout: 5) else {
            return XCTFail("Expected a selection handle after double tapping the source")
        }
        let originalTrailingX = trailing.frame.minX
        let handle = trailing.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 1, dy: 27))
        let afterText = input.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 108, dy: 27))
        handle.press(forDuration: 0.15, thenDragTo: afterText)
        XCTAssertGreaterThan(trailing.frame.minX, originalTrailingX + 25)
        XCTAssertTrue(inline.isEnabled)
        let copy = app.menuItems["Copy"]
        if !copy.exists {
            sourceWord.tap()
        }
        guard copy.waitForExistence(timeout: 5) else {
            attach(app, "Source copy menu")
            return XCTFail("Expected the native Copy action after selecting the description")
        }
        copy.tap()
        app.buttons["fieldEditorCancel"].tap()
        waitGone(input)
        app.buttons["taskDetailDone"].tap()
        edit(target)
        input.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 22, dy: 11)).doubleTap()
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "Copy must populate the private clipboard")
        paste.tap()
        XCTAssertEqual(input.value as? String, "Alpha Beta")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, "Alpha Beta")
    }

    @MainActor func testPlainDescriptionRecoveryDoesNotAutosubmit() {
        let app = launch(), title = "Prepare the weekly plan"
        app.buttons[title].tap(); app.buttons["Edit description"].tap()
        let input = app.textViews["fieldEditor"]; XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("\nRecovered line")
        let expected = "A neutral sample description.\nRecovered line"
        XCTAssertEqual(input.value as? String, expected)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Recovery copy saved"), object: app.staticTexts["draftRecoveryStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.terminate(); app.launch()
        XCTAssertTrue(app.alerts["Resume saved edit?"].waitForExistence(timeout: 10)); app.buttons["Resume"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5)); XCTAssertEqual(input.value as? String, expected)
        attach(app, "Recovered description")
        app.buttons["fieldEditorDone"].tap(); waitGone(input)
        XCTAssertEqual(app.staticTexts["taskDescription"].label, expected)
        app.buttons["taskDetailDone"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 10)); XCTAssertFalse(app.alerts["Resume saved edit?"].exists)
        app.buttons[title].tap(); XCTAssertEqual(app.staticTexts["taskDescription"].label, expected)
    }
    @MainActor func testSaveFailureRetainsEditorAndDraft() {
        let app = launch(qaCase: "save-failure")
        let input = openTitle(app); input.typeText(" retained")
        app.buttons["fieldEditorDone"].tap()
        XCTAssertTrue(app.staticTexts["Could not save. Your edit is still here. Retry when storage is available."].waitForExistence(timeout: 5))
        XCTAssertTrue(input.exists); XCTAssertTrue((input.value as? String)?.hasSuffix(" retained") == true)
        attach(app, "Failed save retains draft")
        app.buttons["fieldEditorCancel"].tap(); app.buttons["Discard"].tap(); waitGone(input)
        app.buttons["taskDetailDone"].tap(); XCTAssertTrue(app.buttons["Review the project outline"].exists)
    }
    @MainActor func testStaleSaveRetainsTextAndDoesNotOverwriteNewerTask() {
        let app = launch(qaCase: "stale-save")
        let input = openTitle(app); input.typeText(" old draft")
        app.buttons["fieldEditorDone"].tap()
        XCTAssertTrue(app.staticTexts["fieldEditorError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["fieldEditorError"].label.hasPrefix("This task changed."))
        XCTAssertFalse(app.buttons["fieldEditorDone"].isEnabled)
        XCTAssertTrue((input.value as? String)?.hasSuffix(" old draft") == true)
        attach(app, "Stale edit retained")
        app.buttons["fieldEditorCancel"].tap(); app.buttons["Discard"].tap(); waitGone(input)
        app.buttons["taskDetailDone"].tap(); XCTAssertTrue(app.buttons["Changed elsewhere"].waitForExistence(timeout: 5))
    }
    @MainActor func testUnknownDataBlocksPhoneEditing() {
        let app = launch(qaCase: "unknown-workspace")
        XCTAssertFalse(app.buttons["openCapture"].isEnabled)
        app.buttons["Review the project outline"].tap()
        XCTAssertFalse(app.buttons["editTitle"].isEnabled); XCTAssertFalse(app.buttons["Edit description"].isEnabled)
        XCTAssertFalse(app.buttons["editRichDescription"].isEnabled)
        XCTAssertTrue(app.staticTexts["This workspace contains data this build cannot safely rewrite. Viewing remains available."].exists)
        attach(app, "Compatibility read-only")
    }
    @MainActor func testUnknownDraftIsPreservedAndBlocksReplacement() {
        let app = launch(qaCase: "unknown-draft")
        XCTAssertTrue(app.staticTexts["A saved edit uses an unreadable or unsupported format. Its file is kept; editing is blocked."].exists)
        app.buttons["Review the project outline"].tap(); XCTAssertFalse(app.buttons["editTitle"].isEnabled)
    }

    @MainActor func testUnchangedDoneAndViewOnlyNavigationPreserveTaskFile() {
        let app = launch(), original = "Review the project outline"
        let input = openTitle(app)
        app.buttons["fieldEditorDone"].tap(); waitGone(input)
        app.buttons["taskDetailDone"].tap()
        app.buttons["Calendar"].tap(); app.buttons["Search"].tap(); app.buttons["Tasks"].tap()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Resume saved edit?"].exists)
    }
    @MainActor func testRecoveryDiscardDoesNotSubmitDraft() {
        let app = launch(), original = "Review the project outline"
        let input = openTitle(app); input.typeText(" recovered but discarded")
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Recovery copy saved"), object: app.staticTexts["draftRecoveryStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.terminate(); app.launch()
        XCTAssertTrue(app.alerts["Resume saved edit?"].waitForExistence(timeout: 10)); app.buttons["Discard"].tap()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[original].waitForExistence(timeout: 10)); XCTAssertFalse(app.alerts["Resume saved edit?"].exists)
    }
    @MainActor func testInvalidIsolationArgumentsNeverFallBackToLocalWorkspace() {
        let app = XCUIApplication()
        for args in [["--qa-session", "../../invalid"], ["--workspace", "/tmp/invalid-workspace.json"], ["--qa-case=unknown-draft"]] {
            app.launchArguments = args; app.launch()
            XCTAssertTrue(app.staticTexts["The requested test workspace is invalid. No local files were opened."].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["previewNotice"].exists)
            app.terminate()
        }
    }
    @MainActor private func openCapture(_ app: XCUIApplication) -> XCUIElement {
        let add = app.buttons["openCapture"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: add)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 6), .completed); add.tap()
        let more = app.buttons["captureMore"]
        if more.waitForExistence(timeout: 5) { more.tap() }
        let title = app.textViews["captureTitle"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); return title
    }
    @MainActor private func reveal(_ row: XCUIElement, in app: XCUIApplication, towardTop: Bool = false, mustBeVisible: Bool = true) {
        for _ in 0..<6 where !(mustBeVisible ? row.isHittable : row.exists) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: towardTop ? 0.23 : 0.48))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: towardTop ? 0.48 : 0.23)))
        }
        XCTAssertTrue(mustBeVisible ? row.isHittable : row.exists)
    }
    @MainActor private func finishCapture(_ app: XCUIApplication) {
        app.buttons["captureAdd"].tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 8)); app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(app.staticTexts["captureSuccess"].waitForExistence(timeout: 4))
    }
    @MainActor func testCaptureCalendarContextAndDurableTask() {
        let app = launch(); app.buttons["Calendar"].tap(); let title = openCapture(app)
        XCTAssertFalse(app.buttons["captureAdd"].isEnabled)
        title.tap(); title.typeText("Local calendar capture")
        reveal(app.staticTexts["captureResolvedDate"], in: app)
        XCTAssertNotEqual(app.staticTexts["captureResolvedDate"].label, "No date")
        attach(app, "Calendar capture context")
        finishCapture(app)
        XCTAssertTrue(app.buttons["Local calendar capture"].waitForExistence(timeout: 4))
        app.buttons["Calendar view"].tap(); app.buttons["Month"].tap()
        let more = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "more items, open Day")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 4)); more.tap()
        XCTAssertTrue(app.staticTexts["Day"].exists)
        XCTAssertTrue(app.buttons["Local calendar capture"].waitForExistence(timeout: 4))
    }
    @MainActor func testCalendarRangeCaptureStagesAndRecoversBeforeAdding() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let grid = app.descendants(matching: .any)["calendarMonthDays"].firstMatch
        let start = grid.staticTexts["calendarMonthDay-2026-11-11"]
        let end = grid.staticTexts["calendarMonthDay-2026-11-6"]
        let title = app.textViews["captureTitle"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(end.isHittable)
        XCTAssertLessThan(end.frame.minY, start.frame.minY)
        func stage() {
            dragCalendarDateRange(from: start, to: end)
            XCTAssertTrue(title.waitForExistence(timeout: 5))
        }
        stage()
        app.buttons["captureCancel"].tap()
        waitGone(title)
        XCTAssertTrue(start.waitForExistence(timeout: 5) && start.isHittable)
        stage()
        let taskTitle = "Phone range capture tomorrow"
        title.tap()
        title.typeText(taskTitle)
        XCTAssertFalse(app.staticTexts["captureRecoveryStatus"].exists)
        let priority = app.buttons["capturePriorityPicker"]
        reveal(priority, in: app); priority.tap()
        XCTAssertTrue(app.navigationBars["Priority"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        reveal(title, in: app, towardTop: true)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        let prompt = app.alerts["Resume new task?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        prompt.buttons["Later"].tap()
        XCTAssertFalse(app.buttons[taskTitle].exists)
        app.buttons["Resume new task"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, taskTitle)
        let rangeEnd = app.descendants(matching: .any)["captureCalendarRangeEnd"].firstMatch
        reveal(rangeEnd, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["captureCalendarRangeStart"].firstMatch.exists)
        attach(app, "Recovered Calendar range draft")
        finishCapture(app)
        app.buttons["Calendar"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: taskTitle).count, 2)
        attach(app, "Saved Calendar range spans two rows")
        let top = start.frame.minY
        let scroller = app.scrollViews["calendarMonthGrid"]
        // Start above the floating tab bar, within the grid’s touch area.
        let lower = scroller.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.68))
        let upper = scroller.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.32))
        lower.press(forDuration: 0.05, thenDragTo: upper, withVelocity: .fast, thenHoldForDuration: 0)
        let scrolled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !start.exists || start.frame.minY < top - 15
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [scrolled], timeout: 4), .completed)
        XCTAssertFalse(title.exists)
    }

    @MainActor private func dragCalendarDateRange(from start: XCUIElement, to end: XCUIElement) {
        // The Calendar dates expose the full cell as their accessibility frame.
        let from = start.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.72))
        let to = end.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.72))
        from.press(forDuration: 0.55, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    @MainActor func testMultiWeekRangeCaptureCanCancel() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Multi-Week"].tap()
        let start = app.staticTexts["calendarMonthDay-2026-11-11"], end = app.staticTexts["calendarMonthDay-2026-11-17"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(end.isHittable)
        dragCalendarDateRange(from: start, to: end)
        let title = app.textViews["captureTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let rangeEnd = app.descendants(matching: .any)["captureCalendarRangeEnd"].firstMatch
        reveal(rangeEnd, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["captureCalendarRangeStart"].firstMatch.exists)
        attach(app, "Staged Multi-Week range")
        app.buttons["captureCancel"].tap()
        waitGone(title)
        XCTAssertTrue(app.staticTexts["Multi-Week"].exists)
    }

    @MainActor func testCaptureDirtyCancelDoesNotCreate() {
        let app = launch(), title = openCapture(app); title.tap(); title.typeText("Discard this capture")
        app.buttons["captureCancel"].tap(); app.buttons["Keep Editing"].tap()
        XCTAssertEqual(title.value as? String, "Discard this capture")
        app.buttons["captureCancel"].tap(); app.alerts["Discard this capture?"].buttons["Discard"].tap(); waitGone(title)
        XCTAssertFalse(app.buttons["Discard this capture"].exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10)); XCTAssertFalse(app.alerts["Resume new task?"].exists)
    }
    @MainActor func testCaptureRecoveryDoesNotAutosubmitAndSavesOnce() {
        let app = launch(), title = openCapture(app); title.tap(); title.typeText("Recovered capture")
        XCTAssertFalse(app.staticTexts["captureRecoveryStatus"].exists)
        // Exercise a real metadata round trip rather than depending on removed status text.
        // This also gives the existing 250ms scratch debounce time to finish before force quit.
        app.buttons["capturePriorityPicker"].tap()
        XCTAssertTrue(app.navigationBars["Priority"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        reveal(title, in: app, towardTop: true)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.alerts["Resume new task?"].waitForExistence(timeout: 10)); app.alerts["Resume new task?"].buttons["Later"].tap()
        XCTAssertFalse(app.buttons["Recovered capture"].exists)
        app.buttons["Resume new task"].tap(); XCTAssertTrue(title.waitForExistence(timeout: 5)); XCTAssertEqual(title.value as? String, "Recovered capture")
        finishCapture(app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["Recovered capture"].waitForExistence(timeout: 10)); XCTAssertFalse(app.alerts["Resume new task?"].exists)
    }
    @MainActor func testCaptureWriteFailureKeepsEditableDraft() {
        let app = launch(qaCase: "save-failure"), title = openCapture(app); title.tap(); title.typeText("Capture kept on failure")
        app.buttons["captureAdd"].tap()
        XCTAssertTrue(app.staticTexts["captureError"].waitForExistence(timeout: 5)); XCTAssertTrue(app.staticTexts["captureError"].label.hasPrefix("Could not save"))
        XCTAssertTrue(title.exists); XCTAssertEqual(title.value as? String, "Capture kept on failure")
        app.buttons["continueCaptureTyping"].tap(); title.typeText(" edited"); XCTAssertEqual(title.value as? String, "Capture kept on failure edited")
        attach(app, "Capture write failure")
        app.buttons["captureCancel"].tap(); app.alerts["Discard this capture?"].buttons["Discard"].tap(); waitGone(title)
        XCTAssertFalse(app.buttons["Capture kept on failure edited"].exists)
    }
    @MainActor func testCaptureConfirmsAfterWriteThrow() {
        let app = launch(qaCase: "capture-after-write"), title = openCapture(app); title.tap(); title.typeText("Confirmed local capture")
        finishCapture(app)
        XCTAssertTrue(app.buttons["Confirmed local capture"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["Confirmed local capture"].waitForExistence(timeout: 10)); XCTAssertFalse(app.alerts["Resume new task?"].exists)
    }
    @MainActor func testCaptureStyledTemplateProtectsBodyAndInstantiates() {
        let app = launch(qaCase: "capture-template"); _ = openCapture(app)
        let chooser = app.buttons["captureTemplatePicker"]; reveal(chooser, in: app); chooser.tap()
        app.buttons["Styled project"].tap()
        let protectedBody = app.staticTexts["captureProtectedBody"]; reveal(protectedBody, in: app, towardTop: true)
        XCTAssertFalse(app.textViews["captureDescription"].exists)
        XCTAssertTrue(app.textViews["captureRichDescription"].exists)
        attach(app, "Capture protected template")
        app.buttons["captureAdd"].tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Edit description"].isEnabled)
        app.buttons["taskDetailDone"].tap(); XCTAssertTrue(app.staticTexts["captureSuccess"].exists)
    }
    @MainActor func testCaptureNoteWithListPriorityAndExistingTag() {
        let app = launch(), title = openCapture(app)
        app.buttons["Note"].tap(); title.tap(); title.typeText("Local capture note")
        let body = app.textViews["captureDescription"]; reveal(body, in: app); body.tap(); body.typeText("Local note description")
        let list = app.descendants(matching: .any)["captureListPicker"].firstMatch
        reveal(list, in: app, mustBeVisible: false); list.tap(); app.buttons["Personal"].tap()
        if app.navigationBars["List"].exists { app.navigationBars["List"].buttons.firstMatch.tap() }
        let priority = app.descendants(matching: .any)["capturePriorityPicker"].firstMatch
        reveal(priority, in: app); priority.tap(); app.buttons["High"].tap()
        if app.navigationBars["Priority"].exists { app.navigationBars["Priority"].buttons.firstMatch.tap() }
        let tags = app.buttons["captureTagsPicker"]; reveal(tags, in: app); tags.tap()
        let planning = app.buttons["Planning"]; XCTAssertTrue(planning.waitForExistence(timeout: 4)); planning.tap(); XCTAssertEqual(planning.value as? String, "Selected")
        app.navigationBars["Tags"].buttons.firstMatch.tap()
        let noDate = app.buttons["No date"]; reveal(noDate, in: app); noDate.tap()
        attach(app, "Capture note metadata")
        finishCapture(app); XCTAssertEqual(app.staticTexts["captureSuccess"].label, "Note added")
    }
    @MainActor func testCaptureRecognitionShowsRemovableCandidates() {
        let app = launch(), title = openCapture(app); title.tap(); title.typeText("Local capture tomorrow #Planning #Unlisted")
        let ignoreDate = app.buttons["ignoreCaptureDate"]; reveal(ignoreDate, in: app); ignoreDate.tap()
        waitGone(ignoreDate)
        let ignoreTag = app.buttons["Ignore Planning suggestion"]; reveal(ignoreTag, in: app); ignoreTag.tap()
        waitGone(ignoreTag)
        attach(app, "Capture recognition review")
        finishCapture(app)
        XCTAssertTrue(app.buttons["Local capture tomorrow #Planning #Unlisted"].waitForExistence(timeout: 5))
    }
    @MainActor func testCaptureCreatesFirstTaskInEmptyWorkspace() {
        let app = launch(qaCase: "capture-empty")
        XCTAssertTrue(app.staticTexts["No matching tasks"].exists)
        let title = openCapture(app); title.tap(); title.typeText("First local task")
        finishCapture(app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["First local task"].waitForExistence(timeout: 10))
    }
    @MainActor func testCaptureStaleWorkspaceRetainsDraftWithoutCreating() {
        let app = launch(qaCase: "stale-save"), title = openCapture(app); title.tap(); title.typeText("Stale local capture")
        app.buttons["captureAdd"].tap()
        XCTAssertTrue(app.staticTexts["captureError"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["captureError"].label.hasPrefix("The workspace changed")); XCTAssertEqual(title.value as? String, "Stale local capture")
        app.buttons["captureCancel"].tap(); app.alerts["Discard this capture?"].buttons["Discard"].tap(); waitGone(title)
        XCTAssertFalse(app.buttons["Stale local capture"].exists); XCTAssertTrue(app.buttons["Changed elsewhere"].exists)
    }
    @MainActor private func goTo(_ name: String, in app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        let destination = app.buttons[name]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        reveal(destination, in: app)
        destination.tap()
        waitGone(destination)
    }

    @MainActor func testTextBatchCaptureReviewsCancelsAndSavesInWork() {
        let app = launch()
        goTo("Work", in: app)
        func openBatch() -> XCUIElement {
            app.buttons["taskListActions"].tap()
            let open = app.buttons["batchCaptureOpen"]
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            open.tap()
            let input = app.textViews["batchCaptureInput"]
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            return input
        }
        func review(_ text: String) {
            let input = openBatch()
            input.tap()
            input.typeText(text)
            app.buttons["batchCaptureReview"].tap()
            XCTAssertTrue(app.staticTexts["batchCaptureDestination"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["batchCaptureDestination"].label, "Add to Work")
        }

        review("Discard this title\nDiscard this too")
        XCTAssertTrue(app.staticTexts["Discard this title"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["Discard this title"].exists)

        review("Batch first\n\nBatch second")
        let first = app.staticTexts["Batch first"], second = app.staticTexts["Batch second"]
        XCTAssertTrue(first.exists && second.exists)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        let add = app.buttons["batchCaptureCommit"]
        XCTAssertEqual(add.label, "Add 2 Tasks")
        attach(app, "Batch text capture review")
        add.tap()
        let firstTask = app.buttons["Batch first"], secondTask = app.buttons["Batch second"]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 5))
        XCTAssertTrue(secondTask.exists)
        XCTAssertLessThan(firstTask.frame.minY, secondTask.frame.minY)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "Batch first").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "Batch second").count, 1)
        XCTAssertFalse(app.buttons["Discard this title"].exists)
    }

    @MainActor func testManualTaskDragSavesOrderAndRespectsPinAndSortBoundaries() {
        let app = launch(qaCase: "task-sort")
        goTo("Work", in: app)
        let pinned = app.buttons["Write meeting notes"]
        let first = app.buttons["Review the project outline"]
        let moving = app.buttons["Review the draft"]
        let grip = app.images["Drag Review the draft"]
        guard grip.waitForExistence(timeout: 5) else { return XCTFail("Manual Order should show a drag grip.") }
        func drag(to target: XCUIElement, at height: CGFloat) {
            grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.6, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: height)),
                       withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        XCTAssertLessThan(first.frame.minY, moving.frame.minY)
        drag(to: pinned, at: 0.2)
        XCTAssertLessThan(first.frame.minY, moving.frame.minY)
        drag(to: first, at: 0.2)
        XCTAssertLessThan(pinned.frame.minY, moving.frame.minY)
        XCTAssertLessThan(moving.frame.minY, first.frame.minY)
        attach(app, "Manual task order in Work")

        let menu = app.buttons["taskSortMenu"]
        chooseTaskSort("Created · Newest First", in: app)
        XCTAssertFalse(grip.exists)
        chooseTaskSort("Default Order", in: app)
        XCTAssertLessThan(moving.frame.minY, first.frame.minY)

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertLessThan(pinned.frame.minY, moving.frame.minY)
        XCTAssertLessThan(moving.frame.minY, first.frame.minY)
    }

    @MainActor func testManualTaskDragStaysInItsSectionAndStopsDuringGrouping() {
        let app = launch(qaCase: "created-grouping")
        goTo("Work", in: app)
        let moving = app.buttons["Prepare the weekly plan"]
        let target = app.buttons["Review the draft"]
        let otherSection = app.buttons["Review the project outline"]
        let sectionHeader = app.staticTexts["Review section"]
        let grip = app.images["Drag Prepare the weekly plan"]
        guard grip.waitForExistence(timeout: 5) else { return XCTFail("The ordinary section should offer a drag grip.") }

        func drop(on row: XCUIElement, at height: CGFloat) {
            grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.6, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: height)),
                       withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        XCTAssertLessThan(moving.frame.minY, target.frame.minY)
        drop(on: otherSection, at: 0.25)
        XCTAssertLessThan(moving.frame.minY, target.frame.minY)
        XCTAssertTrue(app.staticTexts["No Section"].exists)
        XCTAssertLessThan(moving.frame.minY, sectionHeader.frame.minY)
        XCTAssertLessThan(sectionHeader.frame.minY, otherSection.frame.minY)

        drop(on: target, at: 0.8)
        let ordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in target.frame.minY < moving.frame.minY }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ordered], timeout: 5), .completed)
        XCTAssertLessThan(moving.frame.minY, sectionHeader.frame.minY)
        XCTAssertLessThan(sectionHeader.frame.minY, otherSection.frame.minY)

        let menu = app.buttons["taskSortMenu"]
        chooseTaskSort("Group by Created Date", in: app)
        XCTAssertFalse(grip.exists)
        chooseTaskSort("Group by Created Date", in: app)
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertLessThan(target.frame.minY, moving.frame.minY)
    }

    @MainActor func testOrganizationGroupsAndMetadataSortingComposeAndRestore() {
        let app = launch(qaCase: "organization-sort")
        goTo("Work", in: app)
        chooseTaskSort("Group by Tag", in: app)
        XCTAssertTrue(app.staticTexts["Planning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Tags"].exists)
        chooseTaskSort("Date · Ascending", in: app)
        app.buttons["taskSortMenu"].tap()
        XCTAssertTrue(app.buttons["groupTag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["groupTag"].isSelected)
        XCTAssertTrue(app.buttons["sortDate"].isSelected)
        attach(app, "Group Tag and Sort Date")
        app.buttons["groupList"].tap(); waitGone(app.buttons["groupList"])
        XCTAssertTrue(app.staticTexts["taskGroupHeader-Work"].exists)
        XCTAssertFalse(app.staticTexts["No Tags"].exists)
        chooseTaskSort("No Groups", in: app)
        XCTAssertFalse(app.staticTexts["taskGroupHeader-Work"].exists)
        XCTAssertFalse(app.staticTexts["No Tags"].exists)
        XCTAssertLessThan(app.buttons["Review the project outline"].frame.minY, app.buttons["Review the draft"].frame.minY)
        chooseTaskSort("Date · Descending", in: app)
        XCTAssertLessThan(app.buttons["Review the draft"].frame.minY, app.buttons["Review the project outline"].frame.minY)
        chooseTaskSort("Tag · Ascending", in: app)
        XCTAssertLessThan(app.buttons["Prepare the weekly plan"].frame.minY, app.buttons["Review the project outline"].frame.minY)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        app.buttons["taskSortMenu"].tap()
        XCTAssertTrue(app.buttons["groupNone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["groupNone"].isSelected)
        XCTAssertTrue(app.buttons["sortTag"].isSelected)
        attach(app, "All Group and Sort choices")
        app.buttons["restoreDefaultTaskSort"].tap(); waitGone(app.buttons["restoreDefaultTaskSort"])
        app.buttons["taskSortMenu"].tap()
        XCTAssertTrue(app.buttons["groupNone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["groupNone"].isSelected)
        app.buttons["groupDefault"].tap(); waitGone(app.buttons["groupDefault"])
        XCTAssertTrue(app.buttons["Review the project outline"].exists)
    }

    @MainActor func testPriorityListGroupingKeepsPinSortAndSurvivesRelaunch() {
        let app = launch(qaCase: "priority-list")
        goTo("Work", in: app)
        chooseTaskSort("Group by Priority", in: app)
        XCTAssertTrue(app.staticTexts["High Priority"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Low Priority"].exists)
        let pinned = app.buttons["Write meeting notes"]
        XCTAssertLessThan(pinned.frame.minY, app.staticTexts["High Priority"].frame.minY)
        chooseTaskSort("Title · Ascending", in: app)
        XCTAssertLessThan(app.buttons["Review the draft"].frame.minY, app.buttons["Review the project outline"].frame.minY)
        attach(app, "Priority grouped list")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertTrue(app.staticTexts["High Priority"].waitForExistence(timeout: 5))
        XCTAssertLessThan(pinned.frame.minY, app.staticTexts["High Priority"].frame.minY)
        app.buttons["taskSortMenu"].tap()
        XCTAssertTrue(app.buttons["groupPriority"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["groupPriority"].isSelected)
        XCTAssertTrue(app.buttons["sortTitle"].isSelected)
        attach(app, "Priority grouping and Title sorting")
        app.buttons["restoreDefaultTaskSort"].tap()
        waitGone(app.buttons["restoreDefaultTaskSort"])
        XCTAssertTrue(app.staticTexts["High Priority"].exists)
        chooseTaskSort("Group by Priority", in: app)
        XCTAssertFalse(app.staticTexts["High Priority"].exists)
        XCTAssertTrue(app.buttons["Review the project outline"].exists)
    }

    @MainActor func testTitleSortRetainsPinningDirectionAndDefaultOrderAfterRelaunch() {
        let app = launch(qaCase: "task-sort")
        goTo("Work", in: app)
        func expect(_ titles: [String]) {
            let rows = (["Write meeting notes"] + titles).map { app.buttons[$0] }
            for row in rows { XCTAssertTrue(row.exists) }
            let positions = rows.map { $0.frame.minY }
            XCTAssertEqual(positions, positions.sorted())
            XCTAssertEqual(Set(positions).count, positions.count)
        }
        chooseTaskSort("Title · Ascending", in: app)
        expect(["Prepare the weekly plan", "Review the draft", "Review the project outline"])
        app.buttons["taskSortMenu"].tap()
        XCTAssertTrue(app.buttons["sortTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sortTitle"].isSelected)
        XCTAssertTrue(app.buttons["sortDirection"].label.contains("Ascending"))
        attach(app, "Title sorting choice")
        app.buttons["sortDirection"].tap()
        waitGone(app.buttons["sortDirection"])
        expect(["Review the project outline", "Review the draft", "Prepare the weekly plan"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        expect(["Review the project outline", "Review the draft", "Prepare the weekly plan"])
        chooseTaskSort("Default Order", in: app)
        expect(["Review the project outline", "Prepare the weekly plan", "Review the draft"])
    }

    @MainActor func testTaskTimestampSortOrdersWorkRowsAndSurvivesRelaunch() {
        let app = launch(qaCase: "task-sort")
        goTo("Work", in: app)
        let menu = app.buttons["taskSortMenu"]
        let old = "Review the project outline", newest = "Prepare the weekly plan", middle = "Review the draft"
        func choose(_ sort: String) {
            chooseTaskSort(sort, in: app)
        }
        func expect(_ titles: [String]) {
            let rows = (["Write meeting notes"] + titles).map { app.buttons[$0] }
            for row in rows { XCTAssertTrue(row.exists, row.debugDescription) }
            let y = rows.map { $0.frame.minY }
            XCTAssertEqual(y, y.sorted())
            XCTAssertEqual(Set(y).count, y.count)
        }
        expect([old, newest, middle])
        choose("Created · Newest First")
        expect([newest, middle, old])
        choose("Created · Oldest First")
        expect([old, middle, newest])
        choose("Modified · Newest First")
        expect([old, middle, newest])
        choose("Modified · Oldest First")
        expect([newest, middle, old])
        attach(app, "Work sorted by oldest modification")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        expect([newest, middle, old])
    }

    @MainActor func testTaskDueDateGroupingWorksWithPriorityAndSurvivesRelaunch() {
        let app = launch(qaCase: "due-date-grouping")
        goTo("Work", in: app)
        let section = app.staticTexts["Review section"]
        let menu = app.buttons["taskSortMenu"]
        let today = app.staticTexts["Today"]
        let pinned = app.buttons["Write meeting notes"]
        let firstLow = app.buttons["Review the project outline"]
        let high = app.buttons["Prepare the weekly plan"]
        let secondLow = app.buttons["Review the draft"]
        let tomorrow = app.staticTexts["Tomorrow"]
        let allDay = app.buttons["Arrange the studio"]
        var display = Calendar(identifier: .gregorian)
        display.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let dateFormat = Date.FormatStyle(calendar: display, timeZone: display.timeZone).month(.abbreviated).day()
        let todayCaption = display.date(from: DateComponents(year: 2026, month: 11, day: 9))!.formatted(dateFormat)
        let tomorrowCaption = display.date(from: DateComponents(year: 2026, month: 11, day: 10))!.formatted(dateFormat)
        func choose(_ label: String) {
            chooseTaskSort(label, in: app)
        }
        func expectOrder(_ elements: [XCUIElement]) {
            for element in elements { XCTAssertTrue(element.exists, element.debugDescription) }
            let y = elements.map { $0.frame.minY }
            XCTAssertEqual(y, y.sorted())
            XCTAssertEqual(Set(y).count, y.count)
        }

        XCTAssertTrue(section.exists)
        choose("Group by Due Date")
        XCTAssertFalse(section.exists)
        expectOrder([pinned, today, firstLow, high, secondLow])
        expectOrder([today, high, tomorrow, allDay])
        XCTAssertEqual(high.value as? String, todayCaption)
        XCTAssertEqual(allDay.value as? String, tomorrowCaption)
        choose("Priority")
        expectOrder([pinned, today, high, firstLow, secondLow])
        attach(app, "Work grouped by due date and sorted by priority")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertEqual(menu.value as? String, "Priority")
        expectOrder([pinned, today, high, firstLow, secondLow])
        XCTAssertEqual(high.value as? String, todayCaption)
        XCTAssertEqual(allDay.value as? String, tomorrowCaption)
        choose("Group by Created Date")
        XCTAssertFalse(today.exists)
        XCTAssertFalse(section.exists)
        choose("Group by Created Date")
        XCTAssertTrue(section.exists)
        XCTAssertEqual(menu.value as? String, "Priority")
    }

    @MainActor func testTaskCreatedDateGroupingRestoresSectionsAndSurvivesRelaunch() {
        let app = launch(qaCase: "created-grouping")
        goTo("Work", in: app)
        let section = app.staticTexts["Review section"]
        let menu = app.buttons["taskSortMenu"]
        let groupChoice = "Group by Created Date"
        let pinned = app.buttons["Write meeting notes"]
        let earlier = app.buttons["Review the project outline"]
        let newest = app.buttons["Prepare the weekly plan"]
        let middle = app.buttons["Review the draft"]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
        let earlierDay = app.staticTexts[calendar.date(from: DateComponents(year: 2026, month: 11, day: 7))!.formatted(format)]
        let laterDay = app.staticTexts[calendar.date(from: DateComponents(year: 2026, month: 11, day: 8))!.formatted(format)]

        func choose(_ label: String) {
            chooseTaskSort(label, in: app)
        }
        func expectOrder(_ elements: [XCUIElement]) {
            for element in elements { XCTAssertTrue(element.exists, element.debugDescription) }
            let positions = elements.map { $0.frame.minY }
            XCTAssertEqual(positions, positions.sorted())
            XCTAssertEqual(Set(positions).count, positions.count)
        }

        XCTAssertTrue(section.exists)
        choose(groupChoice)
        XCTAssertFalse(section.exists)
        expectOrder([pinned, laterDay, newest, middle, earlierDay, earlier])
        choose("Created · Oldest First")
        expectOrder([pinned, earlierDay, earlier, laterDay, middle, newest])
        attach(app, "Work grouped by creation day in oldest-first order")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        expectOrder([pinned, earlierDay, earlier, laterDay, middle, newest])
        choose(groupChoice)
        XCTAssertTrue(section.exists)
        XCTAssertFalse(earlierDay.exists)
        XCTAssertEqual(menu.value as? String, "Created · Oldest First")
        choose(groupChoice)
        expectOrder([pinned, earlierDay, earlier, laterDay, middle, newest])
    }

    @MainActor private func chooseTaskSort(_ choice: String, in app: XCUIApplication) {
        let menu = app.buttons["taskSortMenu"]
        menu.tap()
        let id: String
        switch choice {
        case "Group by Created Date": id = "groupCreated"
        case "Group by Due Date": id = "groupDate"
        case "Group by Priority": id = "groupPriority"
        case "Group by List": id = "groupList"
        case "Group by Tag": id = "groupTag"
        case "No Groups": id = "groupNone"
        case "Date · Ascending", "Date · Descending": id = "sortDate"
        case "Tag · Ascending", "Tag · Descending": id = "sortTag"
        case "Default Order": id = "restoreDefaultTaskSort"
        case "Priority": id = "sortPriority"
        case "Title · Ascending", "Title · Descending": id = "sortTitle"
        default: id = choice.hasPrefix("Created") ? "sortCreated" : "sortModified"
        }
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        if id.hasPrefix("group") && button.isSelected { app.buttons["groupDefault"].tap() }
        else { button.tap() }
        waitGone(app.buttons[id])
        if choice.contains(" · "), menu.value as? String != choice {
            menu.tap()
            let direction = app.buttons["sortDirection"]
            XCTAssertTrue(direction.waitForExistence(timeout: 5))
            direction.tap()
            waitGone(direction)
        }
    }

    @MainActor func testSortGroupSheetDismissalAndLargeText() {
        let app = launch(qaCase: "task-sort")
        func openSheet() {
            app.buttons["taskListActions"].tap()
            app.buttons["taskGroupAndSort"].tap()
            XCTAssertTrue(app.buttons["sortCreated"].waitForExistence(timeout: 5))
        }
        openSheet()
        attach(app, "Sort Group supported pills light theme")
        let sheet = app.scrollViews["taskSortGroupSheet"]
        XCTAssertTrue(sheet.exists)
        sheet.swipeDown()
        waitGone(app.buttons["sortCreated"])
        openSheet()
        XCTAssertTrue(app.buttons["groupDefault"].isSelected)
        sheet.swipeDown()
        waitGone(app.buttons["sortCreated"])
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openSheet()
        XCTAssertTrue(app.buttons["groupDefault"].isHittable)
        let priority = app.buttons["sortPriority"]
        for _ in 0..<5 where !priority.isHittable { sheet.swipeUp() }
        XCTAssertTrue(priority.isHittable)
        XCTAssertGreaterThanOrEqual(priority.frame.height, 44)
        attach(app, "Sort Group largest text scrollable options")
        priority.tap()
        waitGone(priority)
        openSheet()
        let restore = app.buttons["restoreDefaultTaskSort"]
        for _ in 0..<5 where !restore.isHittable || restore.frame.maxY > app.frame.maxY - 30 { sheet.swipeUp() }
        XCTAssertTrue(restore.isHittable)
        XCTAssertLessThanOrEqual(restore.frame.maxY, app.frame.maxY - 30)
        attach(app, "Sort Group largest text reachable restore")
        restore.tap()
        waitGone(restore)
    }

    @MainActor func testTodaySortGroupSheetIndependentChoices() {
        let app = launch(qaCase: "task-sort")
        func openSheet() {
            app.buttons["taskListActions"].tap()
            app.buttons["taskGroupAndSort"].tap()
            XCTAssertTrue(app.buttons["sortCreated"].waitForExistence(timeout: 5))
        }
        openSheet()
        XCTAssertTrue(app.buttons["groupDefault"].isSelected)
        XCTAssertTrue(app.buttons["sortTag"].exists)
        attach(app, "Supported Sort and Group sheet")
        app.buttons["groupCreated"].tap()
        waitGone(app.buttons["groupCreated"])
        openSheet()
        XCTAssertTrue(app.buttons["groupCreated"].isSelected)
        app.buttons["sortCreated"].tap()
        waitGone(app.buttons["sortCreated"])
        openSheet()
        XCTAssertTrue(app.buttons["groupCreated"].isSelected)
        XCTAssertTrue(app.buttons["sortCreated"].isSelected)
        app.buttons["sortDirection"].tap()
        waitGone(app.buttons["sortDirection"])
        openSheet()
        XCTAssertTrue(app.buttons["groupCreated"].isSelected)
        XCTAssertTrue(app.buttons["sortCreated"].isSelected)
        XCTAssertTrue(app.buttons["sortDirection"].label.contains("Ascending"))
        app.buttons["restoreDefaultTaskSort"].tap()
        waitGone(app.buttons["restoreDefaultTaskSort"])
        openSheet()
        XCTAssertTrue(app.buttons["groupCreated"].isSelected)
        XCTAssertFalse(app.buttons["sortCreated"].isSelected)
        XCTAssertFalse(app.buttons["restoreDefaultTaskSort"].isEnabled)
        attach(app, "Sort reset retains grouping")
    }

    @MainActor private func chooseLifecycleAction(_ name: String, in app: XCUIApplication) {
        app.buttons["taskActions"].tap()
        let action = app.buttons[name]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
    }

    @MainActor func testCustomizeTaskActionsAndKeepLayoutAcrossRelaunch() {
        let app = launch()
        let task = app.buttons["Review the project outline"]
        let done = app.buttons["taskActionsDone"]
        let more = app.buttons["taskActionsMore"]
        let edit = app.buttons["editTaskActionLayout"]
        let save = app.buttons["taskActionLayoutDone"]
        let duplicate = app.buttons["Duplicate"]
        let complete = app.buttons["Complete"]
        let move = app.buttons["Move to List"]
        func openActions() {
            XCTAssertTrue(task.waitForExistence(timeout: 8))
            task.tap()
            app.buttons["taskActions"].tap()
            XCTAssertTrue(done.waitForExistence(timeout: 5))
        }
        func openMore() {
            reveal(more, in: app)
            more.tap()
            XCTAssertTrue(edit.waitForExistence(timeout: 5))
        }
        func openEditor() {
            reveal(edit, in: app)
            edit.tap()
            XCTAssertTrue(save.waitForExistence(timeout: 5))
        }
        func returnToActions() {
            app.navigationBars["More"].buttons.firstMatch.tap()
            XCTAssertTrue(done.waitForExistence(timeout: 5))
        }
        func assertCustomized() {
            XCTAssertTrue(move.waitForExistence(timeout: 5))
            XCTAssertLessThan(move.frame.minY, complete.frame.minY)
            XCTAssertFalse(duplicate.exists)
        }
        openActions()
        XCTAssertTrue(duplicate.exists)
        openMore()
        openEditor()
        app.buttons["Unpin Duplicate"].tap()
        let target = app.staticTexts["taskActionLayoutRow-complete"]
        reveal(target, in: app, towardTop: true)
        let grip = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", "Reorder", "Move to List")).firstMatch
        guard grip.waitForExistence(timeout: 5) else {
            attach(app, "Task action reorder controls")
            return XCTFail("The native reorder grip is unavailable.")
        }
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.3,
            thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.1)))
        save.tap()
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5))
        returnToActions()
        assertCustomized()
        attach(app, "Customized Task Actions")
        app.terminate(); app.launch()
        openActions()
        assertCustomized()
        openMore()
        XCTAssertTrue(duplicate.exists)
        openEditor()
        let pinDuplicate = app.buttons["Pin Duplicate"]
        reveal(pinDuplicate, in: app)
        pinDuplicate.tap()
        let unpinDuplicate = app.buttons["Unpin Duplicate"]
        reveal(unpinDuplicate, in: app, towardTop: true)
        XCTAssertTrue(unpinDuplicate.exists)
        let defaults = app.buttons["Restore Defaults"]
        reveal(defaults, in: app)
        defaults.tap()
        app.buttons["taskActionLayoutCancel"].tap()
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5))
        openEditor()
        reveal(defaults, in: app)
        defaults.tap()
        save.tap()
        waitGone(save)
        returnToActions()
        XCTAssertTrue(duplicate.exists)
        XCTAssertLessThan(complete.frame.minY, move.frame.minY)
    }

    @MainActor private func expectLifecycleNotice(_ value: String, in app: XCUIApplication) {
        let notice = app.staticTexts["lifecycleFeedback"]
        let predicate = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", value), object: notice)
        XCTAssertEqual(XCTWaiter.wait(for: [predicate], timeout: 6), .completed)
    }

    @MainActor func testDuplicateTaskOpensTheIndependentStyledCopy() {
        let app = launch(qaCase: "task-metadata")
        let root = app.buttons["Review the project outline"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        root.tap()
        app.buttons["taskActions"].tap()
        let more = app.buttons["taskActionsMore"]
        reveal(more, in: app)
        more.tap()
        app.buttons["editTaskActionLayout"].tap()
        let unpin = app.buttons["Unpin Duplicate"]
        reveal(unpin, in: app)
        unpin.tap()
        app.buttons["taskActionLayoutDone"].tap()
        let duplicate = app.buttons["Duplicate"]
        reveal(duplicate, in: app)
        duplicate.tap()
        waitGone(app.buttons["taskActionsDone"])
        let previous = app.buttons["relatedTaskBack"]
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, Review the project outline")
        XCTAssertTrue(app.textViews["richTaskDescription"].exists)
        let originalChild = app.buttons["openSubtask-00000000-0000-0000-0000-000000000004"]
        let copiedChild = app.buttons["Open subtask Arrange the studio"]
        reveal(copiedChild, in: app)
        XCTAssertFalse(originalChild.exists)
        attach(app, "Duplicated task with an independent subtask")
        previous.tap()
        reveal(originalChild, in: app)
        XCTAssertFalse(previous.exists)
    }

    @MainActor func testConvertTaskToNoteAndBackAfterRelaunch() {
        let app = launch(qaCase: "task-metadata")
        let root = app.buttons["Review the project outline"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        root.tap()
        app.buttons["taskActions"].tap()
        let toNote = app.buttons["Convert to Note"]
        reveal(toNote, in: app)
        toNote.tap()
        waitGone(app.buttons["taskActionsDone"])
        expectLifecycleNotice("Converted to note", in: app)
        XCTAssertFalse(app.buttons["editSchedule"].exists)
        XCTAssertTrue(app.textViews["richTaskDescription"].exists)
        attach(app, "Converted note keeps its rich description")

        app.terminate()
        app.launch()
        XCTAssertTrue(root.waitForExistence(timeout: 10))
        root.tap()
        XCTAssertFalse(app.buttons["editSchedule"].exists)
        app.buttons["taskActions"].tap()
        let toTask = app.buttons["Convert to Task"]
        reveal(toTask, in: app)
        toTask.tap()
        waitGone(app.buttons["taskActionsDone"])
        expectLifecycleNotice("Converted to task", in: app)
        XCTAssertTrue(app.buttons["editSchedule"].exists)
        let child = app.buttons["openSubtask-00000000-0000-0000-0000-000000000004"]
        reveal(child, in: app)
        XCTAssertTrue(app.buttons["editTaskChecklist"].isEnabled)
    }

    /// D02 detail actions (native slot): supported icon strip and real Tags,
    /// Add Subtask and Link Parent Task routes with Cancel back-transitions.
    /// Deferred Share/external rows must have no placeholder.
    @MainActor func testDetailActionsStripAndSupportedRoutes() {
        let app = launch()
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskActionTile-pin"].exists)
        XCTAssertTrue(app.buttons["taskActionTile-wontDo"].exists)
        XCTAssertTrue(app.buttons["taskActionTile-trash"].exists)
        XCTAssertFalse(app.buttons["Share"].exists)
        for identifier in ["taskActionRow-addSubtask", "taskActionRow-linkParent", "taskActionRow-tags"] {
            let row = app.buttons[identifier]
            reveal(row, in: app)
            XCTAssertTrue(row.exists)
        }
        let tags = app.buttons["taskActionRow-tags"]
        reveal(tags, in: app)
        tags.tap()
        XCTAssertTrue(app.buttons["taskMetadataCancel"].waitForExistence(timeout: 5))
        app.buttons["taskMetadataCancel"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let add = app.buttons["taskActionRow-addSubtask"]
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(app.buttons["taskHierarchyCancel"].waitForExistence(timeout: 5))
        app.buttons["taskHierarchyCancel"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let link = app.buttons["taskActionRow-linkParent"]
        reveal(link, in: app)
        link.tap()
        XCTAssertTrue(app.buttons["taskHierarchyCancel"].waitForExistence(timeout: 5))
        app.buttons["taskHierarchyCancel"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let more = app.buttons["taskActionsMore"]
        reveal(more, in: app)
        more.tap()
        app.buttons["editTaskActionLayout"].tap()
        XCTAssertTrue(app.buttons["taskActionLayoutDone"].waitForExistence(timeout: 5))
        for identifier in ["taskActionLayoutRow-addSubtask", "taskActionLayoutRow-linkParent", "taskActionLayoutRow-tags"] {
            let row = app.staticTexts[identifier]
            reveal(row, in: app)
            XCTAssertTrue(row.exists)
        }
        app.buttons["taskActionLayoutCancel"].tap()
        waitGone(app.buttons["taskActionLayoutDone"])
        // Back on Task Actions before counting: the More screen sits above
        // the actions list, so label queries must run on this screen.
        app.navigationBars["More"].buttons.firstMatch.tap()
        waitGone(app.navigationBars["More"])
        // Each strip action appears exactly once: no duplicated default rows.
        for label in ["Pin", "Won't Do", "Move to Trash"] {
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", label)).count, 1, label)
        }
    }

    /// D02 Tags route (native slot): saving from Task Actions persists and
    /// reopens selected, and survives relaunch.
    @MainActor func testDetailActionsTagsSaveAndReopen() {
        let app = launch(qaCase: "task-metadata"), task = "Review the project outline"
        let tag = "taskTag-00000000-0000-0000-0000-000000000200"
        app.buttons[task].tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let tags = app.buttons["taskActionRow-tags"]
        reveal(tags, in: app)
        tags.tap()
        XCTAssertTrue(app.buttons["taskMetadataCancel"].waitForExistence(timeout: 5))
        let search = app.textFields["searchTaskTags"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Plan")
        let option = app.buttons[tag]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertEqual(option.value as? String, "Selected")
        app.buttons["taskMetadataDone"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        app.buttons["taskActionsDone"].tap()
        XCTAssertEqual(app.buttons["editTaskTags"].value as? String, "Planning, 1 unavailable")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[task].waitForExistence(timeout: 10))
        app.buttons[task].tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let reopened = app.buttons["taskActionRow-tags"]
        reveal(reopened, in: app)
        reopened.tap()
        let saved = app.buttons[tag]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertEqual(saved.value as? String, "Selected")
        attach(app, "Tags saved from Task Actions")
    }

    /// D02 Add Subtask route (native slot): saving from Task Actions returns
    /// to Task Actions, then to detail with the linked child, and persists.
    @MainActor func testDetailActionsAddSubtaskSavesAndReturns() {
        let app = launch(qaCase: "task-metadata"), root = "Review the project outline"
        let child = "Pack the samples"
        app.buttons[root].tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let add = app.buttons["taskActionRow-addSubtask"]
        reveal(add, in: app)
        add.tap()
        let title = app.textViews["newSubtaskTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(child)
        app.buttons["taskHierarchyDone"].tap()
        waitGone(app.buttons["taskHierarchyDone"])
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        app.buttons["taskActionsDone"].tap()
        let open = app.buttons["Open subtask " + child]
        reveal(open, in: app)
        XCTAssertTrue(open.exists)
        open.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, " + child)
        let parent = app.buttons["openParentTask"]
        reveal(parent, in: app)
        XCTAssertEqual(parent.label, "Subtask of " + root)
        parent.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, " + root)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[root].waitForExistence(timeout: 10))
        app.buttons[root].tap()
        reveal(app.buttons["Open subtask " + child], in: app)
        XCTAssertTrue(app.buttons["Open subtask " + child].exists)
        attach(app, "Subtask added from Task Actions")
    }

    /// D02 customization regression (native slot): unpinning an action hides
    /// the strip without reordering or migrating the saved layout; the change
    /// survives relaunch and Restore Defaults brings the strip back.
    @MainActor func testDetailActionsCustomLayoutHidesStripAndRestoresDefaults() {
        let app = launch()
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.tap()
        func openActions() {
            app.buttons["taskActions"].tap()
            XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        }
        func backToActions() {
            app.navigationBars["More"].buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        }
        openActions()
        XCTAssertTrue(app.buttons["taskActionTile-pin"].exists)
        let more = app.buttons["taskActionsMore"]
        reveal(more, in: app)
        more.tap()
        app.buttons["editTaskActionLayout"].tap()
        XCTAssertTrue(app.buttons["taskActionLayoutDone"].waitForExistence(timeout: 5))
        let unpin = app.buttons["Unpin Won't Do"]
        reveal(unpin, in: app, towardTop: true)
        unpin.tap()
        app.buttons["taskActionLayoutDone"].tap()
        waitGone(app.buttons["taskActionLayoutDone"])
        XCTAssertTrue(app.buttons["Won't Do"].waitForExistence(timeout: 5))
        backToActions()
        // Saved custom layout: no strip, exact rows, nothing duplicated.
        XCTAssertFalse(app.buttons["taskActionTile-pin"].exists)
        XCTAssertFalse(app.buttons["taskActionTile-wontDo"].exists)
        XCTAssertFalse(app.buttons["taskActionTile-trash"].exists)
        XCTAssertTrue(app.buttons["Complete"].exists)
        XCTAssertFalse(app.buttons["Won't Do"].exists)
        attach(app, "Custom Task Actions without the icon strip")
        app.terminate()
        app.launch()
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        task.tap()
        openActions()
        XCTAssertFalse(app.buttons["taskActionTile-pin"].exists)
        let reopened = app.buttons["taskActionsMore"]
        reveal(reopened, in: app)
        reopened.tap()
        XCTAssertTrue(app.buttons["Won't Do"].waitForExistence(timeout: 5))
        backToActions()
        app.buttons["taskActionsDone"].tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        let restore = app.buttons["taskActionsMore"]
        reveal(restore, in: app)
        restore.tap()
        app.buttons["editTaskActionLayout"].tap()
        XCTAssertTrue(app.buttons["taskActionLayoutDone"].waitForExistence(timeout: 5))
        let defaults = app.buttons["Restore Defaults"]
        reveal(defaults, in: app)
        defaults.tap()
        app.buttons["taskActionLayoutDone"].tap()
        waitGone(app.buttons["taskActionLayoutDone"])
        backToActions()
        XCTAssertTrue(app.buttons["taskActionTile-pin"].exists)
        XCTAssertTrue(app.buttons["taskActionTile-wontDo"].exists)
        XCTAssertTrue(app.buttons["taskActionTile-trash"].exists)
    }

    /// D02 locked records (native slot): trashed tasks show Restore and
    /// Delete Forever with no strip and no Tags/Add Subtask/Link Parent rows.
    @MainActor func testDetailActionsLockedTrashHasNoStripOrRoutes() {
        let app = launch(qaCase: "organization")
        goTo("Trash", in: app)
        let task = app.buttons["Review the draft"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskActionTile-pin"].exists)
        XCTAssertFalse(app.buttons["taskActionTile-wontDo"].exists)
        XCTAssertFalse(app.buttons["taskActionTile-trash"].exists)
        XCTAssertFalse(app.buttons["taskActionRow-tags"].exists)
        XCTAssertFalse(app.buttons["taskActionRow-addSubtask"].exists)
        XCTAssertFalse(app.buttons["taskActionRow-linkParent"].exists)
        XCTAssertFalse(app.buttons["taskActionsMore"].exists)
        XCTAssertTrue(app.buttons["Restore"].exists)
        XCTAssertTrue(app.buttons["Delete Forever"].exists)
    }

    /// D02 legacy layout (native slot): a persisted pre-D02 custom layout
    /// keeps its exact pinned order with no strip, gains the new Tags, Add
    /// Subtask and Link Parent Task routes in More, and keeps its stored
    /// bytes through an untouched Edit save.
    @MainActor func testDetailActionsLegacyLayoutGainsNewRoutesInMore() {
        let app = launch(qaCase: "legacy-actions")
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.tap()
        app.buttons["taskActions"].tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskActionTile-pin"].exists)
        XCTAssertFalse(app.buttons["taskActionTile-wontDo"].exists)
        XCTAssertFalse(app.buttons["taskActionTile-trash"].exists)
        XCTAssertTrue(app.buttons["Complete"].exists)
        XCTAssertFalse(app.buttons["taskActionRow-tags"].exists)
        let more = app.buttons["taskActionsMore"]
        reveal(more, in: app)
        more.tap()
        for identifier in ["taskActionRow-tags", "taskActionRow-addSubtask", "taskActionRow-linkParent"] {
            let row = app.buttons[identifier]
            reveal(row, in: app)
            XCTAssertTrue(row.exists)
        }
        let edit = app.buttons["editTaskActionLayout"]
        reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.buttons["taskActionLayoutDone"].waitForExistence(timeout: 5))
        app.buttons["taskActionLayoutDone"].tap()
        waitGone(app.buttons["taskActionLayoutDone"])
        app.navigationBars["More"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["taskActionsDone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskActionTile-pin"].exists)
        XCTAssertFalse(app.buttons["taskActionRow-tags"].exists)
        attach(app, "Legacy Task Actions gain new routes in More")
    }

    @MainActor func testLifecycleCompletesRecurringTreeAndUndoFromRow() {
        let app = launch(qaCase: "lifecycle")
        let toggle = app.buttons["lifecycleToggle-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        expectLifecycleNotice("Task completed", in: app)
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)
        XCTAssertEqual(toggle.label, "Reopen Review the project outline")
        attach(app, "Completed task and Undo")
        app.buttons["undoLifecycle"].tap()
        expectLifecycleNotice("Change undone", in: app)
        XCTAssertEqual(toggle.label, "Complete Review the project outline")
        XCTAssertFalse(app.buttons["undoLifecycle"].exists)
        toggle.tap()
        expectLifecycleNotice("Task completed", in: app)
        goTo("Completed", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Arrange the studio"].exists)
    }

    @MainActor func testTaskRowSwipesStageScheduleAndApplyPriorityAndMove() {
        let app = launch()
        let title = "Prepare the weekly plan"
        goTo("Work", in: app)
        let task = app.buttons[title]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        let schedule = app.buttons["taskSwipe-schedule"]
        let priority = app.buttons["taskSwipe-priority"]
        let move = app.buttons["taskSwipe-move"]
        let trash = app.buttons["taskSwipe-trash"]
        task.swipeLeft()
        XCTAssertTrue(schedule.waitForExistence(timeout: 5))
        XCTAssertTrue(priority.isHittable && move.isHittable && trash.isHittable)
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)
        XCTAssertFalse(app.staticTexts["lifecycleFeedback"].exists)
        attach(app, "Task row reveals schedule priority move and Trash")
        schedule.tap()
        let cancel = app.buttons["scheduleCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        app.buttons["Tomorrow"].tap()
        cancel.tap()
        waitGone(cancel)
        XCTAssertFalse(schedule.exists)

        task.swipeLeft()
        XCTAssertTrue(priority.waitForExistence(timeout: 5))
        priority.tap()
        let high = app.buttons["taskPriority-high"]
        XCTAssertTrue(high.waitForExistence(timeout: 5))
        high.tap()
        waitGone(app.buttons["taskMetadataCancel"])
        task.swipeLeft()
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        let list = app.navigationBars["Move to"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        app.buttons["Personal"].tap()
        waitGone(list)
        expectLifecycleNotice("Moved to list", in: app)
        XCTAssertFalse(task.exists)
        goTo("Personal", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["editTaskPriority"].value as? String, "High")
        XCTAssertTrue(app.buttons["editSchedule"].isEnabled)
    }

    @MainActor func testTaskRowSwipesCompleteReopenTrashAndRestoreOnlyAfterTap() {
        let app = launch()
        let task = app.buttons["Prepare the weekly plan"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        let complete = app.buttons["taskSwipe-complete"]
        task.swipeRight()
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertTrue(task.exists)
        XCTAssertFalse(app.staticTexts["lifecycleFeedback"].exists)
        attach(app, "Task row reveals completion before any write")
        complete.tap()
        expectLifecycleNotice("Task completed", in: app)
        XCTAssertTrue(app.buttons["undoLifecycle"].isEnabled)
        goTo("Completed", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.swipeRight()
        let reopen = app.buttons["taskSwipe-reopen"]
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        reopen.tap()
        expectLifecycleNotice("Task reopened", in: app)
        goTo("Today", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.swipeLeft()
        let trash = app.buttons["taskSwipe-trash"]
        XCTAssertTrue(trash.waitForExistence(timeout: 5))
        XCTAssertTrue(task.exists)
        XCTAssertFalse(app.buttons["Delete Forever"].exists)
        trash.tap()
        expectLifecycleNotice("Moved to Trash", in: app)
        XCTAssertTrue(app.buttons["undoLifecycle"].isEnabled)
        goTo("Trash", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.swipeRight()
        let restore = app.buttons["taskSwipe-restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete Forever"].exists)
        attach(app, "Trash row reveals Restore")
        restore.tap()
        expectLifecycleNotice("Restored", in: app)
        goTo("Today", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
    }

    @MainActor func testLifecycleTrashUndoAndRestoreAfterRelaunch() {
        let app = launch(qaCase: "lifecycle")
        app.buttons["Review the project outline"].tap()
        chooseLifecycleAction("Move to Trash", in: app)
        expectLifecycleNotice("Moved to Trash", in: app)
        XCTAssertTrue(app.staticTexts["In Trash"].exists)
        XCTAssertFalse(app.buttons["editTitle"].isEnabled)
        app.buttons["undoLifecycle"].tap()
        expectLifecycleNotice("Change undone", in: app)
        XCTAssertTrue(app.buttons["editTitle"].isEnabled)
        // The parent is restored, and its separately trashed child stays locked.
        let trashedChild = app.buttons["openSubtask-00000000-0000-0000-0000-000000000005"]
        reveal(trashedChild, in: app)
        trashedChild.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, Collect design references")
        XCTAssertTrue(app.staticTexts["In Trash"].exists)
        XCTAssertFalse(app.buttons["editTitle"].isEnabled)
        app.buttons["relatedTaskBack"].tap()
        chooseLifecycleAction("Move to Trash", in: app)
        expectLifecycleNotice("Moved to Trash", in: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Trash", in: app)
        app.buttons["Review the project outline"].tap()
        chooseLifecycleAction("Restore", in: app)
        expectLifecycleNotice("Restored", in: app)
        app.buttons["taskDetailDone"].tap()
        XCTAssertTrue(app.buttons["Collect design references"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Prepare the weekly plan"].exists)
    }

    @MainActor func testLifecyclePurgeConfirmsOnlyTheNamedRecord() {
        let app = launch(qaCase: "lifecycle")
        app.buttons["Review the project outline"].tap()
        chooseLifecycleAction("Move to Trash", in: app)
        expectLifecycleNotice("Moved to Trash", in: app)
        chooseLifecycleAction("Delete Forever", in: app)
        let confirmation = app.alerts["Delete Forever?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Review the project outline")).firstMatch.exists)
        attach(app, "Named permanent deletion confirmation")
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Delete Forever"].exists)
        app.buttons["Delete Forever"].tap()
        confirmation.buttons["Delete Forever"].tap()
        expectLifecycleNotice("Deleted forever", in: app)
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)
        goTo("Trash", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review the project outline"].exists)
    }

    @MainActor func testLifecyclePinWontDoAndReopenRetainThePin() {
        let app = launch(qaCase: "lifecycle")
        app.buttons["Review the project outline"].tap()
        chooseLifecycleAction("Pin", in: app)
        expectLifecycleNotice("Pinned", in: app)
        chooseLifecycleAction("Won't Do", in: app)
        expectLifecycleNotice("Marked Won't Do", in: app)
        app.buttons["taskDetailDone"].tap()
        goTo("Won't Do", in: app)
        app.buttons["lifecycleToggle-00000000-0000-0000-0000-000000000001"].tap()
        expectLifecycleNotice("Task reopened", in: app)
        goTo("Today", in: app)
        XCTAssertTrue(app.staticTexts["Pinned"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lifecycleToggle-00000000-0000-0000-0000-000000000007"].exists)
        attach(app, "Pinned group after reopening")
    }

    @MainActor func testLifecycleArchivedTaskCanMoveOut() {
        let app = launch(qaCase: "lifecycle")
        goTo("Personal", in: app)
        app.buttons["Read a chapter"].tap()
        XCTAssertTrue(app.staticTexts["Archived"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["editTitle"].isEnabled)
        chooseLifecycleAction("Move to List", in: app)
        XCTAssertFalse(app.buttons["Personal"].exists)
        app.buttons["Work"].tap()
        expectLifecycleNotice("Moved to list", in: app)
        XCTAssertTrue(app.buttons["editTitle"].isEnabled)
    }

    @MainActor func testLifecycleWriteFailureDoesNotClaimCompletion() {
        let app = launch(qaCase: "save-failure")
        let toggle = app.buttons["lifecycleToggle-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        expectLifecycleNotice("Could not confirm the change. Review the workspace before retrying.", in: app)
        XCTAssertEqual(toggle.label, "Complete Review the project outline")
        XCTAssertFalse(app.buttons["undoLifecycle"].exists)
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openSchedule(_ app: XCUIApplication, task: String) -> String {
        let row = app.buttons[task]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let schedule = app.buttons["editSchedule"]
        reveal(schedule, in: app)
        let original = schedule.label
        schedule.tap()
        XCTAssertTrue(app.buttons["scheduleDone"].waitForExistence(timeout: 5))
        return original
    }

    @MainActor func testScheduleDateDurationTabsPreserveExistingConversionAndCancel() {
        let app = launch()
        _ = openSchedule(app, task: "Review the project outline")
        let type = app.segmentedControls["scheduleType"]
        XCTAssertTrue(type.waitForExistence(timeout: 5))
        XCTAssertTrue(type.buttons["Date"].isSelected)
        type.buttons["Duration"].tap()
        XCTAssertTrue(type.buttons["Duration"].isSelected)
        XCTAssertFalse(app.datePickers["scheduleDateGrid"].exists)
        XCTAssertEqual(app.switches["scheduleAllDay"].value as? String, "1")
        app.buttons["scheduleRangeStart"].tap()
        XCTAssertTrue(app.datePickers["durationEndpointDate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["durationEndpoint"].buttons["Start"].isSelected)
        app.buttons["durationPopupCancel"].tap()
        waitGone(app.buttons["durationPopupDone"])
        attach(app, "Schedule Duration tab preserves all-day draft")
        type.buttons["Date"].tap()
        XCTAssertTrue(type.buttons["Date"].isSelected)
        XCTAssertEqual(app.buttons["scheduleTime"].value as? String, "None")
        type.buttons["Duration"].tap()
        app.buttons["scheduleCancel"].tap()
        app.buttons["editSchedule"].tap()
        XCTAssertTrue(type.waitForExistence(timeout: 5))
        XCTAssertTrue(type.buttons["Date"].isSelected)
        attach(app, "Schedule Date tab after canceled Duration draft")
        app.buttons["scheduleCancel"].tap()
    }

    @MainActor func testScheduleTimePopupOpensStagesClosesAndOuterCancelDiscards() {
        let app = launch(), task = "Review the project outline"
        let original = openSchedule(app, task: task)
        let time = app.buttons["scheduleTime"]
        reveal(time, in: app)
        XCTAssertEqual(time.value as? String, "None")
        XCTAssertFalse(app.buttons["scheduleTimeRemove"].exists)
        time.tap()
        let wheels = app.datePickers["scheduleTimeWheels"]
        XCTAssertTrue(wheels.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["scheduleTimeZone"].exists)
        attach(app, "Schedule Time popup with staged time and zone")
        app.buttons["scheduleTimePopoverDone"].tap()
        waitGone(wheels)
        XCTAssertNotEqual(time.value as? String, "None")
        XCTAssertTrue(app.buttons["scheduleTimeRemove"].exists)
        // The zone route stays available on the staged draft; choosing a zone
        // then cancelling the outer sheet discards both staged changes.
        let zone = app.buttons["scheduleZone"]
        reveal(zone, in: app)
        zone.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("London")
        let choice = app.buttons["Europe/London"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        waitGone(search)
        app.buttons["scheduleCancel"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        app.buttons["editSchedule"].tap()
        XCTAssertTrue(app.buttons["scheduleDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["scheduleTime"].value as? String, "None")
        XCTAssertFalse(app.buttons["scheduleTimeRemove"].exists)
        app.buttons["scheduleCancel"].tap()
    }

    @MainActor func testScheduleTimeSaveReopenRemoveAndDurationUnchanged() {
        let app = launch(), task = "Review the project outline"
        let original = openSchedule(app, task: task)
        app.buttons["scheduleTime"].tap()
        XCTAssertTrue(app.datePickers["scheduleTimeWheels"].waitForExistence(timeout: 5))
        let wheels = app.pickerWheels
        XCTAssertGreaterThanOrEqual(wheels.count, 2)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "10")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "35")
        XCTAssertEqual((wheels.element(boundBy: 0).value as? String)?.split(separator: " ").first.map(String.init), "10")
        XCTAssertEqual((wheels.element(boundBy: 1).value as? String)?.split(separator: " ").first.map(String.init), "35")
        app.buttons["scheduleTimePopoverDone"].tap()
        waitGone(app.datePickers["scheduleTimeWheels"])
        let selectedTime = app.buttons["scheduleTime"].value as? String
        XCTAssertTrue(selectedTime?.contains("10:35") == true)
        XCTAssertTrue(app.buttons["scheduleTimeRemove"].exists)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        let saved = app.buttons["editSchedule"].label
        XCTAssertNotEqual(saved, original)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app)
        XCTAssertEqual(openSchedule(app, task: task), saved)
        XCTAssertEqual(app.buttons["scheduleTime"].value as? String, selectedTime)
        // The saved time reopens with an inline remove control, and the
        // Duration toggle still offers the unchanged range editor.
        XCTAssertNotEqual(app.buttons["scheduleTime"].value as? String, "None")
        XCTAssertTrue(app.buttons["scheduleTimeRemove"].exists)
        let type = app.segmentedControls["scheduleType"]
        XCTAssertTrue(type.waitForExistence(timeout: 5))
        XCTAssertTrue(type.buttons["Date"].isSelected)
        type.buttons["Duration"].tap()
        XCTAssertTrue(app.switches["scheduleAllDay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scheduleDurationDate"].exists)
        XCTAssertTrue(app.buttons["scheduleDurationTime"].exists)
        attach(app, "Duration cards after Time popup save")
        type.buttons["Date"].tap()
        XCTAssertNotEqual(app.buttons["scheduleTime"].value as? String, "None")
        app.buttons["scheduleTimeRemove"].tap()
        XCTAssertEqual(app.buttons["scheduleTime"].value as? String, "None")
        XCTAssertFalse(app.buttons["scheduleTimeRemove"].exists)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
    }

    @MainActor func testScheduleDurationDateMoveRemainsAvailableAndCancels() {
        let app = launch()
        let original = openSchedule(app, task: "Prepare the weekly plan")
        let date = app.buttons["scheduleDurationDate"], time = app.buttons["scheduleDurationTime"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let beforeDate = date.value as? String, beforeTime = time.value as? String
        date.tap()
        XCTAssertTrue(app.datePickers["scheduleMoveDurationDate"].waitForExistence(timeout: 5))
        let day = app.buttons["Tuesday, November 10"]
        XCTAssertTrue(day.waitForExistence(timeout: 5), app.debugDescription); day.tap()
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertNotEqual(date.value as? String, beforeDate)
        XCTAssertEqual(date.value as? String, "Nov 10, 2026, End date · move whole range")
        XCTAssertEqual(time.value as? String, beforeTime)
        XCTAssertTrue((time.value as? String ?? "").contains("13:00"))
        XCTAssertTrue((time.value as? String ?? "").contains("14:00"))
        XCTAssertEqual(app.switches["scheduleAllDay"].value as? String, "0")
        app.buttons["scheduleCancel"].tap(); waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
    }

    @MainActor func testScheduleDateGridSelectsDayAndOuterCancelDiscards() {
        let app = launch(), task = "Review the project outline"
        let original = openSchedule(app, task: task)
        let grid = app.datePickers["scheduleDateGrid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        attach(app, "Schedule visible month grid")
        let day = grid.buttons.matching(NSPredicate(format: "label CONTAINS %@", "10"))
        XCTAssertEqual(day.count, 1, app.debugDescription)
        day.firstMatch.tap()
        attach(app, "Schedule month grid staged day")
        app.buttons["scheduleCancel"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        app.buttons["editSchedule"].tap()
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        day.firstMatch.tap()
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        let saved = app.buttons["editSchedule"].label
        XCTAssertNotEqual(saved, original)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app)
        XCTAssertEqual(openSchedule(app, task: task), saved)
        app.buttons["scheduleCancel"].tap()
    }

    @MainActor func testScheduleCalendarDateEditSurvivesRelaunch() {
        let app = launch(), task = "Review the project outline"
        app.buttons["Calendar"].tap()
        let original = openSchedule(app, task: task)
        app.buttons["scheduleDay-1"].tap()
        attach(app, "Calendar task schedule staged for tomorrow")
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        let updated = app.buttons["editSchedule"].label
        XCTAssertNotEqual(updated, original)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertEqual(openSchedule(app, task: task), updated)
        app.buttons["scheduleCancel"].tap()
    }

    @MainActor private func openScheduleOptions(_ id: String, in app: XCUIApplication) {
        let row = app.buttons[id]
        reveal(row, in: app)
        attach(app, "Schedule summary rows")
        row.tap()
        let title = id == "scheduleReminderOptions" ? "Reminder" : "Repeat"
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
        attach(app, "Schedule " + title + " options")
    }

    @MainActor private func scheduleRoot(_ app: XCUIApplication) {
        if !app.navigationBars["Schedule"].exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 5))
    }

    @MainActor func testScheduleNestedAndOuterCancelLeaveAnUntouchedTask() {
        let app = launch(), task = "Prepare the weekly plan"
        let original = openSchedule(app, task: task)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        let custom = app.buttons["scheduleCustom"]
        reveal(custom, in: app)
        custom.tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        attach(app, "Nested custom repeat")
        app.buttons["customRepeatCancel"].tap()
        waitGone(app.buttons["customRepeatDone"])
        XCTAssertFalse(app.staticTexts["scheduleCustomRule"].exists)
        scheduleRoot(app)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        app.buttons["editSchedule"].tap()
        scheduleRoot(app)
        let remove = app.buttons["scheduleRemove"]
        reveal(remove, in: app)
        remove.tap()
        XCTAssertTrue(app.buttons["scheduleAddDate"].waitForExistence(timeout: 5))
        app.buttons["scheduleCancel"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
    }

    @MainActor func testScheduleCreatesCustomRepeatAndStagesRemoval() {
        let app = launch(), task = "Review the project outline"
        _ = openSchedule(app, task: task)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        let custom = app.buttons["scheduleCustom"]
        reveal(custom, in: app)
        custom.tap()
        let customDone = app.buttons["customRepeatDone"]
        XCTAssertTrue(customDone.waitForExistence(timeout: 5))
        XCTAssertTrue(customDone.isEnabled)
        customDone.tap()
        waitGone(customDone)
        let rule = app.staticTexts["scheduleCustomRule"]
        reveal(rule, in: app)
        XCTAssertTrue(rule.exists)
        let expectedRule = rule.label
        XCTAssertFalse(expectedRule.isEmpty)
        scheduleRoot(app)
        XCTAssertEqual(app.buttons["scheduleRepeatOptions"].value as? String, expectedRule)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap()
        openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(rule, in: app)
        XCTAssertTrue(rule.exists)
        scheduleRoot(app)
        let remove = app.buttons["scheduleRemove"]
        reveal(remove, in: app, towardTop: true)
        remove.tap()
        XCTAssertTrue(app.buttons["scheduleAddDate"].waitForExistence(timeout: 5))
        scheduleRoot(app)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, "Schedule")
    }

    @MainActor func testScheduleZoneAndManualReminderPreserveTimedWindow() {
        let app = launch(), task = "Prepare the weekly plan"
        let original = openSchedule(app, task: task)
        let zone = app.buttons["scheduleZone"]
        reveal(zone, in: app)
        zone.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("New York")
        let choice = app.buttons["America/New York"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        waitGone(search)
        openScheduleOptions("scheduleReminderOptions", in: app)
        let automatic = app.switches["scheduleAutomaticReminders"]
        reveal(automatic, in: app)
        XCTAssertEqual(automatic.value as? String, "1")
        automatic.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(automatic.value as? String, "0")
        let add = app.buttons["scheduleAddReminder"]
        reveal(add, in: app)
        add.tap()
        attach(app, "Timed range with a manual reminder")
        scheduleRoot(app)
        XCTAssertEqual(app.buttons["scheduleReminderOptions"].value as? String, "1 reminder")
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
    }

    @MainActor func testTimedDurationEndReminderStagesAndSurvivesRelaunch() {
        let app = launch(), task = "Prepare the weekly plan"
        _ = openSchedule(app, task: task)
        let toggle = app.switches["scheduleReminderAtEnd"]
        let caption = app.staticTexts["scheduleEndReminderDate"]
        func enable() {
            openScheduleOptions("scheduleReminderOptions", in: app)
            reveal(toggle, in: app)
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1")
            XCTAssertTrue(caption.exists)
        }
        enable()
        scheduleRoot(app)
        app.buttons["scheduleCancel"].tap()
        waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap()
        XCTAssertTrue(app.buttons["scheduleDone"].waitForExistence(timeout: 5))
        enable()
        attach(app, "Timed duration reminder at the end")
        scheduleRoot(app)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        _ = openSchedule(app, task: task)
        openScheduleOptions("scheduleReminderOptions", in: app)
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertTrue(caption.exists)
        scheduleRoot(app)
        let type = app.segmentedControls["scheduleType"]
        reveal(type, in: app, towardTop: true)
        type.buttons["Date"].tap()
        openScheduleOptions("scheduleReminderOptions", in: app)
        XCTAssertTrue(app.switches["scheduleAutomaticReminders"].waitForExistence(timeout: 5))
        XCTAssertFalse(toggle.exists)
        scheduleRoot(app)
        app.buttons["scheduleCancel"].tap()
    }

    @MainActor private func stageTaskScheduleSkip(in app: XCUIApplication) {
        let skip = app.buttons["scheduleSkipOccurrence"]
        reveal(skip, in: app)
        let safeBottom = app.frame.maxY - 40
        for _ in 0..<3 where skip.frame.maxY > safeBottom {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.63))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.36)))
        }
        XCTAssertLessThanOrEqual(skip.frame.maxY, safeBottom)
        skip.tap()
        XCTAssertTrue(app.staticTexts["Done moves this open task to its next scheduled occurrence."].waitForExistence(timeout: 5))
    }

    @MainActor func testTaskRowScheduleSkipStagesCancelsAndUndoes() {
        continueAfterFailure = false
        let app = launch(qaCase: "skip-occurrence")
        let row = app.buttons["Review the project outline"]
        let schedule = app.buttons["taskSwipe-schedule"]
        let cancel = app.buttons["scheduleCancel"]
        let done = app.buttons["scheduleDone"]
        let notice = app.staticTexts["taskScheduleNotice"]
        let time = app.buttons["scheduleTime"]

        func openFromSwipe() {
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.swipeLeft()
            XCTAssertTrue(schedule.waitForExistence(timeout: 5))
            schedule.tap()
            XCTAssertTrue(done.waitForExistence(timeout: 5))
        }

        func stageTimeThroughPopup() {
            reveal(time, in: app)
            XCTAssertEqual(time.value as? String, "None")
            time.tap()
            XCTAssertTrue(app.datePickers["scheduleTimeWheels"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["scheduleTimeZone"].exists)
            app.buttons["scheduleTimePopoverDone"].tap()
            waitGone(app.datePickers["scheduleTimeWheels"])
            XCTAssertNotEqual(time.value as? String, "None")
            XCTAssertTrue(app.buttons["scheduleTimeRemove"].exists)
        }

        openFromSwipe()
        stageTimeThroughPopup()
        stageTaskScheduleSkip(in: app)
        attach(app, "Task swipe stages a skip of the saved occurrence")
        app.buttons["Keep editing"].tap()
        reveal(time, in: app, towardTop: true)
        XCTAssertNotEqual(time.value as? String, "None")
        stageTaskScheduleSkip(in: app)
        cancel.tap()
        waitGone(done)
        XCTAssertTrue(row.exists)
        XCTAssertFalse(notice.exists)

        openFromSwipe()
        stageTimeThroughPopup()
        stageTaskScheduleSkip(in: app)
        done.tap()
        waitGone(done)
        XCTAssertEqual(notice.label, "Occurrence skipped")
        XCTAssertFalse(row.exists)
        let undo = app.buttons["undoTaskSchedule"]
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(undo.exists)
        openFromSwipe()
        XCTAssertEqual(time.value as? String, "None")
        cancel.tap()
        waitGone(done)
    }

    @MainActor func testTaskDetailScheduleSkipSurvivesRelaunchAndRejectsTerminal() {
        continueAfterFailure = false
        let app = launch(qaCase: "skip-occurrence")
        let title = "Review the project outline"
        let original = openSchedule(app, task: title)
        let schedule = app.buttons["editSchedule"]
        let done = app.buttons["scheduleDone"]
        let cancel = app.buttons["scheduleCancel"]
        let notice = app.staticTexts["taskScheduleNotice"]
        stageTaskScheduleSkip(in: app)
        done.tap()
        waitGone(done)
        XCTAssertEqual(notice.label, "Occurrence skipped")
        XCTAssertTrue(app.buttons["undoTaskSchedule"].isEnabled)
        let advanced = schedule.label
        XCTAssertNotEqual(advanced, original)
        XCTAssertTrue(advanced.contains("Nov 16"))
        attach(app, "Task detail shows the saved next occurrence and Undo")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app)
        XCTAssertEqual(openSchedule(app, task: title), advanced)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app)
        scheduleRoot(app)
        XCTAssertFalse(app.buttons["scheduleSkipOccurrence"].exists)
        cancel.tap()
        waitGone(done)
        XCTAssertFalse(notice.exists)
        XCTAssertFalse(app.buttons["undoTaskSchedule"].exists)
    }

    @MainActor func testTaskScheduleSkipWriteFailureKeepsStagedAction() {
        continueAfterFailure = false
        let app = launch(qaCase: "skip-occurrence-save-failure")
        let original = openSchedule(app, task: "Review the project outline")
        stageTaskScheduleSkip(in: app)
        let done = app.buttons["scheduleDone"]
        done.tap()
        let error = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Could not confirm the save")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled)
        XCTAssertTrue(app.buttons["Keep editing"].exists)
        XCTAssertTrue(app.staticTexts["Done moves this open task to its next scheduled occurrence."].exists)
        app.buttons["scheduleCancel"].tap()
        waitGone(done)
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        XCTAssertFalse(app.staticTexts["taskScheduleNotice"].exists)
        XCTAssertFalse(app.buttons["undoTaskSchedule"].exists)
    }

    @MainActor func testScheduleWriteFailureKeepsStagedDate() {
        let app = launch(qaCase: "save-failure")
        let original = openSchedule(app, task: "Review the project outline")
        app.buttons["scheduleDay-1"].tap()
        app.buttons["scheduleDone"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Could not confirm the save")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scheduleDone"].isEnabled)
        XCTAssertTrue(app.buttons["scheduleRemove"].exists)
        app.buttons["scheduleCancel"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openArrange(_ app: XCUIApplication) {
        app.buttons["Calendar actions"].tap()
        let arrange = app.buttons["Arrange Tasks"]
        XCTAssertTrue(arrange.waitForExistence(timeout: 5))
        arrange.tap()
        XCTAssertTrue(app.buttons["arrangeDone"].waitForExistence(timeout: 5))
    }

    @MainActor private func editCalendarCard(_ app: XCUIApplication, title: String,
                                            action: String = "Edit Calendar Schedule") {
        let card = app.buttons[title]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 0.75)
        let command = app.buttons[action]
        XCTAssertTrue(command.waitForExistence(timeout: 5))
        command.tap()
        XCTAssertTrue(app.buttons["calendarEditDone"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarArrangeSidePanelDismissesWithoutOpeningTask() {
        let app = launch(qaCase: "arrange")
        app.buttons["Calendar"].tap()
        openArrange(app)
        let panel = app.descendants(matching: .any)["calendarArrangePanel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(panel.frame.minX, app.frame.width * 0.2)
        XCTAssertLessThan(panel.frame.width, app.frame.width * 0.8)
        let grouping = app.segmentedControls["arrangeGroup"]
        let filter = app.buttons["arrangeList"]
        XCTAssertTrue(grouping.waitForExistence(timeout: 5))
        XCTAssertTrue(filter.isHittable)
        XCTAssertEqual(filter.label, "Filter")
        XCTAssertGreaterThan(filter.frame.minY, grouping.frame.maxY)
        grouping.buttons["Tag"].tap()
        XCTAssertTrue(grouping.buttons["Tag"].isSelected)
        grouping.buttons["List"].tap()
        attach(app, "Calendar Arrange right panel")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.65)).tap()
        waitGone(app.buttons["arrangeDone"])
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)
        XCTAssertFalse(app.buttons["captureCancel"].exists)
        openArrange(app)
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])
    }

    @MainActor func testArrangeFilterStagesMultipleSourcesAndCancels() {
        let app = launch(qaCase: "arrange")
        app.buttons["Calendar"].tap(); openArrange(app)
        app.buttons["arrangeOptions"].tap(); app.buttons["arrangeOverdue"].tap()
        app.buttons["arrangeList"].tap()
        let all = app.buttons["arrangeFilterAll"], inbox = app.buttons["arrangeFilterInbox"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertEqual(all.value as? String, "Selected")
        inbox.tap(); app.buttons["Personal"].tap()
        XCTAssertEqual(inbox.value as? String, "Selected")
        XCTAssertEqual(app.buttons["Personal"].value as? String, "Selected")
        XCTAssertEqual(all.value as? String, "Not selected")
        attach(app, "Arrange staged multi-source filter")
        app.buttons["arrangeFilterCancel"].tap()
        app.buttons["arrangeList"].tap()
        XCTAssertEqual(all.value as? String, "Selected")
        inbox.tap(); app.buttons["Personal"].tap()
        app.buttons["arrangeFilterDone"].tap()
        XCTAssertTrue(app.buttons["Schedule Read a chapter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schedule Arrange the studio"].exists)
        app.buttons["arrangeList"].tap()
        XCTAssertEqual(inbox.value as? String, "Selected")
        XCTAssertEqual(app.buttons["Personal"].value as? String, "Selected")
        all.tap()
        XCTAssertEqual(inbox.value as? String, "Not selected")
        XCTAssertEqual(app.buttons["Personal"].value as? String, "Not selected")
        app.buttons["arrangeFilterDone"].tap()
        app.buttons["arrangeDone"].tap()
    }

    @MainActor func testArrangeFilterFolderDisclosureDoesNotSelectChildren() {
        let app = launch(qaCase: "timeline-arrange")
        app.buttons["Calendar"].tap(); openArrange(app)
        app.buttons["arrangeList"].tap()
        let folder = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "arrangeFilterFolder-")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        let work = app.buttons["Work"]
        XCTAssertTrue(work.exists)
        folder.tap(); XCTAssertFalse(work.exists)
        XCTAssertEqual(app.buttons["arrangeFilterAll"].value as? String, "Selected")
        folder.tap(); XCTAssertTrue(work.exists)
        XCTAssertEqual(work.value as? String, "Not selected")
        work.tap(); XCTAssertEqual(work.value as? String, "Selected")
        folder.tap(); folder.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        XCTAssertFalse(app.buttons["Old projects"].exists)
        app.buttons["arrangeFilterCancel"].tap()
        app.buttons["arrangeDone"].tap()
    }

    @MainActor func testCalendarArrangeScopesAndSchedulesTheFocusedDay() {
        let app = launch(qaCase: "arrange")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        app.buttons["Next Calendar period"].tap()
        openArrange(app)
        let chapter = app.buttons["Schedule Read a chapter"]
        let overdueTask = app.buttons["Schedule Arrange the studio"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        XCTAssertFalse(overdueTask.exists)

        app.buttons["arrangeOptions"].tap()
        let overdue = app.buttons["arrangeOverdue"]
        XCTAssertEqual(overdue.label, "Overdue Task")
        overdue.tap()
        XCTAssertTrue(overdueTask.waitForExistence(timeout: 5))
        app.buttons["arrangeOptions"].tap()
        XCTAssertEqual(app.buttons["arrangeOverdue"].label, "Overdue Task")
        attach(app, "Arrange overdue selected")
        app.tap()
        app.buttons["arrangeList"].tap()
        XCTAssertTrue(app.buttons["arrangeFilterInbox"].waitForExistence(timeout: 5))
        app.buttons["arrangeFilterInbox"].tap()
        app.buttons["arrangeFilterDone"].tap()
        XCTAssertTrue(overdueTask.exists)
        XCTAssertFalse(chapter.exists)
        app.buttons["arrangeList"].tap()
        app.buttons["arrangeFilterInbox"].tap()
        app.buttons["Personal"].tap()
        app.buttons["arrangeFilterDone"].tap()
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        XCTAssertFalse(overdueTask.exists)
        app.segmentedControls["arrangeGroup"].buttons["Priority"].tap()
        XCTAssertTrue(app.staticTexts["High · 1"].waitForExistence(timeout: 5))
        attach(app, "Arrange Tasks scoped and grouped")

        chapter.tap()
        XCTAssertTrue(app.buttons["calendarEditDone"].waitForExistence(timeout: 5))
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
        XCTAssertTrue(chapter.exists)
        chapter.tap()
        XCTAssertTrue(app.buttons["calendarEditDone"].waitForExistence(timeout: 5))
        attach(app, "Arrange staged on focused day")
        app.buttons["calendarEditDone"].tap()
        waitGone(app.buttons["calendarEditDone"])
        XCTAssertTrue(app.staticTexts["calendarScheduleNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(chapter.exists)
        XCTAssertTrue(app.buttons["undoCalendarSchedule"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openArrange(app)
        XCTAssertFalse(chapter.exists)
    }

    @MainActor func testCalendarArrangeHierarchyDefaultsExpandedAndCollapses() {
        let app = launch(qaCase: "arrange-hierarchy")
        app.buttons["Calendar"].tap()
        openArrange(app)
        XCTAssertTrue(app.buttons["Collapse Neutral arrange parent"].waitForExistence(timeout: 5))
        // The option ships checked: the tree starts expanded, turning the
        // control off flattens it, and turning it back on restores it. Menu
        // hosts do not expose the button value, so the default is proven
        // through this behavior rather than the value string.
        app.buttons["arrangeOptions"].tap()
        XCTAssertEqual(app.buttons["arrangeHierarchy"].label, "Show Task Hierarchy")
        app.buttons["arrangeHierarchy"].tap()
        waitGone(app.buttons["Collapse Neutral arrange parent"])
        XCTAssertTrue(app.buttons["Schedule Neutral arrange child one"].exists)
        app.buttons["arrangeOptions"].tap()
        app.buttons["arrangeHierarchy"].tap()
        XCTAssertTrue(app.staticTexts["Work · 4"].waitForExistence(timeout: 5))
        let collapse = app.buttons["Collapse Neutral arrange parent"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 5))
        let parentSchedule = app.buttons["Schedule Neutral arrange parent"]
        let childOne = app.buttons["Schedule Neutral arrange child one"]
        let childTwo = app.buttons["Schedule Neutral arrange child two"]
        XCTAssertTrue(childOne.exists)
        XCTAssertTrue(childTwo.exists)
        XCTAssertTrue(app.buttons["Schedule Neutral orphan child"].exists)
        XCTAssertGreaterThan(childOne.frame.minY, parentSchedule.frame.minY)
        XCTAssertGreaterThan(childTwo.frame.minY, childOne.frame.minY)
        let parentTitle = app.buttons["arrangeTitle-00000000-0000-0000-0000-000000000002"]
        let childTitle = app.buttons["arrangeTitle-00000000-0000-0000-0000-000000000006"]
        XCTAssertTrue(parentTitle.exists)
        XCTAssertGreaterThan(childTitle.frame.minX, parentTitle.frame.minX)
        let parentGrip = app.descendants(matching: .any)["calendarArrangeDrag-00000000-0000-0000-0000-000000000002"].firstMatch
        let childGrip = app.descendants(matching: .any)["calendarArrangeDrag-00000000-0000-0000-0000-000000000006"].firstMatch
        XCTAssertTrue(parentGrip.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(childGrip.frame.minX, parentGrip.frame.minX)
        XCTAssertGreaterThan(collapse.frame.minX, childTitle.frame.minX)
        attach(app, "Arrange hierarchy expanded")
        collapse.tap()
        XCTAssertTrue(app.buttons["Expand Neutral arrange parent"].waitForExistence(timeout: 5))
        waitGone(childOne)
        XCTAssertFalse(childTwo.exists)
        XCTAssertTrue(app.staticTexts["Work · 4"].exists)
        XCTAssertTrue(parentSchedule.exists)
        XCTAssertTrue(app.buttons["Schedule Neutral orphan child"].exists)
        attach(app, "Arrange hierarchy collapsed")
        app.buttons["Expand Neutral arrange parent"].tap()
        XCTAssertTrue(childOne.waitForExistence(timeout: 5))
        XCTAssertTrue(childTwo.exists)
    }

    @MainActor func testCalendarArrangeHierarchyOffFlatOnExpandedWithGroupingAndChildSchedule() {
        let app = launch(qaCase: "arrange-hierarchy")
        app.buttons["Calendar"].tap()
        openArrange(app)
        XCTAssertTrue(app.buttons["Collapse Neutral arrange parent"].waitForExistence(timeout: 5))
        app.buttons["Collapse Neutral arrange parent"].tap()
        XCTAssertTrue(app.buttons["Expand Neutral arrange parent"].waitForExistence(timeout: 5))
        waitGone(app.buttons["Schedule Neutral arrange child one"])
        app.buttons["arrangeOptions"].tap()
        app.buttons["arrangeHierarchy"].tap()
        XCTAssertFalse(app.buttons["Collapse Neutral arrange parent"].exists)
        XCTAssertFalse(app.buttons["Expand Neutral arrange parent"].exists)
        let flat = ["Schedule Neutral arrange parent", "Schedule Neutral orphan child",
                    "Schedule Neutral arrange child one", "Schedule Neutral arrange child two"]
        var lastY = -1.0
        for id in flat {
            XCTAssertTrue(app.buttons[id].exists)
            let y = app.buttons[id].frame.minY
            XCTAssertGreaterThan(y, lastY)
            lastY = y
        }
        attach(app, "Arrange hierarchy off flat")
        app.buttons["arrangeOptions"].tap()
        app.buttons["arrangeHierarchy"].tap()
        XCTAssertTrue(app.buttons["Collapse Neutral arrange parent"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Expand Neutral arrange parent"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral arrange child one"].exists)
        XCTAssertTrue(app.staticTexts["Work · 4"].exists)
        attach(app, "Arrange hierarchy on expanded")
        app.segmentedControls["arrangeGroup"].buttons["Priority"].tap()
        XCTAssertTrue(app.staticTexts["High · 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schedule Neutral arrange child two"].exists)
        XCTAssertFalse(app.buttons["Collapse Neutral arrange parent"].exists)
        XCTAssertFalse(app.buttons["Expand Neutral arrange parent"].exists)
        app.segmentedControls["arrangeGroup"].buttons["Tag"].tap()
        XCTAssertTrue(app.staticTexts["Planning · 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Collapse Neutral arrange parent"].exists)
        app.segmentedControls["arrangeGroup"].buttons["List"].tap()
        XCTAssertTrue(app.buttons["Collapse Neutral arrange parent"].waitForExistence(timeout: 5))
        attach(app, "Arrange hierarchy back on List")
        let child = app.buttons["Schedule Neutral arrange child one"]
        child.tap()
        XCTAssertTrue(app.buttons["calendarEditDone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Neutral arrange child one"].waitForExistence(timeout: 5))
        attach(app, "Arrange child schedule staged")
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        XCTAssertTrue(app.staticTexts["Work · 4"].exists)
        XCTAssertTrue(child.exists)
        XCTAssertTrue(app.buttons["Schedule Neutral arrange child two"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral arrange parent"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral orphan child"].exists)
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])
    }

    @MainActor func testCalendarArrangeChildScheduleDonePersistsOnlyChild() {
        let app = launch(qaCase: "arrange-hierarchy")
        // Launch lands on Today, which hides undated rows: open the Work
        // list for every detail read below.
        goTo("Work", in: app)
        // Pre-state: the child is unscheduled, like its parent.
        var row = app.buttons["Neutral arrange child one"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertEqual(app.buttons["editSchedule"].label, "Schedule")
        app.buttons["taskDetailDone"].tap()
        waitGone(app.buttons["editSchedule"])

        app.buttons["Calendar"].tap()
        openArrange(app)
        XCTAssertTrue(app.staticTexts["Work · 4"].waitForExistence(timeout: 5))
        app.buttons["Schedule Neutral arrange child one"].tap()
        XCTAssertTrue(app.buttons["calendarEditDone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Neutral arrange child one"].exists)
        app.buttons["calendarEditDone"].tap()
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        waitGone(app.buttons["Schedule Neutral arrange child one"])
        XCTAssertTrue(app.staticTexts["Work · 3"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral arrange parent"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral arrange child two"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral orphan child"].exists)
        attach(app, "Arrange child scheduled")
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])

        // Only the child's date changed: its detail now carries an actual
        // schedule while the parent stays unscheduled.
        app.buttons["Tasks"].tap()
        goTo("Work", in: app)
        row = app.buttons["Neutral arrange child one"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let scheduled = app.buttons["editSchedule"].label
        XCTAssertNotEqual(scheduled, "Schedule")
        app.buttons["taskDetailDone"].tap()
        waitGone(app.buttons["editSchedule"])
        app.buttons["Neutral arrange parent"].tap()
        XCTAssertEqual(app.buttons["editSchedule"].label, "Schedule")
        app.buttons["taskDetailDone"].tap()

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openArrange(app)
        XCTAssertFalse(app.buttons["Schedule Neutral arrange child one"].exists)
        XCTAssertTrue(app.staticTexts["Work · 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Schedule Neutral arrange parent"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral arrange child two"].exists)
        XCTAssertTrue(app.buttons["Schedule Neutral orphan child"].exists)
        attach(app, "Arrange child schedule persisted")
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])

        // The exact staged schedule survived relaunch; the parent is untouched.
        app.buttons["Tasks"].tap()
        goTo("Work", in: app)
        row = app.buttons["Neutral arrange child one"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertEqual(app.buttons["editSchedule"].label, scheduled)
        attach(app, "Child schedule persisted in detail")
        app.buttons["taskDetailDone"].tap()
        waitGone(app.buttons["editSchedule"])
        app.buttons["Neutral arrange parent"].tap()
        XCTAssertEqual(app.buttons["editSchedule"].label, "Schedule")
        app.buttons["taskDetailDone"].tap()
    }

    @MainActor func testCalendarArrangeDragSchedulesAndUndoes() {
        let app = launch(qaCase: "arrange")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        app.buttons["Next Calendar period"].tap()
        let day = app.buttons["calendarDay-2026-11-10"]
        guard day.waitForExistence(timeout: 5) else { return XCTFail("The target day is unavailable.") }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let header = day.frame
        let allDay = origin.withOffset(CGVector(dx: app.frame.width * 0.2, dy: header.maxY + 12))
        let timed = origin.withOffset(CGVector(dx: app.frame.width * 0.2, dy: header.maxY + 65))
        let actions = app.buttons["Calendar actions"].frame
        let outside = origin.withOffset(CGVector(dx: actions.midX, dy: actions.midY))
        openArrange(app)

        let grip = app.descendants(matching: .any)["calendarArrangeDrag-00000000-0000-0000-0000-000000000003"].firstMatch
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        func drag(to target: XCUICoordinate) {
            XCTAssertTrue(grip.isHittable)
            grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.6, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        drag(to: outside)
        XCTAssertTrue(grip.exists)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)

        drag(to: allDay)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertFalse(grip.exists)
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule restored")

        drag(to: timed)
        expectation(for: NSPredicate(format: "label == %@", "Schedule updated"), evaluatedWith: notice)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(grip.exists)
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])
        XCTAssertTrue(app.buttons["Read a chapter"].exists)
        attach(app, "Arranged task in the timed grid")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        app.buttons["Next Calendar period"].tap()
        XCTAssertTrue(app.buttons["Read a chapter"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarArrangeDropsInBothDateGrids() {
        let app = launch(qaCase: "arrange")
        app.buttons["Calendar"].tap()
        let grip = app.descendants(matching: .any)["calendarArrangeDrag-00000000-0000-0000-0000-000000000003"].firstMatch
        for (mode, number) in [("Month", 2), ("Multi-Week", 9)] {
            app.buttons["Calendar view"].tap()
            app.buttons[mode].tap()
            openArrange(app)
            let day = app.staticTexts["calendarMonthDay-2026-11-\(number)"]
            guard day.waitForExistence(timeout: 5) else { return XCTFail("The target date is unavailable in \(mode).") }
            let targetFrame = day.frame
            let panel = app.descendants(matching: .any)["calendarArrangePanel"].firstMatch
            XCTAssertLessThan(targetFrame.minX + 8, panel.frame.minX)
            let target = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: targetFrame.minX + 8, dy: targetFrame.midY))
            guard grip.waitForExistence(timeout: 5), grip.isHittable else { return XCTFail("The Arrange grip is unavailable.") }
            grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.6, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
            let notice = app.staticTexts["calendarScheduleNotice"]
            let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Schedule updated"), object: notice)
            guard XCTWaiter.wait(for: [saved], timeout: 5) == .completed else {
                return XCTFail("The drop did not schedule a task in \(mode).")
            }
            XCTAssertFalse(grip.exists)
            app.buttons["undoCalendarSchedule"].tap()
            XCTAssertTrue(grip.waitForExistence(timeout: 5))
            XCTAssertEqual(notice.label, "Schedule restored")
            app.buttons["arrangeDone"].tap()
            waitGone(app.buttons["arrangeDone"])
        }
    }

    @MainActor func testCalendarArrangeRecurringDropStagesScope() {
        let app = launch(qaCase: "arrange")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        app.buttons["Next Calendar period"].tap()
        let day = app.buttons["calendarDay-2026-11-10"]
        guard day.waitForExistence(timeout: 5) else { return XCTFail("The target day is unavailable.") }
        let target = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.width * 0.2, dy: day.frame.maxY + 12))
        openArrange(app)
        app.buttons["arrangeOptions"].tap()
        app.buttons["arrangeOverdue"].tap()
        let grip = app.descendants(matching: .any)["calendarArrangeDrag-00000000-0000-0000-0000-000000000004"].firstMatch
        guard grip.waitForExistence(timeout: 5) else { return XCTFail("The overdue recurring task is unavailable.") }
        func drag() {
            grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.6, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
        }

        drag()
        let occurrence = app.buttons["This occurrence"]
        guard occurrence.waitForExistence(timeout: 5) else { return XCTFail("The drop did not offer a recurrence scope.") }
        app.buttons["Cancel"].tap()
        waitGone(occurrence)
        XCTAssertTrue(app.buttons["arrangeDone"].exists)
        // The recurring row remaining available proves Include overdue survives Cancel.
        guard grip.waitForExistence(timeout: 5) else { return XCTFail("Cancelling should keep the recurring task in Arrange.") }
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        drag()
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
        occurrence.tap()
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "This occurrence updated")
        XCTAssertFalse(grip.exists)
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        drag()
        XCTAssertTrue(app.buttons["Series"].waitForExistence(timeout: 5))
        app.buttons["Series"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Schedule updated"), object: notice)], timeout: 5), .completed)
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])
    }

    @MainActor func testCalendarCardStagedRemovalAndScopedUndo() {
        let app = launch(), title = "Review the project outline"
        app.buttons["Calendar"].tap()
        editCalendarCard(app, title: title)
        app.buttons["calendarEditRemove"].tap()
        XCTAssertTrue(app.staticTexts["Removal clears the date, duration, reminders, and repeat when you tap Done."].exists)
        app.buttons["calendarEditDone"].tap()
        waitGone(app.buttons["calendarEditDone"])
        XCTAssertFalse(app.buttons[title].exists)
        let undo = app.buttons["undoCalendarSchedule"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["calendarScheduleNotice"].label, "Schedule restored")
    }

    @MainActor func testCalendarHourDragCreatesASnappedTimedRange() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        app.buttons["calendarHours"].tap()
        app.buttons["calendarHourBand-early"].tap()
        app.buttons["calendarHoursDone"].tap()
        let grip = app.images["Drag Review the project outline"]
        let hour = app.staticTexts["02"]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertTrue(hour.isHittable)
        let target = hour.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
            .withOffset(CGVector(dx: 150, dy: 0))
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        attach(app, "Hour drop created timed range")
    }

    @MainActor func testCalendarFoldedHoursRevealTasksAndResetOnRelaunch() {
        let app = launch(qaCase: "folded-hours")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let early = app.buttons["calendarHourBand-early"]
        let late = app.buttons["calendarHourBand-late"]
        XCTAssertFalse(early.exists)
        attach(app, "Calendar without persistent hour row")
        app.buttons["calendarHours"].tap()
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        XCTAssertEqual(early.label, "Show early hours")
        XCTAssertEqual(early.value as? String, "1 item")
        XCTAssertEqual(late.value as? String, "1 item")
        attach(app, "Calendar visible hours popover")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.6)).tap()
        waitGone(app.buttons["calendarHoursDone"])
        XCTAssertFalse(app.buttons["captureCancel"].exists)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        app.buttons["calendarHours"].tap()
        XCTAssertEqual(early.label, "Show early hours")
        early.tap()
        XCTAssertEqual(early.label, "Hide early hours")
        XCTAssertEqual(late.label, "Show late hours")
        app.buttons["calendarHoursDone"].tap()
        reveal(app.buttons["Read a chapter"], in: app)
        app.buttons["calendarHours"].tap()
        late.tap()
        XCTAssertEqual(late.label, "Hide late hours")
        app.buttons["calendarHoursDone"].tap()
        reveal(app.buttons["Arrange the studio"], in: app)
        attach(app, "Expanded late hours")
        app.buttons["calendarHours"].tap()
        late.tap()
        XCTAssertEqual(early.label, "Hide early hours")
        app.buttons["calendarHoursDone"].tap()
        waitGone(app.buttons["Arrange the studio"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertFalse(early.exists)
        app.buttons["calendarHours"].tap()
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        XCTAssertEqual(early.label, "Show early hours")
        XCTAssertEqual(late.label, "Show late hours")
        app.buttons["calendarHoursDone"].tap()
    }

    @MainActor func testMonthZoomPinchRevealsMoreTasksAndResetsOnModeChange() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let level = app.staticTexts["calendarMonthZoomLevel"]
        let extra = app.buttons["Book time for a walk"]
        func expectLevel(_ label: String) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: level)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed, "Expected \(label), saw \(level.label)")
        }
        expectLevel("Full Month")
        XCTAssertFalse(extra.exists)
        let grid = app.scrollViews["calendarMonthGrid"]
        XCTAssertTrue(grid.exists)
        grid.pinch(withScale: 1.7, velocity: 1)
        expectLevel("3 Weeks")
        app.buttons["Zoom Month in"].tap()
        expectLevel("2 Weeks")
        app.buttons["Zoom Month in"].tap()
        expectLevel("1 Week")
        XCTAssertTrue(extra.waitForExistence(timeout: 5))
        attach(app, "One-week Month zoom shows more tasks")
        app.buttons["Next Calendar period"].tap()
        waitGone(extra)
        app.buttons["Today"].tap()
        XCTAssertTrue(extra.waitForExistence(timeout: 5))
        // The scroll view extends under the floating navigation bar.
        // Keep both simulated touches inside the visible week.
        let dayGrid = app.descendants(matching: .any).matching(identifier: "calendarMonthDays").firstMatch
        XCTAssertTrue(dayGrid.exists)
        dayGrid.pinch(withScale: 0.55, velocity: -1)
        expectLevel("2 Weeks")
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        XCTAssertFalse(level.exists)
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        expectLevel("Full Month")
        XCTAssertFalse(extra.exists)
    }

    @MainActor func testCalendarMonthAllDayRangeContinuesOnNextWeekRow() {
        let app = launch(qaCase: "month-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let retreat = app.buttons.matching(identifier: "Weekend retreat")
        XCTAssertTrue(retreat.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(retreat.count, 2)
        let rows = retreat.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        guard rows.count == 2 else { return }
        // The title button shares the bar with the move grip and the true
        // endpoint handle. Measure the complete segment on each week row.
        let moveGrips = app.images.matching(identifier: "Drag Weekend retreat").allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
        let start = app.buttons["Resize start of Weekend retreat"]
        let end = app.buttons["Resize end of Weekend retreat"]
        XCTAssertEqual(moveGrips.count, 2)
        XCTAssertTrue(start.exists && end.exists)
        guard moveGrips.count == 2, start.exists, end.exists else { return }
        let first = rows[0].frame.union(moveGrips[0].frame).union(start.frame)
        let continuation = rows[1].frame.union(moveGrips[1].frame).union(end.frame)
        XCTAssertGreaterThan(first.width, 125)
        XCTAssertGreaterThan(continuation.width, 60)
        XCTAssertGreaterThan(first.minX, continuation.minX)
        XCTAssertGreaterThan(rows[1].frame.minY - rows[0].frame.minY, 55)
        XCTAssertTrue(app.buttons["1 more items, open Day"].exists)
        attach(app, "Month range continues on next row")

        app.buttons["Calendar view"].tap()
        app.buttons["Multi-Week"].tap()
        XCTAssertEqual(retreat.count, 2)
        attach(app, "Multi-Week range continues on next row")
    }

    @MainActor func testCalendarMonthDragMovesAnAllDayTask() {
        let app = launch(), title = "Review the project outline"
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let card = app.images["Drag " + title]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let destination = app.staticTexts["calendarMonthDay-2026-11-10"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.25)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        attach(app, "Month drag moved an all-day task")
    }

    @MainActor func testCalendarMonthTitleAndGripRemainSeparateInBothGrids() {
        let app = launch(qaCase: "month-browse")
        app.buttons["Calendar"].tap()
        let title = "November plan"
        let card = app.buttons[title]
        let grip = app.images["Drag " + title]

        func checkCard(in mode: String) {
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertTrue(card.isHittable && grip.isHittable)
            XCTAssertEqual(card.label, title)
            XCTAssertLessThanOrEqual(card.frame.maxX, grip.frame.minX + 1)
            attach(app, mode + " compact task title")
            card.tap()
            XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, " + title)
            app.buttons["taskDetailDone"].tap()
            waitGone(app.buttons["taskDetailDone"])
        }

        checkCard(in: "Month")
        app.buttons["Calendar view"].tap()
        app.buttons["Multi-Week"].tap()
        checkCard(in: "Multi-Week")
    }

    @MainActor func testCalendarTimedStartHandleKeepsDueAndRestoresOnUndo() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let id = "00000000-0000-0000-0000-000000000002"
        let handle = app.buttons["calendarResizeStartHandle-" + id]
        let lower = app.frame.minY + 245
        let upper = app.frame.maxY - 145
        for _ in 0..<6 {
            if handle.isHittable, (lower...upper).contains(handle.frame.midY) { break }
            let above = handle.exists && handle.frame.midY < lower
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: above ? 0.4 : 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: above ? 0.65 : 0.4)))
        }
        XCTAssertTrue(handle.isHittable)
        XCTAssertTrue((lower...upper).contains(handle.frame.midY))
        XCTAssertTrue(app.buttons["calendarResizeHandle-" + id].exists)
        handle.tap()
        XCTAssertTrue(app.navigationBars["Resize Start"].waitForExistence(timeout: 5))
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])

        let hour = app.staticTexts["13"]
        XCTAssertTrue(hour.exists)
        func offset() -> CGFloat { handle.frame.minY - hour.frame.minY }
        let original = offset()
        let notice = app.staticTexts["calendarScheduleNotice"]
        func resizeStart() {
            let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -26)))
            XCTAssertTrue(notice.waitForExistence(timeout: 5))
            XCTAssertEqual(notice.label, "Schedule updated")
            XCTAssertEqual(offset() - original, -26, accuracy: 2)
        }
        resizeStart()
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(offset(), original, accuracy: 2)
        resizeStart()
        attach(app, "Timed Calendar start resize saved")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(offset() - original, -26, accuracy: 2)
    }

    @MainActor func testCalendarTimedShortMovePreservesDurationAndUndo() {
        let app = launch(qaCase: "short-calendar-move")
        let title = "Review the project outline"
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let card = app.buttons[title]
        let grip = app.images["Drag " + title]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        let lower = app.frame.minY + 220
        let upper = app.frame.maxY - 190
        for _ in 0..<6 {
            if grip.isHittable, (lower...upper).contains(grip.frame.minY) { break }
            let above = grip.frame.minY < lower
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.4 : 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.65 : 0.4)))
        }
        XCTAssertTrue(grip.isHittable)
        XCTAssertTrue((lower...upper).contains(grip.frame.minY))
        XCTAssertFalse(app.buttons["calendarResizeStartHandle-00000000-0000-0000-0000-000000000001"].exists)
        editCalendarCard(app, title: title, action: "Resize Start")
        XCTAssertTrue(app.navigationBars["Resize Start"].exists)
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
        let hour = app.staticTexts["09"]
        XCTAssertTrue(hour.exists)
        func cardOffset() -> CGFloat { card.frame.minY - hour.frame.minY }
        let originalOffset = cardOffset()
        let notice = app.staticTexts["calendarScheduleNotice"]

        func moveOneHour() {
            let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            let end = start.withOffset(CGVector(dx: -45, dy: 48))
            start.press(forDuration: 0.5, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.25)
            XCTAssertTrue(notice.waitForExistence(timeout: 5))
            XCTAssertEqual(notice.label, "Schedule updated")
            XCTAssertEqual(cardOffset() - originalOffset, 52, accuracy: 2)
        }

        moveOneHour()
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(cardOffset(), originalOffset, accuracy: 2)
        moveOneHour()
        attach(app, "Short timed move saved")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["undoCalendarSchedule"].exists)
        XCTAssertEqual(cardOffset() - originalOffset, 52, accuracy: 2)
    }

    @MainActor func testCalendarTimedResizeHandleMovesTheEnd() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        openArrange(app)
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])
        let handle = app.buttons["calendarResizeHandle-00000000-0000-0000-0000-000000000002"]
        // A card can report a hittable sliver beneath the floating tab bar.
        // Bring the handle and the complete drag into the timeline viewport.
        let lower = app.frame.minY + 220
        let upper = app.frame.maxY - 150
        for _ in 0..<6 {
            if handle.isHittable, (lower...upper).contains(handle.frame.midY) { break }
            let above = handle.exists && handle.frame.midY < lower
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.4 : 0.65))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.65 : 0.4)))
        }
        XCTAssertTrue(handle.isHittable)
        XCTAssertTrue((lower...upper).contains(handle.frame.midY))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 26))
        start.press(forDuration: 0.05, thenDragTo: end)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        attach(app, "Day timed range after resize")
        handle.tap()
        XCTAssertTrue(app.buttons["calendarEditDone"].waitForExistence(timeout: 5))
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
    }

    @MainActor private func openRecurringCalendar() -> XCUIApplication {
        let app = launch(qaCase: "occurrence")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        return app
    }

    @MainActor private func dragOccurrence(in app: XCUIApplication, title: String) {
        let grip = app.images["Drag " + title]
        let destination = app.staticTexts["calendarMonthDay-2026-11-10"]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.25)
    }

    @MainActor private func expectNovemberForecasts(in app: XCUIApplication, title: String) {
        let previews = app.buttons.matching(identifier: title + ", recurring preview").allElementsBoundByIndex.map(\.frame)
        for day in [16, 23, 30] {
            let date = app.staticTexts["calendarMonthDay-2026-11-\(day)"]
            XCTAssertTrue(date.exists)
            let top = date.frame.minY
            XCTAssertEqual(previews.filter { (top..<top + 60).contains($0.minY) }.count, 1, "November \(day)")
        }
    }

    @MainActor private func swipeCalendarTitle(_ title: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let center = title.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        let delta = min(64, app.frame.maxX - title.frame.midX - 8)
        XCTAssertGreaterThan(delta, 36)
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: delta, dy: 0)),
                     withVelocity: .fast, thenHoldForDuration: 0)
    }

    @MainActor func testCalendarMonthRecurringTitleSwipeOpensStagedSchedule() {
        continueAfterFailure = false
        let app = launch(qaCase: "skip-occurrence")
        app.buttons["Calendar"].tap()
        let title = "Review the project outline"
        let active = app.buttons[title]
        let projected = app.buttons[title + ", recurring preview"]
        let done = app.buttons["calendarEditDone"]
        let cancel = app.buttons["calendarEditCancel"]
        let header = app.buttons["calendarJumpToDate"]
        let initialHeader = header.value as? String
        swipeCalendarTitle(projected, in: app)
        XCTAssertFalse(done.exists)
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)

        swipeCalendarTitle(active, in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        let skip = app.buttons["calendarSkipOccurrence"]
        reveal(skip, in: app)
        skip.tap()
        XCTAssertTrue(app.staticTexts["Done moves this open task to its next scheduled occurrence."].exists)
        attach(app, "Month swipe opens the staged recurrence editor")
        cancel.tap()
        waitGone(done)
        XCTAssertTrue(projected.exists)
        XCTAssertTrue(active.isHittable)
        XCTAssertEqual(header.value as? String, initialHeader)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)

        editCalendarCard(app, title: title)
        cancel.tap()
        waitGone(done)
        active.tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarAgendaRecurringTitleSwipeSkipsAndUndoes() {
        continueAfterFailure = false
        let app = launch(qaCase: "skip-occurrence")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Agenda"].tap()
        let title = "Review the project outline"
        let active = app.buttons[title]
        let projected = app.buttons[title + ", recurring preview"]
        let notice = app.staticTexts["calendarScheduleNotice"]
        let done = app.buttons["calendarEditDone"]
        let cancel = app.buttons["calendarEditCancel"]
        let undo = app.buttons["undoCalendarSchedule"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        active.swipeLeft()
        XCTAssertFalse(done.exists)
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)
        swipeCalendarTitle(app.buttons["Prepare the weekly plan"], in: app)
        XCTAssertFalse(done.exists)
        XCTAssertFalse(app.buttons["taskDetailDone"].exists)

        func skipFromSwipe() {
            swipeCalendarTitle(active, in: app)
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            let skip = app.buttons["calendarSkipOccurrence"]
            reveal(skip, in: app)
            skip.tap()
            XCTAssertTrue(app.staticTexts["Done moves this open task to its next scheduled occurrence."].exists)
            XCTAssertFalse(notice.exists)
            done.tap()
            waitGone(done)
            XCTAssertEqual(notice.label, "Occurrence skipped")
            XCTAssertFalse(projected.exists)
        }

        skipFromSwipe()
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertTrue(projected.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        skipFromSwipe()
        attach(app, "Agenda occurrence skipped from a card swipe")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertFalse(projected.exists)
        reveal(active, in: app)
        swipeCalendarTitle(active, in: app)
        XCTAssertFalse(done.exists)
        XCTAssertFalse(undo.exists)
        editCalendarCard(app, title: title)
        XCTAssertFalse(app.buttons["calendarSkipOccurrence"].exists)
        cancel.tap()
        waitGone(done)
    }

    @MainActor func testCalendarSkipOccurrenceStagesAdvancesUndoesAndSurvivesRelaunch() {
        let app = launch(qaCase: "skip-occurrence"), title = "Review the project outline"
        app.buttons["Calendar"].tap()
        let forecast = app.buttons.matching(identifier: title + ", recurring preview")
        let notice = app.staticTexts["calendarScheduleNotice"]
        let skip = app.buttons["calendarSkipOccurrence"]
        let done = app.buttons["calendarEditDone"]
        let restore = app.buttons["calendarOccurrenceRestore"]
        XCTAssertEqual(forecast.count, 1)

        dragOccurrence(in: app, title: title)
        let occurrence = app.buttons["This occurrence"]
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
        occurrence.tap()
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "This occurrence updated")

        func stage() {
            editCalendarCard(app, title: title)
            reveal(skip, in: app)
            XCTAssertTrue(skip.isHittable)
            skip.tap()
            XCTAssertTrue(app.staticTexts["Done moves this open task to its next scheduled occurrence."].exists)
        }
        stage()
        attach(app, "Skip occurrence staged")
        app.buttons["calendarEditCancel"].tap()
        waitGone(done)
        XCTAssertEqual(forecast.count, 1)
        XCTAssertEqual(notice.label, "This occurrence updated")

        stage()
        done.tap()
        waitGone(done)
        XCTAssertEqual(notice.label, "Occurrence skipped")
        XCTAssertEqual(forecast.count, 0)
        let undo = app.buttons["undoCalendarSchedule"]
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(forecast.count, 1)
        editCalendarCard(app, title: title)
        XCTAssertTrue(restore.exists)
        app.buttons["calendarEditCancel"].tap()
        waitGone(done)

        stage()
        done.tap()
        waitGone(done)
        XCTAssertEqual(notice.label, "Occurrence skipped")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertEqual(forecast.count, 0)
        XCTAssertFalse(undo.exists)
        editCalendarCard(app, title: title)
        XCTAssertFalse(skip.exists)
        XCTAssertFalse(restore.exists)
        attach(app, "Final occurrence reopened")
        app.buttons["calendarEditCancel"].tap()
        waitGone(done)
    }

    @MainActor func testCalendarRecurringDragStagesScopeAndRetainsExceptionOnRelaunch() {
        let app = openRecurringCalendar(), title = "Review the project outline"
        expectNovemberForecasts(in: app, title: title)
        let occurrence = app.buttons["This occurrence"]
        dragOccurrence(in: app, title: title)
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
        attach(app, "Recurring Calendar drag scope")
        app.buttons["Cancel"].tap()
        waitGone(occurrence)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)

        dragOccurrence(in: app, title: title)
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
        occurrence.tap()
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "This occurrence updated")
        XCTAssertTrue(app.buttons["undoCalendarSchedule"].isEnabled)
        expectNovemberForecasts(in: app, title: title)

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        editCalendarCard(app, title: title)
        let restore = app.buttons["calendarOccurrenceRestore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.staticTexts["Done restores the original schedule for this occurrence."].exists)
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
    }

    @MainActor func testCalendarRestoresOriginalOccurrenceAfterRelaunch() {
        let app = openRecurringCalendar(), title = "Review the project outline"
        dragOccurrence(in: app, title: title)
        let occurrence = app.buttons["This occurrence"]
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5))
        occurrence.tap()
        XCTAssertTrue(app.staticTexts["calendarScheduleNotice"].waitForExistence(timeout: 5))

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        editCalendarCard(app, title: title)
        let restore = app.buttons["calendarOccurrenceRestore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.staticTexts["Done restores the original schedule for this occurrence."].exists)
        app.buttons["calendarEditDone"].tap()
        waitGone(app.buttons["calendarEditDone"])
        XCTAssertEqual(app.staticTexts["calendarScheduleNotice"].label, "Schedule updated")
        expectNovemberForecasts(in: app, title: title)
        editCalendarCard(app, title: title)
        XCTAssertFalse(restore.exists)
        attach(app, "Original recurring schedule restored")
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openCalendarViewOptions(_ app: XCUIApplication) {
        app.buttons["Calendar actions"].tap()
        let item = app.buttons["View Options"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.buttons["calendarPreferencesDone"].waitForExistence(timeout: 5))
    }

    @MainActor private func calendarOptionsRoot(_ app: XCUIApplication) {
        for _ in 0..<4 {
            if app.navigationBars["Calendar View Options"].exists { return }
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.navigationBars["Calendar View Options"].waitForExistence(timeout: 5))
    }

    @MainActor private func calendarIconOptions(_ app: XCUIApplication) {
        app.buttons["calendarStylePage"].tap()
        attach(app, "Calendar Style page")
        app.buttons["calendarIconsPage"].tap()
        XCTAssertTrue(app.switches["calendarIcons"].waitForExistence(timeout: 5))
        attach(app, "Calendar item icons page")
    }

    @MainActor func testCalendarSourceColorSavesAndResetCanBeCancelled() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        let nav = app.navigationBars["Color"]
        let reset = app.buttons["Use default color for Inbox"]
        let inboxColor = app.buttons["Inbox"]
        func listColors() {
            openCalendarViewOptions(app)
            app.buttons["calendarColorPage"].tap()
            XCTAssertTrue(nav.waitForExistence(timeout: 5))
            XCTAssertTrue(inboxColor.waitForExistence(timeout: 5))
        }
        func back(_ bar: XCUIElement) { bar.buttons.firstMatch.tap(); waitGone(bar) }
        func pick(_ button: XCUIElement, from original: String, to color: String) {
            button.tap()
            let sliders = app.buttons["Sliders"]
            XCTAssertTrue(sliders.waitForExistence(timeout: 5))
            sliders.tap()
            let hex = app.textFields.matching(NSPredicate(format: "value == %@", original)).firstMatch
            XCTAssertTrue(hex.waitForExistence(timeout: 5))
            hex.tap()
            hex.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + color + "\n")
            app.buttons["close"].tap()
            XCTAssertEqual(button.value as? String, "#" + color)
        }
        listColors()
        XCTAssertFalse(reset.isEnabled)
        pick(inboxColor, from: "7C6CF2", to: "1C62AE")
        XCTAssertTrue(reset.isEnabled)
        XCTAssertEqual(inboxColor.value as? String, "#1C62AE")
        back(nav)
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        app.terminate(); app.launch()
        app.buttons["Calendar"].tap()
        listColors()
        XCTAssertEqual(inboxColor.value as? String, "#1C62AE")
        XCTAssertTrue(reset.isEnabled)
        reset.tap()
        XCTAssertFalse(reset.isEnabled)
        back(nav)
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        listColors()
        XCTAssertTrue(reset.isEnabled)
        attach(app, "Saved Inbox Calendar color")
        reset.tap()
        XCTAssertFalse(reset.isEnabled)
        app.buttons["calendarColor"].tap()
        app.buttons["calendarColorMode-priority"].tap()
        XCTAssertFalse(app.buttons["Inbox"].exists)
        XCTAssertTrue(app.staticTexts["Priority uses its fixed Calendar colors. There is nothing to customize."].waitForExistence(timeout: 5))
        app.buttons["calendarColor"].tap()
        app.buttons["calendarColorMode-tag"].tap()
        let planning = app.buttons["Planning"]
        XCTAssertTrue(planning.waitForExistence(timeout: 5))
        pick(planning, from: "E6A53A", to: "008122")
        XCTAssertTrue(app.buttons["Use default color for Planning"].isEnabled)
        attach(app, "Custom Calendar tag color")
        back(nav)
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
    }

    @MainActor func testCalendarColorPageShowsFolderHierarchyAndModeSwitch() {
        let app = launch(qaCase: "calendar-filter-hierarchy")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        app.buttons["calendarColorPage"].tap()
        let nav = app.navigationBars["Color"]
        XCTAssertTrue(nav.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["calendarColor"].value as? String, "List")
        XCTAssertTrue(app.buttons["Inbox"].exists)
        XCTAssertTrue(app.buttons["Personal"].exists)
        XCTAssertTrue(app.buttons["Work"].exists)
        XCTAssertTrue(app.staticTexts["Projects"].exists)
        attach(app, "Calendar Color page with Inbox, lists and folder")
        app.buttons["calendarColor"].tap()
        attach(app, "Calendar Color By menu")
        app.buttons["calendarColorMode-tag"].tap()
        XCTAssertEqual(app.buttons["calendarColor"].value as? String, "Tag")
        XCTAssertTrue(app.buttons["Planning"].waitForExistence(timeout: 5))
        app.buttons["calendarColor"].tap()
        app.buttons["calendarColorMode-priority"].tap()
        XCTAssertEqual(app.buttons["calendarColor"].value as? String, "Priority")
        XCTAssertFalse(app.buttons["Inbox"].exists)
        XCTAssertFalse(app.buttons["Planning"].exists)
        XCTAssertTrue(app.staticTexts["Priority uses its fixed Calendar colors. There is nothing to customize."].exists)
        nav.buttons.firstMatch.tap()
        waitGone(nav)
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
    }

    @MainActor private func setSwitch(_ id: String, to state: Bool, app: XCUIApplication) {
        let toggle = app.switches[id]
        reveal(toggle, in: app)
        let desired = state ? "1" : "0"
        if toggle.value as? String != desired {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, desired)
    }

    @MainActor private func weekDayWidth(_ app: XCUIApplication) -> CGFloat {
        abs(app.buttons["calendarDay-2026-11-10"].frame.midX - app.buttons["calendarDay-2026-11-9"].frame.midX)
    }

    @MainActor private func swipeWeekGrid(_ grid: XCUIElement, left: Bool) {
        let right = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.42))
        let leading = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.23, dy: 0.42))
        (left ? right : leading).press(forDuration: 0.05, thenDragTo: left ? leading : right,
                                       withVelocity: .slow, thenHoldForDuration: 0.05)
    }

    @MainActor func testWeekSwipeShowsSevenDaysAndPagesWithoutEditing() {
        let app = launch(qaCase: "all-day-spans")
        app.buttons["Calendar"].tap()
        let grid = app.scrollViews["calendarHourlyGrid"]
        let monday = app.buttons["calendarDay-2026-11-9"]
        let sunday = app.buttons["calendarDay-2026-11-15"]
        let next = app.buttons["calendarDay-2026-11-16"]
        let previous = app.buttons["calendarDay-2026-11-2"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertTrue(sunday.isHittable)
        XCTAssertLessThanOrEqual(sunday.frame.maxX, grid.frame.maxX + 1)
        let top = monday.frame.minY
        attach(app, "Week fits seven days with one ruler")

        swipeWeekGrid(grid, left: true)
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(monday.exists)
        XCTAssertEqual(next.frame.minY, top, accuracy: 2)
        attach(app, "Week after swiping to the next period")
        swipeWeekGrid(grid, left: false)
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        swipeWeekGrid(grid, left: false)
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        app.buttons["Today"].tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 5))

        let lower = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.65))
        let upper = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.36))
        lower.press(forDuration: 0.05, thenDragTo: upper, withVelocity: .slow, thenHoldForDuration: 0.05)
        XCTAssertEqual(app.buttons["calendarJumpToDate"].value as? String, "Monday, 9 November 2026")
        XCTAssertFalse(next.exists)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
    }

    @MainActor func testWeekSwipePansExtraRulersBeforePagingAtTheEdge() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        openCalendarZoneSettings(app)
        setSwitch("calendarAdditionalZones", to: true, app: app)
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        let grid = app.scrollViews["calendarHourlyGrid"]
        let monday = app.buttons["calendarDay-2026-11-9"]
        let sunday = app.buttons["calendarDay-2026-11-15"]
        let next = app.buttons["calendarDay-2026-11-16"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(sunday.frame.maxX, grid.frame.maxX + 10)
        swipeWeekGrid(grid, left: true)
        XCTAssertTrue(sunday.isHittable)
        XCTAssertFalse(next.exists)
        XCTAssertLessThanOrEqual(sunday.frame.maxX, grid.frame.maxX + 2)
        attach(app, "Week pan reveals Sunday with extra rulers")
        swipeWeekGrid(grid, left: true)
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(monday.exists)
        XCTAssertTrue(app.staticTexts["calendarRuler-America/New_York"].isHittable)
        swipeWeekGrid(grid, left: false)
        XCTAssertTrue(sunday.waitForExistence(timeout: 5))
        XCTAssertTrue(sunday.isHittable)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
    }

    @MainActor func testCalendarAllDaySpansShareLanesAcrossWeekDays() {
        let app = launch(qaCase: "all-day-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()

        let workshop = app.buttons.matching(identifier: "Three-day workshop")
        let review = app.buttons.matching(identifier: "Two-day review")
        XCTAssertTrue(workshop.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(review.firstMatch.isHittable)
        XCTAssertEqual(workshop.count, 1)
        XCTAssertEqual(review.count, 1)
        let dayWidth = weekDayWidth(app)
        XCTAssertGreaterThan(workshop.firstMatch.frame.width, 2 * dayWidth - 12)
        XCTAssertGreaterThan(review.firstMatch.frame.width, dayWidth - 12)
        XCTAssertGreaterThan(review.firstMatch.frame.minX, workshop.firstMatch.frame.minX)
        XCTAssertGreaterThanOrEqual(review.firstMatch.frame.minY, workshop.firstMatch.frame.maxY)
        attach(app, "Overlapping all-day spans in Week")

        app.buttons["Calendar view"].tap()
        app.buttons["Multi-Day"].tap()
        XCTAssertEqual(workshop.count, 1)
        XCTAssertEqual(review.count, 1)
        attach(app, "Overlapping all-day spans in Multi-Day")
    }

    @MainActor func testCalendarAllDaySpanDropRetainsItsRange() {
        let app = launch(qaCase: "all-day-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()

        let workshop = app.buttons["Three-day workshop"]
        let grip = app.images["Drag Three-day workshop"]
        XCTAssertTrue(workshop.waitForExistence(timeout: 5))
        XCTAssertTrue(grip.isHittable)
        let dayWidth = weekDayWidth(app)
        let initialX = workshop.frame.minX
        let initialWidth = workshop.frame.width
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let target = app.buttons["calendarDay-2026-11-12"]
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: target.frame.midX - grip.frame.midX, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.25)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(workshop.frame.minX - initialX, 3 * dayWidth, accuracy: 2)
        XCTAssertEqual(workshop.frame.width, initialWidth, accuracy: 2)
        attach(app, "Moved all-day span retains three dates")

        let undo = app.buttons["undoCalendarSchedule"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(workshop.frame.minX, initialX, accuracy: 2)
        XCTAssertEqual(workshop.frame.width, initialWidth, accuracy: 2)
        attach(app, "Undo restores the original three-day span")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(workshop.waitForExistence(timeout: 5))
        XCTAssertEqual(workshop.frame.minX, initialX, accuracy: 2)
        XCTAssertEqual(workshop.frame.width, initialWidth, accuracy: 2)
    }

    @MainActor func testWeekEdgeDragPagesWithoutWritingSchedule() {
        let app = launch(qaCase: "all-day-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        let grid = app.scrollViews["calendarHourlyGrid"]
        let grip = app.images["Drag Three-day workshop"]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.isHittable)
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let edge = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0))
            .withOffset(CGVector(dx: 0, dy: grip.frame.midY - grid.frame.minY))
        let current = app.buttons["calendarDay-2026-11-9"]
        let next = app.buttons["calendarDay-2026-11-16"]
        XCTAssertTrue(current.exists)
        start.press(forDuration: 0.5, thenDragTo: edge, withVelocity: .fast, thenHoldForDuration: 0.05)
        XCTAssertTrue(current.exists)
        XCTAssertTrue(grip.exists)
        XCTAssertFalse(next.exists)
        start.press(forDuration: 0.5, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 1.15)
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(current.exists)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        attach(app, "Week edge hover paged without changing the schedule")
        app.buttons["Previous Calendar period"].tap()
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        let previousEdge = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0))
            .withOffset(CGVector(dx: 0, dy: grip.frame.midY - grid.frame.minY))
        start.press(forDuration: 0.5, thenDragTo: previousEdge, withVelocity: .slow, thenHoldForDuration: 1.15)
        let prior = app.buttons["calendarDay-2026-11-2"]
        XCTAssertTrue(prior.waitForExistence(timeout: 5))
        XCTAssertFalse(current.exists)
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
        app.buttons["Next Calendar period"].tap()
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        let sunday = app.buttons["calendarDay-2026-11-15"]
        XCTAssertTrue(sunday.isHittable)
        XCTAssertTrue(current.exists)
    }

    @MainActor func testWeekAllDayEndResizeUndoAndOneDayHandle() {
        let app = launch(qaCase: "all-day-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        let workshop = app.buttons["Three-day workshop"]
        let handle = app.buttons["Resize end of Three-day workshop"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertTrue(handle.isHittable)
        let dayWidth = weekDayWidth(app)
        let initialWidth = workshop.frame.width
        func resize(by points: CGFloat) {
            let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            grip.press(forDuration: 0.06, thenDragTo: grip.withOffset(CGVector(dx: points, dy: 0)))
        }
        resize(by: dayWidth)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(workshop.frame.width - initialWidth, dayWidth, accuracy: 2)
        attach(app, "Extended Week all-day range")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(workshop.frame.width, initialWidth, accuracy: 2)
        resize(by: -2 * dayWidth)
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertLessThan(workshop.frame.width, dayWidth)
        XCTAssertTrue(handle.isHittable)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertLessThan(workshop.frame.width, dayWidth)
        attach(app, "Resized one-day all-day range retains its handle")
    }

    @MainActor func testWeekAllDayStartResizeClampsAndRestoresOnUndo() {
        let app = launch(qaCase: "all-day-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        let start = app.buttons["Resize start of Three-day workshop"]
        let end = app.buttons["Resize end of Three-day workshop"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(end.isHittable)
        let initialStart = start.frame.minX
        let initialEnd = end.frame.maxX
        let dayWidth = weekDayWidth(app)

        start.tap()
        XCTAssertTrue(app.staticTexts["The end day and reminders stay fixed."].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(start.frame.minX, initialStart, accuracy: 2)
        func resize(by points: CGFloat) {
            let grip = start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            grip.press(forDuration: 0.06, thenDragTo: grip.withOffset(CGVector(dx: points, dy: 0)))
        }
        resize(by: 3 * dayWidth)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(start.frame.minX - initialStart, 2 * dayWidth, accuracy: 2)
        XCTAssertEqual(end.frame.maxX, initialEnd, accuracy: 2)
        XCTAssertLessThanOrEqual(end.frame.maxX - start.frame.minX, dayWidth + 1)
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(end.isHittable)
        attach(app, "Clamped all-day start retains both handles")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(start.frame.minX, initialStart, accuracy: 2)
        resize(by: dayWidth)
        XCTAssertEqual(notice.label, "Schedule updated")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.frame.minX - initialStart, dayWidth, accuracy: 2)
        XCTAssertEqual(end.frame.maxX, initialEnd, accuracy: 2)
        attach(app, "Resized Week all-day start after relaunch")
    }

    @MainActor func testMonthAllDayStartResizeUsesOnlyTrueEdgeAcrossWeekRow() {
        let app = launch(qaCase: "month-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let retreat = app.buttons.matching(identifier: "Weekend retreat")
        let starts = app.buttons.matching(identifier: "Resize start of Weekend retreat")
        let ends = app.buttons.matching(identifier: "Resize end of Weekend retreat")
        XCTAssertTrue(starts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(starts.count, 1)
        XCTAssertEqual(ends.count, 1)
        XCTAssertEqual(retreat.count, 2)
        XCTAssertFalse(app.buttons["Resize start of Weekend call"].exists)
        starts.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Resize Start"].waitForExistence(timeout: 5))
        app.buttons["calendarEditCancel"].tap()
        waitGone(app.buttons["calendarEditDone"])
        let target = app.staticTexts["calendarMonthDay-2026-11-16"]
        XCTAssertTrue(target.isHittable)
        let from = starts.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = target.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.65))
        from.press(forDuration: 0.06, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(retreat.count, 1)
        XCTAssertEqual(starts.count, 1)
        XCTAssertEqual(ends.count, 1)
        attach(app, "Month all-day start moved to the next week row")
    }

    @MainActor func testMonthAllDayEndResizeCrossesWeekRow() {
        let app = launch(qaCase: "month-spans")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let retreat = app.buttons.matching(identifier: "Weekend retreat")
        let handles = app.buttons.matching(identifier: "Resize end of Weekend retreat")
        XCTAssertTrue(handles.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(handles.count, 1)
        XCTAssertEqual(retreat.count, 2)
        let target = app.staticTexts["calendarMonthDay-2026-11-15"]
        XCTAssertTrue(target.isHittable)
        let from = handles.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = target.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.65))
        from.press(forDuration: 0.06, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(retreat.count, 1)
        attach(app, "Month all-day end moved to the previous week row")
    }

    @MainActor func testCalendarAllDayRowsScrollAndSurviveRelaunch() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let overflow = app.scrollViews["calendarAllDayOverflow"]
        XCTAssertFalse(overflow.exists)

        let rows = app.buttons["calendarAllDayRows"]
        openCalendarViewOptions(app)
        reveal(rows, in: app)
        rows.tap()
        app.buttons["2 rows"].tap()
        app.buttons["calendarPreferencesDone"].tap()
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        let laterTask = overflow.buttons["Book time for a walk"]
        XCTAssertFalse(laterTask.isHittable)
        for _ in 0..<6 where !laterTask.isHittable { overflow.swipeUp() }
        XCTAssertTrue(laterTask.isHittable)
        attach(app, "All-day overflow in two rows")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        openCalendarViewOptions(app)
        reveal(rows, in: app)
        XCTAssertTrue(rows.label.contains("2 rows") || (rows.value as? String) == "2 rows")
        rows.tap()
        app.buttons["Automatic"].tap()
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(overflow.exists)
    }

    @MainActor func testCalendarFoldCutoffsDragAndPreferenceSurviveRelaunch() {
        let app = launch(qaCase: "folded-hours")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let early = app.buttons["calendarHourBand-early"], late = app.buttons["calendarHourBand-late"]
        let marker = app.descendants(matching: .any)["calendarFoldCutoff-early"].firstMatch
        XCTAssertFalse(marker.exists)
        early.tap()
        XCTAssertFalse(marker.exists)
        late.tap()
        reveal(marker, in: app)
        XCTAssertEqual(marker.value as? String, "07:00")
        let handle = marker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.06, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -52)))
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "06:00"), object: marker)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 8), .completed)
        attach(app, "Early cutoff moved to 06:00")
        early.tap()
        late.tap()
        let earlierTask = app.buttons["Read a chapter"]
        XCTAssertTrue(earlierTask.waitForExistence(timeout: 5))
        XCTAssertFalse(marker.exists)

        openCalendarViewOptions(app)
        let latePreference = app.buttons["calendarFoldPreference-late"]
        reveal(latePreference, in: app)
        latePreference.tap()
        let later = app.buttons["22:00"]
        reveal(later, in: app)
        later.tap()
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(earlierTask.waitForExistence(timeout: 5))
        openCalendarViewOptions(app)
        reveal(latePreference, in: app)
        XCTAssertTrue(latePreference.label.contains("22:00") || (latePreference.value as? String) == "22:00")
        let reset = app.buttons["Reset Folded Hours"]
        reveal(reset, in: app)
        reset.tap()
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(earlierTask.exists)
    }

    @MainActor func testCalendarTaskAndNoteIconsStayIndependentAcrossRelaunch() {
        let app = launch(qaCase: "lifecycle")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let task = app.buttons["Review the project outline"], note = app.buttons["Book time for a walk"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertTrue(note.exists)
        attach(app, "Task and note icons shown")
        openCalendarViewOptions(app)
        calendarIconOptions(app)
        setSwitch("calendarTaskIcons", to: false, app: app)
        XCTAssertEqual(app.switches["calendarNoteIcons"].value as? String, "1")
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(task.exists && note.exists)
        attach(app, "Only note icons shown")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        calendarIconOptions(app)
        XCTAssertEqual(app.switches["calendarTaskIcons"].value as? String, "0")
        XCTAssertEqual(app.switches["calendarNoteIcons"].value as? String, "1")
        setSwitch("calendarIcons", to: false, app: app)
        XCTAssertFalse(app.switches["calendarTaskIcons"].isEnabled)
        XCTAssertFalse(app.switches["calendarNoteIcons"].isEnabled)
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])

        openCalendarViewOptions(app)
        calendarIconOptions(app)
        XCTAssertEqual(app.switches["calendarIcons"].value as? String, "1")
        setSwitch("calendarTaskIcons", to: true, app: app)
        setSwitch("calendarNoteIcons", to: false, app: app)
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(task.exists && note.exists)
        attach(app, "Only task icons shown")
    }

    @MainActor func testCalendarAgendaCompletesChecklistAndUsesTaskLifecycleUndo() {
        let app = launch(qaCase: "calendar-completion")
        app.buttons["Calendar"].tap()
        let check = app.buttons["Complete Review the first step"]
        let reopen = app.buttons["Reopen Review the first step"]
        let parent = app.buttons["Review the project outline"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(check.frame.height, 44)
        XCTAssertGreaterThanOrEqual(check.frame.width, 44)
        check.tap()
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        XCTAssertTrue(parent.exists)
        XCTAssertTrue(app.buttons["Complete Keep the second step"].exists)
        attach(app, "Completed checklist item in Agenda")
        reopen.tap()
        XCTAssertTrue(check.waitForExistence(timeout: 5))

        let title = "Prepare the weekly plan"
        let completeTask = app.buttons["Complete " + title]
        let reopenTask = app.buttons["Reopen " + title]
        reveal(completeTask, in: app)
        completeTask.tap()
        XCTAssertTrue(reopenTask.waitForExistence(timeout: 5))
        let feedback = app.staticTexts["lifecycleFeedback"]
        XCTAssertEqual(feedback.label, "Task completed")
        app.buttons["undoLifecycle"].tap()
        XCTAssertTrue(completeTask.waitForExistence(timeout: 5))
        XCTAssertEqual(feedback.label, "Change undone")
        reveal(completeTask, in: app)
        completeTask.tap()
        XCTAssertTrue(reopenTask.waitForExistence(timeout: 5))
        reveal(reopenTask, in: app)
        reopenTask.tap()
        XCTAssertTrue(completeTask.waitForExistence(timeout: 5))
        XCTAssertEqual(feedback.label, "Task reopened")

        reveal(check, in: app, towardTop: true)
        check.tap()
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        XCTAssertTrue(completeTask.exists)
        XCTAssertFalse(app.buttons["undoLifecycle"].exists)
        attach(app, "Agenda completion after relaunch")
    }

    @MainActor func testCalendarChecklistMenuWorksWithHiddenIconsAndCompletedRows() {
        let app = launch(qaCase: "calendar-completion")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        calendarIconOptions(app)
        setSwitch("calendarTaskIcons", to: false, app: app)
        calendarOptionsRoot(app)
        setSwitch("calendarCompleted", to: false, app: app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])

        let title = "Review the first step"
        let card = app.buttons[title]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Complete " + title].exists)
        card.press(forDuration: 0.75)
        let complete = app.buttons["Complete checklist item"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Edit Calendar Schedule"].exists)
        attach(app, "Checklist menu with hidden icons")
        complete.tap()
        waitGone(card)
        XCTAssertTrue(app.buttons["Review the project outline"].exists)

        openCalendarViewOptions(app)
        calendarIconOptions(app)
        calendarOptionsRoot(app)
        setSwitch("calendarCompleted", to: true, app: app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 0.75)
        let reopen = app.buttons["Reopen checklist item"]
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        reopen.tap()
        waitGone(reopen)

        let forecast = app.buttons.matching(identifier: title + ", recurring preview").firstMatch
        reveal(forecast, in: app)
        forecast.press(forDuration: 0.75)
        XCTAssertFalse(complete.exists)
        XCTAssertFalse(reopen.exists)
        XCTAssertFalse(app.buttons["Edit Calendar Schedule"].exists)
        attach(app, "Read-only checklist forecast")
    }

    @MainActor func testCalendarShowDetailsStagesAndPersistsAcrossAgendaAndMonth() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        func mode(_ name: String) {
            app.buttons["Calendar view"].tap()
            app.buttons[name].tap()
        }
        let timed = app.buttons["Prepare the weekly plan"]
        let allDay = app.buttons["Arrange the studio"]
        func expectTimedDetails() {
            XCTAssertTrue(timed.waitForExistence(timeout: 5))
            let value = timed.value as? String ?? ""
            XCTAssertTrue(value.contains("Work") && value.contains(":00"), value)
            XCTAssertTrue(value.contains(" – "), value)
        }
        mode("Agenda")
        XCTAssertTrue(timed.waitForExistence(timeout: 5))
        XCTAssertFalse((timed.value as? String ?? "").contains("Work"))

        openCalendarViewOptions(app)
        setSwitch("calendarDetails", to: true, app: app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse((timed.value as? String ?? "").contains("Work"))

        openCalendarViewOptions(app)
        setSwitch("calendarDetails", to: true, app: app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        expectTimedDetails()
        XCTAssertEqual(allDay.value as? String, "All day · Inbox")
        attach(app, "Calendar Agenda time and list details")

        mode("Day")
        XCTAssertTrue(timed.waitForExistence(timeout: 5))
        XCTAssertFalse((timed.value as? String ?? "").contains("Work"))
        mode("Month")
        for _ in 0..<3 { app.buttons["Zoom Month in"].tap() }
        expectTimedDetails()
        attach(app, "Calendar Month detail labels")
        mode("Agenda")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        expectTimedDetails()
        openCalendarViewOptions(app)
        setSwitch("calendarDetails", to: false, app: app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        expectTimedDetails()
        mode("Week")
        XCTAssertTrue(app.descendants(matching: .any)["calendarHourlyGrid"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarYearDayPreviewStaysInYearAndCanOpenWeek() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Year"].tap()
        let year = app.descendants(matching: .any)["calendarYearHeatmap"].firstMatch
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        let done = app.buttons["calendarYearPreviewDone"]
        let empty = app.buttons["calendarYearDay-2026-1-1"]
        reveal(empty, in: app)
        empty.tap()
        XCTAssertTrue(app.staticTexts["No scheduled items for this date"].waitForExistence(timeout: 5))
        done.tap()
        waitGone(done)
        XCTAssertTrue(empty.isHittable)

        let filled = app.buttons["calendarYearDay-2026-11-9"]
        reveal(filled, in: app)
        filled.tap()
        XCTAssertTrue(app.staticTexts["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Review the project outline"].exists)
        attach(app, "Year Calendar preview with local items")
        done.tap()
        waitGone(done)
        XCTAssertTrue(year.exists)
        XCTAssertTrue(filled.isHittable)
        filled.tap()
        app.buttons["calendarYearPreviewOpenWeek"].tap()
        let week = app.descendants(matching: .any)["calendarHourlyGrid"].firstMatch
        XCTAssertTrue(week.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarViewOptionsRenderAndPersistAcrossRelaunch() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        let completed = app.buttons["Arrange the studio"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        openCalendarViewOptions(app)
        app.buttons["calendarColorPage"].tap()
        app.buttons["calendarColor"].tap()
        app.buttons["calendarColorMode-priority"].tap()
        calendarOptionsRoot(app)
        app.buttons["calendarStylePage"].tap()
        let legacyStyle = app.buttons["calendarLegacyStyle"]
        reveal(legacyStyle, in: app)
        legacyStyle.tap()
        app.buttons["calendarLegacyStyle-outline"].tap()
        let outlineNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Current saved style: Outline (Legacy)")).firstMatch
        XCTAssertTrue(outlineNote.waitForExistence(timeout: 5))
        app.buttons["calendarYearStyle-hide"].tap()
        app.buttons["calendarIconsPage"].tap()
        setSwitch("calendarIcons", to: false, app: app)
        calendarOptionsRoot(app)
        setSwitch("calendarCompleted", to: false, app: app)
        setSwitch("calendarChecklist", to: true, app: app)
        setSwitch("calendarRepeats", to: false, app: app)
        attach(app, "Calendar options staged")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse(completed.exists)
        XCTAssertTrue(app.buttons["Review the first step"].waitForExistence(timeout: 5))
        attach(app, "Calendar after saving appearance and visibility")
        app.buttons["Calendar view"].tap()
        app.buttons["Year"].tap()
        let standard = app.descendants(matching: .any)["calendarYearStandard"].firstMatch
        XCTAssertTrue(standard.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(standard.waitForExistence(timeout: 5))
        attach(app, "Saved Year Standard view")
    }

    /// C10 Style tiles: Modern/Classic save and relaunch with actual rendered
    /// Week screenshots, Back retains the staged draft, outer Cancel discards
    /// it, Year Show/Hide assert the actual grid mode, and a saved legacy
    /// style stays selected until explicitly changed.
    @MainActor func testCalendarStyleTilesSaveModernClassicAndLegacyAcrossRelaunch() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["Arrange the studio"].waitForExistence(timeout: 5))
        // Modern: select, Back retains the draft, outer Done saves it.
        openCalendarViewOptions(app)
        app.buttons["calendarStylePage"].tap()
        XCTAssertTrue(app.buttons["calendarItemStyle-modern"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["calendarItemStyle-classic"].exists)
        XCTAssertTrue(app.buttons["calendarYearStyle-show"].exists)
        XCTAssertTrue(app.buttons["calendarYearStyle-hide"].exists)
        app.buttons["calendarItemStyle-modern"].tap()
        app.buttons["calendarYearStyle-show"].tap()
        attach(app, "Style tiles staged Modern and Show")
        calendarOptionsRoot(app)
        XCTAssertTrue(app.navigationBars["Calendar View Options"].exists)
        app.buttons["calendarStylePage"].tap()
        XCTAssertEqual(app.buttons["calendarItemStyle-modern"].value as? String, "Selected")
        app.buttons["calendarYearStyle-show"].tap()
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        // Year Show uses the actual heatmap mode with shading; task data is unchanged.
        app.buttons["Calendar view"].tap()
        app.buttons["Year"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendarYearHeatmap"].waitForExistence(timeout: 5))
        attach(app, "Year rendered with Show heatmap")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendarYearHeatmap"].waitForExistence(timeout: 5))
        // Actual rendered Week under Modern, not just the selected tile.
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        XCTAssertTrue(app.scrollViews["calendarHourlyGrid"].waitForExistence(timeout: 5))
        attach(app, "Week rendered with Modern style")
        // Classic: staged Back retention, then outer Cancel discards the change.
        openCalendarViewOptions(app)
        app.buttons["calendarStylePage"].tap()
        XCTAssertEqual(app.buttons["calendarItemStyle-modern"].value as? String, "Selected")
        app.buttons["calendarItemStyle-classic"].tap()
        calendarOptionsRoot(app)
        app.buttons["calendarStylePage"].tap()
        XCTAssertEqual(app.buttons["calendarItemStyle-classic"].value as? String, "Selected")
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        openCalendarViewOptions(app)
        app.buttons["calendarStylePage"].tap()
        XCTAssertEqual(app.buttons["calendarItemStyle-modern"].value as? String, "Selected")
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        // Classic saves together with Hide; actual Week and Year Standard follow.
        openCalendarViewOptions(app)
        app.buttons["calendarStylePage"].tap()
        app.buttons["calendarItemStyle-classic"].tap()
        app.buttons["calendarYearStyle-hide"].tap()
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        app.buttons["Calendar view"].tap()
        app.buttons["Week"].tap()
        XCTAssertTrue(app.scrollViews["calendarHourlyGrid"].waitForExistence(timeout: 5))
        attach(app, "Week rendered with Classic style")
        app.buttons["Calendar view"].tap()
        app.buttons["Year"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendarYearStandard"].waitForExistence(timeout: 5))
        attach(app, "Year rendered with Hide standard dots")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendarYearStandard"].waitForExistence(timeout: 5))
        openCalendarViewOptions(app)
        app.buttons["calendarStylePage"].tap()
        XCTAssertEqual(app.buttons["calendarItemStyle-classic"].value as? String, "Selected")
        // A saved legacy style stays honest on reopen across relaunch.
        // The menu picker opens a fresh anchored menu, immune to the
        // below-fold row-tap mis-delivery seen with bespoke buttons.
        let legacy = app.buttons["calendarLegacyStyle"]
        reveal(legacy, in: app)
        legacy.tap()
        app.buttons["calendarLegacyStyle-filled"].tap()
        // The menu picker's staged choice surfaces in the honest saved-style
        // note, which is the user-visible proof of the staged selection.
        let stagedNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Current saved style: Filled (Legacy)")).firstMatch
        XCTAssertTrue(stagedNote.waitForExistence(timeout: 5))
        calendarOptionsRoot(app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        app.buttons["calendarStylePage"].tap()
        let savedNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Current saved style: Filled (Legacy)")).firstMatch
        XCTAssertTrue(savedNote.waitForExistence(timeout: 5))
        attach(app, "Legacy Filled style preserved across relaunch")
    }

    @MainActor func testCalendarRulersStageNamedZonesAndKeepFourRulerLimit() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        let zoneSettings = app.buttons["calendarZoneSettings"]
        reveal(zoneSettings, in: app)
        zoneSettings.tap()
        let newYork = app.textFields["calendarZoneLabel-America/New_York"]
        XCTAssertTrue(newYork.waitForExistence(timeout: 5))
        newYork.tap()
        newYork.typeText("Temporary")
        app.buttons["calendarZonesCancel"].tap()
        waitGone(newYork)
        zoneSettings.tap()
        XCTAssertTrue(newYork.waitForExistence(timeout: 5))
        XCTAssertNotEqual(newYork.value as? String, "Temporary")
        for (query, label) in [("London", "Europe/London"), ("Paris", "Europe/Paris")] {
            let add = app.buttons["calendarZoneAdd"]
            reveal(add, in: app)
            add.tap()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText(query)
            let choice = app.buttons[label]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            waitGone(search)
        }
        XCTAssertFalse(app.buttons["calendarZoneAdd"].isEnabled)
        let london = app.textFields["calendarZoneLabel-Europe/London"]
        reveal(london, in: app)
        london.tap()
        london.typeText("UK")
        app.buttons["calendarZonesDone"].tap()
        waitGone(london)
        openCalendarZoneSettings(app)
        setSwitch("calendarAdditionalZones", to: true, app: app)
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        let ruler = app.staticTexts["calendarRuler-Europe/London"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        XCTAssertTrue(ruler.label.contains("UK"))
        XCTAssertTrue(app.staticTexts["calendarRuler-Europe/Paris"].exists)
        attach(app, "Four secondary Calendar rulers")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        XCTAssertTrue(ruler.label.contains("UK"))
    }

    @MainActor func testCalendarPreferenceSaveFailureRetainsDraft() {
        let app = launch(qaCase: "save-failure")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        setSwitch("calendarCompleted", to: false, app: app)
        app.buttons["calendarPreferencesDone"].tap()
        XCTAssertTrue(app.staticTexts["calendarPreferenceError"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["calendarCompleted"].value as? String, "0")
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        openCalendarViewOptions(app)
        XCTAssertEqual(app.switches["calendarCompleted"].value as? String, "1")
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        XCTAssertTrue(app.staticTexts["Day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["calendarPreferenceNotice"].label.contains("for this session"))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Week"].waitForExistence(timeout: 5))
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testRichHeadingCollapseKeepsTheFullEditableDescription() {
        let app = launch(qaCase: "rich-preview")
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        let original = description.value as? String ?? ""
        XCTAssertTrue(original.contains("Check e\u{301} 🧩 with care"))
        let heading = app.buttons["richFoldHeading-0"]
        reveal(heading, in: app)
        XCTAssertEqual(heading.label, "Collapse Launch plan")
        heading.tap()
        XCTAssertEqual(heading.label, "Expand Launch plan")
        XCTAssertEqual(description.value as? String, "Launch plan\n")
        attach(app, "Collapsed description heading")
        heading.tap()
        XCTAssertTrue((description.value as? String)?.utf16.elementsEqual(original.utf16) == true)
        heading.tap()

        let format = app.buttons["editRichDescription"]
        reveal(format, in: app)
        format.tap()
        let editor = app.textViews["richFieldEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String)?.utf16.elementsEqual(original.utf16) == true)
        app.buttons["fieldEditorDone"].tap()
        waitGone(editor)
        app.buttons["taskDetailDone"].tap()
        task.tap()
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertTrue((description.value as? String)?.utf16.elementsEqual(original.utf16) == true)
    }

    @MainActor func testRichDescriptionRendersExactTextAndSurvivesTitleEdit() {
        let app = launch(qaCase: "rich-preview")
        let title = "Review the project outline"
        let expected = ["Launch plan", "Check e\u{301} 🧩 with care", "Draft the outline", "Review the checklist",
                        "Keep decisions together", "Collect references", "Bring notes", "", "Reference link"].joined(separator: "\n")
        app.buttons[title].tap()
        let description = app.textViews["richTaskDescription"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        let rendered = description.value as? String
        XCTAssertTrue(rendered?.utf16.elementsEqual(expected.utf16) == true)
        app.swipeUp()
        attach(app, "Rich description and paragraph decorations")
        app.buttons["editTitle"].tap()
        let input = app.textViews["fieldEditor"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText(" with formatting")
        app.buttons["fieldEditorDone"].tap()
        waitGone(input)
        app.buttons["taskDetailDone"].tap()
        app.terminate()
        app.launch()
        let renamed = app.buttons[title + " with formatting"]
        XCTAssertTrue(renamed.waitForExistence(timeout: 10))
        renamed.tap()
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        XCTAssertTrue((description.value as? String)?.utf16.elementsEqual(expected.utf16) == true)
    }

    @MainActor func testMalformedRichDescriptionShowsItsSavedPlainBody() {
        let app = launch(qaCase: "malformed-rich")
        app.buttons["Review the project outline"].tap()
        let fallback = app.staticTexts["richDescriptionFallback"]
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["taskDescription"].exists)
        XCTAssertFalse(app.textViews["richTaskDescription"].exists)
        XCTAssertFalse(app.buttons["Edit description"].isEnabled)
        XCTAssertFalse(app.buttons["editRichDescription"].exists)
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openTaskMetadata(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        reveal(button, in: app)
        button.tap()
        let presented = identifier == "editTaskPriority" ? app.buttons["taskPriority-high"] : app.buttons["taskMetadataCancel"]
        XCTAssertTrue(presented.waitForExistence(timeout: 5))
    }

    @MainActor func testTaskPriorityAndTagsPersistWithoutChangingDescription() {
        let app = launch(qaCase: "task-metadata"), task = "Review the project outline"
        app.buttons[task].tap()
        openTaskMetadata("editTaskPriority", in: app)
        app.buttons["taskPriority-high"].tap()
        waitGone(app.buttons["taskPriority-high"])
        XCTAssertEqual(app.buttons["editTaskPriority"].value as? String, "High")
        openTaskMetadata("editTaskTags", in: app)
        let search = app.textFields["searchTaskTags"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Plan")
        let tag = app.buttons["taskTag-00000000-0000-0000-0000-000000000200"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        tag.tap()
        XCTAssertEqual(tag.value as? String, "Selected")
        app.buttons["taskMetadataDone"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        XCTAssertEqual(app.buttons["editTaskTags"].value as? String, "Planning, 1 unavailable")
        attach(app, "Saved priority and tags")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[task].waitForExistence(timeout: 10))
        app.buttons[task].tap()
        reveal(app.buttons["editTaskPriority"], in: app)
        XCTAssertEqual(app.buttons["editTaskPriority"].value as? String, "High")
        XCTAssertEqual(app.buttons["editTaskTags"].value as? String, "Planning, 1 unavailable")
        XCTAssertTrue(app.textViews["richTaskDescription"].exists)
    }

    @MainActor func testTaskProgressSavesFromCheckboxAndTracksChecklistAfterRelaunch() {
        let app = launch(qaCase: "calendar-options")
        let manualTask = app.buttons["Prepare the weekly plan"]
        let checklistTask = app.buttons["Review the project outline"]
        let edit = app.buttons["editTaskProgress"]
        let done = app.buttons["taskMetadataDone"]
        let slider = app.sliders["taskProgressSlider"]
        let draftValue = app.staticTexts["taskProgressDraftValue"]
        let detailDone = app.buttons["taskDetailDone"]

        manualTask.tap()
        XCTAssertTrue(app.buttons["editSchedule"].waitForExistence(timeout: 5))
        XCTAssertFalse(edit.exists)
        attach(app, "Ordinary task without idle zero progress")
        let detailCompletion = app.scrollViews.containing(.button, identifier: "editSchedule")
            .buttons["lifecycleToggle-00000000-0000-0000-0000-000000000002"].firstMatch
        detailCompletion.press(forDuration: 0.75)
        let detailProgressMenu = app.buttons["Set Progress"]
        XCTAssertTrue(detailProgressMenu.waitForExistence(timeout: 5))
        detailProgressMenu.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertNotEqual(draftValue.label, "0%")
        app.buttons["taskMetadataCancel"].tap()
        app.buttons["Discard Changes"].tap()
        waitGone(slider)
        XCTAssertFalse(edit.exists)
        detailDone.tap()

        let completion = app.buttons["lifecycleToggle-00000000-0000-0000-0000-000000000002"]
        reveal(completion, in: app)
        completion.press(forDuration: 0.75)
        let progressMenu = app.buttons["Set Progress"]
        XCTAssertTrue(progressMenu.waitForExistence(timeout: 5))
        progressMenu.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.98)
        let nearEnd = Int(draftValue.label.dropLast()) ?? -1
        XCTAssertTrue((96..<100).contains(nearEnd))
        let increment = app.steppers["taskProgressStepper"].buttons["taskProgressStepper-Increment"]
        XCTAssertTrue(increment.exists)
        if (96..<100).contains(nearEnd) {
            for _ in nearEnd..<100 { increment.tap() }
        }
        XCTAssertEqual(draftValue.label, "100%")
        attach(app, "Task progress draft at 100 percent")
        done.tap()
        waitGone(slider)
        XCTAssertEqual(completion.label, "Complete Prepare the weekly plan")

        app.terminate()
        app.launch()
        XCTAssertTrue(manualTask.waitForExistence(timeout: 10))
        manualTask.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertEqual(edit.value as? String, "100%")
        attach(app, "Manual task progress after relaunch")
        edit.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(draftValue.label, "0%")
        done.tap()
        waitGone(slider)
        XCTAssertFalse(edit.exists)
        detailDone.tap()
        manualTask.tap()
        XCTAssertTrue(app.buttons["editSchedule"].waitForExistence(timeout: 5))
        XCTAssertFalse(edit.exists)
        detailDone.tap()

        checklistTask.tap()
        let summary = app.descendants(matching: .any)["taskProgressSummary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.value as? String, "0%")
        XCTAssertFalse(edit.exists)
        let item = app.buttons["checklistToggle-00000000-0000-0000-0000-000000000501"]
        reveal(item, in: app)
        item.tap()
        XCTAssertEqual(item.value as? String, "Checked")
        reveal(summary, in: app, towardTop: true)
        XCTAssertEqual(summary.value as? String, "100%")
        attach(app, "Progress computed from checklist")
    }

    @MainActor func testEmbeddedChecklistEditsAndCalendarReflectSavedItems() {
        let app = launch(qaCase: "task-metadata"), task = "Review the project outline"
        let first = "00000000-0000-0000-0000-000000000501"
        let second = "00000000-0000-0000-0000-000000000502"
        app.buttons[task].tap()
        let toggle = app.buttons["checklistToggle-" + first]
        reveal(toggle, in: app)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "Checked")

        openTaskMetadata("editTaskChecklist", in: app)
        let draft = app.textViews["checklistItem-" + first]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.tap()
        draft.typeText(" reviewed")
        app.buttons["removeChecklistItem-" + second].tap()
        let newEntry = app.textViews["newChecklistItem"]
        reveal(newEntry, in: app)
        newEntry.tap()
        newEntry.typeText("Bring a note\n")
        let added = app.textViews.matching(NSPredicate(format: "value == %@", "Bring a note")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertNotEqual(newEntry.value as? String, "Bring a note")
        app.buttons["taskMetadataDone"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        XCTAssertEqual(toggle.label, "Uncheck First step reviewed")
        XCTAssertFalse(app.buttons["checklistToggle-" + second].exists)
        XCTAssertTrue(app.buttons["Check Bring a note"].exists)
        attach(app, "Saved embedded checklist")
        app.buttons["taskDetailDone"].tap()
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        setSwitch("calendarChecklist", to: true, app: app)
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(app.buttons["First step reviewed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bring a note"].exists)
        XCTAssertFalse(app.buttons["Second step"].exists)
        attach(app, "Calendar inherited checklist items")
    }

    @MainActor func testChecklistDiscardLeavesSavedItemsIntact() {
        let app = launch(qaCase: "task-metadata"), id = "00000000-0000-0000-0000-000000000501"
        app.buttons["Review the project outline"].tap()
        openTaskMetadata("editTaskChecklist", in: app)
        let field = app.textViews["checklistItem-" + id]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(" unsaved")
        app.buttons["taskMetadataCancel"].tap()
        let keep = app.buttons["Keep Editing"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()
        XCTAssertEqual(field.value as? String, "First step unsaved")
        app.buttons["taskMetadataCancel"].tap()
        app.buttons["Discard Changes"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        XCTAssertEqual(app.buttons["checklistToggle-" + id].label, "Check First step")
    }

    @MainActor func testChecklistWriteFailureKeepsDraft() {
        let app = launch(qaCase: "save-failure")
        app.buttons["Review the project outline"].tap()
        openTaskMetadata("editTaskChecklist", in: app)
        let field = app.textViews["newChecklistItem"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Unsaved entry")
        app.buttons["taskMetadataDone"].tap()
        XCTAssertTrue(app.staticTexts["taskMetadataError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value == %@", "Unsaved entry")).firstMatch.exists)
        app.buttons["taskMetadataCancel"].tap()
        app.buttons["Discard Changes"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        XCTAssertFalse(app.buttons["Check Unsaved entry"].exists)
    }

    @MainActor func testLinkedSubtaskDisclosurePreservesNestedStateAndOtherScopes() {
        let app = launch(qaCase: "subtask-disclosure")
        goTo("Work", in: app)
        let parent = app.buttons["taskSubtreeDisclosure-00000000-0000-0000-0000-000000000001"]
        let nested = app.buttons["taskSubtreeDisclosure-00000000-0000-0000-0000-000000000004"]
        let child = app.buttons["Arrange the studio"]
        let grandchild = app.buttons["Book time for a walk"]
        let sibling = app.buttons["Review the draft"]
        reveal(nested, in: app)
        XCTAssertEqual(parent.value as? String, "Expanded")
        XCTAssertTrue(grandchild.exists)
        nested.tap()
        waitGone(grandchild)
        XCTAssertEqual(nested.value as? String, "Collapsed")
        XCTAssertTrue(sibling.exists)
        reveal(parent, in: app)
        parent.tap()
        waitGone(child)
        XCTAssertFalse(sibling.exists)
        XCTAssertEqual(parent.value as? String, "Collapsed")

        app.buttons["taskListActions"].tap()
        app.buttons["batchOpen"].tap()
        let hiddenSelection = app.buttons["batchTask-00000000-0000-0000-0000-000000000007"]
        reveal(hiddenSelection, in: app)
        XCTAssertTrue(hiddenSelection.exists)
        app.buttons["batchBack"].tap()
        waitGone(hiddenSelection)

        goTo("Today", in: app)
        XCTAssertTrue(grandchild.waitForExistence(timeout: 5))
        XCTAssertFalse(parent.exists)
        goTo("Work", in: app)
        reveal(parent, in: app)
        XCTAssertEqual(parent.value as? String, "Collapsed")
        parent.tap()
        XCTAssertTrue(child.waitForExistence(timeout: 5))
        XCTAssertTrue(sibling.exists)
        XCTAssertFalse(grandchild.exists)
        XCTAssertEqual(nested.value as? String, "Collapsed")
        attach(app, "Reopened parent retains its nested fold")
        reveal(nested, in: app)
        nested.tap()
        XCTAssertTrue(grandchild.waitForExistence(timeout: 5))
        reveal(parent, in: app)
        parent.tap()
        waitGone(child)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        reveal(parent, in: app)
        XCTAssertEqual(parent.value as? String, "Expanded")
        XCTAssertTrue(child.exists)
        XCTAssertTrue(grandchild.exists)
    }

    @MainActor func testLinkedSubtaskCreationAndIndependentCompletionPersist() {
        let app = launch(qaCase: "task-metadata"), root = "Review the project outline"
        let child = "Gather a folder"
        app.buttons[root].tap()
        openHierarchy("addSubtask", in: app)
        let title = app.textViews["newSubtaskTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskHierarchyDone"].isEnabled)
        title.typeText(child)
        app.buttons["taskHierarchyDone"].tap()
        waitGone(app.buttons["taskHierarchyDone"])
        let progress = app.staticTexts["subtaskProgress"]
        reveal(progress, in: app)
        XCTAssertEqual(progress.label, "0 of 2")
        let checkbox = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                                         "subtaskToggle-", "Complete " + child)).firstMatch
        reveal(checkbox, in: app)
        checkbox.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "subtaskProgress", "1 of 2")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["lifecycleFeedback"].label, "Subtask completed")
        attach(app, "Linked subtask progress")
        let open = app.buttons["Open subtask " + child]
        reveal(open, in: app)
        let detailTitle = app.buttons["editTitle"]
        let childOpened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Edit title, " + child),
                                                    object: detailTitle)
        open.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [childOpened], timeout: 5), .completed)
        let parent = app.buttons["openParentTask"]
        reveal(parent, in: app)
        let parentOpened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Edit title, " + root),
                                                     object: detailTitle)
        parent.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [parentOpened], timeout: 5), .completed)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[root].waitForExistence(timeout: 10))
        app.buttons[root].tap()
        reveal(progress, in: app)
        XCTAssertEqual(progress.label, "1 of 2")
        XCTAssertTrue(app.textViews["richTaskDescription"].exists)
    }

    @MainActor func testLinkedSubtaskCrossListMoveExcludesDescendantsAndSurvivesRelaunch() {
        let app = launch(qaCase: "task-metadata"), root = "Review the project outline"
        let candidate = "parentChoice-00000000-0000-0000-0000-000000000002"
        app.buttons[root].tap()
        openHierarchy("editParentTask", in: app)
        let search = app.textFields["Search tasks or lists"]
        search.tap()
        search.typeText("Arrange the studio")
        XCTAssertTrue(app.staticTexts["No matching parent tasks"].waitForExistence(timeout: 5))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Arrange the studio".count) + "weekly")
        let parent = app.buttons[candidate]
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        parent.tap()
        let summary = app.staticTexts["parentMoveSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "This task and its subtasks will move to Work.")
        attach(app, "Cross list subtask confirmation")
        app.buttons["taskHierarchyDone"].tap()
        waitGone(app.buttons["taskHierarchyDone"])
        reveal(app.buttons["openParentTask"], in: app)
        XCTAssertEqual(app.buttons["openParentTask"].label, "Subtask of Prepare the weekly plan")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        let listParent = app.buttons["Prepare the weekly plan"]
        XCTAssertTrue(listParent.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[root].exists)
        XCTAssertTrue(app.buttons["Arrange the studio"].exists)
        attach(app, "Nested Work tasks after relaunch")
    }

    @MainActor func testLinkedSubtaskCanDiscardAndDetachWithoutChangingChecklist() {
        let app = launch(qaCase: "task-metadata")
        app.buttons["Review the project outline"].tap()
        let child = app.buttons["openSubtask-00000000-0000-0000-0000-000000000004"]
        reveal(child, in: app)
        child.tap()
        openHierarchy("editParentTask", in: app)
        app.buttons["parentChoice-top"].tap()
        app.buttons["taskHierarchyCancel"].tap()
        app.buttons["Discard Changes"].tap()
        waitGone(app.buttons["taskHierarchyDone"])
        XCTAssertTrue(app.buttons["openParentTask"].exists)
        openHierarchy("editParentTask", in: app)
        app.buttons["parentChoice-top"].tap()
        app.buttons["taskHierarchyDone"].tap()
        waitGone(app.buttons["taskHierarchyDone"])
        XCTAssertFalse(app.buttons["openParentTask"].exists)
        app.buttons["relatedTaskBack"].tap()
        XCTAssertFalse(child.exists)
        XCTAssertTrue(app.buttons["checklistToggle-00000000-0000-0000-0000-000000000501"].exists)
    }

    @MainActor private func openHierarchy(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        reveal(button, in: app)
        button.tap()
        XCTAssertTrue(app.buttons["taskHierarchyCancel"].waitForExistence(timeout: 5))
    }

    @MainActor func testListEmojiPrefixAndExplicitIconPersistAcrossRelaunch() {
        let app = launch()
        let lab = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "manageList-", "Lab")).firstMatch
        let emoji = app.textFields["organizationCustomEmoji"]
        let done = app.buttons["organizationSave"]
        func editLab() {
            reveal(lab, in: app)
            lab.tap()
            reveal(emoji, in: app)
            XCTAssertTrue(emoji.waitForExistence(timeout: 5))
        }
        func replaceEmoji(_ next: String) {
            emoji.tap()
            emoji.typeText(XCUIKeyboardKey.delete.rawValue + next)
            XCTAssertEqual(emoji.value as? String, next)
        }
        openOrganization(app)
        app.buttons["organizationNewList"].tap()
        editOrganizationName("🧪 Lab", in: app)
        finishOrganizationEdit(app)
        editLab()
        XCTAssertEqual(emoji.value as? String, "🧪")
        replaceEmoji("x")
        XCTAssertFalse(done.isEnabled)
        replaceEmoji("👩🏽‍💻")
        XCTAssertTrue(done.isEnabled)
        app.buttons["organizationCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(done)
        editLab()
        XCTAssertEqual(emoji.value as? String, "🧪")
        replaceEmoji("👩🏽‍💻")
        finishOrganizationEdit(app)
        app.buttons["organizationManagerDone"].tap()
        reveal(app.buttons["Lab"], in: app)
        attach(app, "Custom emoji in the list drawer")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openOrganization(app)
        editLab()
        XCTAssertEqual(emoji.value as? String, "👩🏽‍💻")
    }

    @MainActor func testListAndFolderManagementPersistsPlacementAndUngroups() {
        let app = launch()
        openOrganization(app)
        createOrganizationEntity("Projects", button: "organizationNewFolder", in: app)
        createOrganizationEntity("Studio folder", button: "organizationNewFolder", in: app)
        app.buttons["organizationReorder"].tap()
        let move = app.buttons["Move Projects down"]
        reveal(move, in: app)
        move.tap()
        XCTAssertFalse(move.isEnabled)
        app.buttons["organizationReorder"].tap()
        attach(app, "Reordered folders")
        app.buttons["organizationNewList"].tap()
        editOrganizationName("Studio list", in: app)
        chooseListPlacement("Projects", in: app)
        finishOrganizationEdit(app)
        openOrganizationList("00000000-0000-0000-0000-000000000100", in: app)
        app.buttons["organizationClearName"].tap()
        editOrganizationName("Work renamed", in: app)
        chooseListPlacement("Projects", in: app)
        finishOrganizationEdit(app)
        app.buttons["organizationManagerDone"].tap()
        let drawerFolder = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                                            "drawerFolder-", "Projects")).firstMatch
        reveal(drawerFolder, in: app)
        XCTAssertTrue(app.buttons["Work renamed"].exists)
        drawerFolder.tap()
        XCTAssertFalse(app.buttons["Work renamed"].exists)
        drawerFolder.tap()
        XCTAssertTrue(app.buttons["Work renamed"].exists)
        attach(app, "Folder and member lists")
        app.buttons["manageLists"].tap()
        let projectRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                                          "manageFolder-", "Projects")).firstMatch
        reveal(projectRow, in: app)
        projectRow.tap()
        let ungroup = app.buttons["organizationUngroup"]
        reveal(ungroup, in: app)
        ungroup.tap()
        app.alerts["Ungroup folder?"].buttons["Ungroup Folder"].tap()
        waitGone(app.buttons["organizationSave"])
        XCTAssertFalse(projectRow.exists)
        XCTAssertTrue(app.buttons["Studio list"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work renamed", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
    }

    @MainActor func testListArchiveAndSmartExclusionKeepDirectAccess() {
        let app = launch()
        openOrganization(app)
        let work = "00000000-0000-0000-0000-000000000100"
        openOrganizationList(work, in: app)
        setSwitch("organizationArchive", to: true, app: app)
        finishOrganizationEdit(app)
        app.buttons["organizationManagerDone"].tap()
        let archived = app.staticTexts["Archived Lists"]
        reveal(archived, in: app)
        XCTAssertTrue(archived.exists)
        attach(app, "Archived list in navigation")
        app.buttons["Work"].tap()
        app.buttons["Prepare the weekly plan"].tap()
        XCTAssertTrue(app.staticTexts["Archived"].exists)
        XCTAssertFalse(app.buttons["editTitle"].isEnabled)
        app.buttons["taskDetailDone"].tap()
        openOrganization(app)
        openOrganizationList(work, in: app)
        setSwitch("organizationArchive", to: false, app: app)
        setSwitch("organizationSmartInclusion", to: false, app: app)
        finishOrganizationEdit(app)
        app.buttons["organizationManagerDone"].tap()
        app.buttons["Today"].tap()
        XCTAssertFalse(app.buttons["Prepare the weekly plan"].exists)
        goTo("Work", in: app)
        app.buttons["Prepare the weekly plan"].tap()
        XCTAssertTrue(app.buttons["editTitle"].isEnabled)
    }

    @MainActor func testListDuplicateAndDeletePreserveTasksAndUnavailableFilter() {
        let app = launch(qaCase: "organization")
        let work = "00000000-0000-0000-0000-000000000100"
        openOrganization(app)
        openOrganizationList(work, in: app)
        let duplicate = app.buttons["organizationDuplicate"]
        reveal(duplicate, in: app)
        duplicate.tap()
        app.alerts["Duplicate list?"].buttons["Duplicate List"].tap()
        waitGone(app.buttons["organizationSave"])
        XCTAssertTrue(app.buttons["Work copy"].exists)
        openOrganizationList(work, in: app)
        let delete = app.buttons["organizationDelete"]
        reveal(delete, in: app)
        delete.tap()
        let confirmation = app.alerts["Delete list?"]
        XCTAssertTrue(confirmation.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "will move to Inbox")).firstMatch.exists)
        confirmation.buttons["Delete List"].tap()
        waitGone(app.buttons["organizationSave"])
        XCTAssertFalse(app.buttons["manageList-" + work].exists)
        app.buttons["organizationManagerDone"].tap()
        app.buttons["Inbox"].tap()
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 5))
        goTo("Work copy", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review the draft"].exists)
        goTo("Original Work only", in: app)
        XCTAssertTrue(app.staticTexts["No matching tasks"].waitForExistence(timeout: 5))
        attach(app, "Deleted list filter remains empty")
    }

    @MainActor func testListOrganizationWriteFailureKeepsDraft() {
        let app = launch(qaCase: "save-failure")
        openOrganization(app)
        app.buttons["organizationNewFolder"].tap()
        editOrganizationName("Unsaved folder", in: app)
        app.buttons["organizationSave"].tap()
        XCTAssertTrue(app.staticTexts["organizationSaveError"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["organizationName"].value as? String, "Unsaved folder")
        app.buttons["organizationCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["organizationSave"])
        XCTAssertFalse(app.buttons["Unsaved folder"].exists)
    }

    @MainActor private func openOrganization(_ app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        let manage = app.buttons["manageLists"]
        reveal(manage, in: app)
        manage.tap()
        XCTAssertTrue(app.buttons["organizationManagerDone"].waitForExistence(timeout: 5))
    }

    @MainActor private func openOrganizationList(_ id: String, in app: XCUIApplication) {
        let row = app.buttons["manageList-" + id]
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.buttons["organizationSave"].waitForExistence(timeout: 5))
    }

    @MainActor private func createOrganizationEntity(_ title: String, button: String, in app: XCUIApplication) {
        app.buttons[button].tap()
        editOrganizationName(title, in: app)
        finishOrganizationEdit(app)
    }

    @MainActor private func editOrganizationName(_ name: String, in app: XCUIApplication) {
        let field = app.textViews["organizationName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        XCTAssertEqual(field.value as? String, name)
    }

    @MainActor private func revealListCreationMore(_ app: XCUIApplication) {
        guard app.navigationBars["Add List"].exists else { return }
        // Edit List remains expanded; only creation has the More disclosure.
        if !app.buttons["organizationPlacement"].exists {
            let more = app.buttons["organizationMore"]
            reveal(more, in: app)
            XCTAssertTrue(more.waitForExistence(timeout: 5)); more.tap()
        }
    }

    @MainActor private func chooseListPlacement(_ name: String, in app: XCUIApplication) {
        revealListCreationMore(app)
        let placement = app.buttons["organizationPlacement"]
        reveal(placement, in: app)
        placement.tap()
        let option = app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@) AND NOT (identifier BEGINSWITH %@)",
                                                       name, "drawerFolder-", "manageFolder-")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    @MainActor private func finishOrganizationEdit(_ app: XCUIApplication) {
        app.buttons["organizationSave"].tap()
        waitGone(app.buttons["organizationSave"])
    }

    @MainActor func testSmartListVisibilityAndOrderSurviveRelaunch() {
        let app = launch()
        app.buttons["Open navigation"].tap()
        XCTAssertFalse(app.buttons["smartDrawer-all"].exists)
        XCTAssertFalse(app.buttons["smartDrawer-tomorrow"].exists)
        XCTAssertFalse(app.buttons["smartDrawer-wontDo"].exists)
        openSmartSettings(in: app)
        setSmartVisibility("tomorrow", to: "Show", in: app)
        app.buttons["smartListCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["smartListDone"])
        XCTAssertFalse(app.buttons["smartDrawer-tomorrow"].exists)
        openSmartSettings(in: app)
        setSmartVisibility("all", to: "Show", in: app)
        setSmartVisibility("today", to: "Hidden", in: app)
        setSmartVisibility("tomorrow", to: "Show if not empty", in: app)
        setSmartVisibility("tags", to: "Hidden", in: app)
        setSmartVisibility("filters", to: "Show if not empty", in: app)
        app.buttons["smartListReorder"].tap()
        let up = app.buttons["smartListUp-inbox"]
        reveal(up, in: app)
        up.tap()
        app.buttons["smartListReorder"].tap()
        attach(app, "Saved Smart List settings")
        app.buttons["smartListDone"].tap()
        waitGone(app.buttons["smartListDone"])
        let all = app.buttons["smartDrawer-all"], inbox = app.buttons["smartDrawer-inbox"], week = app.buttons["smartDrawer-week"]
        XCTAssertTrue(all.exists)
        XCTAssertLessThan(inbox.frame.midY, week.frame.midY)
        XCTAssertFalse(app.buttons["smartDrawer-today"].exists)
        XCTAssertFalse(app.buttons["smartDrawer-tomorrow"].exists)
        XCTAssertFalse(app.staticTexts["Tags"].exists)
        XCTAssertTrue(app.staticTexts["Filters"].exists)
        attach(app, "Smart List drawer after Save")
        app.buttons["drawerDone"].tap()
        XCTAssertTrue(app.staticTexts["All"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["All"].waitForExistence(timeout: 10))
        app.buttons["Open navigation"].tap()
        XCTAssertLessThan(inbox.frame.midY, week.frame.midY)
        XCTAssertFalse(app.buttons["smartDrawer-today"].exists)
    }

    @MainActor func testSmartListFailedSaveKeepsDraftAndDrawer() {
        let app = launch(qaCase: "save-failure")
        app.buttons["Open navigation"].tap()
        openSmartSettings(in: app)
        setSmartVisibility("all", to: "Show", in: app)
        app.buttons["smartListDone"].tap()
        XCTAssertTrue(app.staticTexts["smartListError"].waitForExistence(timeout: 5))
        let row = app.buttons["smartListVisibility-all"]
        XCTAssertTrue(row.exists)
        XCTAssertTrue(row.label.contains("Show") || (row.value as? String) == "Show")
        app.buttons["smartListCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["smartListDone"])
        XCTAssertFalse(app.buttons["smartDrawer-all"].exists)
    }

    @MainActor private func openSmartSettings(in app: XCUIApplication) {
        app.buttons["openSmartLists"].tap()
        XCTAssertTrue(app.buttons["smartListDone"].waitForExistence(timeout: 5))
    }

    @MainActor private func setSmartVisibility(_ key: String, to option: String, in app: XCUIApplication) {
        let row = app.buttons["smartListVisibility-" + key]
        reveal(row, in: app)
        row.tap()
        let choice = app.buttons[option]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        XCTAssertTrue(app.buttons["smartListDone"].waitForExistence(timeout: 5))
    }

    @MainActor func testSavedNormalFilterCreatesMatchesAndDeletesWithoutLosingTasks() {
        let app = launch()
        openFilterManagement(in: app)
        app.buttons["newSavedFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Weekly only")
        let keyword = app.textFields["savedFilterKeyword"]
        reveal(keyword, in: app)
        keyword.tap()
        keyword.typeText("weekly")
        reveal(app.switches["savedFilterPin"], in: app, towardTop: true)
        setSwitch("savedFilterPin", to: true, app: app)
        app.buttons["savedFilterDone"].tap()
        waitGone(app.buttons["savedFilterDone"])
        let managerRow = managedFilter("Weekly only", in: app)
        XCTAssertTrue(managerRow.exists)
        app.buttons["filterManagerDone"].tap()
        XCTAssertTrue(app.buttons["Pinned Weekly only"].exists)
        let filter = app.buttons["Weekly only"]
        reveal(filter, in: app)
        filter.tap()
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review the project outline"].exists)
        attach(app, "Normal saved filter results")
        openFilterManagement(in: app)
        reveal(managerRow, in: app)
        managerRow.tap()
        let remove = app.buttons["deleteSavedFilter"]
        reveal(remove, in: app)
        remove.tap()
        app.alerts["Delete filter?"].buttons["Delete Filter"].tap()
        waitGone(app.buttons["savedFilterDone"])
        XCTAssertFalse(app.buttons["Weekly only"].exists)
        app.buttons["filterManagerDone"].tap()
        app.buttons["drawerDone"].tap()
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
    }

    @MainActor func testSavedAdvancedFilterBuildsNestedRuleAndReloads() {
        let app = launch()
        openFilterManagement(in: app)
        app.buttons["newSavedFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Work words")
        let mode = app.segmentedControls["savedFilterMode"]
        reveal(mode, in: app)
        mode.buttons["Advanced"].tap()
        chooseFilterRule("Add condition", from: "filterAddRule-root", in: app)
        chooseFilterRule("Add AND group", from: "filterAddRule-root", in: app)
        chooseFilterRule("Change to OR", from: "filterRuleActions-root-1", in: app)
        chooseFilterRule("Add condition", from: "filterAddRule-root-1", in: app)
        setRuleKeyword("weekly", path: "root-1-0", in: app)
        app.keyboards.buttons["Done"].tap()
        chooseFilterRule("Wrap in NOT", from: "filterRuleActions-root-1-0", in: app)
        let wrappedOperator = app.staticTexts["filterOperator-root-1-0"]
        XCTAssertTrue(wrappedOperator.waitForExistence(timeout: 5))
        XCTAssertEqual(wrappedOperator.label, "NOT")
        let invertedPreview = app.buttons["savedFilterPreview"]
        reveal(invertedPreview, in: app); invertedPreview.tap()
        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000001"].exists)
        app.navigationBars["Preview"].buttons.firstMatch.tap()
        reveal(app.buttons["filterRuleActions-root-1-0"], in: app, towardTop: true)
        chooseFilterRule("Remove NOT", from: "filterRuleActions-root-1-0", in: app)
        XCTAssertEqual(app.textFields["filterRuleKeyword-root-1-0"].value as? String, "weekly")
        chooseFilterRule("Add AND group", from: "filterAddRule-root-1", in: app)
        chooseFilterRule("Add condition", from: "filterAddRule-root-1-1", in: app)
        attach(app, "Deep saved filter groups")
        chooseFilterRule("Remove rule", from: "filterRuleActions-root-1-1", in: app)
        XCTAssertFalse(app.staticTexts["filterOperator-root-1-1"].exists)
        chooseFilterRule("Add condition", from: "filterAddRule-root-1", in: app)
        setRuleKeyword("meeting", path: "root-1-1", in: app)
        attach(app, "Nested keyword keyboard")
        app.keyboards.buttons["Done"].tap()
        attach(app, "Nested saved filter rules")
        let preview = app.buttons["savedFilterPreview"]
        reveal(preview, in: app); preview.tap()
        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 5))
        let rows = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "savedFilterPreviewTask-"))
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000006"].exists)
        XCTAssertFalse(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000001"].exists)
        app.navigationBars["Preview"].buttons.firstMatch.tap()
        let examples = app.buttons["savedFilterExamples"]
        reveal(examples, in: app); examples.tap()
        XCTAssertTrue(app.staticTexts["Taskovsky examples"].waitForExistence(timeout: 5))
        app.navigationBars["Examples"].buttons.firstMatch.tap()
        reveal(app.staticTexts["filterOperator-root"], in: app, towardTop: true)
        attach(app, "Advanced Filter logic and filters")
        app.buttons["savedFilterDone"].tap()
        waitGone(app.buttons["savedFilterDone"])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work words", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Write meeting notes"].exists)
        XCTAssertFalse(app.buttons["Review the project outline"].exists)
        attach(app, "Advanced saved filter results")
    }

    @MainActor func testSavedAdvancedRenameKeepsUnavailableRuleAndCancelsModeSwitch() {
        let app = launch(qaCase: "saved-filter")
        openFilterManagement(in: app)
        let row = managedFilter("Unavailable work", in: app)
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts["Filter Conditions"].waitForExistence(timeout: 5))
        let preview = app.buttons["savedFilterPreview"]
        reveal(preview, in: app); XCTAssertTrue(preview.isEnabled); preview.tap()
        XCTAssertTrue(app.staticTexts["No matching tasks"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "savedFilterPreviewTask-")).count, 0)
        app.navigationBars["Preview"].buttons.firstMatch.tap()
        let examples = app.buttons["savedFilterExamples"]
        reveal(examples, in: app); examples.tap()
        XCTAssertTrue(app.staticTexts["Taskovsky examples"].waitForExistence(timeout: 5))
        app.navigationBars["Examples"].buttons.firstMatch.tap()
        app.buttons["savedFilterCancel"].tap()
        waitGone(app.buttons["savedFilterDone"])
        XCTAssertFalse(app.alerts["Discard changes?"].exists)
        row.tap()
        let mode = app.segmentedControls["savedFilterMode"]
        reveal(mode, in: app)
        mode.buttons["Normal"].tap()
        app.alerts["Switch to Normal?"].buttons["Cancel"].tap()
        XCTAssertTrue(mode.buttons["Advanced"].isSelected)
        let clear = app.buttons["savedFilterClearName"]
        reveal(clear, in: app, towardTop: true)
        clear.tap()
        let name = app.textFields["savedFilterName"]
        name.tap()
        name.typeText("Retained rule")
        app.buttons["savedFilterDone"].tap()
        waitGone(app.buttons["savedFilterDone"])
        app.buttons["filterManagerDone"].tap()
        let filter = app.buttons["Retained rule"]
        reveal(filter, in: app)
        filter.tap()
        XCTAssertTrue(app.staticTexts["No matching tasks"].waitForExistence(timeout: 5))
    }

    @MainActor func testSavedFilterFailedWriteKeepsDraft() {
        let app = launch(qaCase: "save-failure")
        openFilterManagement(in: app)
        app.buttons["newSavedFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Unsaved filter")
        app.buttons["savedFilterDone"].tap()
        let error = app.staticTexts["savedFilterError"]
        reveal(error, in: app)
        reveal(name, in: app, towardTop: true)
        XCTAssertEqual(name.value as? String, "Unsaved filter")
        app.buttons["savedFilterCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["savedFilterDone"])
        XCTAssertFalse(managedFilter("Unsaved filter", in: app).exists)
    }

    @MainActor private func managedFilter(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "manageFilter-", name)).firstMatch
    }

    @MainActor private func openFilterManagement(in app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        let manage = app.buttons["manageFilters"]
        reveal(manage, in: app)
        manage.tap()
        XCTAssertTrue(app.buttons["filterManagerDone"].waitForExistence(timeout: 5))
    }

    @MainActor private func tapFilterRule(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        reveal(button, in: app)
        button.tap()
    }

    @MainActor private func chooseFilterRule(_ title: String, from menu: String, in app: XCUIApplication) {
        tapFilterRule(menu, in: app)
        app.buttons[title].tap()
    }

    @MainActor private func setRuleKeyword(_ value: String, path: String, in app: XCUIApplication) {
        tapFilterRule("filterConditionKind-" + path, in: app)
        app.buttons["Keyword"].tap()
        let field = app.textFields["filterRuleKeyword-" + path]
        reveal(field, in: app)
        field.tap()
        field.typeText(value)
    }

    @MainActor func testTagManagerCreatesPinsAndAssignsNestedTag() {
        let app = launch()
        openTagManager(in: app)
        app.buttons["newTag"].tap()
        let title = app.textFields["tagName"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("# Sprint")
        app.keyboards.buttons["Done"].tap()
        let parent = app.buttons["tagParent"]
        reveal(parent, in: app)
        parent.tap()
        tagChoice("Planning", id: "tagParentChoice-00000000-0000-0000-0000-000000000200", in: app).tap()
        setSwitch("tagPin", to: true, app: app)
        app.buttons["tagDone"].tap()
        waitGone(app.buttons["tagDone"])
        app.buttons["tagManagerDone"].tap()
        XCTAssertTrue(app.buttons["Pinned Sprint"].exists)
        let collapse = app.buttons["drawerTagDisclosure-00000000-0000-0000-0000-000000000200"]
        reveal(collapse, in: app)
        collapse.tap()
        waitGone(app.buttons["Sprint"])
        collapse.tap()
        XCTAssertTrue(app.buttons["Sprint"].waitForExistence(timeout: 5))
        app.buttons["drawerDone"].tap()
        app.buttons["Arrange the studio"].tap()
        openTaskMetadata("editTaskTags", in: app)
        let tag = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "taskTag-", "Sprint")).firstMatch
        reveal(tag, in: app)
        tag.tap()
        app.buttons["taskMetadataDone"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        app.buttons["taskDetailDone"].tap()
        app.buttons["Open navigation"].tap()
        let parentTag = app.buttons["drawerTag-00000000-0000-0000-0000-000000000200"]
        reveal(parentTag, in: app)
        parentTag.tap()
        XCTAssertTrue(app.buttons["Arrange the studio"].waitForExistence(timeout: 5))
        attach(app, "Parent tag includes assigned subtag")
    }

    @MainActor func testTagManagerMergesIntoDescendantAndReopensMatchingFilter() {
        let app = launch(qaCase: "tag-organization")
        openTagManager(in: app)
        app.buttons["manageTag-00000000-0000-0000-0000-000000000200"].tap()
        let mergeTarget = app.buttons["tagMergeTarget"]
        reveal(mergeTarget, in: app)
        mergeTarget.tap()
        tagChoice("Planning / Sprint", id: "tagMergeChoice-00000000-0000-0000-0000-000000000201", in: app).tap()
        app.buttons["mergeTag"].tap()
        app.alerts["Merge tags?"].buttons["Merge Tag"].tap()
        waitGone(app.buttons["tagDone"])
        XCTAssertFalse(app.buttons["manageTag-00000000-0000-0000-0000-000000000200"].exists)
        XCTAssertTrue(app.buttons["manageTag-00000000-0000-0000-0000-000000000201"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Tagged review", in: app)
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 5))
        attach(app, "Saved filter after tag merge")
    }

    @MainActor func testTagManagerDeleteKeepsUnavailableFilterAndTasks() {
        let app = launch(qaCase: "tag-organization")
        openTagManager(in: app)
        app.buttons["manageTag-00000000-0000-0000-0000-000000000200"].tap()
        let delete = app.buttons["deleteTag"]
        reveal(delete, in: app)
        delete.tap()
        app.alerts["Delete tag?"].buttons["Delete Tag"].tap()
        waitGone(app.buttons["tagDone"])
        app.buttons["tagManagerDone"].tap()
        let filter = app.buttons["Tagged review"]
        reveal(filter, in: app)
        filter.tap()
        XCTAssertTrue(app.staticTexts["No matching tasks"].waitForExistence(timeout: 5))
        goTo("Today", in: app)
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 5))
    }

    @MainActor func testTagManagerReordersAndEditsWithoutSavingCanceledName() {
        let app = launch(qaCase: "tag-organization")
        openTagManager(in: app)
        app.buttons["tagReorder"].tap()
        let move = app.buttons["Move Review group up"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        XCTAssertTrue(move.isEnabled)
        move.tap()
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: move)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        attach(app, "Tag sibling order")
        app.buttons["tagReorder"].tap()

        let sprint = app.buttons["manageTag-00000000-0000-0000-0000-000000000201"]
        sprint.tap()
        let name = app.textFields["tagName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.buttons["tagClearName"].tap()
        name.tap()
        name.typeText("Discarded")
        app.buttons["tagCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(name)

        sprint.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Sprint")
        app.buttons["tagClearName"].tap()
        name.tap()
        name.typeText("Sprint renamed")
        app.keyboards.buttons["Done"].tap()
        app.buttons["tagParent"].tap()
        tagChoice("None", id: "tagParentChoice-root", in: app).tap()
        app.buttons["tagDone"].tap()
        waitGone(name)
        XCTAssertTrue(sprint.label.contains("Sprint renamed"))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Sprint renamed", in: app)
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 5))
    }

    @MainActor private func tagChoice(_ name: String, id: String, in app: XCUIApplication) -> XCUIElement {
        let identified = app.buttons[id]
        let choice = identified.exists ? identified : app.buttons.matching(NSPredicate(
            format: "label == %@ AND value == nil AND NOT (identifier BEGINSWITH %@)",
            name, "manageTag-"
        )).firstMatch
        reveal(choice, in: app)
        return choice
    }

    @MainActor func testTaskCountdownSettingAndDateTapSurviveRelaunchAsDesigned() {
        let app = launch()
        let date = app.buttons["taskCountdown-00000000-0000-0000-0000-000000000002"]
        let title = app.buttons["Prepare the weekly plan"]
        XCTAssertFalse(date.exists)
        app.buttons["Open navigation"].tap()
        let settings = app.buttons["openLocalSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let toggle = app.switches["localTaskCountdown"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["localSettingsCancel"].tap()
        app.alerts["Discard settings changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["localSettingsDone"])
        let settingsReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: settings)
        XCTAssertEqual(XCTWaiter.wait(for: [settingsReady], timeout: 5), .completed)
        settings.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["localSettingsDone"].tap()
        waitGone(app.buttons["localSettingsDone"])
        app.buttons["smartDrawer-today"].tap()
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let dateLabel = date.label
        date.tap()
        XCTAssertEqual(date.label, "2h left")
        attach(app, "Timed task countdown")
        title.tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
        app.buttons["taskDetailDone"].tap()
        XCTAssertEqual(date.label, "2h left")
        date.tap()
        XCTAssertEqual(date.label, dateLabel)
        date.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertEqual(date.label, dateLabel)
    }

    @MainActor func testLocalSettingsCancelAndSaveAffectNewCaptureAfterRelaunch() {
        let app = launch()
        app.buttons["Open navigation"].tap()
        let settings = app.buttons["openLocalSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let priority = app.buttons["localDefaultPriority"]
        XCTAssertTrue(priority.waitForExistence(timeout: 5))
        priority.tap()
        app.buttons["High"].tap()
        app.buttons["localSettingsCancel"].tap()
        app.alerts["Discard settings changes?"].buttons["Discard Changes"].tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(priority.waitForExistence(timeout: 5))
        XCTAssertTrue(priority.label.contains("None") || (priority.value as? String) == "None")
        priority.tap()
        app.buttons["High"].tap()
        let list = app.buttons["localDefaultList"]
        reveal(list, in: app, towardTop: true)
        list.tap()
        app.collectionViews.buttons["Work"].tap()
        let weekStart = app.buttons["localWeekStart"]
        reveal(weekStart, in: app, towardTop: true)
        weekStart.tap()
        app.buttons["Sunday"].tap()
        attach(app, "Staged local settings")
        app.buttons["localSettingsDone"].tap()
        waitGone(app.buttons["localSettingsDone"])

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["openCapture"].tap()
        let capturePriority = app.buttons["capturePriorityPicker"]
        reveal(capturePriority, in: app)
        XCTAssertTrue(capturePriority.label.contains("High") || (capturePriority.value as? String) == "High")
        let captureList = app.buttons["captureListPicker"]
        XCTAssertTrue(captureList.label.contains("Work") || (captureList.value as? String) == "Work")
        attach(app, "New capture uses saved defaults")
        app.buttons["captureCancel"].tap()
        waitGone(app.buttons["captureCancel"])
        app.buttons["Calendar"].tap()
        let sunday = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Show Sunday")).firstMatch
        XCTAssertTrue(sunday.waitForExistence(timeout: 5))
        attach(app, "Calendar begins on saved Sunday")
    }

    @MainActor func testTemplateSearchAndNativeReorderSurviveRelaunch() {
        let app = launch(qaCase: "template-order")
        openTemplateManager(app)
        let search = app.textFields["templateSearch"]
        let styled = app.buttons["Styled project"]
        let weekly = app.buttons["Weekly setup"]
        let travel = app.buttons["Travel bag"]
        let reorder = app.buttons["templateReorder"]
        XCTAssertTrue(styled.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("CAFE")
        XCTAssertTrue(weekly.exists)
        XCTAssertFalse(styled.exists)
        XCTAssertFalse(travel.exists)
        XCTAssertFalse(reorder.isEnabled)
        app.buttons["Clear template search"].tap()
        XCTAssertTrue(styled.waitForExistence(timeout: 5))
        XCTAssertLessThan(styled.frame.minY, travel.frame.minY)
        reorder.tap()

        let grip = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Reorder Styled project")
        ).firstMatch
        guard grip.waitForExistence(timeout: 5) else {
            attach(app, "Template manager edit mode")
            return XCTFail("The native template reorder control is unavailable.")
        }
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: travel.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.85)))
        reorder.tap()
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in travel.frame.minY < styled.frame.minY }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        attach(app, "Templates in saved order")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openTemplateManager(app)
        XCTAssertTrue(styled.waitForExistence(timeout: 5))
        XCTAssertLessThan(travel.frame.minY, styled.frame.minY)

        app.buttons["templateManagerDone"].tap()
        waitGone(app.buttons["templateManagerDone"])
        app.buttons["drawerDone"].tap()
        waitGone(app.buttons["drawerDone"])
        _ = openCapture(app)
        let chooser = app.buttons["captureTemplatePicker"]
        reveal(chooser, in: app)
        chooser.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("passport")
        XCTAssertTrue(travel.exists)
        XCTAssertFalse(styled.exists)
        travel.tap()
        waitGone(search)
        let title = app.textViews["captureTitle"]
        reveal(title, in: app, towardTop: true)
        XCTAssertEqual(title.value as? String, "Pack the bag")
    }

    @MainActor func testTemplateManagerCreatesRenamesAndDeletesPlainTemplate() {
        let app = launch()
        openTemplateManager(app)
        app.buttons["newTemplate"].tap()
        let name = app.textFields["templateName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Weekly Template")
        let title = app.textFields["templateTaskTitle"]
        title.tap()
        title.typeText("Weekly plan from template")
        app.buttons["templateDone"].tap()
        let template = app.buttons["Weekly Template"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openTemplateManager(app)
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" revised")
        app.buttons["templateDone"].tap()
        let renamed = app.buttons["Weekly Template revised"]
        XCTAssertTrue(renamed.waitForExistence(timeout: 5))
        renamed.tap()
        let delete = app.buttons["deleteTemplate"]
        reveal(delete, in: app)
        delete.tap()
        app.alerts["Delete template?"].buttons["Delete Template"].tap()
        waitGone(app.buttons["templateDone"])
        XCTAssertFalse(renamed.exists)
    }

    @MainActor func testStyledTaskCanBeSavedAndAppliedAsTemplate() {
        let app = launch(qaCase: "task-metadata")
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        app.buttons["taskActions"].tap()
        let save = app.buttons["Save as Template"]
        reveal(save, in: app)
        save.tap()
        let submit = app.buttons["saveTaskTemplateDone"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()
        waitGone(submit)

        let child = app.buttons["openSubtask-00000000-0000-0000-0000-000000000004"]
        reveal(child, in: app)
        child.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, Arrange the studio")
        app.buttons["taskActions"].tap()
        let apply = app.buttons["Apply Template"]
        reveal(apply, in: app)
        apply.tap()
        let search = app.textFields["templateSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("OUTLINE")
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                                       "applyTaskTemplate-", "Review the project outline")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        app.alerts["Apply “Review the project outline”?"].buttons["Apply Template"].tap()
        let changed = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                                         "editTitle", "Edit title, Review the project outline")).firstMatch
        XCTAssertTrue(changed.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["openParentTask"].exists)
        attach(app, "Applied styled template with parent link")
    }

    @MainActor private func openTemplateManager(_ app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        let manager = app.buttons["manageTemplates"]
        reveal(manager, in: app)
        manager.tap()
        XCTAssertTrue(app.buttons["templateManagerDone"].waitForExistence(timeout: 5))
    }

    @MainActor func testTaskBatchEditsPriorityTagsDateAndListFromWork() {
        let app = launch()
        goTo("Work", in: app)
        openWorkBatch(app, action: "batchPriority")
        app.buttons["batchPriority-low"].tap()
        let back = app.buttons["batchBack"]
        back.tap()
        back.tap()
        back.tap()
        waitGone(back)
        XCTAssertFalse(app.staticTexts["batchNotice"].exists)

        openWorkBatch(app, action: "batchPriority")
        app.buttons["batchPriority-high"].tap()
        applyWorkBatch(app)

        openWorkBatch(app, action: "batchTags")
        app.buttons["batchTag-00000000-0000-0000-0000-000000000200"].tap()
        applyWorkBatch(app)

        openWorkBatch(app, action: "batchSchedule")
        setSwitch("batchClearDate", to: true, app: app)
        applyWorkBatch(app)

        openWorkBatch(app, action: "batchMove")
        app.buttons["batchList-00000000-0000-0000-0000-000000000101"].tap()
        attach(app, "Review batch list move")
        applyWorkBatch(app)
        XCTAssertFalse(app.buttons["Prepare the weekly plan"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Personal", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Write meeting notes"].exists)
        attach(app, "Reopened batch edits in Personal")
    }

    @MainActor func testTaskBatchCompletionAndTrashRequireExplicitApplication() {
        let app = launch()
        goTo("Work", in: app)
        openWorkBatch(app, action: "batchComplete")
        applyWorkBatch(app)
        XCTAssertTrue(app.staticTexts["Completed"].exists)

        openWorkBatch(app, action: "batchTrash")
        let apply = app.buttons["batchApply"]
        apply.tap()
        let confirmation = app.alerts["Move selected items to Trash?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Cancel"].tap()
        waitGone(confirmation)
        XCTAssertTrue(app.buttons["batchApply"].exists)
        apply.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Move to Trash"].tap()
        waitGone(apply)
        XCTAssertTrue(app.staticTexts["batchNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Prepare the weekly plan"].exists)
        goTo("Trash", in: app)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Write meeting notes"].exists)
        attach(app, "Batch items recoverable in Trash")
    }

    @MainActor func testTaskBatchPostponeRequiresTimedSelectionAndExplicitApply() {
        let app = launch(qaCase: "batch-postpone")
        goTo("Work", in: app)
        app.buttons["taskListActions"].tap()
        app.buttons["batchOpen"].tap()
        let next = app.buttons["batchChooseAction"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        let timed = batchRow("002", in: app)
        let repeating = batchRow("006", in: app)
        let allDay = batchRow("008", in: app)
        timed.tap()
        allDay.tap()
        next.tap()
        XCTAssertFalse(app.buttons["batchPostpone"].exists)
        let back = app.buttons["batchBack"]
        back.tap()
        allDay.tap()
        repeating.tap()
        next.tap()
        app.buttons["batchPostpone"].tap()
        XCTAssertTrue(app.buttons["batchApply"].waitForExistence(timeout: 5))
        back.tap()
        back.tap()
        back.tap()
        waitGone(back)
        XCTAssertFalse(app.staticTexts["batchNotice"].exists)
        openWorkBatch(app, action: "batchPostpone")
        attach(app, "Review before postponing Tasks")
        applyWorkBatch(app)
        XCTAssertEqual(app.staticTexts["batchNotice"].label, "Selected tasks postponed by 1 hour.")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertTrue(app.buttons["Write meeting notes"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarBatchPostponeUsesSavedCalendarSourcesAcrossDays() {
        let app = launch(qaCase: "batch-postpone")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar actions"].tap()
        let action = app.buttons["Postpone Tasks"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        let review = app.buttons["batchChooseAction"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertFalse(review.isEnabled)
        XCTAssertFalse(batchRow("005", in: app).exists)
        XCTAssertFalse(batchRow("008", in: app).exists)
        for tail in ["002", "006"] {
            let row = batchRow(tail, in: app)
            reveal(row, in: app)
            row.tap()
        }
        attach(app, "Calendar sources for postponing")
        review.tap()
        XCTAssertTrue(app.buttons["batchApply"].waitForExistence(timeout: 5))
        applyWorkBatch(app)
        XCTAssertEqual(app.staticTexts["batchNotice"].label, "Selected tasks postponed by 1 hour.")
    }

    @MainActor private func batchRow(_ tail: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["batchTask-00000000-0000-0000-0000-000000000" + tail]
    }

    @MainActor private func openWorkBatch(_ app: XCUIApplication, action: String) {
        app.buttons["taskListActions"].tap()
        let open = app.buttons["batchOpen"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let next = app.buttons["batchChooseAction"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        for tail in ["002", "006"] {
            let row = batchRow(tail, in: app)
            reveal(row, in: app)
            row.tap()
        }
        next.tap()
        app.buttons[action].tap()
        XCTAssertTrue(app.buttons["batchApply"].waitForExistence(timeout: 5))
    }

    @MainActor private func applyWorkBatch(_ app: XCUIApplication) {
        let apply = app.buttons["batchApply"]
        apply.tap()
        waitGone(apply)
        XCTAssertTrue(app.staticTexts["batchNotice"].waitForExistence(timeout: 8))
    }

    @MainActor func testSummaryFiltersAndSavesEditedInboxNote() {
        let app = launch(qaCase: "summary")
        goTo("Summary", in: app)
        let report = app.textViews["summaryText"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertTrue((report.value as? String)?.contains("Prepare the weekly plan") == true)
        app.buttons["summaryFilter"].tap()
        app.buttons["summaryPeriod"].tap()
        app.buttons["Today"].tap()
        let grouping = app.buttons["summaryGrouping"]
        reveal(grouping, in: app)
        grouping.tap()
        app.buttons["By List"].tap()
        app.buttons["summaryFilterDone"].tap()
        let generated = report.value as? String
        XCTAssertTrue(generated?.contains("\nWork\n") == true)
        attach(app, "Generated local Summary")

        report.tap()
        report.typeText("Temporary edit")
        let changed = report.value as? String
        XCTAssertTrue(changed?.contains("Temporary edit") == true)
        app.buttons["summaryFilter"].tap()
        reveal(grouping, in: app)
        grouping.tap()
        app.buttons["By Date"].tap()
        app.buttons["summaryFilterCancel"].tap()
        XCTAssertEqual(report.value as? String, changed)

        app.buttons["summaryRegenerate"].tap()
        XCTAssertEqual(report.value as? String, generated)
        app.buttons["summaryCopy"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 5))
        report.tap()
        report.typeText("Edited locally")
        guard let edited = report.value as? String, edited.contains("Edited locally") else {
            XCTFail("The edited report was not visible")
            return
        }
        let exact = XCTAttachment(data: Data(edited.utf8), uniformTypeIdentifier: "public.utf8-plain-text")
        exact.name = "Summary edited output"
        exact.lifetime = .keepAlways
        add(exact)
        let save = app.buttons["summarySave"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved as note"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app)
        let note = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Summary ")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        XCTAssertEqual(app.staticTexts["taskDescription"].label, edited)
    }

    @MainActor func testSummaryTagPrioritySortAndFieldsSaveExactReport() {
        let app = launch(qaCase: "summary-fields")
        goTo("Summary", in: app)
        let report = app.textViews["summaryText"]
        let filter = app.buttons["summaryFilter"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        let original = report.value as? String
        XCTAssertTrue(original?.contains("Read a chapter") == true)
        XCTAssertTrue(original?.contains("Arrange the studio") == true)

        filter.tap()
        app.buttons["summaryTagFilter"].tap()
        let planning = "summaryTag-00000000-0000-0000-0000-000000000200"
        setSwitch(planning, to: true, app: app)
        app.navigationBars["Tags"].buttons.firstMatch.tap()
        app.buttons["summaryPriorityFilter"].tap()
        setSwitch("summaryPriority-high", to: true, app: app)
        app.navigationBars["Priority"].buttons.firstMatch.tap()
        let grouping = app.buttons["summaryGrouping"]
        reveal(grouping, in: app)
        grouping.tap()
        app.buttons["By Date"].tap()
        let sort = app.buttons["summarySort"]
        reveal(sort, in: app)
        sort.tap()
        app.buttons["Title"].tap()
        app.swipeUp()
        for field in ["Progress", "Status", "Completion Date"] {
            setSwitch("summaryField-" + field, to: true, app: app)
        }
        attach(app, "Summary display options")
        app.buttons["summaryFilterDone"].tap()
        waitGone(app.buttons["summaryFilterDone"])
        let generated = report.value as? String ?? ""
        XCTAssertTrue(generated.contains("Prepare the weekly plan") && generated.contains("Undone · 25% progress"))
        XCTAssertTrue(generated.contains("Review the project outline") && generated.contains("Completed · 40% progress"))
        XCTAssertTrue(generated.contains("Finished"))
        XCTAssertFalse(generated.contains("Read a chapter") || generated.contains("Arrange the studio"))
        if let first = generated.range(of: "Prepare the weekly plan"),
           let second = generated.range(of: "Review the project outline") {
            XCTAssertLessThan(first.lowerBound, second.lowerBound)
        }
        attach(app, "Filtered Summary report")

        filter.tap()
        let selectedTags = app.buttons["summaryTagFilter"]
        reveal(selectedTags, in: app, towardTop: true)
        selectedTags.tap()
        setSwitch(planning, to: false, app: app)
        app.navigationBars["Tags"].buttons.firstMatch.tap()
        app.buttons["summaryFilterCancel"].tap()
        waitGone(app.buttons["summaryFilterDone"])
        XCTAssertEqual(report.value as? String, generated)

        report.tap()
        report.typeText("Local review")
        guard let edited = report.value as? String, edited.contains("Local review") else {
            return XCTFail("Expected an edited report")
        }
        let exact = XCTAttachment(data: Data(edited.utf8), uniformTypeIdentifier: "public.utf8-plain-text")
        exact.name = "Summary edited fields output"
        exact.lifetime = .keepAlways
        add(exact)
        let save = app.buttons["summarySave"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved as note"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app)
        let note = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Summary ")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        XCTAssertEqual(app.staticTexts["taskDescription"].label, edited)
    }

    @MainActor func testSummaryPresetsStageApplyRenameDeleteAndSurviveRelaunch() {
        let app = launch(qaCase: "summary")
        goTo("Summary", in: app)
        let report = app.textViews["summaryText"]
        let filter = app.buttons["summaryFilter"]
        let presets = app.buttons["summaryPresets"]
        let done = app.buttons["summaryFilterDone"]
        let cancel = app.buttons["summaryFilterCancel"]

        func openPresets() {
            reveal(presets, in: app, towardTop: true)
            presets.tap()
            XCTAssertTrue(app.navigationBars["Summary Presets"].waitForExistence(timeout: 5))
        }
        func backToFilter() {
            app.navigationBars["Summary Presets"].buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Summary Filter"].waitForExistence(timeout: 5))
        }
        func namePreset(_ name: String) {
            app.buttons["Save Current Options…"].tap()
            let alert = app.alerts["Save Summary Preset"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            let save = alert.buttons["Save"]
            XCTAssertFalse(save.isEnabled)
            alert.textFields.firstMatch.tap()
            alert.textFields.firstMatch.typeText(name)
            save.tap()
            waitGone(alert)
        }
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        let defaultReport = report.value as? String
        filter.tap()
        app.buttons["summaryPeriod"].tap()
        app.buttons["Today"].tap()
        app.buttons["summaryStatus"].tap()
        app.buttons["Completed"].tap()
        openPresets()
        namePreset("Weekly review")
        backToFilter()
        done.tap()
        waitGone(done)
        let selectedReport = report.value as? String
        XCTAssertNotEqual(selectedReport, defaultReport)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Summary", in: app)
        XCTAssertEqual(report.value as? String, defaultReport)
        report.tap()
        report.typeText("Preserve this edit")
        let edited = report.value as? String
        XCTAssertTrue(edited?.contains("Preserve this edit") == true)
        filter.tap()
        openPresets()
        namePreset("Discarded preset")
        app.buttons["Weekly review"].tap()
        cancel.tap()
        waitGone(done)
        XCTAssertEqual(report.value as? String, edited)

        filter.tap()
        openPresets()
        XCTAssertFalse(app.buttons["Discarded preset"].exists)
        attach(app, "Persisted Summary presets")
        app.buttons["Weekly review"].tap()
        done.tap()
        waitGone(done)
        XCTAssertEqual(report.value as? String, selectedReport)

        filter.tap()
        openPresets()
        app.buttons["summaryPresetManage"].tap()
        app.buttons["Rename Weekly review"].tap()
        let rename = app.alerts["Rename Summary Preset"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        let name = rename.textFields.firstMatch
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Weekly review".count) + "Completed today")
        rename.buttons["Save"].tap()
        namePreset("Temporary preset")
        app.buttons["Delete Temporary preset"].tap()
        XCTAssertFalse(app.buttons["Delete Temporary preset"].exists)
        app.buttons["summaryPresetManage"].tap()
        XCTAssertFalse(app.buttons["Temporary preset"].exists)
        app.buttons["Completed today"].tap()
        done.tap()
        waitGone(done)
        XCTAssertEqual(report.value as? String, selectedReport)
    }

    @MainActor func testSummaryFailedNoteSaveRecoversWithoutSubmitting() {
        let app = launch(qaCase: "summary-save-failure")
        goTo("Summary", in: app)
        let report = app.textViews["summaryText"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()
        report.typeText("Keep this report")
        guard let draft = report.value as? String, draft.contains("Keep this report") else {
            XCTFail("The draft report was not visible")
            return
        }
        let save = app.buttons["summarySave"]
        reveal(save, in: app)
        save.tap()
        let feedback = app.staticTexts["summaryFeedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 8))
        XCTAssertTrue(feedback.label.hasPrefix("Could not save"))
        XCTAssertEqual(report.value as? String, draft)
        app.terminate()
        app.launch()
        let recovery = app.alerts["Resume new task?"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 10))
        recovery.buttons["Resume"].tap()
        let body = app.textViews["captureDescription"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertEqual(body.value as? String, draft)
        attach(app, "Recovered local Summary note")
        app.buttons["captureCancel"].tap()
        waitGone(body)
        XCTAssertFalse(app.staticTexts["Note added"].exists)
    }

    @MainActor func testListSectionOrganizerDragReordersRows() {
        let app = launch()
        goTo("Work", in: app)
        app.buttons["Manage Sections"].tap()
        let name = app.textFields["sectionName"]
        let save = app.buttons["sectionSaveName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Planning"); save.tap()
        let first = app.buttons["Actions for Planning"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Active"); save.tap()
        let second = app.buttons["Actions for Active"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        let grip = app.descendants(matching: .any).matching(identifier: "Drag Active").firstMatch
        reveal(grip, in: app)
        XCTAssertTrue(first.isHittable)
        grip.press(forDuration: 0.1, thenDragTo: first)
        let ordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in second.frame.minY < first.frame.minY }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ordered], timeout: 6), .completed)
        attach(app, "Section organizer reordered by drag")
    }

    @MainActor func testListSectionsCreateMoveAndRemoveWithoutLosingTask() {
        let app = launch()
        goTo("Work", in: app)
        let name = app.textFields["sectionName"]
        let save = app.buttons["sectionSaveName"]
        let manage = app.buttons["Manage Sections"]
        let done = app.buttons["sectionsDone"]
        manage.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Planning"); save.tap()
        let planning = app.buttons["Actions for Planning"]
        XCTAssertTrue(planning.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Active"); save.tap()
        let active = app.buttons["Actions for Active"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        active.tap(); app.buttons["Move Up"].tap()
        let ordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in active.frame.minY < planning.frame.minY }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ordered], timeout: 5), .completed)
        active.tap(); app.buttons["Rename"].tap()
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Active".count) + "Doing")
        save.tap()
        let doing = app.buttons["Actions for Doing"]
        XCTAssertTrue(doing.waitForExistence(timeout: 5))
        done.tap()
        waitGone(done)

        app.buttons["Add task to Planning"].tap()
        let title = app.textViews["captureTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Local section task")
        finishCapture(app)
        app.segmentedControls["listViewMode"].buttons["Board"].tap()
        let planningTab = app.buttons["Planning"], doingTab = app.buttons["Doing"]
        XCTAssertTrue(planningTab.waitForExistence(timeout: 5)); planningTab.tap()
        let card = app.buttons["Local section task"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let grip = app.descendants(matching: .any).matching(identifier: "Drag Local section task").firstMatch
        reveal(grip, in: app)
        grip.press(forDuration: 0.8, thenDragTo: doingTab)
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true AND value == %@", "1"), object: doingTab)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 8), .completed)
        XCTAssertTrue(card.exists)
        attach(app, "Moved card in Doing")

        manage.tap()
        XCTAssertTrue(doing.waitForExistence(timeout: 5))
        doing.tap(); app.buttons["Remove"].tap()
        app.alerts["Remove section?"].buttons["Remove Section"].tap()
        waitGone(doing)
        done.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertTrue(app.segmentedControls["listViewMode"].buttons["Board"].isSelected)
        XCTAssertFalse(doingTab.exists)
        XCTAssertTrue(planningTab.exists)
        XCTAssertTrue(app.buttons["boardSection-none"].isSelected)
        XCTAssertTrue(card.exists)
    }

    @MainActor func testTimelineSuccessFeedbackExpiresWithoutUndoingSchedule() {
        let app = launch(qaCase: "all-day-spans")
        goTo("Work", in: app)
        app.segmentedControls["listViewMode"].buttons["Timeline"].tap()
        let move = app.buttons["Move Three-day workshop"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        let before = move.frame.minX
        let grip = move.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grip.press(forDuration: 0.06, thenDragTo: grip.withOffset(CGVector(dx: 36, dy: 0)))
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertTrue(app.buttons["undoCalendarSchedule"].exists)
        attach(app, "Phone schedule feedback before automatic dismissal")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: notice)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 9), .completed)
        XCTAssertFalse(app.buttons["undoCalendarSchedule"].exists)
        XCTAssertEqual(move.frame.minX, before + 36, accuracy: 3)
        attach(app, "Phone schedule feedback dismissed; schedule retained")
    }

    @MainActor func testTimelineMovesResizesAndCapturesOnTheAxis() {
        let app = launch(qaCase: "all-day-spans")
        goTo("Work", in: app)
        app.segmentedControls["listViewMode"].buttons["Timeline"].tap()
        let move = app.buttons["Move Three-day workshop"]
        let resize = app.buttons["Resize end of Three-day workshop"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        XCTAssertTrue(resize.isHittable)
        let baselineMoveX = move.frame.minX, baselineEndX = resize.frame.minX
        let notice = app.staticTexts["calendarScheduleNotice"]
        func drag(_ handle: XCUIElement, by points: CGFloat) {
            let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            grip.press(forDuration: 0.06, thenDragTo: grip.withOffset(CGVector(dx: points, dy: 0)))
        }
        drag(move, by: 6)
        XCTAssertFalse(notice.exists)
        XCTAssertEqual(move.frame.minX, baselineMoveX, accuracy: 2)
        drag(move, by: 36)
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(move.frame.minX, baselineMoveX + 36, accuracy: 3)
        XCTAssertEqual(resize.frame.minX, baselineEndX + 36, accuracy: 3)
        attach(app, "Timeline drag moved both endpoints")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(move.frame.minX, baselineMoveX, accuracy: 2)

        drag(resize, by: 36)
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(move.frame.minX, baselineMoveX, accuracy: 2)
        XCTAssertEqual(resize.frame.minX, baselineEndX + 36, accuracy: 3)
        attach(app, "Timeline end resize kept the start fixed")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(resize.frame.minX, baselineEndX, accuracy: 2)

        let axis = app.scrollViews["taskTimelineAxis"]
        let rail = app.buttons["timelineCaptureRail"]
        app.segmentedControls["taskTimelineScale"].buttons["Day"].tap()
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        let blank = axis.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 168, dy: rail.frame.midY - axis.frame.minY))
        blank.press(forDuration: 0.6)
        let title = app.textViews["captureTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.buttons["captureCancel"].tap()
        waitGone(title)
        blank.press(forDuration: 0.6)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Timeline capture tomorrow")
        finishCapture(app)
        if app.buttons["taskDetailDone"].exists { app.buttons["taskDetailDone"].tap() }
        XCTAssertTrue(app.buttons["Move Timeline capture tomorrow"].waitForExistence(timeout: 5))
        attach(app, "Timeline date capture retained the typed title")
    }

    @MainActor func testTimelinePinchKeepsTheDateUnderTheGesture() {
        let app = launch(qaCase: "all-day-spans")
        goTo("Work", in: app)
        app.segmentedControls["listViewMode"].buttons["Timeline"].tap()
        let axis = app.scrollViews["taskTimelineAxis"]
        let reset = app.buttons["taskTimelineZoom"]
        let mark = app.staticTexts["taskTimelineMark-1"]
        let period = app.staticTexts["taskTimelinePeriod"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        let originalPeriod = period.label
        let center = axis.frame.midX
        let originalX = mark.frame.minX
        axis.pinch(withScale: 1.55, velocity: 1)
        let value = reset.value as? String ?? ""
        let percent = Int(value.split(separator: " ").first ?? "0") ?? 0
        XCTAssertGreaterThan(percent, 115)
        let expected = center + (originalX - center) * CGFloat(percent) / 100
        XCTAssertEqual(mark.frame.minX, expected, accuracy: 16)
        XCTAssertEqual(period.label, originalPeriod)
        attach(app, "Timeline pinch keeps the date near the gesture center")

        app.buttons["Zoom task timeline in"].tap()
        XCTAssertNotEqual(reset.value as? String, value)
        XCTAssertEqual(period.label, originalPeriod)
        reset.tap()
        XCTAssertEqual(reset.value as? String, "100 percent")
        app.buttons["Zoom task timeline out"].tap()
        XCTAssertEqual(reset.value as? String, "80 percent")
        app.segmentedControls["taskTimelineScale"].buttons["Day"].tap()
        XCTAssertEqual(reset.value as? String, "100 percent")
        XCTAssertFalse(app.staticTexts["calendarScheduleNotice"].exists)
    }

    @MainActor func testTimelineColorsChangeWithoutChangingTheSchedule() {
        let app = launch(qaCase: "timeline")
        goTo("Work", in: app)
        app.segmentedControls["listViewMode"].buttons["Timeline"].tap()
        let color = app.buttons["taskTimelineColor"]
        let schedule = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(color.waitForExistence(timeout: 5))
        let original = schedule.value as? String
        XCTAssertNotNil(original)
        func choose(_ option: String) {
            color.tap()
            let submenu = app.buttons["Color by"]
            if !app.buttons[option].exists && submenu.exists { submenu.tap() }
            let choice = app.buttons[option]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            XCTAssertEqual(color.value as? String, option)
            XCTAssertEqual(schedule.value as? String, original)
            attach(app, "Timeline colored by " + option)
        }
        choose("Tag")
        choose("Priority")
    }

    @MainActor func testTimelineArrangesAnUndatedTaskByDroppingOnTheAxis() {
        let app = launch(qaCase: "timeline-arrange")
        goTo("Work", in: app)
        app.segmentedControls["listViewMode"].buttons["Timeline"].tap()
        let grip = app.images["timelineArrangeDrag-00000000-0000-0000-0000-000000000008"]
        let undated = app.buttons["timelineUndated-00000000-0000-0000-0000-000000000008"]
        let scheduled = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000008"]
        let notice = app.staticTexts["calendarScheduleNotice"]
        let axis = app.scrollViews["taskTimelineAxis"], rail = app.buttons["timelineCaptureRail"]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        func drag(to target: XCUICoordinate) {
            grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.55, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        func date(at offset: CGFloat) -> XCUICoordinate {
            axis.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: offset, dy: rail.frame.midY - axis.frame.minY))
        }
        drag(to: app.buttons["Previous Timeline period"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertTrue(undated.exists)
        XCTAssertFalse(notice.exists)
        drag(to: date(at: 46))
        XCTAssertTrue(scheduled.waitForExistence(timeout: 5))
        XCTAssertFalse(undated.exists)
        XCTAssertEqual(notice.label, "Schedule updated")
        attach(app, "Undated task dropped onto a Week date")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertTrue(undated.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule restored")

        app.segmentedControls["taskTimelineScale"].buttons["Day"].tap()
        drag(to: date(at: 108))
        XCTAssertTrue(scheduled.waitForExistence(timeout: 5))
        XCTAssertFalse(undated.exists)
        attach(app, "Undated task dropped onto a Day time")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertTrue(scheduled.waitForExistence(timeout: 5))
        XCTAssertFalse(undated.exists)
    }

    @MainActor func testTimelineUsesSavedSectionsAndListHeadings() {
        let app = launch(qaCase: "timeline")
        goTo("Work", in: app)
        app.segmentedControls["listViewMode"].buttons["Timeline"].tap()
        let build = app.staticTexts["Build"], review = app.staticTexts["Review"]
        XCTAssertTrue(build.waitForExistence(timeout: 5))
        XCTAssertTrue(review.exists)
        let outline = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000001"]
        let plan = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(outline.exists && plan.exists)
        XCTAssertLessThan(build.frame.midY, outline.frame.midY)
        XCTAssertLessThan(outline.frame.midY, review.frame.midY)
        XCTAssertLessThan(review.frame.midY, plan.frame.midY)
        attach(app, "Timeline section headings and scheduled tasks")
        goTo("Work and Personal", in: app)
        selectScopedView("Timeline View", in: app)
        XCTAssertTrue(app.staticTexts["Work · Build"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Work · Review"].exists)
        XCTAssertTrue(app.staticTexts["Personal"].exists)
        XCTAssertFalse(app.staticTexts["Old projects"].exists)
    }

    @MainActor func testTimelineScopesScaleAndUndatedScheduleUndo() {
        let app = launch(qaCase: "timeline")
        goTo("Work", in: app)
        let listMode = app.segmentedControls["listViewMode"]
        listMode.buttons["Timeline"].tap()
        let scales = app.segmentedControls["taskTimelineScale"]
        XCTAssertTrue(scales.waitForExistence(timeout: 5))
        let workRange = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000002"]
        let undated = app.buttons["timelineUndated-00000000-0000-0000-0000-000000000008"]
        let personal = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000006"]
        let archived = app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000005"]
        XCTAssertTrue(workRange.exists)
        XCTAssertTrue(undated.exists)
        XCTAssertFalse(personal.exists)
        XCTAssertFalse(archived.exists)
        attach(app, "Work Timeline with range and undated task")

        scales.buttons["Day"].tap()
        XCTAssertTrue(scales.buttons["Day"].isSelected)
        let period = app.staticTexts["taskTimelinePeriod"]
        let currentPeriod = period.label
        app.buttons["Next Timeline period"].tap()
        XCTAssertNotEqual(period.label, currentPeriod)
        XCTAssertFalse(workRange.exists)
        app.buttons["Today"].tap()
        XCTAssertTrue(workRange.waitForExistence(timeout: 5))
        scales.buttons["Month"].tap()
        XCTAssertTrue(scales.buttons["Month"].isSelected)
        scales.buttons["Week"].tap()

        let schedule = app.buttons["Schedule Review the draft"]
        reveal(schedule, in: app)
        schedule.tap()
        let cancel = app.buttons["calendarEditCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        waitGone(cancel)
        XCTAssertTrue(undated.exists)
        schedule.tap()
        app.buttons["calendarEditDone"].tap()
        XCTAssertTrue(app.buttons["timelineScheduled-00000000-0000-0000-0000-000000000008"].waitForExistence(timeout: 5))
        XCTAssertFalse(undated.exists)
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertTrue(undated.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["calendarScheduleNotice"].label, "Schedule restored")

        goTo("Personal", in: app)
        XCTAssertTrue(listMode.buttons["List"].isSelected)
        goTo("Open Launch projects", in: app)
        selectScopedView("Timeline View", in: app)
        XCTAssertTrue(workRange.waitForExistence(timeout: 5))
        XCTAssertTrue(undated.exists)
        XCTAssertFalse(personal.exists)
        XCTAssertFalse(archived.exists)

        goTo("Work and Personal", in: app)
        selectScopedView("Timeline View", in: app)
        XCTAssertTrue(personal.waitForExistence(timeout: 5))
        XCTAssertTrue(workRange.exists)
        XCTAssertFalse(archived.exists)
        attach(app, "Saved filter Timeline")

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertTrue(listMode.buttons["Timeline"].isSelected)
        XCTAssertTrue(undated.waitForExistence(timeout: 5))
    }

    @MainActor private func selectScopedView(_ name: String, in app: XCUIApplication) {
        app.buttons["taskListActions"].tap()
        app.buttons["taskDestinationViewMode"].tap()
        let choice = app.buttons[name]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        XCTAssertEqual(app.buttons["taskListActions"].value as? String, name)
        XCTAssertFalse(app.segmentedControls["taskDestinationViewMode"].exists)
    }

    @MainActor private func selectScopedGrouping(_ name: String, in app: XCUIApplication) {
        app.buttons["taskListActions"].tap()
        app.buttons["scopedBoardGrouping"].tap()
        XCTAssertTrue(app.buttons["boardGroup-list"].waitForExistence(timeout: 5))
        if name.hasPrefix("Title ·") {
            let wanted = name.contains("Descending") ? "Descending" : "Ascending"
            let direction = app.buttons["boardSortDirection"]
            if direction.value as? String != wanted { direction.tap() }
            app.buttons["boardSort-title"].tap()
        } else {
            let key = name == "Created Time" ? "createdTime" : name.lowercased()
            app.buttons["boardGroup-" + key].tap()
        }
        XCTAssertTrue(app.buttons["boardGroup-list"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        waitGone(app.buttons["boardGroup-list"])
    }

    @MainActor func testPriorityBoardEmptyState() {
        let app = launch(qaCase: "capture-empty")
        selectScopedView("Kanban View", in: app)
        selectScopedGrouping("Priority", in: app)
        XCTAssertTrue(app.staticTexts["No tasks"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scopedBoardColumn-0"].exists)
        attach(app, "Empty Priority board")
        selectScopedGrouping("Date", in: app)
        XCTAssertTrue(app.buttons["scopedBoardColumn-0"].waitForExistence(timeout: 5))
    }

    @MainActor func testPriorityBoardDisplayAndLastLaneRemoval() {
        let app = launch(qaCase: "timeline")
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        selectScopedGrouping("Priority", in: app)
        let lane = app.buttons["scopedBoardColumn-0"]
        XCTAssertTrue(lane.waitForExistence(timeout: 5))
        XCTAssertEqual(lane.label, "No Priority")
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(card.exists)
        XCTAssertFalse(app.buttons["Move Prepare the weekly plan"].exists)
        XCTAssertFalse(app.otherElements["Drag Prepare the weekly plan"].exists)
        attach(app, "Priority board display-only lane")
        card.tap()
        openTaskMetadata("editTaskPriority", in: app)
        app.buttons["taskPriority-high"].tap()
        waitGone(app.buttons["taskPriority-high"])
        app.buttons["taskDetailDone"].tap()
        XCTAssertEqual(lane.label, "High Priority")
        lane.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        openTaskMetadata("editTaskPriority", in: app)
        app.buttons["taskPriority-none"].tap()
        waitGone(app.buttons["taskPriority-none"])
        app.buttons["taskDetailDone"].tap()
        XCTAssertEqual(lane.label, "No Priority")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        selectScopedGrouping("List", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }

    @MainActor func testCompactBoardCardLayoutEvidence() {
        let app = launch(qaCase: "timeline")
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "Prepare the weekly plan")
        XCTAssertGreaterThanOrEqual(card.frame.height, 44)
        XCTAssertLessThanOrEqual(card.frame.height, 48)
        attach(app, "Compact Kanban card with trailing date")
        card.tap()
        XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
        app.buttons["taskDetailDone"].tap()

        app.terminate()
        let originalArguments = app.launchArguments
        app.launchArguments = originalArguments + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "Prepare the weekly plan")
        XCTAssertGreaterThanOrEqual(card.frame.height, 44)
        attach(app, "Kanban card largest standard text size")
        app.terminate()
        app.launchArguments = originalArguments + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "Prepare the weekly plan")
        XCTAssertGreaterThan(card.frame.height, 48)
        attach(app, "Kanban card accessibility text fallback")
    }

    @MainActor func testTodayViewMenuEvidence() {
        let app = launch()
        XCTAssertFalse(app.segmentedControls["taskDestinationViewMode"].exists)
        app.buttons["taskListActions"].tap()
        app.buttons["taskDestinationViewMode"].tap()
        XCTAssertTrue(app.buttons["List View"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Kanban View"].exists)
        attach(app, "Today View submenu")
        app.buttons["Kanban View"].tap()
        XCTAssertEqual(app.buttons["taskListActions"].value as? String, "Kanban View")
        attach(app, "Today Kanban without permanent mode controls")
        app.buttons["taskListActions"].tap()
        app.buttons["scopedBoardGrouping"].tap()
        XCTAssertTrue(app.buttons["boardGroup-date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["boardGroup-list"].exists)
        attach(app, "Today Group and Sort sheet")
        app.buttons["boardGroup-date"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        waitGone(app.buttons["boardGroup-date"])
        selectScopedView("List View", in: app)
    }

    @MainActor func testScopedViewMenuCanReturnToList() {
        let app = launch(qaCase: "timeline")
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        selectScopedGrouping("Date", in: app)
        selectScopedView("List View", in: app)
        XCTAssertFalse(app.buttons["scopedBoardColumn-0"].exists)
        selectScopedView("Kanban View", in: app)
        XCTAssertTrue(app.buttons["scopedBoardColumn-0"].waitForExistence(timeout: 5))
    }

    @MainActor func testScopedBoardMovesDateAndUndoesRange() {
        let app = launch(qaCase: "all-day-spans")
        goTo("Next 7 Days", in: app)
        selectScopedView("Kanban View", in: app)
        XCTAssertFalse(app.segmentedControls["scopedBoardGrouping"].exists)
        let original = app.buttons["scopedBoardColumn-2"]
        let next = app.buttons["scopedBoardColumn-3"]
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        original.tap()
        let move = app.buttons["Move Three-day workshop"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        let nextTitle = next.label
        move.tap()
        let target = app.buttons["Move to " + nextTitle]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        let undo = app.buttons["undoCalendarSchedule"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(next.isSelected)
        XCTAssertTrue(move.exists)
        attach(app, "Date column after moving an inclusive range")
        undo.tap()
        original.tap()
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["calendarScheduleNotice"].label, "Schedule restored")
    }

    @MainActor func testScopedBoardFolderAndTagListMove() {
        let app = launch(qaCase: "timeline")
        let work = app.buttons["scopedBoardColumn-0"]
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000002"]
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertEqual(work.label, "Work")
        XCTAssertFalse(app.buttons["scopedBoardColumn-1"].exists)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        selectScopedGrouping("Date", in: app)
        selectScopedGrouping("List", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        goTo("drawerTag-00000000-0000-0000-0000-000000000200", in: app)
        selectScopedView("Kanban View", in: app)
        let workTab = app.buttons["scopedBoardColumn-1"]
        let personal = app.buttons["scopedBoardColumn-2"]
        XCTAssertTrue(workTab.waitForExistence(timeout: 5))
        workTab.tap()
        let move = app.buttons["Move Prepare the weekly plan"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.tap()
        app.buttons["Move to Personal"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(personal.isSelected)
        attach(app, "Tag Board with the card in its new list")
        goTo("Open Launch projects", in: app)
        XCTAssertEqual(app.buttons["taskListActions"].value as? String, "Kanban View")
        XCTAssertFalse(card.exists)
    }

    @MainActor func testScopedBoardDragsTagCardAcrossLists() {
        let app = launch(qaCase: "timeline")
        goTo("drawerTag-00000000-0000-0000-0000-000000000200", in: app)
        selectScopedView("Kanban View", in: app)
        let work = app.buttons["scopedBoardColumn-1"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let personal = app.buttons["scopedBoardColumn-2"]
        let grip = app.descendants(matching: .any).matching(identifier: "Drag Prepare the weekly plan").firstMatch
        reveal(grip, in: app)
        grip.press(forDuration: 0.8, thenDragTo: personal)
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true AND value == %@", "1"),
                                               object: personal)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 8), .completed)
        XCTAssertTrue(app.buttons["boardCard-00000000-0000-0000-0000-000000000002"].exists)
        attach(app, "Tag Board after dragging to a different list")
    }

    @MainActor func testBoardModeIsPerListAndSurvivesRelaunch() {
        let app = launch(qaCase: "board")
        goTo("Work", in: app)
        selectBoardMode(in: app)
        XCTAssertTrue(app.buttons["boardColumn-open"].isSelected)
        XCTAssertTrue(app.buttons["boardColumn-wontDo"].exists)
        goTo("Personal", in: app)
        XCTAssertTrue(app.segmentedControls["listViewMode"].buttons["List"].isSelected)
        XCTAssertFalse(app.buttons["boardColumn-open"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Work", in: app)
        XCTAssertTrue(app.segmentedControls["listViewMode"].buttons["Board"].isSelected)
        XCTAssertTrue(app.buttons["boardCard-00000000-0000-0000-0000-000000000005"].waitForExistence(timeout: 5))
        attach(app, "Open board cards")
    }

    @MainActor func testBoardCompletesRecurringCardFromWontDoAndUndo() {
        let app = launch(qaCase: "board")
        goTo("Work", in: app)
        selectBoardMode(in: app)
        let wont = app.buttons["boardColumn-wontDo"], open = app.buttons["boardColumn-open"]
        let before = open.value as? String
        wont.tap()
        let move = app.buttons["boardMove-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        reveal(move, in: app)
        move.tap()
        app.buttons["Move to Completed"].tap()
        let undo = app.buttons["undoLifecycle"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["boardColumn-completed"].isSelected)
        XCTAssertNotEqual(open.value as? String, before)
        attach(app, "Completed board card")
        undo.tap()
        XCTAssertTrue(app.staticTexts["Change undone"].waitForExistence(timeout: 5))
        XCTAssertEqual(open.value as? String, before)
        wont.tap()
        XCTAssertTrue(app.buttons["boardCard-00000000-0000-0000-0000-000000000002"].waitForExistence(timeout: 5))
    }

    @MainActor func testBoardArchiveDisplaysCompletedOnlyAndDisablesChanges() {
        let app = launch(qaCase: "board")
        goTo("Reference Board", in: app)
        XCTAssertTrue(app.staticTexts["boardArchiveNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["listViewMode"].buttons["List"].isEnabled)
        XCTAssertEqual(app.buttons["boardColumn-open"].value as? String, "0")
        app.buttons["boardColumn-completed"].tap()
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000003"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.isHittable)
        XCTAssertFalse(app.buttons["boardMove-00000000-0000-0000-0000-000000000003"].exists)
        XCTAssertFalse(app.buttons["lifecycleToggle-00000000-0000-0000-0000-000000000003"].exists)
        attach(app, "Archived completed-only board")
    }

    @MainActor func testBoardDragMovesCardAndRefusesNote() {
        let app = launch(qaCase: "board")
        goTo("Work", in: app)
        selectBoardMode(in: app)
        let note = app.buttons["boardCard-00000000-0000-0000-0000-000000000005"]
        let completed = app.buttons["boardColumn-completed"]
        reveal(note, in: app)
        note.press(forDuration: 0.9, thenDragTo: completed)
        XCTAssertTrue(app.staticTexts["boardMoveNotice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["boardColumn-open"].isSelected)
        let task = app.buttons["boardCard-00000000-0000-0000-0000-000000000006"]
        reveal(task, in: app)
        task.press(forDuration: 0.9, thenDragTo: completed)
        XCTAssertTrue(app.buttons["undoLifecycle"].waitForExistence(timeout: 5))
        XCTAssertTrue(completed.isSelected)
        XCTAssertTrue(task.isHittable)
    }

    @MainActor private func selectBoardMode(in app: XCUIApplication) {
        let control = app.segmentedControls["listViewMode"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        control.buttons["Board"].tap()
        XCTAssertTrue(app.buttons["boardColumn-open"].waitForExistence(timeout: 5))
    }

    @MainActor private func openTagManager(in app: XCUIApplication) {
        app.buttons["Open navigation"].tap()
        app.buttons["manageTags"].tap()
        XCTAssertTrue(app.buttons["tagManagerDone"].waitForExistence(timeout: 5))
    }
}


extension ReadOnlyNavigationTests {
    @MainActor private func openMoveHierarchy(_ app: XCUIApplication) {
        let task = app.buttons["Review the project outline"]
        XCTAssertTrue(task.waitForExistence(timeout: 5)); task.tap()
        XCTAssertTrue(app.buttons["taskMoveList"].waitForExistence(timeout: 5))
        app.buttons["taskMoveList"].tap()
        XCTAssertTrue(app.navigationBars["Move to"].waitForExistence(timeout: 5))
    }

    @MainActor func testMoveHierarchySearchFolderCurrentAndClosePreserveTask() {
        let app = launch(qaCase: "move-hierarchy")
        openMoveHierarchy(app)
        let folder = app.buttons["taskMoveFolder-00000000-0000-0000-0000-000000000700"]
        let work = app.buttons["taskMoveTarget-00000000-0000-0000-0000-000000000100"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        XCTAssertFalse(work.exists)
        folder.tap()
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertEqual(work.value as? String, "Current list")
        XCTAssertFalse(work.isEnabled)
        folder.tap(); XCTAssertFalse(work.exists)
        let search = app.textFields["taskMoveSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Work")
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskMoveTarget-inbox"].exists)
        attach(app, "Move to searched folder and current list")
        app.buttons["taskMoveClose"].tap()
        waitGone(app.navigationBars["Move to"])
        XCTAssertTrue(app.buttons["taskMoveList"].label.contains("Work"))
        app.buttons["taskDetailDone"].tap()
        app.terminate(); app.launch()
        openMoveHierarchy(app)
        app.buttons["taskMoveFolder-00000000-0000-0000-0000-000000000700"].tap()
        XCTAssertEqual(work.value as? String, "Current list")
        app.buttons["taskMoveClose"].tap()
    }

    @MainActor func testMoveHierarchyActualMoveReopensWithNewCurrentDestination() {
        let app = launch(qaCase: "move-hierarchy")
        openMoveHierarchy(app)
        let inbox = app.buttons["taskMoveTarget-inbox"]
        XCTAssertTrue(inbox.isEnabled); inbox.tap()
        waitGone(app.navigationBars["Move to"])
        XCTAssertTrue(app.buttons["taskMoveList"].label.contains("Inbox"))
        app.buttons["taskMoveList"].tap()
        XCTAssertTrue(inbox.waitForExistence(timeout: 5))
        XCTAssertEqual(inbox.value as? String, "Current list")
        XCTAssertFalse(inbox.isEnabled)
        app.buttons["taskMoveFolder-00000000-0000-0000-0000-000000000700"].tap()
        let work = app.buttons["taskMoveTarget-00000000-0000-0000-0000-000000000100"]
        XCTAssertTrue(work.isEnabled); work.tap()
        waitGone(app.navigationBars["Move to"])
        XCTAssertTrue(app.buttons["taskMoveList"].label.contains("Work"))
    }

    @MainActor func testMoveHierarchyAddListCancelAndCreateNeverImplicitlyMove() {
        let app = launch(qaCase: "move-hierarchy")
        openMoveHierarchy(app)
        app.buttons["taskMoveAddList"].tap()
        XCTAssertTrue(app.buttons["organizationCancel"].waitForExistence(timeout: 5))
        app.buttons["organizationCancel"].tap()
        waitGone(app.buttons["organizationCancel"])
        XCTAssertTrue(app.navigationBars["Move to"].exists)
        app.buttons["taskMoveClose"].tap()
        XCTAssertTrue(app.buttons["taskMoveList"].label.contains("Work"))
        app.buttons["taskMoveList"].tap()
        app.buttons["taskMoveAddList"].tap()
        editOrganizationName("Neutral destination", in: app)
        XCTAssertEqual(app.buttons["organizationView-list"].value as? String, "Selected")
        app.buttons["organizationSave"].tap()
        waitGone(app.buttons["organizationSave"])
        waitGone(app.navigationBars["Move to"])
        XCTAssertTrue(app.buttons["taskMoveList"].label.contains("Work"))
        app.buttons["taskMoveList"].tap()
        let target = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "taskMoveTarget-", "Neutral destination")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5)); XCTAssertTrue(target.isEnabled)
        attach(app, "New list available without implicit task movement")
        target.tap(); waitGone(app.navigationBars["Move to"])
        XCTAssertTrue(app.buttons["taskMoveList"].label.contains("Neutral destination"))
    }

    @MainActor func testAssignedTagsPartitionSearchAndCloseDiscard() {
        let app = launch(qaCase: "assigned-tags")
        app.buttons["Review the project outline"].tap()
        openTaskMetadata("editTaskTags", in: app)
        let planning = app.buttons["taskTag-00000000-0000-0000-0000-000000000200"]
        let studio = app.buttons["taskTag-00000000-0000-0000-0000-000000000201"]
        XCTAssertTrue(studio.waitForExistence(timeout: 5))
        XCTAssertEqual(studio.value as? String, "Selected")
        XCTAssertEqual(planning.value as? String, "Not selected")
        XCTAssertLessThan(studio.frame.minY, planning.frame.minY)
        XCTAssertEqual(app.buttons["taskMetadataCancel"].label, "Close")
        attach(app, "Assigned checked tags separate from remaining tags")
        planning.tap()
        XCTAssertEqual(planning.value as? String, "Selected")
        XCTAssertLessThan(planning.frame.minY, studio.frame.minY)
        studio.tap()
        XCTAssertEqual(studio.value as? String, "Not selected")
        let search = app.textFields["searchTaskTags"]
        XCTAssertEqual(search.placeholderValue, "Input Tag")
        search.tap(); search.typeText("Studio")
        XCTAssertTrue(studio.exists); XCTAssertFalse(planning.exists)
        search.typeText(" no match")
        XCTAssertTrue(app.staticTexts["No matching tags"].exists)
        app.buttons["taskMetadataCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["taskMetadataCancel"])
        XCTAssertEqual(app.buttons["editTaskTags"].value as? String, "Studio, 1 unavailable")
        openTaskMetadata("editTaskTags", in: app)
        XCTAssertEqual(studio.value as? String, "Selected")
        XCTAssertEqual(planning.value as? String, "Not selected")
        app.buttons["taskMetadataCancel"].tap()
    }

    @MainActor func testAssignedTagsSaveRetainsUnavailableIDsAcrossRelaunch() {
        let app = launch(qaCase: "assigned-tags")
        app.buttons["Review the project outline"].tap()
        openTaskMetadata("editTaskTags", in: app)
        app.buttons["taskTag-00000000-0000-0000-0000-000000000200"].tap()
        app.buttons["taskMetadataDone"].tap()
        waitGone(app.buttons["taskMetadataDone"])
        XCTAssertTrue((app.buttons["editTaskTags"].value as? String ?? "").contains("1 unavailable"))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 10))
        app.buttons["Review the project outline"].tap()
        openTaskMetadata("editTaskTags", in: app)
        XCTAssertEqual(app.buttons["taskTag-00000000-0000-0000-0000-000000000200"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["taskTag-00000000-0000-0000-0000-000000000201"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["Remove unavailable tags"].exists)
        app.buttons["taskMetadataCancel"].tap()
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openCalendarSourceHierarchy(_ app: XCUIApplication) {
        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        XCTAssertTrue(app.navigationBars["Filter View Range"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarSourceFoldersExpandWithoutChangingSelectionAndCancel() {
        let app = launch(qaCase: "calendar-filter-hierarchy")
        app.buttons["Calendar"].tap()
        openCalendarSourceHierarchy(app)
        let all = app.buttons["All"], tags = app.buttons["calendarFilterTags"]
        let folder = app.buttons["calendarFilterFolder-00000000-0000-0000-0000-000000000700"]
        XCTAssertEqual(all.value as? String, "Selected")
        XCTAssertTrue(app.buttons["Planning"].exists)
        tags.tap(); XCTAssertFalse(app.buttons["Planning"].exists)
        tags.tap(); XCTAssertTrue(app.buttons["Planning"].exists)
        reveal(folder, in: app); folder.tap()
        let work = app.buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertEqual(work.value as? String, "Not selected")
        XCTAssertEqual(all.value as? String, "Selected")
        attach(app, "Calendar filter expanded Tags and folder sources")
        work.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarPreferencesCancel"].tap()
        openCalendarSourceHierarchy(app)
        XCTAssertEqual(all.value as? String, "Selected")
        app.buttons["calendarPreferencesDone"].tap()
        openCalendarSourceHierarchy(app)
        XCTAssertEqual(all.value as? String, "Selected")
        app.buttons["calendarPreferencesCancel"].tap()
    }

    @MainActor func testCalendarSourceTagInboxUnionPersistsAndAllReset() {
        let app = launch(qaCase: "calendar-filter-hierarchy")
        app.buttons["Calendar"].tap()
        openCalendarSourceHierarchy(app)
        let planning = app.buttons["Planning"], inbox = app.buttons["Inbox"]
        planning.tap()
        XCTAssertEqual(planning.value as? String, "Selected")
        XCTAssertEqual(inbox.value as? String, "Not selected")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse(app.buttons["Review the project outline"].exists)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        openCalendarSourceHierarchy(app)
        inbox.tap()
        XCTAssertEqual(planning.value as? String, "Selected")
        XCTAssertEqual(inbox.value as? String, "Selected")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openCalendarSourceHierarchy(app)
        XCTAssertEqual(planning.value as? String, "Selected")
        XCTAssertEqual(inbox.value as? String, "Selected")
        app.buttons["All"].tap()
        XCTAssertEqual(planning.value as? String, "Not selected")
        XCTAssertEqual(inbox.value as? String, "Not selected")
        app.buttons["calendarPreferencesDone"].tap()
    }

    @MainActor func testListCreationSelectedViewModesPersistAfterRelaunch() {
        let app = launch()
        for (mode, title, expected) in [("list", "Neutral List", "List"), ("board", "Neutral Board", "Board"), ("timeline", "Neutral Timeline", "Timeline")] {
            openOrganization(app)
            app.buttons["organizationNewList"].tap()
            XCTAssertTrue(app.navigationBars["Add List"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["organizationSave"].isEnabled)
            editOrganizationName(title, in: app)
            let choice = app.buttons["organizationView-" + mode]
            reveal(choice, in: app); choice.tap()
            XCTAssertEqual(choice.value as? String, "Selected")
            attach(app, "Add List selected " + mode)
            finishOrganizationEdit(app)
            app.buttons["organizationManagerDone"].tap()
            let destination = app.buttons[title]
            XCTAssertTrue(destination.waitForExistence(timeout: 5))
            reveal(destination, in: app); destination.tap()
            waitGone(app.buttons["manageLists"])

            XCTAssertTrue(app.segmentedControls["listViewMode"].buttons[expected].isSelected)
            if mode == "board" {
                XCTAssertTrue(app.buttons["boardColumn-open"].waitForExistence(timeout: 5))
            } else if mode == "timeline" {
                XCTAssertTrue(app.descendants(matching: .any)["taskTimelineAxis"].waitForExistence(timeout: 5))
            }
            app.terminate(); app.launch()
            XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
            goTo(title, in: app)
            XCTAssertTrue(app.segmentedControls["listViewMode"].buttons[expected].isSelected)
            if mode == "board" {
                XCTAssertTrue(app.buttons["boardColumn-open"].waitForExistence(timeout: 5))
            } else if mode == "timeline" {
                XCTAssertTrue(app.descendants(matching: .any)["taskTimelineAxis"].waitForExistence(timeout: 5))
            }
        }
    }

    @MainActor func testListCreationViewSelectionCancelDoesNotCreateList() {
        let app = launch()
        openOrganization(app)
        app.buttons["organizationNewList"].tap()
        editOrganizationName("Discarded Board", in: app)
        let board = app.buttons["organizationView-board"]
        reveal(board, in: app); board.tap()
        revealListCreationMore(app)
        XCTAssertTrue(app.buttons["organizationPlacement"].exists)
        XCTAssertTrue(app.buttons["organizationIcon"].exists)
        setSwitch("organizationPin", to: true, app: app)
        app.buttons["organizationCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["organizationSave"])
        XCTAssertFalse(app.buttons["Discarded Board"].exists)
        app.buttons["organizationNewList"].tap()
        XCTAssertEqual(app.buttons["organizationView-list"].value as? String, "Selected")
        app.buttons["organizationCancel"].tap()
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testCalendarNestedFolderListSelectionSavesResultsAndRelaunches() {
        let app = launch(qaCase: "calendar-filter-hierarchy")
        app.buttons["Calendar"].tap()
        let inboxTask = app.buttons["Review the project outline"]
        let workTask = app.buttons["Prepare the weekly plan"]
        XCTAssertTrue(inboxTask.waitForExistence(timeout: 5))
        openCalendarSourceHierarchy(app)
        let folder = app.buttons["calendarFilterFolder-00000000-0000-0000-0000-000000000700"]
        reveal(folder, in: app); folder.tap()
        let work = app.buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        reveal(work, in: app); work.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        XCTAssertEqual(app.buttons["All"].value as? String, "Not selected")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse(inboxTask.exists)
        XCTAssertTrue(workTask.waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(workTask.waitForExistence(timeout: 5))
        XCTAssertFalse(inboxTask.exists)
        openCalendarSourceHierarchy(app)
        reveal(folder, in: app); folder.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        XCTAssertEqual(app.buttons["Planning"].value as? String, "Not selected")
        XCTAssertEqual(app.buttons["Inbox"].value as? String, "Not selected")
        app.buttons["calendarPreferencesCancel"].tap()
    }

    @MainActor func testListCreationPreviewScreenshotWithoutKeyboard() {
        let app = launch()
        openOrganization(app)
        app.buttons["organizationNewList"].tap()
        editOrganizationName("Neutral project", in: app)
        let board = app.buttons["organizationView-board"]
        reveal(board, in: app); board.tap()
        // Form uses interactive scroll dismissal. Do not capture an obscured preview.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.35))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.85)))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let list = app.buttons["organizationView-list"]
        let timeline = app.buttons["organizationView-timeline"]
        let more = app.buttons["organizationMore"]
        reveal(board, in: app)
        XCTAssertTrue(list.isHittable && board.isHittable && timeline.isHittable)
        XCTAssertTrue(more.isHittable)
        XCTAssertEqual(board.value as? String, "Selected")
        attach(app, "Add List view previews and More without keyboard")
        app.buttons["organizationCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["organizationSave"])
        XCTAssertFalse(app.buttons["Neutral project"].exists)
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testCalendarCompactSourceLayoutAndSecondaryActions() {
        let app = launch(qaCase: "calendar-filter-hierarchy")
        app.buttons["Calendar"].tap()
        app.buttons["Calendar actions"].tap()
        app.buttons["Filter View Range"].tap()
        let all = app.buttons["All"], inbox = app.buttons["Inbox"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertEqual(all.value as? String, "Selected")
        XCTAssertGreaterThanOrEqual(all.frame.height, 44)
        XCTAssertLessThanOrEqual(all.frame.height, 54)
        XCTAssertLessThanOrEqual(inbox.frame.height, 54)
        let folder = app.buttons["calendarFilterFolder-00000000-0000-0000-0000-000000000700"]
        folder.tap()
        let work = app.buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertTrue(work.isHittable)
        attach(app, "Calendar compact source layout")
        work.press(forDuration: 1)
        let only = app.buttons["Show only Work"]
        XCTAssertTrue(only.waitForExistence(timeout: 3)); only.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarFilterMore"].tap()
        let tags = app.buttons["Select all tags"]
        reveal(tags, in: app); tags.tap()
        XCTAssertEqual(app.buttons["Planning"].value as? String, "Selected")
        let lists = app.buttons["Select all lists and Inbox"]
        reveal(lists, in: app); lists.tap()
        XCTAssertEqual(lists.value as? String, "Selected")
        app.buttons["calendarPreferencesCancel"].tap()
        app.buttons["Calendar actions"].tap(); app.buttons["Filter View Range"].tap()
        XCTAssertEqual(app.buttons["All"].value as? String, "Selected")
        app.buttons["calendarPreferencesCancel"].tap()
    }
}


extension ReadOnlyNavigationTests {
    @MainActor func testTimePrecisionZoneAndOutsideDismissal() {
        let app = launch(qaCase: "time-precision")
        let originalEvidence = app.staticTexts["previewNotice"].value as? String
        XCTAssertTrue(originalEvidence?.contains("Pacific/Kiritimati") == true)
        _ = openSchedule(app, task: "Review the project outline")
        let time = app.buttons["scheduleTime"]
        reveal(time, in: app)
        XCTAssertTrue((time.value as? String)?.contains("0:15") == true)
        time.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual((wheels.element(boundBy: 0).value as? String)?.split(separator: " ").first.flatMap { Int($0) }, 0)
        XCTAssertEqual((wheels.element(boundBy: 1).value as? String)?.split(separator: " ").first.map(String.init), "15")
        XCTAssertEqual(app.descendants(matching: .any)["scheduleTimeZone"].firstMatch.value as? String, "Pacific/Kiritimati")
        attach(app, "Time popup in non-device zone")
        // The sheet title is visibly outside the popover; dismiss without selecting Done.
        app.navigationBars["Schedule"].staticTexts["Schedule"].tap()
        waitGone(app.buttons["scheduleTimePopoverDone"])
        XCTAssertTrue((time.value as? String)?.contains("0:15") == true)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["previewNotice"].value as? String, originalEvidence)
    }

    @MainActor private func openCalendarZoneSettings(_ app: XCUIApplication) {
        let entry = app.buttons["calendarZoneSettings"]
        reveal(entry, in: app)
        entry.tap()
        XCTAssertTrue(app.switches["calendarAdditionalZones"].waitForExistence(timeout: 5))
    }

    @MainActor func testCalendarZoneToggleChildCancelAndParentCancelAreStaged() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        openCalendarZoneSettings(app)
        let toggle = app.switches["calendarAdditionalZones"]
        let original = toggle.value as? String
        XCTAssertNotNil(original)
        setSwitch("calendarAdditionalZones", to: original != "1", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["calendarCurrentZone"].firstMatch.exists)
        attach(app, "Staged Additional Time Zone settings")
        app.buttons["calendarZonesCancel"].tap()
        waitGone(app.buttons["calendarZonesCancel"])
        openCalendarZoneSettings(app)
        XCTAssertEqual(toggle.value as? String, original)
        setSwitch("calendarAdditionalZones", to: original != "1", app: app)
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        openCalendarZoneSettings(app)
        XCTAssertEqual(toggle.value as? String, original == "1" ? "0" : "1")
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesCancel"])
        openCalendarViewOptions(app)
        openCalendarZoneSettings(app)
        XCTAssertEqual(toggle.value as? String, original)
        XCTAssertTrue(app.textFields["calendarZoneLabel-America/New_York"].exists)
    }

    @MainActor func testCalendarZoneOffRetainsConfigurationAndPersists() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        openCalendarZoneSettings(app)
        setSwitch("calendarAdditionalZones", to: true, app: app)
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(app.staticTexts["calendarRuler-America/New_York"].waitForExistence(timeout: 5))
        openCalendarViewOptions(app)
        openCalendarZoneSettings(app)
        setSwitch("calendarAdditionalZones", to: false, app: app)
        XCTAssertTrue(app.textFields["calendarZoneLabel-America/New_York"].exists)
        XCTAssertTrue(app.buttons["calendarZoneAdd"].isEnabled)
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse(app.staticTexts["calendarRuler-America/New_York"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        openCalendarZoneSettings(app)
        XCTAssertEqual(app.switches["calendarAdditionalZones"].value as? String, "0")
        XCTAssertTrue(app.textFields["calendarZoneLabel-America/New_York"].exists)
        setSwitch("calendarAdditionalZones", to: true, app: app)
        app.buttons["calendarZonesDone"].tap()
        waitGone(app.buttons["calendarZonesDone"])
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(app.staticTexts["calendarRuler-America/New_York"].waitForExistence(timeout: 5))
    }
}


extension ReadOnlyNavigationTests {
    @MainActor func testArrangeOptionsFilterUndatedNotesAndOverdueIndependently() {
        let app = launch(qaCase: "arrange-options")
        app.buttons["Calendar"].tap(); openArrange(app)
        let task = app.buttons["Schedule Neutral undated task"]
        let note = app.buttons["Schedule Neutral undated note"]
        let overdue = app.buttons["Schedule Neutral overdue task"]
        XCTAssertTrue(task.waitForExistence(timeout: 5)); XCTAssertTrue(note.exists); XCTAssertFalse(overdue.exists)
        app.buttons["arrangeOptions"].tap()
        XCTAssertEqual(app.buttons["arrangeUndated"].label, "Undated Task")
        XCTAssertEqual(app.buttons["arrangeNotes"].label, "Show Notes")
        attach(app, "Arrange options with undated tasks and notes")
        app.buttons["arrangeNotes"].tap()
        XCTAssertFalse(note.exists); XCTAssertTrue(task.exists)
        app.buttons["arrangeOptions"].tap(); app.buttons["arrangeUndated"].tap()
        XCTAssertFalse(task.exists); XCTAssertFalse(note.exists)
        app.buttons["arrangeOptions"].tap(); app.buttons["arrangeOverdue"].tap()
        XCTAssertTrue(overdue.waitForExistence(timeout: 5)); XCTAssertFalse(task.exists)
        app.buttons["arrangeOptions"].tap(); app.buttons["arrangeUndated"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5)); XCTAssertFalse(note.exists); XCTAssertTrue(overdue.exists)
        app.buttons["arrangeOptions"].tap(); app.buttons["arrangeNotes"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 5)); XCTAssertTrue(task.exists)
        app.buttons["arrangeDone"].tap()
        waitGone(app.buttons["arrangeDone"])
        openArrange(app)
        XCTAssertTrue(task.waitForExistence(timeout: 5)); XCTAssertTrue(note.exists); XCTAssertFalse(overdue.exists)
    }

    @MainActor func testDetailPriorityPopupChoicesPersistAndDismissWithoutChange() {
        let app = launch(), title = "Review the project outline"
        app.buttons[title].tap()
        let entry = app.buttons["editTaskPriority"]
        for (key, label) in [("high", "High"), ("medium", "Medium"), ("low", "Low"), ("none", "None")] {
            openTaskMetadata("editTaskPriority", in: app)
            let rows = ["high", "medium", "low", "none"].map { app.buttons["taskPriority-" + $0] }
            for index in 0..<3 { XCTAssertLessThan(rows[index].frame.minY, rows[index + 1].frame.minY) }
            XCTAssertTrue(rows[0].label.contains("High Priority"))
            XCTAssertTrue(rows[1].label.contains("Medium Priority"))
            XCTAssertTrue(rows[2].label.contains("Low Priority"))
            XCTAssertTrue(rows[3].label.contains("No Priority"))
            attach(app, "Detail Priority popup")
            app.buttons["taskPriority-" + key].tap()
            waitGone(rows[0])
            XCTAssertEqual(entry.value as? String, label)
            app.buttons["taskDetailDone"].tap()
            app.buttons[title].tap()
            XCTAssertEqual(entry.value as? String, label)
        }
        openTaskMetadata("editTaskPriority", in: app)
        XCTAssertTrue(app.buttons["taskPriority-none"].isSelected)
        app.navigationBars.firstMatch.tap()
        waitGone(app.buttons["taskPriority-high"])
        XCTAssertEqual(entry.value as? String, "None")
    }
}


extension ReadOnlyNavigationTests {
    @MainActor func testDetailPriorityLockedTrashAndRestore() {
        let app = launch(qaCase: "lifecycle")
        app.buttons["Review the project outline"].tap()
        chooseLifecycleAction("Move to Trash", in: app)
        expectLifecycleNotice("Moved to Trash", in: app)
        let entry = app.buttons["editTaskPriority"]
        reveal(entry, in: app)
        XCTAssertFalse(entry.isEnabled)
        XCTAssertFalse(app.buttons["taskPriority-high"].exists)
        app.buttons["undoLifecycle"].tap()
        expectLifecycleNotice("Change undone", in: app)
        openTaskMetadata("editTaskPriority", in: app)
        app.buttons["taskPriority-high"].tap()
        waitGone(app.buttons["taskPriority-high"])
        XCTAssertEqual(entry.value as? String, "High")
    }

    @MainActor func testParentTagPickerExcludesCyclesAndCancelPreservesParent() {
        let app = launch(qaCase: "tag-organization")
        openTagManager(in: app)
        let rootID = "00000000-0000-0000-0000-000000000200"
        let childID = "00000000-0000-0000-0000-000000000201"
        app.buttons["manageTag-" + rootID].tap()
        app.buttons["tagParent"].tap()
        let none = app.buttons["tagParentChoice-root"]
        XCTAssertTrue(none.waitForExistence(timeout: 5))
        XCTAssertEqual(none.value as? String, "Selected")
        XCTAssertFalse(app.buttons["tagParentChoice-" + rootID].exists)
        XCTAssertFalse(app.buttons["tagParentChoice-" + childID].exists)
        attach(app, "Parent Tag None and cycle-safe radio choices")
        let back = app.navigationBars["Parent Tag"].buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["tagCancel"].waitForExistence(timeout: 5))
        app.buttons["tagCancel"].tap()
        app.buttons["manageTag-" + childID].tap()
        app.buttons["tagParent"].tap()
        XCTAssertEqual(app.buttons["tagParentChoice-" + rootID].value as? String, "Selected")
        none.tap()
        app.buttons["tagCancel"].tap()
        app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        app.buttons["manageTag-" + childID].tap()
        app.buttons["tagParent"].tap()
        XCTAssertEqual(app.buttons["tagParentChoice-" + rootID].value as? String, "Selected")
    }
}


extension ReadOnlyNavigationTests {
    @MainActor func testCustomReminderStagesCancelsAndPersistsExactDate() {
        let app = launch(), task = "Review the project outline"
        let original = openSchedule(app, task: task)
        app.buttons["scheduleDay-7"].tap()
        openScheduleOptions("scheduleReminderOptions", in: app)
        reveal(app.buttons["scheduleCustomReminder"], in: app); app.buttons["scheduleCustomReminder"].tap()
        let preview = app.staticTexts["customReminderPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        func selectCustomTime() {
            app.buttons["Week"].tap()
            app.buttons["Day"].tap()
            let wheels = app.pickerWheels
            XCTAssertEqual(wheels.count, 3)
            wheels.element(boundBy: 0).adjust(toPickerWheelValue: "1")
            wheels.element(boundBy: 1).adjust(toPickerWheelValue: "10")
            wheels.element(boundBy: 2).adjust(toPickerWheelValue: "35")
        }
        selectCustomTime()
        let expected = preview.label
        XCTAssertTrue(expected.contains("10:35"))
        XCTAssertTrue(app.buttons["customReminderAdd"].isEnabled)
        attach(app, "Custom Reminder Day and time wheels")
        app.buttons["customReminderCancel"].tap()
        waitGone(app.buttons["customReminderAdd"])
        reveal(app.buttons["scheduleCustomReminder"], in: app); app.buttons["scheduleCustomReminder"].tap()
        selectCustomTime()
        app.buttons["customReminderAdd"].tap()
        waitGone(app.buttons["customReminderAdd"])
        let reminder = app.datePickers["scheduleManualReminder-0"]
        XCTAssertEqual(reminder.value as? String, expected)
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        app.buttons["editSchedule"].tap()
        app.buttons["scheduleDay-7"].tap()
        openScheduleOptions("scheduleReminderOptions", in: app)
        reveal(app.buttons["scheduleCustomReminder"], in: app); app.buttons["scheduleCustomReminder"].tap(); selectCustomTime(); app.buttons["customReminderAdd"].tap()
        waitGone(app.buttons["customReminderAdd"])
        scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app); _ = openSchedule(app, task: task)
        openScheduleOptions("scheduleReminderOptions", in: app)
        XCTAssertEqual(reminder.value as? String, expected)
    }
    @MainActor func testCustomReminderExpiredCannotAdd() {
        let app = launch()
        _ = openSchedule(app, task: "Review the project outline")
        openScheduleOptions("scheduleReminderOptions", in: app)
        reveal(app.buttons["scheduleCustomReminder"], in: app); app.buttons["scheduleCustomReminder"].tap()
        XCTAssertTrue(app.staticTexts["customReminderExpired"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["customReminderAdd"].isEnabled)
        app.buttons["customReminderCancel"].tap()
        waitGone(app.buttons["customReminderAdd"])
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testCustomRepeatFrequencyWheelsAndWeekdayChipsPersistAndCancel() {
        let app = launch(), title = "Review the project outline"
        _ = openSchedule(app, task: title)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        func openCustom() {
            reveal(app.buttons["scheduleCustom"], in: app)
            app.buttons["scheduleCustom"].tap()
            XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        }
        openCustom()
        let wheels = app.pickerWheels
        XCTAssertEqual(wheels.count, 2)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "3")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "Weeks")
        XCTAssertEqual(wheels.element(boundBy: 0).value as? String, "3")
        XCTAssertEqual(wheels.element(boundBy: 1).value as? String, "Weeks")
        for day in 1...7 {
            let chip = app.buttons["customRepeatWeekday-\(day)"]
            XCTAssertTrue(chip.exists)
            if chip.value as? String == "Selected" { chip.tap() }
        }
        XCTAssertFalse(app.buttons["customRepeatDone"].isEnabled)
        app.buttons["customRepeatWeekday-2"].tap()
        app.buttons["customRepeatWeekday-4"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].isEnabled)
        let expected = app.staticTexts["customRepeatSummary"].label
        attach(app, "Custom Repeat Frequency wheels and weekday chips")
        app.buttons["customRepeatDone"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app); _ = openSchedule(app, task: title)
        openScheduleOptions("scheduleRepeatOptions", in: app); openCustom()
        XCTAssertEqual(app.staticTexts["customRepeatSummary"].label, expected)
        XCTAssertEqual(wheels.element(boundBy: 0).value as? String, "3")
        XCTAssertEqual(wheels.element(boundBy: 1).value as? String, "Weeks")
        XCTAssertEqual(app.buttons["customRepeatWeekday-2"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["customRepeatWeekday-4"].value as? String, "Selected")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "4")
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        openCustom(); XCTAssertEqual(app.staticTexts["customRepeatSummary"].label, expected)
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
    }

    @MainActor func testCustomRepeatFrequencyRetainsMonthlyPatternEditor() {
        let app = launch(), title = "Review the project outline"
        _ = openSchedule(app, task: title)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "2")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "Months")
        XCTAssertEqual(app.pickerWheels.element(boundBy: 0).value as? String, "2")
        XCTAssertEqual(app.pickerWheels.element(boundBy: 1).value as? String, "Months")
        let days = app.textFields["Days, e.g. 1, 15, 31"]
        reveal(days, in: app); XCTAssertTrue(days.exists)
        days.tap(); days.typeText("1, 15")
        app.buttons["customRepeatDone"].tap(); waitGone(app.buttons["customRepeatDone"])
        let summary = app.staticTexts["scheduleCustomRule"]
        reveal(summary, in: app); let expected = summary.label
        scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap(); openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        reveal(days, in: app); XCTAssertEqual(days.value as? String, "1, 15")
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        reveal(summary, in: app); XCTAssertEqual(summary.label, expected)
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
    }
    @MainActor func testCustomRepeatExactIntervalPreservesFullModelRange() {
        let app = launch(); _ = openSchedule(app, task: "Review the project outline")
        openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        app.buttons["Exact interval"].tap()
        let field = app.textFields["customRepeatExactInterval"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10))
        XCTAssertFalse(app.buttons["customRepeatDone"].isEnabled)
        field.typeText("0"); XCTAssertFalse(app.buttons["customRepeatDone"].isEnabled)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "10001")
        XCTAssertFalse(app.buttons["customRepeatDone"].isEnabled)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "10000")
        XCTAssertTrue(app.buttons["customRepeatDone"].isEnabled)
        app.buttons["customRepeatDone"].tap(); waitGone(app.buttons["customRepeatDone"])
        app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.pickerWheels.element(boundBy: 0).value as? String, "10000")
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
    }

}

extension ReadOnlyNavigationTests {
    @MainActor func testNormalFilterConditionsPreviewPersistsAndCancelPreservesCriteria() {
        let app = launch(), filterName = "Focused planning"
        openFilterManagement(in: app); app.buttons["newSavedFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText(filterName + "\n")
        let ordered = ["List", "Tag", "Date", "Priority"].map { app.buttons["normalFilterCriterion-" + $0] }
        for row in ordered { XCTAssertTrue(row.exists) }
        for index in 0..<3 { XCTAssertLessThan(ordered[index].frame.minY, ordered[index + 1].frame.minY) }
        func optionButton(_ criterion: String, _ label: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "normalFilterOption-" + criterion + "-", label)).firstMatch
        }
        func choose(_ criterion: String, _ option: String) {
            let row = app.buttons["normalFilterCriterion-" + criterion]
            reveal(row, in: app); row.tap()
            XCTAssertTrue(app.navigationBars[criterion].waitForExistence(timeout: 5))
            optionButton(criterion, option).tap()
            app.navigationBars[criterion].buttons.firstMatch.tap()
        }
        choose("List", "Work"); choose("Tag", "Planning")
        app.buttons["normalFilterCriterion-Date"].tap()
        app.buttons["dateRule-today"].tap(); app.navigationBars["Date"].buttons.firstMatch.tap()
        choose("Priority", "None"); choose("Type", "Tasks")
        let keyword = app.textFields["savedFilterKeyword"]
        reveal(keyword, in: app); keyword.tap(); keyword.typeText("weekly")
        app.swipeDown()
        let preview = app.buttons["savedFilterPreview"]
        reveal(preview, in: app); preview.tap()
        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "savedFilterPreviewTask-")).count, 1)
        XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertFalse(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000001"].exists)
        XCTAssertFalse(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000006"].exists)
        app.navigationBars["Preview"].buttons.firstMatch.tap()
        reveal(name, in: app, towardTop: true); attach(app, "Normal Filter conditions and real Preview")
        app.buttons["savedFilterDone"].tap(); waitGone(app.buttons["savedFilterDone"])
        app.terminate(); app.launch(); XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openFilterManagement(in: app); managedFilter(filterName, in: app).tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        reveal(keyword, in: app); XCTAssertEqual(keyword.value as? String, "weekly")
        for (criterion, option) in [("List", "Work"), ("Priority", "None"), ("Type", "Tasks")] {
            let row = app.buttons["normalFilterCriterion-" + criterion]
            reveal(row, in: app); row.tap()
            XCTAssertTrue(optionButton(criterion, option).isSelected)
            app.navigationBars[criterion].buttons.firstMatch.tap()
        }
        let date = app.buttons["normalFilterCriterion-Date"]
        reveal(date, in: app); date.tap(); XCTAssertTrue(app.buttons["dateRule-today"].isSelected)
        app.navigationBars["Date"].buttons.firstMatch.tap()
        let tag = app.buttons["normalFilterCriterion-Tag"]
        reveal(tag, in: app, towardTop: true); tag.tap()
        XCTAssertTrue(optionButton("Tag", "Planning").isSelected)
        app.buttons["savedFilterAll-Tag"].tap()
        XCTAssertTrue(app.buttons["savedFilterAll-Tag"].isSelected)
        XCTAssertFalse(optionButton("Tag", "Planning").isSelected)
        app.navigationBars["Tag"].buttons.firstMatch.tap()
        app.buttons["savedFilterCancel"].tap(); app.alerts["Discard changes?"].buttons["Discard Changes"].tap()
        waitGone(app.buttons["savedFilterDone"])
        managedFilter(filterName, in: app).tap(); XCTAssertTrue(name.waitForExistence(timeout: 5))
        reveal(tag, in: app); tag.tap(); XCTAssertTrue(optionButton("Tag", "Planning").isSelected)
        app.navigationBars["Tag"].buttons.firstMatch.tap()
        reveal(preview, in: app); preview.tap()
        XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000002"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000006"].exists)
        app.navigationBars["Preview"].buttons.firstMatch.tap()
        app.buttons["savedFilterCancel"].tap(); waitGone(app.buttons["savedFilterDone"])
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testNormalFilterTagAllResetsMoreModesAndPreviewPredicate() {
        let app = launch(); openFilterManagement(in: app); app.buttons["newSavedFilter"].tap()
        XCTAssertTrue(app.textFields["savedFilterName"].waitForExistence(timeout: 5))
        let more = app.buttons["savedFilterMore"]
        reveal(more, in: app); more.tap()
        let matching = app.buttons.containing(.staticText, identifier: "Tag matching").firstMatch
        for mode in ["No tags", "Any tag"] {
            reveal(matching, in: app); matching.tap()
            XCTAssertTrue(app.navigationBars["Tag matching"].waitForExistence(timeout: 5))
            app.buttons[mode].tap()
            if app.navigationBars["Tag matching"].exists { app.navigationBars["Tag matching"].buttons.firstMatch.tap() }
            XCTAssertTrue(app.navigationBars["New Filter"].waitForExistence(timeout: 5))
            let tag = app.buttons["normalFilterCriterion-Tag"]
            reveal(tag, in: app, towardTop: true); XCTAssertTrue(tag.label.contains(mode))
            let preview = app.buttons["savedFilterPreview"]
            reveal(preview, in: app); preview.tap()
            XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000002"].exists, mode == "Any tag")
            XCTAssertEqual(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000001"].exists, mode == "No tags")
            app.navigationBars["Preview"].buttons.firstMatch.tap()
            reveal(tag, in: app, towardTop: true); tag.tap()
            let all = app.buttons["savedFilterAll-Tag"]
            XCTAssertFalse(all.isSelected); all.tap(); XCTAssertTrue(all.isSelected)
            app.navigationBars["Tag"].buttons.firstMatch.tap()
            reveal(preview, in: app); preview.tap()
            XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000002"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["savedFilterPreviewTask-00000000-0000-0000-0000-000000000001"].exists)
            app.navigationBars["Preview"].buttons.firstMatch.tap()
        }
        app.buttons["savedFilterCancel"].tap(); waitGone(app.buttons["savedFilterDone"])
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testAdvancedEmptyPreviewAndExamplesPreserveSavedRule() {
        let app = launch(); openFilterManagement(in: app); app.buttons["newSavedFilter"].tap()
        let name = app.textFields["savedFilterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Empty logic\n")
        let mode = app.segmentedControls["savedFilterMode"]
        mode.buttons["Advanced"].tap()
        let preview = app.buttons["savedFilterPreview"]
        reveal(preview, in: app); XCTAssertFalse(preview.isEnabled)
        XCTAssertTrue(app.staticTexts["Add a filter condition to preview."].exists)
        XCTAssertTrue(app.buttons["savedFilterDone"].isEnabled)
        let examples = app.buttons["savedFilterExamples"]
        reveal(examples, in: app); examples.tap()
        XCTAssertTrue(app.staticTexts["Taskovsky examples"].waitForExistence(timeout: 5))
        app.navigationBars["Examples"].buttons.firstMatch.tap()
        XCTAssertFalse(preview.isEnabled)
        app.buttons["savedFilterDone"].tap(); waitGone(app.buttons["savedFilterDone"])
        app.terminate(); app.launch(); XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openFilterManagement(in: app); managedFilter("Empty logic", in: app).tap()
        XCTAssertTrue(mode.buttons["Advanced"].waitForExistence(timeout: 5)); XCTAssertTrue(mode.buttons["Advanced"].isSelected)
        reveal(preview, in: app); XCTAssertFalse(preview.isEnabled)
        reveal(examples, in: app); examples.tap()
        XCTAssertTrue(app.staticTexts["Taskovsky examples"].waitForExistence(timeout: 5))
        app.navigationBars["Examples"].buttons.firstMatch.tap()
        app.buttons["savedFilterCancel"].tap(); waitGone(app.buttons["savedFilterDone"])
        XCTAssertFalse(app.alerts["Discard changes?"].exists)
        app.buttons["filterManagerDone"].tap()
        let destination = app.buttons["Empty logic"]
        reveal(destination, in: app); destination.tap(); waitGone(destination)
        XCTAssertTrue(app.buttons["Prepare the weekly plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Review the project outline"].exists)
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testAddTagPaletteParentSaveReloadAndCancel() {
        let app = launch(); openTagManager(in: app); app.buttons["newTag"].tap()
        let name = app.textFields["tagName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Add Tag"].exists)
        XCTAssertFalse(app.buttons["tagDone"].isEnabled)
        XCTAssertTrue(app.buttons["tagParent"].label.contains("None"))
        name.tap(); name.typeText("Palette child\n")
        let colors = ["#526BF5", "#EC6574", "#E7A548", "#58A58B", "#9C7BD5", "#5BA7CC", "#8A8F98"]
        for color in colors {
            let swatch = app.buttons["tagColor-" + color]
            reveal(swatch, in: app); swatch.tap(); XCTAssertTrue(swatch.isSelected)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND selected == true", "tagColor-")).count, 1)
        }
        app.buttons["tagColor-#EC6574"].tap()
        app.buttons["tagParent"].tap()
        tagChoice("Planning", id: "tagParentChoice-00000000-0000-0000-0000-000000000200", in: app).tap()
        XCTAssertTrue(app.buttons["tagParent"].label.contains("Planning"))
        attach(app, "Add Tag palette and parent")
        app.buttons["tagDone"].tap(); waitGone(name)
        app.terminate(); app.launch(); XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openTagManager(in: app)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "manageTag-", "Palette child")).firstMatch
        reveal(row, in: app); row.tap(); XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tagColor-#EC6574"].isSelected)
        XCTAssertTrue(app.buttons["tagParent"].label.contains("Planning"))
        app.buttons["tagColor-#526BF5"].tap()
        app.buttons["tagParent"].tap(); tagChoice("None", id: "tagParentChoice-root", in: app).tap()
        app.buttons["tagCancel"].tap(); app.alerts["Discard changes?"].buttons["Discard Changes"].tap(); waitGone(name)
        row.tap(); XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tagColor-#EC6574"].isSelected)
        XCTAssertTrue(app.buttons["tagParent"].label.contains("Planning"))
        app.buttons["tagCancel"].tap(); waitGone(name)
    }

    @MainActor func testTagCustomColorIsPreservedOnOpenAndUnrelatedSave() {
        let app = launch(); openTagManager(in: app)
        let planning = app.buttons["manageTag-00000000-0000-0000-0000-000000000200"]
        planning.tap()
        let name = app.textFields["tagName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let custom = app.descendants(matching: .any).matching(identifier: "tagCustomColor").firstMatch
        XCTAssertTrue(custom.exists)
        let original = custom.value as? String
        XCTAssertEqual(original, "#E6A53A")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND selected == true", "tagColor-")).count, 0)
        app.buttons["tagCancel"].tap(); waitGone(name); XCTAssertFalse(app.alerts["Discard changes?"].exists)
        planning.tap(); XCTAssertTrue(name.waitForExistence(timeout: 5))
        setSwitch("tagPin", to: true, app: app)
        app.buttons["tagDone"].tap(); waitGone(name)
        app.terminate(); app.launch(); XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        openTagManager(in: app); planning.tap(); XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(custom.value as? String, original)
        XCTAssertEqual(app.switches["tagPin"].value as? String, "1")
        app.buttons["tagCancel"].tap(); waitGone(name)
    }

    @MainActor func testRepeatTypeCompletionPersistsAndMenuDismissalDoesNotChange() {
        let app = launch(), title = "Review the project outline"
        _ = openSchedule(app, task: title); openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        let type = app.buttons["customRepeatType"]
        XCTAssertEqual(type.value as? String, "By Due Dates")
        type.tap()
        XCTAssertTrue(app.buttons["customRepeatType-due"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["customRepeatType-completion"].exists)
        XCTAssertTrue(app.buttons["customRepeatType-dates"].exists)
        let choices = [app.buttons["customRepeatType-due"], app.buttons["customRepeatType-completion"], app.buttons["customRepeatType-dates"]]
        XCTAssertEqual(choices.map(\.label), ["By Due Dates", "By Completion Date", "By Specific Dates"])
        XCTAssertTrue(choices[0].isSelected)
        XCTAssertLessThan(choices[0].frame.minY, choices[1].frame.minY)
        XCTAssertLessThan(choices[1].frame.minY, choices[2].frame.minY)
        attach(app, "Repeat Type observed three choices")
        app.navigationBars["Custom Repeat"].tap()
        waitGone(app.buttons["customRepeatType-due"])
        XCTAssertEqual(type.value as? String, "By Due Dates")
        type.tap(); app.buttons["customRepeatType-completion"].tap()
        XCTAssertEqual(type.value as? String, "By Completion Date")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "2")
        app.buttons["customRepeatDone"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app); _ = openSchedule(app, task: title)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(type.value as? String, "By Completion Date")
        XCTAssertEqual(app.pickerWheels.element(boundBy: 0).value as? String, "2")
        type.tap(); app.buttons["customRepeatType-due"].tap()
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(type.value as? String, "By Completion Date")
        type.tap(); app.buttons["customRepeatType-due"].tap()
        app.buttons["customRepeatDone"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleCancel"].tap(); waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap(); openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(type.value as? String, "By Completion Date")
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
    }

    @MainActor func testRepeatTypeSpecificDatesPreservesBothDraftsAndPersistsDates() {
        let app = launch(), title = "Review the project outline"
        _ = openSchedule(app, task: title); openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "3")
        let type = app.buttons["customRepeatType"]
        type.tap(); app.buttons["customRepeatType-dates"].tap()
        XCTAssertFalse(app.buttons["customRepeatDone"].isEnabled)
        app.buttons["Add date"].tap(); app.buttons["Add date"].tap()
        let first = app.datePickers["customRepeatDate-0"], second = app.datePickers["customRepeatDate-1"]
        XCTAssertTrue(first.exists); XCTAssertTrue(second.exists)
        let firstValue = first.value as? String, secondValue = second.value as? String
        XCTAssertNotNil(firstValue); XCTAssertNotNil(secondValue)
        XCTAssertFalse(firstValue?.isEmpty ?? true); XCTAssertFalse(secondValue?.isEmpty ?? true)
        XCTAssertNotEqual(firstValue, secondValue)
        type.tap(); app.buttons["customRepeatType-due"].tap()
        XCTAssertEqual(app.pickerWheels.element(boundBy: 0).value as? String, "3")
        type.tap(); app.buttons["customRepeatType-dates"].tap()
        XCTAssertEqual(first.value as? String, firstValue); XCTAssertEqual(second.value as? String, secondValue)
        app.buttons["customRepeatDone"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app); _ = openSchedule(app, task: title)
        openScheduleOptions("scheduleRepeatOptions", in: app)
        reveal(app.buttons["scheduleCustom"], in: app); app.buttons["scheduleCustom"].tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(type.value as? String, "By Specific Dates")
        XCTAssertEqual(first.value as? String, firstValue); XCTAssertEqual(second.value as? String, secondValue)
        app.buttons["customRepeatCancel"].tap(); waitGone(app.buttons["customRepeatDone"])
        scheduleRoot(app); app.buttons["scheduleCancel"].tap()
    }
}


extension ReadOnlyNavigationTests {
    @MainActor private func toggleTaskDisplay(_ id: String, in app: XCUIApplication) {
        app.buttons["taskListActions"].tap()
        let control = app.buttons[id]
        XCTAssertTrue(control.waitForExistence(timeout: 5)); control.tap()
        waitGone(control)
    }
    @MainActor func testTaskDisplayCompletedInboxCollapseAndBatchScope() {
        let app = launch(qaCase: "task-display")
        goTo("Inbox", in: app)
        let completed = app.buttons["Book time for a walk"]
        let disclosure = app.buttons["taskCompletedDisclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        XCTAssertEqual(disclosure.value as? String, "Expanded")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", completed.label)).count, 1)
        disclosure.tap(); XCTAssertFalse(completed.exists)
        app.buttons["taskListActions"].tap(); app.buttons["batchOpen"].tap()
        XCTAssertTrue(app.navigationBars["Select Tasks"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["batchTask-00000000-0000-0000-0000-000000000007"].exists)
        XCTAssertTrue(app.buttons["batchTask-00000000-0000-0000-0000-000000000001"].exists)
        app.buttons["batchBack"].tap()
        disclosure.tap(); XCTAssertTrue(completed.waitForExistence(timeout: 5))
        app.buttons["taskListActions"].tap(); app.buttons["batchOpen"].tap()
        XCTAssertTrue(app.buttons["batchTask-00000000-0000-0000-0000-000000000007"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["batchTask-00000000-0000-0000-0000-000000000001"].exists)
        app.buttons["batchBack"].tap()
        toggleTaskDisplay("taskDisplayCompleted", in: app)
        XCTAssertFalse(completed.exists); XCTAssertFalse(disclosure.exists)
        XCTAssertTrue(app.buttons["Review the project outline"].exists)
        app.buttons["taskListActions"].tap(); app.buttons["batchOpen"].tap()
        XCTAssertTrue(app.buttons["batchTask-00000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["batchTask-00000000-0000-0000-0000-000000000007"].exists)
        app.buttons["batchBack"].tap()
        toggleTaskDisplay("taskDisplayCompleted", in: app)
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        attach(app, "Tasks Completed section")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Completed", in: app)
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        app.buttons["taskListActions"].tap()
        XCTAssertFalse(app.buttons["taskDisplayCompleted"].exists)
    }
    @MainActor func testTaskDisplaySectionListDetailsAndHistory() {
        let app = launch(qaCase: "task-display")
        goTo("Work", in: app)
        let completed = app.buttons["Arrange the studio"]
        XCTAssertTrue(app.buttons["taskCompletedDisclosure"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", completed.label)).count, 1)
        toggleTaskDisplay("taskDisplayCompleted", in: app)
        XCTAssertFalse(completed.exists)
        XCTAssertTrue(app.buttons["Write meeting notes"].exists)
        toggleTaskDisplay("taskDisplayDetails", in: app)
        XCTAssertTrue((app.buttons["Prepare the weekly plan"].value as? String ?? "").contains("A neutral sample description."))
        attach(app, "Tasks expanded details")
        toggleTaskDisplay("taskDisplayDetails", in: app)
        XCTAssertFalse((app.buttons["Prepare the weekly plan"].value as? String ?? "").contains("A neutral sample description."))
        toggleTaskDisplay("taskDisplayCompleted", in: app)
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
    }
    @MainActor func testTaskDisplayKanbanDetailsPreservesOpeningAndMode() {
        let app = launch(qaCase: "timeline")
        goTo("Open Launch projects", in: app)
        selectScopedView("Kanban View", in: app)
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let compact = card.frame.height
        toggleTaskDisplay("taskDisplayDetails", in: app)
        XCTAssertGreaterThan(card.frame.height, compact)
        app.buttons["taskListActions"].tap()
        XCTAssertFalse(app.buttons["taskDisplayCompleted"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.55)).tap()
        waitGone(app.buttons["taskDisplayDetails"])
        XCTAssertTrue((card.value as? String ?? "").contains("#Planning"))
        attach(app, "Kanban expanded details")
        card.tap(); XCTAssertTrue(app.buttons["taskDetailDone"].waitForExistence(timeout: 5))
        app.buttons["taskDetailDone"].tap()
        toggleTaskDisplay("taskDisplayDetails", in: app)
        XCTAssertEqual(card.frame.height, compact, accuracy: 1)
    }
}


extension ReadOnlyNavigationTests {
    @MainActor func testDurationCardsNoOpPreservesSecondsZoneAcrossSave() {
        let app = launch(qaCase: "duration-precision")
        let evidence = app.staticTexts["previewNotice"].value as? String
        XCTAssertTrue(evidence?.contains("Pacific/Kiritimati") == true)
        _ = openSchedule(app, task: "Review the project outline")
        app.buttons["scheduleDurationTime"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.segmentedControls["durationEndpoint"].buttons["End"].tap()
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        app.buttons["scheduleDurationDate"].tap()
        XCTAssertTrue(app.datePickers["scheduleMoveDurationDate"].waitForExistence(timeout: 5))
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        attach(app, "Duration cards in non-device zone")
        app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["previewNotice"].value as? String, evidence)
    }
    @MainActor func testDurationCardsEndpointEditsNestedCancelSaveAndRelaunch() {
        let app = launch()
        _ = openSchedule(app, task: "Prepare the weekly plan")
        let time = app.buttons["scheduleDurationTime"]
        let before = time.value as? String
        time.tap(); XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "15")
        app.buttons["durationPopupCancel"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertEqual(time.value as? String, before)
        time.tap(); XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "15")
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertTrue((time.value as? String ?? "").contains("13:15"))
        XCTAssertTrue((time.value as? String ?? "").contains("14:00"))
        time.tap(); app.segmentedControls["durationEndpoint"].buttons["End"].tap()
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "30")
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertTrue((time.value as? String ?? "").contains("14:30"))
        let changed = time.value as? String
        attach(app, "Duration cards with edited endpoints")
        app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.buttons["taskDetailDone"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        _ = openSchedule(app, task: "Prepare the weekly plan")
        XCTAssertEqual(time.value as? String, changed)
        app.buttons["scheduleCancel"].tap()
    }
    @MainActor func testDurationAllDayEndpointTabsAndNestedCancel() {
        let app = launch()
        _ = openSchedule(app, task: "Prepare the weekly plan")
        let original = app.buttons["scheduleDurationTime"].value as? String
        let allDay = app.switches["scheduleAllDay"]
        allDay.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(allDay.value as? String, "1")
        let end = app.buttons["scheduleRangeEnd"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        let before = end.value as? String
        end.tap()
        XCTAssertTrue(app.segmentedControls["durationEndpoint"].buttons["End"].isSelected)
        app.buttons["Tuesday, November 10"].tap()
        app.buttons["durationPopupCancel"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertEqual(end.value as? String, before)
        end.tap(); app.buttons["Tuesday, November 10"].tap()
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertEqual(end.value as? String, "Nov 10, 2026, End date")
        XCTAssertEqual(app.buttons["scheduleRangeStart"].value as? String, "Nov 9, 2026, Start date")
        app.buttons["scheduleDurationMove"].tap()
        XCTAssertTrue(app.datePickers["scheduleMoveDurationDate"].waitForExistence(timeout: 5))
        app.buttons["Thursday, November 12"].tap()
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertEqual(app.buttons["scheduleRangeStart"].value as? String, "Nov 11, 2026, Start date")
        XCTAssertEqual(end.value as? String, "Nov 12, 2026, End date")
        attach(app, "All Day duration endpoint cards")
        app.buttons["scheduleCancel"].tap(); waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap()
        XCTAssertTrue(app.buttons["scheduleDurationTime"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["scheduleDurationTime"].value as? String, original)
        app.buttons["scheduleCancel"].tap()
    }
}


extension ReadOnlyNavigationTests {
    @MainActor func testDurationEndpointInvalidRangeCorrectionAndOuterCancel() {
        let app = launch()
        _ = openSchedule(app, task: "Prepare the weekly plan")
        let time = app.buttons["scheduleDurationTime"]
        let before = time.value as? String
        time.tap(); XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
        XCTAssertFalse(app.buttons["durationPopupDone"].isEnabled)
        app.segmentedControls["durationEndpoint"].buttons["End"].tap()
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "16")
        XCTAssertTrue(app.buttons["durationPopupDone"].isEnabled)
        app.buttons["durationPopupDone"].tap(); waitGone(app.buttons["durationPopupDone"])
        XCTAssertTrue((time.value as? String ?? "").contains("15:00"))
        XCTAssertTrue((time.value as? String ?? "").contains("16:00"))
        app.buttons["scheduleCancel"].tap(); waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap()
        XCTAssertTrue(time.waitForExistence(timeout: 5)); XCTAssertEqual(time.value as? String, before)
        time.tap(); XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "15")
        let popup = app.buttons["durationPopupDone"]
        let outside = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.95))
        XCTAssertTrue(popup.exists)
        outside.tap()
        waitGone(app.buttons["durationPopupDone"])
        XCTAssertEqual(time.value as? String, before)
        app.buttons["scheduleCancel"].tap()
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testScopedKanbanTagAndTitleDirectionPreserveLane() {
        let app = launch()
        selectScopedView("Kanban View", in: app)
        selectScopedGrouping("Tag", in: app)
        let planning = app.buttons["scopedBoardColumn-0"]
        let noTags = app.buttons["scopedBoardColumn-1"]
        XCTAssertTrue(planning.waitForExistence(timeout: 5))
        XCTAssertEqual(planning.label, "Planning")
        XCTAssertEqual(planning.value as? String, "1")
        XCTAssertEqual(noTags.label, "No Tags")
        XCTAssertEqual(noTags.value as? String, "6")
        noTags.tap()
        selectScopedGrouping("Title · Ascending", in: app)
        XCTAssertTrue(noTags.isSelected)
        let arrange = app.buttons["boardCard-00000000-0000-0000-0000-000000000004"]
        let book = app.buttons["boardCard-00000000-0000-0000-0000-000000000007"]
        XCTAssertTrue(arrange.waitForExistence(timeout: 5)); XCTAssertTrue(book.exists)
        XCTAssertLessThan(arrange.frame.minY, book.frame.minY)
        let outline = app.buttons["boardCard-00000000-0000-0000-0000-000000000001"]
        let draft = app.buttons["boardCard-00000000-0000-0000-0000-000000000008"]
        XCTAssertTrue(outline.exists); XCTAssertTrue(draft.exists)
        XCTAssertLessThan(draft.frame.minY, outline.frame.minY)
        selectScopedGrouping("Title · Descending", in: app)
        XCTAssertTrue(noTags.isSelected)
        XCTAssertTrue(outline.waitForExistence(timeout: 5)); XCTAssertTrue(draft.exists)
        XCTAssertLessThan(outline.frame.minY, draft.frame.minY)
        XCTAssertFalse(app.buttons["Move Review the project outline"].exists)
        XCTAssertFalse(app.otherElements["Drag Review the project outline"].exists)
        attach(app, "Kanban Tag lanes with descending Title")
        selectScopedGrouping("Created Time", in: app)
        XCTAssertEqual(app.buttons["scopedBoardColumn-0"].value as? String, "7")
        XCTAssertFalse(app.buttons["scopedBoardColumn-1"].exists)
        XCTAssertTrue(outline.exists)
        attach(app, "Kanban Created Time lane")
        selectScopedGrouping("List", in: app)
        XCTAssertEqual(app.buttons["scopedBoardColumn-0"].label, "Inbox")
        selectScopedView("List View", in: app)
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 5))
    }

    @MainActor func testScopedKanbanTagLaneRemovalFallsBackToNoTags() {
        let app = launch()
        selectScopedView("Kanban View", in: app)
        selectScopedGrouping("Tag", in: app)
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        openTaskMetadata("editTaskTags", in: app)
        let tag = app.buttons["taskTag-00000000-0000-0000-0000-000000000200"]
        XCTAssertEqual(tag.value as? String, "Selected")
        tag.tap()
        app.buttons["taskMetadataDone"].tap()
        waitGone(app.buttons["taskMetadataCancel"])
        app.buttons["taskDetailDone"].tap()
        let lane = app.buttons["scopedBoardColumn-0"]
        XCTAssertTrue(lane.waitForExistence(timeout: 5))
        XCTAssertEqual(lane.label, "No Tags")
        XCTAssertEqual(lane.value as? String, "7")
        XCTAssertFalse(app.buttons["scopedBoardColumn-1"].exists)
        XCTAssertTrue(card.exists)
        selectScopedGrouping("Date", in: app)
        XCTAssertTrue(app.buttons["scopedBoardColumn-0"].exists)
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openKanbanSortSheet(_ app: XCUIApplication) {
        app.buttons["taskListActions"].tap()
        app.buttons["scopedBoardGrouping"].tap()
        XCTAssertTrue(app.buttons["boardGroup-list"].waitForExistence(timeout: 5))
    }
    @MainActor private func dismissKanbanSortSheet(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        waitGone(app.buttons["boardGroup-list"])
    }
    @MainActor private func assertKanbanOrder(_ ids: [Int], _ app: XCUIApplication) {
        let cards = ids.map { app.buttons[String(format: "boardCard-00000000-0000-0000-0000-%012d", $0)] }
        for card in cards { XCTAssertTrue(card.waitForExistence(timeout: 5)) }
        for index in 1..<cards.count { XCTAssertLessThan(cards[index-1].frame.minY, cards[index].frame.minY) }
    }
    @MainActor func testKanbanSheetEverySortIsRealAndStaysOpen() {
        let app = launch(qaCase: "kanban-sort")
        selectScopedView("Kanban View", in: app)
        openKanbanSortSheet(app)
        let groupKeys = ["list","date","createdTime","tag","priority"]
        let groupLabels = ["List","Date","Created Time","Tag","Priority"]
        for (key,label) in zip(groupKeys,groupLabels) {
            let button = app.buttons["boardGroup-"+key]
            XCTAssertEqual(button.label,label); XCTAssertGreaterThanOrEqual(button.frame.height,44)
        }
        for key in ["date","createdTime","modifiedTime","title","tag","priority"] {
            XCTAssertTrue(app.buttons["boardSort-"+key].exists)
            XCTAssertFalse(app.buttons["boardSort-"+key].isSelected)
        }
        XCTAssertFalse(app.buttons["Done"].exists)
        XCTAssertFalse(app.buttons["Existing Order"].exists)
        XCTAssertFalse(app.staticTexts["Group & Sort"].exists)
        let first = app.buttons["boardGroup-list"], second = app.buttons["boardGroup-date"], third = app.buttons["boardGroup-createdTime"]
        XCTAssertLessThan(first.frame.minX,second.frame.minX); XCTAssertLessThan(second.frame.minX,third.frame.minX)
        XCTAssertEqual(first.frame.minY,second.frame.minY,accuracy:1)
        XCTAssertGreaterThan(app.buttons["boardGroup-tag"].frame.minY,first.frame.minY)
        let direction = app.buttons["boardSortDirection"]
        XCTAssertGreaterThanOrEqual(direction.frame.height,44)
        XCTAssertLessThanOrEqual(direction.frame.maxY, app.buttons["boardSort-date"].frame.minY)
        direction.tap()
        XCTAssertEqual(direction.value as? String,"Descending")
        app.buttons["boardSort-title"].tap()
        XCTAssertTrue(app.buttons["boardSort-title"].isSelected)
        XCTAssertEqual(direction.value as? String,"Descending")
        for key in groupKeys {
            app.buttons["boardGroup-"+key].tap()
            XCTAssertTrue(app.buttons["boardGroup-"+key].isSelected)
            XCTAssertTrue(app.buttons["boardSort-title"].isSelected)
        }
        app.buttons["boardGroup-list"].tap()
        attach(app,"Kanban Group and Sort reference-structured sheet")
        dismissKanbanSortSheet(app)
        assertKanbanOrder([3,1,2],app)
        let choices: [(String,[Int])] = [("date",[1,2,3]),("createdTime",[3,1,2]),("modifiedTime",[2,3,1]),("priority",[3,1,2]),("title",[2,1,3])]
        for (key,expected) in choices {
            openKanbanSortSheet(app)
            if app.buttons["boardSortDirection"].value as? String != "Ascending" { app.buttons["boardSortDirection"].tap() }
            app.buttons["boardSort-"+key].tap()
            XCTAssertTrue(app.buttons["boardSort-"+key].isSelected)
            dismissKanbanSortSheet(app)
            assertKanbanOrder(expected,app)
        }
        selectScopedView("List View",in:app)
        XCTAssertTrue(app.buttons["Beta"].waitForExistence(timeout:5))
    }
    @MainActor func testKanbanTagSortHasRealCollapsibleSections() {
        let app = launch(qaCase:"kanban-sort")
        selectScopedView("Kanban View",in:app)
        openKanbanSortSheet(app)
        app.buttons["boardGroup-list"].tap(); app.buttons["boardSort-tag"].tap()
        XCTAssertTrue(app.buttons["boardSort-tag"].isSelected)
        dismissKanbanSortSheet(app)
        let sections = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","boardTagSection-"))
        let planning = sections.matching(NSPredicate(format:"label == %@","Planning")).firstMatch
        let untagged = sections.matching(NSPredicate(format:"label == %@","No Tags")).firstMatch
        XCTAssertTrue(planning.waitForExistence(timeout:5)); XCTAssertTrue(untagged.exists)
        XCTAssertEqual(planning.value as? String,"1, Expanded")
        XCTAssertEqual(untagged.value as? String,"2, Expanded")
        XCTAssertLessThan(planning.frame.minY,untagged.frame.minY)
        planning.tap()
        XCTAssertEqual(planning.value as? String,"1, Collapsed")
        XCTAssertFalse(app.buttons["boardCard-00000000-0000-0000-0000-000000000001"].exists)
        XCTAssertTrue(app.buttons["boardCard-00000000-0000-0000-0000-000000000002"].exists)
        openKanbanSortSheet(app); app.buttons["boardSortDirection"].tap(); dismissKanbanSortSheet(app)
        XCTAssertEqual(planning.value as? String,"1, Collapsed")
        planning.tap()
        XCTAssertTrue(app.buttons["boardCard-00000000-0000-0000-0000-000000000001"].exists)
        attach(app,"Kanban real Tag subsections")
    }
}

extension ReadOnlyNavigationTests {
    @MainActor func testReminderPresetsToggleIndependentlyAndPersistWithoutMovingDate() {
        let app = launch(), title = "Review the project outline"
        _ = openSchedule(app, task: title)
        app.buttons["scheduleDay-7"].tap()
        openScheduleOptions("scheduleReminderOptions", in: app)
        let ids = ["onDay9", "dayBefore9", "twoDaysBefore9", "threeDaysBefore9", "weekBefore9"]
        let labels = ["On the day", "1 day early", "2 days early", "3 days early", "1 week early"]
        func preset(_ id: String) -> XCUIElement { app.buttons["scheduleReminderPreset-" + id] }
        for (id, label) in zip(ids, labels) {
            let row = preset(id); reveal(row, in: app)
            XCTAssertEqual(row.label, label)
            row.tap()
            XCTAssertEqual(row.value as? String, "Selected")
            XCTAssertTrue(app.navigationBars["Reminder"].exists)
        }
        reveal(preset("none"), in: app)
        XCTAssertEqual(preset("none").value as? String, "Not selected")
        attach(app, "All-day Reminder presets selected")
        preset("dayBefore9").tap()
        XCTAssertEqual(preset("dayBefore9").value as? String, "Not selected")
        XCTAssertEqual(preset("onDay9").value as? String, "Selected")
        scheduleRoot(app)
        XCTAssertEqual(app.buttons["scheduleReminderOptions"].value as? String, "4 reminders")
        app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        let savedSchedule = app.buttons["editSchedule"].label
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app)
        XCTAssertEqual(openSchedule(app, task: title), savedSchedule)
        openScheduleOptions("scheduleReminderOptions", in: app)
        for id in ids {
            let row = preset(id); reveal(row, in: app)
            XCTAssertEqual(row.value as? String, id == "dayBefore9" ? "Not selected" : "Selected")
        }
        // Actual stored absolute reminders retain the selected civil dates at09:00.
        let expected = ["Nov 9, 2026 at 9:00", "Nov 13, 2026 at 9:00", "Nov 14, 2026 at 9:00", "Nov 16, 2026 at 9:00"]
        for (index, value) in expected.enumerated() {
            let row = app.datePickers["scheduleManualReminder-\(index)"]; reveal(row, in: app)
            XCTAssertEqual(row.value as? String, value)
        }
    }

    @MainActor func testReminderPresetNoneAndOuterCancelPreserveSavedReminders() {
        let app = launch(), title = "Review the project outline"
        let original = openSchedule(app, task: title)
        openScheduleOptions("scheduleReminderOptions", in: app)
        let onDay = app.buttons["scheduleReminderPreset-onDay9"], none = app.buttons["scheduleReminderPreset-none"]
        onDay.tap(); XCTAssertEqual(onDay.value as? String, "Selected")
        none.tap(); XCTAssertEqual(none.value as? String, "Selected")
        XCTAssertEqual(onDay.value as? String, "Not selected")
        onDay.tap()
        scheduleRoot(app); app.buttons["scheduleCancel"].tap(); waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        app.buttons["editSchedule"].tap(); openScheduleOptions("scheduleReminderOptions", in: app)
        XCTAssertEqual(none.value as? String, "Selected")
        XCTAssertEqual(onDay.value as? String, "Not selected")
        onDay.tap(); scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap(); openScheduleOptions("scheduleReminderOptions", in: app)
        XCTAssertEqual(onDay.value as? String, "Selected")
        none.tap(); scheduleRoot(app); app.buttons["scheduleDone"].tap(); waitGone(app.buttons["scheduleDone"])
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        goTo("Inbox", in: app); XCTAssertEqual(openSchedule(app, task: title), original)
        openScheduleOptions("scheduleReminderOptions", in: app)
        XCTAssertEqual(none.value as? String, "Selected")
        XCTAssertEqual(onDay.value as? String, "Not selected")
    }
}
