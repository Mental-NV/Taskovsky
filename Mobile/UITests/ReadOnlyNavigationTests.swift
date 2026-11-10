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
        input.typeText("\n--")
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
        let start = grid.staticTexts["11"]
        let end = grid.staticTexts.matching(identifier: "6").firstMatch
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
        stage()
        let taskTitle = "Phone range capture tomorrow"
        title.tap()
        title.typeText(taskTitle)
        let recovery = app.staticTexts["captureRecoveryStatus"]
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Recovery copy saved"), object: recovery)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 6), .completed)
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
        let start = app.staticTexts["11"], end = app.staticTexts["17"]
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

    @MainActor func testTaskTimestampSortOrdersWorkRowsAndSurvivesRelaunch() {
        let app = launch(qaCase: "task-sort")
        goTo("Work", in: app)
        let menu = app.buttons["taskSortMenu"]
        let old = "Review the project outline", newest = "Prepare the weekly plan", middle = "Review the draft"
        func choose(_ sort: String) {
            menu.tap()
            let choice = app.buttons[sort]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            waitGone(choice)
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
            menu.tap()
            let choice = app.buttons[label]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            waitGone(choice)
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

    @MainActor func testDuplicateTaskOpensTheIndependentStyledCopy() {
        let app = launch(qaCase: "task-metadata")
        let root = app.buttons["Review the project outline"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        root.tap()
        app.buttons["taskActions"].tap()
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
        app.buttons["calendarHourBand-early"].tap()
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
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        XCTAssertEqual(early.label, "Show early hours")
        XCTAssertEqual(early.value as? String, "1 item")
        XCTAssertEqual(late.value as? String, "1 item")
        XCTAssertFalse(app.buttons["Read a chapter"].exists)
        XCTAssertFalse(app.buttons["Arrange the studio"].exists)
        early.tap()
        reveal(app.buttons["Read a chapter"], in: app)
        XCTAssertEqual(early.label, "Hide early hours")
        XCTAssertEqual(late.label, "Show late hours")
        late.tap()
        reveal(app.buttons["Arrange the studio"], in: app)
        XCTAssertEqual(late.label, "Hide late hours")
        attach(app, "Expanded late hours")
        late.tap()
        waitGone(app.buttons["Arrange the studio"])
        XCTAssertEqual(early.label, "Hide early hours")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(early.waitForExistence(timeout: 5))
        XCTAssertEqual(early.label, "Show early hours")
        XCTAssertEqual(late.label, "Show late hours")
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
        let destination = app.staticTexts["10"]
        XCTAssertTrue(grip.waitForExistence(timeout: 5))
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.25)
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
        let forecast = app.buttons.matching(identifier: title + ", recurring preview")
        XCTAssertEqual(forecast.count, 3)
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
        XCTAssertEqual(forecast.count, 3)

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
        XCTAssertEqual(app.buttons.matching(identifier: title + ", recurring preview").count, 3)
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

    @MainActor private func setSwitch(_ id: String, to state: Bool, app: XCUIApplication) {
        let toggle = app.switches[id]
        reveal(toggle, in: app)
        let desired = state ? "1" : "0"
        if toggle.value as? String != desired {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, desired)
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
        XCTAssertGreaterThan(workshop.firstMatch.frame.width, 128)
        XCTAssertGreaterThan(review.firstMatch.frame.width, 64)
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
        let initialX = workshop.frame.minX
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 40, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.25)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertGreaterThan(workshop.frame.minX - initialX, 180)
        XCTAssertGreaterThan(workshop.frame.width, 128)
        attach(app, "Moved all-day span retains three dates")

        let undo = app.buttons["undoCalendarSchedule"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(workshop.frame.minX, initialX, accuracy: 2)
        XCTAssertGreaterThan(workshop.frame.width, 128)
        attach(app, "Undo restores the original three-day span")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(workshop.waitForExistence(timeout: 5))
        XCTAssertEqual(workshop.frame.minX, initialX, accuracy: 2)
        XCTAssertGreaterThan(workshop.frame.width, 128)
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
        let trailing = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.79, dy: 0.5))
        let leading = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        trailing.press(forDuration: 0.05, thenDragTo: leading)
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
        let initialWidth = workshop.frame.width
        func resize(by points: CGFloat) {
            let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            grip.press(forDuration: 0.06, thenDragTo: grip.withOffset(CGVector(dx: points, dy: 0)))
        }
        resize(by: 64)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertGreaterThan(workshop.frame.width - initialWidth, 50)
        attach(app, "Extended Week all-day range")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(workshop.frame.width, initialWidth, accuracy: 2)
        resize(by: -128)
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertLessThan(workshop.frame.width, 64)
        XCTAssertTrue(handle.isHittable)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertLessThan(workshop.frame.width, 64)
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

        start.tap()
        XCTAssertTrue(app.staticTexts["The end day and reminders stay fixed."].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(start.frame.minX, initialStart, accuracy: 2)
        func resize(by points: CGFloat) {
            let grip = start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            grip.press(forDuration: 0.06, thenDragTo: grip.withOffset(CGVector(dx: points, dy: 0)))
        }
        resize(by: 192)
        let notice = app.staticTexts["calendarScheduleNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(notice.label, "Schedule updated")
        XCTAssertEqual(start.frame.minX - initialStart, 128, accuracy: 2)
        XCTAssertEqual(end.frame.maxX, initialEnd, accuracy: 2)
        XCTAssertLessThanOrEqual(end.frame.maxX - start.frame.minX, 64)
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(end.isHittable)
        attach(app, "Clamped all-day start retains both handles")
        app.buttons["undoCalendarSchedule"].tap()
        XCTAssertEqual(notice.label, "Schedule restored")
        XCTAssertEqual(start.frame.minX, initialStart, accuracy: 2)
        resize(by: 64)
        XCTAssertEqual(notice.label, "Schedule updated")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.frame.minX - initialStart, 64, accuracy: 2)
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
        let target = app.staticTexts["16"]
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
        let target = app.staticTexts["15"]
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
        setSwitch("calendarTaskIcons", to: false, app: app)
        XCTAssertEqual(app.switches["calendarNoteIcons"].value as? String, "1")
        app.buttons["calendarPreferencesDone"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])
        XCTAssertTrue(task.exists && note.exists)
        attach(app, "Only note icons shown")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["previewNotice"].waitForExistence(timeout: 10))
        app.buttons["Calendar"].tap()
        openCalendarViewOptions(app)
        XCTAssertEqual(app.switches["calendarTaskIcons"].value as? String, "0")
        XCTAssertEqual(app.switches["calendarNoteIcons"].value as? String, "1")
        setSwitch("calendarIcons", to: false, app: app)
        XCTAssertFalse(app.switches["calendarTaskIcons"].isEnabled)
        XCTAssertFalse(app.switches["calendarNoteIcons"].isEnabled)
        app.buttons["calendarPreferencesCancel"].tap()
        waitGone(app.buttons["calendarPreferencesDone"])

        openCalendarViewOptions(app)
        XCTAssertEqual(app.switches["calendarIcons"].value as? String, "1")
        setSwitch("calendarTaskIcons", to: true, app: app)
        setSwitch("calendarNoteIcons", to: false, app: app)
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
        setSwitch("calendarTaskIcons", to: false, app: app)
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
        setSwitch("calendarIcons", to: false, app: app)
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
        setSwitch("calendarAdditionalZones", to: true, app: app)
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
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertEqual(edit.value as? String, "0%")
        edit.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertNotEqual(draftValue.label, "0%")
        app.buttons["taskMetadataCancel"].tap()
        app.buttons["Discard Changes"].tap()
        waitGone(slider)
        XCTAssertEqual(edit.value as? String, "0%")
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
        app.segmentedControls["taskDestinationViewMode"].buttons["Timeline"].tap()
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
        app.segmentedControls["taskDestinationViewMode"].buttons["Timeline"].tap()
        XCTAssertTrue(workRange.waitForExistence(timeout: 5))
        XCTAssertTrue(undated.exists)
        XCTAssertFalse(personal.exists)
        XCTAssertFalse(archived.exists)

        goTo("Work and Personal", in: app)
        app.segmentedControls["taskDestinationViewMode"].buttons["Timeline"].tap()
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

    @MainActor func testScopedBoardMovesDateAndUndoesRange() {
        let app = launch(qaCase: "all-day-spans")
        goTo("Next 7 Days", in: app)
        app.segmentedControls["taskDestinationViewMode"].buttons["Board"].tap()
        let grouping = app.segmentedControls["scopedBoardGrouping"]
        XCTAssertTrue(grouping.waitForExistence(timeout: 5))
        XCTAssertTrue(grouping.buttons["Date"].isSelected)
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
        let mode = app.segmentedControls["taskDestinationViewMode"]
        let work = app.buttons["scopedBoardColumn-0"]
        let card = app.buttons["boardCard-00000000-0000-0000-0000-000000000002"]
        goTo("Open Launch projects", in: app)
        mode.buttons["Board"].tap()
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertEqual(work.label, "Work")
        XCTAssertFalse(app.buttons["scopedBoardColumn-1"].exists)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let grouping = app.segmentedControls["scopedBoardGrouping"]
        grouping.buttons["Date"].tap()
        XCTAssertTrue(grouping.buttons["Date"].isSelected)
        grouping.buttons["List"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        goTo("drawerTag-00000000-0000-0000-0000-000000000200", in: app)
        mode.buttons["Board"].tap()
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
        XCTAssertTrue(mode.buttons["Board"].isSelected)
        XCTAssertFalse(card.exists)
    }

    @MainActor func testScopedBoardDragsTagCardAcrossLists() {
        let app = launch(qaCase: "timeline")
        goTo("drawerTag-00000000-0000-0000-0000-000000000200", in: app)
        app.segmentedControls["taskDestinationViewMode"].buttons["Board"].tap()
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
