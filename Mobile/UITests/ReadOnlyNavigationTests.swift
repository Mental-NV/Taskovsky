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
    @MainActor func testCalendarFilterReset() {
        let app = launch()
        app.buttons["Calendar"].tap()
        let task = app.buttons["Review the project outline"]
        app.buttons["Calendar filters"].tap()
        let work = app.buttons["Work"]
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        work.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarPreferencesCancel"].tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))

        app.buttons["Calendar filters"].tap()
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        app.buttons["Show only Work"].tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertFalse(task.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertFalse(task.exists)
        app.buttons["Calendar filters"].tap()
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
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Recovery copy saved"), object: app.staticTexts["captureRecoveryStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 6), .completed)
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

    @MainActor private func chooseLifecycleAction(_ name: String, in app: XCUIApplication) {
        app.buttons["taskActions"].tap()
        let action = app.buttons[name]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
    }

    @MainActor private func expectLifecycleNotice(_ value: String, in app: XCUIApplication) {
        let notice = app.staticTexts["lifecycleFeedback"]
        let predicate = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", value), object: notice)
        XCTAssertEqual(XCTWaiter.wait(for: [predicate], timeout: 6), .completed)
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

    @MainActor func testScheduleNestedAndOuterCancelLeaveAnUntouchedTask() {
        let app = launch(), task = "Prepare the weekly plan"
        let original = openSchedule(app, task: task)
        let custom = app.buttons["scheduleCustom"]
        reveal(custom, in: app)
        custom.tap()
        XCTAssertTrue(app.buttons["customRepeatDone"].waitForExistence(timeout: 5))
        attach(app, "Nested custom repeat")
        app.buttons["customRepeatCancel"].tap()
        waitGone(app.buttons["customRepeatDone"])
        XCTAssertFalse(app.staticTexts["scheduleCustomRule"].exists)
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
        app.buttons["editSchedule"].tap()
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
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        app.buttons["editSchedule"].tap()
        reveal(rule, in: app)
        XCTAssertTrue(rule.exists)
        let remove = app.buttons["scheduleRemove"]
        reveal(remove, in: app, towardTop: true)
        remove.tap()
        XCTAssertTrue(app.buttons["scheduleAddDate"].waitForExistence(timeout: 5))
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
        let automatic = app.switches["scheduleAutomaticReminders"]
        reveal(automatic, in: app)
        XCTAssertEqual(automatic.value as? String, "1")
        automatic.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(automatic.value as? String, "0")
        let add = app.buttons["scheduleAddReminder"]
        reveal(add, in: app)
        add.tap()
        attach(app, "Timed range with a manual reminder")
        app.buttons["scheduleDone"].tap()
        waitGone(app.buttons["scheduleDone"])
        XCTAssertEqual(app.buttons["editSchedule"].label, original)
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

        let overdue = app.switches["arrangeOverdue"]
        XCTAssertEqual(overdue.value as? String, "0")
        overdue.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(overdueTask.waitForExistence(timeout: 5))
        app.buttons["arrangeList"].tap()
        app.buttons["Inbox"].tap()
        XCTAssertTrue(overdueTask.exists)
        XCTAssertFalse(chapter.exists)
        app.buttons["arrangeList"].tap()
        app.buttons["Personal"].tap()
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        XCTAssertFalse(overdueTask.exists)
        app.buttons["arrangeGroup"].tap()
        app.buttons["Priority"].tap()
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

    @MainActor func testCalendarMonthDragMovesAnAllDayTask() {
        let app = launch(), title = "Review the project outline"
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Month"].tap()
        let card = app.images["Drag " + title]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let destination = app.staticTexts["10"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.25)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        attach(app, "Month drag moved an all-day task")
    }

    @MainActor func testCalendarTimedResizeHandleMovesTheEnd() {
        let app = launch()
        app.buttons["Calendar"].tap()
        app.buttons["Calendar view"].tap()
        app.buttons["Day"].tap()
        let card = app.buttons["Prepare the weekly plan"]
        reveal(card, in: app)
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        let end = start.withOffset(CGVector(dx: 0, dy: 26))
        start.press(forDuration: 0.05, thenDragTo: end)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        attach(app, "Day timed range after resize")
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

    @MainActor private func setCalendarSwitch(_ id: String, to state: Bool, app: XCUIApplication) {
        let toggle = app.switches[id]
        reveal(toggle, in: app)
        let desired = state ? "1" : "0"
        if toggle.value as? String != desired {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, desired)
    }

    @MainActor func testCalendarViewOptionsRenderAndPersistAcrossRelaunch() {
        let app = launch(qaCase: "calendar-options")
        app.buttons["Calendar"].tap()
        let completed = app.buttons["Arrange the studio"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        openCalendarViewOptions(app)
        app.buttons["calendarColor"].tap()
        app.buttons["Priority"].tap()
        app.buttons["calendarStyle"].tap()
        app.buttons["Outline"].tap()
        app.buttons["calendarYearStyle"].tap()
        app.buttons["Standard"].tap()
        setCalendarSwitch("calendarIcons", to: false, app: app)
        setCalendarSwitch("calendarCompleted", to: false, app: app)
        setCalendarSwitch("calendarChecklist", to: true, app: app)
        setCalendarSwitch("calendarRepeats", to: false, app: app)
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
        setCalendarSwitch("calendarAdditionalZones", to: true, app: app)
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
        setCalendarSwitch("calendarCompleted", to: false, app: app)
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
    }
}

extension ReadOnlyNavigationTests {
    @MainActor private func openTaskMetadata(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        reveal(button, in: app)
        button.tap()
        XCTAssertTrue(app.buttons["taskMetadataCancel"].waitForExistence(timeout: 5))
    }

    @MainActor func testTaskPriorityAndTagsPersistWithoutChangingDescription() {
        let app = launch(qaCase: "task-metadata"), task = "Review the project outline"
        app.buttons[task].tap()
        openTaskMetadata("editTaskPriority", in: app)
        app.buttons["taskPriority-high"].tap()
        waitGone(app.buttons["taskMetadataCancel"])
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
        setCalendarSwitch("calendarChecklist", to: true, app: app)
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
        open.tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, " + child)
        reveal(app.buttons["openParentTask"], in: app)
        app.buttons["openParentTask"].tap()
        XCTAssertEqual(app.buttons["editTitle"].label, "Edit title, " + root)
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
        setCalendarSwitch("organizationArchive", to: true, app: app)
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
        setCalendarSwitch("organizationArchive", to: false, app: app)
        setCalendarSwitch("organizationSmartInclusion", to: false, app: app)
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

    @MainActor private func chooseListPlacement(_ name: String, in app: XCUIApplication) {
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
        setCalendarSwitch("savedFilterPin", to: true, app: app)
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
        XCTAssertTrue(app.staticTexts["Advanced Rules"].waitForExistence(timeout: 5))
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
        setCalendarSwitch("tagPin", to: true, app: app)
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
        tagChoice("Top level", id: "tagParentChoice-root", in: app).tap()
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

    @MainActor func testSummaryFiltersAndSavesEditedInboxNote() {
        let app = launch(qaCase: "summary")
        goTo("Summary", in: app)
        let report = app.textViews["summaryText"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertTrue((report.value as? String)?.contains("Prepare the weekly plan") == true)
        app.buttons["summaryFilter"].tap()
        app.buttons["summaryPeriod"].tap()
        app.buttons["Today"].tap()
        app.buttons["summaryGrouping"].tap()
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
        app.buttons["summaryGrouping"].tap()
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
