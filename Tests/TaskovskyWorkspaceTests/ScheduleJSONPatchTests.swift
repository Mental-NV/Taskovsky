import XCTest
@testable import TaskovskyDomain
@testable import TaskovskyWorkspace

final class ScheduleJSONPatchTests: XCTestCase {
    func testOccurrenceEnvelopeUpgradeDowngradeAndHigherPriorityProtection() throws {
        for progress in [false, true] {
            var task = TaskItem(title: "Owned", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true, recurrence: .daily)
            if progress { task.manualProgress = 35 }
            let original = WorkspaceData(tasks: [task])
            let bytes = try JSONEncoder().encode(original)
            var staged = original
            staged.tasks[0].originalOccurrenceSchedule = OccurrenceSchedule(task: task)
            staged.tasks[0].dueDate = task.dueDate!.addingTimeInterval(3600)
            let patched = try XCTUnwrap(ScheduleJSONPatch.applying(taskID: task.id, staged: staged, to: bytes))
            let root = try XCTUnwrap(JSONSerialization.jsonObject(with: patched) as? [String: Any])
            XCTAssertEqual((root["tasks"] as? [String: Any])?["format"] as? String, progress ? "taskProgressV1" : "occurrenceSchedulesV1")
            let restored = try XCTUnwrap(ScheduleJSONPatch.applying(taskID: task.id, staged: original, to: patched))
            XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: restored), original)
            let restoredRoot = try XCTUnwrap(JSONSerialization.jsonObject(with: restored) as? [String: Any])
            if progress { XCTAssertEqual((restoredRoot["tasks"] as? [String: Any])?["format"] as? String, "taskProgressV1") }
            else { XCTAssertNotNil(restoredRoot["tasks"] as? [Any]) }
        }
    }
    func testUnknownNestedChangedFieldRefusedUntouchedFieldPreserved() throws {
        var task = TaskItem(title: "Owned", dueDate: Date(timeIntervalSince1970: 2_000_000_000), hasDueTime: true)
        task.scheduledDuration = .init(start: task.dueDate!.addingTimeInterval(-3600), end: task.dueDate!)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [task]))) as? [String: Any])
        var records = try XCTUnwrap(root["tasks"] as? [[String: Any]])
        var duration = try XCTUnwrap(records[0]["scheduledDuration"] as? [String: Any])
        duration["future"] = "retain"; records[0]["scheduledDuration"] = duration; root["tasks"] = records
        let bytes = try JSONSerialization.data(withJSONObject: root)
        let original = try JSONDecoder().decode(WorkspaceData.self, from: bytes)
        var changed = original; changed.tasks[0].scheduledDuration!.end = task.dueDate!.addingTimeInterval(3600)
        XCTAssertNil(try ScheduleJSONPatch.applying(taskID: task.id, staged: changed, to: bytes))
        changed = original; changed.tasks[0].timeZoneID = "UTC"
        let patched = try XCTUnwrap(ScheduleJSONPatch.applying(taskID: task.id, staged: changed, to: bytes))
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        let afterRecords = try XCTUnwrap(after["tasks"] as? [[String: Any]])
        XCTAssertEqual((afterRecords[0]["scheduledDuration"] as? [String: Any])?["future"] as? String, "retain")
    }
    func testRejectsNonScheduleChangeDuplicateIDAndUnknownEnvelopeMember() throws {
        var task = TaskItem(title: "Owned")
        let original = WorkspaceData(tasks: [task]), bytes = try JSONEncoder().encode(WorkspaceData(tasks: [task]))
        var staged = original; staged.tasks[0].title = "Not schedule"
        XCTAssertNil(try ScheduleJSONPatch.applying(taskID: task.id, staged: staged, to: bytes))
        let duplicates = WorkspaceData(tasks: [task, task])
        XCTAssertNil(try ScheduleJSONPatch.applying(taskID: task.id, staged: duplicates, to: JSONEncoder().encode(duplicates)))
        task.dueDate = Date(timeIntervalSince1970: 2_000_000_000); task.recurrence = .daily; task.originalOccurrenceSchedule = OccurrenceSchedule(task: task)
        XCTAssertNotNil(task.originalOccurrenceSchedule)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkspaceData(tasks: [task]))) as? [String: Any])
        var envelope = try XCTUnwrap(root["tasks"] as? [String: Any]); envelope["future"] = true; root["tasks"] = envelope
        let unknown = try JSONSerialization.data(withJSONObject: root)
        staged = WorkspaceData(tasks: [task]); staged.tasks[0].originalOccurrenceSchedule = nil
        XCTAssertNil(try ScheduleJSONPatch.applying(taskID: task.id, staged: staged, to: unknown))
    }
}

extension ScheduleJSONPatchTests {
    func testUnrelatedUnicodeAndDuplicateKeysRefused() throws {
        let first = TaskItem(title: "Target"), second = TaskItem(title: "\u{00E9}")
        let original = WorkspaceData(tasks: [first, second])
        let bytes = try JSONEncoder().encode(original)
        var staged = original; staged.tasks[0].timeZoneID = "UTC"; staged.tasks[1].title = "e\u{0301}"
        XCTAssertNil(try ScheduleJSONPatch.applying(taskID: first.id, staged: staged, to: bytes))
        staged = original; staged.tasks[0].timeZoneID = "UTC"
        var duplicate = bytes
        duplicate.insert(contentsOf: Data("\"tasks\":[],".utf8), at: 1)
        XCTAssertNil(try ScheduleJSONPatch.applying(taskID: first.id, staged: staged, to: duplicate))
    }
}
