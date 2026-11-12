import XCTest
@testable import TaskovskyWorkspace
import TaskovskyDomain

final class DescriptionJSONPatchTests: XCTestCase {
    func testExactUnicodeAndUnrelatedRawPreservation() throws {
        let task = TaskItem(title: "Task", body: "é")
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [task]))) as! [String: Any]
        var records = object["tasks"] as! [[String: Any]]; records[0]["future"] = ["keep": true]; object["tasks"] = records; object["futureRoot"] = "keep"
        let bytes = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
        let old = DescriptionSnapshot(body: task.body, rich: nil)!, new = DescriptionSnapshot(body: "e\u{301}", rich: nil)!
        let patched = try XCTUnwrap(DescriptionJSONPatch.applying(taskID: task.id, content: new, expected: old, to: bytes, now: Date()))
        let result = try JSONDecoder().decode(WorkspaceData.self, from: patched)
        XCTAssertTrue(result.tasks[0].body.utf16.elementsEqual(new.body.utf16))
        let raw = try JSONSerialization.jsonObject(with: patched) as! [String: Any]
        XCTAssertEqual(raw["futureRoot"] as? String, "keep"); XCTAssertNotNil((raw["tasks"] as? [[String: Any]])?[0]["future"])
    }
    func testProtectedRichFormatTransitionAndRemoval() throws {
        let task = TaskItem(title: "Task", body: "old"), old = DescriptionSnapshot(body: "old", rich: nil)!
        let rich = RichBody(text: "new", runs: [RichInlineRun(location: 0, length: 3, highlight: true, highlightColor: .green)])
        let content = DescriptionSnapshot(body: "new", rich: rich)!
        let bytes = try JSONEncoder().encode(WorkspaceData(tasks: [task]))
        let patched = try XCTUnwrap(DescriptionJSONPatch.applying(taskID: task.id, content: content, expected: old, to: bytes, now: Date()))
        let raw = try JSONSerialization.jsonObject(with: patched) as! [String: Any]
        XCTAssertEqual((raw["tasks"] as? [String: Any])?["format"] as? String, "richHighlightColorsV1")
        let removed = try XCTUnwrap(DescriptionJSONPatch.applying(taskID: task.id, content: old, expected: content, to: patched, now: Date()))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: removed).tasks[0].body, "old")
    }
    func testChangedBaselineAndUnknownRichMetadataRefuse() throws {
        let rich = RichBody(text: "old"), task = TaskItem(title: "Task", body: "old", richBody: rich)
        let bytes = try JSONEncoder().encode(WorkspaceData(tasks: [task]))
        let wrong = DescriptionSnapshot(body: "external", rich: nil)!, old = DescriptionSnapshot(body: "old", rich: rich)!, new = DescriptionSnapshot(body: "new", rich: nil)!
        XCTAssertNil(try DescriptionJSONPatch.applying(taskID: task.id, content: new, expected: wrong, to: bytes, now: Date()))
        var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        var records = raw["tasks"] as! [[String: Any]], companion = records[0]["richBody"] as! [String: Any]
        companion["future"] = true; records[0]["richBody"] = companion; raw["tasks"] = records
        let unknown = try JSONSerialization.data(withJSONObject: raw, options: .sortedKeys)
        XCTAssertNil(try DescriptionJSONPatch.applying(taskID: task.id, content: new, expected: old, to: unknown, now: Date()))
        XCTAssertEqual(try DescriptionJSONPatch.applying(taskID: task.id, content: old, expected: old, to: unknown, now: Date()), unknown)
    }
    func testCodeAndHigherPriorityProtectionAreRetained() throws {
        let old = DescriptionSnapshot(body: "old", rich: nil)!
        let code = RichBody(text: "code", blocks: [RichBlockRun(location: 0, length: 4, codeBlockID: UUID())])
        let content = try XCTUnwrap(DescriptionSnapshot(body: "code", rich: code))
        for progress in [false, true] {
            var task = TaskItem(title: "Task", body: "old")
            if progress { task.manualProgress = 50 }
            let bytes = try JSONEncoder().encode(WorkspaceData(tasks: [task]))
            let patched = try XCTUnwrap(DescriptionJSONPatch.applying(taskID: task.id, content: content, expected: old, to: bytes, now: Date()))
            let object = try JSONSerialization.jsonObject(with: patched) as! [String: Any]
            XCTAssertEqual((object["tasks"] as? [String: Any])?["format"] as? String, progress ? "taskProgressV1" : "richCodeBlocksV1")
            XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: patched).tasks[0].manualProgress, task.manualProgress)
        }
    }

}
