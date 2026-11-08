import XCTest
@testable import TaskovskyCore

/// Rich-text representation safety and task pinning.
///
/// The plain body is authoritative: styles mirror it and clear whenever it is
/// replaced independently. Pinning is persisted state with active-only
/// grouping semantics.
final class RichTextPinTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("workspace.json")
    }

    // MARK: - Legacy decoding

    @MainActor func testLegacyTaskDecodesPlainAndUnpinned() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Legacy", body: "plain body")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var tasks = try XCTUnwrap(json["tasks"] as? [[String: Any]])
        XCTAssertEqual(tasks.count, 1)
        tasks[0].removeValue(forKey: "richBody")
        tasks[0].removeValue(forKey: "isPinned")
        json["tasks"] = tasks
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let loaded = TaskStore(fileURL: url, seed: false)
        let task = try XCTUnwrap(loaded.data.tasks.first { $0.id == id })
        XCTAssertEqual(task.body, "plain body")
        XCTAssertNil(task.richBody)
        XCTAssertFalse(task.isPinned)
    }

    @MainActor func testLegacyTemplateDecodesWithoutRichBody() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "T", body: "styled?")
        _ = store.saveTemplate(from: id)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var templates = try XCTUnwrap(json["templates"] as? [[String: Any]])
        templates = templates.map { var t = $0; t.removeValue(forKey: "richBody"); return t }
        json["templates"] = templates
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertTrue(loaded.data.templates.allSatisfy { $0.richBody == nil })
    }

    // MARK: - Representation safety

    func testValidGatesOnExactBodyMatch() {
        let rich = RichBody(text: "hello", runs: [RichInlineRun(location: 0, length: 5, bold: true)])
        XCTAssertNotNil(rich.valid(for: "hello"))
        XCTAssertNil(rich.valid(for: "hello!"))
        XCTAssertNil(rich.valid(for: ""))
    }

    func testSanitizedClampsDropsAndSorts() {
        // "héllo" is 5 UTF-16 units (precomposed é); runs past the end clamp,
        // zero-length and unstyled runs drop, survivors sort by location.
        let rich = RichBody(
            text: "héllo",
            runs: [
                RichInlineRun(location: 4, length: 10, bold: true),
                RichInlineRun(location: 2, length: 0, italic: true),
                RichInlineRun(location: 0, length: 2, italic: true),
                RichInlineRun(location: 1, length: 1)
            ],
            blocks: [
                RichBlockRun(location: 0, length: 99, heading: 9),
                RichBlockRun(location: 3, length: 99, quote: true)
            ])
        XCTAssertEqual((rich.text as NSString).length, 5)
        let clean = rich.sanitized()
        XCTAssertEqual(clean.text, "héllo")
        XCTAssertEqual(clean.runs.map(\.location), [0, 4])
        XCTAssertEqual(clean.runs.map(\.length), [2, 1])
        XCTAssertTrue(clean.runs.allSatisfy { !$0.isEmpty })
        // An out-of-range heading level drops the block; the quote clamps.
        XCTAssertEqual(clean.blocks.count, 1)
        XCTAssertEqual(clean.blocks[0].location, 3)
        XCTAssertEqual(clean.blocks[0].length, 2)
        XCTAssertTrue(clean.blocks[0].quote)
    }

    // MARK: - Persistence

    @MainActor func testRichBodyAndPinPersistAcrossReload() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Styled", body: "hello world")
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.richBody = RichBody(text: "hello world", runs: [RichInlineRun(location: 0, length: 5, bold: true)])
        store.updateTask(task)
        XCTAssertTrue(store.setPinned(id: id, pinned: true))
        let loaded = TaskStore(fileURL: url, seed: false)
        let saved = try XCTUnwrap(loaded.data.tasks.first { $0.id == id })
        XCTAssertEqual(saved.richBody, RichBody(text: "hello world", runs: [RichInlineRun(location: 0, length: 5, bold: true)]))
        XCTAssertTrue(saved.isPinned)
        XCTAssertEqual(saved.body, "hello world")
    }

    @MainActor func testIndependentBodyReplaceClearsStaleStyles() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Doc", body: "first")
        var styled = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        styled.richBody = RichBody(text: "first", runs: [RichInlineRun(location: 0, length: 5, bold: true)])
        store.updateTask(styled)
        XCTAssertNotNil(store.data.tasks.first { $0.id == id }?.richBody)
        // A matching write (the rich editor path) preserves styles.
        var same = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        same.richBody = RichBody(text: "first", runs: [RichInlineRun(location: 0, length: 5, italic: true)])
        store.updateTask(same)
        XCTAssertEqual(store.data.tasks.first { $0.id == id }?.richBody?.runs.first?.italic, true)
        // An independent body replacement drops styles instead of shifting them.
        var replaced = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        replaced.body = "completely different"
        replaced.richBody = RichBody(text: "first", runs: [RichInlineRun(location: 0, length: 5, italic: true)])
        store.updateTask(replaced)
        let cleared = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        XCTAssertEqual(cleared.body, "completely different")
        XCTAssertNil(cleared.richBody)
    }

    // MARK: - Duplicate / template integration

    @MainActor func testDuplicatePreservesStyles() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Doc", body: "keep me")
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.richBody = RichBody(text: "keep me", runs: [RichInlineRun(location: 0, length: 4, underline: true)])
        store.updateTask(task)
        XCTAssertTrue(store.setPinned(id: id, pinned: true))
        let copyID = try XCTUnwrap(store.duplicateTask(id: id))
        let copy = try XCTUnwrap(store.data.tasks.first { $0.id == copyID })
        XCTAssertEqual(copy.body, "keep me")
        XCTAssertEqual(copy.richBody?.valid(for: copy.body)?.runs.first?.underline, true)
        XCTAssertTrue(copy.isPinned)
    }

    @MainActor func testTemplateSaveApplyPreservesStyles() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createTask(title: "Doc", body: "repeat me")
        var task = try XCTUnwrap(store.data.tasks.first { $0.id == id })
        task.richBody = RichBody(text: "repeat me", runs: [RichInlineRun(location: 0, length: 6, highlight: true)])
        store.updateTask(task)
        let templateID = try XCTUnwrap(store.saveTemplate(from: id))
        let createdID = try XCTUnwrap(store.createTaskFromTemplate(id: templateID))
        let created = try XCTUnwrap(store.data.tasks.first { $0.id == createdID })
        XCTAssertEqual(created.body, "repeat me")
        XCTAssertEqual(created.richBody?.valid(for: created.body)?.runs.first?.highlight, true)
        // A template whose mirrored text no longer matches its body applies plain.
        var template = try XCTUnwrap(store.data.templates.first { $0.id == templateID })
        template.body = "changed elsewhere"
        store.updateTemplate(template)
        let plainID = try XCTUnwrap(store.createTaskFromTemplate(id: templateID))
        let plain = try XCTUnwrap(store.data.tasks.first { $0.id == plainID })
        XCTAssertEqual(plain.body, "changed elsewhere")
        XCTAssertNil(plain.richBody)
    }

    // MARK: - Pin state

    @MainActor func testSetPinnedRefusesNonActiveRows() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        XCTAssertFalse(store.setPinned(id: UUID(), pinned: true))
        let id = store.createTask(title: "Pinnable")
        XCTAssertTrue(store.setPinned(id: id, pinned: true))
        XCTAssertTrue(store.data.tasks.first { $0.id == id }?.isPinned == true)
        XCTAssertTrue(store.setPinned(id: id, pinned: false))
        store.trashTask(id: id)
        XCTAssertFalse(store.setPinned(id: id, pinned: true))
        store.restoreTask(id: id)
        XCTAssertTrue(store.setPinned(id: id, pinned: true))
        store.toggleComplete(id: id)
        XCTAssertFalse(store.setPinned(id: id, pinned: false))
        XCTAssertFalse(store.setPinned(id: id, pinned: true))
        store.reopenTask(id: id)
        // The stored flag survived completion, so the pin is back.
        XCTAssertTrue(store.data.tasks.first { $0.id == id }?.isPinned == true)
        store.markWontDo(id: id)
        XCTAssertFalse(store.setPinned(id: id, pinned: false))
    }

    func testPinnedPartitionKeepsOrderAndExcludesNonActive() {
        let pinned = TaskItem(title: "P", body: "x", isPinned: true)
        let plain = TaskItem(title: "A", body: "x")
        let donePin = TaskItem(title: "D", body: "x", completedAt: Date(), isPinned: true)
        let wontPin = TaskItem(title: "W", body: "x", wontDoAt: Date(), isPinned: true)
        let trashedPin = TaskItem(title: "T", body: "x", deletedAt: Date(), isPinned: true)
        let (tops, rest) = PinnedGrouping.partition([plain, donePin, pinned, wontPin, trashedPin])
        XCTAssertEqual(tops.map(\.title), ["P"])
        XCTAssertEqual(rest.map(\.title), ["A", "D", "W", "T"])
        XCTAssertFalse(PinnedGrouping.isPinnedRow(donePin))
        XCTAssertFalse(PinnedGrouping.isPinnedRow(wontPin))
        XCTAssertFalse(PinnedGrouping.isPinnedRow(trashedPin))
        XCTAssertTrue(PinnedGrouping.isPinnedRow(pinned))
    }
}
