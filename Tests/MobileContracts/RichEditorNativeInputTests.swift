#if DEBUG
import SwiftUI
import UIKit
import XCTest
import TaskovskyDomain
import TaskovskyWorkspace
@testable import TaskovskyMobile

final class RichEditorNativeInputTests: XCTestCase {
    @MainActor func testUIKitKeepsMarkedTextLocalAndCommitsAtItsOriginalStyleBoundary() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let harness = RichInputHarness()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: RichInputHarnessView(harness: harness))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKey() }
        window.layoutIfNeeded()
        let editor = try XCTUnwrap(input(in: window))
        XCTAssertTrue(editor.isFirstResponder || editor.becomeFirstResponder())
        editor.selectedRange = NSRange(location: 1, length: 0)

        editor.setMarkedText("a", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(editor.markedTextRange)
        XCTAssertTrue(harness.composing)
        XCTAssertEqual(harness.content.text, "aaa")
        XCTAssertEqual(harness.operationCount, 0)

        editor.setMarkedText("aa", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual(harness.content.text, "aaa")
        XCTAssertEqual(harness.operationCount, 0)
        editor.unmarkText()
        XCTAssertFalse(harness.composing)
        XCTAssertEqual(harness.content.text, "aaaaa")
        XCTAssertEqual(harness.content.runs, [.init(location: 3, length: 2, bold: true)])
        XCTAssertEqual(harness.operationCount, 1)
    }

    @MainActor private func input(in view: UIView) -> UITextView? {
        if let editor = view as? UITextView, editor.accessibilityIdentifier == "richFieldEditor" { return editor }
        return view.subviews.lazy.compactMap { self.input(in: $0) }.first
    }
}

@MainActor private final class RichInputHarness: ObservableObject {
    @Published var content = RichBody(text: "aaa", runs: [.init(location: 1, length: 2, bold: true)])
    @Published var selection = NSRange(location: 0, length: 0)
    @Published var composing = false
    private(set) var operationCount = 0

    func apply(_ edit: RichBodyEdit) -> Bool {
        do {
            content = try RichBodyEdit.applying([edit], to: content.text, rich: content)
            operationCount += 1
            return true
        } catch { return false }
    }
}

private struct RichInputHarnessView: View {
    @ObservedObject var harness: RichInputHarness

    var body: some View {
        PhoneRichTextInput(content: harness.content, selection: $harness.selection, composing: $harness.composing,
                           editable: true, read: { harness.content }, apply: harness.apply)
    }
}

/// Deterministic clock deliberately ignores cancellation to exercise stale timers.
@MainActor private final class FeedbackTestClock {
    var waits: [CheckedContinuation<Void, Error>] = []
    var durations: [Duration] = []
    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        try await withCheckedThrowingContinuation { waits.append($0) }
    }
    func advance(_ index: Int) {
        guard waits.indices.contains(index) else { return XCTFail("Missing timer continuation") }
        waits[index].resume()
    }
    func waitForCount(_ count: Int) async {
        for _ in 0..<200 where waits.count < count { await Task.yield() }
        XCTAssertEqual(waits.count, count)
    }
}

final class PhoneFeedbackLifetimeTests: XCTestCase {
    @MainActor func testIdenticalSuccessRestartsWindowAndOldTimerCannotClearNewMessage() async {
        let clock = FeedbackTestClock()
        let lifetime = PhoneFeedbackLifetime(sleep: clock.sleep)
        let model = PhoneWorkspaceModel(arguments: ["--qa-session", UUID().uuidString], feedbackLifetime: lifetime)
        model.showCreationNotice("Task added")
        await clock.waitForCount(1)
        model.showCreationNotice("Task added")
        await clock.waitForCount(2)
        XCTAssertEqual(clock.waits.count, 2)
        clock.advance(0)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.creationNotice, "Task added")
        clock.advance(1)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.creationNotice)
    }

    @MainActor func testCancelledSuccessCannotDismissPersistentReplacement() async {
        let clock = FeedbackTestClock()
        let lifetime = PhoneFeedbackLifetime(sleep: clock.sleep)
        var message = "Schedule updated"
        lifetime.replace(.schedule(.calendar)) { message = "" }
        await clock.waitForCount(1)
        lifetime.cancel(.schedule(.calendar))
        message = "Could not save. Retry."
        clock.advance(0)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(message, "Could not save. Retry.")
    }

    @MainActor func testIndependentSurfaceAndLifecycleLifetimes() async {
        let clock = FeedbackTestClock()
        let lifetime = PhoneFeedbackLifetime(sleep: clock.sleep)
        var expired: Set<String> = []
        lifetime.replace(.schedule(.calendar)) { expired.insert("calendar") }
        await clock.waitForCount(1)
        lifetime.replace(.schedule(.tasks)) { expired.insert("tasks") }
        await clock.waitForCount(2)
        lifetime.replace(.lifecycle) { expired.insert("lifecycle") }
        await clock.waitForCount(3)
        clock.advance(0)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(expired, ["calendar"])
        clock.advance(1); clock.advance(2)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(expired, ["calendar", "tasks", "lifecycle"])
    }

    @MainActor func testBatchDismissAndNewEmissionAreIndependentOfOldExpiry() async {
        let clock = FeedbackTestClock()
        let lifetime = PhoneFeedbackLifetime(sleep: clock.sleep)
        let model = PhoneWorkspaceModel(arguments: ["--qa-session", UUID().uuidString], feedbackLifetime: lifetime)
        model.showBatchNotice("Tasks updated")
        await clock.waitForCount(1)
        model.clearBatchNotice()
        model.showBatchNotice("Tasks updated")
        await clock.waitForCount(2)
        clock.advance(0)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.batchNotice, "Tasks updated")
        clock.advance(1)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.batchNotice)
    }
    @MainActor func testActualScheduleAndLifecycleExpireUndoAndPreserveNewErrors() async throws {
        let clock = FeedbackTestClock()
        let model = PhoneWorkspaceModel(arguments: ["--qa-session", UUID().uuidString],
                                        feedbackLifetime: PhoneFeedbackLifetime(sleep: clock.sleep))
        await model.open()
        var document = try XCTUnwrap(model.document)
        let task = try XCTUnwrap(document.snapshot.workspace.tasks.first { $0.kind == .task && $0.dueDate != nil && $0.completedAt == nil })
        let error = await model.saveCalendarSchedule(.unschedule, taskID: task.id, expected: document.revision)
        XCTAssertNil(error)
        await clock.waitForCount(1)
        XCTAssertTrue(model.canUndoSchedule(in: .calendar))
        clock.advance(0)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.scheduleNotice(in: .calendar))
        XCTAssertFalse(model.canUndoSchedule(in: .calendar))

        document = try XCTUnwrap(model.document)
        let saved = await model.performLifecycle(.complete, taskID: task.id, expected: document.revision)
        XCTAssertTrue(saved)
        await clock.waitForCount(2)
        XCTAssertEqual(model.lifecycleNotice, "Task completed")
        XCTAssertTrue(model.canUndoLifecycle)
        document = try XCTUnwrap(model.document)
        _ = await model.performLifecycle(.complete, taskID: UUID(), expected: document.revision)
        let persistentError = try XCTUnwrap(model.lifecycleNotice)
        XCTAssertNotEqual(persistentError, "Task completed")
        clock.advance(1)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.lifecycleNotice, persistentError)
    }

    @MainActor func testActualLifecycleExpiryClearsUndoAndScheduleErrorCancelsOldTimer() async throws {
        let clock = FeedbackTestClock()
        let model = PhoneWorkspaceModel(arguments: ["--qa-session", UUID().uuidString],
                                        feedbackLifetime: PhoneFeedbackLifetime(sleep: clock.sleep))
        await model.open()
        var document = try XCTUnwrap(model.document)
        let task = try XCTUnwrap(document.snapshot.workspace.tasks.first { $0.kind == .task && $0.dueDate != nil && $0.completedAt == nil })
        _ = await model.performLifecycle(.complete, taskID: task.id, expected: document.revision)
        await clock.waitForCount(1)
        clock.advance(0)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.lifecycleNotice)
        XCTAssertFalse(model.canUndoLifecycle)
        document = try XCTUnwrap(model.document)
        _ = await model.saveCalendarSchedule(.unschedule, taskID: task.id, expected: document.revision)
        await clock.waitForCount(2)
        document = try XCTUnwrap(model.document)
        await model.dropCalendarTask(.unschedule, taskID: UUID(), expected: document.revision)
        let persistentError = try XCTUnwrap(model.scheduleNotice(in: .calendar))
        XCTAssertNotEqual(persistentError, "Schedule updated")
        clock.advance(1)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.scheduleNotice(in: .calendar), persistentError)
    }

}
#endif
