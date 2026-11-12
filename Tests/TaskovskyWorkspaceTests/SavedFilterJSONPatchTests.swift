import XCTest
import TaskovskyDomain
@testable import TaskovskyWorkspace

final class SavedFilterJSONPatchTests: XCTestCase {
    func testRenamePreservesUnknownFieldsLegacyDefaultsAndEscapesByteForByte() throws {
        let id = UUID()
        let raw = """
        {"future": { "large": 123456789012345678901, "text": "é\\u263a" }, "tasks":[],"lists":[],"tags":[],"templates":[],
         "filters":[{"id":"\(id.uuidString)","name":"Old","customDateFrom":null,
         "priority":"high","futureFilter": {"keep":1e3},
         "ruleRoot": {"type":"and","children":[],"futureRule": { "x":42 }} }]}
        """
        let bytes = Data(raw.utf8), old = try JSONDecoder().decode(WorkspaceData.self, from: bytes).filters[0]
        var renamed = old; renamed.name = "New é \"quoted\""
        let patched = try XCTUnwrap(SavedFilterJSONPatch.applying(.update(renamed), to: bytes))
        let expectedName = String(decoding: try JSONEncoder().encode(renamed.name), as: UTF8.self)
        XCTAssertEqual(String(decoding: patched, as: UTF8.self), raw.replacingOccurrences(of: "\"name\":\"Old\"", with: "\"name\":\(expectedName)"))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: patched).filters[0], renamed)
        var changedRule = old; changedRule.ruleRoot = .or([])
        XCTAssertNil(try SavedFilterJSONPatch.applying(.update(changedRule), to: bytes))
    }
    func testCreatePreservesUnknownOtherFilterAndSupportsAbsentArrayOnly() throws {
        let id = UUID(), old = "{\"id\":\"\(UUID().uuidString)\",\"name\":\"Old\",\"future\":[1,2]}"
        let raw = "{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"filters\":[ \(old) ],\"future\":true}"
        let filter = TaskFilter(id: id, name: "New")
        let result = try XCTUnwrap(SavedFilterJSONPatch.applying(.create(filter), to: Data(raw.utf8)))
        XCTAssertTrue(String(decoding: result, as: UTF8.self).contains(old))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: result).filters.count, 2)
        let absent = try XCTUnwrap(SavedFilterJSONPatch.applying(.create(filter), to: Data("{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"future\":42}".utf8)))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: absent).filters, [filter])
        XCTAssertNil(try SavedFilterJSONPatch.applying(.create(filter), to: Data("{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"filters\":null}".utf8)))
    }
    func testChangedLegacyDefaultsAndOptionalNullAreLossless() throws {
        let id = UUID()
        let raw = Data("{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"filters\":[{\"id\":\"\(id.uuidString)\",\"name\":\"Old\",\"customDateFrom\":42}]}".utf8)
        var changed = try JSONDecoder().decode(WorkspaceData.self, from: raw).filters[0]
        changed.keyword = "new"; changed.customDateFrom = nil
        let result = try XCTUnwrap(SavedFilterJSONPatch.applying(.update(changed), to: raw))
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceData.self, from: result).filters, [changed])
        XCTAssertTrue(String(decoding: result, as: UTF8.self).contains("\"customDateFrom\":null"))
        XCTAssertFalse(String(decoding: result, as: UTF8.self).contains("\"priorities\""))
    }
    func testDuplicateKeysIDsAndMalformedArraysAreRefused() throws {
        let value = TaskFilter(name: "Owned")
        let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        let cases = ["{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"filters\":[],\"filters\":[]}", "{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"filters\":[\(encoded),\(encoded)]}",
                     "{\"tasks\":[],\"lists\":[],\"tags\":[],\"templates\":[],\"filters\":{}}"]
        for raw in cases {
            do { let result = try SavedFilterJSONPatch.applying(.create(TaskFilter(name: "New")), to: Data(raw.utf8)); XCTAssertNil(result) }
            catch { /* Typed malformed collections also fail closed. */ }
        }
    }
}
