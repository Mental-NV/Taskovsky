import XCTest
@testable import TaskovskyCore

final class TemplateManagementAtomicTests: XCTestCase {
    @MainActor func testFailedManagementDoesNotPublishAndExplicitRetryPersistsOnce() throws {
        for operation in ["capture", "update", "new", "delete"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("workspace.json")
            let task = TaskItem(title: "Owned source", body: "Keep me")
            let template = TaskTemplate(name: "Owned template", title: "Original", body: "Styled",
                                        checklist: [ChecklistItem(title: "One")],
                                        richBody: RichBody(text: "Styled", runs: [.init(location: 0, length: 6, bold: true)]))
            let workspace = WorkspaceData(tasks: [task], templates: [template])
            let bytes = try JSONEncoder().encode(workspace)
            try bytes.write(to: url)
            let store = TaskStore(fileURL: url, seed: false)
            var replacement = template; replacement.name = "Renamed"
            if operation == "new" { replacement.id = UUID() }
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            switch operation {
            case "capture": XCTAssertNil(store.saveTemplate(from: task.id))
            case "update", "new": XCTAssertFalse(store.updateTemplate(replacement))
            default: XCTAssertFalse(store.deleteTemplate(id: template.id))
            }
            XCTAssertEqual(store.data, workspace, operation)
            XCTAssertNotNil(store.storageError)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
            try FileManager.default.removeItem(at: url)
            try bytes.write(to: url)
            switch operation {
            case "capture":
                let id = try XCTUnwrap(store.saveTemplate(from: task.id))
                XCTAssertEqual(store.data.templates.count, 2)
                XCTAssertEqual(store.data.templates.first, template)
                XCTAssertEqual(store.data.templates.last?.id, id)
                XCTAssertEqual(store.data.templates.last?.body, task.body)
            case "update", "new":
                XCTAssertTrue(store.updateTemplate(replacement))
                XCTAssertEqual(store.data.templates, operation == "new" ? [template, replacement] : [replacement])
            default:
                XCTAssertTrue(store.deleteTemplate(id: template.id))
                XCTAssertTrue(store.data.templates.isEmpty)
            }
            XCTAssertEqual(store.data.tasks, workspace.tasks)
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, store.data)
            XCTAssertNil(store.storageError)
            let successful = store.data
            XCTAssertNil(store.saveTemplate(from: UUID()))
            XCTAssertTrue(store.deleteTemplate(id: UUID()))
            XCTAssertEqual(store.data, successful)
            XCTAssertEqual(TaskStore(fileURL: url, seed: false).data, successful)
        }
    }

    @MainActor func testManagementRecoveryGuardPreservesUnreadableWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("workspace.json")
        let bytes = Data("{future unreadable workspace".utf8)
        try bytes.write(to: url)
        let store = TaskStore(fileURL: url, seed: false)
        let before = store.data
        let template = TaskTemplate(name: "Must not publish", title: "Owned")
        XCTAssertTrue(store.needsRecovery)
        XCTAssertFalse(store.updateTemplate(template))
        XCTAssertFalse(store.deleteTemplate(id: UUID()))
        XCTAssertNil(store.saveTemplate(from: UUID()))
        XCTAssertEqual(store.data, before)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
