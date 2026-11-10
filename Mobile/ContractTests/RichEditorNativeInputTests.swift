#if DEBUG
import SwiftUI
import UIKit
import XCTest
import TaskovskyDomain
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
#endif
