import XCTest
@testable import TaskovskyWorkspace

final class MacDescriptionRecoveryDirectoryTests: XCTestCase {
    func testStableDistinctNamespaceAndOwnedReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let location = try MacDescriptionRecoveryDirectory(workspaceURL: root.appendingPathComponent("workspace.json"))
        XCTAssertEqual(location.workspaceID, try MacDescriptionRecoveryDirectory(workspaceURL: root.appendingPathComponent("workspace.json")).workspaceID)
        XCTAssertNotEqual(location.workspaceID, try MacDescriptionRecoveryDirectory(workspaceURL: root.appendingPathComponent("other.json")).workspaceID)
        try location.prepare(); let task = UUID(), journal = try location.journal(taskID: task)
        let draft = MacDescriptionDraft(workspaceID: location.workspaceID, taskID: task, baseline: DescriptionSnapshot(body:"saved",rich:nil)!)
        let result = await journal.save(draft); XCTAssertEqual(result,.saved)
        XCTAssertEqual(try location.savedTaskIDs(),[task])
        guard case .available(let recovered) = await (try location.journal(taskID:task)).load() else { return XCTFail("Missing recovery") }
        XCTAssertEqual(recovered,draft)
    }
    func testSymlinkAndUnknownEntriesRefuseWithoutRemoval() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let location = try MacDescriptionRecoveryDirectory(workspaceURL: root.appendingPathComponent("workspace.json")); try location.prepare()
        let outside = root.appendingPathComponent("owned-outside.json"); try Data("preserve".utf8).write(to:outside)
        let task = UUID(), link = location.root.appendingPathComponent(task.uuidString+".json")
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:outside)
        XCTAssertThrowsError(try location.journal(taskID:task)); XCTAssertThrowsError(try location.savedTaskIDs())
        XCTAssertEqual(try Data(contentsOf:outside),Data("preserve".utf8))
    }
    func testExistingJournalRevalidatesReplacementLinkBeforeRead() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let location = try MacDescriptionRecoveryDirectory(workspaceURL: root.appendingPathComponent("workspace.json")); try location.prepare()
        let task = UUID(), journal = try location.journal(taskID: task)
        let outside = root.appendingPathComponent("outside.json")
        try Data("preserve".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: location.root.appendingPathComponent(task.uuidString + ".json"), withDestinationURL: outside)
        guard case .unavailable = await journal.load() else { return XCTFail("Replacement link must refuse") }
        XCTAssertEqual(try Data(contentsOf: outside), Data("preserve".utf8))
    }

}
