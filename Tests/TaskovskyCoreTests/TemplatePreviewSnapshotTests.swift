import XCTest
@testable import TaskovskyCore

final class TemplatePreviewSnapshotTests: XCTestCase {
    @MainActor func testPreviewExpectedSnapshotRejectsChangedRemovedAndWrongTemplate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("workspace.json")
        let template = TaskTemplate(name: "Owned snapshot", title: "Original", body: "Styled",
                                    checklist: [ChecklistItem(title: "One")],
                                    richBody: RichBody(text: "Styled", runs: [.init(location: 0, length: 6, bold: true)]))
        try JSONEncoder().encode(WorkspaceData(templates: [template])).write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        var changed = template; changed.title = "Changed elsewhere"
        store.updateTemplate(changed)
        let changedBytes = try Data(contentsOf: url)
        XCTAssertNil(store.createTaskFromTemplate(id: template.id, expectedTemplate: template))
        XCTAssertEqual(try Data(contentsOf: url), changedBytes)
        XCTAssertTrue(store.data.tasks.isEmpty)
        let id = try XCTUnwrap(store.createTaskFromTemplate(id: template.id, expectedTemplate: changed))
        let created = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(created.title, changed.title)
        XCTAssertEqual(created.richBody, changed.richBody)
        XCTAssertEqual(created.checklist.map(\.title), changed.checklist.map(\.title))
        XCTAssertNotEqual(created.checklist.first?.id, changed.checklist.first?.id)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
        let successBytes = try Data(contentsOf: url)
        XCTAssertNil(store.createTaskFromTemplate(id: UUID(), expectedTemplate: changed))
        XCTAssertEqual(try Data(contentsOf: url), successBytes)
        store.deleteTemplate(id: changed.id)
        let deletedBytes = try Data(contentsOf: url)
        XCTAssertNil(store.createTaskFromTemplate(id: changed.id, expectedTemplate: changed))
        XCTAssertEqual(try Data(contentsOf: url), deletedBytes)
        XCTAssertEqual(store.data.tasks.count, 1)
    }
}
