import AppKit
import XCTest
import TaskovskyCore
@testable import Taskovsky

@MainActor
final class RichFormattingShortcutTests: XCTestCase {
    func testCollapsedToolbarShortcutsPreserveTextAndUseNativeUndo() throws {
        _ = NSApplication.shared
        let controller = RichBodyController()
        var commits = 0
        let host = RichBodyEditor(controller: controller, documentID: UUID(), text: "Hello", rich: nil,
                                  disabled: false, onChange: { _, _ in commits += 1 }, onHeightChange: { _ in })
        let coordinator = host.makeCoordinator()
        let view = RichBodyTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        view.isRichText = true; view.allowsUndo = true; view.delegate = coordinator
        coordinator.configure(view); controller.textView = view
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        XCTAssertTrue(window.makeFirstResponder(view))
        view.setSelectedRange(NSRange(location: 0, length: 5))
        for key in ["b", "i", "u"] {
            XCTAssertTrue(view.performKeyEquivalent(with: try event(key)))
        }
        let state = RichRender.extract(from: view)
        XCTAssertEqual(state.text, "Hello")
        XCTAssertTrue(state.rich?.runs.first?.bold == true)
        XCTAssertTrue(state.rich?.runs.first?.italic == true)
        XCTAssertTrue(state.rich?.runs.first?.underline == true)
        XCTAssertEqual(commits, 3)
        XCTAssertTrue(view.undoManager?.canUndo == true)
        view.undoManager?.undo()
        XCTAssertFalse(RichRender.extract(from: view).rich?.runs.first?.underline == true)
        let before = commits
        let title = NSTextField(frame: .zero)
        window.contentView?.addSubview(title)
        XCTAssertTrue(window.makeFirstResponder(title))
        _ = view.performKeyEquivalent(with: try event("b"))
        XCTAssertEqual(commits, before, "A shortcut outside the description must not format it")
        window.makeFirstResponder(view); view.isEditable = false
        _ = view.performKeyEquivalent(with: try event("b"))
        XCTAssertEqual(commits, before, "Locked descriptions must not be formatted")
    }

    private func event(_ key: String) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                       timestamp: 0, windowNumber: 0, context: nil, characters: key,
                                       charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0))
    }
}
