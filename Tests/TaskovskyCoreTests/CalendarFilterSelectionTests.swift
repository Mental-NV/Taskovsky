import XCTest
@testable import TaskovskyCore

final class CalendarFilterSelectionTests: XCTestCase {
    private struct Fixture {
        let a = TaskList(name: "A", color: "#528DD9")
        let b = TaskList(name: "B", color: "#58A888")
        let tag = TaskTag(name: "Area", color: "#123456")
        let other = TaskTag(name: "Other", color: "#654321")
        var data: WorkspaceData { .init(lists: [a, b], tags: [tag, other]) }
    }
    private func titles(_ options: TaskCalendarOptions, _ data: WorkspaceData) -> Set<String> {
        Set(data.tasks.filter { options.includes($0, data: data) }.map(\.title))
    }

    func testAllIsAnIdempotentModeWithUnmarkedChildrenAndClearsEverySelection() {
        let f = Fixture(); var options = TaskCalendarOptions()
        for _ in 0..<3 {
            options.selectAllSources()
            XCTAssertTrue(options.isAllSources)
            XCTAssertTrue(options.selectedListIDs(in: f.data).isEmpty)
            XCTAssertFalse(options.isInboxSelected)
            XCTAssertEqual(options.listSelectionState(in: f.data), .off)
            XCTAssertEqual(options.tagSelectionState(in: f.data), .off)
        }
        options.setListSelected(f.a.id, true, data: f.data)
        options.setTagSelected(f.tag.id, true, data: f.data)
        options.setInboxSelected(true, data: f.data)
        options.selectAllSources()
        XCTAssertNil(options.listIDs); XCTAssertTrue(options.includeInbox); XCTAssertTrue(options.tagIDs.isEmpty)
    }

    func testFirstSourceFromAllSelectsOnlyThatSource() {
        let f = Fixture(); var options = TaskCalendarOptions()
        options.setListSelected(f.a.id, true, data: f.data)
        XCTAssertEqual(options.listIDs, [f.a.id]); XCTAssertFalse(options.includeInbox); XCTAssertTrue(options.tagIDs.isEmpty)
        options.selectAllSources(); options.setTagSelected(f.tag.id, true, data: f.data)
        XCTAssertEqual(options.listIDs, []); XCTAssertFalse(options.includeInbox); XCTAssertEqual(options.tagIDs, [f.tag.id])
        options.selectAllSources(); options.setInboxSelected(true, data: f.data)
        XCTAssertEqual(options.listIDs, []); XCTAssertTrue(options.isInboxSelected); XCTAssertTrue(options.tagIDs.isEmpty)
    }

    func testListsInboxAndTagsAreAUnionRatherThanAnIntersection() {
        let f = Fixture()
        let data = WorkspaceData(tasks: [TaskItem(title: "A plain", listID: f.a.id),
            TaskItem(title: "B tagged", listID: f.b.id, tagIDs: [f.tag.id]),
            TaskItem(title: "B plain", listID: f.b.id), TaskItem(title: "Inbox plain"),
            TaskItem(title: "Inbox tagged", tagIDs: [f.tag.id])], lists: f.data.lists, tags: f.data.tags)
        var options = TaskCalendarOptions()
        options.setListSelected(f.a.id, true, data: data); options.setTagSelected(f.tag.id, true, data: data)
        XCTAssertEqual(titles(options, data), ["A plain", "B tagged", "Inbox tagged"])
        options.setInboxSelected(true, data: data)
        XCTAssertEqual(titles(options, data), ["A plain", "B tagged", "Inbox tagged", "Inbox plain"])
        options.setListSelected(f.a.id, false, data: data)
        XCTAssertEqual(titles(options, data), ["B tagged", "Inbox tagged", "Inbox plain"])
    }

    func testClearingLastListInboxOrTagReturnsToAllAndRepeatedCommandsDoNotDuplicate() {
        let f = Fixture(); var options = TaskCalendarOptions()
        for _ in 0..<5 {
            options.setListSelected(f.a.id, true, data: f.data); options.setListSelected(f.a.id, true, data: f.data)
            XCTAssertEqual(options.listIDs, [f.a.id])
            options.setListSelected(f.a.id, false, data: f.data); XCTAssertTrue(options.isAllSources)
            options.setTagSelected(f.tag.id, true, data: f.data); options.setTagSelected(f.tag.id, true, data: f.data)
            XCTAssertEqual(options.tagIDs, [f.tag.id])
            options.setTagSelected(f.tag.id, false, data: f.data); XCTAssertTrue(options.isAllSources)
            options.setInboxSelected(true, data: f.data); options.setInboxSelected(false, data: f.data)
            XCTAssertTrue(options.isAllSources)
        }
    }

    func testListAndTagGroupOffMixedOnAndClearingPreservesOtherGroup() {
        let f = Fixture(); var options = TaskCalendarOptions()
        options.setListSelected(f.a.id, true, data: f.data)
        XCTAssertEqual(options.listSelectionState(in: f.data), .mixed)
        options.setListsSelected(true, data: f.data)
        XCTAssertEqual(Set(options.listIDs ?? []), Set([f.a.id, f.b.id]))
        XCTAssertEqual(options.listSelectionState(in: f.data), .on); XCTAssertFalse(options.isAllSources)
        options.setTagSelected(f.tag.id, true, data: f.data)
        XCTAssertEqual(options.tagSelectionState(in: f.data), .mixed)
        options.setTagsSelected(true, data: f.data); XCTAssertEqual(options.tagSelectionState(in: f.data), .on)
        options.setListsSelected(false, data: f.data)
        XCTAssertEqual(options.listSelectionState(in: f.data), .off); XCTAssertFalse(options.isAllSources)
        XCTAssertEqual(options.tagSelectionState(in: f.data), .on)
        options.setTagsSelected(false, data: f.data); XCTAssertTrue(options.isAllSources)
    }

    func testLegacyTagOnlyAndAllListsWithoutInboxRemainRestrictive() throws {
        let f = Fixture()
        let data = WorkspaceData(tasks: [TaskItem(title: "A plain", listID: f.a.id),
            TaskItem(title: "B tagged", listID: f.b.id, tagIDs: [f.tag.id]), TaskItem(title: "Inbox plain")], lists: f.data.lists, tags: f.data.tags)
        var options = TaskCalendarOptions(); options.tagIDs = [f.tag.id]
        let restored = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
        XCTAssertEqual(titles(restored, data), ["B tagged"]); XCTAssertFalse(restored.isInboxSelected)
        options.tagIDs = []; options.includeInbox = false
        XCTAssertEqual(titles(options, data), ["A plain", "B tagged"])
        options.setListSelected(f.a.id, false, data: data)
        XCTAssertEqual(options.listIDs, [f.b.id]); XCTAssertFalse(options.includeInbox)
    }

    func testEmptyAndStaleSavedSelectionsNeverBroadenUntilExplicitClear() throws {
        let f = Fixture(); var options = TaskCalendarOptions()
        options.listIDs = []; options.includeInbox = false
        var data = f.data; data.tasks = [TaskItem(title: "Hidden", listID: f.a.id)]
        let empty = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
        XCTAssertFalse(empty.isAllSources); XCTAssertTrue(titles(empty, data).isEmpty)
        options.listIDs = [UUID()]; options.tagIDs = [UUID()]
        let stale = try JSONDecoder().decode(TaskCalendarOptions.self, from: JSONEncoder().encode(options))
        XCTAssertEqual(stale, options); XCTAssertTrue(titles(stale, data).isEmpty)
        XCTAssertEqual(stale.listSelectionState(in: data), .mixed); XCTAssertEqual(stale.tagSelectionState(in: data), .mixed)
        options.clearUnavailableSources(data: data); XCTAssertTrue(options.isAllSources)
    }

    func testClearingUnavailableSourcesKeepsSurvivingIntent() {
        let f = Fixture(); var options = TaskCalendarOptions()
        options.listIDs = [UUID(), f.a.id]; options.includeInbox = false; options.tagIDs = [UUID(), f.tag.id]
        options.clearUnavailableSources(data: f.data)
        XCTAssertEqual(options.listIDs, [f.a.id]); XCTAssertEqual(options.tagIDs, [f.tag.id]); XCTAssertFalse(options.isAllSources)
    }

    func testDescendantTagUnionStillExcludesArchivedAndDeletedTasks() {
        let f = Fixture()
        let childTag = TaskTag(name: "Child", color: "#123456", parentID: f.tag.id)
        var archived = f.b; archived.isArchived = true
        var deleted = TaskItem(title: "Deleted", listID: f.a.id, tagIDs: [childTag.id]); deleted.deletedAt = Date()
        let data = WorkspaceData(tasks: [TaskItem(title: "Descendant", tagIDs: [childTag.id]),
            TaskItem(title: "Archived", listID: archived.id, tagIDs: [childTag.id]), deleted], lists: [f.a, archived], tags: [f.tag, childTag])
        var options = TaskCalendarOptions(); options.setTagSelected(f.tag.id, true, data: data)
        XCTAssertEqual(titles(options, data), ["Descendant"])
        options.selectAllSources(); XCTAssertEqual(titles(options, data), ["Descendant"])
    }

    func testEmptyWorkspaceAndTaglessGroupCommandsRemainUsable() {
        var options = TaskCalendarOptions(); let data = WorkspaceData()
        options.setTagsSelected(true, data: data); XCTAssertTrue(options.isAllSources)
        options.setListsSelected(true, data: data); XCTAssertTrue(options.isInboxSelected)
        XCTAssertEqual(options.listSelectionState(in: data), .on)
        options.setListsSelected(false, data: data); XCTAssertTrue(options.isAllSources)
    }

    func testShowOnlyListClearsTagsAndInbox() {
        let f = Fixture(); var options = TaskCalendarOptions()
        options.setTagSelected(f.tag.id, true, data: f.data); options.setInboxSelected(true, data: f.data)
        options.selectOnlyList(f.a.id)
        XCTAssertEqual(options.listIDs, [f.a.id]); XCTAssertFalse(options.includeInbox); XCTAssertTrue(options.tagIDs.isEmpty)
    }

    func testArrangeExplicitListRestrictsWhileCalendarChoiceUsesUnion() {
        let f = Fixture()
        let data = WorkspaceData(tasks: [TaskItem(title: "A plain", listID: f.a.id), TaskItem(title: "A tagged", listID: f.a.id, tagIDs: [f.tag.id]),
            TaskItem(title: "B tagged", listID: f.b.id, tagIDs: [f.tag.id]), TaskItem(title: "Inbox tagged", tagIDs: [f.tag.id])], lists: f.data.lists, tags: f.data.tags)
        var options = TaskCalendarOptions(); options.setListSelected(f.a.id, true, data: data); options.setTagSelected(f.tag.id, true, data: data)
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertEqual(Set(TaskCalendarProjection.arrangementTasks(data: data, options: options, calendar: calendar).map(\.title)), ["A plain", "A tagged", "B tagged", "Inbox tagged"])
        XCTAssertEqual(TaskCalendarProjection.arrangementTasks(data: data, options: options, calendar: calendar, selection: .list(f.a.id)).map(\.title), ["A tagged"])
        XCTAssertEqual(TaskCalendarProjection.arrangementTasks(data: data, options: options, calendar: calendar, selection: .inbox).map(\.title), ["Inbox tagged"])
    }

    @MainActor func testStoreReloadAndViewChangesKeepSelectionAndNeverWriteTaskFile() throws {
        let f = Fixture(), dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("workspace.json"), settings = dir.appendingPathComponent("settings.json")
        var data = f.data; data.tasks = [TaskItem(title: "Unchanged", listID: f.a.id)]
        try JSONEncoder().encode(data).write(to: file); let original = try Data(contentsOf: file)
        let store = TaskStore(fileURL: file, settingsURL: settings, seed: false)
        var options = store.settings.calendarOptions
        options.setListSelected(f.a.id, true, data: store.data); options.setTagSelected(f.tag.id, true, data: store.data)
        for mode in TaskCalendarMode.allCases { options.mode = mode; store.settings.calendarOptions = options }
        let restored = TaskStore(fileURL: file, settingsURL: settings, seed: false)
        XCTAssertEqual(restored.settings.calendarOptions, options)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}
