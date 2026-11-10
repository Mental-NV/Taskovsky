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
        XCTAssertTrue(app.staticTexts["Formatting is shown as plain text in this preview. The original content is preserved."].waitForExistence(timeout: 3))
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
        let app = launch(); app.buttons["Calendar"].tap()
        app.buttons["Calendar filters"].tap()
        let work = app.buttons["Work"]; XCTAssertTrue(work.waitForExistence(timeout: 3)); work.tap()
        XCTAssertEqual(work.value as? String, "Selected")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["Review the project outline"].exists)
        app.buttons["Calendar filters"].tap(); app.buttons["All"].tap(); app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Review the project outline"].waitForExistence(timeout: 3))
        attach(app, "Calendar Week after All reset")
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
        app.buttons["undoLifecycle"].tap()
        expectLifecycleNotice("Change undone", in: app)
        XCTAssertFalse(app.staticTexts["In Trash"].exists)
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
