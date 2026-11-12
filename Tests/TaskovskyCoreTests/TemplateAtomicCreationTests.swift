import XCTest
@testable import TaskovskyCore

final class TemplateAtomicCreationTests: XCTestCase {
    @MainActor func testTemplateFailurePreservesWorkspaceAndRetryCreatesOneTaskAtConfiguredPosition() throws {
        for position in TaskPosition.allCases {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("workspace.json")
            let template = TaskTemplate(name: "Owned template", title: "Created", body: "Preserve content",
                                        checklist: [ChecklistItem(title: "Step")], priority: .high)
            let workspace = WorkspaceData(tasks: [TaskItem(title: "Existing")], templates: [template])
            let bytes = try JSONEncoder().encode(workspace)
            try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            store.settings.defaultAddTo = position
            let before = store.data
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            XCTAssertNil(store.createTaskFromTemplate(id: template.id))
            XCTAssertEqual(store.data, before)
            XCTAssertNotNil(store.storageError)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
            try FileManager.default.removeItem(at: url)
            try bytes.write(to: url)
            let id = try XCTUnwrap(store.createTaskFromTemplate(id: template.id))
            XCTAssertEqual(store.data.tasks.count, before.tasks.count + 1)
            XCTAssertEqual(position == .top ? store.data.tasks.first?.id : store.data.tasks.last?.id, id)
            let created = try XCTUnwrap(store.data.tasks.first { $0.id == id })
            XCTAssertEqual(created.title, template.title)
            XCTAssertEqual(created.body, template.body)
            XCTAssertEqual(created.priority, template.priority)
            XCTAssertEqual(created.checklist.map(\.title), template.checklist.map(\.title))
            XCTAssertEqual(store.data.templates, before.templates)
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
            XCTAssertNil(store.storageError)
        }
    }

    @MainActor func testSectionTemplateFailureAndSuccessRemainAtomic() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("workspace.json")
        let template = TaskTemplate(name: "Owned", title: "Section task")
        let list = TaskList(name: "Owned list", color: "#123456")
        let section = TaskSection(name: "Owned section")
        var workspace = WorkspaceData(lists: [list], templates: [template])
        XCTAssertEqual(TaskSectionChange(listID: list.id, operation: .create(section)).apply(to: &workspace, now: Date()), true)
        let bytes = try JSONEncoder().encode(workspace)
        try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertNil(store.createTaskFromTemplate(id: template.id, listID: list.id, sectionID: UUID()))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertNil(store.createTaskFromTemplate(id: template.id, listID: list.id, sectionID: section.id))
        XCTAssertEqual(store.data, workspace)
        try FileManager.default.removeItem(at: url)
        try bytes.write(to: url)
        let id = try XCTUnwrap(store.createTaskFromTemplate(id: template.id, listID: list.id, sectionID: section.id))
        let task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.listID, list.id)
        XCTAssertEqual(task.sectionID, section.id)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
    }

    @MainActor func testProtectedUnknownFieldsStillBlockTemplateCreation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("workspace.json")
        let template = TaskTemplate(name: "Owned", title: "Never created")
        var existing = TaskItem(title: "Protected")
        existing.manualProgress = 25
        let workspace = WorkspaceData(tasks: [existing], templates: [template])
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as? [String: Any])
        document["futureUnrecognizedField"] = ["keep": true]
        let bytes = try JSONSerialization.data(withJSONObject: document)
        try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(store.needsRecovery)
        let before = store.data
        XCTAssertNil(store.createTaskFromTemplate(id: template.id))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
