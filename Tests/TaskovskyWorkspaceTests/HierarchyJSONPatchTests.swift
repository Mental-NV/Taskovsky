import XCTest
@testable import TaskovskyDomain
@testable import TaskovskyWorkspace

final class HierarchyJSONPatchTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func testCreationPreservesRawUnknownTaskAndChecklistDataAtBothEnds() throws {
        let parent = TaskItem(title: "Parent", checklist: [ChecklistItem(title: "Keep")])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [parent]))) as? [String: Any])
        var records = try XCTUnwrap(object["tasks"] as? [[String: Any]])
        records[0]["futureTask"] = ["text": "é \\\""]
        var steps = try XCTUnwrap(records[0]["checklist"] as? [[String: Any]]); steps[0]["futureStep"] = ["value": 42]; records[0]["checklist"] = steps
        object["tasks"] = records; object["futureRoot"] = "preserved"
        let raw = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
        let original = try JSONDecoder().decode(WorkspaceData.self, from: raw)
        let originalRecord = String(decoding: try JSONSerialization.data(withJSONObject: records[0], options: .sortedKeys), as: UTF8.self)
        for position in [TaskPosition.top, .bottom] {
            var staged = original
            let childID = UUID()
            XCTAssertTrue(TaskHierarchy.addChild(id: childID, to: parent.id, title: "Child", in: &staged, position: position, now: now))
            let patched = try XCTUnwrap(HierarchyJSONPatch.applying(staged: staged, to: raw))
            XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: patched), staged)
            XCTAssertTrue(String(decoding: patched, as: UTF8.self).contains(originalRecord))
            XCTAssertTrue(String(decoding: patched, as: UTF8.self).contains("\"futureRoot\":\"preserved\""))
        }
    }
    func testCrossListDescendantsAndSectionClearingRoundTripWithoutReorder() throws {
        let section = TaskSection(name: "Owned section")
        var source = TaskList(name: "Source", color: "#123456"); source.sections = [section]
        let target = TaskList(name: "Target", color: "#654321")
        let parent = TaskItem(title: "Parent", listID: target.id)
        var child = TaskItem(title: "Child", listID: source.id); child.sectionID = section.id
        let grandchild = TaskItem(title: "Grandchild", listID: source.id, parentID: child.id)
        let original = WorkspaceData(tasks: [parent, child, grandchild], lists: [source, target])
        let raw = try JSONEncoder().encode(original); var staged = original
        XCTAssertEqual(TaskHierarchy.setParent(childID: child.id, parentID: parent.id, in: &staged, now: now), true)
        XCTAssertEqual(staged.tasks.map(\.id), original.tasks.map(\.id)); XCTAssertNil(staged.tasks[1].sectionID)
        XCTAssertEqual(staged.tasks[1].listID, target.id); XCTAssertEqual(staged.tasks[2].listID, target.id)
        let patched = try XCTUnwrap(HierarchyJSONPatch.applying(staged: staged, to: raw))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: patched), staged)
    }
    func testEveryCurrentProtectedFormatSurvivesChildInsertion() throws {
        for format in ["occurrenceSchedulesV1", "listSectionsV1", "richCodeBlocksV1", "richHighlightColorsV1", "taskProgressV1", "endRemindersV1"] {
            var parent = TaskItem(title: "Protected", dueDate: now, hasDueTime: true)
            var lists: [TaskList] = []
            switch format {
            case "occurrenceSchedulesV1": parent.recurrence = .daily; parent.originalOccurrenceSchedule = OccurrenceSchedule(task: parent)
            case "listSectionsV1":
                var list = TaskList(name: "List", color: "#123456"); list.sections = [TaskSection(name: "Section")]; lists = [list]; parent.listID = list.id
            case "richCodeBlocksV1": parent.body = "x"; parent.richBody = RichBody(text: "x", blocks: [.init(location: 0, length: 1, codeBlockID: UUID())])
            case "richHighlightColorsV1": parent.body = "x"; parent.richBody = try RichBodyEdit.applying([.setHighlight(.blue, NSRange(location: 0, length: 1))], to: "x", rich: nil)
            case "taskProgressV1": parent = try XCTUnwrap(TaskMetadataChange.progress(50).applying(to: parent, availableTags: []))
            default: parent.endReminderEnabled = true
            }
            let original = WorkspaceData(tasks: [parent], lists: lists), raw = try JSONEncoder().encode(original)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
            XCTAssertEqual((object["tasks"] as? [String: Any])?["format"] as? String, format)
            var staged = original
            XCTAssertTrue(TaskHierarchy.addChild(id: UUID(), to: parent.id, title: "Child", in: &staged, position: .top, now: now))
            let patched = try XCTUnwrap(HierarchyJSONPatch.applying(staged: staged, to: raw))
            XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: patched), staged)
            let after = try XCTUnwrap(JSONSerialization.jsonObject(with: patched) as? [String: Any])
            XCTAssertEqual((after["tasks"] as? [String: Any])?["format"] as? String, format)
        }
    }
    func testSanitizedAffectedParentRefusesInsteadOfRewritingRawIntent() throws {
        let parent = TaskItem(title: "Parent"), child = TaskItem(title: "Child", parentID: UUID())
        let raw = try JSONEncoder().encode(WorkspaceData(tasks: [parent, child]))
        var staged = try JSONDecoder().decode(WorkspaceData.self, from: raw)
        XCTAssertNil(staged.tasks[1].parentID)
        XCTAssertEqual(TaskHierarchy.setParent(childID: child.id, parentID: parent.id, in: &staged, now: now), true)
        XCTAssertNil(try HierarchyJSONPatch.applying(staged: staged, to: raw))
    }
    func testDeletionReorderDuplicateAndFormatChangesAreRefused() throws {
        let parent = TaskItem(title: "Parent"), child = TaskItem(title: "Child")
        let original = WorkspaceData(tasks: [parent, child]), raw = try JSONEncoder().encode(original)
        var staged = original; staged.tasks.reverse()
        XCTAssertNil(try HierarchyJSONPatch.applying(staged: staged, to: raw))
        staged = original; staged.tasks.removeLast(); XCTAssertNil(try HierarchyJSONPatch.applying(staged: staged, to: raw))
        staged = original; staged.tasks.append(parent); XCTAssertNil(try HierarchyJSONPatch.applying(staged: staged, to: raw))
        staged = original; staged.tasks[0] = try XCTUnwrap(TaskMetadataChange.progress(50).applying(to: parent, availableTags: []))
        XCTAssertNil(try HierarchyJSONPatch.applying(staged: staged, to: raw))
        let duplicate = Data("{\"tasks\":[],\"tasks\":[],\"lists\":[],\"tags\":[]}".utf8)
        XCTAssertNil(try HierarchyJSONPatch.applying(staged: original, to: duplicate))
    }
}
