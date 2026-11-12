import XCTest
@testable import TaskovskyWorkspace
import TaskovskyDomain

final class ListEditorJSONPatchTests: XCTestCase {
    func testRenamePreservesUnknownRawFieldsAndNoOpBytes() throws {
        let id = UUID()
        let bytes = Data("""
        { "lists" : [{"id":"\(id)","name":"Old","color":"#123456", "future":{"x":1.00},"symbol":null}], "futureRoot":[1.00,"\\u0061"],"tasks":[],"tags":[],"filters":[],"templates":[],"folders":[] }
        """.utf8)
        let original = try JSONDecoder().decode(WorkspaceData.self, from: bytes).lists[0]
        XCTAssertEqual(try ListEditorJSONPatch.applying(original, expected: original, to: bytes), bytes)
        var value = original; value.name = "New 🗂"
        let patched = try XCTUnwrap(ListEditorJSONPatch.applying(value, expected: original, to: bytes))
        let text = String(decoding: patched, as: UTF8.self)
        XCTAssertTrue(text.contains("\"future\":{\"x\":1.00}")); XCTAssertTrue(text.contains("\"futureRoot\":[1.00,\"\\u0061\"]"))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: patched).lists, [value])
    }
    func testAppendPreservesExistingOrderAndProtectedTaskBytes() throws {
        var list = TaskList(name: "Existing", color: "#123456"); list.sections = [TaskSection(name: "Section")]
        let task = TaskItem(title: "Task", listID: list.id)
        let data = try JSONEncoder().encode(WorkspaceData(tasks: [task], lists: [list]))
        let before = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let added = TaskList(name: "Board", color: "#ABCDEF", viewMode: .board)
        let result = try XCTUnwrap(ListEditorJSONPatch.applying(added, expected: nil, to: data))
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: result) as? [String: Any])
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: before["tasks"]!, options: .sortedKeys), try JSONSerialization.data(withJSONObject: after["tasks"]!, options: .sortedKeys))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: result).lists, [list, added])
        XCTAssertNil(try ListEditorJSONPatch.applying(added, expected: nil, to: result))
    }
    func testStaleDefinitionAndDuplicateKeysRefuse() throws {
        let original = TaskList(name: "Original", color: "#123456")
        for update in [0, 1, 2, 3] {
            var current = original
            switch update { case 0: current.isPinned = true; case 1: current.isArchived = true; case 2: current.sections = [TaskSection(name: "New")]; default: current.viewMode = .timeline }
            let bytes = try JSONEncoder().encode(WorkspaceData(lists: [current]))
            var edit = original; edit.name = "Edited"
            XCTAssertNil(try ListEditorJSONPatch.applying(edit, expected: original, to: bytes))
        }
        let duplicate = Data("{\"lists\":[],\"lists\":[]}".utf8)
        XCTAssertNil(try ListEditorJSONPatch.applying(original, expected: nil, to: duplicate))
    }
}
