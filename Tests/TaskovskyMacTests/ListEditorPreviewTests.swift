import AppKit
import SwiftUI
import XCTest
import TaskovskyCore
@testable import Taskovsky

@MainActor
final class ListEditorPreviewTests: XCTestCase {
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

    func testEntitySheetRenderingNeverInvokesSaveAndTagsKeepOriginalWidth() {
        _ = NSApplication.shared
        var saveCalls = 0
        let tag = NSHostingView(rootView: EntitySheet(editor: EntityEditor(isTag: true)) { _, _, _, _, _, _, _, _, _ in
            saveCalls += 1; return true
        })
        XCTAssertEqual(tag.fittingSize.width, 360, accuracy: 1)
        let list = NSHostingView(rootView: EntitySheet(editor: EntityEditor(isTag: false)) { _, _, _, _, _, _, _, _, _ in
            saveCalls += 1; return true
        })
        let size = list.fittingSize
        XCTAssertTrue(size.width.isFinite && size.height.isFinite)
        XCTAssertLessThanOrEqual(size.width, 640 + 1)
        XCTAssertGreaterThanOrEqual(size.width, 360 - 1)
        XCTAssertEqual(saveCalls, 0)
    }
}
