import XCTest
@testable import TaskovskyCore

final class EntryAndListTests: XCTestCase {
    func testInboxFilterAndMixedListsRoundTrip() throws {
        let listID = UUID()
        let inbox = TaskItem(title: "Inbox")
        let listed = TaskItem(title: "Listed", listID: listID)
        var filter = TaskFilter(name: "Inbox", listIDs: [TaskFilter.inboxListID])
        XCTAssertTrue(filter.matches(inbox))
        XCTAssertFalse(filter.matches(listed))
        filter.listIDs.append(listID)
        let decoded = try JSONDecoder().decode(TaskFilter.self, from: JSONEncoder().encode(filter))
        XCTAssertTrue(decoded.matches(inbox))
        XCTAssertTrue(decoded.matches(listed))
    }
    @MainActor func testPreviewMatchesSavedDateAndRejectionKeepsPlainText() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        store.settings.urlParsing = false
        let title = "Review tomorrow at 4pm #audit"
        let preview = try XCTUnwrap(TaskStore.recognizeDate(in: title, calendar: store.settings.calendar))
        XCTAssertEqual(String(title[preview.range]), "tomorrow at 4pm")
        XCTAssertTrue(preview.hasTime)
        let scheduled = store.createTask(title: title, body: "A plain-text description")
        let saved = try XCTUnwrap(store.data.tasks.first { $0.id == scheduled })
        XCTAssertEqual(saved.dueDate, preview.date)
        XCTAssertEqual(saved.body, "A plain-text description")
        let rejected = store.createTask(title: title, recognizeDates: false, body: "Keep this date as text")
        let unscheduled = try XCTUnwrap(store.data.tasks.first { $0.id == rejected })
        XCTAssertNil(unscheduled.dueDate)
        XCTAssertTrue(unscheduled.title.contains("tomorrow at 4pm"))
        XCTAssertFalse(unscheduled.title.contains("#audit"))
        XCTAssertEqual(unscheduled.tagIDs, saved.tagIDs)
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.tasks.first { $0.id == rejected }?.body, "Keep this date as text")
        let spaced = store.createTag(name: "Deep work", color: "#526BF5")
        let tagged = store.createTask(title: "Focus #\"Deep work\"", recognizeDates: false)
        XCTAssertEqual(store.data.tasks.first { $0.id == tagged }?.tagIDs, [spaced])
        XCTAssertEqual(store.data.tasks.first { $0.id == tagged }?.title, "Focus")
    }

    @MainActor func testListSymbolsRoundTripAndOldListsDecode() throws {
        let old = TaskList(name: "Old list", color: "#526BF5")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "symbol")
        let decoded = try JSONDecoder().decode(TaskList.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.symbol)
        XCTAssertEqual(decoded.name, old.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TaskStore(fileURL: url, seed: false)
        let id = store.createList(name: "Home", color: "#526BF5", symbol: "🏠")
        let loaded = TaskStore(fileURL: url, seed: false)
        XCTAssertEqual(loaded.data.lists.first { $0.id == id }?.symbol, "🏠")
        var list = try XCTUnwrap(loaded.data.lists.first)
        list.symbol = "briefcase"; loaded.updateList(list)
        XCTAssertEqual(TaskStore(fileURL: url, seed: false).data.lists.first?.symbol, "briefcase")
    }
}
