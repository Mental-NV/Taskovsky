import AppKit
import SwiftUI
import XCTest
import TaskovskyCore
@testable import Taskovsky

@MainActor
final class ListEditorPreviewTests: XCTestCase {
    func testAccessibilitySummaryDoesNotAdvertiseUnavailableTimelinePreview() {
        func summary(_ mode: TaskListViewMode, name: String) -> String {
            ListEditorPreview(name: name, symbol: "book", tint: .blue, mode: mode, kind: .task)
                .accessibilitySummary
        }

        XCTAssertEqual(summary(.timeline, name: "  Work  "), "Timeline preview is not available.")
        XCTAssertEqual(summary(.timeline, name: " "), "Timeline preview is not available.")
        XCTAssertEqual(summary(.list, name: "Work"), "Illustrative List preview for Work. No saved items are displayed.")
        XCTAssertEqual(summary(.board, name: "Work"), "Illustrative Board preview for Work. No saved items are displayed.")
    }

    func testPreviewModesFitBoundedPaneAndDoNotNeedStore() {
        _ = NSApplication.shared
        for mode in [TaskListViewMode.list, .board, .timeline] {
            for kind in [TaskKind.task, .note] {
                for name in ["", String(repeating: "Long draft name ", count: 8)] {
                    let view = NSHostingView(rootView: ListEditorPreview(name: name, symbol: "book",
                        tint: .blue, mode: mode, kind: kind).frame(width: 280).environment(\.colorScheme, .light))
                    let size = view.fittingSize
                    XCTAssertEqual(size.width, 280, accuracy: 1)
                    XCTAssertTrue(size.height.isFinite)
                    XCTAssertGreaterThan(size.height, 60)
                    XCTAssertLessThan(size.height, 480)
                }
            }
        }
    }

    func testEntitySheetUsesWorkspaceWidthWithoutInvokingSave() {
        _ = NSApplication.shared
        var saveCalls = 0
        func fittingWidth(isTag: Bool, workspaceWidth: CGFloat) -> CGFloat {
            let view = NSHostingView(rootView: EntitySheet(
                editor: EntityEditor(isTag: isTag), workspaceWidth: workspaceWidth
            ) { _, _, _, _, _, _, _, _, _ in
                saveCalls += 1; return true
            })
            return view.fittingSize.width
        }
        XCTAssertEqual(fittingWidth(isTag: true, workspaceWidth: 1060), 360, accuracy: 1)
        XCTAssertEqual(fittingWidth(isTag: false, workspaceWidth: 382), 360, accuracy: 1)
        XCTAssertEqual(fittingWidth(isTag: false, workspaceWidth: 639), 360, accuracy: 1)
        XCTAssertEqual(fittingWidth(isTag: false, workspaceWidth: 640), 640, accuracy: 1)
        XCTAssertEqual(fittingWidth(isTag: false, workspaceWidth: 1060), 640, accuracy: 1)
        XCTAssertEqual(saveCalls, 0)
    }
}
